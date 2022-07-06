Basic :: #import "Basic";
Compiler :: #import "Compiler";

#run build();

// @TODO Make a bug report. Notes aren't specified in the typechecking of the structs.

component_list : [..]*Compiler.Code_Struct;
update_component_list : [..]*Compiler.Code_Struct;
draw_component_list : [..]*Compiler.Code_Struct;
hit_component_list : [..]*Compiler.Code_Struct;
once := false;

handle_components :: (message : *Compiler.Message) {
    using Compiler;
    if message.kind == .TYPECHECKED {
        tc := cast(* Message_Typechecked) message;
        for decl : tc.declarations {
            if !decl.expression.expression || decl.expression.expression.kind != .STRUCT continue;
            for note: decl.expression.notes {
                if note.text == "Component" {
                    Basic.array_add(*component_list, cast(*Compiler.Code_Struct)decl.expression.expression);
                }
                if note.text == "Update" {
                    Basic.array_add(*update_component_list, cast(*Compiler.Code_Struct)decl.expression.expression);
                }
                if note.text == "Draw" {
                    Basic.array_add(*draw_component_list, cast(*Compiler.Code_Struct)decl.expression.expression);
                }
                if note.text == "Hit" {
                    Basic.array_add(*hit_component_list, cast(*Compiler.Code_Struct)decl.expression.expression);
                }
            }
        }
    }

    if message.kind == .PHASE {
        phase := cast(*Message_Phase)message;
        if phase.phase == .TYPECHECKED_ALL_WE_CAN {
            if !once {
                builder : Basic.String_Builder;
                Basic.print_to_builder(*builder, "COMPONENT_COUNT :: %;\n", component_list.count);

                Basic.print_to_builder(*builder, "COMPONENT_LIST :: Type.[");
                for component_list {
                    Basic.print_to_builder(*builder, "%, ", it.defined_type.name);
                }
                Basic.print_to_builder(*builder, "];\n");

                Basic.print_to_builder(*builder, "UPDATE_COMPONENT_LIST :: Type.[");
                for update_component_list {
                    Basic.print_to_builder(*builder, "%, ", it.defined_type.name);
                }
                Basic.print_to_builder(*builder, "];\n");

                Basic.print_to_builder(*builder, "DRAW_COMPONENT_LIST :: Type.[");
                for draw_component_list {
                    Basic.print_to_builder(*builder, "%, ", it.defined_type.name);
                }
                Basic.print_to_builder(*builder, "];\n");

                Basic.print_to_builder(*builder, "HIT_COMPONENT_LIST :: Type.[");
                for hit_component_list {
                    Basic.print_to_builder(*builder, "%, ", it.defined_type.name);
                }
                Basic.print_to_builder(*builder, "];\n");

                add_build_string(Basic.builder_to_string(*builder), message.workspace);
                once = true;
            }
        }
    }
}

build :: () {
    w := Compiler.compiler_create_workspace("zelda");
    
    options := Compiler.get_build_options();
    options.output_path = "bin";
    options.intermediate_path = "tmp";
    options.output_type = .EXECUTABLE;
    //options.emit_debug_info = .DEFAULT;
    //options.backend = .X64;
    
    is_lsp := false;
    lsp_message : (*Compiler.Message) -> void;
    
    if options.user_data_u64 {
        lsp_message = << cast(*type_of(lsp_message)) options.user_data_u64;
        is_lsp = true;
    }

    import_path : [..] string = ---;
    Basic.array_add(*import_path, ..options.import_path);
    Basic.array_add(*import_path, "modules");
    options.import_path = import_path;

    Compiler.set_build_options(options, w);
    Compiler.compiler_begin_intercept(w);
    Compiler.add_build_string("DEVELOPER :: true;", w); // @Completeness: add release flag
    // Compiler.add_build_string("DEVELOPER :: false;", w); // @Completeness: add release flag
    Compiler.add_build_file("src/main.jai", w);
    
    
    while true {
        message := Compiler.compiler_wait_for_message();
        if !message continue;

        if is_lsp {
            lsp_message(message);
        }
        handle_components(message);

        if message.kind == .COMPLETE break;
    }   
    
    Compiler.compiler_end_intercept(w);
    Compiler.set_build_options_dc(.{do_output = false});
}
