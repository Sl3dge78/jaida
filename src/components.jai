
#placeholder COMPONENT_COUNT;
#placeholder COMPONENT_LIST;
#placeholder UPDATE_COMPONENT_LIST;
#placeholder DRAW_COMPONENT_LIST;

#scope_module

Entity_ :: struct {
    components : [COMPONENT_COUNT]u8; // This is an offset to the array in Component_Manager 
    // @Todo: once we get into deletion, use a Bucket_Array

    get_component :: (entity : *Entity_, $component : Type) -> *component {
        #run Component_Manager.assert_is_component(component);
        return Component_Manager.get_component(component, entity.components[Component_Manager.get_component_id(component)]);
    }

    add_component :: (entity : *Entity_, $component : Type) -> *component {
        #run Component_Manager.assert_is_component(component);
        comp_id := Component_Manager.get_component_id(component); 
        if entity.components[comp_id] != 0 {
            return get_component(entity, component);
        } else {
            comp, id := Component_Manager.create_component(component);
            Basic.log("comp = %, id = %", comp, id);
            entity.components[comp_id] = id;
            comp.entity = entity;
            return comp;
        }
    }

    has_component :: (entity : *Entity_, $component : Type) -> bool {
        comp_id := Component_Manager.get_component_id(component); 
        return entity.components[comp_id] != 0;
    }
};

Component_Manager :: struct {
    // Here is inserted one dynamic array for each struct declared as @Component. 
    generate_component_storage :: () -> string {
        builder : Basic.String_Builder;
        for COMPONENT_LIST {
            ti := cast(* Type_Info_Struct)it;
            name := ti.name;
            Basic.print_to_builder(*builder, "% : [..]%;\n", String.to_lower_copy(name), name);
        }
        return Basic.builder_to_string(*builder);
    }

    #insert #run generate_component_storage();

    // Create and Get component, use an offset in the dynamic array of the component offset by one.
    // This is so that a value of 0 equals to no component.
    create_component :: ($component : Type) -> *component, u8 {
        storage := get_component_storage(component);
        comp := Basic.array_add(storage);
        Basic.assert(storage.count <= 255, "We exceeded the capacity of u8 for storage of this component.");
        return comp, xx storage.count;
    }

    get_component :: ($component : Type, id : u32) -> *component {
        storage := get_component_storage(component);
        return *(<< storage)[id - 1];
    }

    get_component_storage :: ($component : Type) -> *[..]component {
        #insert #run -> string {
            ti := cast(* Type_Info_Struct)component;
            return Basic.tprint("return *component_manager.%;", String.to_lower_copy(ti.name));
        };
    }


    get_component_id :: ($component : $T) -> u32 {
        #run assert_is_component(component);     
        return #run -> u32 {
            value := component_id;
            component_id += 1;
            return value;
        };
    }

    is_component :: ($component : Type) -> bool {
        return #run -> bool {
            for COMPONENT_LIST {
                if component == it return true;
            }
            return false;
        };
    }

    assert_is_component :: ($component : Type) {
        if !Component_Manager.is_component(component) {
            Basic.assert(false, "% is not a component.", component);
        }
    }

    update_all_components :: (delta_time : float) {
        #insert #run -> string {
            builder : Basic.String_Builder;
            for UPDATE_COMPONENT_LIST {
                Basic.print_to_builder(*builder, "for * << (Component_Manager.get_component_storage(%)) {\n\t%.update(it, delta_time);\n}\n", it, it);
            }
            return Basic.builder_to_string(*builder);
        };
    }

    draw_all_components :: () {
        #insert #run -> string {
            builder : Basic.String_Builder;
            for DRAW_COMPONENT_LIST {
                Basic.print_to_builder(*builder, "for * << (Component_Manager.get_component_storage(%)) {\n\t%.draw(it);\n}\n", it, it);
            }
            return Basic.builder_to_string(*builder);
        };
    }
};

Component :: struct {
    entity : *Entity_; // @Todo change that to offset into table 
}

Sprite :: struct {
    using component : Component;

    sprite_sheet : Renderer.Texture = ---; 
    x0, y0, x1, y1 : int;
    sprite_x : u32;
    sprite_y : u32;

    update :: (using sprite : *Sprite, delta_time : float) {
        animation := Entity_.get_component(entity, Animation);
        if animation {
            if animation.state == { 
                case .IDLE;      sprite_y = 6; 
                case .WALKING;   sprite_y = 6 - cast(u32)(animation.time * 4.0); 
                case .ATTACKING; sprite_y = 2;
            }
        }

        xform := Entity_.get_component(entity, Transform);
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
        vel := Entity_.get_component(entity, Velocity);
        if vel {
            final_vel := Game.move_and_slide(pos, vel.vel, context.game.current_map);
            xform.pos += final_vel;

            if length(final_vel) > 0 {
                anim := Entity_.get_component(entity, Animation);

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
                        if Entity_.has_component(entity, Player) {
                            Game.request_map_change(context.game.current_map, xform.world_pos);
                        }
                        xform.pos = new_pos;
                    }
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
        vel := Entity_.get_component(entity, Velocity);
        if vel {
            if Math.length(vel.vel) > 0 {
                state = .WALKING;
            } else {
                state = .IDLE;
            }
        }

        player := Entity_.get_component(entity, Player);
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
        if state != .ATTACKING {
            // Movement
            player_vel : Vector2;
            if Input.get_keyboard(SDL_SCANCODE_W) then player_vel.y += 1;         
            if Input.get_keyboard(SDL_SCANCODE_A) then player_vel.x -= 1;
            if Input.get_keyboard(SDL_SCANCODE_S) then player_vel.y -= 1; 
            if Input.get_keyboard(SDL_SCANCODE_D) then player_vel.x += 1; 
            norm_vel := Math.unit_vector(player_vel) * (delta_time * SPEED);
            velocity := Entity_.get_component(entity, Velocity);
            velocity.vel = norm_vel;

            // Attack
            if Input.pressed_this_frame(SDL_SCANCODE_SPACE) {
                state = .ATTACKING;
                attack_time = 0.1;
            }
        } else {
            attack_time -= delta_time;
            if attack_time <= 0 then state == .IDLE;
        }
    }
} @Component @Update

#scope_file
component_manager : Component_Manager;
component_id : u32 = 0;
