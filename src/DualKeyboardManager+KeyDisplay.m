#import "DualKeyboardManager+KeyDisplay.h"
#import "DualKeyboardManager+KeyboardMapping.h"
#import <objc/runtime.h>

@interface KeyDisplayWindow : NSPanel
@property (nonatomic, strong) NSTextField *keyLabel;
@property (nonatomic, strong) NSTextField *keyStateLabel;
@property (nonatomic, strong) NSTextField *pressStateLabel; // New label for press state
@property (nonatomic, strong) NSView *modifiersView;
@property (nonatomic, strong) NSArray<NSButton *> *modButtons;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *modifierState;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *deviceFlags;
@property (nonatomic, strong) NSVisualEffectView *visualEffectView; // For modern blur effect
@end

@implementation KeyDisplayWindow

- (instancetype)init {
    self = [super initWithContentRect:NSMakeRect(0, 0, 220, 140) // Increased height for more info
                          styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                            backing:NSBackingStoreBuffered
                              defer:NO];
    if (self) {
        // Set up appearance-aware window
        self.hasShadow = YES;
        self.backgroundColor = [NSColor clearColor]; // Clear background for the visual effect view
        self.level = NSPopUpMenuWindowLevel;
        self.movableByWindowBackground = YES;
        
        // Set up the visual effect view for modern UI with blur
        self.visualEffectView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 220, 140)]; // Increased height
        self.visualEffectView.material = NSVisualEffectMaterialHUDWindow;
        self.visualEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        self.visualEffectView.state = NSVisualEffectStateActive;
        self.visualEffectView.wantsLayer = YES;
        self.visualEffectView.layer.cornerRadius = 12.0;
        self.visualEffectView.layer.masksToBounds = YES;
        
        // Use autoresizing for visual effect view
        self.visualEffectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        
        // Set the visual effect view as the content view
        self.contentView = self.visualEffectView;
        
        // Create a container view for all content to add proper padding
        NSView *containerView = [[NSView alloc] initWithFrame:NSMakeRect(15, 15, 190, 110)]; // Increased height
        containerView.wantsLayer = YES;
        containerView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self.visualEffectView addSubview:containerView];
        
        // Key display with improved styling - moved up to make room
        self.keyLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 80, 190, 30)]; // Moved up
        self.keyLabel.bezeled = NO;
        self.keyLabel.editable = NO;
        self.keyLabel.backgroundColor = [NSColor clearColor];
        self.keyLabel.textColor = nil; // Use system color
        self.keyLabel.font = [NSFont monospacedSystemFontOfSize:16 weight:NSFontWeightSemibold];
        self.keyLabel.alignment = NSTextAlignmentCenter;
        [containerView addSubview:self.keyLabel];
        
        // Key code label - Shows hex and decimal keycodes
        self.keyStateLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 55, 190, 20)]; // Adjusted position
        self.keyStateLabel.bezeled = NO;
        self.keyStateLabel.editable = NO;
        self.keyStateLabel.backgroundColor = [NSColor clearColor];
        self.keyStateLabel.textColor = nil; // Will be set dynamically
        self.keyStateLabel.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
        self.keyStateLabel.alignment = NSTextAlignmentCenter;
        [containerView addSubview:self.keyStateLabel];
        
        // Key press state label - Shows PRESSED/RELEASED
        self.pressStateLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 35, 190, 20)]; // Adjusted position
        self.pressStateLabel.bezeled = NO;
        self.pressStateLabel.editable = NO;
        self.pressStateLabel.backgroundColor = [NSColor clearColor];
        self.pressStateLabel.textColor = nil; // Will be set dynamically
        self.pressStateLabel.font = [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightBold];
        self.pressStateLabel.alignment = NSTextAlignmentCenter;
        [containerView addSubview:self.pressStateLabel];
        
        // Separator line
        NSBox *separatorLine = [[NSBox alloc] initWithFrame:NSMakeRect(0, 30, 190, 1)];
        separatorLine.boxType = NSBoxSeparator;
        [containerView addSubview:separatorLine];
        
        // Modifier buttons with improved styling
        NSArray *modNames = @[@"⌘", @"⌃", @"⌥", @"⇧"];
        NSMutableArray *buttons = [NSMutableArray array];
        CGFloat spacing = 10;
        CGFloat buttonWidth = (190 - spacing * 3) / 4;  // Distribute evenly with spacing
        CGFloat x = 0;
        
        for (NSString *name in modNames) {
            NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(x, 0, buttonWidth, 25)];
            [btn setTitle:name];
            [btn setBezelStyle:NSBezelStyleInline];
            [btn setEnabled:NO];
            btn.wantsLayer = YES;
            btn.layer.cornerRadius = 5;
            
            // Use system-defined colors for better dark/light mode support
            btn.layer.backgroundColor = [NSColor quaternaryLabelColor].CGColor;
            
            NSAttributedString *title = [[NSAttributedString alloc] 
                initWithString:name 
                attributes:@{
                    NSForegroundColorAttributeName: [NSColor labelColor],
                    NSFontAttributeName: [NSFont systemFontOfSize:14 weight:NSFontWeightMedium]
                }];
            [btn setAttributedTitle:title];
            [containerView addSubview:btn];
            [buttons addObject:btn];
            x += buttonWidth + spacing;
        }
        self.modButtons = buttons;
        
        // Initialize state dictionaries
        self.modifierState = [NSMutableDictionary dictionary];
        self.deviceFlags = [NSMutableDictionary dictionary];
        
        // Register for appearance changes
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                            selector:@selector(applyAppearance)
                                                                name:@"AppleInterfaceThemeChangedNotification"
                                                              object:nil];
        
        // Apply initial appearance
        [self applyAppearance];
    }
    return self;
}

