Basic :: #import "Basic";
Math :: #import "Math";
Random :: #import "Random";
using Math; // To import operator overloading
libc :: #foreign_system_library "libm";
round :: (val : float32) -> float32 #foreign libc "roundf";

File :: #import "File";
#import "GL";
#import "SDL";

Renderer :: #import "Renderer";
Input :: #import "sInput";

#load "game.jai";
#load "keymaps.jai";
#load "sprite.jai";
#load "map.jai";
#load "editor.jai";
#load "character.jai";

TILE_SIZE :: 16;
TILE_HALF :: TILE_SIZE / 2;
ZOOM :: 2;

Direction :: enum u8 {
    SOUTH :: 0;
    NORTH :: 1;
    WEST :: 2;
    EAST :: 3;
}

main :: () {
    // Init
    Basic.init_time();
    SDL_Init(SDL_INIT_EVERYTHING);
    defer SDL_Quit();

    window := SDL_CreateWindow("Zelda", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1280, 720, SDL_WINDOW_OPENGL);
    if !window {
        Basic.log("%", Basic.to_string(SDL_GetError()));
        return;
    }
    defer SDL_DestroyWindow(window);

    Renderer.init(window);
    defer Renderer.deinit();

    // Note: Game_State and Editor are added to the context where they are defined.
    game_state := *context.game;
    editor := *context.editor;

    w, h : s32 = ---;
    SDL_GetWindowSize(window, *game_state.screen_width, *game_state.screen_height);

    Game.load();

    quit := false;
    last_time := Basic.get_time();
    while !quit {
        now := Basic.get_time();
        delta_time : float = cast(float) (now - last_time);
        last_time = now;

        Input.begin_frame(game_state.screen_height);

        // @TODO : Make it so that the only way to access these is through keymaps?
        event : SDL_Event = ---;
        while SDL_PollEvent(*event) {
            if event.type == {
                case SDL_QUIT;
                    quit = true;
                case SDL_WINDOWEVENT; 
                    if event.window.event == {
                        case SDL_WINDOWEVENT_RESIZED; 
                            Renderer.update_window(window);
                    };
            };
            if game_state.state == .EDITOR {
                if event.type == {
                    case SDL_MOUSEBUTTONUP;
                        if event.button.button == SDL_BUTTON_LEFT {
                            if editor.show_map {
                                if Input.mouse_x < game_state.screen_width / 2 { // Clicking on the map
                                    tile_x := Input.mouse_x / TILE_SIZE / editor.zoom - editor.offset_x;
                                    tile_y := Input.mouse_y / TILE_SIZE / editor.zoom - editor.offset_y;
                                    editor.selected_tile = xy_to_tile_id(*game_state.map_texture, xx tile_x, xx tile_y);
                                }
                            }
                        }
                }
            }
            keymap_handler(*event);
        }

        Game.update(delta_time);
        Game.draw();

        Renderer.swap_buffers(window);
        Basic.reset_temporary_storage();
    }
}
