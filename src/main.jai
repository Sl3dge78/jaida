Basic :: #import "Basic";
Window_Creation :: #import "Window_Creation";
Simp :: #import "Simp";
Input :: #import "Input";
Math :: #import "Math";
X11 :: #import "X11";
#import "GL";

#load "input.jai";

using Math;

TILE_SIZE :: 16;
TILE_HALF :: TILE_SIZE / 2;
ZOOM :: 2;
PLAYER_SPEED :: 100.0;
MAP_WIDTH :: 50;
MAP_HEIGHT :: 50;

Map :: [MAP_WIDTH*MAP_HEIGHT]u32;

Game_State :: struct {
    State :: enum {
        GAME;
        EDITOR;
    }
    state : State = .GAME;
    player_pos : Vector2 = .{16,16};
    player_texture : Simp.Texture;
    map : Map;
    map_texture : Simp.Texture;
}

from_index_to_vector2 :: inline (index : int, width : int) -> x : int, y : int {
    return x = index % width, y = index / width;
}

get_uv_from_texture :: (texture : *Simp.Texture, tile_x : int, tile_y : int) -> uv0 : Vector2, uv1 : Vector2 {
    nb_tiles_width := texture.width / TILE_SIZE;
    nb_tiles_height := texture.height / TILE_SIZE;

    flipped_y := nb_tiles_height - tile_y;
    uv0 := Math.xy(cast(float)tile_x / cast(float)nb_tiles_width, cast(float)(flipped_y-1) / cast(float)nb_tiles_height);
    uv1 := Math.xy(cast(float)(tile_x+1) / cast(float)nb_tiles_width, cast(float)flipped_y / cast(float)nb_tiles_height);
    return uv0, uv1;
}

get_uv_from_texture :: (texture : *Simp.Texture, tile : int) -> uv0 : Vector2, uv1 : Vector2 {
    nb_tiles_width := texture.width / TILE_SIZE;
    nb_tiles_height := texture.height / TILE_SIZE;
    tile_x := tile % nb_tiles_width;
    tile_y := tile / nb_tiles_width;

    flipped_y := nb_tiles_height - tile_y;
    uv0 := Math.xy(cast(float)tile_x / cast(float)nb_tiles_width, cast(float)(flipped_y-1) / cast(float)nb_tiles_height);
    uv1 := Math.xy(cast(float)(tile_x+1) / cast(float)nb_tiles_width, cast(float)flipped_y / cast(float)nb_tiles_height);
    return uv0, uv1;
}

xy_to_tile_id :: (texture : *Simp.Texture, x : u32, y : u32) -> tile_id : u32 {
    nb_tiles_width := texture.width / TILE_SIZE;
    return xx x + y * xx nb_tiles_width;
}

immediate_tile :: (pos : Vector2, uv0: Vector2, uv1 : Vector2) {
    p0 := pos * cast(float) ZOOM; p0.x -= TILE_HALF * ZOOM; p0.y -= TILE_HALF * ZOOM;
    p1 := pos * cast(float) ZOOM; p1.x += TILE_HALF * ZOOM; p1.y -= TILE_HALF * ZOOM;
    p2 := pos * cast(float) ZOOM; p2.x += TILE_HALF * ZOOM; p2.y += TILE_HALF * ZOOM;
    p3 := pos * cast(float) ZOOM; p3.x -= TILE_HALF * ZOOM; p3.y += TILE_HALF * ZOOM;

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
    load_texture(*game_state.map_texture, "res/world.png");

    grass := xy_to_tile_id(*game_state.map_texture, 0, 12);
    for game_state.map {
        game_state.map[it_index] = grass;
    }
    
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
            if it.type == .KEYBOARD {
                if it.key_code == .F1 && it.key_pressed {
                    game_state.state = ifx game_state.state == .GAME then Game_State.State.EDITOR else .GAME;
                    Basic.log("Toggling editor");
                }
            }
        }

        if game_state.state == .GAME {
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
        }

        Simp.clear_render_target(0, 0, 0, 1);
        draw_map(*game_state.map_texture, game_state.map);
        
        Simp.set_shader_for_images(*game_state.player_texture);
        Simp.immediate_begin();
        uv0, uv1 := get_uv_from_texture(*game_state.player_texture, 0, 0);
        immediate_tile(game_state.player_pos, uv0, uv1);
        Simp.immediate_flush();

        Simp.swap_buffers(window);
        Basic.reset_temporary_storage();
    }
}

draw_map :: (texture : *Simp.Texture, map : Map) {
    Simp.set_shader_for_images(texture);
    Simp.immediate_begin();
    y := 0;
    for map {
        x := it_index % MAP_WIDTH;
        if x == 0 then y += 1;
        uv0, uv1 := get_uv_from_texture(texture, it); 
        immediate_tile(xy(xx (x * TILE_SIZE), xx (y * TILE_SIZE)), uv0, uv1);
    }
    Simp.immediate_flush();
}