- (void)applyAppearance {
    // This will be called when system appearance changes
    if (@available(macOS 10.14, *)) {
        // Update visual effect material based on appearance
        BOOL isDarkMode = [self.effectiveAppearance.name containsString:@"Dark"];
        self.visualEffectView.material = isDarkMode ? 
                                       NSVisualEffectMaterialHUDWindow : 
                                       NSVisualEffectMaterialSheet;
                                       
        // Update button colors for inactive state
        for (NSButton *btn in self.modButtons) {
            if (btn.state != NSControlStateValueOn) {
                btn.layer.backgroundColor = isDarkMode ? 
                    [NSColor colorWithWhite:0.3 alpha:0.6].CGColor : 
                    [NSColor colorWithWhite:0.9 alpha:0.6].CGColor;
            }
        }
    }
}

- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

@end

@implementation DualKeyboardManager (KeyDisplay)

static char keyDisplayWindowKey;
static char lastWindowFrameKey;

- (KeyDisplayWindow *)keyDisplayWindow {
    return objc_getAssociatedObject(self, &keyDisplayWindowKey);
}

- (void)setKeyDisplayWindow:(KeyDisplayWindow *)window {
    objc_setAssociatedObject(self, &keyDisplayWindowKey, window, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSValue *)lastWindowFrame {
    return objc_getAssociatedObject(self, &lastWindowFrameKey);
}

- (void)setLastWindowFrame:(NSValue *)frameValue {
    objc_setAssociatedObject(self, &lastWindowFrameKey, frameValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)toggleKeyDisplay {
    if (self.keyDisplayWindow) {
        // Store the current frame before closing
        self.lastWindowFrame = [NSValue valueWithRect:self.keyDisplayWindow.frame];
        [self.keyDisplayWindow close];
        self.keyDisplayWindow = nil;
    } else {
        KeyDisplayWindow *window = [[KeyDisplayWindow alloc] init];
        
        // Position at last known location if available, otherwise center
        if (self.lastWindowFrame) {
            [window setFrame:[self.lastWindowFrame rectValue] display:YES];
        } else {
            [window center];
        }
        
        [window makeKeyAndOrderFront:nil];
        self.keyDisplayWindow = window;
    }
}

- (void)updateKeyDisplay:(CGKeyCode)keycode flags:(CGEventFlags)flags isKeyDown:(BOOL)isDown {
    KeyDisplayWindow *window = self.keyDisplayWindow;
    if (!window) return;
    
    // Use centralized method to compute combined flags
    CGEventFlags combinedFlags = [self computeCombinedModifierFlags];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Key display update
        if (isDown) {
            // Create a temporary event to get the unicode string
            CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
            CGEventRef keyEvent = CGEventCreateKeyboardEvent(source, keycode, true);
            CGEventSetFlags(keyEvent, flags);
            
            UniChar chars[4];
            UniCharCount count;
            CGEventKeyboardGetUnicodeString(keyEvent, sizeof(chars)/sizeof(chars[0]), &count, chars);
            NSString *character = count > 0 ? [[NSString alloc] initWithCharacters:chars length:count] : @"?";
            
            CFRelease(keyEvent);
            CFRelease(source);
            
            // Get human-readable key name if possible
            NSString *keyName = [self humanReadableKeyName:keycode];
            
            // Format to show both hex code and keycode values
            NSString *displayString = keyName ? 
                [NSString stringWithFormat:@"%@ (%@)", character, keyName] : 
                [NSString stringWithFormat:@"%@", character];
                
            // Show keycode and hex values separately below the main label
            NSString *codeDisplay = [NSString stringWithFormat:@"Key: %d (0x%02X)", 
                                   (int)keycode, (unsigned int)keycode];
            
            // Set the main key display with symbol and name
            window.keyLabel.stringValue = displayString;
            
            // Update the state label to show key codes (we'll create a dedicated field for state)
            NSMutableAttributedString *attrState = [[NSMutableAttributedString alloc] 
                initWithString:codeDisplay
                attributes:@{
                    NSForegroundColorAttributeName: [NSColor secondaryLabelColor],
                    NSFontAttributeName: [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular]
                }];
                
            window.keyStateLabel.attributedStringValue = attrState;
        }
        
        // Update the pressed/released state indicator with improved styling
        NSString *stateText = isDown ? @"PRESSED" : @"RELEASED";
        
        // Use system colors with semantic meaning for better dark/light mode support
        NSColor *stateColor;
        if (isDown) {
            stateColor = [NSColor systemGreenColor]; // Green for pressed
        } else {
            stateColor = [NSColor systemRedColor];   // Red for released
        }
        
        // Create a dedicated state display (we'll add this in the init method)
        if (window.pressStateLabel) {
            NSMutableAttributedString *attrPressState = [[NSMutableAttributedString alloc] 
                initWithString:stateText
                attributes:@{
                    NSForegroundColorAttributeName: stateColor,
                    NSFontAttributeName: [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightBold]
                }];
                
            window.pressStateLabel.attributedStringValue = attrPressState;
        }
        
        // Update modifier buttons
        [self updateModifierButtonsInWindow:window withFlags:combinedFlags];
    });
}

