Basic :: #import "Basic";
Math :: #import "Math";
using Math; // To import operator overloading

File :: #import "File";
#import "GL";
#import "SDL";

Renderer :: #import "Renderer";

TILE_SIZE :: 16;
TILE_HALF :: TILE_SIZE / 2;
ZOOM :: 2;
PLAYER_SPEED :: 100.0;
MAP_WIDTH :: 40;
MAP_HEIGHT :: 22;
MAP_LAYERS :: 3;

Map :: [MAP_LAYERS][MAP_WIDTH*MAP_HEIGHT]u32;

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
}

Game_Editor :: struct {
    show_map := true;
    offset_x : s32 = 0;
    offset_y : s32 = -42;
    selected_tile : u32 = 0;
    current_layer := 0;
    zoom := 2.0;
}

from_index_to_vector2 :: inline (index : int, width : int) -> x : int, y : int {
    return x = index % width, y = index / width;
}

get_uv_from_texture :: (texture : *Renderer.Texture, tile_x : int, tile_y : int) -> uv0 : Vector2, uv1 : Vector2 {
    nb_tiles_width := texture.width / TILE_SIZE;
    nb_tiles_height := texture.height / TILE_SIZE;

    uv0 := Math.xy(cast(float)tile_x / cast(float)nb_tiles_width, cast(float)tile_y / cast(float)nb_tiles_height);
    uv1 := Math.xy(cast(float)(tile_x+1) / cast(float)nb_tiles_width, cast(float)(tile_y+1) / cast(float)nb_tiles_height);
    return uv0, uv1;
}

get_uv_from_texture :: (texture : *Renderer.Texture, tile : u32) -> uv0 : Vector2, uv1 : Vector2 {
    nb_tiles_width : u32 = cast(u32)(texture.width) / TILE_SIZE;
    nb_tiles_height : u32 = cast(u32)(texture.height) / TILE_SIZE;
    tile_x, tile_y := tile_id_to_xy(texture, tile);

    uv0 := Math.xy(cast(float)tile_x / cast(float)nb_tiles_width, cast(float)tile_y / cast(float)nb_tiles_height);
    uv1 := Math.xy(cast(float)(tile_x+1) / cast(float)nb_tiles_width, cast(float)(tile_y + 1) / cast(float)nb_tiles_height);
    return uv0, uv1;
}

xy_to_tile_id :: inline (texture : *Renderer.Texture, x : u32, y : u32) -> tile_id : u32 {
    nb_tiles_width := texture.width / TILE_SIZE;
    return xx x + y * xx nb_tiles_width;
}

tile_id_to_xy :: inline (texture : *Renderer.Texture, tile_id : u32) -> x : u32 , y : u32 {
    nb_tiles_width : u32 = cast(u32)texture.width / TILE_SIZE;
    tile_x := tile_id % nb_tiles_width;
    tile_y := tile_id / nb_tiles_width;
    return tile_x, tile_y;
}

get_tile_from_pixel :: inline (x : int, y : int) -> x: int, y: int {
    return x / (TILE_SIZE * ZOOM), y / (TILE_SIZE * ZOOM);
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
    load_map(game_state.map);

    // Editor
    editor : Game_Editor;
    
    quit := false;
    last_time := Basic.get_time();
    while !quit {
        now := Basic.get_time();
        delta_time : float = cast(float) (now - last_time);
        last_time = now;

        mouse_x, mouse_y: s32 = ---;
        SDL_GetMouseState(*mouse_x, *mouse_y);
        keyboard := SDL_GetKeyboardState(null);
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
                        case SDL_SCANCODE_F1; {
                            game_state.state = ifx game_state.state == .GAME then Game_State.State.EDITOR else .GAME;
                            if game_state.state == .GAME {
                                Basic.log("Editor off");
                            } else {
                                Basic.log("Editor on");
                            }
                        }
                        case SDL_SCANCODE_F5; 
                            save_map(game_state.map);
                        case SDL_SCANCODE_F9; 
                            load_map(game_state.map);
                        case SDL_SCANCODE_1;
                            editor.current_layer = 0;
                            Basic.log("Changed layer %", editor.current_layer);
                        case SDL_SCANCODE_2;
                            editor.current_layer = 1;
                            Basic.log("Changed layer %", editor.current_layer);
                        case SDL_SCANCODE_3;
                            editor.current_layer = 2;
                            Basic.log("Changed layer %", editor.current_layer);


                    };

            };
            if game_state.state == .EDITOR {

                if event.type == {
                    case SDL_MOUSEBUTTONUP;
                        if event.button.button == SDL_BUTTON_LEFT {
                            if editor.show_map {
                                if mouse_x < game_state.screen_width / 2 { // Clicking on the map
                                    tile_x := mouse_x / TILE_SIZE / editor.zoom - editor.offset_x;
                                    tile_y :=  mouse_y / TILE_SIZE / editor.zoom - editor.offset_y;
                                    editor.selected_tile = xy_to_tile_id(*game_state.map_texture, xx tile_x, xx tile_y);
                                }
                            }
                        }
                    case SDL_MOUSEBUTTONDOWN;
                        if !editor.show_map || mouse_x > game_state.screen_width / 2 {
                            x,y := get_tile_from_pixel(mouse_x, mouse_y);
                            if x < MAP_WIDTH && y < MAP_HEIGHT && x >= 0 && y >= 0 {
                                game_state.map[editor.current_layer][x + y * MAP_WIDTH] = editor.selected_tile;
                            }
                        }
                    case SDL_KEYUP; 
                        if event.key.keysym.scancode == SDL_SCANCODE_TAB {
                            editor.show_map = !editor.show_map;
                        }
                }
            }
        }


        if game_state.state == .GAME {
            player_vel : Vector2;
            if keyboard[SDL_SCANCODE_W] {
                player_vel.y += 1;
            }        
            if keyboard[SDL_SCANCODE_S] {
                player_vel.y -= 1;
            } 
            if keyboard[SDL_SCANCODE_A] {
                player_vel.x -= 1;
            }
            if keyboard[SDL_SCANCODE_D] {
                player_vel.x += 1;
            } 
            game_state.player_pos += Math.unit_vector(player_vel) * (delta_time * PLAYER_SPEED);
        }
        
        if game_state.state == .EDITOR {
            
            if keyboard[SDL_SCANCODE_W] {
                editor.offset_y += 1;
                if (editor.offset_y > 0) editor.offset_y = 0; 
            }        
            if keyboard[SDL_SCANCODE_S] {
                editor.offset_y -= 1;
                if (editor.offset_y < -42) editor.offset_y = -42; // @Hardcoded, can't be bothered to do the math
            } 
            if keyboard[SDL_SCANCODE_A] {
                editor.offset_x -= 1;
                if (editor.offset_x < -43) editor.offset_x = -43; // @Hardcoded, can't be bothered to do the math
            }
            if keyboard[SDL_SCANCODE_D] {
                editor.offset_x += 1;
                if (editor.offset_x > 0) editor.offset_x = 0;
            } 

        }

        if game_state.state == .GAME {
            Renderer.clear_render_target(0, 0, 0, 1);
        } else {
            Renderer.clear_render_target(0.5, 0, 0, 1);
        }
        //draw_map(*game_state.map_texture, game_state.map, game_state.camera_position);
        
        // Player
        Renderer.set_shader_for_images(*game_state.player_texture);
        p0 := (game_state.player_pos * cast(float) ZOOM) + game_state.camera_position; p0.x -= TILE_HALF * ZOOM; p0.y -= TILE_HALF * ZOOM;
        p1 := (game_state.player_pos * cast(float) ZOOM) + game_state.camera_position; p1.x += TILE_HALF * ZOOM; p1.y += TILE_HALF * ZOOM;
        uv0, uv1 := get_uv_from_texture(*game_state.player_texture, 0, 6);
        Renderer.immediate_quad(x0 = p0.x, y0 = p0.y, x1 = p1.x, y1 = p1.y, uv0 = uv0, uv1 = uv1);

        if game_state.state == .EDITOR {
            if editor.show_map draw_editor_map(*editor, *game_state);
        }

        Renderer.swap_buffers(window);
        Basic.reset_temporary_storage();
    }
}

