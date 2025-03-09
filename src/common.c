#include "../include/common.h"
#include "../include/capslock.h"
#include "../include/navigation.h"
#include "../include/termstatus.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>

// Global variables
bool debug_mode = false;
bool quiet_mode = false;  // Initialize quiet mode flag
bool should_restart = false;

// Lock file path for single instance check
#define LOCK_FILE "/tmp/dual.lock"
int lock_fd = -1;

// Function to clean up resources before exit
void cleanup_and_exit() {
    // Restore original keyboard mapping
    restore_capslock_mapping();
    
    // Clean up status bar
    cleanup_status_bar();
    
    // Release the lock file
    if (lock_fd != -1) {
        flock(lock_fd, LOCK_UN);
        close(lock_fd);
        unlink(LOCK_FILE);
    }
    
    if (debug_mode) {
        printf("Exiting dual program...\n");
        if (should_restart) {
            printf("Restarting program...\n");
        }
    }
    
    // If restart is requested, restart the program
    if (should_restart) {
        // Get the path to the current executable
        char path[1024];
        uint32_t size = sizeof(path);
        if (_NSGetExecutablePath(path, &size) == 0) {
            // Prepare arguments
            char *args[4];  // Increased size to accommodate quiet flag
            args[0] = path;
            int arg_index = 1;
            
            if (debug_mode) {
                args[arg_index++] = "-debug";
            }
            if (quiet_mode) {
                args[arg_index++] = "-q";
            }
            args[arg_index] = NULL;
            
            // Execute the program
            execv(path, args);
            
            // If execv fails, print error
            perror("Failed to restart program");
        } else {
            fprintf(stderr, "Failed to get executable path\n");
        }
    }
    
    exit(0);
}

// Signal handler for graceful termination
void signal_handler(int signum) {
    if (debug_mode) {
        printf("Received signal %d, exiting...\n", signum);
    }
    cleanup_and_exit();
}

// Function to check if another instance is running
bool is_another_instance_running() {
    // Create or open the lock file
    lock_fd = open(LOCK_FILE, O_CREAT | O_RDWR, 0666);
    if (lock_fd == -1) {
        perror("Failed to open lock file");
        return false; // Assume no other instance is running if we can't check
    }
    
    // Try to get an exclusive lock
    if (flock(lock_fd, LOCK_EX | LOCK_NB) == -1) {
        // Another instance has the lock
        close(lock_fd);
        lock_fd = -1;
        return true;
    }
    
    // Write PID to lock file
    char pid_str[16];
    sprintf(pid_str, "%d\n", getpid());
    ftruncate(lock_fd, 0);
    write(lock_fd, pid_str, strlen(pid_str));
    
    // We got the lock, no other instance is running
    return false;
}

// Function to print keycode information in debug mode
void debug_print_key(CGKeyCode keycode, CGEventType type) {
    if (!debug_mode) return;
    
    const char* event_type = "";
    if (type == kCGEventKeyDown) event_type = "KeyDown";
    else if (type == kCGEventKeyUp) event_type = "KeyUp";
    else if (type == kCGEventFlagsChanged) event_type = "FlagsChanged";
    
    char* key_name = "";
    switch (keycode) {
        case KEYCODE_SECTION: key_name = "Section § (10) [CapsLock remapped]"; break;
        case KEYCODE_ESCAPE: key_name = "Escape (53)"; break;
        case KEYCODE_LEFT_ARROW: key_name = "LeftArrow (123)"; break;
        case KEYCODE_RIGHT_ARROW: key_name = "RightArrow (124)"; break;
        case KEYCODE_DOWN_ARROW: key_name = "DownArrow (125)"; break;
        case KEYCODE_UP_ARROW: key_name = "UpArrow (126)"; break;
        case KEYCODE_PAGE_UP: key_name = "PageUp (116)"; break;
        case KEYCODE_PAGE_DOWN: key_name = "PageDown (121)"; break;
        case KEYCODE_HOME: key_name = "Home (115)"; break;
        case KEYCODE_END: key_name = "End (119)"; break;
        case KEYCODE_H: key_name = "H (4)"; break;
        case KEYCODE_J: key_name = "J (38)"; break;
        case KEYCODE_K: key_name = "K (40)"; break;
        case KEYCODE_L: key_name = "L (37)"; break;
        case KEYCODE_I: key_name = "I (34)"; break;
        case KEYCODE_O: key_name = "O (31)"; break;
        case KEYCODE_COMMA: key_name = "Comma (43)"; break;
        case KEYCODE_PERIOD: key_name = "Period (47)"; break;
        default: key_name = ""; break;
    }
    
    printf("Event: %s, KeyCode: %d %s\n", event_type, (int)keycode, key_name);
}

// Get current time in nanoseconds
uint64_t get_current_time_ns() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

bool ensure_single_instance(void) {
    // Try to open or create the lock file
    lock_fd = open(LOCK_FILE, O_CREAT | O_RDWR, 0666);
    if (lock_fd == -1) {
        fprintf(stderr, "Error creating lock file: %s\n", strerror(errno));
        return false;
    }

    // Try to acquire an exclusive lock
    struct flock fl = {
        .l_type = F_WRLCK,
        .l_whence = SEEK_SET,
        .l_start = 0,
        .l_len = 0
    };

    if (fcntl(lock_fd, F_SETLK, &fl) == -1) {
        if (errno == EACCES || errno == EAGAIN) {
            fprintf(stderr, "Another instance of Dual is already running.\n");
        } else {
            fprintf(stderr, "Error locking file: %s\n", strerror(errno));
        }
        close(lock_fd);
        return false;
    }

    // Write PID to lock file
    char pid_str[16];
    sprintf(pid_str, "%d\n", getpid());
    if (write(lock_fd, pid_str, strlen(pid_str)) == -1) {
        fprintf(stderr, "Error writing to lock file: %s\n", strerror(errno));
        // Not a critical error, continue anyway
    }

    return true;
}

void cleanup_single_instance(void) {
    if (lock_fd != -1) {
        // Release the lock and close the file
        close(lock_fd);
        // Remove the lock file
        unlink(LOCK_FILE);
    }
}