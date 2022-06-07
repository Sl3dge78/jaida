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
    };

    Direction :: enum u8 {
        SOUTH :: 0;
        NORTH :: 1;
        WEST :: 2;
        EAST :: 3;
    };
    state : State = .GAME;
    screen_width : s32;
    screen_height : s32;
    player_pos : Vector2 = .{20, 11};
    player_texture : Renderer.Texture;
    player_direction : Direction;
    player_anim_time : float32;
    current_map : Map;
    world_pos : Vector2 = .{0, 0};
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
    return result;
}


move_and_slide :: (current_pos : Vector2, velocity : Vector2, map : Map) -> Vector2 {
    result : Vector2 = current_pos;
    new_center_x := current_pos + xy(velocity.x, 0);
    new_center_y := current_pos + xy(0, velocity.y);
    // Try to move on x
    // @Speed : Get the sign of the velocity, to check only 1 side
    // @Hardcoded : Specify the size of the sprite?
    if  Map.get_collision_at(context.game_state.current_map, new_center_x + Vector2.{ 0.4,  0.0}) == 0 &&
        Map.get_collision_at(context.game_state.current_map, new_center_x + Vector2.{-0.4,  0.0}) == 0 &&
        Map.get_collision_at(context.game_state.current_map, new_center_x + Vector2.{ 0.4, -0.4}) == 0 &&
        Map.get_collision_at(context.game_state.current_map, new_center_x + Vector2.{-0.4, -0.4}) == 0 {
            result.x += velocity.x;
    }

    if  Map.get_collision_at(context.game_state.current_map, new_center_y + Vector2.{ 0.4,  0.0}) == 0 &&
        Map.get_collision_at(context.game_state.current_map, new_center_y + Vector2.{ 0.4, -0.5}) == 0 &&
        Map.get_collision_at(context.game_state.current_map, new_center_y + Vector2.{-0.4,  0.0}) == 0 &&
        Map.get_collision_at(context.game_state.current_map, new_center_y + Vector2.{-0.4, -0.5}) == 0 {
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
    Map.load(context.game_state.current_map, context.game_state.world_pos);

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
                context.game_state.player_direction = .NORTH;
            }        
            if Input.get_keyboard(SDL_SCANCODE_A) {
                player_vel.x -= 1;
                context.game_state.player_direction = .WEST;
            }
            if Input.get_keyboard(SDL_SCANCODE_S) {
                player_vel.y -= 1;
                context.game_state.player_direction = .SOUTH;
            } 
            if Input.get_keyboard(SDL_SCANCODE_D) {
                player_vel.x += 1;
                context.game_state.player_direction = .EAST;
            } 
            final_vel := Math.unit_vector(player_vel) * (delta_time * PLAYER_SPEED);
            if length(final_vel) > 0 {
                context.game_state.player_anim_time += delta_time;
            } else {
                context.game_state.player_anim_time = 0.0;
            }
            if context.game_state.player_anim_time > 1.0 then context.game_state.player_anim_time = 0.0;
            context.game_state.player_pos = move_and_slide(context.game_state.player_pos, final_vel, context.game_state.current_map);

            Basic.log("%", context.game_state.player_pos);

            // World movement
            world_movement : Vector2;
            if context.game_state.player_pos.x < 0              then world_movement -= Vector2.{1, 0};
            if context.game_state.player_pos.x > MAP_WIDTH - 1  then world_movement += Vector2.{1, 0};
            if context.game_state.player_pos.y < 0.1            then world_movement -= Vector2.{0, 1};
            if context.game_state.player_pos.y > MAP_HEIGHT - 1 then world_movement += Vector2.{0, 1};
            if Math.length(world_movement) > 0 {
                if Map.exists(context.game_state.world_pos + world_movement) {
                    context.game_state.world_pos += world_movement;
                    Map.load(context.game_state.current_map, context.game_state.world_pos);
                    if world_movement.x < 0 then context.game_state.player_pos.x = MAP_WIDTH - 1;
                    if world_movement.x > 0 then context.game_state.player_pos.x = 0;
                    if world_movement.y < 0 then context.game_state.player_pos.y = MAP_HEIGHT - 1;
                    if world_movement.y > 0 then context.game_state.player_pos.y = 0.1;
                }
            }
        }
        
        if context.game_state.state == .EDITOR {
            Editor.update();
        }

        // --------
        // Drawing

        if context.game_state.state == .GAME {
            Renderer.clear_render_target(0, 0, 0, 1);
        } else {
            Renderer.clear_render_target(0.5, 0, 0, 1);
        }

        Map.draw_layer(0, context.game_state.current_map, *context.game_state.map_texture, context.game_state.camera_position);
        layer_separator(0);
        Map.draw_layer(1, context.game_state.current_map, *context.game_state.map_texture, context.game_state.camera_position);
        layer_separator(1);

        // Player
        Renderer.set_shader_for_images(*context.game_state.player_texture);
        x0, y0 := world_to_screen(context.game_state.camera_position, context.game_state.player_pos + Vector2.{-0.5, -0.5});
        x1, y1 := world_to_screen(context.game_state.camera_position, context.game_state.player_pos + Vector2.{+0.5, +0.5});
        y : int = xx (context.game_state.player_anim_time * 4);
        uv0, uv1 := get_uv_from_texture(*context.game_state.player_texture, xx context.game_state.player_direction, 6 - y);
        Renderer.immediate_quad(x0 = xx x0, y0 = xx y0, x1 = xx x1, y1 = xx y1, uv0 = uv0, uv1 = uv1);

        Map.draw_layer(2, context.game_state.current_map, *context.game_state.map_texture, context.game_state.camera_position);

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
