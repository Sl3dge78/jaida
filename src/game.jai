Vector2i :: struct {
    x : s32;
    y : s32;

    length :: (v: Vector2i) -> float {
        return sqrt(cast(float)(v.x * v.x + v.y * v.y));
    }

    from :: (v : Vector2) -> Vector2i {
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

#add_context game : Game;

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
    key_texture          : Simp.Texture;

    entities : [..]* Entity;

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
        using context.game;

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
        load_texture_no_filter(*key_texture, "res/key.png");

        dialog_blip = Audio_Stream.load("res/audio/blip.wav");
        starting_world_pos :: Vector2i.{0, 1};
        create_player(.{18, 7}, starting_world_pos);
        request_map_change(current_map, starting_world_pos);
    }

    update :: (delta_time : float32) {
        game := *context.game;

        game.second += delta_time;
        if game.second > 1.0 then game.second -= 1.0;

        if game.state == { 
            case .GAME;
                for game.entities {
                    if it.tag == {
                        case .PLAYER;
                            Player.simulate(xx it, delta_time);
                        case .ENEMY; 
                            Enemy.simulate(xx it, delta_time);
                        case .TELEPORTER;
                            Teleporter.simulate(xx it, delta_time);
                        case .WEAPON;
                            Weapon.simulate(xx it, delta_time);
                        case .PICKUP;
                            Pickup.simulate(xx it, delta_time);
                    }
                }
            case .EDITOR; {
                #if DEVELOPER {
                    Editor.update();
                }
            }
            case .DIALOG; {
                Dialog.update(delta_time);
            }
        }

        for game.entities {
            if it.flags & .SHOULD_DELETE {
                Basic.free(it);
                remove it;
            }
        }
    }

    draw :: () {
        game := *context.game;
        if game.state == .EDITOR {
            Simp.clear_render_target(0.5, 0, 0, 1);
        } else {
            Simp.clear_render_target(0, 0, 0, 1);
        }

        Map.draw_layer(0, game.current_map, *game.map_texture, game.camera_position);

        layer_separator :: (layer : int) {
            #if DEVELOPER {
                if context.game.state == .EDITOR && context.editor.current_layer > layer {
                    Simp.set_shader_for_color(true);
                    Simp.immediate_quad(x0 = xx 0, y0 = xx 0, x1 = xx context.game.screen_width, y1 = xx context.game.screen_height, color = .{1, 1, 1, 0.5});
                }
            }
        }

        layer_separator(0);
        Map.draw_layer(1, game.current_map, *game.map_texture, game.camera_position);
        layer_separator(1);

        // Sort entities in y
        sort_entities(game.entities);

        for game.entities {
            Entity.draw(it);
        }

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
        Basic.log("request: %", map_pos);
        success := Map.load(current_map, map_pos);
        if !success return false;
        context.game.current_world_pos = map_pos;

        for context.game.entities {
            if it.world_pos != map_pos {
                it.flags |= .SHOULD_DELETE;
            }
        }

        load_entities(map_pos);
        return true;
    }

    sort_entities :: (arr : [..]* Entity) {
        for i: 1..arr.count - 1 {
            entity := arr[i];
            y := arr[i].position.y;
            j := i - 1;
            while (j >= 0 && arr[j].position.y < y) {
                arr[j + 1] = arr[j];
                j -= 1;
            }
            arr[j + 1] = entity;
        }
    }

    // @Temporary : Until we have entity loading.
    load_entities :: (map_pos : Vector2i) {

        if map_pos == .{-1, 0} { // Interior
            create_teleporter(.{14, 8}, .{13, 12}, .{0, 0});
            create_teleporter(.{15, 8}, .{13, 12}, .{0, 0});
        } else if map_pos == .{0, 0} { // Town South
            create_teleporter(.{13, 13}, .{14.5, 9}, .{-1, 0});
            create_enemy(.{10, 10});
            create_key(.{20, 10});
            create_door(.{20, 20});
        } else if map_pos == .{0, 1} { // Town North
            create_bush(.{18, 14});
            create_bush(.{18, 8});
            create_bush(.{16, 8});
            create_bush(.{14, 8});
        } else if map_pos == .{1, 1} {
            create_bush(.{5, 11});
        }
    }

    rect_intersects :: (a0 : Vector2, a1 : Vector2, b0 : Vector2, b1 : Vector2) -> bool {
        return a0.x < b1.x && a1.x > b0.x && a0.y < b1.y && a1.y > b0.y;
    }

    is_point_in_rect :: (p : Vector2, a1 : Vector2, a2 : Vector2) -> bool {
        return p.x > a1.x && p.x < a2.y && p.y > a1.y && p.y < a2.y;
    }

    new_entity :: ($type : Type) -> *type {
        e := Basic.New(type);
        Basic.array_add(*context.game.entities, e);
        return e;
    }

    create_player :: (pos : Vector2, world_pos : Vector2i) {
        player := new_entity(Player);
        player.sprite_sheet = *context.game.blue_samurai_texture;
        player.position = pos;
        player.world_pos = world_pos;
        player.flags |= .SOLID;
    }

    create_enemy :: (pos : Vector2) -> *Entity {
        e := new_entity(Enemy);
        e.sprite_sheet = *context.game.red_samurai_texture;
        e.position = pos;
        e.world_pos = context.game.current_world_pos;
        e.flags |= .SOLID;
        return e;
    }

    create_weapon :: (parent : Entity, target: Entity.Tag, time : float) -> *Entity {
        weapon := new_entity(Weapon);
        weapon.look_for = target;
        weapon.position = parent.position;
        weapon.position += forward(parent.direction);
        weapon.direction = parent.direction;
        weapon.world_pos = parent.world_pos;
        weapon.p0.x = -0.4;
        weapon.p0.y = -0.2;
        weapon.p1.x = 0;
        weapon.p1.y = 0.5;
        weapon.time_left = time;
        weapon.sprite_sheet = *context.game.katana_texture;
        weapon.sprite.x = xx weapon.direction;
        Basic.log("pos: %", weapon.position);
        return weapon;
    }

    create_teleporter :: (pos : Vector2, new_pos : Vector2, new_world_pos : Vector2i) -> *Teleporter {
        tp := new_entity(Teleporter);
        tp.position = pos;
        tp.world_pos = context.game.current_world_pos;
        tp.new_pos = new_pos;
        tp.new_world_pos = new_world_pos;
        return tp;
    }

    create_bush :: (pos : Vector2) {
        e := new_entity(Entity);
        e.position = pos;
        e.flags |= .SOLID;
        e.world_pos = context.game.current_world_pos;
        e.sprite_sheet = *context.game.map_texture;
        x, y := tile_id_to_xy(*context.game.map_texture, 1895);
        e.sprite.x = xx x;
        e.sprite.y = xx y;

        e.hit_tag = .ENEMY;
        e.health = 1;
    }

    create_key :: (pos : Vector2) {
        e := new_entity(Pickup);
        e.position = pos;
        e.world_pos = context.game.current_world_pos;
        e.sprite_sheet = *context.game.key_texture;
        e.pickup_type = .KEY;
    }

    create_door :: (pos: Vector2){
        e := new_entity(Door);
        e.position = pos;
        e.world_pos = context.game.current_world_pos;
        e.sprite_sheet = *context.game.map_texture;
        x, y := tile_id_to_xy(*context.game.map_texture, 3414);
        e.sprite.x = xx x;
        e.sprite.y = xx y;
    }

    /// Computes a new velocity that avoids map obstacles
    move_and_slide :: (entity: *Entity, velocity : Vector2, map : Map) -> Vector2 {
        // @Speed : Get the sign of the velocity? to check only 1 side
        is_move_possible :: (entity: *Entity, new_center : Vector2, map : Map) -> bool {
            if Map.get_collision_at(map, new_center + entity.p1) == 0 &&
            Map.get_collision_at(map, new_center + entity.p0) == 0 &&
            Map.get_collision_at(map, new_center + xy(entity.p0.x, entity.p1.y)) == 0 &&
            Map.get_collision_at(map, new_center + xy(entity.p1.x, entity.p0.y)) == 0 {
                // Check entities
                p0 := new_center + entity.p0;
                p1 := new_center + entity.p1;
                for context.game.entities {
                    if it == entity then continue;
                    if it.flags & .SOLID {
                        is_in_rect := Game.rect_intersects(p0, p1, it.position + it.p0, it.position + it.p1);
                        if is_in_rect {
                            return false;
                        }
                    }
                }
                return true;
            }
            return false;
        }

        result : Vector2;
        new_center_x := entity.position + xy(velocity.x, 0);
        new_center_y := entity.position + xy(0, velocity.y);

        if is_move_possible(entity, new_center_x, map) {
            result.x += velocity.x;
        }

        if is_move_possible(entity, new_center_y, map) {
            result.y += velocity.y;
        }

        entity.position += result;
        if entity.position.y >= MAP_HEIGHT - 1 {
            entity.world_pos.y += 1;
            entity.position.y = 0;
            if entity.tag == .PLAYER {
                Game.request_map_change(context.game.current_map, entity.world_pos);
            }
        }
        if entity.position.y < 0 {
            entity.world_pos.y -= 1;
            entity.position.y = MAP_HEIGHT - 1;
            if entity.tag == .PLAYER {
                Game.request_map_change(context.game.current_map, entity.world_pos);
            }
        }

        if entity.position.x >= MAP_WIDTH - 1 {
            entity.world_pos.x += 1;
            entity.position.x = 0;
            if entity.tag == .PLAYER {
                Game.request_map_change(context.game.current_map, entity.world_pos);
            }
        }
        if entity.position.x < 0 {
            entity.world_pos.x -= 1;
            entity.position.x = MAP_WIDTH - 1;
            if entity.tag == .PLAYER {
                Game.request_map_change(context.game.current_map, entity.world_pos);
            }
        }
        return result;
    }

    get_player :: () -> *Player {
        for context.game.entities {
            if it.tag == .PLAYER then return xx it;
        }
        Basic.assert(false, "Couldn't find the player entity");
        return null;
    }
}

