
#placeholder COMPONENT_COUNT;
#placeholder COMPONENT_LIST;

Entity_ :: struct {
    components : [64]int;

    get_component :: (component : $T) -> u32 {

    }
};

Components_Manager :: struct {
    entities : [..]Entity_;
    
    #insert #run get_component_storage();

    get_component_id :: ($component : $T) -> u32 {
        #assert T == Type;
        #assert type_info(component).type == .STRUCT;
        return #run -> u32 {
            component_id += 1;
            return component_id;
        };
    }
};

component_id : u32 = 0;

get_component_storage :: () -> string {
    builder : Basic.String_Builder;
    Basic.print_to_builder(*builder, "sprites : [..]Sprite;");
    return Basic.builder_to_string(*builder);
}

Sprite :: struct {
    sprite_sheet : Renderer.Texture = ---; 
    uv0 : Vector2 = .{0, 0};
    uv1 : Vector2 = .{1, 1};
} @Component

