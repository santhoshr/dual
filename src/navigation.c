#include "../include/navigation.h"
#include "../include/common.h"

// Global state variables
bool vim_mode_active = false;
bool vim_mode_locked = false;

// Key state tracking
bool escape_pressed = false;
bool control_pressed = false;
bool space_pressed = false;
bool zero_pressed = false;
bool minus_pressed = false;  // Initialize minus key state

// Modifier key states
bool ctr = false;
bool sft = false;
bool cmd = false;
bool opt = false;