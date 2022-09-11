
Boss :: struct {
    using #as e: Entity;
    tag = .BOSS;
    hit_tag = .ENEMY;
    damage := 1;
    on_death = death;
    health = 5;

    cooldown_time : float = 2.0;

    Boss_State :: enum {
        DASH_TOWARDS :: 0;
        WHIRLWIND :: 1;
        DASH_CORNERS :: 2;
        COOLDOWN :: 5;
        PEACEFUL;
    };
    state : Boss_State = .COOLDOWN; 
    previous_attack : Boss_State = .COOLDOWN; // To avoid repeating the same attack twice

    attack_time: float;
    weapon : *Entity;

    door : [3]*Entity;

    dash_start_pos : Vector2; // For the lerp
    dash_target : Vector2; 
    dash_state : enum {
        WAIT;
        WALK;
        DASH;
    } = .WAIT;
    current_dash := 0;
    starting_corner := 0;

    CORNERS :: Vector2.[.{14, 12}, .{24, 12}, .{24, 9}, .{14, 9}];
    DASH_TIME :: .2;
    TIME_BETWEEN_DASHES :: 0.1;

    reset_boss :: (self: *Boss) {
        self.state = .PEACEFUL;
        self.hit_tag = .NONE;
        self.immunity = 0;
        self.direction = .SOUTH;
        self.anim_state = .IDLE;
        self.sprite = Entity.get_sprite(.IDLE, 0, .SOUTH);
        self.on_interact = (e : *Entity, player: *Player) {
            Dialog.open(boss_dialog_repeat);
        };
    }

    simulate :: (using boss: *Boss, delta_time: float) {
        Entity.update_immunity(boss, delta_time);

        if state == {
            case .COOLDOWN; {
                cooldown_time -= delta_time;

                if immunity > 0 { // If the player hit the enemy shorten the cd time to prevent attack spam
                    cooldown_time = Basic.min(0.5, cooldown_time);
                }

                if cooldown_time > .5 {
                    boss.anim_state = .JUMP_END;
                } else {
                    boss.anim_state = .IDLE;
                }
                if cooldown_time <= 0 {
                    state = cast(Boss_State)(Random.random_get() % 3);
                    while(state == previous_attack) {
                        state = cast(Boss_State)(Random.random_get() % 3);
                        Basic.log("%", state);
                    }
                    previous_attack = state; 
                    dash_state = .WAIT;
                    attack_time = 0;
                    if state == .WHIRLWIND {
                        weapon = create_weapon(boss, .PLAYER, 4);
                    }
                    Basic.log("Boss is currently doing: %", state);
                }   
            }
            case .WHIRLWIND; {
                whirlwind(boss, delta_time);
            }
            case .DASH_TOWARDS; {
                dash_towards(boss, delta_time);
            }
            case .DASH_CORNERS; {
                dash_corners(boss, delta_time);
            }
        }

        sprite = Entity.get_sprite(anim_state, anim_time, direction);
    }

    switch_to_cooldown :: (boss: *Boss) {
        boss.cooldown_time = 2.0;
        boss.state = .COOLDOWN;
    }

    whirlwind :: (using boss: *Boss, delta_time: float) {
        player := Game.get_player();
        player_dir := Math.unit_vector(player.position - boss.position);

        attack_time += delta_time;
        if attack_time >= 4 {
            switch_to_cooldown(boss);
            weapon = null;
            return;
        }

        e.direction = cast(Direction)(attack_time * 10) % 4;
        weapon.position = position + forward(direction);
        weapon.direction = direction;
        weapon.sprite.x = xx weapon.direction;

        Game.move_and_slide(*e, player_dir * delta_time * 3.0, context.game.current_map);
        anim_state = .ATTACKING;
    }

    dash_towards :: (using boss: *Boss, delta_time: float) {
        player := Game.get_player();
        player_dir := Math.unit_vector(player.position - boss.position);
        
        attack_time += delta_time;
        if dash_state == {
            case .WAIT; {
                if attack_time < 1.4 {
                    dash_target = player.position; // Record player position's a bit early to give them time to dodge
                }
                if attack_time >= 1.5 {
                    dash_start_pos = e.position;
                    dash_state = .DASH;
                    attack_time = 0.0;
                    e.color = .{1, 1, 1, .5};
                }
                anim_state = .POSE;
            }
            case .DASH; {
                e.position = Math.lerp(dash_start_pos, dash_target, Basic.min(1.0, attack_time / DASH_TIME));
                if Math.distance(player.position, e.position) <= 1 {
                    Entity.deal_damage(xx player, 1);
                }
                if attack_time >= DASH_TIME {
                    // e.position = dash_target;
                    e.color = .{1, 1, 1, 1};
                    switch_to_cooldown(boss);
                }
            }
        }
    }

    get_dash_corner :: (corners : []Vector2, current_dash: int, starting_corner: int) -> Vector2 {
        id := (starting_corner + current_dash) % corners.count;
        return corners[id];
    }

    dash_corners :: (using boss: *Boss, delta_time: float) {
        player := Game.get_player();
        player_dir := Math.unit_vector(player.position - boss.position);

        if dash_state == {
            case .WAIT; { // Move to the closest corner
                // Find the closest corner
                distance := 100.0;
                starting_corner = 0;
                for CORNERS {
                    this_dist := Math.distance(boss.position, it);
                    if this_dist < distance {
                        distance = this_dist;
                        starting_corner = it_index;                        
                    }
                }
                Basic.log("Starting in %", starting_corner);
                dash_state = .WALK;
            }
            case .WALK; {
                Entity.move_towards(boss, CORNERS[starting_corner], 4.0, delta_time);
                if Math.distance(boss.position, CORNERS[starting_corner]) <= 0.1 {
                    current_dash = 0;
                    dash_state = .DASH;
                    anim_state = .POSE;
                    dash_target = get_dash_corner(CORNERS, current_dash + 1, starting_corner);
                    attack_time = -TIME_BETWEEN_DASHES;
                    dash_start_pos = boss.position;
                }
            }
            case .DASH; {
                attack_time += delta_time;
                if attack_time >= 0 { 
                    e.position = Math.lerp(dash_start_pos, dash_target, Basic.min(1.0, attack_time / DASH_TIME));
                    if Math.distance(player.position, e.position) <= 1 {
                        Entity.deal_damage(xx player, 1);
                    }
                    if attack_time >= DASH_TIME {
                        // Next dash
                        current_dash += 1;
                        if current_dash > CORNERS.count {
                            switch_to_cooldown(boss);
                        } else {
                            dash_target = get_dash_corner(CORNERS, current_dash, starting_corner);;
                            attack_time = -TIME_BETWEEN_DASHES;
                            dash_start_pos = boss.position;
                        }
                    }
                } 
            }
        }
    }

    death :: (e: *Entity) {
        e.flags |= .SOLID;
        Dialog.open(boss_dialog_after_fight);
        context.game.main_quest_state = .BOSS_KILLED;
        boss : *Boss = xx e;
        for boss.door {
            it.flags |= .SHOULD_DELETE;
        }
        reset_boss(xx e);
    }
}