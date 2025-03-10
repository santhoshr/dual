#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "../include/DualKeyboard.h"
#import "DualKeyboardManager+SingleInstance.h"

@implementation NSApplication (CommandLineCheck)
- (BOOL)isRunningFromCommandLine {
    return isatty(STDIN_FILENO);
}
@end

// Function to read version from VERSION file
NSString* readVersion() {
    NSString *versionPath = [[NSBundle mainBundle].bundlePath stringByDeletingLastPathComponent];
    versionPath = [versionPath stringByAppendingPathComponent:@"VERSION"];
    
    // If running from app bundle, path is different
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

void handleSignal(int sig) {
    [[DualKeyboardManager sharedInstance] cleanup];
    [[DualKeyboardManager sharedInstance] cleanupSingleInstance];
    exit(0);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Initialize NSApplication and set activation policy
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        
        DualKeyboardManager *manager = [DualKeyboardManager sharedInstance];
        
        // Parse command line arguments
        for (int i = 1; i < argc; i++) {
            NSString *arg = [NSString stringWithUTF8String:argv[i]];
            if ([arg isEqualToString:@"--debug"] || [arg isEqualToString:@"-d"]) {
                manager.debugMode = YES;
                manager.debugModeAtStartup = YES;
            } else if ([arg isEqualToString:@"--version"] || [arg isEqualToString:@"-v"]) {
                printf("DualKeyboard version %s\n", [readVersion() UTF8String]);
                return 0;
            } else if ([arg isEqualToString:@"--help"] || [arg isEqualToString:@"-h"]) {
                printf("Usage: dual [OPTIONS]\n\n"
                       "Options:\n"
                       "  -d, --debug     Enable debug mode\n"
                       "  -q, --quiet     Quiet mode, suppress non-error output\n"
                       "  -v, --version   Show version information\n"
                       "  -h, --help      Show this help message\n");
                return 0;
            }
        }
        
        // Check for another instance
        if (![manager ensureSingleInstance]) {
            return 1;
        }
        
        // Set up signal handlers
        signal(SIGINT, handleSignal);
        signal(SIGTERM, handleSignal);
        
        // Start the event tap
        if (![manager startEventTap]) {
            fprintf(stderr, "Failed to start event tap\n");
            [manager cleanupSingleInstance];
            return 1;
        }
        
        // Run the main loop
        [NSApp run];
    }
    return 0;
}