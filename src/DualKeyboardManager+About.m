#import "DualKeyboardManager+About.h"
#import <objc/runtime.h>

@interface AboutWindow : NSPanel
@property (nonatomic, strong) NSImageView *logoView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *versionLabel;
@property (nonatomic, strong) NSTextField *creatorLabel;
@property (nonatomic, strong) NSTextView *attributionText;
@end

@implementation AboutWindow

- (instancetype)init {
    self = [super initWithContentRect:NSMakeRect(0, 0, 400, 350)
                           styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                             backing:NSBackingStoreBuffered
                               defer:NO];  // Important: non-deferred window
    if (self) {
        self.title = @"About DualKeyboard";
        [self center];
        self.movableByWindowBackground = YES;
        self.level = NSPopUpMenuWindowLevel;
        self.becomesKeyOnlyIfNeeded = YES;
        self.releasedWhenClosed = NO;  // Keep window in memory when closed
        
        // Create a visual effect view for the background
        NSVisualEffectView *visualEffectView = [[NSVisualEffectView alloc] initWithFrame:self.contentView.bounds];
        visualEffectView.material = NSVisualEffectMaterialPopover;
        visualEffectView.state = NSVisualEffectStateActive;
        visualEffectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.contentView = visualEffectView;
        
        // Setup the logo image view
        NSImage *logoImage = [NSImage imageNamed:@"DualKeyboardLogo"];
        if (!logoImage) {
            // Create a default logo if image not found
            logoImage = [self createDefaultLogo];
        }
        
        self.logoView = [[NSImageView alloc] initWithFrame:NSMakeRect((400 - 128) / 2, 200, 128, 128)];
        self.logoView.image = logoImage;
        self.logoView.imageScaling = NSImageScaleProportionallyUpOrDown;
        [self.contentView addSubview:self.logoView];
        
        // App title
        self.titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 170, 360, 24)];
        self.titleLabel.stringValue = @"DualKeyboard";
        self.titleLabel.alignment = NSTextAlignmentCenter;
        self.titleLabel.font = [NSFont systemFontOfSize:18 weight:NSFontWeightBold];
        self.titleLabel.textColor = [NSColor labelColor];
        self.titleLabel.bezeled = NO;
        self.titleLabel.editable = NO;
        self.titleLabel.drawsBackground = NO;
        [self.contentView addSubview:self.titleLabel];
        
        // Version info
        NSString *version = [self appVersion];
        self.versionLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 145, 360, 20)];
        self.versionLabel.stringValue = [NSString stringWithFormat:@"Version %@", version];
        self.versionLabel.alignment = NSTextAlignmentCenter;
        self.versionLabel.font = [NSFont systemFontOfSize:12];
        self.versionLabel.textColor = [NSColor secondaryLabelColor];
        self.versionLabel.bezeled = NO;
        self.versionLabel.editable = NO;
        self.versionLabel.drawsBackground = NO;
        [self.contentView addSubview:self.versionLabel];
        
        // Creator info with styled text
        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] init];
        
        // Create styled text with links
        [self appendBoldText:@"Created by " toString:attributedString];
        [self appendLinkText:@"Santhosh R" withURL:@"https://github.com/santhoshr/DualKeyboard" toString:attributedString];
        [self appendText:@" (Github)\n\n" toString:attributedString];
        
        [self appendText:@"Thanks to " toString:attributedString];
        [self appendBoldText:@"Chance Miller" toString:attributedString];
        [self appendText:@" (" toString:attributedString];
        [self appendLinkText:@"Link" withURL:@"http://dotdotcomorg.net/dual" toString:attributedString];
        [self appendText:@") and " toString:attributedString];
        [self appendBoldText:@"Phillip Calvin" toString:attributedString];
        [self appendText:@" (" toString:attributedString];
        [self appendLinkText:@"Github" withURL:@"https://github.com/pnc/dual-keyboards" toString:attributedString];
        [self appendText:@")" toString:attributedString];
        
        // Create a text view to display the attributed string with links
        NSTextView *attributionTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(20, 20, 360, 120)];
        attributionTextView.editable = NO;
        attributionTextView.selectable = YES;
        attributionTextView.drawsBackground = NO;
        attributionTextView.textStorage.attributedString = attributedString;
        attributionTextView.alignment = NSTextAlignmentCenter;
        attributionTextView.textContainerInset = NSMakeSize(5, 10);
        [self.contentView addSubview:attributionTextView];
        
        self.attributionText = attributionTextView;
    }
    return self;
}

// Override close to just hide the window
- (void)close {
    [self orderOut:nil];
}

