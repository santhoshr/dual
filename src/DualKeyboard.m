#import "../include/DualKeyboard.h"
#import "DualKeyboardManager+KeyboardStatus.h"
#import "DualKeyboardManager+KeyboardMapping.h"
#import "DualKeyboardManager+CapsNavigation.h"
#import "DualKeyboardManager+MenuBar.h"
#import "DualKeyboardManager+SingleInstance.h"
#import "DualKeyboardManager+About.h"  // Add missing import

// Mode constants
#define MODE_INSERT 'I'
#define MODE_NAVIGATION 'N'

@interface DualKeyboardManager ()
@property (nonatomic, strong) id eventTap;
@end

@implementation DualKeyboardManager

+ (instancetype)sharedInstance {
    static DualKeyboardManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _debugMode = NO;
        _debugModeAtStartup = NO;
        _shouldRestart = NO;
        _currentMode = MODE_INSERT;
        
        // Set proper activation policy early
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        // Pre-create the about window during initialization
        [self createAboutWindowIfNeeded];
    }
    return self;
}

- (BOOL)startEventTap {
    [self setupCapsLockRemapping];
    [self setupStatusBar];
    [self setupMenuBar];  // Add menubar setup
    
    CGEventMask eventMask = ((1 << kCGEventKeyDown) | (1 << kCGEventKeyUp) | (1 << kCGEventFlagsChanged));
    CFMachPortRef tap = CGEventTapCreate(kCGSessionEventTap,
                                        kCGHeadInsertEventTap,
                                        0,
                                        eventMask,
                                        eventCallback,
                                        (__bridge void *)self);
    
    if (!tap) {
        NSLog(@"Failed to create event tap");
        return NO;
    }
    
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(tap, true);
    
    self.eventTap = (__bridge id)tap;
    
    return YES;
}

static CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    if ((type != kCGEventKeyDown) && (type != kCGEventKeyUp) && (type != kCGEventFlagsChanged)) {
        return event;
    }
    
    DualKeyboardManager *manager = (__bridge DualKeyboardManager *)refcon;
    CGKeyCode keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    
    if (manager.debugMode) {
        // More detailed debug message that includes flag changes
        NSString *eventTypeStr;
        switch (type) {
            case kCGEventKeyDown:
                eventTypeStr = @"KeyDown";
                break;
            case kCGEventKeyUp:
                eventTypeStr = @"KeyUp";
                break;
            case kCGEventFlagsChanged:
                eventTypeStr = @"FlagsChanged";
                break;
            default:
                eventTypeStr = @"Unknown";
                break;
        }
        
        NSLog(@"Event: %@ (%d), KeyCode: %d", eventTypeStr, (int)type, (int)keycode);
    }
    
    // Handle the key event using our KeyboardMapping category
    if ([manager handleKeyEvent:event ofType:type withKeycode:keycode]) {
        return NULL;
    }
    
    return event;
}

- (void)cleanup {
    [self cleanupStatusBar];
    [self restoreCapsLockMapping];
    [self cleanupSingleInstance];
}

@end