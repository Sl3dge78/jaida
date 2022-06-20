
Vector2i :: struct {
    x : s32;
    y : s32;

    length :: (v: Vector2i) -> float {
        return sqrt(cast(float)(v.x * v.x + v.y * v.y));
    }

    from_vector2 :: (v : Vector2) -> Vector2i {
        result : Vector2i = ---;
        result.x = xx round(v.x);
        result.y = xx round(v.y);
        return result;
    }
}

operator == :: (a: Vector2i, b: Vector2i) -> bool {
    return a.x == b.x && a.y == b.y;
}

operator + :: (a: Vector2i, b: Vector2i) -> Vector2i {
    result := a;
    result.x += b.x;
    result.y += b.y;
    return result;
}

operator - :: (a: Vector2i, b: Vector2i) -> Vector2i {
    result := a;
    result.x -= b.x;
    result.y -= b.y;
    return result;
}



Game :: struct {
    State :: enum {
        GAME;
        EDITOR;
    };

    state : State = .GAME;
    screen_width : s32;
    screen_height : s32;

    current_map : Map;
    current_world_pos : Vector2i;
    map_texture : Renderer.Texture;
    
    camera_position : Vector2 = .{0.5, 0.75};

    blue_samurai_texture : Renderer.Texture;
    red_samurai_texture : Renderer.Texture;
    katana_texture : Renderer.Texture;

    player : *Entity;

    load :: () {
        using context.game;

        Random.random_seed(SDL_GetPerformanceCounter());

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

            xform := Entity.add_component(player, Transform.{pos = .{20, 11}});
            Entity.add_component(player, Animation);
            Entity.add_component(player, Velocity);
            Entity.add_component(player, Player);
            Entity.add_component(player, Health);
            Entity.add_component(player, Hitbox.{tag = .PLAYER});
            request_map_change(current_map, xform.world_pos);
        }

        create_enemy();
        create_teleporter(.{13, 13}, .{14.5, 9}, .{-1, 0});
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

    request_map_change :: (current_map : Map, map_pos : Vector2i) -> bool {
        success := Map.load(current_map, map_pos);
        if !success return false;
        context.game.current_world_pos = map_pos;

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

        load_entities(map_pos);

        return true;
    }


    // @Temporary : Until we have entity loading.
    load_entities :: (map_pos : Vector2i) {
        if map_pos == .{-1, 0} { // Interior
            create_teleporter(.{14, 8}, .{13, 12}, .{0, 0});
            create_teleporter(.{15, 8}, .{13, 12}, .{0, 0});
        }
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

    rect_intersects :: (a0 : Vector2, a1 : Vector2, b0 : Vector2, b1 : Vector2) -> bool {
        return a0.x < b1.x && a1.x > b0.x && a0.y < b1.y && a1.y > b0.y;
    }

    create_enemy :: () {
        e := Entity.create();
        sprite := Entity.add_component(e, Sprite);
        sprite.sprite_sheet = context.game.red_samurai_texture;
        xform := Entity.add_component(e, Transform);
        xform.pos.x = Random.random_get_within_range(0, MAP_WIDTH);
        xform.pos.y = Random.random_get_within_range(0, MAP_HEIGHT);
        xform.world_pos = context.game.current_world_pos;
        Entity.add_component(e, Enemy);
        Entity.add_component(e, Velocity);
        Entity.add_component(e, Animation);
        Entity.add_component(e, Hitbox.{tag = .ENEMY});
        Entity.add_component(e, Health);
    }

    create_weapon :: (parent : *Entity, tag : Entity.Tag, time : float) -> *Entity {
        weapon := Entity.create();
        xform := Entity.get_component(parent, Transform);
        w_xform := Entity.add_component(weapon, Transform);
        Component.copy(xform, w_xform);
        w_xform.pos += forward(w_xform.direction);

        sprite := Entity.add_component(weapon, Sprite);
        sprite.sprite_sheet = context.game.katana_texture;

        hitbox := Entity.add_component(weapon, Hitbox);
        hitbox.look_for = tag;
        hitbox.p0.x = -0.4;
        hitbox.p1.x = 0;
        autokill := Entity.add_component(weapon, AutoKill);
        autokill.time = time;
        return weapon;
    }

    create_teleporter :: (pos : Vector2i, new_pos : Vector2, new_world_pos : Vector2i) -> *Entity {
        tp := Entity.create();
        
        xform := Entity.add_component(tp, Transform);
        xform.pos.x = xx pos.x;
        xform.pos.y = xx pos.y;
        xform.world_pos = context.game.current_world_pos;
        comp := Entity.add_component(tp, Teleporter);
        comp.new_pos = new_pos;
        comp.new_world_pos = new_world_pos;
        return tp;
    }
}

#add_context game : Game;
