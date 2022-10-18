Basic   :: #import "Basic";
String  :: #import "String";
Math    :: #import "Math";
Random  :: #import "Random";
B_Array :: #import "Bucket_Array";
File    :: #import "File";
File_Utilities :: #import "File_Utilities";

#import "SDL"; // Audio

#import "GL";
Simp    :: #import "Simp";

Input   :: #import "Input";
Window_Creation  :: #import "Window_Creation";

using Math; // To import operator overloading
round :: (x : float32) -> float32 {
    return ifx x >= 0.0 then floor(x+0.5) else ceil(x+0.5);
}

todo :: () #expand {
    Basic.assert(false, "Todo!");
}

#load "game.jai";

#load "entities/entities.jai";
#load "entities/player.jai";
#load "entities/boss.jai";

#load "keymaps.jai";
#load "sprite.jai";
#load "map.jai";
#load "dialog.jai";
#load "dialogs.jai";
#load "audio.jai";
#load "npc.jai";

//#placeholder DEVELOPER;

#if DEVELOPER {
    #load "editor.jai";
}

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
    {
        Basic.push_allocator(Basic.temp);
        wd := File_Utilities.parse_path(to_string(__command_line_arguments[0]));
        wd_string := path_to_string(wd, wd.words.count - 1);
        Basic.set_working_directory(wd_string);
    }

    Basic.init_time();
    SDL_Init(SDL_INIT_AUDIO);
    defer SDL_Quit();

    window := Window_Creation.create_window(1280, 720, "Zelda!");

    // Note: Editor is added to the context where they are defined.
    game_state := *context.game;

    // Init audio
    Audio_System.init(*game_state.audio_system);
    defer Audio_System.deinit(*game_state.audio_system);

    game_state.screen_width, game_state.screen_height = Simp.get_render_dimensions(window);
    Simp.set_render_target(window);

    Game.load();

    last_time := Basic.get_time();
    while !context.game.quit {
        now := Basic.get_time();
        delta_time : float = cast(float) (now - last_time);
        last_time = now;

        game_state.mouse_x, game_state.mouse_y = Window_Creation.get_mouse_pointer_position(window, false);
        game_state.mouse_y = game_state.screen_height - game_state.mouse_y;
        Input.update_window_events();
        for Input.events_this_frame {
            if it.type == .QUIT then context.game.quit = true;
            keymap_handler(it);
        }
        for Input.get_window_resizes() {
            Simp.update_window(it.window);
        }

        Game.update(delta_time);
        Game.draw();

        Simp.swap_buffers(window);
        Basic.reset_temporary_storage();
    }

    // Game.unload();
    // Basic.reset_temporary_storage();
}
