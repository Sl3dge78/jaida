

Entity :: struct {
    Tag :: enum {
        NONE;
        PLAYER;
        ENEMY;
        TELEPORTER;
    };
    tag : Tag;

    position : Vector2;
    direction : Direction;
    world_pos : Vector2i;

    // @Cleanup Not used by every entity
    sprite_sheet : *Simp.Texture = null;
    sprite : Vector2i;

    draw :: (using e: *Entity) {
        if !sprite_sheet then return;
        x0, y0 := Map.map_to_screen(global_game.camera_position, position - Vector2.{0.5, 0.5});
        x1, y1 := Map.map_to_screen(global_game.camera_position, position + Vector2.{0.5, 0.5});
        uv0, uv1 := get_uv_from_texture(sprite_sheet, sprite);
        Simp.set_shader_for_images(sprite_sheet);
        Simp.immediate_quad(
            p0 = make_vector2(xx x0, xx y0),
            p1 = make_vector2(xx x1, xx y0),
            p2 = make_vector2(xx x1, xx y1),
            p3 = make_vector2(xx x0, xx y1),
            uv0 = uv0, uv1 = make_vector2(uv1.x, uv0.y), uv2 = uv1, uv3 = make_vector2(uv0.x, uv1.y));

    }
}

Player :: struct {
    using e: Entity;
    SPEED :: 5.0;
    tag = .PLAYER;

    state : enum {
        IDLE;
        ATTACKING;
    }
    attack_time : float;
    anim_time   : float;

    health : int;

    simulate :: (using player : *Player, delta_time : float) { 
        if state != .ATTACKING {
            // Movement
            vel : Vector2;
            if Input.input_button_states[#char "W"] & .DOWN {
                vel.y += 1;
                direction = .NORTH;
                sprite.x = xx direction;
            }
            if Input.input_button_states[#char "A"] & .DOWN {
                vel.x -= 1;
                direction = .WEST;
                sprite.x = xx direction;
            }
            if Input.input_button_states[#char "S"] & .DOWN {
                vel.y -= 1; 
                direction = .SOUTH;
                sprite.x = xx direction;
            }
            if Input.input_button_states[#char "D"] & .DOWN {
                vel.x += 1; 
                direction = .EAST;
                sprite.x = xx direction;
            }
            norm_vel := Math.unit_vector(vel) * (delta_time * SPEED);
            if Math.length(norm_vel) > 0 { 
                anim_time += delta_time;
                if anim_time > 1.0 then anim_time = 0;
                sprite.y = 6 - cast(s32)(anim_time * 4.0); 
                Game.move_and_slide(*e, norm_vel, global_game.current_map);
            } else {
                sprite.y = 6;
            }

            // Attack
            if Input.input_button_states[Input.Key_Code.SPACEBAR] & .START {
                state = .ATTACKING;
                sprite.y = 2;
                attack_time = 0.2;
                // Game.create_weapon(entity, .ENEMY, attack_time);
            }

            if Input.input_button_states[#char "E"] & .START {
                // Game.create_interactor(entity);
            }
        } else {
            attack_time -= delta_time;
            if attack_time <= 0 then state = .IDLE;
        }
    }
}

Enemy :: struct { 
    using e : Entity;
    tag = .ENEMY;

    is_aggroed : bool;
    combat_phase : enum {
        NOT_AGGROED;
        APPROACHING;
        WINDUP;
        ATTACK;
    }
    combat_timer : float;

    WINDUP_TIME :: 0.5;
    ATTACK_TIME :: 0.2;

    AGGRO_DIST :: 10;
    DEAGGRO_DIST :: 10;

    simulate :: (using enemy: *Enemy, delta_time: float) {
        player := global_game.player;
        distance := Math.distance(player.position, position);

        if distance > DEAGGRO_DIST || player.world_pos != world_pos {
            combat_phase = .NOT_AGGROED;
            //npc_move.state = .IDLE;
        }

        if #complete combat_phase == {
            case .NOT_AGGROED; {
                // NPC_Move.update(*npc_move, delta_time);
                if distance < AGGRO_DIST then {
                    combat_phase = .APPROACHING;
                }
            }
            case .APPROACHING; {
                if distance < 1 {
                    combat_phase = .WINDUP;
                    combat_timer = WINDUP_TIME;
                    return;
                }
                dir := Math.unit_vector(player.position - position);
                vel := dir * delta_time * 3.0;
                Game.move_and_slide(*e, vel, global_game.current_map);
            }
            case .WINDUP; {
                combat_timer -= delta_time;
                if combat_timer < 0 {
                    combat_phase = .ATTACK;
                    combat_timer = ATTACK_TIME;
                    // Game.create_weapon(entity, .PLAYER, ATTACK_TIME);
                }
            }
            case .ATTACK; {
                combat_timer -= delta_time;
                if combat_timer <= 0 then combat_phase = .APPROACHING;
            }
        }
    }
}

Teleporter :: struct {
    using e: Entity;
    tag = .TELEPORTER;

    new_world_pos : Vector2i;
    new_pos : Vector2;

    simulate :: (using teleporter: *Teleporter, delta_time: float) {
        player := global_game.player;
        
        if Vector2i.from_vector2(player.position) == Vector2i.from_vector2(position) {
            Basic.log("%", new_world_pos);
            if player.world_pos != new_world_pos {
                if Game.request_map_change(global_game.current_map, new_world_pos) {
                    player.position = new_pos;
                } else {
                    // The map doesn't exist, to prevent checking every frame, delete ourselves.
                    Basic.log_error("Map % doesn't exist!", new_world_pos);
                    // @Todo
                    // entity.flags |= .SHOULD_DELETE;
                }
            } else {
                player.position = new_pos;
            }
        }
    }
}
