Basic :: #import "Basic";
Math :: #import "Math";
using Math; // To import operator overloading

File :: #import "File";
#import "GL";
#import "SDL";

Renderer :: #import "Renderer";
Input :: #import "sInput";
#load "sprite.jai";
#load "map.jai";
#load "editor.jai";

TILE_SIZE :: 16;
TILE_HALF :: TILE_SIZE / 2;
ZOOM :: 2;
PLAYER_SPEED :: 100.0;

Game_State :: struct {
    State :: enum {
        GAME;
        EDITOR;
    }
    state : State = .GAME;
    screen_width : s32;
    screen_height : s32;
    player_pos : Vector2 = .{16,16};
    player_texture : Renderer.Texture;
    map : Map;
    map_texture : Renderer.Texture;
    camera_position : Vector2 = .{0, 8};
    editor : Editor;
}


Key_Press_Proc :: #type (* Game_State, bool);
Keymap :: struct {
    proc : Key_Press_Proc;
    key : SDL_Scancode;
}

keymaps_storage :: Keymap.[
    Keymap.{toggle_editor, SDL_SCANCODE_F1},
    Keymap.{save_map, SDL_SCANCODE_F5},
    Keymap.{load_map, SDL_SCANCODE_F9},
    // Keymap.{#run get_input_proc(toggle_editor_map), SDL_SCANCODE_TAB},
    Keymap.{toggle_editor_map, SDL_SCANCODE_TAB},
    ];

keymap_handler :: (event : *SDL_Event, game_state : *Game_State) {
    if event.type == SDL_KEYUP || event.type == SDL_KEYDOWN {
        for keymaps_storage {
            if it.key == event.key.keysym.scancode {
                it.proc(game_state, event.type == SDL_KEYDOWN);
            }
        }
    }
}

/*
@Todo : Try with #insert
Temp :: struct($input_proc : $R) {
    original_proc :: input_proc;

    editor_input :: (game_state : *Game_State, down : bool) {
        if game_state.state == .EDITOR original_proc(*game_state.editor, game_state, down);
    }

    game_input :: (game_state : *Game_State, down : bool) {
        original_proc(game_state, down);
    }
}

get_input_proc :: ($proc : $T) -> Key_Press_Proc {
    info := type_info(T);

    temp : Temp(proc);
    if info.argument_types.count == 3 
        return temp.editor_input;
    else 
        return temp.game_input;
}
*/

save_map :: (game_state : *Game_State, down : bool) {
    if down Map.save(game_state.map);
}

load_map :: (game_state : *Game_State, down : bool) {
    if down Map.load(game_state.map);
}

toggle_editor :: (game_state : *Game_State, down : bool) {
    if !down return;

    game_state.state = ifx game_state.state == .GAME then Game_State.State.EDITOR else .GAME;
    if game_state.state == .GAME {
        Basic.log("Editor off");
    } else {
        Basic.log("Editor on");
    }
}

toggle_editor_map :: (game_state : *Game_State, down : bool) {
    if !down return;
    game_state.editor.show_map = !game_state.editor.show_map;
}

main :: () {
    // Init
    Basic.init_time();
    SDL_Init(SDL_INIT_EVERYTHING);
    defer SDL_Quit();

    window := SDL_CreateWindow("Zelda", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1280, 720, SDL_WINDOW_OPENGL);
    if !window {
        Basic.log("%", Basic.to_string(SDL_GetError()));
        return;
    }
    defer SDL_DestroyWindow(window);

    Renderer.init(window);
    defer Renderer.deinit();

    // Load 
    game_state : Game_State;
    w, h : s32 = ---;
    SDL_GetWindowSize(window, *game_state.screen_width, *game_state.screen_height);
    Renderer.load_texture(*game_state.player_texture, "res/blue_samurai.png");
    Renderer.load_texture(*game_state.map_texture, "res/world.png");
    Map.load(game_state.map);

    quit := false;
    last_time := Basic.get_time();
    while !quit {
        now := Basic.get_time();
        delta_time : float = cast(float) (now - last_time);
        last_time = now;

        Input.begin_frame(game_state.screen_height);

        event : SDL_Event = ---;
        while SDL_PollEvent(*event) {
            if event.type == {
                case SDL_QUIT;
                    quit = true;
                case SDL_WINDOWEVENT; 
                    if event.window.event == {
                        case SDL_WINDOWEVENT_RESIZED; 
                            Renderer.update_window(window);
                    };
                case SDL_KEYUP;
                    if event.key.keysym.scancode == {
                        case SDL_SCANCODE_1;
                            game_state.editor.current_layer = 0;
                            Basic.log("Changed layer %", game_state.editor.current_layer);
                        case SDL_SCANCODE_2;
                            game_state.editor.current_layer = 1;
                            Basic.log("Changed layer %", game_state.editor.current_layer);
                        case SDL_SCANCODE_3;
                            game_state.editor.current_layer = 2;
                            Basic.log("Changed layer %", game_state.editor.current_layer);
                    };

            };
            if game_state.state == .EDITOR {
                if event.type == {
                    case SDL_MOUSEBUTTONUP;
                        if event.button.button == SDL_BUTTON_LEFT {
                            if game_state.editor.show_map {
                                if Input.mouse_x < game_state.screen_width / 2 { // Clicking on the map
                                    tile_x := Input.mouse_x / TILE_SIZE / game_state.editor.zoom - game_state.editor.offset_x;
                                    tile_y := Input.mouse_y / TILE_SIZE / game_state.editor.zoom - game_state.editor.offset_y;
                                    game_state.editor.selected_tile = xy_to_tile_id(*game_state.map_texture, xx tile_x, xx tile_y);
                                }
                            }
                        }
                }
            }
            keymap_handler(*event, *game_state);
        }

        if game_state.state == .GAME {
            player_vel : Vector2;
            if Input.get_keyboard(SDL_SCANCODE_W) {
                player_vel.y += 1;
            }        
            if Input.get_keyboard(SDL_SCANCODE_S) {
                player_vel.y -= 1;
            } 
            if Input.get_keyboard(SDL_SCANCODE_A) {
                player_vel.x -= 1;
            }
            if Input.get_keyboard(SDL_SCANCODE_D) {
                player_vel.x += 1;
            } 
            game_state.player_pos += Math.unit_vector(player_vel) * (delta_time * PLAYER_SPEED);
        }
        
        if game_state.state == .EDITOR {
            Editor.update(*game_state);
        }

        if game_state.state == .GAME {
            Renderer.clear_render_target(0, 0, 0, 1);
        } else {
            Renderer.clear_render_target(0.5, 0, 0, 1);
        }
        Map.draw(game_state.map, *game_state.map_texture, game_state.camera_position);
        
        // Player
        Renderer.set_shader_for_images(*game_state.player_texture);
        p0 := (game_state.player_pos * cast(float) ZOOM) + game_state.camera_position; p0.x -= TILE_HALF * ZOOM; p0.y -= TILE_HALF * ZOOM;
        p1 := (game_state.player_pos * cast(float) ZOOM) + game_state.camera_position; p1.x += TILE_HALF * ZOOM; p1.y += TILE_HALF * ZOOM;
        uv0, uv1 := get_uv_from_texture(*game_state.player_texture, 0, 6);
        Renderer.immediate_quad(x0 = p0.x, y0 = p0.y, x1 = p1.x, y1 = p1.y, uv0 = uv0, uv1 = uv1);

        if game_state.state == .EDITOR {
            Editor.draw(*game_state);
        }

        Renderer.swap_buffers(window);
        Basic.reset_temporary_storage();
    }
}


