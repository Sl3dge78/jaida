Player :: struct {
    using e: Entity;
    SPEED :: 5.0;
    tag = .PLAYER;
    hit_tag = .PLAYER;

    attack_time : float;

    keys : int;
    can_attack : bool;

    on_death = player_death;

    simulate :: (using player : *Player, delta_time : float) { 
        update_immunity(xx player, delta_time);

        if anim_state != .ATTACKING {
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
                anim_state = .WALKING;
                Game.move_and_slide(*e, norm_vel, context.game.current_map);
            } else {
                anim_state = .IDLE;
            }

            // Attack
            if can_attack && Input.input_button_states[Input.Key_Code.SPACEBAR] & .START {
                anim_state = .ATTACKING;
                sprite.y = 2;
                attack_time = 0.2;
                create_weapon(e, .ENEMY, attack_time);
            }

            sprite = Entity.get_sprite(anim_state, anim_time, direction);

            if Input.input_button_states[#char "E"] & .START {
                interacted_tile : Vector2i = Vector2i.from(position + forward(direction));
                Basic.log("Interacting with: %", interacted_tile);
                for context.game.entities {
                    if Vector2i.from(it.position) == interacted_tile {
                        Entity.interact(it, player);
                    }
                }
            }
        } else {
            attack_time -= delta_time;
            if attack_time <= 0 then anim_state = .IDLE;
        }
    }

    player_death :: (e : *Entity) {
        Game.switch_state(.DEATH);
    }
}

create_player :: (pos : Vector2, world_pos : Vector2i) -> *Player {
    player := Game.new_entity(Player);
    player.sprite_sheet = *context.game.blue_samurai_texture;
    player.position = pos;
    player.world_pos = world_pos;
    player.flags |= .SOLID;
    return player;
}