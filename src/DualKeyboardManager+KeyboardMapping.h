#import "DualKeyboard.h"
#import "DualKeyboardManager+KeyboardStatus.h"

@interface DualKeyboardManager (KeyboardMapping)
- (BOOL)handleKeyEvent:(CGEventRef)event ofType:(CGEventType)type withKeycode:(CGKeyCode)keycode;
- (void)restartApplication;
@end