#include "../include/termstatus.h"

// Current mode
static char current_mode = MODE_INSERT;

void setup_status_bar() {
    if (quiet_mode) return;
    
    printf("\033[1;36mDual Keyboard Start\033[0m\n");
    printf("Current Mode: \033[1;32m%c\033[0m | Debug: \033[1;33m%s\033[0m\n", 
           current_mode, debug_mode ? "ON" : "OFF");
    fflush(stdout);
}

void update_status_msg(char mode) {
    if (mode != MODE_INSERT && mode != MODE_NAVIGATION) {
        return;
    }

    // Only update if the mode has changed
    if (mode == current_mode) {
        return;
    }

    current_mode = mode;
    
    if (!quiet_mode) {
        printf("\033[1;33mMode Changed\033[0m -> Current: \033[1;32m%c\033[0m | Debug: \033[1;33m%s\033[0m\n",
               current_mode, debug_mode ? "ON" : "OFF");
        fflush(stdout);
    }
}

void cleanup_status_bar() {
    if (quiet_mode) return;
    
    printf("\n\033[1;31mDual Keyboard Exit\033[0m\n");
    printf("Final Mode: \033[1;32m%c\033[0m | Debug: \033[1;33m%s\033[0m\n",
           current_mode, debug_mode ? "ON" : "OFF");
    fflush(stdout);
} 