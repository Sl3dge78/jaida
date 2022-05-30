#import "SDL";

current_keyboard : [SDL_NUM_SCANCODES]u8 = ---;
previous_keyboard : [SDL_NUM_SCANCODES]u8 = ---;

mouse_state : u32 = ---;
mouse_x, mouse_y : s32 = ---;

previous_mouse_state : u32 = ---;
previous_mouse_x, previous_mouse_y : s32 = ---;

begin_frame :: (window_height : s32) {
    // @Temporary : Find a better way to handle the inversion of the y coordinate.
    memcpy(previous_keyboard.data, current_keyboard.data, xx SDL_NUM_SCANCODES * size_of(u8));
    keyboard := SDL_GetKeyboardState(null);
    memcpy(current_keyboard.data, keyboard, xx SDL_NUM_SCANCODES * size_of(u8));

    previous_mouse_state = mouse_state;
    previous_mouse_x = mouse_x;
    previous_mouse_y = mouse_y;
    mouse_state = SDL_GetMouseState(*mouse_x, *mouse_y);
    mouse_y = window_height - mouse_y;
}

get_keyboard :: inline (scancode : SDL_Scancode) -> bool {
    return xx current_keyboard[scancode];
}

pressed_this_frame :: inline (scancode : SDL_Scancode) -> bool {
    return current_keyboard[scancode] == 1 && previous_keyboard[scancode] == 0;
}

get_mouse_button :: inline (button : int) -> bool {
    return (mouse_state & SDL_BUTTON(button)) == 1;
}
