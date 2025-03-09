#import "DualKeyboardManager+KeyboardStatus.h"
#import "DualKeyboardManager+MenuBar.h"

@implementation DualKeyboardManager (KeyboardStatus)

- (void)setupStatusBar {
    if (self.quietMode) return;
    printf("\033[1;36mDual Keyboard Start\033[0m\n");
    printf("Current Mode: \033[1;32m%c\033[0m | Debug: \033[1;33m%s\033[0m\n", 
           self.currentMode, self.debugMode ? "ON" : "OFF");
    fflush(stdout);
}

- (void)updateStatusWithMode:(char)mode {
    if (mode != 'I' && mode != 'N') return;
    if (mode == self.currentMode) return;
    
    self.currentMode = mode;
    [self updateMenuBarStatus];  // Update menubar when mode changes
    
    if (!self.quietMode) {
        printf("\033[1;33mMode Changed\033[0m -> Current: \033[1;32m%c\033[0m | Debug: \033[1;33m%s\033[0m\n",
               self.currentMode, self.debugMode ? "ON" : "OFF");
        fflush(stdout);
    }
}

- (void)cleanupStatusBar {
    if (self.quietMode) return;
    printf("\n\033[1;31mDual Keyboard Exit\033[0m\n");
    printf("Final Mode: \033[1;32m%c\033[0m | Debug: \033[1;33m%s\033[0m\n",
           self.currentMode, self.debugMode ? "ON" : "OFF");
    fflush(stdout);
}

@end