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

load_texture_no_filter :: (tex : *Simp.Texture, path : string) -> bool {
    result := Simp.texture_load_from_file(tex, path);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    return result;
}

Game :: struct {
    State :: enum {
        GAME;
        EDITOR;
        DIALOG;
    };
    
    Palette :: struct {
        BLACK       :: Vector4.{0.078, 0.106, 0.106, 1};
        BLUE        :: Vector4.{0.176, 0.412, 0.482, 1};
        ORANGE      :: Vector4.{1, 0.584, 0.329, 1};
        DARK_ORANGE :: Vector4.{0.82, 0.294, 0.204, 1};
    };

    state : State = .GAME;
    screen_width : s32;
    screen_height : s32;

    audio_device : SDL_AudioDeviceID = ---;
    volume : s8 = 32;

    font : *Simp.Dynamic_Font;
    small_font : *Simp.Dynamic_Font;

    mouse_x : int;
    mouse_y : int;

    current_map : Map;
    current_world_pos : Vector2i;
    map_texture : Simp.Texture;
    
    camera_position : Vector2 = .{0.5, 0.75};

    blue_samurai_texture : Simp.Texture;
    red_samurai_texture  : Simp.Texture;
    katana_texture       : Simp.Texture;

    player : *Entity;

    // Dialog
    dialogbox_texture : Simp.Texture;
    dialogbox_notitle_texture : Simp.Texture;
    dialogbox_choice_texture : Simp.Texture;

    current_dialog_tree : []Dialog.Node;
    current_dialog_node : u8; // I don't think we'll ever get a dialog tree bigger than 255...
    current_choice : s8;
    char_timer : float;
    dialog_nb_chars: int;
    dialog_blip : Audio_Stream;

    // This is a timer that is reset every second
    second : float;

    load :: () {
        using global_game;

        Random.random_seed(cast(u64) Basic.get_time());


        font = Simp.get_font_at_size("res", "monospace.ttf", 8 * ZOOM);
        small_font = Simp.get_font_at_size("res", "monospace.ttf", 4 * ZOOM);
        load_texture_no_filter(*dialogbox_texture, "res/ui/dialogbox.png");
        load_texture_no_filter(*dialogbox_notitle_texture, "res/ui/dialogbox_notitle.png");
        load_texture_no_filter(*dialogbox_choice_texture, "res/ui/dialogbox_choice.png");

        load_texture_no_filter(*blue_samurai_texture, "res/blue_samurai.png");
        load_texture_no_filter(*red_samurai_texture, "res/red_samurai.png");
        load_texture_no_filter(*katana_texture, "res/katana.png");
        load_texture_no_filter(*map_texture, "res/world.png");

        dialog_blip = Audio_Stream.load("res/audio/blip.wav");
        
        Basic.log("Sprite : %", Component_Manager.get_component_id(Sprite));
        starting_world_pos :: Vector2i.{-1, 0};
        // Create player
        {
            player = Entity.create();
            player.tag = .PLAYER;
            sprite := Entity.add_component(player, Sprite);
            sprite.sprite_sheet = blue_samurai_texture;
            sprite.flags |= .USE_DIRECTION_AS_X;

            xform := Entity.add_component(player, Transform.{pos = .{14, 11}, world_pos = starting_world_pos});
            Entity.add_component(player, Animation);
            Entity.add_component(player, Velocity);
            Entity.add_component(player, Player);
            //Entity.add_component(player, Health);
            Entity.add_component(player, Hitbox.{tag = .PLAYER});
        }

        create_enemy();
        create_bush(.{18, 14}, .{0, 1});
        create_bush(.{5, 11}, .{1, 1});
        create_teleporter(.{13, 13}, .{14.5, 9}, .{-1, 0});

        dialog := Entity.create();
        Entity.add_component(dialog, Transform.{pos = .{14, 13}, world_pos = .{-1, 0}});
        Entity.add_component(dialog, Interact);
        Entity.add_component(dialog, Hitbox.{tag = .INTERACT});

        request_map_change(current_map, starting_world_pos);
    }

    update :: (delta_time : float32) {
        game := *global_game;

        game.second += delta_time;
        if game.second > 1.0 then game.second -= 1.0;

        if game.state == { 
            case .GAME;
                Component_Manager.update_components(delta_time);
            case .EDITOR; {
                #if DEVELOPER {
                    Editor.update();
                }
            }
            case .DIALOG; {
                Dialog.update(delta_time);
            }
        }
    }

    draw :: () {
        game := *global_game;
        if game.state == .EDITOR {
            Simp.clear_render_target(0.5, 0, 0, 1);
        } else {
            Simp.clear_render_target(0, 0, 0, 1);
        }

        Map.draw_layer(0, game.current_map, *game.map_texture, game.camera_position);

        layer_separator :: (layer : int) {
            #if DEVELOPER {
                if global_game.state == .EDITOR && context.editor.current_layer > layer {
                    Simp.set_shader_for_color(true);
                    Simp.immediate_quad(x0 = xx 0, y0 = xx 0, x1 = xx global_game.screen_width, y1 = xx global_game.screen_height, color = .{1, 1, 1, 0.5});
                }
            }
        }

        layer_separator(0);
        Map.draw_layer(1, game.current_map, *game.map_texture, game.camera_position);
        layer_separator(1);

        Component_Manager.draw_components();

        Map.draw_layer(2, game.current_map, *game.map_texture, game.camera_position);
        layer_separator(2);

        if game.state == .DIALOG {
            Dialog.draw();
        }

        #if DEVELOPER {
           Editor.draw();
        }
    }

    request_map_change :: (current_map : Map, map_pos : Vector2i) -> bool {
        success := Map.load(current_map, map_pos);
        if !success return false;
        global_game.current_world_pos = map_pos;

        for * all_entities {
            xform := Entity.get_component(it, Transform);
            if xform {
                if xform.world_pos == map_pos && it.inactive {
                    it.flags |= .CHANGE_ACTIVE;
                }
                if !it.inactive && xform.world_pos != map_pos {
                    it.flags |= .CHANGE_ACTIVE;
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

    rect_intersects :: (a0 : Vector2, a1 : Vector2, b0 : Vector2, b1 : Vector2) -> bool {
        return a0.x < b1.x && a1.x > b0.x && a0.y < b1.y && a1.y > b0.y;
    }

    is_point_in_rect :: (p : Vector2, a1 : Vector2, a2 : Vector2) -> bool {
        return p.x > a1.x && p.x < a2.y && p.y > a1.y && p.y < a2.y;
    }

    create_enemy :: () {
        e := Entity.create();
        sprite := Entity.add_component(e, Sprite);
        sprite.sprite_sheet = global_game.red_samurai_texture;
        sprite.flags |= .USE_DIRECTION_AS_X;
        xform := Entity.add_component(e, Transform);
        xform.pos.x = 10; // Random.random_get_within_range(0, MAP_WIDTH);
        xform.pos.y = 10; // Random.random_get_within_range(0, MAP_HEIGHT);
        xform.world_pos = .{0,0};
        Entity.add_component(e, Enemy);
        Entity.add_component(e, Velocity);
        Entity.add_component(e, Animation);
        Entity.add_component(e, Hitbox.{tag = .ENEMY});
        Entity.add_component(e, Health);
        Entity.add_component(e, Collision);
    }

    create_weapon :: (parent : *Entity, tag : Hitbox.Tag, time : float) -> *Entity {
        weapon := Entity.create();
        xform := Entity.get_component(parent, Transform);
        w_xform := Entity.add_component(weapon, Transform);
        Component.copy(xform, w_xform);
        w_xform.pos += forward(w_xform.direction);

        sprite := Entity.add_component(weapon, Sprite);
        sprite.sprite_sheet = global_game.katana_texture;
        sprite.flags |= .USE_DIRECTION_AS_X;

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
        xform.world_pos = global_game.current_world_pos;
        comp := Entity.add_component(tp, Teleporter);
        comp.new_pos = new_pos;
        comp.new_world_pos = new_world_pos;
        return tp;
    }

    create_interactor :: (parent : *Entity) {
        interactor := Entity.create();
        xform := Entity.get_component(parent, Transform);
        w_xform := Entity.add_component(interactor, Transform);
        Component.copy(xform, w_xform);
        w_xform.pos += forward(w_xform.direction);

        hitbox := Entity.add_component(interactor, Hitbox);
        hitbox.look_for = .INTERACT;
        hitbox.p0.x = -0.2;
        hitbox.p1.x = 0.2;
        hitbox.p0.y = -0.2;
        hitbox.p1.y = 0.2;
        interactor.flags |= .SHOULD_DELETE; // @Hack: is it even a hack??
    }

    create_bush :: (pos : Vector2, world_pos : Vector2i) {
        ett := Entity.create();
        xform := Entity.add_component(ett, Transform);
        xform.pos = pos;
        xform.world_pos = world_pos;
        Entity.add_component(ett, Collision.{p0 = .{-0.5, -0.5}, p1 = .{0.5, 0.5}});
        Entity.add_component(ett, Health.{hp = 1});
        Entity.add_component(ett, Hitbox.{tag = .ENEMY});
        sprite := Entity.add_component(ett, Sprite);
        sprite.sprite_sheet = *global_game.map_texture;
        x, y := tile_id_to_xy(*global_game.map_texture, 1895);
        sprite.sprite_x = x;
        sprite.sprite_y = y;
        
    }
}

global_game : Game;
