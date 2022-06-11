
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

    player : Character;
    player_brain : Player_Brain;

    all_characters : [..]Character;
    active_characters : [..]*Character;
    inactive_characters : [..]*Character;
    npc_brains : [..]NPC_Brain;
    enemy_brains : [..]Enemy_Brain;

    load :: () {
        using context.game;

        Renderer.load_texture(*blue_samurai_texture, "res/blue_samurai.png");
        Renderer.load_texture(*red_samurai_texture, "res/red_samurai.png");
        Renderer.load_texture(*map_texture, "res/world.png");
        player = Character.init(tag = .PLAYER, sprite_sheet = blue_samurai_texture);
        Basic.array_add(*all_characters, Character.init(tag = .NPC, sprite_sheet = blue_samurai_texture));
        Basic.array_add(*all_characters, Character.init(tag = .ENEMY, pos = .{2, 2}, sprite_sheet = red_samurai_texture));
        request_map_change(current_map, player.world_pos);
    }

    update :: (delta_time : float32) {
        game := *context.game;
        if game.state == .GAME {
            Player_Brain.update(*game.player_brain, *game.player, delta_time);

            // @Speed : Easy to multithread
            for * game.npc_brains {
                NPC_Brain.update(it, delta_time);
            }
            for * game.enemy_brains {
                Enemy_Brain.update(it, *game.player, delta_time);
            }
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

        // Player
        Character.draw(*game.player);
        for game.active_characters {
            Character.draw(it);
        }

        Map.draw_layer(2, game.current_map, *game.map_texture, game.camera_position);

        if game.state == .EDITOR {
            Editor.draw();
        }
    }

    request_map_change :: (current_map : Map, map_pos : Vector2) -> bool {

        success := Map.load(current_map, map_pos);

        if !success return false;
        
        Basic.array_reset_keeping_memory(*context.game.active_characters);
        Basic.array_reset_keeping_memory(*context.game.inactive_characters);
        Basic.array_reset_keeping_memory(*context.game.npc_brains);
        Basic.array_reset_keeping_memory(*context.game.enemy_brains);

        for context.game.all_characters {
            if it.world_pos == map_pos {
                char := *context.game.all_characters[it_index];
                Basic.array_add(*context.game.active_characters, char);
                if char.tag == {
                    case .NPC; 
                        brain := Basic.array_add(*context.game.npc_brains);
                        brain.char = char;
                    case .ENEMY;
                        brain := Basic.array_add(*context.game.enemy_brains); 
                        brain.char = char;
                }
            } else {
                Basic.array_add(*context.game.inactive_characters, *context.game.all_characters[it_index]);
            }
        }

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
