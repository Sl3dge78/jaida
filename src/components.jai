Component :: struct {
    entity : *Entity; 
    loc : Bucket_Locator;

    require_component :: ($component : Type) #expand {
        Basic.assert(Entity.has_component(`entity, component));
    }

    // @Speed, do a memcpy?
    copy :: (from : * $T/Component, to : *T) {
        o := to.component;
        << to = << from;
        to.component = o;
    }
}

Sprite :: struct {
    using component : Component;

    Flags :: enum_flags {
        USE_DIRECTION_AS_X;
    };

    flags : Flags;
    sprite_sheet : Simp.Texture = ---; 
    x0, y0, x1, y1 : int;
    sprite_x : u32;
    sprite_y : u32;

    draw :: (using sprite: *Sprite) {
        xform := Entity.get_component(entity, Transform);
        animation := Entity.get_component(entity, Animation);
        if animation {
            if animation.state == { 
                case .IDLE;      sprite_y = 6; 
                case .WALKING;   sprite_y = 6 - cast(u32)(animation.time * 4.0); 
                case .ATTACKING; sprite_y = 2;
                case .WINDUP;    sprite_y = xx ifx (xform.direction == .SOUTH) then 5 else 3;
            }    
        }
        if xform {
            x0, y0 = Map.map_to_screen(global_game.camera_position, xform.pos - Vector2.{0.5, 0.5});
            x1, y1 = Map.map_to_screen(global_game.camera_position, xform.pos + Vector2.{0.5, 0.5});
            if sprite.flags & .USE_DIRECTION_AS_X {
                sprite_x = xx xform.direction;
            }
        }
        uv0, uv1 := get_uv_from_texture(*sprite_sheet, sprite_x, sprite_y);
        Simp.set_shader_for_images(*sprite_sheet);
        Simp.immediate_quad(
            p0 = make_vector2(xx x0, xx y0),
            p1 = make_vector2(xx x1, xx y0),
            p2 = make_vector2(xx x1, xx y1),
            p3 = make_vector2(xx x0, xx y1),
            uv0 = uv0, uv1 = make_vector2(uv1.x, uv0.y), uv2 = uv1, uv3 = make_vector2(uv0.x, uv1.y));
    }

} @Component @Draw 

Transform :: struct {
    using component : Component;
    pos : Vector2;
    direction : Direction;
    world_pos : Vector2i;

    update :: (using xform: *Transform, delta_time : float) {
        vel := Entity.get_component(entity, Velocity);
        if vel {
            final_vel := move_and_slide(xform, vel.vel, global_game.current_map);

            if final_vel.x != 0 || final_vel.y != 0 {
                anim := Entity.get_component(entity, Animation);

                if abs(final_vel.x) > abs(final_vel.y) {
                    if final_vel.x > 0 then xform.direction = Direction.EAST;
                    else xform.direction = Direction.WEST;
                } else {
                    if final_vel.y > 0 then xform.direction = Direction.NORTH;
                    else xform.direction = Direction.SOUTH;
                }

                // World movement
                world_movement : Vector2i;
                new_pos := xform.pos;
                if xform.pos.x < 0 {
                    world_movement -= Vector2i.{1, 0};
                    new_pos.x = MAP_WIDTH - 1;
                }
                if xform.pos.x > MAP_WIDTH - 1 {
                    world_movement += Vector2i.{1, 0};
                    new_pos.x = 0;
                }
                if xform.pos.y < 0.1 {
                    world_movement -= Vector2i.{0, 1};
                    new_pos.y = MAP_HEIGHT - 1.1;
                }
                if xform.pos.y > MAP_HEIGHT - 1 {
                    world_movement += Vector2i.{0, 1};
                    new_pos.y = 0.1;
                }
                if Vector2i.length(world_movement) > 0 {
                    if Map.exists(xform.world_pos + world_movement) {
                        xform.world_pos += world_movement;
                        xform.pos = new_pos;
                        if entity.tag == .PLAYER {
                            Game.request_map_change(global_game.current_map, xform.world_pos);
                        } else {
                            Entity.change_inactive(entity, global_game.current_world_pos != xform.world_pos);
                        }
                    }
                }
            }
        }
    }

    /// Computes a new velocity that avoids map obstacles
    move_and_slide :: (xform : *Transform, velocity : Vector2, map : Map) -> Vector2{
        result : Vector2;
        new_center_x := xform.pos + xy(velocity.x, 0);
        new_center_y := xform.pos + xy(0, velocity.y);

        // @Speed : Get the sign of the velocity? to check only 1 side
        // @Hardcoded : Specify the size of the sprite?
        xp1 := new_center_x + Vector2.{ 0.4,  0.0};
        xp0 := new_center_x + Vector2.{-0.4, -0.5};
        if Map.get_collision_at(global_game.current_map, new_center_x + Vector2.{ 0.4,  0.0}, xform.entity) == 0 &&
           Map.get_collision_at(global_game.current_map, new_center_x + Vector2.{ 0.4, -0.5}, xform.entity) == 0 &&
           Map.get_collision_at(global_game.current_map, new_center_x + Vector2.{-0.4,  0.0}, xform.entity) == 0 &&
           Map.get_collision_at(global_game.current_map, new_center_x + Vector2.{-0.4, -0.5}, xform.entity) == 0 {
            do_move := true;
            for Component_Manager.get_component_storage(Collision, false) {
                if it.entity == xform.entity continue;
                it_xform := Entity.get_component(it.entity, Transform);
                is_in_rect := Game.rect_intersects(xp0, xp1, it_xform.pos + it.p0, it_xform.pos + it.p1);
                if is_in_rect {
                    do_move = false;
                    break;
                }
            }
            if do_move then result.x += velocity.x;
        }

        yp1 := new_center_y + Vector2.{ 0.4,  0.0};
        yp0 := new_center_y + Vector2.{-0.4, -0.5};
        if Map.get_collision_at(global_game.current_map, new_center_y + Vector2.{ 0.4,  0.0}, xform.entity) == 0 &&
           Map.get_collision_at(global_game.current_map, new_center_y + Vector2.{-0.4,  0.0}, xform.entity) == 0 &&
           Map.get_collision_at(global_game.current_map, new_center_y + Vector2.{ 0.4, -0.5}, xform.entity) == 0 &&
           Map.get_collision_at(global_game.current_map, new_center_y + Vector2.{-0.4, -0.5}, xform.entity) == 0 {
            do_move := true;
            for Component_Manager.get_component_storage(Collision, false) {
                if it.entity == xform.entity continue;
                it_xform := Entity.get_component(it.entity, Transform);
                is_in_rect := Game.rect_intersects(yp0, yp1, it_xform.pos + it.p0, it_xform.pos + it.p1);
                if is_in_rect {
                    do_move = false;
                    break;
                }
            }
            if do_move then result.y += velocity.y;
        }   

        xform.pos += result;
        return result;
    }
} @Component @Update

Animation :: struct {
    using component : Component;
    time : float;
    state : enum {
        IDLE;
        WALKING;
        ATTACKING;
        WINDUP;
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

        enemy := Entity.get_component(entity, Enemy);
        if enemy {
            if enemy.combat_phase == {
                case .ATTACK; state = .ATTACKING;
                case .WINDUP; state = .WINDUP;
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

Health :: struct {
    using component : Component;
    hp : s32 = 4;
    cooldown : float;

    on_hit :: (using self: *Health, other: *Entity) {
        if cooldown > 0 then return;
        hp -= 1;
        cooldown = 1.0;
        Basic.log("hp: %", hp);

        if !hp {
            entity.flags |= .SHOULD_DELETE;
        }
    }

    update :: (using h : *Health, delta_time : float) {
        if cooldown > 0 then cooldown -= delta_time;
    }
} @Component @Update @Hit

Hitbox :: struct {
    Tag :: enum {
        NONE;
        PLAYER;
        ENEMY;
        INTERACT;
    }
    using component : Component;
    p0 := Vector2.{-0.5, -0.5}; // Relative to the current center in the transform, looking south
    p1 := Vector2.{ 0.5,  0.5};

    o0 : Vector2; // Relative to current center but oriented
    o1 : Vector2; 

    tag: Tag = .NONE;       // Will be looked at by hitboxes. Used to receive 
    look_for : Tag = .NONE; // What kind of hitboxes to search. Used to give

    update :: (using comp : *Hitbox, delta_time : float) {
        Component.require_component(Transform);
        xform := Entity.get_component(entity, Transform);

        if xform.direction == {
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

        if look_for == .NONE then return;
        others := Component_Manager.get_component_storage(Hitbox, false);
        for * others {
            if it.tag != look_for then continue;
            other_xform := Entity.get_component(it.entity, Transform);
            collides := Game.rect_intersects(o0 + xform.pos, o1 + xform.pos, it.o0 + other_xform.pos, it.o1 + other_xform.pos);
            if collides {
                #insert #run -> string {
                    builder : Basic.String_Builder;
                    for hit_comp : HIT_COMPONENT_LIST { 
                        Basic.print_to_builder(*builder, "{\n\thit_component := Entity.get_component(it.entity, %);\n", hit_comp);
                        Basic.print_to_builder(*builder, "\tif hit_component then %.on_hit(hit_component, entity);\n}\n", hit_comp);
                    }
                    return Basic.builder_to_string(*builder);
                };
            }
        }
    }

    draw :: (using comp : *Hitbox) {
        Simp.set_shader_for_color(true);
        xform := Entity.get_component(entity, Transform);
        x0, y0 := Map.map_to_screen(global_game.camera_position, xform.pos + o0);
        x1, y1 := Map.map_to_screen(global_game.camera_position, xform.pos + o1);
        color : Vector4;
        if comp.tag == {
            case .NONE; {
                if comp.look_for == {
                    case .ENEMY;    color = rgba( 1, .4, .4, .2);
                    case .PLAYER;   color = rgba(.4,  1, .4, .2);
                    case .INTERACT; color = rgba(.4, .4, .4, .2);
                }
            }
            case .ENEMY; color = rgba(1, .2, .2, 0.4);
            case .PLAYER; color = rgba(.2, 1, .2, 0.4);
            case .INTERACT; color = rgba(.2, .2, 1, 0.4);
        }
        Simp.immediate_quad(x0 = xx x0, y0 = xx y0, x1 = xx x1, y1 = xx y1, color = color);
    }

} @Component @Update @Draw

AutoKill :: struct {
    using component : Component;
    time : float;
    update :: (using c : *AutoKill, delta_time : float) {
        time -= delta_time;
        if time <= 0 then entity.flags |= .SHOULD_DELETE;
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
        if wait_time > 0 then wait_time -= delta_time;
        if state == {
            case .IDLE; {
                vel.vel = .{0, 0};
                if wait_time <= 0 {
                    current_dest = xform.pos;
                    wait_time := 5;
                    state = .WALKING;
                    if Random.random_get_zero_to_one() < .5 {
                        current_dest.x += ifx Random.random_get_zero_to_one() < .5 then -1 else 1;
                    } else {
                        current_dest.y += ifx Random.random_get_zero_to_one() < .5 then -1 else 1;
                    }
                }
            }
            case .WALKING; {
                distance := Math.distance(current_dest, xform.pos);
                if distance <= 0.1 || distance > 1 || wait_time <= 0 {
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

Player :: struct {
    using component : Component;
    SPEED :: 5.0;

    state : enum {
        IDLE;
        ATTACKING;
    };
    attack_time : float;
    nb_keys : int = 0;

    update :: (using player : *Player, delta_time : float) {
        Component.require_component(Velocity);
        velocity := Entity.get_component(entity, Velocity);
        if state != .ATTACKING {
            // Movement
            player_vel : Vector2;
            if Input.input_button_states[#char "W"] & .DOWN then player_vel.y += 1;         
            if Input.input_button_states[#char "A"] & .DOWN then player_vel.x -= 1;
            if Input.input_button_states[#char "S"] & .DOWN then player_vel.y -= 1; 
            if Input.input_button_states[#char "D"] & .DOWN then player_vel.x += 1; 
            norm_vel := Math.unit_vector(player_vel) * (delta_time * SPEED);
            velocity.vel = norm_vel;

            // Attack
            if Input.input_button_states[Input.Key_Code.SPACEBAR] & .START {
                state = .ATTACKING;
                attack_time = 0.2;
                Game.create_weapon(entity, .ENEMY, attack_time);
            }

            if Input.input_button_states[#char "E"] & .START {
                Game.create_interactor(entity);
            }
        } else {
            velocity.vel = .{0, 0};
            attack_time -= delta_time;
            if attack_time <= 0 then state = .IDLE;
        }
    }
} @Component @Update

Enemy :: struct {
    using npc_move : NPC_Move;
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

    update :: (using c: *Enemy, delta_time : float) {
        player := Entity.find_first(.PLAYER);
        if !player {
            NPC_Move.update(*npc_move, delta_time);
            return;
        }
        player_xform := Entity.get_component(player, Transform);
        my_xform := Entity.get_component(entity, Transform);
        distance := Math.distance(player_xform.pos, my_xform.pos);

        if distance > DEAGGRO_DIST || player_xform.world_pos != my_xform.world_pos {
            combat_phase = .NOT_AGGROED;
            npc_move.state = .IDLE;
        }

        if #complete combat_phase == {
            case .NOT_AGGROED; {
                NPC_Move.update(*npc_move, delta_time);
                if distance < AGGRO_DIST then {
                    combat_phase = .APPROACHING;
                }
            }
            case .APPROACHING; {
                vel := Entity.get_component(entity, Velocity);
                if distance < 1 {
                    vel.vel = .{0, 0};
                    combat_phase = .WINDUP;
                    combat_timer = WINDUP_TIME;
                    return;
                }
                dir := Math.unit_vector(player_xform.pos - my_xform.pos);
                vel.vel = dir * delta_time * 3.0;
            }
            case .WINDUP; {
                combat_timer -= delta_time;
                if combat_timer < 0 {
                    combat_phase = .ATTACK;
                    combat_timer = ATTACK_TIME;
                    Game.create_weapon(entity, .PLAYER, ATTACK_TIME);
                }
            }
            case .ATTACK; {
                combat_timer -= delta_time;
                if combat_timer <= 0 then combat_phase = .APPROACHING;
            }
        }
    }
} @Component @Update

Teleporter :: struct {
    using component : Component;

    new_world_pos : Vector2i;
    new_pos : Vector2;

    update :: (using c : *Teleporter, delta_time : float) {
        player := global_game.player;
        player_xform := Entity.get_component(player, Transform);
        my_xform := Entity.get_component(entity, Transform);
        
        if Vector2i.from_vector2(player_xform.pos) == Vector2i.from_vector2(my_xform.pos) {
            if player_xform.world_pos != new_world_pos {
                player_xform.world_pos = new_world_pos; // @Hack
                if Game.request_map_change(global_game.current_map, new_world_pos) {
                    player_xform.pos = new_pos;
                } else {
                    // The map doesn't exist, to prevent checking every frame, delete ourselves.
                    Basic.log_error("Map % doesn't exist!", new_world_pos);
                    entity.flags |= .SHOULD_DELETE;
                }
            } else {
                player_xform.pos = new_pos;
            }
        }
    }
} @Component @Update

Interact :: struct {
    using component : Component;

    on_hit :: (using self : *Interact, other: *Entity) {
        Basic.log("Hello");
        Dialog.open(tree);
    }
} @Component @Hit

Collision :: struct {
    using component : Component;
    p0 : Vector2 = .{-0.4, -0.5};
    p1 : Vector2 = .{0.4, 0.0};
} @Component

Key :: struct { 
    using component: Component;

    on_hit :: (using self: *Key, other: *Entity) {
        Basic.log("Hit!");
        player := Entity.get_component(other, Player);
        if !player then return;
        player.nb_keys += 1;
        self.entity.flags |= .SHOULD_DELETE;
    }

} @Component @Hit

#scope_file
tree := Dialog.Node.[
    Dialog.Node.{lines = .["Hello, I'm a chest!","And this is a second line!", "How many lines can you fit here?"], jumps = .[1]},
    Dialog.Node.{has_title = true, lines = .["Chest", "Hey I have a title now!"], jumps = .[2] },
    Dialog.Node.{has_title = true, lines = .["Chest", "Go back to the start?", "Yes", "No"], jumps = .[0, -1]},
];
