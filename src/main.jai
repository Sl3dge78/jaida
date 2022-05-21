Basic :: #import "Basic";
Window_Creation :: #import "Window_Creation";
Simp :: #import "Simp";
Input :: #import "Input";
Math :: #import "Math";
X11 :: #import "X11";
File :: #import "File";
#import "GL";

#load "input.jai";

using Math;

TILE_SIZE :: 16;
TILE_HALF :: TILE_SIZE / 2;
ZOOM :: 2;
PLAYER_SPEED :: 100.0;
MAP_WIDTH :: 40;
MAP_HEIGHT :: 22;

Map :: [MAP_WIDTH*MAP_HEIGHT]u32;

Game_State :: struct {
    State :: enum {
        GAME;
        EDITOR;
    }
    state : State = .GAME;
    screen_width : u16;
    screen_height : u16;
    player_pos : Vector2 = .{16,16};
    player_texture : Simp.Texture;
    map : Map;
    map_texture : Simp.Texture;
    camera_position : Vector2 = .{0, 8};
}

Game_Editor :: struct {
    show_map := true;
    offset_x : s32 = 0;
    offset_y : s32 = -42;
    selected_tile : u32 = 0;
    zoom := 2.0;
}

from_index_to_vector2 :: inline (index : int, width : int) -> x : int, y : int {
    return x = index % width, y = index / width;
}

get_uv_from_texture :: (texture : *Simp.Texture, tile_x : int, tile_y : int) -> uv0 : Vector2, uv1 : Vector2 {
    nb_tiles_width := texture.width / TILE_SIZE;
    nb_tiles_height := texture.height / TILE_SIZE;

    uv0 := Math.xy(cast(float)tile_x / cast(float)nb_tiles_width, cast(float)tile_y / cast(float)nb_tiles_height);
    uv1 := Math.xy(cast(float)(tile_x+1) / cast(float)nb_tiles_width, cast(float)(tile_y+1) / cast(float)nb_tiles_height);
    return uv0, uv1;
}

get_uv_from_texture :: (texture : *Simp.Texture, tile : u32) -> uv0 : Vector2, uv1 : Vector2 {
    nb_tiles_width : u32 = cast(u32)(texture.width) / TILE_SIZE;
    nb_tiles_height : u32 = cast(u32)(texture.height) / TILE_SIZE;
    tile_x, tile_y := tile_id_to_xy(texture, tile);

    uv0 := Math.xy(cast(float)tile_x / cast(float)nb_tiles_width, cast(float)tile_y / cast(float)nb_tiles_height);
    uv1 := Math.xy(cast(float)(tile_x+1) / cast(float)nb_tiles_width, cast(float)(tile_y + 1) / cast(float)nb_tiles_height);
    return uv0, uv1;
}

xy_to_tile_id :: inline (texture : *Simp.Texture, x : u32, y : u32) -> tile_id : u32 {
    nb_tiles_width := texture.width / TILE_SIZE;
    return xx x + y * xx nb_tiles_width;
}

tile_id_to_xy :: inline (texture : *Simp.Texture, tile_id : u32) -> x : u32 , y : u32 {
    nb_tiles_width : u32 = cast(u32)texture.width / TILE_SIZE;
    tile_x := tile_id % nb_tiles_width;
    tile_y := tile_id / nb_tiles_width;
    return tile_x, tile_y;
}

get_tile_from_pixel :: inline (x : int, y : int) -> x: int, y: int {
    return x / (TILE_SIZE * ZOOM), y / (TILE_SIZE * ZOOM);
}

