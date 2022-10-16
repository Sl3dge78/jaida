

Dialog :: struct {

    Choice :: struct {
        reply: string;
        jump: s8;
    };

    Node :: struct {
        title : string;
        text : []string; 
        choices : []Choice = .[.{"", -1}];
    };

    CHARS_PER_SECOND :: 100;

    get_char_timer :: (char : u8) -> float {
        if char == {
            case 0; return -1;
            case #char "."; #through;
            case #char "!"; #through;
            case #char "?"; return 1.0/5;
            case #char ","; return 1.0/10;

            case #char " "; return 1.0/50;
            case; return 1.0/100;
        }
    }

    update :: (delta_time : float) {
        using context.game;

        current : *Node = *current_dialog_tree[current_dialog_node];
        
        if current_line < current.text.count { // We're in the process of drawing lines
            if char_timer > 0 {
                char_timer -= delta_time;  
            } else {
                line := current.text[current_line];                  
                
                char_timer += get_char_timer(line[current_char]);
                if Basic.is_alpha(line[current_char]) {
                    Audio_System.play(*audio_system, 0, *sounds.blip);
                }
                current_char += 1;
                if current_char >= line.count { // We finished the line
                    current_char = 0;
                    current_line += 1;
                }
            }
        }


        if Input.input_button_states[#char "E"] & .START {
            if current_line < current.text.count { // We haven't finished drawing the full dialog. Finish it now
                current_line = current.text.count;
                current_char = 0;
            } else { // Go to the next dialog/end
                if current.choices.count == 0 || (current.choices.count > 0 && current.choices[current_choice].jump == -1) {
                    if context.game.on_dialog_complete {
                        on_dialog_complete();  
                        context.game.on_dialog_complete = null;
                    } 
                    context.game.state = .GAME; // End the dialog
                    
                } else {
                    current_dialog_node = xx current.choices[current_choice].jump;
                }
                current_choice = 0;
                current_line = 0;
                char_timer = 0;
            }
        }
        if Input.input_button_states[#char "A"] & .START { 
            current_choice -= 1;
            if current_choice < 0 then current_choice = xx (current.choices.count - 1);
        }

        if Input.input_button_states[#char "D"] & .START { 
            current_choice += 1;
            if current_choice >= current.choices.count then current_choice = 0;
        }

        if Input.input_button_states[#char "G"] & .START {
            
        }
    }

    draw :: () {
        bg : *Simp.Texture;
        title := false;
        current_node : *Node = *context.game.current_dialog_tree[context.game.current_dialog_node];
        shadow_distance :: ZOOM * 2;

        
        if current_node.title.count == 0 {
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
        if current_node.title.count > 0 {
            title_x0 := x0 + margin_x;
            title_y0 := y0 + h - (20); // @Hardcoded
            Simp.draw_text(font, xx title_x0, xx title_y0, current_node.title, .{1,1,1,1});
        }

        // Main dialog box
        y_space := 2;   // @Hardcoded
        line_height := font.character_height + y_space;
        text_x0 := x0 + margin_x;
        text_y0 := y0 + (4 * line_height) - y_space;
        if current_node.title.count == 0 then text_y0 += line_height;

        for current_node.text {
            if context.game.current_line > it_index {
                Simp.draw_text(font, xx text_x0, xx text_y0 - line_height * it_index, it, .{0,0,0,1});
                continue;
            } else {
                current := it;
                current.count = context.game.current_char;
                Simp.draw_text(font, xx text_x0, xx text_y0 - line_height * it_index, current, .{0,0,0,1});                
                break;
            }
        }
        
        // Choice box
        if current_node.choices.count > 1 {
            choice_w := context.game.dialogbox_choice_texture.width * ZOOM;
            choice_h := context.game.dialogbox_choice_texture.height * ZOOM;
            choice_padding := choice_w + 8;
            choice_x0 := (x0 + w) - (current_node.choices.count * choice_padding) - 8;
            choice_y0 := y0 + 8;
            for current_node.choices {
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
                Simp.draw_text(font, xx (x + 6 * ZOOM), xx (choice_y0 + 7 * ZOOM), it.reply, color);
            }
        }
    }

    open :: (tree : []Node, first : u8 = 0) {
        context.game.current_dialog_node = 0;
        context.game.state = .DIALOG;
        context.game.current_dialog_tree = tree;
        context.game.current_dialog_node = first;
        context.game.current_char = 0;
        context.game.current_line = 0;
        context.game.char_timer = 0;
    }
}
