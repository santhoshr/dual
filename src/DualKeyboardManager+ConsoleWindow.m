#import "DualKeyboardManager+ConsoleWindow.h"
#import "DualKeyboardManager+MenuBar.h"
#import <objc/runtime.h>

@interface ConsoleWindowDelegate : NSObject <NSWindowDelegate>
@property (weak) DualKeyboardManager *manager;
@end

@implementation ConsoleWindowDelegate
- (BOOL)windowShouldClose:(NSWindow *)sender {
    if ([self.manager respondsToSelector:@selector(toggleDebugMode)]) {
        [self.manager toggleDebugMode];
    }
    return NO;
}
@end

@implementation DualKeyboardManager (ConsoleWindow)

static char consoleTextViewKey;
static char consoleWindowPipeKey;
static char originalStdoutKey;
static char originalStdoutFdKey;

- (NSTextView *)consoleTextView {
    return objc_getAssociatedObject(self, &consoleTextViewKey);
}

- (void)setConsoleTextView:(NSTextView *)textView {
    objc_setAssociatedObject(self, &consoleTextViewKey, textView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSPipe *)consolePipe {
    return objc_getAssociatedObject(self, &consoleWindowPipeKey);
}

- (void)setConsolePipe:(NSPipe *)pipe {
    objc_setAssociatedObject(self, &consoleWindowPipeKey, pipe, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSFileHandle *)originalStdout {
    return objc_getAssociatedObject(self, &originalStdoutKey);
}

- (void)setOriginalStdout:(NSFileHandle *)fileHandle {
    objc_setAssociatedObject(self, &originalStdoutKey, fileHandle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (int)originalStdoutFd {
    NSNumber *fd = objc_getAssociatedObject(self, &originalStdoutFdKey);
    return fd ? [fd intValue] : -1;
}

- (void)setOriginalStdoutFd:(int)fd {
    objc_setAssociatedObject(self, &originalStdoutFdKey, @(fd), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)createConsoleWindowIfNeeded {
    NSLog(@"Creating Console window if needed");
    if (self.consoleWindow != nil) return;
    
    // Create window first
    self.consoleWindow = [[NSWindow alloc] 
                         initWithContentRect:NSMakeRect(0, 0, 800, 500)
                         styleMask:NSWindowStyleMaskTitled | 
                                 NSWindowStyleMaskResizable | 
                                 NSWindowStyleMaskMiniaturizable
                         backing:NSBackingStoreBuffered
                         defer:NO];
    
    // Default to floating window level (always on top)
    self.consoleWindow.level = NSFloatingWindowLevel;
    
    self.consoleWindow.title = @"Dual Keyboard Debug Console";
    self.consoleWindow.backgroundColor = [NSColor whiteColor];
    
    // Create text view and scroll view
    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSZeroRect];
    textView.editable = NO;
    textView.backgroundColor = [NSColor whiteColor];
    textView.textColor = [NSColor blackColor];
    textView.font = [NSFont fontWithName:@"Menlo" size:12];
    self.consoleTextView = textView;
    
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scrollView.documentView = textView;
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = NO;
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    self.consoleWindow.contentView = scrollView;
    
    // Set up pin button with initial state
    NSTitlebarAccessoryViewController *accessoryController = [[NSTitlebarAccessoryViewController alloc] init];
    NSButton *pinButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 30, 24)];
    pinButton.bezelStyle = NSBezelStyleTexturedRounded;
    pinButton.image = [NSImage imageWithSystemSymbolName:@"pin.fill" accessibilityDescription:@"Always on Top"];
    pinButton.target = self;
    pinButton.action = @selector(toggleAlwaysOnTop:);
    pinButton.state = NSControlStateValueOff;  // OFF means floating (always-on-top)
    
    accessoryController.view = pinButton;
    accessoryController.layoutAttribute = NSLayoutAttributeRight;
    
    [self.consoleWindow addTitlebarAccessoryViewController:accessoryController];
    
    // Set window delegate
    ConsoleWindowDelegate *delegate = [[ConsoleWindowDelegate alloc] init];
    delegate.manager = self;
    self.consoleWindow.delegate = delegate;
    
    // Position and show window
    [self.consoleWindow center];
    [self.consoleWindow setFrameAutosaveName:@"DebugConsole"];
    [self.consoleWindow makeKeyAndOrderFront:nil];
    
    // Store original stdout
    if (self.originalStdoutFd == -1) {
        self.originalStdoutFd = dup(STDOUT_FILENO);
        self.originalStdout = [[NSFileHandle alloc] initWithFileDescriptor:self.originalStdoutFd];
    }
    
    // Create and setup pipe
    self.consolePipe = [NSPipe pipe];
    dup2([[self.consolePipe fileHandleForWriting] fileDescriptor], STDOUT_FILENO);
    
    [[self.consolePipe fileHandleForReading] waitForDataInBackgroundAndNotify];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleDataAvailableNotification
                                                    object:[self.consolePipe fileHandleForReading]
                                                     queue:[NSOperationQueue mainQueue]
                                                usingBlock:^(NSNotification *notification) {
        NSFileHandle *fileHandle = notification.object;
        NSData *data = [fileHandle availableData];
        if (data.length > 0) {
            NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            [self appendToConsole:output];
            [fileHandle waitForDataInBackgroundAndNotify];
        }
    }];
    NSLog(@"Console window created");
}

- (void)toggleAlwaysOnTop:(NSButton *)sender {
    BOOL isAlwaysOnTop = (sender.state == NSControlStateValueOff);
    self.consoleWindow.level = isAlwaysOnTop ? NSFloatingWindowLevel : NSNormalWindowLevel;
    
    // Update pin icon - solid for always-on-top, slanted hollow for normal
    NSString *symbolName = isAlwaysOnTop ? @"pin.fill" : @"pin.slash";
    sender.image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:@"Pin Window"];
}

- (void)closeConsoleWindow {
    if (self.consoleWindow) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        
        // Restore original stdout
        if (self.originalStdoutFd != -1) {
            dup2(self.originalStdoutFd, STDOUT_FILENO);
            close(self.originalStdoutFd);
            self.originalStdoutFd = -1;
        }
        
        // Clean up pipe
        if (self.consolePipe) {
            [[self.consolePipe fileHandleForWriting] closeFile];
            [[self.consolePipe fileHandleForReading] closeFile];
            self.consolePipe = nil;
        }
        
        [self.consoleWindow orderOut:nil];
        self.consoleWindow = nil;
        self.consoleTextView = nil;
        self.originalStdout = nil;
    }
}

- (void)appendToConsole:(NSString *)text {
    NSTextView *textView = [self consoleTextView];
    if (!textView) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSTextStorage *storage = textView.textStorage;
        [storage beginEditing];
        [storage appendAttributedString:[[NSAttributedString alloc] initWithString:text]];
        [storage endEditing];
        
        // Force scroll to bottom with animation
        NSRange range = NSMakeRange(storage.length, 0);
        [textView scrollRangeToVisible:range];
        [textView setSelectedRange:range];
        
        // Update scroll position and refresh display
        NSPoint newScrollPoint = NSMakePoint(0, NSMaxY([textView bounds]) - NSHeight([[textView enclosingScrollView] contentView].bounds));
        [[textView enclosingScrollView] contentView].bounds = NSMakeRect(0, newScrollPoint.y, NSWidth(textView.bounds), NSHeight([[textView enclosingScrollView] contentView].bounds));
        [textView.window display];
    });
}

@end
