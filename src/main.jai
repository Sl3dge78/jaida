Basic :: #import "Basic";
Math :: #import "Math";
using Math; // To import operator overloading
libc :: #foreign_system_library "libm";
round :: (val : float32) -> float32 #foreign libc "roundf";

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
PLAYER_SPEED :: 5.0;

Game_State :: struct {
    State :: enum {
        GAME;
        EDITOR;
    }
    state : State = .GAME;
    screen_width : s32;
    screen_height : s32;
    player_pos : Vector2 = .{0,0};
    player_texture : Renderer.Texture;
    map : Map;
    map_texture : Renderer.Texture;
    camera_position : Vector2 = .{0.5, 0.75};
}

#add_context game_state : Game_State;

Key_Press_Proc :: #type (bool);
Keymap :: struct {
    proc : Key_Press_Proc;
    key : SDL_Scancode;
}

keymaps_storage :: Keymap.[
    Keymap.{toggle_editor, SDL_SCANCODE_F1},
    Keymap.{save_map, SDL_SCANCODE_F5},
    Keymap.{load_map, SDL_SCANCODE_F9},
    Keymap.{toggle_editor_map, SDL_SCANCODE_TAB},
    Keymap.{layer_prev, SDL_SCANCODE_1},
    Keymap.{layer_next, SDL_SCANCODE_2},
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

save_map :: (down : bool) {
    if down Map.save(context.game_state.map);
}

load_map :: (down : bool) {
    if down Map.load(context.game_state.map);
}

toggle_editor :: (down : bool) {
    if !down return;

    context.game_state.state = ifx context.game_state.state == .GAME then Game_State.State.EDITOR else .GAME;
    if context.game_state.state == .GAME {
        Basic.log("Editor off");
    } else {
        Basic.log("Editor on");
    }
}

toggle_editor_map :: (down : bool) {
    if !down return;
    context.editor.show_map = !context.editor.show_map;
}

layer_prev :: (down : bool) {
    if !down return;
    if context.game_state.state != .EDITOR return;
    if context.editor.current_layer > 0 then context.editor.current_layer -= 1;
    Basic.log("Layer : %", context.editor.current_layer);
}

layer_next :: (down : bool) {
    if !down return;
    if context.game_state.state != .EDITOR return;
    if context.editor.current_layer < MAP_LAYERS-1 then context.editor.current_layer += 1;
    Basic.log("Layer : %", context.editor.current_layer);
}

world_to_screen :: inline (cam : Vector2, pos : Vector2) -> x : int, y : int {
    x : int = xx ((pos.x + cam.x) * TILE_SIZE * ZOOM);
    y : int = xx ((pos.y + cam.y) * TILE_SIZE * ZOOM);
    return x, y;
}

screen_to_world :: inline (cam : Vector2, x : int, y : int) -> Vector2 {
    result := xy(xx x, xx y);
    result /= cast(float32)(TILE_SIZE * ZOOM);
    result -= cam;
    result += Vector2.{0.5, 0.5};
    Basic.log("%", result);
    return result;
}


move_and_slide :: (current_pos : Vector2, velocity : Vector2, map : Map) -> Vector2 {
    result : Vector2 = current_pos;
    new_center_x := current_pos + xy(velocity.x, 0);
    new_center_y := current_pos + xy(0, velocity.y);
    // Try to move on x
    // @Speed : Get the sign of the velocity, to check only 1 side
    // @Hardcoded : Specify the size of the sprite?
    if  Map.get_collision_at(context.game_state.map, new_center_x + Vector2.{ 0.4,  0.}) == 0 &&
        Map.get_collision_at(context.game_state.map, new_center_x + Vector2.{-0.4,  0.}) == 0 &&
        Map.get_collision_at(context.game_state.map, new_center_x + Vector2.{ 0.4, -0.5}) == 0 &&
        Map.get_collision_at(context.game_state.map, new_center_x + Vector2.{-0.4, -0.5}) == 0 {
            result.x += velocity.x;
    }

    if  Map.get_collision_at(context.game_state.map, new_center_y + Vector2.{ 0.4,  0.}) == 0 &&
        Map.get_collision_at(context.game_state.map, new_center_y + Vector2.{ 0.4, -0.5}) == 0 &&
        Map.get_collision_at(context.game_state.map, new_center_y + Vector2.{-0.4,  0.}) == 0 &&
        Map.get_collision_at(context.game_state.map, new_center_y + Vector2.{-0.4, -0.5}) == 0 {
            result.y += velocity.y;
    }

    return result;
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

    // Note: Game_State and Editor are added to the context where they are defined.

    // Load 
    w, h : s32 = ---;
    SDL_GetWindowSize(window, *context.game_state.screen_width, *context.game_state.screen_height);
    Renderer.load_texture(*context.game_state.player_texture, "res/blue_samurai.png");
    Renderer.load_texture(*context.game_state.map_texture, "res/world.png");
    Map.load(context.game_state.map);

    quit := false;
    last_time := Basic.get_time();
    while !quit {
        now := Basic.get_time();
        delta_time : float = cast(float) (now - last_time);
        last_time = now;

        Input.begin_frame(context.game_state.screen_height);

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
            };
            if context.game_state.state == .EDITOR {
                if event.type == {
                    case SDL_MOUSEBUTTONUP;
                        if event.button.button == SDL_BUTTON_LEFT {
                            if context.editor.show_map {
                                if Input.mouse_x < context.game_state.screen_width / 2 { // Clicking on the map
                                    tile_x := Input.mouse_x / TILE_SIZE / context.editor.zoom - context.editor.offset_x;
                                    tile_y := Input.mouse_y / TILE_SIZE / context.editor.zoom - context.editor.offset_y;
                                    context.editor.selected_tile = xy_to_tile_id(*context.game_state.map_texture, xx tile_x, xx tile_y);
                                }
                            }
                        }
                }
            }
            keymap_handler(*event);
        }

        if context.game_state.state == .GAME {
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
            final_vel := Math.unit_vector(player_vel) * (delta_time * PLAYER_SPEED);
            
            context.game_state.player_pos = move_and_slide(context.game_state.player_pos, final_vel, context.game_state.map);
        }
        
        if context.game_state.state == .EDITOR {
            Editor.update();
        }

        if context.game_state.state == .GAME {
            Renderer.clear_render_target(0, 0, 0, 1);
        } else {
            Renderer.clear_render_target(0.5, 0, 0, 1);
        }

        Map.draw_layer(0, context.game_state.map, *context.game_state.map_texture, context.game_state.camera_position);
        layer_separator(0);
        Map.draw_layer(1, context.game_state.map, *context.game_state.map_texture, context.game_state.camera_position);
        layer_separator(1);

        // Player
        Renderer.set_shader_for_images(*context.game_state.player_texture);
        x0, y0 := world_to_screen(context.game_state.camera_position, context.game_state.player_pos + Vector2.{-0.5, -0.5});
        x1, y1 := world_to_screen(context.game_state.camera_position, context.game_state.player_pos + Vector2.{+0.5, +0.5});
        uv0, uv1 := get_uv_from_texture(*context.game_state.player_texture, 0, 6);
        Renderer.immediate_quad(x0 = xx x0, y0 = xx y0, x1 = xx x1, y1 = xx y1, uv0 = uv0, uv1 = uv1);

        Map.draw_layer(2, context.game_state.map, *context.game_state.map_texture, context.game_state.camera_position);

        if context.game_state.state == .EDITOR {
            Editor.draw();
        }

        Renderer.swap_buffers(window);
        Basic.reset_temporary_storage();
    }
}

layer_separator :: (layer : int) {
    if context.game_state.state == .EDITOR && context.editor.current_layer > layer {
        Renderer.set_shader_for_color();
        Renderer.immediate_quad(x0 = xx 0, y0 = xx 0, x1 = xx context.game_state.screen_width, y1 = xx context.game_state.screen_height, color = .{1, 1, 1, 0.5});
    }
}
