
Entity :: struct {
    Tag :: enum {
        NONE;
        PLAYER;
        ENEMY;
        TELEPORTER;
        WEAPON;
        PICKUP;
        BOSS;
    };
    tag : Tag;

    Flag :: enum_flags {
        SHOULD_DELETE;
        SOLID;
        ORIENT_HITBOX;
        HIDDEN;
        NO_SHADOW;
    };
    flags : Flag;

    position : Vector2;
    direction : Direction;
    world_pos : Vector2i;

    color : Vector4 = .{1, 1, 1, 1};

    // Hitbox
    p0 := Vector2.{-0.4, -0.5}; // Relative to the current center in the transform, looking south
    p1 := Vector2.{ 0.4,  0.0};

    // @Cleanup From here on, these are not used by every entity
    sprite_sheet : *Simp.Texture = null;
    sprite : Vector2i;

    anim_time : float;
    Anim_State :: enum {
        IDLE;
        WALKING;
        WINDUP;
        ATTACKING;
        POSE;
        JUMP_END;
    };
    anim_state : Anim_State;

    // To deal damage
    hit_tag : Tag;
    health: int = 4;
    immunity: float;

    on_interact : (*Entity, *Player) = null;
    on_death    : (*Entity) = generic_death;

    IMMUNITY_TIME :: 1;

    draw :: (using e: *Entity) {
        if !sprite_sheet || (e.flags & .HIDDEN) then return;
        
        x0, y0 := Map.map_to_screen(context.game.camera_position, position - Vector2.{0.5, 0.5});
        x1, y1 := Map.map_to_screen(context.game.camera_position, position + Vector2.{0.5, 0.5});
        
        uv0, uv1 := get_uv_from_texture(sprite_sheet, sprite);
        Simp.set_shader_for_images(sprite_sheet);
        Simp.immediate_quad(
            p0 = make_vector2(xx x0, xx y0),
            p1 = make_vector2(xx x1, xx y0),
            p2 = make_vector2(xx x1, xx y1),
            p3 = make_vector2(xx x0, xx y1), color = color, 
            uv0 = uv0, uv1 = make_vector2(uv1.x, uv0.y), uv2 = uv1, uv3 = make_vector2(uv0.x, uv1.y));   

        #if DEVELOPER {
            if e.tag == .WEAPON || e.tag == .ENEMY {
                o0, o1 := Entity.orient_hitbox(e);
                x0, y0 := Map.map_to_screen(context.game.camera_position, position + o0);
                x1, y1 := Map.map_to_screen(context.game.camera_position, position + o1);
                Simp.set_shader_for_color(true);
                Simp.immediate_quad(
                    p0 = make_vector2(xx x0, xx y0),
                    p1 = make_vector2(xx x1, xx y0),
                    p2 = make_vector2(xx x1, xx y1),
                    p3 = make_vector2(xx x0, xx y1), color = .{1, .5, .5, .5});
            }
        }
    }

    draw_shadow :: (e: *Entity) {
        if !e.sprite_sheet || (e.flags & .HIDDEN) then return;
        if !(e.flags & .NO_SHADOW) {
        Simp.set_shader_for_images(*context.game.shadow_texture);
        offset :: (1.0/16.0) * 2;
        s_x0, s_y0 := Map.map_to_screen(context.game.camera_position, e.position - Vector2.{0.5, (0.5 + offset)});
        s_x1, s_y1 := Map.map_to_screen(context.game.camera_position, e.position + Vector2.{0.5, (0.5 - offset)});
        Simp.immediate_quad(cast(float)s_x0, cast(float)s_y0, cast(float)s_x1, cast(float)s_y1, make_vector4(1, 1, 1, 0.8));
    }
    }

    orient_hitbox :: (using e: Entity) -> Vector2, Vector2{
        if e.flags & .ORIENT_HITBOX == 0 {
            return e.p0, e.p1;
        }

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
                o0.x = -p0.y;
                o0.y = p0.x;
                o1.x = -p1.y;
                o1.y = p1.x;
            }
        }
        return o0, o1;
    }

    set_direction_from_velocity :: (using e: *Entity, vel: Vector2) {
        if abs(vel.x) > abs(vel.y) {
            if vel.x > 0 then {
                direction = Direction.EAST;
            } else {
                direction = Direction.WEST;
            }
        } else {
            if vel.y > 0 {
                direction = Direction.NORTH;
            } else {
                direction = Direction.SOUTH;
            }
        }
    }

    move_towards :: (using e: *Entity, dest: Vector2, speed: float, delta_time: float) {
        dir := Math.unit_vector(dest - e.position);
        vel := dir * delta_time * speed;
        final_vel := Game.move_and_slide(e, vel, context.game.current_map);

        Entity.set_direction_from_velocity(e, vel);

        if Math.length(final_vel) > 0 {
            anim_time += delta_time;
            if anim_time > 1.0 then anim_time = 0;
            anim_state = .WALKING;
        } else {
            anim_state = .IDLE;
        }
    }

    get_sprite :: (state : Anim_State, anim_time: float, direction : Direction) -> Vector2i {
        result : Vector2i = ---;
        result.x = xx direction;
        if #complete state == {
            case .IDLE;      result.y = 6;
            case .WALKING;   result.y = 6 - cast(s32)(anim_time * 4);
            case .ATTACKING; result.y = 2;
            case .WINDUP;    result.y = xx ifx (direction == .SOUTH) then 5 else 3;
            case .POSE;      { result.y = 0; result.x = 3; }
            case .JUMP_END;  { result.y = 0; result.x = 2; }

        };
        return result;
    }

    deal_damage :: (ett: *Entity, amount : int) {
        if ett.immunity <= 0 {
            ett.health -= amount;
            ett.immunity = IMMUNITY_TIME;
        }
        if ett.health <= 0 { 
            if ett.on_death then ett.on_death(ett);
        }
    }

    generic_death :: (ett: *Entity) {
        ett.flags |= .SHOULD_DELETE;
    }

    interact :: (ett: *Entity, player: *Player) {
        if ett.on_interact {
            ett.on_interact(ett, player);
        }         
    }

    update_immunity :: (using ett: *Entity, delta_time: float) {
        if immunity > 0 {
            immunity -= delta_time;
            if cast(s32)(immunity * 16.0) % 2 == 0 {
                color = .{1, 1, 1, 1};
            } else {
                color = .{10, 10, 10, 1};
            }
        }
    }

    intersects_entity :: (e1: *Entity, e2: *Entity) -> bool {
        e1_0, e1_1 := Entity.orient_hitbox(e1);
        e2_0, e2_1 := Entity.orient_hitbox(e2);
        return Game.rect_intersects(e1_0 + e1.position, e1_1 + e1.position, e2_0 + e2.position, e2_1 + e2.position);
    }
}

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
                Game.create_weapon(e, .ENEMY, attack_time);
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
        // Game.switch_state(.DEATH);
    }
}

