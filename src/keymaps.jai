
Key_Press_Proc :: #type (bool);
Keymap :: struct {
    proc : Key_Press_Proc;
    key : Input.Key_Code;
}

keymaps_storage :: Keymap.[
    Keymap.{Editor.toggle_editor,     .F1},
    Keymap.{Editor.save_map,          .F5},
    Keymap.{Editor.load_map,          .F9},
    Keymap.{Editor.toggle_editor_map, .TAB},
    Keymap.{Editor.layer_prev,        .PAGE_UP},
    Keymap.{Editor.layer_next,        .PAGE_DOWN},
    Keymap.{Editor.map_left,   .ARROW_LEFT},
    Keymap.{Editor.map_right,  .ARROW_RIGHT},
    Keymap.{Editor.map_up,     .ARROW_UP},
    Keymap.{Editor.map_down,   .ARROW_DOWN},
    ];

keymap_handler :: (event : Input.Event) {
    if event.type == .KEYBOARD {
        for keymaps_storage {
            if it.key == event.key_code {
                it.proc(event.key_pressed == 1);
            }
        }
    }
}
