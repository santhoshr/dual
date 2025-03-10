#import "DualKeyboardManager+KeyboardMapping.h"
#import "DualKeyboardManager+CapsNavigation.h"
#import "DualKeyboardManager+MenuBar.h"
#import "DualKeyboardManager+KeyDisplay.h"
#import "DualKeyboardManager+ConsoleWindow.h"
#import "NSApplication+CommandLine.h"
#import <mach/mach_time.h>

// Key tracking for shortcuts
static BOOL escapePressed = NO;
static BOOL controlPressed = NO;
static BOOL spacePressed = NO;
static BOOL zeroPressed = NO;
static BOOL minusPressed = NO;

// Modifier key states - removed static keyword to match extern declarations
BOOL leftShiftDown = NO;
BOOL rightShiftDown = NO;
BOOL leftControlDown = NO;
BOOL rightControlDown = NO;
BOOL leftCommandDown = NO;
BOOL rightCommandDown = NO;
BOOL leftOptionDown = NO;
BOOL rightOptionDown = NO;

@implementation DualKeyboardManager (KeyboardMapping)

- (CGEventFlags)computeCombinedModifierFlags {
    CGEventFlags combinedFlags = 0;
    if (leftShiftDown || rightShiftDown) combinedFlags |= kCGEventFlagMaskShift;
    if (leftControlDown || rightControlDown) combinedFlags |= kCGEventFlagMaskControl;
    if (leftOptionDown || rightOptionDown) combinedFlags |= kCGEventFlagMaskAlternate;
    if (leftCommandDown || rightCommandDown) combinedFlags |= kCGEventFlagMaskCommand;
    return combinedFlags;
}

// Centralized method to notify all UI elements about modifier changes
- (void)notifyModifierChanges:(CGKeyCode)keycode flags:(CGEventFlags)flags modifierChanged:(BOOL)modifierChanged {
    // Update control pressed state for shortcuts
    controlPressed = leftControlDown || rightControlDown;
    
    // Log modifier changes explicitly for debug purposes
    if (self.debugMode && modifierChanged) {
        NSString *modifierName = @"unknown";
        NSString *modifierState = @"unknown";
        
        switch (keycode) {
            case 56: modifierName = @"Left Shift"; modifierState = leftShiftDown ? @"DOWN" : @"UP"; break;
            case 60: modifierName = @"Right Shift"; modifierState = rightShiftDown ? @"DOWN" : @"UP"; break;
            case 59: modifierName = @"Left Control"; modifierState = leftControlDown ? @"DOWN" : @"UP"; break;
            case 62: modifierName = @"Right Control"; modifierState = rightControlDown ? @"DOWN" : @"UP"; break;
            case 58: modifierName = @"Left Option"; modifierState = leftOptionDown ? @"DOWN" : @"UP"; break;
            case 61: modifierName = @"Right Option"; modifierState = rightOptionDown ? @"DOWN" : @"UP"; break;
            case 55: modifierName = @"Left Command"; modifierState = leftCommandDown ? @"DOWN" : @"UP"; break;
            case 54: modifierName = @"Right Command"; modifierState = rightCommandDown ? @"DOWN" : @"UP"; break;
        }
        
        NSString *debugMsg = [NSString stringWithFormat:@"Modifier: %@ is %@ [cmd:%d ctrl:%d opt:%d shift:%d]\n",
                           modifierName, modifierState,
                           (leftCommandDown || rightCommandDown) ? 1 : 0,
                           (leftControlDown || rightControlDown) ? 1 : 0,
                           (leftOptionDown || rightOptionDown) ? 1 : 0,
                           (leftShiftDown || rightShiftDown) ? 1 : 0];
        
        if ([NSApp isRunningFromCommandLine]) {
            printf("%s", [debugMsg UTF8String]);
            fflush(stdout);
        } else {
            [self appendToConsole:debugMsg];
        }
    }
    
    // Update key display with current modifiers state for immediate feedback
    if (modifierChanged) {
        [self updateKeyDisplay:keycode flags:flags isKeyDown:YES];
        // Also refresh the key display modifiers to ensure it's fully up to date
        [self refreshKeyDisplayModifiers];
    }
}

- (void)restartApplication {
    NSString *executablePath = [[NSBundle mainBundle] executablePath];
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = executablePath;
    
    NSMutableArray *args = [NSMutableArray array];
    if (self.debugMode) [args addObject:@"-d"];
    task.arguments = args;
    
    [task launch];
}

