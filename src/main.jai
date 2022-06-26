Basic :: #import "Basic";
String :: #import "String";
Math :: #import "Math";
Random :: #import "Random";
B_Array :: #import "Bucket_Array";
Simp :: #import "Simp";
Window_Creation :: #import "Window_Creation";
Input :: #import "Input";

using Math; // To import operator overloading
libc :: #foreign_system_library "libm";
round :: (val : float32) -> float32 #foreign libc "roundf";

File :: #import "File";
#import "GL";

#load "game.jai";
#load "ecs.jai";
#load "components.jai";
#load "keymaps.jai";
#load "sprite.jai";
#load "map.jai";
#load "editor.jai";

TILE_SIZE :: 16;
TILE_HALF :: TILE_SIZE / 2;
ZOOM :: 2;

Direction :: enum u8 {
    SOUTH :: 0;
    NORTH :: 1;
    WEST :: 2;
    EAST :: 3;
}

forward :: (dir : Direction) -> Vector2 {
    if #complete dir == { 
        case .EAST; return .{1, 0};
        case .WEST; return .{-1, 0};
        case .NORTH; return .{0, 1};
        case .SOUTH; return .{0, -1};
    }
}

main :: () {
    // Init
    Basic.init_time();

    window := Window_Creation.create_window(1280, 720, "Zelda!");

    // Note: Game_State and Editor are added to the context where they are defined.
    game_state := *context.game;
    editor := *context.editor;

    game_state.screen_width, game_state.screen_height = Simp.get_render_dimensions(window);
    Simp.set_render_target(window);
    Game.load();

    quit := false;
    last_time := Basic.get_time();
    while !quit {
        now := Basic.get_time();
        delta_time : float = cast(float) (now - last_time);
        last_time = now;

        game_state.mouse_x, game_state.mouse_y = Window_Creation.get_mouse_pointer_position(window, false);
        game_state.mouse_y = game_state.screen_height - game_state.mouse_y;
        Input.update_window_events();
        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;
            keymap_handler(it);
        }
        for Input.get_window_resizes() {
            Simp.update_window(it.window);
        }

        Game.update(delta_time);
        Component_Manager.cleanup();
        Game.draw();

        Simp.swap_buffers(window);
        Basic.reset_temporary_storage();
    }
}
