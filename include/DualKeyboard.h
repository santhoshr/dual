// DualKeyboard.h
#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

@interface DualKeyboardManager : NSObject

@property (nonatomic, assign) BOOL debugMode;
@property (nonatomic, assign) BOOL quietMode;
@property (nonatomic, assign) BOOL shouldRestart;
@property (nonatomic, assign) char currentMode;

+ (instancetype)sharedInstance;
- (BOOL)startEventTap;
- (void)cleanup;

@end