

Dialog :: struct {
    update :: () {
        if Input.input_button_states[#char "E"] & .START {
            context.game.state = .GAME;

        }
    }

    draw :: () {
        db : *Simp.Texture;
        title := false;
        if context.game.current_dialog_title.count == 0 {
            db = *context.game.dialogbox_notitle_texture;
        } else {
            title = true;
            db = *context.game.dialogbox_texture;
        }
        Simp.set_shader_for_images(db);
        w := ZOOM * db.width;
        h := ZOOM * db.height;

        x0 := (context.game.screen_width / 2.0) - w/2.0; 
        y0 := (context.game.screen_height * .05);
        Simp.immediate_quad(x0, y0, x0 + w, y0 + h, .{1,1,1,1}); 
        
        font := context.game.font;
        margin_x := 16; // @Hardcoded

        // Title
        if title {
            title_x0 := x0 + margin_x;
            title_y0 := y0 + h - (20); // @Hardcoded
            Simp.draw_text(font, xx title_x0, xx title_y0, context.game.current_dialog_title, .{1,1,1,1});
        }

        nb_lines := ifx title then 4 else 5;

        // Main dialog box
        y_space := 2;   // @Hardcoded
        line_height := font.character_height + y_space;
        text_x0 := x0 + margin_x;
        text_y0 := y0 + (nb_lines * line_height) - y_space;
        for context.game.current_dialog_lines {
            Simp.draw_text(font, xx text_x0, xx text_y0 - line_height * it_index, it, .{0,0,0,1});
        }
    }

    open :: (text: string, title : string = "") {
        context.game.state = .DIALOG;
        context.game.current_dialog_lines = Basic.array_copy(String.split(text, "\n"));
        context.game.current_dialog_title = title;
    }
}
