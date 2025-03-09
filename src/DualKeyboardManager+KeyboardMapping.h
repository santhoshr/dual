#import "DualKeyboard.h"

@interface DualKeyboardManager (KeyboardMapping)
- (void)setupCapsLockRemapping;
- (void)restoreCapsLockMapping;
- (void)sendEscapeKey;
- (BOOL)handleKeyEvent:(CGEventRef)event ofType:(CGEventType)type withKeycode:(CGKeyCode)keycode;
- (void)restartApplication;
@end