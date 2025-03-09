#ifndef NAVIGATION_H
#define NAVIGATION_H

#include <stdbool.h>
#include <ApplicationServices/ApplicationServices.h>
#include "capslock.h"

// Time threshold for holding CapsLock to enter vim mode (in nanoseconds)
#define HOLD_THRESHOLD 150000000ULL // 150ms

// Global state variables
extern bool vim_mode_active;
extern bool vim_mode_locked;

// Key state tracking
extern bool escape_pressed;
extern bool control_pressed;
extern bool space_pressed;
extern bool zero_pressed;
extern bool minus_pressed;  // Track minus key state

// Modifier key states
extern bool ctr;
extern bool sft;
extern bool cmd;
extern bool opt;

#endif // NAVIGATION_H