draw_map :: (texture : *Renderer.Texture, map : Map, cam : Vector2) {
    Renderer.set_shader_for_images(texture);
    y := 0;
    for layer : map {
        for layer {
        x := it_index % MAP_WIDTH;
        y := it_index / MAP_WIDTH;
        x0 := xy(xx (x * TILE_SIZE * ZOOM) + cam.x, xx (y * TILE_SIZE * ZOOM) + cam.y); 
        x1 := xy(x0.x + TILE_SIZE * ZOOM, x0.y + TILE_SIZE * ZOOM);

        uv0, uv1 := get_uv_from_texture(texture, it); 
        uvx := uv0;
        uvx.x = uv1.x;

        uvy := uv0;
        uvy.y = uv1.y;
            
        Renderer.immediate_quad(
            x0 = x0.x, y0 = x0.y, 
            x1 = x1.x, y1 = x1.y,
            uv0 = uv0, uv1 = uv1);
        }
    }
}

save_map :: (map : Map) {
    if !File.write_entire_file("map.bin", map.data, MAP_LAYERS * MAP_WIDTH * MAP_HEIGHT * size_of(type_of(map[0][0]))){
        Basic.log_error("Unable to save map!");
    }
    Basic.log("Saved!");
}

load_map :: (map : Map) {
    map_file, success := File.file_open("map.bin");
    if !success {
        Basic.log_error("Unable to open map file!");
        return;
    }
    defer File.file_close(*map_file);
    File.file_read(*map_file, map.data, MAP_LAYERS * MAP_WIDTH * MAP_HEIGHT * size_of(type_of(map[0][0])));
    Basic.log("Loaded!");
}

draw_editor_map :: (editor : *Game_Editor, game_state : *Game_State) {
    using game_state;
    half_sw := screen_width / 2.0;
    zoom := editor.zoom;

    
    Renderer.set_scissor(0, 0, screen_width / 2, screen_height);
    // Draw the background 
    Renderer.set_shader_for_color();
    Renderer.immediate_quad(0, 0, map_texture.width * zoom, map_texture.height * zoom, .{.70, 0.20, 0.70, 1.0});
        
    // Draw the texture
    Renderer.set_shader_for_images(*map_texture);
    x0 := xx (editor.offset_x * TILE_SIZE + 0) * zoom;
    x1 := xx (editor.offset_x * TILE_SIZE + map_texture.width) * zoom;
    y0 := xx (editor.offset_y * TILE_SIZE + 0) * zoom;
    y1 := xx (editor.offset_y * TILE_SIZE + map_texture.height) * zoom;
    Renderer.immediate_quad(x0, y0, x1, y1, .{1,1,1,1}); 

    // Highlight selected tile
    Renderer.set_shader_for_color();
    tile_x, tile_y := tile_id_to_xy(*map_texture, editor.selected_tile);

    Renderer.immediate_quad(
        x0 + tile_x * TILE_SIZE * zoom, 
        y0 + tile_y * TILE_SIZE * zoom, 
        x0 + (tile_x + 1) * TILE_SIZE * zoom, 
        y0 + (tile_y + 1) * TILE_SIZE * zoom, 
        .{1,1,0,.5});

    Renderer.clear_scissor();

}
