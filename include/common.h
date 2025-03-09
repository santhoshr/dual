#ifndef COMMON_H
#define COMMON_H

#include <ApplicationServices/ApplicationServices.h>
#include <time.h>  // For measuring time durations
#include <stdbool.h> // For boolean types
#include <stdio.h>  // For printf
#include <stdlib.h> // For system() and atexit()
#include <string.h> // For strcmp
#include <unistd.h> // For access() and getpid()
#include <signal.h> // For signal handling
#include <fcntl.h>  // For file operations
#include <sys/file.h> // For flock()
#include <sys/stat.h> // For chmod
#include <mach-o/dyld.h> // For _NSGetExecutablePath

// Define keycodes
#define KEYCODE_SECTION 10      // § symbol - CapsLock gets remapped to this
#define KEYCODE_ESCAPE 53
#define KEYCODE_LEFT_ARROW 123
#define KEYCODE_RIGHT_ARROW 124
#define KEYCODE_DOWN_ARROW 125
#define KEYCODE_UP_ARROW 126
#define KEYCODE_PAGE_UP 116
#define KEYCODE_PAGE_DOWN 121
#define KEYCODE_HOME 115
#define KEYCODE_END 119
#define KEYCODE_H 4
#define KEYCODE_J 38
#define KEYCODE_K 40
#define KEYCODE_L 37
#define KEYCODE_I 34
#define KEYCODE_O 31
#define KEYCODE_COMMA 43
#define KEYCODE_PERIOD 47
#define KEYCODE_SPACE 49
#define KEYCODE_ZERO 29        // 0 key
#define KEYCODE_ONE 18         // 1 key
#define KEYCODE_N 45           // N key
#define KEYCODE_MINUS 27       // - key

// Global variables
extern bool debug_mode;
extern bool quiet_mode;
extern int lock_fd;
extern bool should_restart;

// Lock file path for single instance protection
#define LOCK_FILE "/tmp/dual.lock"

// Function declarations
bool ensure_single_instance(void);
void cleanup_single_instance(void);

// Common functions
void cleanup_and_exit();
void signal_handler(int signum);
bool is_another_instance_running();
void debug_print_key(CGKeyCode keycode, CGEventType type);
uint64_t get_current_time_ns();

#endif // COMMON_H