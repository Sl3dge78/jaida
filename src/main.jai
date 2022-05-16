Basic :: #import "Basic";
Window_Creation :: #import "Window_Creation";
Simp :: #import "Simp";
Input :: #import "Input";
Math :: #import "Math";
X11 :: #import "X11";
using Math;
#import "GL";

PRINT_SCANCODES :: true;
TILE_SIZE :: 16;
TILE_HALF :: TILE_SIZE / 2;
ZOOM :: 2;
PLAYER_SPEED :: 100.0;

// @Release : remember to remove the print in Input/x11.jai !!
Scan_Code :: enum u32 {
    W :: 25;
    A :: 38;
    S :: 39;
    D :: 40;
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
}

// @Speed : We can build an array at startup of translations Scan_Code -> Key_Codes
get_keycode_from_scancode :: (scancode: Scan_Code) -> Input.Key_Code {
    keysym := X11.XkbKeycodeToKeysym(X11.x_global_display, xx scancode, 0, 0);
    return Input.get_key_code(keysym);
}

Game_State :: struct {
    player_pos : Vector2 = .{16,16};
    player_texture : Simp.Texture;
}

from_index_to_vector2 :: inline (index : int, width : int) -> x : int, y : int {
    return x = index % width, y = index / width;
}

get_uv_from_texture :: (texture : Simp.Texture, tile_x : int, tile_y : int) -> uv0 : Vector2, uv1 : Vector2 {
    nb_tiles_width := texture.width / 16;
    nb_tiles_height := texture.height / 16;

    flipped_y := nb_tiles_height - tile_y;
    uv0 := Math.xy(cast(float)tile_x / cast(float)nb_tiles_width, cast(float)(flipped_y-1) / cast(float)nb_tiles_height);
    uv1 := Math.xy(cast(float)(tile_x+1) / cast(float)nb_tiles_width, cast(float)flipped_y / cast(float)nb_tiles_height);
    return uv0, uv1;
}

immediate_tile :: (pos : Vector2, uv0: Vector2, uv1 : Vector2) {

    p0 := pos; p0.x -= TILE_HALF * ZOOM; p0.y -= TILE_HALF * ZOOM;
    p1 := pos; p1.x += TILE_HALF * ZOOM; p1.y -= TILE_HALF * ZOOM;
    p2 := pos; p2.x += TILE_HALF * ZOOM; p2.y += TILE_HALF * ZOOM;
    p3 := pos; p3.x -= TILE_HALF * ZOOM; p3.y += TILE_HALF * ZOOM;

    uvx := uv0;
    uvx.x = uv1.x;

    uvy := uv0;
    uvy.y = uv1.y;

    Simp.immediate_quad(p0  = p0,  p1  = p1,  p2  = p2,  p3  = p3,
                        uv0 = uv0, uv1 = uvx , uv2 = uv1, uv3 = uvy);
}

load_texture :: (texture : *Simp.Texture, path : string) {
    success := Simp.texture_load_from_file(texture, path);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    if !success {
        Basic.log_error("Unable to load %", path);
        Basic.assert(success);
    }
}

main :: () {
    Basic.init_time();

    window := Window_Creation.create_window(1280, 720, "Zelda");

    window_width, window_height := Simp.get_render_dimensions(window);
    Simp.set_render_target(window);

    // Load 
    game_state : Game_State;
    load_texture(*game_state.player_texture, "res/SpriteSheet.png");
    Basic.print("Hello!\n");
    
    quit := false;
    last_time := Basic.get_time();
    while !quit {
        now := Basic.get_time();
        delta_time : float = cast(float) (now - last_time);
        last_time = now;

        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);
            if it.window == window {
                window_width = it.width;
                window_height = it.height;
            }
        }

        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;
        }

        player_vel : Vector2;
        if Input.input_button_states[get_keycode_from_scancode(.W)] == .DOWN {
            player_vel.y += 1;
        }        
        if Input.input_button_states[get_keycode_from_scancode(.S)] == .DOWN {
            player_vel.y -= 1;
        } 
        if Input.input_button_states[get_keycode_from_scancode(.A)] == .DOWN {
            player_vel.x -= 1;
        }
        if Input.input_button_states[get_keycode_from_scancode(.D)] == .DOWN {
            player_vel.x += 1;
        } 
        game_state.player_pos += Math.unit_vector(player_vel) * (delta_time * PLAYER_SPEED);

        Simp.clear_render_target(0, 0, 0, 1);
        
        Simp.set_shader_for_images(*game_state.player_texture);
        Simp.immediate_begin();
        uv0, uv1 := get_uv_from_texture(game_state.player_texture, 0, 0);
        immediate_tile(game_state.player_pos, uv0, uv1);
        Simp.immediate_flush();

        Simp.swap_buffers(window);
        Basic.reset_temporary_storage();
    }
}
