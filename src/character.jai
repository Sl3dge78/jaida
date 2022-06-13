Entity :: struct {

    Type :: enum {
        PLAYER;
        NPC;
        ENEMY;
    };
    type : Type = ---;
    pos : Vector2;
    sprite_sheet : Renderer.Texture = ---;
    time : float32;
    direction : Direction;
    state : enum {
        IDLE;
        WALKING;
        ATTACKING;
    } = .IDLE;
    world_pos : Vector2;
    hit_points : u16;

    init :: (type: Type, pos : Vector2 = .{20, 11}, sprite_sheet : Renderer.Texture) -> Entity {
        result : Entity;
        result.type = type;
        result.pos = pos;
        result.sprite_sheet = sprite_sheet;
        return result;
    }

    // @Cleanup: this is more like update animation
    update :: (using this : *Entity, dt : float32) {
        if state == .IDLE then return;

        time += dt;

        // @Hardcoded: Have an animation time? Auto transitions? Loop
        if state == {
            case .WALKING; {
                if time > 1.0 then time = 0;
            }
            case .ATTACKING; {
                if time >= 0.1 {
                    state = .IDLE;
                    time = 0;
                }
            }
        }
    }

    translate_and_animate :: (char: *Entity, vel : Vector2) {
        final_vel := Game.move_and_slide(char.pos, vel, context.game.current_map);
        char.pos += final_vel;

        // Walk animation
        if length(final_vel) > 0 {
            char.state = .WALKING;
            if final_vel.x > 0 then char.direction = Direction.EAST;
            if final_vel.x < 0 then char.direction = Direction.WEST;
            if final_vel.y > 0 then char.direction = Direction.NORTH;
            if final_vel.y < 0 then char.direction = Direction.SOUTH;
        } else {
            char.state = .IDLE;
        }
    }

    draw :: (using this : *Entity) {
        Renderer.set_shader_for_images(*sprite_sheet);
        x0, y0 := Map.map_to_screen(context.game.camera_position, pos + Vector2.{-0.5, -0.5});
        x1, y1 := Map.map_to_screen(context.game.camera_position, pos + Vector2.{+0.5, +0.5});
        sprite_y := 0;
        if state == { // @Hardcoded
            case .IDLE; sprite_y = 6; 
            case .WALKING; sprite_y = 6 - cast(u32)(time * 4.0); 
            case .ATTACKING; sprite_y = 2;
        }
        uv0, uv1 := get_uv_from_texture(*sprite_sheet, xx direction, sprite_y);
        Renderer.immediate_quad(x0 = xx x0, y0 = xx y0, x1 = xx x1, y1 = xx y1, uv0 = uv0, uv1 = uv1);
        if state == .ATTACKING {
            katana_tex := context.game.katana_texture;
            uv0, uv1 = get_uv_from_texture(*katana_tex, xx direction, 0);
            weapon_center := pos + forward(this);
            w_x0, w_y0 := Map.map_to_screen(context.game.camera_position, weapon_center + Vector2.{-0.5, -0.5});
            w_x1, w_y1 := Map.map_to_screen(context.game.camera_position, weapon_center + Vector2.{0.5, 0.5});
            Renderer.set_shader_for_images(*katana_tex);
            Renderer.immediate_quad(x0 = xx w_x0, y0 = xx w_y0, x1 = xx w_x1, y1 = xx w_y1, uv0 = uv0, uv1 = uv1);
        }
    }

    forward :: (char : *Entity) -> Vector2 {
        if char.direction == {
            case .EAST; return .{1, 0};
            case .WEST; return .{-1, 0};
            case .NORTH; return .{0, 1};
            case .SOUTH; return .{0, -1};
        }
        return .{0, 0};
    }
}

