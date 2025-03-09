#import "DualKeyboardManager+KeyboardMapping.h"
#import <mach/mach_time.h>

// Key state tracking
static BOOL vimModeActive = NO;
static BOOL vimModeLocked = NO;
static BOOL capsKeyDown = NO;
static uint64_t capsKeyPressTime = 0;
static BOOL keyRepeat = NO;

// Key tracking for shortcuts
static BOOL escapePressed = NO;
static BOOL controlPressed = NO;
static BOOL spacePressed = NO;
static BOOL zeroPressed = NO;
static BOOL minusPressed = NO;

// Modifier states
static BOOL ctr = NO;
static BOOL sft = NO;
static BOOL cmd = NO;
static BOOL opt = NO;

// Constants
static const uint64_t HOLD_THRESHOLD = 150000000ULL; // 150ms in nanoseconds

@implementation DualKeyboardManager (KeyboardMapping)

- (void)setupCapsLockRemapping {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/hidutil";
    task.arguments = @[@"property", @"--set", @"{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":0x700000039,\"HIDKeyboardModifierMappingDst\":0x700000064}]}"];
    [task launch];
    [task waitUntilExit];
    
    if (self.debugMode) {
        NSLog(@"CapsLock remapping applied successfully");
    }
}

- (void)restoreCapsLockMapping {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/hidutil";
    task.arguments = @[@"property", @"--set", @"{\"UserKeyMapping\":[]}"];
    [task launch];
    [task waitUntilExit];
    
    if (self.debugMode) {
        NSLog(@"Original keyboard mapping restored");
    }
}

