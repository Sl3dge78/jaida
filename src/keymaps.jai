
Key_Press_Proc :: #type (bool);
Keymap :: struct {
    proc : Key_Press_Proc;
    key : Input.Key_Code;
}

// @Todo : Make this useful in gameplay, and find a way to keep both separated
#if DEVELOPER {
    keymaps_storage :: Keymap.[
    Keymap.{Editor.toggle_editor,     .F1},
    Keymap.{Editor.save_map,          .F5},
    Keymap.{Editor.load_map,          .F9},
    Keymap.{Editor.toggle_editor_map, .TAB},
    Keymap.{Editor.layer_prev,        .F2},
    Keymap.{Editor.layer_next,        .F3},
    Keymap.{Editor.fill_layer,        #char "F"},
    Keymap.{Editor.map_left,   .ARROW_LEFT},
    Keymap.{Editor.map_right,  .ARROW_RIGHT},
    Keymap.{Editor.map_up,     .ARROW_UP},
    Keymap.{Editor.map_down,   .ARROW_DOWN},
    ];
} else {
    keymaps_storage : []Keymap;
}

keymap_handler :: (event : Input.Event) {
    if event.type == .KEYBOARD {
        for keymaps_storage {
            if it.key == event.key_code {
                it.proc(event.key_pressed == 1);
            }
        }
    }
}
