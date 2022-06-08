
Animator :: struct {
    time : float32;
    direction : Direction;
    state : enum {
        IDLE;
        WALKING;
        ATTACKING;
    } = .IDLE;

    update :: (using animator: *Animator, dt : float32) {
        if state == .IDLE then return;

        time += dt;

        // @Hardcoded: Have an animation time? Auto transitions? Loop
        if state == {
            case .WALKING; {
                if time > 1.0 then time = 0;
            }
            case .ATTACKING; 
            if time > 1.0 {
                state = .IDLE;
                time = 0;
            }
        }
    }

    set_char_sprites :: (using animator : *Animator, char : *Character) {
        char.sprite_x = xx direction;

        if state == { // @Hardcoded
            case .IDLE; char.sprite_y = 6; 
            case .WALKING; char.sprite_y = 6 - cast(u32)(time * 4.0); 
            case .ATTACKING; char.sprite_y = 2;
        }
    }
}
