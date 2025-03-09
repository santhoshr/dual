#import "DualKeyboard.h"

@interface DualKeyboardManager (KeyboardStatus)
- (void)setupStatusBar;
- (void)updateStatusWithMode:(char)mode;
- (void)cleanupStatusBar;
@end