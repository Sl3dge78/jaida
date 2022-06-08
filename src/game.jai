
Game :: struct {
    State :: enum {
        GAME;
        EDITOR;
    };

    state : State = .GAME;
    screen_width : s32;
    screen_height : s32;
    player : Character;
    player_texture : Renderer.Texture;
    player_animator : Animator;
    current_map : Map;
    world_pos : Vector2 = .{0, 0};
    map_texture : Renderer.Texture;
    camera_position : Vector2 = .{0.5, 0.75};

    load :: () {
        using context.game;

        Renderer.load_texture(*player_texture, "res/blue_samurai.png");
        Renderer.load_texture(*map_texture, "res/world.png");
        Map.load(current_map, world_pos);
        player = Character.init(sprite_sheet = player_texture);
    }

    update :: (delta_time : float32) {
        game := *context.game;
        if game.state == .GAME {
            { // Player update 
                player := *game.player;
                // Movement
                player_vel : Vector2;
                if Input.get_keyboard(SDL_SCANCODE_W) then player_vel.y += 1;         
                if Input.get_keyboard(SDL_SCANCODE_A) then player_vel.x -= 1;
                if Input.get_keyboard(SDL_SCANCODE_S) then player_vel.y -= 1; 
                if Input.get_keyboard(SDL_SCANCODE_D) then player_vel.x += 1; 
                norm_vel := Math.unit_vector(player_vel) * (delta_time * PLAYER_SPEED);
                Character.translate_and_animate(player, norm_vel, *game.player_animator);

                // World movement
                world_movement : Vector2;
                if player.pos.x < 0              then world_movement -= Vector2.{1, 0};
                if player.pos.x > MAP_WIDTH - 1  then world_movement += Vector2.{1, 0};
                if player.pos.y < 0.1            then world_movement -= Vector2.{0, 1};
                if player.pos.y > MAP_HEIGHT - 1 then world_movement += Vector2.{0, 1};
                if Math.length(world_movement) > 0 {
                    if Map.exists(game.world_pos + world_movement) {
                        game.world_pos += world_movement;
                        Map.load(game.current_map, game.world_pos);
                        if world_movement.x < 0 then player.pos.x = MAP_WIDTH - 1;
                        if world_movement.x > 0 then player.pos.x = 0;
                        if world_movement.y < 0 then player.pos.y = MAP_HEIGHT - 1;
                        if world_movement.y > 0 then player.pos.y = 0.1;
                    }
                }
            }

            Animator.update(*game.player_animator, delta_time);
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
        Animator.set_char_sprites(*game.player_animator, *game.player);
        Character.draw(*game.player);

        Map.draw_layer(2, game.current_map, *game.map_texture, game.camera_position);

        if game.state == .EDITOR {
            Editor.draw();
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
}

#add_context game : Game;
