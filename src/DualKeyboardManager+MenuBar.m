#import "DualKeyboardManager+MenuBar.h"
#import "DualKeyboardManager+KeyboardMapping.h"
#import "DualKeyboardManager+ConsoleWindow.h"
#import "DualKeyboardManager+About.h"
#import "NSApplication+CommandLine.h"
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

@interface ANSITextView : NSTextView
@property (nonatomic, strong) NSRegularExpression *ansiRegex;
@property (nonatomic, strong) NSDictionary *ansiColors;
@end

@implementation ANSITextView

- (instancetype)initWithFrame:(NSRect)frame {
    if (self = [super initWithFrame:frame]) {
        // ANSI color escape sequence regex
        NSString *pattern = @"\033\\[(\\d+);?(\\d+)?m([^\033]+)";
        self.ansiRegex = [NSRegularExpression regularExpressionWithPattern:pattern 
                                                                 options:0 
                                                                   error:nil];
        
        // ANSI color mappings
        self.ansiColors = @{
            @"30": [NSColor blackColor],
            @"31": [NSColor redColor],
            @"32": [NSColor greenColor],
            @"33": [NSColor yellowColor],
            @"34": [NSColor blueColor],
            @"35": [NSColor magentaColor],
            @"36": [NSColor cyanColor],
            @"37": [NSColor whiteColor],
            @"1": [NSColor whiteColor], // Bold
        };
    }
    return self;
}

- (void)appendANSIString:(NSString *)string {
    if (!string.length) return;
    
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] init];
    NSArray *matches = [self.ansiRegex matchesInString:string 
                                             options:0 
                                               range:NSMakeRange(0, string.length)];
    
    NSUInteger lastIndex = 0;
    for (NSTextCheckingResult *match in matches) {
        // Add any text before the ANSI sequence
        NSRange prefixRange = NSMakeRange(lastIndex, match.range.location - lastIndex);
        if (prefixRange.length > 0) {
            NSString *plainText = [string substringWithRange:prefixRange];
            [attrString appendAttributedString:[[NSAttributedString alloc] 
                                              initWithString:plainText]];
        }
        
        // Extract color code and text
        NSString *code = [string substringWithRange:[match rangeAtIndex:1]];
        NSString *text = [string substringWithRange:[match rangeAtIndex:3]];
        
        // Create attributed string with color
        NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
        NSColor *color = self.ansiColors[code];
        if (color) {
            attrs[NSForegroundColorAttributeName] = color;
        }
        
        // Add bold if code is 1
        if ([code isEqualToString:@"1"]) {
            attrs[NSFontAttributeName] = [NSFont boldSystemFontOfSize:self.font.pointSize];
        }
        
        NSAttributedString *coloredText = [[NSAttributedString alloc] 
                                         initWithString:text 
                                         attributes:attrs];
        [attrString appendAttributedString:coloredText];
        
        lastIndex = match.range.location + match.range.length;
    }
    
    // Add any remaining text
    if (lastIndex < string.length) {
        NSString *remainingText = [string substringFromIndex:lastIndex];
        [attrString appendAttributedString:[[NSAttributedString alloc] 
                                          initWithString:remainingText]];
    }
    
    // Append to text storage
    [[self textStorage] appendAttributedString:attrString];
    [self scrollRangeToVisible:NSMakeRange([self string].length, 0)];
}

@end

@interface DualWindowDelegate : NSObject <NSWindowDelegate>
@property (weak) DualKeyboardManager *manager;
@end

@implementation DualWindowDelegate

- (BOOL)windowShouldClose:(NSWindow *)sender {
    [self.manager toggleDebugMode];
    return NO;
}

@end

@implementation DualKeyboardManager (MenuBar)

static char consoleWindowPipeKey;
static char originalStdoutKey;
static char originalStdoutFdKey;

