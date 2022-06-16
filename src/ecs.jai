#placeholder COMPONENT_COUNT;
#placeholder COMPONENT_LIST;
#placeholder UPDATE_COMPONENT_LIST;
#placeholder DRAW_COMPONENT_LIST;

using B_Array;

Entity :: struct {
    components : [COMPONENT_COUNT] *Component;
    Tag :: enum {
        NONE;
        PLAYER;
        NPC;
        ENEMY;
    };
    tag : Tag; 
    request_active_state_toggle : bool;
    inactive: bool;

    create :: () -> *Entity {
        return find_and_occupy_empty_slot(*all_entities);
    }

    delete :: (entity : *Entity) {
        #insert #run -> string {
            builder : Basic.String_Builder;
            for COMPONENT_LIST {
                Basic.print_to_builder(*builder, "remove_component(entity, %);\n", it);
            }
            return Basic.builder_to_string(*builder);
        };

        for all_entities {
            if *it == entity {
                remove it;
                return;
            }
        }
    }

    get_first :: (tag : Tag) -> *Entity {
        for * all_entities {
            if it.tag == tag return it;
        }
        return null;
    }

    get_all :: (tag : Tag) -> []* Entity {
        result : [..]*Entity;
        result.allocator = Basic.temporary_allocator;

        for * all_entities {
            if it.tag == tag {
                Basic.array_add(*result, it);
            }
        }
        return result;
    }

    get_component :: (entity : *Entity, $component : Type) -> *component {
        #run Component_Manager.assert_is_component(component);
        return cast(*component)entity.components[Component_Manager.get_component_id(component)];
    }

    add_component :: (entity : *Entity, $component : Type) -> *component {
        #run Component_Manager.assert_is_component(component);
        comp_id := Component_Manager.get_component_id(component); 
        if entity.components[comp_id] != null {
            return get_component(entity, component);
        } else {
            comp := Component_Manager.create_component(component, entity.inactive);
            comp.entity = entity;
            entity.components[comp_id] = cast(*Component)comp;
            return comp;
        }
    }

    has_component :: (entity : *Entity, $component : Type) -> bool {
        comp_id := Component_Manager.get_component_id(component); 
        return entity.components[comp_id] != null;
    }
    
    remove_component :: (entity: *Entity, $component : Type) {
        comp := get_component(entity, component);
        if comp == null then return;
        storage := Component_Manager.get_component_storage(component, entity.inactive);
        bucket_array_remove(storage, comp.loc);
        entity.components[Component_Manager.get_component_id(component)] = null;
    }

    change_inactive :: (entity : *Entity, $$inactive : bool) {
        #if is_constant(inactive) {
            #insert #run -> string {
                builder : Basic.String_Builder;
                for COMPONENT_LIST {
                    Basic.print_to_builder(*builder, "if has_component(entity, %) then \n", it);
                    Basic.print_to_builder(*builder, "\tComponent_Manager.change_inactive(cast(*%)(entity.components[%]), %);\n", it, it_index, inactive);
                }
                return Basic.builder_to_string(*builder);
            };
        } else {
            if inactive 
                change_inactive(entity, true);
            else 
                change_inactive(entity, false);
        }
        entity.inactive = inactive;
    }
};

all_entities : Bucket_Array(Entity, 1);

Component_Manager :: struct {

    // Here is inserted one dynamic array for each struct declared as @Component. 
    generate_component_storage :: () -> string {
        builder : Basic.String_Builder;
        for COMPONENT_LIST {
            ti := cast(* Type_Info_Struct)it;
            name := ti.name;
            Basic.print_to_builder(*builder, "%_active : Bucket_Array(%, 1);\n", String.to_lower_copy(name), name);
            Basic.print_to_builder(*builder, "%_inactive : Bucket_Array(%, 1);\n", String.to_lower_copy(name), name);
        }
        return Basic.builder_to_string(*builder);
    }

    #insert #run generate_component_storage();

    create_component :: ($component : Type, $$inactive : bool) -> *component {
        storage := get_component_storage(component, inactive);
        comp, loc := find_and_occupy_empty_slot(storage);
        comp.loc = loc;
        return comp;
    }

    get_component_storage :: ($component : $T, $$inactive : bool) -> *Bucket_Array(component, 1) {
        #if is_constant(inactive) {
            #insert #run -> string {
                ti := cast(* Type_Info_Struct)component;
                return Basic.tprint("return *component_manager.%_%;", 
                                    String.to_lower_copy(ti.name),
                                    ifx inactive then "inactive" else "active");
            };
        } 

        if inactive 
            return get_component_storage(component, true);
        else 
            return get_component_storage(component, false);
    }

    get_component_id :: ($component : $T) -> u32 {
        #run assert_is_component(component);     
        return #run -> u32 {
            for COMPONENT_LIST {
                if it == component return xx it_index;
            }
            Basic.assert(false);
            return 0;
        };
    }

    component_from_id :: ($id : u32) -> Type {
        return #run -> Type {
            return COMPONENT_LIST[id];
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
        Basic.assert(Component_Manager.is_component(component), "% is not a component.", component);
    }

    update_components :: (delta_time : float, $inactive : bool = false) {
        #insert #run -> string {
            builder : Basic.String_Builder;
            for UPDATE_COMPONENT_LIST {
                Basic.print_to_builder(*builder, "for * << (Component_Manager.get_component_storage(%, %)) {\n\t%.update(it, delta_time);\n}\n", it, inactive, it);
            }
            return Basic.builder_to_string(*builder);
        };
    }

    draw_components :: ($inactive : bool = false) {
        #insert #run -> string {
            builder : Basic.String_Builder;
            for DRAW_COMPONENT_LIST {
                Basic.print_to_builder(*builder, "for * << (Component_Manager.get_component_storage(%, %)) {\n\t%.draw(it);\n}\n", it, inactive, it);
            }
            return Basic.builder_to_string(*builder);
        };
    }

    change_inactive :: (component : *$T, $$inactive : bool) {
        new_comp := create_component(T, inactive);
        << new_comp = << component; // Copy
        new_comp.entity.components[get_component_id(T)] = cast(*Component)new_comp;

        old_storage := get_component_storage(T, !inactive);
        bucket_array_remove(old_storage, component.loc);
    }

    cleanup :: () {
        for * all_entities {
            if it.request_active_state_toggle {
                for it.components {
                    Basic.log("%: %", it_index, it);
                }
                Entity.change_inactive(it, !it.inactive);
                it.request_active_state_toggle = false;
            }
        }
    }
};

#scope_file
component_manager : Component_Manager;