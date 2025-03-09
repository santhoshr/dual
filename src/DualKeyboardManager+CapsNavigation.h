#import "DualKeyboard.h"

@interface DualKeyboardManager (CapsNavigation)

- (void)setupCapsLockRemapping;
- (void)restoreCapsLockMapping;
- (BOOL)handleCapsNavigation:(CGEventRef)event ofType:(CGEventType)type withKeycode:(CGKeyCode)keycode flags:(CGEventFlags)flags;

@end