- (void)sendEscapeKey {
    if (self.debugMode) {
        NSLog(@"Sending Escape key");
    }
    
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

- (void)restartApplication {
    NSString *executablePath = [[NSBundle mainBundle] executablePath];
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = executablePath;
    
    NSMutableArray *args = [NSMutableArray array];
    if (self.debugMode) [args addObject:@"-d"];
    if (self.quietMode) [args addObject:@"-q"];
    task.arguments = args;
    
    [task launch];
}

- (BOOL)handleKeyEvent:(CGEventRef)event ofType:(CGEventType)type withKeycode:(CGKeyCode)keycode {
    CGEventFlags flags = CGEventGetFlags(event);
    
    // Handle Escape key
    if (keycode == 53) {
        if (type == kCGEventKeyDown) {
            escapePressed = YES;
            // Exit navigation mode with Escape unless part of a shortcut
            if ((vimModeActive || vimModeLocked) && !zeroPressed && !controlPressed && !spacePressed && !minusPressed) {
                vimModeActive = NO;
                vimModeLocked = NO;
                [self updateStatusWithMode:'I'];
                return YES;
            }
        } else if (type == kCGEventKeyUp) {
            escapePressed = NO;
        }
    }
    
    // Handle shortcuts
    if (type == kCGEventKeyDown) {
        switch (keycode) {
            case 49: // Space
                spacePressed = YES;
                break;
            case 29: // 0
                zeroPressed = YES;
                break;
            case 27: // -
                minusPressed = YES;
                break;
            case 18: // 1 key
                if (escapePressed) {
                    vimModeLocked = YES;
                    vimModeActive = YES;
                    [self updateStatusWithMode:'N'];
                    return YES;
                }
                break;
            case 45: // N key
                if (capsKeyDown) {
                    vimModeLocked = YES;
                    vimModeActive = YES;
                    [self updateStatusWithMode:'N'];
                    return YES;
                }
                break;
        }
        
        // Check for exit combination
        if (escapePressed && controlPressed && spacePressed) {
            if (self.debugMode) {
                NSLog(@"Exit key combination detected");
            }
            [self cleanup];
            exit(0);
        }
        
        // Check for restart combination
        if (escapePressed && zeroPressed) {
            if (self.debugMode) {
                NSLog(@"Restart key combination detected");
            }
            [self cleanup];
            [self restartApplication];
            exit(0);
        }
        
        // Check for debug toggle
        if (escapePressed && minusPressed && !self.quietMode) {
            self.debugMode = !self.debugMode;
            printf("\nDebug messages %s\n", self.debugMode ? "enabled" : "disabled");
            return YES;
        }
    }
    
    // Handle CapsLock (Section key)
    if (keycode == 10) {
        uint64_t currentTime = mach_absolute_time();
        
        if (type == kCGEventKeyDown) {
            BOOL isRepeat = (flags & kCGEventFlagMaskNonCoalesced) == 0;
            
            if (!capsKeyDown) {
                capsKeyDown = YES;
                capsKeyPressTime = currentTime;
                keyRepeat = NO;
                
                if (self.debugMode) {
                    NSLog(@"CapsLock pressed");
                }
            } else if (isRepeat) {
                keyRepeat = YES;
                uint64_t holdDuration = currentTime - capsKeyPressTime;
                
                // Enter navigation mode if held long enough
                if (!vimModeActive && !vimModeLocked && holdDuration >= HOLD_THRESHOLD) {
                    vimModeActive = YES;
                    [self updateStatusWithMode:'N'];
                }
            }
            return YES;
        } else if (type == kCGEventKeyUp) {
            if (!capsKeyDown) return YES;
            
            uint64_t holdDuration = currentTime - capsKeyPressTime;
            capsKeyDown = NO;
            keyRepeat = NO;
            
            if (!vimModeLocked) {
                if (holdDuration < HOLD_THRESHOLD) {
                    if (!vimModeActive) {
                        [self sendEscapeKey];
                    }
                } else if (vimModeActive) {
                    vimModeActive = NO;
                    [self updateStatusWithMode:'I'];
                }
            }
            return YES;
        }
        return YES;
    }
    
    // Handle vim navigation mode
    if ((capsKeyDown || vimModeLocked) && type == kCGEventKeyDown) {
        BOOL shouldProcessVimKeys = vimModeLocked;
        
        if (!shouldProcessVimKeys && capsKeyDown) {
            uint64_t currentTime = mach_absolute_time();
            uint64_t holdDuration = currentTime - capsKeyPressTime;
            shouldProcessVimKeys = (holdDuration >= HOLD_THRESHOLD);
            
            if (shouldProcessVimKeys && !vimModeActive) {
                vimModeActive = YES;
                [self updateStatusWithMode:'N'];
            }
        }
        
        if (shouldProcessVimKeys) {
            // Handle Shift+I to exit vim mode when locked
            if (keycode == 34 && (flags & kCGEventFlagMaskShift)) {
                vimModeLocked = NO;
                vimModeActive = NO;
                [self updateStatusWithMode:'I'];
                return YES;
            }
            
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
                CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
                if (source) {
                    CGEventRef newEvent = CGEventCreateKeyboardEvent(source, newKeycode, true);
                    CGEventSetFlags(newEvent, flags);
                    CGEventPost(kCGHIDEventTap, newEvent);
                    CFRelease(newEvent);
                    CFRelease(source);
                    return YES;
                }
            }
        }
    }
    
    // Handle modifier keys
    if (type == kCGEventFlagsChanged || type == kCGEventKeyDown || type == kCGEventKeyUp) {
        BOOL updateFlags = NO;
        
        switch (keycode) {
            case 59: // Left Control
            case 62: // Right Control
                controlPressed = (type == kCGEventKeyDown);
                ctr = ((flags & NX_CONTROLMASK) != 0);
                updateFlags = YES;
                break;
            case 56: // Left Shift
            case 60: // Right Shift
                sft = ((flags & NX_SHIFTMASK) != 0);
                updateFlags = YES;
                break;
            case 55: // Command
            case 54: // Right Command
                cmd = ((flags & NX_COMMANDMASK) != 0);
                updateFlags = YES;
                break;
            case 58: // Left Option
            case 61: // Right Option
                opt = ((flags & NX_ALTERNATEMASK) != 0);
                updateFlags = YES;
                break;
        }
        
        if (updateFlags) {
            CGEventFlags newFlags = 0;
            if (ctr) newFlags |= NX_CONTROLMASK;
            if (sft) newFlags |= NX_SHIFTMASK;
            if (cmd) newFlags |= NX_COMMANDMASK;
            if (opt) newFlags |= NX_ALTERNATEMASK;
            
            CGEventSetFlags(event, newFlags | (flags & ~(NX_CONTROLMASK | NX_SHIFTMASK | NX_COMMANDMASK | NX_ALTERNATEMASK)));
        }
    }
    
    return NO;
}

@end