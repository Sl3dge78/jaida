Basic :: #import "Basic";
Compiler :: #import "Compiler";

#run build();

build :: () {
    w := Compiler.compiler_create_workspace("Zelda");
    
    options := Compiler.get_build_options();
    options.output_executable_name = "Zelda";
    options.output_path = "bin";
    options.intermediate_path = "tmp";
    options.output_type = .EXECUTABLE;
    options.emit_debug_info = .DEFAULT;
    
    is_lsp := false;
    lsp_message : (*Compiler.Message) -> void;
    
    if options.user_data_u64 {
        lsp_message = << cast(*type_of(lsp_message)) options.user_data_u64;
        is_lsp = true;
    }

    Compiler.set_build_options(options, w);
    Compiler.compiler_begin_intercept(w);
    Compiler.add_build_file("src/main.jai", w);
    
    while true {
        message := Compiler.compiler_wait_for_message();
        if !message continue;

        if is_lsp {
            lsp_message(message);
        }

        if message.kind == .COMPLETE break;
    }   
    
    Compiler.compiler_end_intercept(w);
    Compiler.set_build_options_dc(.{do_output = false});
}