immediate_tile :: (pos : Vector2, uv0: Vector2, uv1 : Vector2, cam : Vector2) {
    p0 := (pos * cast(float) ZOOM) + cam; p0.x -= TILE_HALF * ZOOM; p0.y -= TILE_HALF * ZOOM;
    p1 := (pos * cast(float) ZOOM) + cam; p1.x += TILE_HALF * ZOOM; p1.y -= TILE_HALF * ZOOM;
    p2 := (pos * cast(float) ZOOM) + cam; p2.x += TILE_HALF * ZOOM; p2.y += TILE_HALF * ZOOM;
    p3 := (pos * cast(float) ZOOM) + cam; p3.x -= TILE_HALF * ZOOM; p3.y += TILE_HALF * ZOOM;

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
    Simp.set_render_target(window);

    // Load 
    game_state : Game_State;
    w, h := Simp.get_render_dimensions(window);
    game_state.screen_width = xx w;
    game_state.screen_height = xx h;
    load_texture(*game_state.player_texture, "res/SpriteSheet.png");
    load_texture(*game_state.map_texture, "res/world.png");
    load_map(game_state.map);

    // Editor
    editor : Game_Editor;
    
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
                game_state.screen_width = xx it.width;
                game_state.screen_height = xx it.height;
            }
        }

        mouse_x, mouse_y := Window_Creation.get_mouse_pointer_position(window, false);
        mouse_y = game_state.screen_height - mouse_y;
        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;
            if it.type == .KEYBOARD {
                if it.key_code == .F1 && it.key_pressed {
                    game_state.state = ifx game_state.state == .GAME then Game_State.State.EDITOR else .GAME;
                    if game_state.state == .GAME {
                        Basic.log("Editor off");
                    } else {
                        Basic.log("Editor on");
                    }
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
        
        if game_state.state == .EDITOR {
            
            if Input.input_button_states[get_keycode_from_scancode(.W)] == .DOWN {
                editor.offset_y += 1;
                if (editor.offset_y > 0) editor.offset_y = 0; 
            }        
            if Input.input_button_states[get_keycode_from_scancode(.S)] == .DOWN {
                editor.offset_y -= 1;
                if (editor.offset_y < -42) editor.offset_y = -42; // @Hardcoded, can't be bothered to do the math
            } 
            if Input.input_button_states[get_keycode_from_scancode(.A)] == .DOWN {
                editor.offset_x -= 1;
                if (editor.offset_x < -43) editor.offset_x = -43; // @Hardcoded, can't be bothered to do the math
            }
            if Input.input_button_states[get_keycode_from_scancode(.D)] == .DOWN {
                editor.offset_x += 1;
                if (editor.offset_x > 0) editor.offset_x = 0;
            } 

            if Input.input_button_states[Input.Key_Code.F5] == .END {
                save_map(game_state.map);
                Basic.log("Map saved!");
            }

            if Input.input_button_states[Input.Key_Code.F9] == .END {
                load_map(game_state.map);
                Basic.log("Map loaded!");
            }

            if Input.input_button_states[Input.Key_Code.MOUSE_BUTTON_LEFT] == .END {
                if editor.show_map {
                    if mouse_x < game_state.screen_width / 2{ // Clicking on the map
                        tile_x := mouse_x / TILE_SIZE / editor.zoom - editor.offset_x;
                        tile_y :=  mouse_y / TILE_SIZE / editor.zoom - editor.offset_y;
                        editor.selected_tile = xy_to_tile_id(*game_state.map_texture, xx tile_x, xx tile_y);
                    }
                }
            }

            if Input.input_button_states[Input.Key_Code.MOUSE_BUTTON_LEFT] == .DOWN {
                if !editor.show_map || mouse_x > game_state.screen_width / 2 {
                    x,y := get_tile_from_pixel(mouse_x, mouse_y);
                    if x < MAP_WIDTH && y < MAP_HEIGHT && x >= 0 && y >= 0 {
                        game_state.map[x + y * MAP_WIDTH] = editor.selected_tile;
                    }
                }

            }
            if Input.input_button_states[Input.Key_Code.TAB] == .END {
                editor.show_map = !editor.show_map;
            }
        }

        Simp.clear_render_target(0, 0, 0, 1);
        draw_map(*game_state.map_texture, game_state.map, game_state.camera_position);
        
        Simp.set_shader_for_images(*game_state.player_texture);
        Simp.immediate_begin();

        uv0, uv1 := get_uv_from_texture(*game_state.player_texture, 0, 6);
        immediate_tile(game_state.player_pos, uv0, uv1, game_state.camera_position);

        if game_state.state == .EDITOR {
            if editor.show_map draw_editor_map(*editor, *game_state);

        }

        Simp.swap_buffers(window);
        Basic.reset_temporary_storage();
    }
}

draw_map :: (texture : *Simp.Texture, map : Map, cam : Vector2) {
    Simp.set_shader_for_images(texture);
    y := 0;
    for map {
        x := it_index % MAP_WIDTH;
        y := it_index / MAP_WIDTH;
        x0 := xy(xx (x * TILE_SIZE * ZOOM) + cam.x, xx (y * TILE_SIZE * ZOOM) + cam.y); 
        x1 := xy(x0.x + TILE_SIZE * ZOOM, x0.y + TILE_SIZE * ZOOM);

        uv0, uv1 := get_uv_from_texture(texture, it); 
        uvx := uv0;
        uvx.x = uv1.x;

        uvy := uv0;
        uvy.y = uv1.y;
            
        Simp.immediate_quad(
            p0 = x0, p1 = xy(x1.x, x0.y), 
            p2 = x1, p3 = xy(x0.x, x1.y),
            uv0 = uv0, uv1 = uvx,
            uv2 = uv1, uv3 = uvy);
    }
}

save_map :: (map : Map) {
    if !File.write_entire_file("map.bin", map.data, MAP_WIDTH * MAP_HEIGHT * size_of(type_of(map[0]))){
        Basic.log_error("Unable to save map!");
    }
}

load_map :: (map : Map) {
    map_file, success := File.file_open("map.bin");
    if !success {
        Basic.log_error("Unable to open map file!");
        return;
    }
    defer File.file_close(*map_file);
    File.file_read(*map_file, map.data, MAP_WIDTH * MAP_HEIGHT * size_of(type_of(map[0])));
    Basic.log("Map loaded");
}

draw_editor_map :: (editor : *Game_Editor, game_state : *Game_State) {
    using game_state;
    half_sw := screen_width / 2.0;
    zoom := editor.zoom;

    Simp.set_scissor(0, 0, screen_width / 2, screen_height);
    // Draw the background 
    Simp.set_shader_for_color();
    Simp.immediate_quad(0, 0, map_texture.width * zoom, map_texture.height * zoom, .{.70, 0.20, 0.70, 1.0});
        
    // Draw the texture
    Simp.set_shader_for_images(*map_texture);
    x0 := xx (editor.offset_x * TILE_SIZE + 0) * zoom;
    x1 := xx (editor.offset_x * TILE_SIZE + map_texture.width) * zoom;
    y0 := xx (editor.offset_y * TILE_SIZE + 0) * zoom;
    y1 := xx (editor.offset_y * TILE_SIZE + map_texture.height) * zoom;
    Simp.immediate_quad(x0, y0, x1, y1, .{1,1,1,1}); 

    // Highlight selected tile
    Simp.set_shader_for_color(true);
    tile_x, tile_y := tile_id_to_xy(*map_texture, editor.selected_tile);

    Simp.immediate_quad(
        x0 + tile_x * TILE_SIZE * zoom, 
        y0 + tile_y * TILE_SIZE * zoom, 
        x0 + (tile_x + 1) * TILE_SIZE * zoom, 
        y0 + (tile_y + 1) * TILE_SIZE * zoom, 
        .{1,1,0,.5});

    Simp.clear_scissor();

}
