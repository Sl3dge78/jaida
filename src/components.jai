Component :: struct {
    entity : *Entity; // @Todo change that to offset into table 
    loc : Bucket_Locator;

    require_component :: ($component : Type) #expand {
        Basic.assert(Entity.has_component(`entity, component));
    }
}

Sprite :: struct {
    using component : Component;

    sprite_sheet : Renderer.Texture = ---; 
    x0, y0, x1, y1 : int;
    sprite_x : u32;
    sprite_y : u32;

    update :: (using sprite : *Sprite, delta_time : float) {
        animation := Entity.get_component(entity, Animation);
        if animation {
            if animation.state == { 
                case .IDLE;      sprite_y = 6; 
                case .WALKING;   sprite_y = 6 - cast(u32)(animation.time * 4.0); 
                case .ATTACKING; sprite_y = 2;
            }
        }

        xform := Entity.get_component(entity, Transform);
        if xform {
            x0, y0 = Map.map_to_screen(context.game.camera_position, xform.pos - Vector2.{0.5, 0.5});
            x1, y1 = Map.map_to_screen(context.game.camera_position, xform.pos + Vector2.{0.5, 0.5});
            sprite_x = xx xform.direction;
        }
    }

    draw :: (using sprite: *Sprite) {
        uv0, uv1 := get_uv_from_texture(*sprite_sheet, sprite_x, sprite_y);
        Renderer.set_shader_for_images(*sprite_sheet);
        Renderer.immediate_quad(x0 = xx x0, y0 = xx y0, x1 = xx x1, y1 = xx y1, uv0 = uv0, uv1 = uv1);
    }

} @Component @Draw @Update

Transform :: struct {
    using component : Component;
    pos : Vector2;
    direction : Direction;
    world_pos : Vector2;

    update :: (using xform: *Transform, delta_time : float) {
        Component.require_component(Velocity);
        vel := Entity.get_component(entity, Velocity);
        final_vel := Game.move_and_slide(pos, vel.vel, context.game.current_map);
        xform.pos += final_vel;

        if length(final_vel) > 0 {
            anim := Entity.get_component(entity, Animation);

            if final_vel.x > 0 then xform.direction = Direction.EAST;
            if final_vel.x < 0 then xform.direction = Direction.WEST;
            if final_vel.y > 0 then xform.direction = Direction.NORTH;
            if final_vel.y < 0 then xform.direction = Direction.SOUTH;

            // World movement
            world_movement : Vector2;
            new_pos := xform.pos;
            if xform.pos.x < 0 {
                world_movement -= Vector2.{1, 0};
                new_pos.x = MAP_WIDTH - 1;
            }
            if xform.pos.x > MAP_WIDTH - 1 {
                world_movement += Vector2.{1, 0};
                new_pos.x = 0;
            }
            if xform.pos.y < 0.1 {
                world_movement -= Vector2.{0, 1};
                new_pos.y = MAP_HEIGHT - 1.1;
            }
            if xform.pos.y > MAP_HEIGHT - 1 {
                world_movement += Vector2.{0, 1};
                new_pos.y = 0.1;
            }
            if Math.length(world_movement) > 0 {
                if Map.exists(xform.world_pos + world_movement) {
                    xform.world_pos += world_movement;
                    if Entity.has_component(entity, Player) {
                        Game.request_map_change(context.game.current_map, xform.world_pos);
                    }
                    xform.pos = new_pos;
                }
            }
        }
    }
} @Component @Update

Animation :: struct {
    using component : Component;
    time : float;
    state : enum {
        IDLE;
        WALKING;
        ATTACKING;
    };

    update :: (using animation : *Animation, delta_time : float) {
        vel := Entity.get_component(entity, Velocity);
        if vel {
            if Math.length(vel.vel) > 0 {
                state = .WALKING;
            } else {
                state = .IDLE;
            }
        }

        player := Entity.get_component(entity, Player);
        if player {
            if player.state == .ATTACKING {
                state = .ATTACKING;
            }
        }

        if state == {
            case .WALKING; {
                time += delta_time;
                if time > 1.0 then time = 0;
            }
        }
    }
} @Component @Update

Velocity :: struct {
    using component : Component;
    vel : Vector2;
} @Component

Player :: struct {
    using component : Component;
    SPEED :: 5.0;

    state : enum {
        IDLE;
        ATTACKING;
    };
    attack_time : float;

    update :: (using player : *Player, delta_time : float) {
        Component.require_component(Velocity);
        velocity := Entity.get_component(entity, Velocity);
        if state != .ATTACKING {
            // Movement
            player_vel : Vector2;
            if Input.get_keyboard(SDL_SCANCODE_W) then player_vel.y += 1;         
            if Input.get_keyboard(SDL_SCANCODE_A) then player_vel.x -= 1;
            if Input.get_keyboard(SDL_SCANCODE_S) then player_vel.y -= 1; 
            if Input.get_keyboard(SDL_SCANCODE_D) then player_vel.x += 1; 
            norm_vel := Math.unit_vector(player_vel) * (delta_time * SPEED);
            velocity.vel = norm_vel;

            // Attack
            if Input.pressed_this_frame(SDL_SCANCODE_SPACE) {
                state = .ATTACKING;
                attack_time = 0.2;
            }
        } else {
            velocity.vel = .{0, 0};
            attack_time -= delta_time;
            if attack_time <= 0 then state = .IDLE;
        }
    }
} @Component @Update

Hitbox :: struct {
    using component : Component;

    p0 : Vector2;
    p1 : Vector2;
} @Component 

AutoKill :: struct {
    using component : Component;
    time : float;
    update :: (using c : *AutoKill, delta_time : float) {
        time -= delta_time;
        if time <= 0 then Entity.delete(entity);
    }
} @Component @Update

NPC_Move :: struct {
    using component : Component;

    current_dest : Vector2;
    SPEED :: 2.5;
    wait_time : float32 = 0;
    state : enum {
        IDLE;
        WALKING;
    } = .IDLE;

    update :: (using c : *NPC_Move, delta_time : float) {
        Component.require_component(Transform);
        Component.require_component(Velocity);
        xform := Entity.get_component(entity, Transform);
        vel := Entity.get_component(entity, Velocity);
        if state == {
            case .IDLE; {
                vel.vel = .{0, 0};
                if wait_time > 0 then wait_time -= delta_time;
                else {
                    current_dest = xform.pos;
                    state = .WALKING;
                    if Random.random_get_zero_to_one() < .5 {
                        current_dest.x += ifx Random.random_get_zero_to_one() < .5 then -1 else 1;
                    } else {
                        current_dest.y += ifx Random.random_get_zero_to_one() < .5 then -1 else 1;
                    }
                }
            }
            case .WALKING; {
                if Math.distance(current_dest, xform.pos) <= 0.1 {
                    state = .IDLE;
                    wait_time = Random.random_get_within_range(1, 5);
                } else {
                    dir := Math.unit_vector(current_dest - xform.pos);
                    vel.vel = dir * SPEED * delta_time;
                }
            }
        }
    }
} @Component @Update

