#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <CoreFoundation/CoreFoundation.h>
#include "../include/capslock.h"
#include "../include/navigation.h"
#include "../include/termstatus.h"
#include "../include/common.h"

// Version information
#define DUAL_VERSION "2.0.0"

// Function declarations
static void handle_signal(int signum);

// Global variables
extern CFMachPortRef eventTap;
extern CFRunLoopSourceRef runLoopSource;

// This callback will be invoked every time there is a keystroke.
CGEventRef
myCGEventCallback(CGEventTapProxy proxy, CGEventType type,
                  CGEventRef event, void *refcon)
{
    // Paranoid sanity check.
    if ((type != kCGEventKeyDown) && (type != kCGEventKeyUp) && (type != kCGEventFlagsChanged))
        return event;

    // The incoming keycode.
    CGKeyCode keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    
    // Print debug info if debug mode is on
    if (debug_mode && !quiet_mode) {
        debug_print_key(keycode, type);
    }
    
    // Track keys for exit combination (Escape + Control + Space)
    if (keycode == KEYCODE_ESCAPE) {
        escape_pressed = (type == kCGEventKeyDown);
        
        // Unlock vim mode when Escape is pressed
        if (type == kCGEventKeyDown && vim_mode_locked) {
            vim_mode_locked = false;
            if (debug_mode) {
                printf("Vim navigation mode unlocked with Escape\n");
            }
            update_status_msg('I');  // Update status bar to show Insert mode
        }
    } else if (keycode == (CGKeyCode)59 || keycode == (CGKeyCode)62) {
        // Control key
        control_pressed = (type == kCGEventKeyDown || type == kCGEventFlagsChanged);
    } else if (keycode == KEYCODE_SPACE) {
        space_pressed = (type == kCGEventKeyDown);
    } else if (keycode == KEYCODE_ZERO) {
        zero_pressed = (type == kCGEventKeyDown);
    } else if (keycode == KEYCODE_MINUS) {
        minus_pressed = (type == kCGEventKeyDown);
    }
    
    // Check for exit combination
    if (escape_pressed && control_pressed && space_pressed) {
        if (debug_mode) {
            printf("Exit key combination detected (Escape + Control + Space)\n");
        }
        cleanup_and_exit();
    }
    
    // Check for restart combination (Escape + 0)
    if (escape_pressed && zero_pressed) {
        if (debug_mode) {
            printf("Restart key combination detected (Escape + 0)\n");
        }
        should_restart = true;
        cleanup_and_exit();
    }
    
    // Check for vim mode lock combination (Escape + 1)
    if (escape_pressed && keycode == KEYCODE_ONE && type == kCGEventKeyDown) {
        vim_mode_locked = true;
        vim_mode_active = true;
        if (debug_mode) {
            printf("Vim navigation mode locked with Escape + 1\n");
        }
        update_status_msg('N');  // Update status bar to show Navigation mode
        return NULL; // Suppress the 1 key
    }
    
    // Check for Shift+I to exit vim mode when locked
    if (keycode == KEYCODE_I && type == kCGEventKeyDown && vim_mode_locked) {
        // Check if shift is pressed
        CGEventFlags flags = CGEventGetFlags(event);
        bool shift_pressed = (flags & kCGEventFlagMaskShift) != 0;
        
        if (shift_pressed) {
            vim_mode_locked = false;
            vim_mode_active = false;
            if (debug_mode) {
                printf("Vim navigation mode unlocked with Shift+I\n");
            }
            update_status_msg('I');  // Update status when exiting with Shift+I
            return NULL; // Suppress the Shift+I key to avoid unwanted input
        }
        // If it's just I without Shift, let it continue to the vim navigation handling below
    }
    
    // Handle remapped CapsLock key (now Section key, keycode 10)
    if (keycode == KEYCODE_SECTION) {
        if (type == kCGEventKeyDown) {
            // Check if this is a repeat or new press
            uint64_t current_time = get_current_time_ns();
            CGEventFlags flags = CGEventGetFlags(event);
            bool is_repeat = (flags & kCGEventFlagMaskNonCoalesced) == 0;
            
            if (!caps_key_down) {
                // Initial key press
                caps_key_down = true;
                caps_press_time = current_time;
                
                // If vim mode is locked, unlock it when CapsLock is pressed
                if (vim_mode_locked) {
                    vim_mode_locked = false;
                    vim_mode_active = false;
                    if (debug_mode) {
                        printf("Vim navigation mode unlocked with CapsLock\n");
                    }
                    update_status_msg('I');  // Update status bar to show Insert mode
                }
                
                key_repeat = false;
                
                if (debug_mode) {
                    printf("CapsLock (§ key) pressed down - INITIAL PRESS\n");
                }
                
                // Suppress the original event
                return NULL;
            } else if (is_repeat) {
                // This is a key repeat, mark it as such
                key_repeat = true;
                
                if (debug_mode) {
                    printf("CapsLock (§ key) key repeat detected - ignoring\n");
                }
                
                // Suppress repeats
                return NULL;
            }
        }
        else if (type == kCGEventKeyUp && caps_key_down) {
            // Key was released
            uint64_t release_time = get_current_time_ns();
            uint64_t hold_duration = release_time - caps_press_time;
            
            caps_key_down = false;
            key_repeat = false;
            
            // Only send Escape if key was tapped briefly and Vim mode wasn't activated
            if (!vim_mode_active && !vim_mode_locked && hold_duration < HOLD_THRESHOLD) {
                send_escape_key();
            }
            
            // End Vim navigation mode only if it's not locked
            if (!vim_mode_locked) {
                if (vim_mode_active) {
                    vim_mode_active = false;
                    if (debug_mode) {
                        printf("Vim navigation mode deactivated\n");
                    }
                    update_status_msg('I');  // Update status when exiting navigation mode
                }
            }
            
            // Suppress the original event
            return NULL;
        }
        
        // Always suppress any other events related to the CapsLock key
        // This ensures no special characters are emitted when holding CapsLock
        return NULL;
    }
    
    // Check for Capslock + n to lock vim mode
    if (caps_key_down && keycode == KEYCODE_N && type == kCGEventKeyDown) {
        vim_mode_locked = true;
        vim_mode_active = true;
        if (debug_mode) {
            printf("Vim navigation mode locked with Capslock + n\n");
        }
        update_status_msg('N');  // Update status when locking with CapsLock + n
        return NULL; // Suppress the n key
    }
    
    // Check for debug message toggle (Escape + -)
    if (escape_pressed && minus_pressed && type == kCGEventKeyDown) {
        if (!quiet_mode) {
            debug_mode = !debug_mode;
            printf("\nDebug messages %s\n", debug_mode ? "enabled" : "disabled");
            return NULL; // Suppress the minus key
        }
    }

    // Handle Vim navigation when in vim mode (either active or locked)
    if ((caps_key_down || vim_mode_locked) && type == kCGEventKeyDown) {
        // Create a new event source for better event handling
        CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
        if (!source) {
            return event;
        }
        
        // If vim mode is locked, we don't need to check hold duration
        // Otherwise, check if CapsLock has been held long enough
        bool should_process_vim_keys = vim_mode_locked;
        
        if (!should_process_vim_keys && caps_key_down) {
            uint64_t current_time = get_current_time_ns();
            uint64_t hold_duration = current_time - caps_press_time;
            should_process_vim_keys = (hold_duration >= HOLD_THRESHOLD);
            
            // Only update the status bar icon when we've held long enough to enter vim mode
            if (should_process_vim_keys && !vim_mode_active) {
                vim_mode_active = true;
                if (debug_mode) {
                    printf("Vim navigation mode activated\n");
                }
                update_status_msg('N');  // Update status bar to show Navigation mode
            }
        }
        
        if (should_process_vim_keys) {
            // Mark that we're in Vim mode (which prevents Escape on release)
            if (!vim_mode_active) {
                vim_mode_active = true;
            }
            
            CGKeyCode new_keycode = 0;
            bool should_remap = true;
            
            // Map keys to vim navigation
            switch (keycode) {
                case KEYCODE_H: new_keycode = KEYCODE_LEFT_ARROW; break;
                case KEYCODE_J: new_keycode = KEYCODE_DOWN_ARROW; break;
                case KEYCODE_K: new_keycode = KEYCODE_UP_ARROW; break;
                case KEYCODE_L: new_keycode = KEYCODE_RIGHT_ARROW; break;
                case KEYCODE_I: 
                    // If i is pressed and vim mode is locked, we need to check if shift is pressed
                    if (vim_mode_locked) {
                        CGEventFlags flags = CGEventGetFlags(event);
                        bool shift_pressed = (flags & kCGEventFlagMaskShift) != 0;
                        
                        // Only remap to Page Up if Shift is not pressed
                        if (!shift_pressed) {
                            new_keycode = KEYCODE_PAGE_UP;
                        } else {
                            should_remap = false;
                        }
                        break;
                    }
                    new_keycode = KEYCODE_PAGE_UP; 
                    break;
                case KEYCODE_O: new_keycode = KEYCODE_PAGE_DOWN; break;
                case KEYCODE_COMMA: new_keycode = KEYCODE_HOME; break;
                case KEYCODE_PERIOD: new_keycode = KEYCODE_END; break;
                default: should_remap = false; break;
            }
            
            if (should_remap) {
                // Create a new event with the remapped keycode
                CGEventRef new_event = CGEventCreateKeyboardEvent(source, new_keycode, true);
                CGEventSetFlags(new_event, CGEventGetFlags(event));
                
                // Post the event directly to the HID system
                CGEventPost(kCGHIDEventTap, new_event);
                CFRelease(new_event);
                CFRelease(source);
                return NULL;
            }
            
            CFRelease(source);
        }
    }
    // Handle key up events for vim navigation keys
    else if ((caps_key_down || vim_mode_locked) && type == kCGEventKeyUp && vim_mode_active) {
        // Create a new event source for better event handling
        CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
        if (!source) {
            return event;
        }
        
        // If this is a CapsLock release and we're not in locked mode, we'll exit vim mode
        if (keycode == KEYCODE_SECTION && !vim_mode_locked) {
            vim_mode_active = false;
            if (debug_mode) {
                printf("Vim navigation mode deactivated\n");
            }
        }
        
        CGKeyCode new_keycode = 0;
        bool should_remap = true;
        
        // Map keys to vim navigation (same mapping as for key down)
        switch (keycode) {
            case KEYCODE_H: new_keycode = KEYCODE_LEFT_ARROW; break;
            case KEYCODE_J: new_keycode = KEYCODE_DOWN_ARROW; break;
            case KEYCODE_K: new_keycode = KEYCODE_UP_ARROW; break;
            case KEYCODE_L: new_keycode = KEYCODE_RIGHT_ARROW; break;
            case KEYCODE_I: 
                // If i is pressed and vim mode is locked, we need to check if shift is pressed
                if (vim_mode_locked) {
                    CGEventFlags flags = CGEventGetFlags(event);
                    bool shift_pressed = (flags & kCGEventFlagMaskShift) != 0;
                    
                    // Only remap to Page Up if Shift is not pressed
                    if (!shift_pressed) {
                        new_keycode = KEYCODE_PAGE_UP;
                    } else {
                        should_remap = false;
                    }
                    break;
                }
                new_keycode = KEYCODE_PAGE_UP; 
                break;
            case KEYCODE_O: new_keycode = KEYCODE_PAGE_DOWN; break;
            case KEYCODE_COMMA: new_keycode = KEYCODE_HOME; break;
            case KEYCODE_PERIOD: new_keycode = KEYCODE_END; break;
            default: should_remap = false; break;
        }
        
        if (should_remap) {
            if (debug_mode) {
                printf("Sending key up event for remapped key: %d\n", (int)new_keycode);
            }
            
            // Create a new event with the remapped keycode (key up)
            CGEventRef new_event = CGEventCreateKeyboardEvent(source, new_keycode, false);
            CGEventSetFlags(new_event, CGEventGetFlags(event));
            
            // Post the event directly to the HID system
            CGEventPost(kCGHIDEventTap, new_event);
            CFRelease(new_event);
            CFRelease(source);
            return NULL;
        }
        
        CFRelease(source);
    }
    
    //Control
    if(keycode == (CGKeyCode)59||keycode == (CGKeyCode)62){
        ctr = !ctr;
    }
    if(ctr){
        CGEventSetFlags(event,NX_CONTROLMASK|CGEventGetFlags(event));
    }
    //Shift
    if(keycode == (CGKeyCode)60||keycode == (CGKeyCode)56){
        sft = !sft;
    }
    if(sft){
        CGEventSetFlags(event,NX_SHIFTMASK|CGEventGetFlags(event));
    }
    //Command
    if(keycode == (CGKeyCode)55||keycode == (CGKeyCode)54){
        cmd = !cmd;
    }
    if(cmd){
        CGEventSetFlags(event,NX_COMMANDMASK|CGEventGetFlags(event));
    }
    //Option
    if(keycode == (CGKeyCode)58||keycode == (CGKeyCode)61){
        opt = !opt;
    }
    if(opt){
        CGEventSetFlags(event,NX_ALTERNATEMASK|CGEventGetFlags(event));
    }
    CGEventSetIntegerValueField(
        event, kCGKeyboardEventKeycode, (int64_t)keycode);

    // We must return the event for it to be useful.
    return event;
}

