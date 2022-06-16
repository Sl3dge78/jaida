
Game :: struct {
    State :: enum {
        GAME;
        EDITOR;
    };

    state : State = .GAME;
    screen_width : s32;
    screen_height : s32;

    current_map : Map;
    map_texture : Renderer.Texture;
    
    camera_position : Vector2 = .{0.5, 0.75};

    blue_samurai_texture : Renderer.Texture;
    red_samurai_texture : Renderer.Texture;
    katana_texture : Renderer.Texture;

    player : *Entity;

    load :: () {
        using context.game;

        Renderer.load_texture(*blue_samurai_texture, "res/blue_samurai.png");
        Renderer.load_texture(*red_samurai_texture, "res/red_samurai.png");
        Renderer.load_texture(*katana_texture, "res/katana.png");
        Renderer.load_texture(*map_texture, "res/world.png");
        
        Basic.log("Sprite : %", Component_Manager.get_component_id(Sprite));
        // Create player
        {
        player = Entity.create();
        player.tag = .PLAYER;
        sprite := Entity.add_component(player, Sprite);
        sprite.sprite_sheet = blue_samurai_texture;

        xform := Entity.add_component(player, Transform);
        xform.pos = .{20, 11};
        Entity.add_component(player, Animation);
        Entity.add_component(player, Velocity);
        Entity.add_component(player, Player);
        request_map_change(current_map, xform.world_pos);
        for player.components {
            Basic.log("%: %", it_index, it);
        }
        }
        Basic.log("Sprite : %", Component_Manager.get_component_id(Sprite));

        {
        e := Entity.create();
        sprite := Entity.add_component(e, Sprite);
        sprite.sprite_sheet = red_samurai_texture;
        xform := Entity.add_component(e, Transform);
        xform.pos.x = Random.random_get_zero_to_one() * MAP_WIDTH;
        xform.pos.y = Random.random_get_zero_to_one() * MAP_HEIGHT;
        Entity.add_component(e, NPC_Move);
        Entity.add_component(e, Velocity);
        Entity.add_component(e, Animation);
        }
    }

    update :: (delta_time : float32) {
        game := *context.game;
        if game.state == .GAME {
            Component_Manager.update_components(delta_time);
        } else if game.state == .EDITOR {
            Editor.update();
        }
    }

    draw :: () {
        game := *context.game;
        if game.state == .GAME {
            Renderer.clear_render_target(0, 0, 0, 1);
        } else {
            Renderer.clear_render_target(0.5, 0, 0, 1);
        }

        Map.draw_layer(0, game.current_map, *game.map_texture, game.camera_position);

        layer_separator :: (layer : int) {
            if context.game.state == .EDITOR && context.editor.current_layer > layer {
                Renderer.set_shader_for_color();
                Renderer.immediate_quad(x0 = xx 0, y0 = xx 0, x1 = xx context.game.screen_width, y1 = xx context.game.screen_height, color = .{1, 1, 1, 0.5});
            }
        }
        layer_separator(0);
        Map.draw_layer(1, game.current_map, *game.map_texture, game.camera_position);
        layer_separator(1);

        Component_Manager.draw_components();

        // Player
        Map.draw_layer(2, game.current_map, *game.map_texture, game.camera_position);

        if game.state == .EDITOR {
            Editor.draw();
        }
    }

    request_map_change :: (current_map : Map, map_pos : Vector2) -> bool {
        success := Map.load(current_map, map_pos);

        for * all_entities {
            xform := Entity.get_component(it, Transform);
            if xform {
                if xform.world_pos == map_pos && it.inactive {
                    it.request_active_state_toggle = true;
                }
                if !it.inactive && xform.world_pos != map_pos {
                    it.request_active_state_toggle = true;
                }
            }
        }

        if !success return false;
        return true;
    }

    /// Computes a new velocity that avoids map obstacles
    move_and_slide :: (current_pos : Vector2, velocity : Vector2, map : Map) -> new_vel : Vector2 {
        result : Vector2;
        new_center_x := current_pos + xy(velocity.x, 0);
        new_center_y := current_pos + xy(0, velocity.y);
        // @Speed : Get the sign of the velocity? to check only 1 side
        // @Hardcoded : Specify the size of the sprite?
        // Try to move on x
        if  Map.get_collision_at(context.game.current_map, new_center_x + Vector2.{ 0.4,  0.0}) == 0 &&
            Map.get_collision_at(context.game.current_map, new_center_x + Vector2.{-0.4,  0.0}) == 0 &&
            Map.get_collision_at(context.game.current_map, new_center_x + Vector2.{ 0.4, -0.4}) == 0 &&
            Map.get_collision_at(context.game.current_map, new_center_x + Vector2.{-0.4, -0.4}) == 0 {
                result.x += velocity.x;
        }

        if  Map.get_collision_at(context.game.current_map, new_center_y + Vector2.{ 0.4,  0.0}) == 0 &&
            Map.get_collision_at(context.game.current_map, new_center_y + Vector2.{ 0.4, -0.5}) == 0 &&
            Map.get_collision_at(context.game.current_map, new_center_y + Vector2.{-0.4,  0.0}) == 0 &&
            Map.get_collision_at(context.game.current_map, new_center_y + Vector2.{-0.4, -0.5}) == 0 {
                result.y += velocity.y;
        }

        return result;
    }
}

#add_context game : Game;