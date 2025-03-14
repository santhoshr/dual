#import "DualManager+CapsNavigation.h"
#import "DualManager+KeyboardStatus.h"
#import "DualManager+ConsoleWindow.h"
#import "DualManager+KeyDisplay.h"
#import "NSApplication+CommandLine.h"
#import <mach/mach_time.h>

// Navigation state tracking
static BOOL vimModeActive = NO;
static BOOL vimModeLocked = NO;
static BOOL capsKeyDown = NO;
static uint64_t capsKeyPressTime = 0;
static BOOL keyRepeat = NO;
static NSTimer *remapCheckTimer = nil;

// Constants
static const uint64_t HOLD_THRESHOLD = 150000000ULL; // 150ms in nanoseconds

// Timebase info for accurate timing
static mach_timebase_info_data_t timebaseInfo;

@implementation DualManager (CapsNavigation)

- (void)setupCapsLockRemapping {
    // Initialize timebase info
    if (timebaseInfo.denom == 0) {
        mach_timebase_info(&timebaseInfo);
    }
    
    [self applyCapsLockRemapping];
    
    // Set up periodic check every 30 seconds
    if (!remapCheckTimer) {
        remapCheckTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                         target:self
                                                       selector:@selector(checkAndReapplyCapsLockMapping)
                                                       userInfo:nil
                                                        repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:remapCheckTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)applyCapsLockRemapping {
    NSTask *task = [[NSTask alloc] init];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    task.launchPath = @"/usr/bin/hidutil";
    task.arguments = @[@"property", @"--set", @"{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":0x700000039,\"HIDKeyboardModifierMappingDst\":0x700000064}]}"];
    
    NSError *error = nil;
    [task launchAndReturnError:&error];
    
    if (error) {
        if (self.debugMode) {
            NSLog(@"Error applying CapsLock mapping: %@", error);
        }
        return;
    }
    
    [task waitUntilExit];
    
    if (task.terminationStatus != 0) {
        NSData *errorData = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *errorOutput = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
        if (self.debugMode) {
            NSLog(@"CapsLock remapping failed with status %d: %@", task.terminationStatus, errorOutput);
        }
    } else if (self.debugMode) {
        NSLog(@"CapsLock remapping applied successfully");
    }
}

- (void)checkAndReapplyCapsLockMapping {
    // Check if capslock is still mapped correctly by checking a recent keycode
    if (self.debugMode) {
        NSLog(@"Checking CapsLock mapping status...");
    }
    
    static NSTimeInterval lastRemapTime = 0;
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    // Only reapply if more than 1 second has passed since last remap
    if (currentTime - lastRemapTime > 1.0) {
        [self applyCapsLockRemapping];
        lastRemapTime = currentTime;
        
        if (self.debugMode) {
            NSLog(@"CapsLock mapping reapplied at %@", [NSDate date]);
        }
    }
}

- (void)restoreCapsLockMapping {
    if (remapCheckTimer) {
        [remapCheckTimer invalidate];
        remapCheckTimer = nil;
    }
    
    NSTask *task = [[NSTask alloc] init];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    task.launchPath = @"/usr/bin/hidutil";
    task.arguments = @[@"property", @"--set", @"{\"UserKeyMapping\":[]}"];
    
    NSError *error = nil;
    [task launchAndReturnError:&error];
    
    if (error) {
        if (self.debugMode) {
            NSLog(@"Error restoring CapsLock mapping: %@", error);
        }
        return;
    }
    
    [task waitUntilExit];
    
    if (task.terminationStatus == 0 && self.debugMode) {
        NSLog(@"Original keyboard mapping restored successfully");
    }
}

- (void)sendEscapeKey {
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (!source) return;
    
    CGEventRef escapeDown = CGEventCreateKeyboardEvent(source, 53, true);
    CGEventRef escapeUp = CGEventCreateKeyboardEvent(source, 53, false);
    
    CGEventPost(kCGHIDEventTap, escapeDown);
    usleep(1000);
    CGEventPost(kCGHIDEventTap, escapeUp);
    
    CFRelease(escapeDown);
    CFRelease(escapeUp);
    CFRelease(source);
}

- (uint64_t)getHoldDurationInNanoseconds:(uint64_t)currentTime {
    if (capsKeyPressTime == 0) return 0;
    uint64_t delta = currentTime - capsKeyPressTime;
    return (delta * timebaseInfo.numer) / timebaseInfo.denom;
}

- (BOOL)handleCapsNavigation:(CGEventRef)event ofType:(CGEventType)type withKeycode:(CGKeyCode)keycode flags:(CGEventFlags)flags {
    // Access the combined modifier states from KeyboardMapping
    extern BOOL leftShiftDown, rightShiftDown;
    extern BOOL leftControlDown, rightControlDown; 
    extern BOOL leftCommandDown, rightCommandDown;
    extern BOOL leftOptionDown, rightOptionDown;
    
    // Update key display if active
    [self updateKeyDisplay:keycode flags:flags isKeyDown:(type == kCGEventKeyDown)];
    
    if (self.debugMode) {
        // Compute combined modifier states for display - use direct state variables
        BOOL shiftActive = leftShiftDown || rightShiftDown;
        BOOL ctrlActive = leftControlDown || rightControlDown;
        BOOL optActive = leftOptionDown || rightOptionDown;
        BOOL cmdActive = leftCommandDown || rightCommandDown;
        
        // Get raw flags directly from the event
        CGEventFlags rawFlags = CGEventGetFlags(event);
        NSString *eventType = (type == kCGEventKeyDown) ? @"KeyDown" : (type == kCGEventKeyUp) ? @"KeyUp" : @"FlagsChanged";
        NSString *debugMsg = [NSString stringWithFormat:@"Key Event: %@ keycode=%d [flags=0x%llx] cmd:%d ctrl:%d opt:%d shift:%d\n", 
                           eventType, (int)keycode, (unsigned long long)rawFlags,
                           cmdActive ? 1 : 0,
                           ctrlActive ? 1 : 0,
                           optActive ? 1 : 0,
                           shiftActive ? 1 : 0];
        if ([NSApp isRunningFromCommandLine]) {
            printf("%s", [debugMsg UTF8String]);
            fflush(stdout);
        } else {
            [self appendToConsole:debugMsg];
        }
    }
    
    // Handle CapsLock (Section key)
    if (keycode == 10) {
        uint64_t currentTime = mach_absolute_time();
        
        if (type == kCGEventKeyDown) {
            BOOL isRepeat = (CGEventGetIntegerValueField(event, kCGKeyboardEventAutorepeat) != 0);
            uint64_t holdDuration = [self getHoldDurationInNanoseconds:currentTime];
            
            if (!capsKeyDown && !isRepeat) {
                capsKeyDown = YES;
                capsKeyPressTime = currentTime;
                keyRepeat = NO;
                if (self.debugMode) {
                    NSLog(@"CapsLock pressed at %llu", capsKeyPressTime);
                }
            }
            
            // Check hold duration on every key down event, not just repeats
            if (capsKeyDown && !vimModeActive && !vimModeLocked && holdDuration >= HOLD_THRESHOLD) {
                vimModeActive = YES;
                [self updateStatusWithMode:'N'];
                if (self.debugMode) {
                    NSLog(@"Entering vim mode (hold duration: %llu ns)", holdDuration);
                }
            }
            
            return YES;
            
        } else if (type == kCGEventKeyUp) {
            if (!capsKeyDown) return YES;
            
            uint64_t holdDuration = [self getHoldDurationInNanoseconds:currentTime];
            capsKeyDown = NO;
            keyRepeat = NO;
            
            if (self.debugMode) {
                NSLog(@"CapsLock released, hold duration: %llu ns", holdDuration);
            }
            
            // If it was a quick tap and we're in locked navigation mode, exit it
            if (holdDuration < HOLD_THRESHOLD) {
                if (vimModeLocked) {
                    vimModeLocked = NO;
                    vimModeActive = NO;
                    [self updateStatusWithMode:'I'];
                    if (self.debugMode) {
                        NSLog(@"Exiting vim mode via CapsLock tap");
                    }
                } else if (!vimModeActive) {
                    [self sendEscapeKey];
                }
            }
            
            if (!vimModeLocked) {
                vimModeActive = NO;
                capsKeyPressTime = 0;  // Reset press time
                [self updateStatusWithMode:'I'];
            }
            return YES;
        }
    }

    // If we detect CapsLock reverting (keycode 57), reapply the mapping
    if (keycode == 57 && type == kCGEventFlagsChanged) {
        if (self.debugMode) {
            NSLog(@"Detected CapsLock reversion, reapplying mapping...");
        }
        [self applyCapsLockRemapping];
        return YES;
    }

    // Handle Escape key for exiting navigation mode
    if (keycode == 53 && type == kCGEventKeyDown) {
        if (vimModeLocked) {
            vimModeLocked = NO;
            vimModeActive = NO;
            capsKeyDown = NO;
            capsKeyPressTime = 0;
            [self updateStatusWithMode:'I'];
            if (self.debugMode) {
                NSLog(@"Exiting vim mode via Escape");
            }
            return YES;
        }
    }

    // Handle navigation keys when CapsLock is held
    if (capsKeyDown && type == kCGEventKeyDown && !vimModeLocked) {
        // Check if it's a navigation key
        switch (keycode) {
            case 4:  // h
            case 38: // j
            case 40: // k
            case 37: // l
            case 34: // i
            case 31: // o
            case 43: // comma
            case 47: // dot
                if (!vimModeActive) {
                    vimModeActive = YES;
                    [self updateStatusWithMode:'N'];
                    if (self.debugMode) {
                        NSLog(@"Entering vim mode via navigation key %d", (int)keycode);
                    }
                }
                break;
            default:
                break;
        }
    }

    // Handle vim navigation mode
    if ((vimModeActive || vimModeLocked) && type == kCGEventKeyDown) {
        // Handle Shift+I to exit vim mode when locked
        if (keycode == 34 && (flags & kCGEventFlagMaskShift)) {
            vimModeLocked = NO;
            vimModeActive = NO;
            capsKeyDown = NO;  // Ensure capslock state is reset
            capsKeyPressTime = 0;
            [self updateStatusWithMode:'I'];
            return YES;
        }
        
        // Handle vim navigation keys
        CGKeyCode newKeycode = 0;
        BOOL shouldRemap = YES;
        
        switch (keycode) {
            case 4:  newKeycode = 123; break; // h -> left
            case 38: newKeycode = 125; break; // j -> down
            case 40: newKeycode = 126; break; // k -> up
            case 37: newKeycode = 124; break; // l -> right
            case 34: newKeycode = 116; break; // i -> page up
            case 31: newKeycode = 121; break; // o -> page down
            case 43: newKeycode = 115; break; // , -> home
            case 47: newKeycode = 119; break; // . -> end
            default: shouldRemap = NO; break;
        }
        
        if (shouldRemap) {
            static CGEventSourceRef source = NULL;
            if (!source) {
                source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
            }
            
            if (source) {
                CGEventRef newEvent = CGEventCreateKeyboardEvent(source, newKeycode, true);
                CGEventSetFlags(newEvent, flags);
                CGEventSetIntegerValueField(newEvent, kCGKeyboardEventAutorepeat, 
                    CGEventGetIntegerValueField(event, kCGKeyboardEventAutorepeat));
                CGEventPost(kCGHIDEventTap, newEvent);
                CFRelease(newEvent);
                return YES;
            }
        }
    } else if ((vimModeActive || vimModeLocked) && type == kCGEventKeyUp) {
        // Handle key up events for vim navigation keys
        CGKeyCode newKeycode = 0;
        BOOL shouldRemap = YES;
        
        switch (keycode) {
            case 4:  newKeycode = 123; break; // h -> left
            case 38: newKeycode = 125; break; // j -> down
            case 40: newKeycode = 126; break; // k -> up
            case 37: newKeycode = 124; break; // l -> right
            case 34: newKeycode = 116; break; // i -> page up
            case 31: newKeycode = 121; break; // o -> page down
            case 43: newKeycode = 115; break; // , -> home
            case 47: newKeycode = 119; break; // . -> end
            default: shouldRemap = NO; break;
        }
        
        if (shouldRemap) {
            static CGEventSourceRef source = NULL;
            if (!source) {
                source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
            }
            
            if (source) {
                CGEventRef newEvent = CGEventCreateKeyboardEvent(source, newKeycode, false);
                CGEventSetFlags(newEvent, flags);
                CGEventPost(kCGHIDEventTap, newEvent);
                CFRelease(newEvent);
                return YES;
            }
        }
    }

    // Handle mode locking shortcuts
    if (keycode == 18 && type == kCGEventKeyDown) { // 1 key pressed
        // Check if escape is held using raw keyboard state
        if (CGEventSourceKeyState(kCGEventSourceStateHIDSystemState, 53)) { // If escape is held
            vimModeLocked = YES;
            vimModeActive = YES;
            [self updateStatusWithMode:'N'];
            return YES;
        }
    }

    if (capsKeyDown && keycode == 45 && type == kCGEventKeyDown) { // CapsLock + N
        vimModeLocked = YES;
        vimModeActive = YES;
        [self updateStatusWithMode:'N'];
        return YES;
    }

    // Handle Escape + Equal shortcut for key display
    if (keycode == 24 && type == kCGEventKeyDown) {  // Equal key (=)
        if (CGEventSourceKeyState(kCGEventSourceStateHIDSystemState, 53)) {  // Escape key
            [self toggleKeyDisplay];
            return YES;
        }
    }

    return NO;
}

@end