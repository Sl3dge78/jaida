
Character :: struct {
    pos : Vector2;
    sprite_sheet : Renderer.Texture;
    sprite_x : u32;
    sprite_y : u32;

    init :: (pos : Vector2 = .{20, 11}, sprite_sheet : Renderer.Texture) -> Character {
        result : Character;
        result.pos = pos;
        result.sprite_sheet = sprite_sheet;
        return result;
    }

    draw :: (using this : *Character) {
        Renderer.set_shader_for_images(*sprite_sheet);
        x0, y0 := Map.map_to_screen(context.game.camera_position, pos + Vector2.{-0.5, -0.5});
        x1, y1 := Map.map_to_screen(context.game.camera_position, pos + Vector2.{+0.5, +0.5});
        uv0, uv1 := get_uv_from_texture(*sprite_sheet, sprite_x, sprite_y);
        Renderer.immediate_quad(x0 = xx x0, y0 = xx y0, x1 = xx x1, y1 = xx y1, uv0 = uv0, uv1 = uv1);
    }

    translate_and_animate :: (char: *Character, vel : Vector2, animator : *Animator) {
        final_vel := move_and_slide(char.pos, vel, context.game.current_map);
        char.pos += final_vel;

        // Walk animation
        if length(final_vel) > 0 {
            animator.state = .WALKING;
            if final_vel.x > 0 then animator.direction = Direction.EAST;
            if final_vel.x < 0 then animator.direction = Direction.WEST;
            if final_vel.y > 0 then animator.direction = Direction.NORTH;
            if final_vel.y < 0 then animator.direction = Direction.SOUTH;
        } else {
            animator.state = .IDLE;
        }
    }
}