- (void)setConsolePipe:(NSPipe *)pipe {
    objc_setAssociatedObject(self, &consoleWindowPipeKey, pipe, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSPipe *)consolePipe {
    return objc_getAssociatedObject(self, &consoleWindowPipeKey);
}

- (void)setOriginalStdout:(NSFileHandle *)fileHandle {
    objc_setAssociatedObject(self, &originalStdoutKey, fileHandle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSFileHandle *)originalStdout {
    return objc_getAssociatedObject(self, &originalStdoutKey);
}

- (void)setOriginalStdoutFd:(int)fd {
    objc_setAssociatedObject(self, &originalStdoutFdKey, @(fd), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (int)originalStdoutFd {
    NSNumber *fd = objc_getAssociatedObject(self, &originalStdoutFdKey);
    return fd ? [fd intValue] : -1;
}

- (void)setupMenuBar {
    // Ensure proper activation policy is set at startup
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"⌨️ I";
    
    self.statusMenu = [[NSMenu alloc] init];
    
    // Create mode menu item with a fixed tag for easy lookup
    NSMenuItem *modeItem = [[NSMenuItem alloc] initWithTitle:@"Mode: Insert" 
                                                     action:nil 
                                              keyEquivalent:@""];
    modeItem.tag = 1001;
    [self.statusMenu addItem:modeItem];
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // Create debug menu item without checking debugMode
    NSMenuItem *debugItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Debug: %@", 
                                                              self.debugMode ? @"ON" : @"OFF"] 
                                                     action:@selector(toggleDebugMode) 
                                              keyEquivalent:@""];
    debugItem.tag = 1002;
    [debugItem setTarget:self];
    [self.statusMenu addItem:debugItem];
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // Add Key Display menu item
    NSMenuItem *keyDisplayItem = [[NSMenuItem alloc] initWithTitle:@"Show Key Display" 
                                                          action:@selector(toggleKeyDisplay) 
                                                   keyEquivalent:@"="];
    keyDisplayItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    keyDisplayItem.tag = 1004;
    [keyDisplayItem setTarget:self];
    [self.statusMenu addItem:keyDisplayItem];
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // Add About menu item with proper target retention
    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:@"About DualKeyboard" 
                                                     action:@selector(showAboutWindow) 
                                              keyEquivalent:@"i"];
    aboutItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    aboutItem.tag = 1005;
    
    // Important: Create the about window upfront
    [self createAboutWindowIfNeeded];
    
    // Set target after window is created
    [aboutItem setTarget:self];
    [self.statusMenu addItem:aboutItem];
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *exitItem = [[NSMenuItem alloc] initWithTitle:@"Exit" 
                                                    action:@selector(exitApplication) 
                                             keyEquivalent:@""];
    exitItem.tag = 1003;
    [exitItem setTarget:self];
    [self.statusMenu addItem:exitItem];
    
    self.statusItem.menu = self.statusMenu;
    
    // Initial update
    [self updateMenuBarStatus];
}

- (void)updateMenuBarStatus {
    if (!self.statusItem) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Ensure proper activation policy whenever menu updates
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        
        // Update menu bar icon
        NSString *modeTitle = [NSString stringWithFormat:@"⌨️ %c", self.currentMode];
        self.statusItem.button.title = modeTitle;
        
        // Update mode menu item
        NSMenuItem *modeItem = [self.statusMenu itemWithTag:1001];
        if (modeItem) {
            modeItem.title = [NSString stringWithFormat:@"Mode: %@", 
                             self.currentMode == 'I' ? @"Insert" : @"Navigation"];
        }
        
        // Update debug menu item if it exists
        NSMenuItem *debugItem = [self.statusMenu itemWithTag:1002];
        if (debugItem) {
            debugItem.title = [NSString stringWithFormat:@"Debug: %@", 
                             self.debugMode ? @"ON" : @"OFF"];
        }
        
        // Ensure exit item remains unchanged
        NSMenuItem *exitItem = [self.statusMenu itemWithTag:1003];
        if (exitItem) {
            exitItem.title = @"Exit";
            exitItem.action = @selector(exitApplication);
            exitItem.target = self;
        }
    });
}

- (void)toggleDebugMode {
    BOOL wasDebugEnabled = self.debugMode;
    self.debugMode = !self.debugMode;
    
    if (self.debugMode && ![NSApp isRunningFromCommandLine]) {
        [self createConsoleWindowIfNeeded];
    } else if (!self.debugMode && wasDebugEnabled) {
        [self closeConsoleWindow];
    }
    
    [self updateMenuBarStatus];
    
    NSString *debugMsg = [NSString stringWithFormat:@"\nDebug messages %s\n", 
                         self.debugMode ? "enabled" : "disabled"];
    
    if ([NSApp isRunningFromCommandLine]) {
        printf("%s", [debugMsg UTF8String]);
    } else if (self.debugMode) {
        [self appendToConsole:debugMsg];
    }
}

- (void)exitApplication {
    [self closeConsoleWindow];
    [self cleanup];
    exit(0);
}

@end