- (void)updateModifierButtonsInWindow:(KeyDisplayWindow *)window withFlags:(CGEventFlags)combinedFlags {
    // Get current appearance for proper colors
    BOOL isDarkMode = NO;
    if (@available(macOS 10.14, *)) {
        isDarkMode = [window.effectiveAppearance.name containsString:@"Dark"];
    }
    
    // Update modifier button states
    [window.modButtons[0] setState:(combinedFlags & kCGEventFlagMaskCommand) ? NSControlStateValueOn : NSControlStateValueOff];
    [window.modButtons[1] setState:(combinedFlags & kCGEventFlagMaskControl) ? NSControlStateValueOn : NSControlStateValueOff];
    [window.modButtons[2] setState:(combinedFlags & kCGEventFlagMaskAlternate) ? NSControlStateValueOn : NSControlStateValueOff];
    [window.modButtons[3] setState:(combinedFlags & kCGEventFlagMaskShift) ? NSControlStateValueOn : NSControlStateValueOff];
    
    // Update button appearances with proper colors for dark/light mode
    for (NSButton *btn in window.modButtons) {
        BOOL isPressed = (btn.state == NSControlStateValueOn);
        
        if (isPressed) {
            // Active button - system blue color looks good in both dark and light modes
            btn.layer.backgroundColor = [NSColor systemBlueColor].CGColor;
            
            // White text for contrast on blue background
            NSAttributedString *title = [[NSAttributedString alloc]
                initWithString:btn.title
                attributes:@{
                    NSForegroundColorAttributeName: [NSColor whiteColor],
                    NSFontAttributeName: [NSFont systemFontOfSize:14 weight:NSFontWeightMedium]
                }];
            [btn setAttributedTitle:title];
        } else {
            // Inactive button - respect dark/light mode
            btn.layer.backgroundColor = isDarkMode ? 
                [NSColor colorWithWhite:0.3 alpha:0.6].CGColor : 
                [NSColor colorWithWhite:0.9 alpha:0.6].CGColor;
            
            // Text color that works with the background
            NSAttributedString *title = [[NSAttributedString alloc]
                initWithString:btn.title
                attributes:@{
                    NSForegroundColorAttributeName: isDarkMode ? 
                        [NSColor colorWithWhite:0.9 alpha:1.0] : 
                        [NSColor colorWithWhite:0.2 alpha:1.0],
                    NSFontAttributeName: [NSFont systemFontOfSize:14 weight:NSFontWeightMedium]
                }];
            [btn setAttributedTitle:title];
        }
    }
}

