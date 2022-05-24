#import "Math";
#import "SDL";
#import "GL";
#import "stb_image";
#import "Basic";

Texture :: struct {
    width, height : s32;
    gl_handle : u32;
}

Shader :: struct {
    gl_program : u32;
}

texture_shader : Shader;
color_shader : Shader;

gl_context : SDL_GLContext;
immediate_vao, immediate_vbo : u32;

init :: (window : *SDL_Window) {
    gl_context := SDL_GL_CreateContext(window);

    gl_load(*gl);
    gl_enable_debug_output(break_on_error = true);

    glGenVertexArrays(1, *immediate_vao);
    glGenBuffers(1, *immediate_vbo);
}

deinit :: () {
    glDeleteVertexArrays(1, *immediate_vao);
    glDeleteBuffers(1, *immediate_vbo);
    SDL_GL_DeleteContext(gl_context);
}

load_texture :: (texture : *Texture, path : string) -> bool {
    channels : s32 = ---;
    data := stbi_load(temp_c_string(path), *texture.width, *texture.height, *channels, 0);
    if !data {
        log("Unable to load %", path, flags = .ERROR);
        return false;
    }
    defer stbi_image_free(data);

    glGenTextures(1, *texture.gl_handle);
    glBindTexture(GL_TEXTURE_2D, texture.gl_handle);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    
    pixel_format : u32 = ---;
    if channels == {
        case 1; pixel_format = GL_RED;
        case 2; pixel_format = GL_RG;
        case 3; pixel_format = GL_RGB;
        case 4; pixel_format = GL_RGBA;
        case;
            log("Texture has % channels, this isn't supported", channels, flags = .ERROR);
            assert(false);
            return false;
    }

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx texture.width, xx texture.height, 0, pixel_format, GL_UNSIGNED_BYTE, data);
    return true;
}

set_scissor :: (x0 :s32, y0 : s32, x1 : s32, y1 : s32) {
    glEnable(GL_SCISSOR_TEST);
    glScissor(x0, y0, cast(u32)(x1-x0), cast(u32)(y1-y0));
}

clear_scissor :: () {
    glDisable(GL_SCISSOR_TEST);
}

set_shader :: (shader : *Shader) {
    // @TODO
    if state.current_shader && (state.current_shader != shader) {
        immediate_flush();
        glUseProgram(shader.gl_program);
        state.current_shader = shader;
    }
}

set_shader_for_images :: (texture : *Texture) {
    set_shader(texture_shader);
    glBindTexture(GL_TEXTURE_2D, texture.gl_handle);
}

immediate_quad :: (x0 : float, y0 : float, x1: float, y1 : float, color : Vector4) {
    get_space(6);
    put_vertex(*v[0], xy(x1, y0), color, 1, 0);
    put_vertex(*v[1], xy(x0, y0), color, 0, 0);
    put_vertex(*v[2], xy(x1, y1), color, 1, 1);

    put_vertex(*v[3], xy(x1, y1), color, 1, 0);
    put_vertex(*v[4], xy(x0, y0), color, 0, 0);
    put_vertex(*v[5], xy(x0, y1), color, 0, 1);

}