Patrol_Behavior :: struct {
    points: []Vector2;
    next_point : int;
    wait_time : float;
    wait_timer : float;

    do_the_patrol :: (e : *Entity, using patrol: *Patrol_Behavior, delta_time: float) {
        if wait_timer > 0 then wait_timer -= delta_time;
        if wait_timer <= 0 {
            distance_to_next_point := Math.distance(e.position, points[next_point]);
            if distance_to_next_point <= 0.2 {
                next_point += 1;
                wait_timer += wait_time;
                if next_point >= points.count then next_point = 0;
            }
            Entity.move_towards(e, points[next_point], 3, delta_time);
        }
    }
}

Enemy :: struct { 
    using #as e: Entity;
    tag = .ENEMY;
    hit_tag = .ENEMY;
    damage := 1;

    Type :: enum {
        STATIC;
        HUMANOID;
        FOLLOW;
    }
    type: Type;
    patrol: Patrol_Behavior;

    is_aggroed: bool;
    combat_phase: enum {
        NOT_AGGROED;
        APPROACHING;
        WINDUP;
        ATTACK;
    }
    state: Anim_State;
    combat_timer: float;

    WINDUP_TIME :: 0.5;
    ATTACK_TIME :: 0.2;

    aggro_dist := 5;
    deaggro_dist := 5;

    simulate :: (using enemy: *Enemy, delta_time: float) {
        update_immunity(xx enemy, delta_time);

        if enemy.type != .STATIC {
            player := Game.get_player();
            distance := Math.distance(player.position, position);

            if distance > xx deaggro_dist || player.world_pos != world_pos {
                combat_phase = .NOT_AGGROED;
                // npc_move.state = .IDLE;
            }

            if #complete combat_phase == {
                case .NOT_AGGROED; {
                    if patrol.points.count > 0 {
                        Patrol_Behavior.do_the_patrol(*e, *patrol, delta_time);
                    }
                    // NPC_Move.update(*npc_move, delta_time);
                    if distance < xx aggro_dist then {
                        combat_phase = .APPROACHING;
                    }
                }
                case .APPROACHING; {
                    if distance < 1 {
                        if type == .HUMANOID {
                            combat_phase = .WINDUP;
                            state = .WINDUP;
                            combat_timer = WINDUP_TIME;
                        } else {
                            Entity.deal_damage(xx player, damage);
                        }
                    } else {
                        Entity.move_towards(*e, player.position, 3, delta_time);
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
}

Teleporter :: struct {
    using e: Entity;
    tag = .TELEPORTER;

    new_world_pos : Vector2i;
    new_pos : Vector2;

    simulate :: (using teleporter: *Teleporter, delta_time: float) {
        player := Game.get_player();
        if Vector2i.from(player.position) == Vector2i.from(position) {
            if player.world_pos != new_world_pos {
                old_world_pos := player.world_pos;
                player.world_pos = new_world_pos; // @Cleanup : we need to do this or the player gets deleted
                if Game.request_map_change(context.game.current_map, new_world_pos) {
                } else {
                    // The map doesn't exist, to prevent checking every frame, delete ourselves.
                    player.world_pos = old_world_pos; 
                    Basic.log_error("Map % doesn't exist!", new_world_pos);
                    flags |= .SHOULD_DELETE;
                }
            } 
            player.position = new_pos;
        }
    }
}

Damage_Area :: struct {
    using e: Entity;
    tag = .WEAPON;
    flags = Entity.Flag.ORIENT_HITBOX | .NO_SHADOW;

    look_for: Entity.Tag = .NONE; // What kind of hitboxes to search. Used to give
    time_left: float;

    simulate :: (using weapon: *Damage_Area, delta_time: float) { 
        time_left -= delta_time;
        if time_left <= 0 then e.flags |= .SHOULD_DELETE;
    
        for context.game.entities { 
            if it.hit_tag == .NONE then continue;
            if it.hit_tag != look_for then continue;
            
            if Entity.intersects_entity(*e, it){
                Entity.deal_damage(it, 1);
            }
        }
    }
}

Pickup :: struct {
    using e: Entity;
    tag = .PICKUP;

    Pickup_Type :: enum {
        KEY;
    };

    pickup_type : Pickup_Type;

    simulate :: (using pickup: *Pickup, delta_time: float) {
        player := Game.get_player();
        collides := Game.rect_intersects(p0 + position, p1 + position, player.p0 + player.position, player.p1 + player.position);
        if collides {
            flags |= .SHOULD_DELETE;
            player.keys += 1;
        }
    }
}

Door :: struct {
    using e: Entity;
    on_interact = try_open;
    e.flags = Entity.Flag.SOLID;
    
    tiles : [6]*Entity;

    try_open :: (e: *Entity, player: *Player) {
        if player.keys > 0 {
            self := cast(*Door)e;
            for t : self.tiles {
                t.sprite.y += 3;
            }

            e.flags |= .SHOULD_DELETE;
            player.keys -= 1;
            context.game.main_quest_state = .DOOR_OPEN;
        } else {
            Dialog.open(no_key_dialog);
        }
    }
}

NPC :: struct {
    using #as e : Entity;
    
}

Dialog_NPC :: struct {
    using #as e : Entity;
    e.on_interact = show_dialog;
    e.flags = Entity.Flag.SOLID;

    dialog : []Dialog.Node;

    show_dialog :: (e: *Entity, player: *Player) {
        npc := cast(*Dialog_NPC)e;
        Dialog.open(npc.dialog);
    }
}

Boss :: struct {
    using #as e: Entity;
    tag = .BOSS;
    hit_tag = .ENEMY;
    damage := 1;

    cooldown_time : float = 2.0;

    Boss_State :: enum {
        DASH_TOWARDS :: 0;
        WHIRLWIND :: 1;
        DASH_CORNERS :: 2;
        COOLDOWN :: 5;
    };
    state : Boss_State = .COOLDOWN; 
    previous_attack : Boss_State = .COOLDOWN; // To avoid repeating the same attack twice

    attack_time: float;

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

    simulate :: (using boss: *Boss, delta_time: float) {
        Entity.update_immunity(boss, delta_time);

        if state == {
            case .COOLDOWN; {
                cooldown_time -= delta_time;
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
        }

        e.direction = cast(Direction)(attack_time * 10) % 4;
        Game.move_and_slide(*e, player_dir * delta_time * 3.0, context.game.current_map);
        anim_state = .ATTACKING;
        if Math.distance(player.position, e.position) <= 1.5 {
            Entity.deal_damage(xx player, 1);
        }
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
}