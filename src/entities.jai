

Entity :: struct {
    Tag :: enum {
        NONE;
        PLAYER;
        ENEMY;
        TELEPORTER;
        WEAPON;
    };
    tag : Tag;

    Flag :: enum_flags {
        SHOULD_DELETE;
    };
    flags : Flag;

    position : Vector2;
    direction : Direction;
    world_pos : Vector2i;

    // Hitbox
    p0 := Vector2.{-0.5, -0.5}; // Relative to the current center in the transform, looking south
    p1 := Vector2.{ 0.5,  0.5};

    // @Cleanup Not used by every entity
    sprite_sheet : *Simp.Texture = null;
    sprite : Vector2i;

    draw :: (using e: *Entity) {
        if !sprite_sheet then return;
        x0, y0 := Map.map_to_screen(context.game.camera_position, position - Vector2.{0.5, 0.5});
        x1, y1 := Map.map_to_screen(context.game.camera_position, position + Vector2.{0.5, 0.5});
        uv0, uv1 := get_uv_from_texture(sprite_sheet, sprite);
        Simp.set_shader_for_images(sprite_sheet);
        Simp.immediate_quad(
            p0 = make_vector2(xx x0, xx y0),
            p1 = make_vector2(xx x1, xx y0),
            p2 = make_vector2(xx x1, xx y1),
            p3 = make_vector2(xx x0, xx y1),
            uv0 = uv0, uv1 = make_vector2(uv1.x, uv0.y), uv2 = uv1, uv3 = make_vector2(uv0.x, uv1.y));

    }

    orient_hitbox :: (using e: Entity) -> Vector2, Vector2{
        o0: Vector2; // Hitbox in grid space relative to current center but oriented
        o1: Vector2; 
        if direction == {
            case .SOUTH; o0 = p0; o1 = p1;
            case .NORTH; {
                o0.x = -p1.x;
                o0.y = -p1.y;
                o1.x = -p0.x;
                o1.y = -p0.y;
            }
            case .WEST; {
                o0.x = p0.y;
                o0.y = p0.x;
                o1.x = p1.y;
                o1.y = p1.x;
            }
            case .EAST; {
                o0.x = p0.y;
                o0.y = p0.x;
                o1.x = p1.y;
                o1.y = p1.x;
            }
        }
        return o0, o1;
        
    }

    Anim_State :: enum {
        IDLE;
        WALKING;
        WINDUP;
        ATTACKING;
    };

    get_sprite :: (state : Anim_State, anim_time: float, direction : Direction) -> Vector2i {
        result : Vector2i = ---;
        result.x = xx direction;
        if #complete state == {
            case .IDLE;      result.y = 6;
            case .WALKING;   result.y = 6 - cast(s32)(anim_time * 4);
            case .ATTACKING; result.y = 2;
            case .WINDUP;    result.y = xx ifx (direction == .SOUTH) then 5 else 3;

        };
        return result;
    }
}

Player :: struct {
    using e: Entity;
    SPEED :: 5.0;
    tag = .PLAYER;

    state : Entity.Anim_State;
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
            }
            if Input.input_button_states[#char "A"] & .DOWN {
                vel.x -= 1;
                direction = .WEST;
            }
            if Input.input_button_states[#char "S"] & .DOWN {
                vel.y -= 1; 
                direction = .SOUTH;
            }
            if Input.input_button_states[#char "D"] & .DOWN {
                vel.x += 1; 
                direction = .EAST;
            }
            norm_vel := Math.unit_vector(vel) * (delta_time * SPEED);
            if Math.length(norm_vel) > 0 { 
                anim_time += delta_time;
                if anim_time > 1.0 then anim_time = 0;
                state = .WALKING;
                Game.move_and_slide(*e, norm_vel, context.game.current_map);
            } else {
                state = .IDLE;
            }

            // Attack
            if Input.input_button_states[Input.Key_Code.SPACEBAR] & .START {
                state = .ATTACKING;
                sprite.y = 2;
                attack_time = 0.2;
                Game.create_weapon(e, .ENEMY, attack_time);
            }

            sprite = Entity.get_sprite(state, anim_time, direction);

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
    state : Anim_State;
    combat_timer : float;
    anim_time : float;

    WINDUP_TIME :: 0.5;
    ATTACK_TIME :: 0.2;

    AGGRO_DIST :: 10;
    DEAGGRO_DIST :: 10;

    simulate :: (using enemy: *Enemy, delta_time: float) {
        player := context.game.player;
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
                    state = .WINDUP;
                    combat_timer = WINDUP_TIME;
                } else {
                    dir := Math.unit_vector(player.position - position);
                    vel := dir * delta_time * 3.0;
                    final_vel := Game.move_and_slide(*e, vel, context.game.current_map);

                    if abs(final_vel.x) > abs(final_vel.y) {
                        if final_vel.x > 0 then {
                            direction = Direction.EAST;
                        } else {
                            direction = Direction.WEST;
                        }
                    } else {
                        if final_vel.y > 0 {
                            direction = Direction.NORTH;
                        } else {
                            direction = Direction.SOUTH;
                        }
                    }

                    if Math.length(final_vel) > 0 {
                        anim_time += delta_time;
                        if anim_time > 1.0 then anim_time = 0;
                        state = .WALKING;
                    } else {
                        state = .IDLE;
                    }
                }
            }
            case .WINDUP; {
                combat_timer -= delta_time;
                if combat_timer < 0 {
                    combat_phase = .ATTACK;
                    state = .ATTACKING;
                    combat_timer = ATTACK_TIME;
                    Game.create_weapon(e, .PLAYER, ATTACK_TIME);
                }
            }
            case .ATTACK; {
                combat_timer -= delta_time;
                if combat_timer <= 0 then combat_phase = .APPROACHING;
            }
        }

        sprite = Entity.get_sprite(state, anim_time, direction);
    }
}

Teleporter :: struct {
    using e: Entity;
    tag = .TELEPORTER;

    new_world_pos : Vector2i;
    new_pos : Vector2;

    simulate :: (using teleporter: *Teleporter, delta_time: float) {
        player := *context.game.player;
        if Vector2i.from_vector2(player.position) == Vector2i.from_vector2(position) {
            Basic.log("Before: Player: %, New: %", player.world_pos, new_world_pos);
            if player.world_pos != new_world_pos {
                Basic.log("Before: Player: %, New: %", player.world_pos, new_world_pos);
                if Game.request_map_change(context.game.current_map, new_world_pos) {
                    player.world_pos = new_world_pos;
                    Basic.log("After: Player: %, New: %", player.world_pos, new_world_pos);
                } else {
                    // The map doesn't exist, to prevent checking every frame, delete ourselves.
                    Basic.log_error("Map % doesn't exist!", new_world_pos);
                    // @Todo
                    // entity.flags |= .SHOULD_DELETE;
                }
            } 
            player.position = new_pos;
        }
    }
}

Weapon :: struct {
    using e: Entity;
    tag = .WEAPON;

    look_for: Entity.Tag = .NONE; // What kind of hitboxes to search. Used to give
    time_left : float;

    simulate :: (using weapon: *Weapon, delta_time: float) { 
        time_left -= delta_time;
        if time_left <= 0 then e.flags |= .SHOULD_DELETE;
        o0, o1 := Entity.orient_hitbox(e);
        for context.game.entities { 
            if it.tag != look_for then continue;
            it_o0, it_o1 := Entity.orient_hitbox(it);
            collides := Game.rect_intersects(o0 + position, o1 + position, it_o0 + it.position, it_o1 + it.position);
            if collides {
                Basic.log("Collision!");
            }
        }
    }
}
