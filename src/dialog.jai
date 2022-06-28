

Dialog :: struct {

    Node :: struct {
        title : string;
        lines : []string;
        next : []u8;
    };

    update :: () {
        using context.game;
        if Input.input_button_states[#char "E"] & .START {
            current : *Node = *current_dialog_tree[current_dialog_node];
            if current.next.count == 0 {
                context.game.state = .GAME; // End the dialog
            } else {
                current_dialog_node = current.next[current_choice];
                current_choice = 0;
            }
        }
    }

    draw :: () {
        bg : *Simp.Texture;
        title := false;
        current_node : *Node = *context.game.current_dialog_tree[context.game.current_dialog_node];

        if current_node.title.count == 0 {
            bg = *context.game.dialogbox_notitle_texture;
        } else {
            title = true;
            bg = *context.game.dialogbox_texture;
        }
        Simp.set_shader_for_images(bg);
        w := ZOOM * bg.width;
        h := ZOOM * bg.height;

        x0 := (context.game.screen_width / 2.0) - w/2.0; 
        y0 := (context.game.screen_height * .05);
        Simp.immediate_quad(x0, y0, x0 + w, y0 + h, .{1,1,1,1}); 
        
        font := context.game.font;
        margin_x := 16; // @Hardcoded

        // Title
        if title {
            title_x0 := x0 + margin_x;
            title_y0 := y0 + h - (20); // @Hardcoded
            Simp.draw_text(font, xx title_x0, xx title_y0, current_node.title, .{1,1,1,1});
        }

        nb_lines := ifx title then 4 else 5;

        // Main dialog box
        y_space := 2;   // @Hardcoded
        line_height := font.character_height + y_space;
        text_x0 := x0 + margin_x;
        text_y0 := y0 + (nb_lines * line_height) - y_space;
        for current_node.lines {
            Simp.draw_text(font, xx text_x0, xx text_y0 - line_height * it_index, it, .{0,0,0,1});
        }
    }

    open :: (tree : []Node, first : u8 = 0) {
        context.game.state = .DIALOG;
        context.game.current_dialog_tree = tree;
        context.game.current_dialog_node = first;
    }
}