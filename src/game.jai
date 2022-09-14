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
    if !result {
        Basic.log_error("Unable to load texture %", path);
        Basic.exit(0);
    }
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    return result;
}

#add_context game : Game;

load_all_actors :: () {
    #insert #run -> string {
        #import "File_Utilities";
        builder : Basic.String_Builder;

        Basic.set_working_directory("bin");
        all_actor_files := file_list("res/actor");
        for all_actor_files {
            name := String.path_strip_extension(String.path_filename(it));
            Basic.print_to_builder(*builder, "load_texture_no_filter(*actors.%, \"%\");\n", name, it);
        }
        Basic.set_working_directory("../");
        return Basic.builder_to_string(*builder);
    };
}

Actors :: struct {

    // Contains all the textures
    #insert #run -> string {
        builder : Basic.String_Builder;

        all_actor_files := file_list("bin/res/actor");
        for all_actor_files {
            name := String.path_strip_extension(String.path_filename(it));
            Basic.print_to_builder(*builder, "%: Simp.Texture;\n", name);
        }
        return Basic.builder_to_string(*builder);
    };
}

actors : Actors;

Game :: struct {
    State :: enum {
        GAME;
        PAUSE;
        EDITOR;
        DIALOG;
        DEATH;
        GAME_OVER;
        MAIN_MENU;
    };
    
    Palette :: struct {
        BLACK       :: Vector4.{0.078, 0.106, 0.106, 1};
        BLUE        :: Vector4.{0.176, 0.412, 0.482, 1};
        ORANGE      :: Vector4.{1, 0.584, 0.329, 1};
        DARK_ORANGE :: Vector4.{0.82, 0.294, 0.204, 1};
    };

    state : State = .MAIN_MENU;
    quit : bool = false;
    screen_width : s32;
    screen_height : s32;
    starting_world_pos :: Vector2i.{-1, 0};

    audio_device : SDL_AudioDeviceID = ---;
    volume : s8 = 32;

    font : *Simp.Dynamic_Font;
    small_font : *Simp.Dynamic_Font;

    mouse_x : int;
    mouse_y : int;

    respawn_position : Vector2 = .{15, 10};
    respawn_map : Vector2i = starting_world_pos;
    // respawn_position : Vector2 = .{19, 6.5};
    //respawn_map : Vector2i = DUNGEON;

    current_map : Map;
    current_world_pos : Vector2i;
    map_texture : Simp.Texture;
    
    camera_position : Vector2 = .{0.5, 0.75};

    hearts_texture       : Simp.Texture;
    shadow_texture       : Simp.Texture;
    key_texture          : Simp.Texture;
    katana_texture       : Simp.Texture;

    entities : [..]* Entity;

    // Dialog
    dialogbox_texture : Simp.Texture;
    dialogbox_notitle_texture : Simp.Texture;
    dialogbox_choice_texture : Simp.Texture;

    current_dialog_tree : []Dialog.Node;
    current_dialog_node : u8; // I don't think we'll ever get a dialog tree bigger than 255...
    current_choice : s8;

    current_line : int; // The line we're in the process of drawing
    current_char : int; // The character we last drew
    char_timer : float; // Time until the next character gets drawn
    dialog_blip : Audio_Stream;

    // Quest
    main_quest_state : enum {
        START;
        SWORD_OK;
        TRAINING_OK;
        QUEST_ACCEPTED;
        KEY_GOT;
        DOOR_OPEN;
        BOSS_KILLED;
    };

    // This is a timer that is reset every second
    second : float;

    // Death
    death_timer : float;
    death_current_selection : enum {
        CONTINUE;
        QUIT;
    } = .CONTINUE;

    // Main menu
    menu_current_selection : enum {
        START;
        QUIT;   
    } = .START;

    load :: () {
        using context.game;

        Random.random_seed(cast(u64) Basic.get_time());

        font = Simp.get_font_at_size("res", "monospace.ttf", 8 * ZOOM);
        small_font = Simp.get_font_at_size("res", "monospace.ttf", 4 * ZOOM);

        // Map
        load_texture_no_filter(*map_texture, "res/world.png");

        // UI
        load_texture_no_filter(*hearts_texture, "res/ui/hearts.png");

        load_texture_no_filter(*dialogbox_texture, "res/ui/dialogbox.png");
        load_texture_no_filter(*dialogbox_notitle_texture, "res/ui/dialogbox_notitle.png");
        load_texture_no_filter(*dialogbox_choice_texture, "res/ui/dialogbox_choice.png");

        load_all_actors();
        load_texture_no_filter(*shadow_texture, "res/shadow.png");

        // Items
        load_texture_no_filter(*katana_texture, "res/katana.png");
        load_texture_no_filter(*key_texture, "res/key.png");

        dialog_blip = Audio_Stream.load("res/audio/blip.wav");
        
        player := create_player(context.game.respawn_position, context.game.respawn_map);
        // player.can_attack = true;
        Game.switch_state(.MAIN_MENU);
    }

    update :: (delta_time : float32) {
        game := *context.game;

        game.second += delta_time;
        if game.second > 1.0 then game.second -= 1.0;

        if game.state == { 
            case .MAIN_MENU; {
                if Input.input_button_states[#char "W"] & .START {
                    if game.menu_current_selection > .START {
                        game.menu_current_selection -= 1;
                    }
                }
                if Input.input_button_states[#char "S"] & .START {
                    if game.menu_current_selection < .QUIT {
                        game.menu_current_selection += 1;
                    }
                }

                if Input.input_button_states[#char "E"] & .START {
                    if game.menu_current_selection == .START {
                        Game.request_map_change(game.current_map, game.respawn_map);
                        Game.switch_state(.GAME);
                    } else {
                        game.quit = true;
                    }
                }
            }
            case .GAME; {
                if Input.input_button_states[Input.Key_Code.ESCAPE] & .START {
                    Game.switch_state(.PAUSE);
                }
                for game.entities {
                    if it.tag == {
                        case .PLAYER;
                            Player.simulate(xx it, delta_time);
                        case .ENEMY; 
                            Enemy.simulate(xx it, delta_time);
                        case .TELEPORTER;
                            Teleporter.simulate(xx it, delta_time);
                        case .WEAPON;
                            Damage_Area.simulate(xx it, delta_time);
                        case .PICKUP;
                            Pickup.simulate(xx it, delta_time);
                        case .BOSS;
                            Boss.simulate(xx it, delta_time);
                        case .NPC;
                            NPC.simulate(xx it, delta_time);
                    }
                }
            }
            case .PAUSE; {
                if Input.input_button_states[Input.Key_Code.ESCAPE] & .START {
                    Game.switch_state(.GAME);
                }

                if Input.input_button_states[#char "W"] & .START {
                    if game.menu_current_selection > .START {
                        game.menu_current_selection -= 1;
                    }
                }
                if Input.input_button_states[#char "S"] & .START {
                    if game.menu_current_selection < .QUIT {
                        game.menu_current_selection += 1;
                    }
                }

                if Input.input_button_states[#char "E"] & .START {
                    if game.menu_current_selection == .START {
                        Game.switch_state(.GAME);
                    } else {
                        game.quit = true;
                    }
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
            case .DEATH; {
                game.death_timer -= delta_time;
                if game.death_timer <= 0 {
                    Game.switch_state(.GAME_OVER);
                }
            }
            case .GAME_OVER; {
                if Input.input_button_states[#char "W"] & .START {
                    if game.death_current_selection != .CONTINUE {
                        game.death_current_selection -= 1;
                    }
                }
                if Input.input_button_states[#char "S"] & .START {
                    if game.death_current_selection < .QUIT {
                        game.death_current_selection += 1;
                    }
                }

                if Input.input_button_states[#char "E"] & .START {
                    if game.death_current_selection == .CONTINUE {
                        Game.switch_state(.GAME);
                    } else {
                        Game.switch_state(.MAIN_MENU);
                    }
                }
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
        layer_separator :: (layer : int) {
            #if DEVELOPER {
                if context.game.state == .EDITOR && context.editor.current_layer > layer {
                    Simp.set_shader_for_color(true);
                    Simp.immediate_quad(x0 = xx 0, y0 = xx 0, x1 = xx context.game.screen_width, y1 = xx context.game.screen_height, color = .{1, 1, 1, 0.5});
                }
            }
        }

        game := *context.game;

        // Sort entities in y
        sort_entities(game.entities);

        if game.state == .EDITOR {
            Simp.clear_render_target(0.5, 0, 0, 1);
        } else {
            Simp.clear_render_target(0, 0, 0, 1);
        }

        Map.draw_layer(0, game.current_map, *game.map_texture, game.camera_position);
        layer_separator(0);

        for game.entities {
            Entity.draw_shadow(it);
        }

        Map.draw_layer(1, game.current_map, *game.map_texture, game.camera_position);
        layer_separator(1);

        for game.entities {
            Entity.draw(it);
        }

        Map.draw_layer(2, game.current_map, *game.map_texture, game.camera_position);
        layer_separator(2);

        // UI
        if game.state == .GAME {
            draw_ui();
        }

        if game.state == .DIALOG {
            Dialog.draw();
        }

        if game.state == {
            case .MAIN_MENU; {
                Simp.set_shader_for_color(true);
                Simp.immediate_quad(0, 0, 1280, 720, make_vector4(0, 0, 0, 0.2));

                Simp.draw_text(game.font, 100, 650, "GENERIC ADVENTURE GAME", make_vector4(1, 0, 0, 1));
                
                Simp.draw_text(game.font, 80, ifx game.menu_current_selection == .START then 250 else 200, ">");
                Simp.draw_text(game.font, 100, 250, "Start",
                    ifx game.menu_current_selection == .START then make_vector4(1, 0, 0, 1) else make_vector4(1, 1, 1, 1));
                Simp.draw_text(game.font, 100, 200, "Quit", 
                    ifx game.menu_current_selection == .QUIT then make_vector4(1, 0, 0, 1) else make_vector4(1, 1, 1, 1));
            }
            case .PAUSE; {
                Simp.set_shader_for_color(true);
                Simp.immediate_quad(0, 0, 1280, 720, make_vector4(1, 1, 1, 0.5));

                Simp.draw_text(game.font, 100, 650, "GENERIC ADVENTURE GAME", make_vector4(1, 0, 0, 1));
                
                Simp.draw_text(game.font, 80, ifx game.menu_current_selection == .START then 250 else 200, ">");
                Simp.draw_text(game.font, 100, 250, "Resume",
                    ifx game.menu_current_selection == .START then make_vector4(1, 0, 0, 1) else make_vector4(1, 1, 1, 1));
                Simp.draw_text(game.font, 100, 200, "Quit", 
                    ifx game.menu_current_selection == .QUIT then make_vector4(1, 0, 0, 1) else make_vector4(1, 1, 1, 1));
            }
            case .DEATH; {
                Simp.set_shader_for_color(true);
                Simp.immediate_quad(0, 0, 1280, 720, make_vector4(0, 0, 0, 1.0 - (game.death_timer / 4.0)));
            }
            case .GAME_OVER; {
                Simp.set_shader_for_color(true);
                Simp.immediate_quad(0, 0, 1280, 720, make_vector4(0, 0, 0, 1));

                Simp.draw_text(game.font, 100, 650, "YOU ARE DEAD", make_vector4(1, 0, 0, 1));

                Simp.draw_text(game.font, 80, ifx game.death_current_selection == .CONTINUE then 250 else 200, ">");

                Simp.draw_text(game.font, 100, 250, "Continue",
                    ifx game.death_current_selection == .CONTINUE then make_vector4(1, 0, 0, 1) else make_vector4(1, 1, 1, 1));
                Simp.draw_text(game.font, 100, 200, "Quit", 
                    ifx game.death_current_selection == .QUIT then make_vector4(1, 0, 0, 1) else make_vector4(1, 1, 1, 1));
            }
        }

        #if DEVELOPER {
            Editor.draw();
        }        
    }

    draw_ui :: () {
        Simp.set_shader_for_images(*context.game.hearts_texture);

        player := Game.get_player();

        x0 : float = 16 * ZOOM * 1; 
        y0 : float = xx (context.game.screen_height - 16 * ZOOM * 2);

        heart_size := 16;

        for 0..3 { // @Hardcoded
            uv0 := Vector2.{0, 0};
            uv1 := Vector2.{0.5, 1};
            if player.health <= it {
                uv0 = .{0.5, 0};
                uv1 = .{1, 1};
            }
            
            Simp.immediate_quad(
                make_vector2(x0, y0),
                make_vector2(x0 + 16 * ZOOM, y0),
                make_vector2(x0 + 16 * ZOOM, y0 + 16 * ZOOM),
                make_vector2(x0, y0 + 16 * ZOOM), 
                .{1, 1, 1, 1},
                uv0, 
                make_vector2(uv1.x, uv0.y),
                make_vector2(uv1.x, uv1.y),
                make_vector2(uv0.x, uv1.y));
            x0 += 16 * ZOOM;
        }

        // Key
        if player.keys > 0 {
            x0 += 16 * ZOOM; // 1 tile padding
            Simp.set_shader_for_images(*context.game.key_texture);
            Simp.immediate_quad(x0, y0, xx (x0 + 16 * ZOOM), xx (y0 + 16 * ZOOM), .{1, 1, 1, 1});
        }
    }

    request_map_change :: (current_map : Map, map_pos : Vector2i) -> bool {
        Basic.log("request: %", map_pos);
        success := Map.load(current_map, map_pos);
        if !success return false;
        context.game.current_world_pos = map_pos;
        player := Game.get_player();

        if context.game.current_world_pos == player.world_pos {
            player.flags &= ~.HIDDEN;
        } else {
            player.flags |= .HIDDEN;
        }

        for context.game.entities {
            if it.tag != .PLAYER {
                it.flags |= .SHOULD_DELETE;
            }
        }

        Map.load_entities(map_pos);
        return true;
    }

    set_spawn :: (map_pos : Vector2i, pos : Vector2) {
        context.game.respawn_map = map_pos;
        context.game.respawn_position = pos;
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

    rect_intersects :: (a0 : Vector2, a1 : Vector2, b0 : Vector2, b1 : Vector2) -> bool {
        return a0.x < b1.x && a1.x > b0.x && a0.y < b1.y && a1.y > b0.y;
    }

    is_point_in_rect :: (p : Vector2, a1 : Vector2, a2 : Vector2) -> bool {
        return p.x > a1.x && p.x < a2.y && p.y > a1.y && p.y < a2.y;
    }

    new_entity :: ($type : Type) -> *type {
        e := Basic.New(type);
        Basic.array_add(*context.game.entities, xx e);
        e.world_pos = context.game.current_world_pos;
        return e;
    }

    switch_state :: (to: Game.State){
        game := *context.game;
        player := Game.get_player();
        if to == {
            case .GAME; {
                if game.state != .PAUSE {
                    player.position = game.respawn_position;
                    player.world_pos = game.respawn_map;
                    player.health = 4;
                    player.color = .{1, 1, 1, 1};
                    player.immunity = 0;
                    Game.request_map_change(game.current_map, game.respawn_map);
                }             }
            case .MAIN_MENU; {
                Game.request_map_change(game.current_map, .{0, 0});
            }
            case .DEATH; {
                game.death_timer = 4.0;
            }
            case .GAME_OVER; {

            }
        }
        game.state = to;
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
                set_spawn(entity.world_pos, entity.position);
                Game.request_map_change(context.game.current_map, entity.world_pos);
            }
        }
        if entity.position.y < 0 {
            entity.world_pos.y -= 1;
            entity.position.y = MAP_HEIGHT - 1;
            if entity.tag == .PLAYER {
                set_spawn(entity.world_pos, entity.position);
                Game.request_map_change(context.game.current_map, entity.world_pos);
            }
        }

        if entity.position.x >= MAP_WIDTH - 1 {
            entity.world_pos.x += 1;
            entity.position.x = 0;
            if entity.tag == .PLAYER {
                set_spawn(entity.world_pos, entity.position);
                Game.request_map_change(context.game.current_map, entity.world_pos);
            }
        }
        if entity.position.x < 0 {
            entity.world_pos.x -= 1;
            entity.position.x = MAP_WIDTH - 1;
            if entity.tag == .PLAYER {
                set_spawn(entity.world_pos, entity.position);
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