- (NSImage *)createDefaultLogo {
    NSImage *logo = [[NSImage alloc] initWithSize:NSMakeSize(128, 128)];
    [logo lockFocus];
    
    // Draw a gradient background
    NSGradient *gradient = [[NSGradient alloc] initWithColors:@[
        [NSColor colorWithCalibratedRed:0.0 green:0.5 blue:0.8 alpha:1.0],
        [NSColor colorWithCalibratedRed:0.0 green:0.3 blue:0.6 alpha:1.0]
    ]];
    
    NSBezierPath *circlePath = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(4, 4, 120, 120)];
    [gradient drawInBezierPath:circlePath angle:90];
    
    // Add a white border
    [[NSColor whiteColor] setStroke];
    [circlePath setLineWidth:3.0];
    [circlePath stroke];
    
    // Draw the "DK" letters in white
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    
    NSDictionary *textAttributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:60],
        NSForegroundColorAttributeName: [NSColor whiteColor],
        NSParagraphStyleAttributeName: paragraphStyle
    };
    
    NSAttributedString *text = [[NSAttributedString alloc] initWithString:@"DK" attributes:textAttributes];
    NSRect textRect = NSMakeRect(0, 30, 128, 70);
    [text drawInRect:textRect];
    
    // Draw small keyboard icon
    NSBezierPath *keyboardPath = [NSBezierPath bezierPath];
    [keyboardPath moveToPoint:NSMakePoint(38, 25)];
    [keyboardPath lineToPoint:NSMakePoint(90, 25)];
    [keyboardPath lineToPoint:NSMakePoint(90, 45)];
    [keyboardPath lineToPoint:NSMakePoint(38, 45)];
    [keyboardPath closePath];
    
    [[NSColor whiteColor] setStroke];
    [keyboardPath setLineWidth:2.0];
    [keyboardPath stroke];
    
    // Draw some keyboard keys
    for (int i = 0; i < 5; i++) {
        NSRect keyRect = NSMakeRect(40 + i * 10, 28, 8, 8);
        NSBezierPath *keyPath = [NSBezierPath bezierPathWithRect:keyRect];
        [[NSColor whiteColor] setStroke];
        [keyPath stroke];
    }
    
    [logo unlockFocus];
    
    return logo;
}

- (NSString *)appVersion {
    NSString *versionPath = [[NSBundle mainBundle].bundlePath stringByDeletingLastPathComponent];
    versionPath = [versionPath stringByAppendingPathComponent:@"VERSION"];
    
    // If running from app bundle, path might be different
    if (![[NSFileManager defaultManager] fileExistsAtPath:versionPath]) {
        versionPath = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"VERSION"];
    }
    
    // If still not found, try relative path for command line execution
    if (![[NSFileManager defaultManager] fileExistsAtPath:versionPath]) {
        versionPath = @"VERSION";
    }
    
    NSError *error = nil;
    NSString *version = [NSString stringWithContentsOfFile:versionPath 
                                                 encoding:NSUTF8StringEncoding 
                                                    error:&error];
    if (error || !version) {
        return @"4.0.1"; // Fallback version
    }
    
    return [version stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)appendText:(NSString *)text toString:(NSMutableAttributedString *)attrString {
    NSAttributedString *attrText = [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: [NSFont systemFontOfSize:13],
        NSForegroundColorAttributeName: [NSColor labelColor]
    }];
    [attrString appendAttributedString:attrText];
}

- (void)appendBoldText:(NSString *)text toString:(NSMutableAttributedString *)attrString {
    NSAttributedString *attrText = [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:13],
        NSForegroundColorAttributeName: [NSColor labelColor]
    }];
    [attrString appendAttributedString:attrText];
}

- (void)appendLinkText:(NSString *)text withURL:(NSString *)urlString toString:(NSMutableAttributedString *)attrString {
    NSAttributedString *attrText = [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: [NSFont systemFontOfSize:13],
        NSForegroundColorAttributeName: [NSColor linkColor],
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
        NSLinkAttributeName: [NSURL URLWithString:urlString]
    }];
    [attrString appendAttributedString:attrText];
}

@end

@implementation DualKeyboardManager (About)

static char aboutWindowKey;

- (NSWindow *)aboutWindow {
    return objc_getAssociatedObject(self, &aboutWindowKey);
}

- (void)setAboutWindow:(NSWindow *)window {
    objc_setAssociatedObject(self, &aboutWindowKey, window, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)createAboutWindowIfNeeded {
    NSLog(@"Creating About window if needed");
    if (!self.aboutWindow) {
        AboutWindow *aboutWindow = [[AboutWindow alloc] init];
        self.aboutWindow = aboutWindow;  // Retain immediately
        [aboutWindow center];
        NSLog(@"About window created");
    }
}

- (void)showAboutWindow {
    NSLog(@"Showing About window");
    [self createAboutWindowIfNeeded];
    
    // Force window creation even if deferred
    [self.aboutWindow display];
    
    // Ensure app is active and in front
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [NSApp activateIgnoringOtherApps:YES];
    
    // Force window to front with explicit ordering
    AboutWindow *window = (AboutWindow *)self.aboutWindow;
    [window setLevel:NSPopUpMenuWindowLevel];
    [window orderOut:nil];  // Force window to update ordering
    [window center];
    [window makeKeyAndOrderFront:nil];
    
    // Secondary ordering after a tiny delay to ensure visibility
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [window orderFrontRegardless];
        [window makeKeyWindow];
    });
    
    NSLog(@"About window shown");
}

@end