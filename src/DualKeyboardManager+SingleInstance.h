#import "DualKeyboard.h"

@interface DualKeyboardManager (SingleInstance)

- (BOOL)ensureSingleInstance;
- (void)cleanupSingleInstance;

@end