int
main(int argc, char* argv[])
{
    // Parse command line arguments
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--debug") == 0 || strcmp(argv[i], "-d") == 0) {
            debug_mode = true;
            if (!quiet_mode) {
                printf("Debug mode enabled\n");
            }
        } else if (strcmp(argv[i], "--quiet") == 0 || strcmp(argv[i], "-q") == 0) {
            quiet_mode = true;
        } else if (strcmp(argv[i], "--version") == 0 || strcmp(argv[i], "-v") == 0) {
            printf("DualKeyboard version %s\n", DUAL_VERSION);
            return 0;
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            printf("Usage: dual [OPTIONS]\n\n");
            printf("Options:\n");
            printf("  -d, --debug     Enable debug mode\n");
            printf("  -q, --quiet     Quiet mode, suppress non-error output\n");
            printf("  -v, --version   Show version information\n");
            printf("  -h, --help      Show this help message\n");
            return 0;
        }
    }
    
    // Ensure only one instance is running
    if (!ensure_single_instance()) {
        return 1;
    }
    
    // Set up signal handlers
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);

    // Set up CapsLock remapping
    setup_capslock_remapping();
    
    // Set up initial status bar display
    setup_status_bar();
    
    // Register the cleanup function to be called on program exit
    atexit(restore_capslock_mapping);

    CFMachPortRef      eventTap;
    CGEventMask        eventMask;
    CFRunLoopSourceRef runLoopSource;

    // Create an event tap. We are interested in key presses.
    eventMask = ((1 << kCGEventKeyDown) | (1 << kCGEventKeyUp) | (1 << kCGEventFlagsChanged));
    eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0,
                                eventMask, myCGEventCallback, NULL);
    if (!eventTap) {
        fprintf(stderr, "failed to create event tap\n");
        cleanup_and_exit();
        return 1;
    }

    // Create a run loop source.
    runLoopSource = CFMachPortCreateRunLoopSource(
                        kCFAllocatorDefault, eventTap, 0);

    // Add to the current run loop.
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource,
                       kCFRunLoopCommonModes);

    // Enable the event tap.
    CGEventTapEnable(eventTap, true);
    
    if (debug_mode) {
        printf("dual is running.\n");
        printf("Usage: dual [-debug] [-q|-quiet]\n\n");
        printf("Control shortcuts:\n");
        printf("- Press Escape + Control + Space to exit\n");
        printf("- Press Escape + 0 to restart the program\n");
        printf("\nVim navigation mode features:\n");
        printf("- Hold CapsLock and press h/j/k/l for arrow keys\n");
        printf("- Press Escape+1 or CapsLock+n to lock vim navigation mode\n");
        printf("- Press Escape, CapsLock, or Shift+I to exit vim navigation mode\n");
    }

    // Main event loop
    CFRunLoopRun();

    // Cleanup before exit
    cleanup_and_exit();
    return 0;
}

static void handle_signal(int signum) {
    cleanup_and_exit();
}