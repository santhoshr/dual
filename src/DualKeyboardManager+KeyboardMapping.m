#import "DualKeyboardManager+KeyboardMapping.h"
#import "DualKeyboardManager+CapsNavigation.h"
#import <mach/mach_time.h>

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

@implementation DualKeyboardManager (KeyboardMapping)

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
    
    // Handle caps navigation first
    if ([self handleCapsNavigation:event ofType:type withKeycode:keycode flags:flags]) {
        return YES;
    }
    
    // Handle modifier keys 
    if (type == kCGEventFlagsChanged) {
        // Preserve non-modifier flags
        CGEventFlags preservedFlags = flags & ~(kCGEventFlagMaskControl | kCGEventFlagMaskShift | 
                                              kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate);
        
        // Update modifier states based on current flags
        ctr = ((flags & kCGEventFlagMaskControl) != 0);
        sft = ((flags & kCGEventFlagMaskShift) != 0);
        cmd = ((flags & kCGEventFlagMaskCommand) != 0);
        opt = ((flags & kCGEventFlagMaskAlternate) != 0);
        
        // Update control pressed state for shortcuts
        controlPressed = ctr;
        
        // Build new flags
        CGEventFlags newFlags = preservedFlags;
        if (ctr) newFlags |= kCGEventFlagMaskControl;
        if (sft) newFlags |= kCGEventFlagMaskShift;
        if (cmd) newFlags |= kCGEventFlagMaskCommand;
        if (opt) newFlags |= kCGEventFlagMaskAlternate;
        
        CGEventSetFlags(event, newFlags);
        
        if (self.debugMode) {
            NSLog(@"Modifier flags changed - ctrl:%d shift:%d cmd:%d opt:%d", ctr, sft, cmd, opt);
        }
        
        return NO;
    }
    
    // For normal key events, apply current modifier states
    if (type == kCGEventKeyDown || type == kCGEventKeyUp) {
        CGEventFlags preservedFlags = flags & ~(kCGEventFlagMaskControl | kCGEventFlagMaskShift | 
                                              kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate);
        CGEventFlags newFlags = preservedFlags;
        if (ctr) newFlags |= kCGEventFlagMaskControl;
        if (sft) newFlags |= kCGEventFlagMaskShift;
        if (cmd) newFlags |= kCGEventFlagMaskCommand;
        if (opt) newFlags |= kCGEventFlagMaskAlternate;
        
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
            if (escapePressed && !self.quietMode) {
                self.debugMode = !self.debugMode;
                printf("\nDebug messages %s\n", self.debugMode ? "enabled" : "disabled");
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