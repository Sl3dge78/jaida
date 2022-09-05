Basic   :: #import "Basic";
String  :: #import "String";
Math    :: #import "Math";
Random  :: #import "Random";
B_Array :: #import "Bucket_Array";
File    :: #import "File";

#import "SDL"; // Audio

#import "GL";
Simp    :: #import "Simp";

Input   :: #import "Input";
Window_Creation  :: #import "Window_Creation";

using Math; // To import operator overloading
round :: (x : float32) -> float32 {
    return ifx x >= 0.0 then floor(x+0.5) else ceil(x+0.5);
}

#placeholder DEVELOPER;

#load "game.jai";
#if 0 {
    #load "ecs.jai";
    #load "components.jai";
} else {
    #load "entities.jai";
}
#load "keymaps.jai";
#load "sprite.jai";
#load "map.jai";
#load "dialog.jai";
#load "dialogs.jai";
#load "audio.jai";
#load "npc.jai";
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
    Basic.init_time();
    SDL_Init(SDL_INIT_AUDIO);
    defer SDL_Quit();

    window := Window_Creation.create_window(1280, 720, "Zelda!");

    // Note: Editor is added to the context where they are defined.
    game_state := *context.game;

    requested_spec := SDL_AudioSpec.{
        freq = 44100,
        format = AUDIO_S16,
        channels = 1,
        silence = 0,
        samples = 4096,
        size = 0,
        callback = null,
        userdata = null,
    };
    obtained : SDL_AudioSpec = ---;
    game_state.audio_device = SDL_OpenAudioDevice(null, 0, *requested_spec, *obtained, 0);
    Basic.assert(game_state.audio_device != 0);
    defer SDL_CloseAudioDevice(game_state.audio_device);
    SDL_PauseAudioDevice(context.game.audio_device, 0);

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
}
