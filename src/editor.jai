#import "SDL";

Editor :: struct {
    show_map := true;
    offset_x : s32 = 0;
    offset_y : s32 = -42;
    selected_tile : u32 = 0;
    current_layer := 0;
    zoom := 2.0;

    update :: (game_state : *Game_State) {
        using game_state;
        if Input.get_mouse_button(1) {
            if !editor.show_map || Input.mouse_x > game_state.screen_width / 2 {
                x, y := Map.get_tile_from_pixel(Input.mouse_x, Input.mouse_y);
                if x < MAP_WIDTH && y < MAP_HEIGHT && x >= 0 && y >= 0 {
                    game_state.map.tiles[editor.current_layer][x + y * MAP_WIDTH] = editor.selected_tile;
                }
            }
        }

        if Input.get_keyboard(SDL_SCANCODE_W) {
            editor.offset_y += 1;
            if (editor.offset_y > 0) editor.offset_y = 0; 
        }        
        if Input.get_keyboard(SDL_SCANCODE_S) {
            editor.offset_y -= 1;
            if (editor.offset_y < -42) editor.offset_y = -42; // @Hardcoded, can't be bothered to do the math
        } 
        if Input.get_keyboard(SDL_SCANCODE_A) {
            editor.offset_x -= 1;
            if (editor.offset_x < -43) editor.offset_x = -43; // @Hardcoded, can't be bothered to do the math
        }
        if Input.get_keyboard(SDL_SCANCODE_D) {
            editor.offset_x += 1;
            if (editor.offset_x > 0) editor.offset_x = 0;
        } 
    }

    draw :: (game_state : *Game_State) {
        using game_state;
        if editor.show_map {
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
    }
}