- (void)refreshKeyDisplayModifiers {
    KeyDisplayWindow *window = self.keyDisplayWindow;
    if (!window) return;
    
    // Use centralized method to compute combined flags
    CGEventFlags combinedFlags = [self computeCombinedModifierFlags];
    
    [self updateModifierButtonsInWindow:window withFlags:combinedFlags];
}

- (NSString *)humanReadableKeyName:(CGKeyCode)keycode {
    // Map of common keycodes to human-readable names
    static NSDictionary *keyNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keyNames = @{
            @(0): @"A", @(1): @"S", @(2): @"D", @(3): @"F", @(4): @"H", @(5): @"G",
            @(6): @"Z", @(7): @"X", @(8): @"C", @(9): @"V", @(11): @"B", @(12): @"Q",
            @(13): @"W", @(14): @"E", @(15): @"R", @(16): @"Y", @(17): @"T",
            @(18): @"1", @(19): @"2", @(20): @"3", @(21): @"4", @(22): @"6",
            @(23): @"5", @(24): @"=", @(25): @"9", @(26): @"7", @(27): @"-",
            @(28): @"8", @(29): @"0", @(30): @"]", @(31): @"O", @(32): @"U", 
            @(33): @"[", @(34): @"I", @(35): @"P", @(36): @"Return", @(37): @"L", 
            @(38): @"J", @(39): @"'", @(40): @"K", @(41): @";", @(42): @"\\", 
            @(43): @",", @(44): @"/", @(45): @"N", @(46): @"M", @(47): @".",
            @(48): @"Tab", @(49): @"Space", @(50): @"`", @(51): @"Delete", 
            @(53): @"Esc", @(55): @"⌘", @(56): @"⇧", @(57): @"Caps Lock", 
            @(58): @"⌥", @(59): @"⌃", @(60): @"⇧", @(61): @"⌥", @(62): @"⌃",
            @(65): @".", @(67): @"*", @(69): @"+", @(71): @"Clear", 
            @(75): @"/", @(76): @"Enter", @(78): @"-", @(81): @"=",
            @(82): @"0", @(83): @"1", @(84): @"2", @(85): @"3", @(86): @"4", 
            @(87): @"5", @(88): @"6", @(89): @"7", @(91): @"8", @(92): @"9",
            @(96): @"F5", @(97): @"F6", @(98): @"F7", @(99): @"F3", @(100): @"F8", 
            @(101): @"F9", @(103): @"F11", @(105): @"F13", @(107): @"F14",
            @(109): @"F10", @(111): @"F12", @(113): @"F15", @(114): @"Help", 
            @(115): @"Home", @(116): @"PgUp", @(117): @"⌦", @(118): @"F4", 
            @(119): @"End", @(120): @"F2", @(121): @"PgDn", @(122): @"F1", 
            @(123): @"←", @(124): @"→", @(125): @"↓", @(126): @"↑",
            @(10): @"§"  // Section key (remapped CapsLock)
        };
    });
    
    return keyNames[@(keycode)];
}

@end