- (BOOL)handleKeyEvent:(CGEventRef)event ofType:(CGEventType)type withKeycode:(CGKeyCode)keycode {
    CGEventFlags flags = CGEventGetFlags(event);
    BOOL needsUpdate = NO;
    BOOL modifierChanged = NO;
    
    // Handle caps navigation first
    if ([self handleCapsNavigation:event ofType:type withKeycode:keycode flags:flags]) {
        return YES;
    }
    
    // Handle modifier keys - always check current state for immediate updates
    if (type == kCGEventFlagsChanged) {
        // Track individual modifier keys
        switch (keycode) {
            case 56:  // Left shift
                if (leftShiftDown != ((flags & kCGEventFlagMaskShift) != 0)) {
                    leftShiftDown = (flags & kCGEventFlagMaskShift) != 0;
                    needsUpdate = YES;
                    modifierChanged = YES;
                }
                break;
            case 60:  // Right shift
                if (rightShiftDown != ((flags & kCGEventFlagMaskShift) != 0)) {
                    rightShiftDown = (flags & kCGEventFlagMaskShift) != 0;
                    needsUpdate = YES;
                    modifierChanged = YES;
                }
                break;
            case 59:  // Left control
                if (leftControlDown != ((flags & kCGEventFlagMaskControl) != 0)) {
                    leftControlDown = (flags & kCGEventFlagMaskControl) != 0;
                    needsUpdate = YES;
                    modifierChanged = YES;
                }
                break;
            case 62:  // Right control
                if (rightControlDown != ((flags & kCGEventFlagMaskControl) != 0)) {
                    rightControlDown = (flags & kCGEventFlagMaskControl) != 0;
                    needsUpdate = YES;
                    modifierChanged = YES;
                }
                break;
            case 58:  // Left option
                if (leftOptionDown != ((flags & kCGEventFlagMaskAlternate) != 0)) {
                    leftOptionDown = (flags & kCGEventFlagMaskAlternate) != 0;
                    needsUpdate = YES;
                    modifierChanged = YES;
                }
                break;
            case 61:  // Right option
                if (rightOptionDown != ((flags & kCGEventFlagMaskAlternate) != 0)) {
                    rightOptionDown = (flags & kCGEventFlagMaskAlternate) != 0;
                    needsUpdate = YES;
                    modifierChanged = YES;
                }
                break;
            case 55:  // Left command
                if (leftCommandDown != ((flags & kCGEventFlagMaskCommand) != 0)) {
                    leftCommandDown = (flags & kCGEventFlagMaskCommand) != 0;
                    needsUpdate = YES;
                    modifierChanged = YES;
                }
                break;
            case 54:  // Right command
                if (rightCommandDown != ((flags & kCGEventFlagMaskCommand) != 0)) {
                    rightCommandDown = (flags & kCGEventFlagMaskCommand) != 0;
                    needsUpdate = YES;
                    modifierChanged = YES;
                }
                break;
        }
        
        // Use centralized method to compute combined flags
        CGEventFlags newFlags = [self computeCombinedModifierFlags];
        
        // Use centralized method to notify UI elements
        if (needsUpdate) {
            [self notifyModifierChanges:keycode flags:flags modifierChanged:modifierChanged];
        }
        
        CGEventSetFlags(event, newFlags);
        return NO;
    }
    
    // For normal key events, apply combined modifier states
    if (type == kCGEventKeyDown || type == kCGEventKeyUp) {
        // Use centralized method to compute combined flags
        CGEventFlags newFlags = [self computeCombinedModifierFlags];
        CGEventSetFlags(event, newFlags);
    }

    // Handle Escape key
    if (keycode == 53) {
        if (type == kCGEventKeyDown && !escapePressed) {
            escapePressed = YES;
        } else if (type == kCGEventKeyUp) {
            escapePressed = NO;
        }
    }

    // Handle Control key for shortcuts
    if (keycode == 59 || keycode == 62) {
        if (type == kCGEventKeyDown) {
            controlPressed = YES;
        } else if (type == kCGEventKeyUp) {
            controlPressed = NO;
        }
    }

    // Handle Space key
    if (keycode == 49) {
        if (type == kCGEventKeyDown) {
            spacePressed = YES;
        } else if (type == kCGEventKeyUp) {
            spacePressed = NO;
        }
    }

    // Handle Zero key for restart shortcut
    if (keycode == 29) {
        if (type == kCGEventKeyDown) {
            zeroPressed = YES;
            if (escapePressed) {
                if (self.debugMode) {
                    NSLog(@"Restart key combination detected");
                }
                [self cleanup];
                [self restartApplication];
                exit(0);
            }
        } else if (type == kCGEventKeyUp) {
            zeroPressed = NO;
        }
    }

    // Handle Minus key for debug toggle
    if (keycode == 27) {
        if (type == kCGEventKeyDown) {
            minusPressed = YES;
            if (escapePressed) {
                [self toggleDebugMode];
                return YES;
            }
        } else if (type == kCGEventKeyUp) {
            minusPressed = NO;
        }
    }

    // Check for exit combination
    if (escapePressed && controlPressed && spacePressed) {
        if (self.debugMode) {
            NSLog(@"Exit key combination detected");
        }
        [self cleanup];
        exit(0);
    }

    return NO;
}

@end
