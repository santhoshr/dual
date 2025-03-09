#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "../include/DualKeyboard.h"
#import "DualKeyboardManager+SingleInstance.h"

void handleSignal(int sig) {
    [[DualKeyboardManager sharedInstance] cleanup];
    [[DualKeyboardManager sharedInstance] cleanupSingleInstance];
    exit(0);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Initialize NSApplication
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        
        DualKeyboardManager *manager = [DualKeyboardManager sharedInstance];
        
        // Parse command line arguments
        for (int i = 1; i < argc; i++) {
            NSString *arg = [NSString stringWithUTF8String:argv[i]];
            if ([arg isEqualToString:@"--debug"] || [arg isEqualToString:@"-d"]) {
                manager.debugMode = YES;
            } else if ([arg isEqualToString:@"--quiet"] || [arg isEqualToString:@"-q"]) {
                manager.quietMode = YES;
            } else if ([arg isEqualToString:@"--version"] || [arg isEqualToString:@"-v"]) {
                printf("DualKeyboard version 3.0.0\n");
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