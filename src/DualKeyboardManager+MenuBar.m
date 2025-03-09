#import "DualKeyboardManager+MenuBar.h"
#import "DualKeyboardManager+KeyboardMapping.h"
#import <AppKit/AppKit.h>

@implementation DualKeyboardManager (MenuBar)

- (void)setupMenuBar {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"⌨️ I";
    
    self.statusMenu = [[NSMenu alloc] init];
    [self.statusMenu addItemWithTitle:@"Mode: Insert" action:nil keyEquivalent:@""];
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    if (!self.quietMode) {
        NSMenuItem *debugItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Debug: %@", self.debugMode ? @"ON" : @"OFF"] 
                                                          action:@selector(toggleDebugMode) 
                                                   keyEquivalent:@""];
        [debugItem setTarget:self];
        [self.statusMenu addItem:debugItem];
        [self.statusMenu addItem:[NSMenuItem separatorItem]];
    }
    
    NSMenuItem *exitItem = [[NSMenuItem alloc] initWithTitle:@"Exit" 
                                                     action:@selector(exitApplication) 
                                              keyEquivalent:@""];
    [exitItem setTarget:self];
    [self.statusMenu addItem:exitItem];
    
    self.statusItem.menu = self.statusMenu;
}

- (void)updateMenuBarStatus {
    if (!self.statusItem) return;
    
    NSString *modeTitle = [NSString stringWithFormat:@"⌨️ %c", self.currentMode];
    self.statusItem.button.title = modeTitle;
    
    NSMenuItem *modeItem = [self.statusMenu itemAtIndex:0];
    modeItem.title = [NSString stringWithFormat:@"Mode: %@", 
                      self.currentMode == 'I' ? @"Insert" : @"Navigation"];
    
    if (!self.quietMode) {
        NSMenuItem *debugItem = [self.statusMenu itemAtIndex:2];
        debugItem.title = [NSString stringWithFormat:@"Debug: %@", 
                          self.debugMode ? @"ON" : @"OFF"];
    }
}

- (void)toggleDebugMode {
    self.debugMode = !self.debugMode;
    [self updateMenuBarStatus];
    
    if (!self.quietMode) {
        printf("\nDebug messages %s\n", self.debugMode ? "enabled" : "disabled");
        fflush(stdout);
    }
}

- (void)exitApplication {
    [self cleanup];
    exit(0);
}

@end