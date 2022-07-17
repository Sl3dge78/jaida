

Dialog :: struct {

    Node :: struct {
        has_title : bool;

        // if title : 1st line is the title
        // if choices > 1 : last lines = choices
        lines : []string; 
        
        // choices
        jumps : []s8;

    };

    CHARS_PER_SECOND :: 100;

    get_char_timer :: (char : u8) -> float {
        if char == {
            case 0; return -1;
            case #char "."; #through;
            case #char "!"; #through;
            case #char "?"; return 1.0/5;
            case #char ","; return 1.0/10;

            case #char " "; return 1.0/20;
            case; return 1.0/100;
        }
    }

    update :: (delta_time : float) {
        using context.game;

        current : *Node = *current_dialog_tree[current_dialog_node];

        if char_timer > 0 {
            char_timer -= delta_time;  
        } else if char_timer > -1 {
            first_line, last_line := get_first_and_last_line(current);

            nb_chars : int;
            current_char : u8;
            for i : first_line..last_line - 1 {
                line := current.lines[i];
                position_in_line := context.game.dialog_nb_chars - nb_chars;
                if position_in_line <= line.count - 1 {
                    current_char = line[position_in_line];
                    char_timer += get_char_timer(current_char);
                    dialog_nb_chars += 1;
                    if Basic.is_alpha(current_char) {
                        Audio_Stream.mix_and_play_immediate(*dialog_blip, volume, audio_device);
                    }
                    if char_timer > 0 then break;
                } else {
                    nb_chars += line.count;
                }
            }
            if current_char == 0 { 
                char_timer = -1;
            }
        }


        if Input.input_button_states[#char "E"] & .START {
            if current.jumps.count == 0 || (current.jumps.count > 0 && current.jumps[current_choice] == -1) {
                context.game.state = .GAME; // End the dialog
                current_choice = 0;
                dialog_nb_chars = 0;
                char_timer = -1;
            } else {
                current_dialog_node = xx current.jumps[current_choice];
                current_choice = 0;
                dialog_nb_chars = 0;
                char_timer = 0;
            }
        }
        if Input.input_button_states[#char "A"] & .START { 
            current_choice -= 1;
            if current_choice < 0 then current_choice = xx (current.jumps.count - 1);
        }

        if Input.input_button_states[#char "D"] & .START { 
            current_choice += 1;
            if current_choice >= current.jumps.count then current_choice = 0;
        }

        if Input.input_button_states[#char "G"] & .START {
            
        }
    }

    get_first_and_last_line :: (node: *Node) -> int, int {
        first_line := ifx node.has_title then 1 else 0;
        last_line := node.lines.count - (ifx node.jumps.count == 1 then 0 else node.jumps.count);
        return first_line, last_line;
    }

    draw :: () {
        bg : *Simp.Texture;
        title := false;
        current_node : *Node = *context.game.current_dialog_tree[context.game.current_dialog_node];
        shadow_distance :: ZOOM * 2;

        
        if !current_node.has_title {
            bg = *context.game.dialogbox_notitle_texture;
        } else {
            bg = *context.game.dialogbox_texture;
        }
        Simp.set_shader_for_images(bg);
        w := ZOOM * bg.width;
        h := ZOOM * bg.height;

        x0 := (context.game.screen_width / 2.0) - w/2.0; 
        y0 := (context.game.screen_height * .05);
        Simp.immediate_quad(x0 + shadow_distance, y0 - shadow_distance, x0 + w + shadow_distance, y0 + h - shadow_distance, .{0,0,0,0.5}); 
        Simp.immediate_quad(x0, y0, x0 + w, y0 + h, .{1,1,1,1}); 
        
        font := context.game.font;
        margin_x := 16; // @Hardcoded

        // Title
        if current_node.has_title {
            title_x0 := x0 + margin_x;
            title_y0 := y0 + h - (20); // @Hardcoded
            Simp.draw_text(font, xx title_x0, xx title_y0, current_node.lines[0], .{1,1,1,1});
        }

        first_line, last_line := get_first_and_last_line(current_node);

        // Main dialog box
        y_space := 2;   // @Hardcoded
        line_height := font.character_height + y_space;
        text_x0 := x0 + margin_x;
        text_y0 := y0 + (5 * line_height) - y_space;

        // We'll stop drawing once we have reached this number
        char_left := context.game.dialog_nb_chars;
        for i : first_line..last_line - 1 {
            line := current_node.lines[i];
            if line.count > char_left {
                line.count = char_left;
                char_left = 0;
            } else {
                char_left -= line.count;
            }
            Simp.draw_text(font, xx text_x0, xx text_y0 - line_height * i, line, .{0,0,0,1});

            if char_left == 0 break;
        }
        
        // Choice box
        if current_node.jumps.count > 1 {
            choice_w := context.game.dialogbox_choice_texture.width * ZOOM;
            choice_h := context.game.dialogbox_choice_texture.height * ZOOM;
            choice_padding := choice_w + 8;
            choice_x0 := (x0 + w) - (current_node.jumps.count * choice_padding) - 8;
            choice_y0 := y0 + 8;
            for current_node.jumps {
                Simp.set_shader_for_images(*context.game.dialogbox_choice_texture);
                x := choice_x0 + it_index * choice_padding;
                // Shadow
                Simp.immediate_quad(x + shadow_distance, choice_y0 - shadow_distance, x + choice_w + shadow_distance, choice_y0 + choice_h - shadow_distance, .{0, 0, 0, 0.5});
                // Actual 
                Simp.immediate_quad(x, choice_y0, x + choice_w, choice_y0 + choice_h, .{1, 1, 1, 1});
                // Text
                color : Vector4 = Game.Palette.BLACK;
                if context.game.current_choice == it_index  { 
                    if (context.game.second * 2.0) > 1.0 {
                        color = lerp(Game.Palette.BLACK, Game.Palette.DARK_ORANGE, context.game.second);
                    } else {
                        color = lerp(Game.Palette.DARK_ORANGE, Game.Palette.BLACK, context.game.second);
                    }
                }
                Simp.draw_text(font, xx (x + 6 * ZOOM), xx (choice_y0 + 7 * ZOOM), current_node.lines[it_index + last_line], color);
            }
        }
    }

    open :: (tree : []Node, first : u8 = 0) {
        context.game.current_dialog_node = 0;
        context.game.state = .DIALOG;
        context.game.current_dialog_tree = tree;
        context.game.current_dialog_node = first;
        context.game.dialog_nb_chars = 0;
        context.game.char_timer = 0;
    }
}
