Basic :: #import "Basic";
Window_Creation :: #import "Window_Creation";
Simp :: #import "Simp";
Input :: #import "Input";

main :: () {
    Basic.init_time();

    window := Window_Creation.create_window(1280, 720, "Zelda");

    window_width, window_height := Simp.get_render_dimensions(window);
    Simp.set_render_target(window);

    quit := false;
    last_time := Basic.get_time();
    while !quit {
        now := Basic.get_time();
        delta_time : float = cast(float) (now - last_time);
        last_time = now;

        Input.update_window_events();
        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;
        }

        Basic.reset_temporary_storage();

        Simp.clear_render_target(0, 0, 0, 1);
        Simp.swap_buffers(window);
    }
}