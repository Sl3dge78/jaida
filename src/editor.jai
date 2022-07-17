#add_context editor : Editor;

Editor :: struct {
    show_map := false;
    offset_x : s32 = 0;
    offset_y : s32 = -42;
    selected_tile : u32 = 0;
    current_layer := 0;
    zoom :: 2.0;

    update :: () {
        game := *context.game;
        editor := *context.editor;
        if Input.input_button_states[Input.Key_Code.MOUSE_BUTTON_LEFT] & .START {
            if editor.show_map {
                if game.mouse_x < game.screen_width / 2 { // Clicking on the map
                    tile_x := game.mouse_x / TILE_SIZE / editor.zoom - editor.offset_x;
                    tile_y := game.mouse_y / TILE_SIZE / editor.zoom - editor.offset_y;
                    editor.selected_tile = xy_to_tile_id(*game.map_texture, xx tile_x, xx tile_y);
                    Basic.log("%", editor.selected_tile);
                }
            }
        }

        if Input.input_button_states[Input.Key_Code.MOUSE_BUTTON_LEFT] & .DOWN {
            if !editor.show_map || game.mouse_x > game.screen_width / 2 {
                Map.set_tile(
                    game.current_map,
                    Map.screen_to_map(game.camera_position, game.mouse_x, game.mouse_y),
                    xx editor.current_layer,
                    editor.selected_tile);
            }
        }
        if Input.input_button_states[Input.Key_Code.MOUSE_BUTTON_RIGHT] & .DOWN {
            if !editor.show_map || game.mouse_x > game.screen_width / 2 {
                Map.set_tile(
                    game.current_map,
                    Map.screen_to_map(game.camera_position, game.mouse_x, game.mouse_y),
                    xx editor.current_layer,
                    0);
            }
        }

        if Input.input_button_states[Input.Key_Code.MOUSE_BUTTON_MIDDLE] & .START {
            if !editor.show_map || game.mouse_x > game.screen_width / 2 {
                pos := Map.screen_to_map(game.camera_position, game.mouse_x, game.mouse_y);
                if pos.x >= 0 && pos.x < MAP_WIDTH && pos.y >= 0 && pos.y < MAP_HEIGHT {
                    editor.selected_tile = game.current_map.tiles[cast(u32)editor.current_layer][cast(u32)pos.y * MAP_WIDTH + cast(u32)pos.x];
                    Basic.log("%", editor.selected_tile);
                }
            }
        }

        if Input.input_button_states[#char "W"] {
            editor.offset_y += 1;
            if (editor.offset_y > 0) editor.offset_y = 0; 
        }        
        if Input.input_button_states[#char "S"] {
            editor.offset_y -= 1;
            if (editor.offset_y < -42) editor.offset_y = -42; // @Hardcoded, can't be bothered to do the math
        } 
        if Input.input_button_states[#char "A"] {
            editor.offset_x -= 1;
            if (editor.offset_x < -43) editor.offset_x = -43; // @Hardcoded, can't be bothered to do the math
        }
        if Input.input_button_states[#char "D"] {
            editor.offset_x += 1;
            if (editor.offset_x > 0) editor.offset_x = 0;
        } 
    }

    draw :: () {
        using context.game;
        
        if context.editor.current_layer == 3 {
            Map.draw_layer(3, current_map, *map_texture, camera_position);
        }

        if context.editor.show_map {
            half_sw := screen_width / 2.0;
            zoom := context.editor.zoom;


            Simp.set_scissor(0, 0, screen_width / 2, screen_height);
            // Draw the background 
            Simp.set_shader_for_color();
            Simp.immediate_quad(0, 0, map_texture.width * zoom, map_texture.height * zoom, .{.70, 0.20, 0.70, 1.0});

            // Draw the texture
            Simp.set_shader_for_images(*map_texture);
            x0 := xx (context.editor.offset_x * TILE_SIZE + 0) * zoom;
            x1 := xx (context.editor.offset_x * TILE_SIZE + map_texture.width) * zoom;
            y0 := xx (context.editor.offset_y * TILE_SIZE + 0) * zoom;
            y1 := xx (context.editor.offset_y * TILE_SIZE + map_texture.height) * zoom;
            Simp.immediate_quad(x0, y0, x1, y1, .{1,1,1,1}); 

            // Highlight selected tile
            Simp.set_shader_for_color();
            tile_x, tile_y := tile_id_to_xy(*map_texture, context.editor.selected_tile);

            Simp.immediate_quad(
                x0 + tile_x * TILE_SIZE * zoom, 
                y0 + tile_y * TILE_SIZE * zoom, 
                x0 + (tile_x + 1) * TILE_SIZE * zoom, 
                y0 + (tile_y + 1) * TILE_SIZE * zoom, 
                .{1,1,0,.5});

            Simp.clear_scissor();
        }
        player := Game.get_player();
        status_line := Basic.tprint("% - % - %hp - % keys", player.position, player.world_pos, player.health, player.keys);

        Simp.draw_text(small_font, 0, screen_height - 16, status_line);
    }

    save_map :: (down : bool) {
        if down {
            Map.save(context.game.current_map, context.game.current_world_pos);
        }
    }

    load_map :: (down : bool) {
        if down Map.load(context.game.current_map, context.game.current_world_pos);
    }

    change_or_create_map :: (map : Map, pos : Vector2i) {
        if Map.exists(pos) {
            Game.request_map_change(map, pos);
        } else {
            Basic.Initialize(*map.tiles, Map_Type);
            Basic.log("Created new blank map at %.", pos);
            context.game.current_world_pos = pos;
        }
    }

    toggle_editor :: (down : bool) {
        if !down return;

        context.game.state = ifx context.game.state == .GAME then Game.State.EDITOR else .GAME;
        if context.game.state == .GAME {
            Basic.log("Editor off");
        } else {
            Basic.log("Editor on");
        }
    }

    toggle_editor_map :: (down : bool) {
        if !down return;
        if context.game.state != .EDITOR return;
        context.editor.show_map = !context.editor.show_map;
    }

    layer_prev :: (down : bool) {
        if !down return;
        if context.game.state != .EDITOR return;
        if context.editor.current_layer > 0 then context.editor.current_layer -= 1;
        Basic.log("Layer : %", context.editor.current_layer);
    }

    layer_next :: (down : bool) {
        if !down return;
        if context.game.state != .EDITOR return;
        if context.editor.current_layer < MAP_LAYERS-1 then context.editor.current_layer += 1;
        Basic.log("Layer : %", context.editor.current_layer);
    }

    map_left :: (down : bool) {
        if context.game.state != .EDITOR return;
        if down {
            player := Game.get_player();
            player.world_pos.x -= 1;
            Editor.change_or_create_map(context.game.current_map, player.world_pos);
        }
    }

    map_right :: (down : bool) {
        if context.game.state != .EDITOR return;
        if down {
            player := Game.get_player();
            player.world_pos.x += 1;
            Editor.change_or_create_map(context.game.current_map, player.world_pos);
        }
    }

    map_up :: (down : bool) {
        if context.game.state != .EDITOR return;
        if down {
            player := Game.get_player();
            player.world_pos.y += 1;
            Editor.change_or_create_map(context.game.current_map, player.world_pos);
        }
    }

    map_down :: (down : bool) {
        if context.game.state != .EDITOR return;
        if down {
            player := Game.get_player();
            player.world_pos.y -= 1;
            Editor.change_or_create_map(context.game.current_map, player.world_pos);
        }
    }

    fill_layer :: (down : bool) {
        if context.game.state != .EDITOR return;
        if down {
            for * context.game.current_map.tiles[context.editor.current_layer] {
                << it = context.editor.selected_tile;
            }
        }
    }
}
