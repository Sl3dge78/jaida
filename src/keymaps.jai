
Key_Press_Proc :: #type (bool);
Keymap :: struct {
    proc : Key_Press_Proc;
    key : SDL_Scancode;
}

keymaps_storage :: Keymap.[
    Keymap.{Editor.toggle_editor,     SDL_SCANCODE_F1},
    Keymap.{Editor.save_map,          SDL_SCANCODE_F5},
    Keymap.{Editor.load_map,          SDL_SCANCODE_F9},
    Keymap.{Editor.toggle_editor_map, SDL_SCANCODE_TAB},
    Keymap.{Editor.layer_prev,        SDL_SCANCODE_1},
    Keymap.{Editor.layer_next,        SDL_SCANCODE_2},
    Keymap.{Editor.map_left,   SDL_SCANCODE_LEFT},
    Keymap.{Editor.map_right,  SDL_SCANCODE_RIGHT},
    Keymap.{Editor.map_up,     SDL_SCANCODE_UP},
    Keymap.{Editor.map_down,   SDL_SCANCODE_DOWN},
    ];

keymap_handler :: (event : *SDL_Event) {
    if event.type == SDL_KEYUP || event.type == SDL_KEYDOWN {
        for keymaps_storage {
            if it.key == event.key.keysym.scancode {
                it.proc(event.type == SDL_KEYDOWN);
            }
        }
    }
}
