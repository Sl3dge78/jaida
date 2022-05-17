
// module/Input works with localized keyboard symbols.
// This means that 'W' will change location depending on the keyboard. 
// We use the trick below to avoid that.

// @Release : remember to remove the print in Input/x11.jai !!
Scan_Code :: enum u32 {
    KEY_1 :: 10;
    KEY_2 :: 11;
    KEY_3 :: 12;
    KEY_4 :: 13;
    KEY_5 :: 14;
    KEY_6 :: 15;
    KEY_7 :: 16;
    KEY_8 :: 17;
    KEY_9 :: 18;
    KEY_10 :: 19;
    Q :: 24;
    W :: 25;
    E :: 26;
    A :: 38;
    S :: 39;
    D :: 40;
}

// @Speed : We can build an array at startup of translations Scan_Code -> Key_Codes
get_keycode_from_scancode :: (scancode: Scan_Code) -> Input.Key_Code {
    keysym := X11.XkbKeycodeToKeysym(X11.x_global_display, xx scancode, 0, 0);
    return Input.get_key_code(keysym);
}