Player_Brain :: struct {
    SPEED :: 5.0;

    update :: (using brain : *Player_Brain, char : *Entity, delta_time : float32) {
        if char.state != .ATTACKING {
            // Movement
            player_vel : Vector2;
            if Input.get_keyboard(SDL_SCANCODE_W) then player_vel.y += 1;         
            if Input.get_keyboard(SDL_SCANCODE_A) then player_vel.x -= 1;
            if Input.get_keyboard(SDL_SCANCODE_S) then player_vel.y -= 1; 
            if Input.get_keyboard(SDL_SCANCODE_D) then player_vel.x += 1; 
            norm_vel := Math.unit_vector(player_vel) * (delta_time * SPEED);
            Entity.translate_and_animate(char, norm_vel);

            // World movement
            world_movement : Vector2;
            if char.pos.x < 0              then world_movement -= Vector2.{1, 0};
            if char.pos.x > MAP_WIDTH - 1  then world_movement += Vector2.{1, 0};
            if char.pos.y < 0.1            then world_movement -= Vector2.{0, 1};
            if char.pos.y > MAP_HEIGHT - 1 then world_movement += Vector2.{0, 1};
            if Math.length(world_movement) > 0 {
                if Map.exists(char.world_pos + world_movement) {
                    char.world_pos += world_movement;
                    if(Game.request_map_change(context.game.current_map, char.world_pos)) {
                        if world_movement.x < 0 then char.pos.x = MAP_WIDTH - 1;
                        if world_movement.x > 0 then char.pos.x = 0;
                        if world_movement.y < 0 then char.pos.y = MAP_HEIGHT - 1;
                        if world_movement.y > 0 then char.pos.y = 0.1;
                    }
                }
            }
        }

        // Attack
        if Input.pressed_this_frame(SDL_SCANCODE_SPACE) {
            if char.state != .ATTACKING {
               char.state = .ATTACKING;
               char.time = 0;
            }
        }

        Entity.update(char, delta_time);
    }
}

NPC_Brain :: struct {
    char : *Entity;
    current_dest : Vector2;
    SPEED :: 2.5;
    wait_time : float32 = 0;
    state : enum {
        IDLE;
        WALKING;
    } = .IDLE;

    update :: (using brain : *NPC_Brain, delta_time : float32) {
        if state == {
            case .IDLE; {
                if wait_time > 0 then wait_time -= delta_time;
                else {
                    current_dest = char.pos;
                    state = .WALKING;
                    if Random.random_get_zero_to_one() < .5 {
                        current_dest.x += ifx Random.random_get_zero_to_one() < .5 then -1 else 1;
                    } else {
                        current_dest.y += ifx Random.random_get_zero_to_one() < .5 then -1 else 1;
                    }
                }
            }
            case .WALKING; {
                if Math.distance(current_dest, char.pos) <= 0.1 {
                    char.state = .IDLE;
                    state = .IDLE;
                    wait_time = Random.random_get_within_range(1, 5);
                } else {
                    dir := Math.unit_vector(current_dest - char.pos);
                    Entity.translate_and_animate(char, dir * SPEED * delta_time);
                }
            }
        }

        Entity.update(char, delta_time);
    }
}

Enemy_Brain :: struct {
    char : *Entity;
    SPEED :: 3.0;
    state : enum {
        IDLE;
        AGGROED;
    } = .IDLE;
    AGGRO_DISTANCE :: 10.0;

    update :: (using brain : *Enemy_Brain, player : *Entity, delta_time : float32) {
        if state == {
            case .IDLE;
            if Math.distance(char.pos, player.pos) <= AGGRO_DISTANCE {
                state = .AGGROED;
            }
            case .AGGROED;
            if Math.distance(char.pos, player.pos) >= 2.0 * AGGRO_DISTANCE {
                state = .IDLE;
            } else {
                dir := Math.unit_vector(player.pos - char.pos);
                Entity.translate_and_animate(char, dir * SPEED * delta_time);
            }
        } 
    }
}


Projectile_Brain :: struct {
    entity : *Entity;
    time_alive : float;
    mask : Entity.Type = ---;

    update :: (using brain : *Projectile_Brain, proj : *Entity, dt : float32) {
        // @Todo : Check all active entities, and collide with them

    }
}
