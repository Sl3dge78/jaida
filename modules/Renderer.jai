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
    gl_program : GLuint;
}

Vertex :: struct {
    pos : Vector2;
    color : Vector4;
    uv : Vector2;
}

Immediate_State :: struct {
    width, height : s32;
    current_shader : *Shader;

    MAX_VERTICES :: 2400;
    vertices : [MAX_VERTICES] Vertex;
    nb_vertices : u32;
}

#add_context renderer_state : *Immediate_State;

texture_shader : Shader;
color_shader : Shader;

gl_context : SDL_GLContext;
immediate_vao, immediate_vbo : u32;

// --------
// Lifecycle 

init :: (window : *SDL_Window) {
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    gl_context := SDL_GL_CreateContext(window);

    gl_load(*gl);
    gl_enable_debug_output(break_on_error = true);

    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);

    glGenVertexArrays(1, *immediate_vao);
    glGenBuffers(1, *immediate_vbo);
    context.renderer_state = New(Immediate_State);

    color_shader.gl_program = load_shader(color_shader_code);
    texture_shader.gl_program = load_shader(texture_shader_code);

    update_window(window);
}

deinit :: () {
    glDeleteVertexArrays(1, *immediate_vao);
    glDeleteBuffers(1, *immediate_vbo);
    SDL_GL_DeleteContext(gl_context);
    free(context.renderer_state);
}

update_window :: (window : *SDL_Window) {
    w, h : s32 = ---;
    SDL_GetWindowSize(window, *w, *h);
    glViewport(0, 0, xx w, xx h);
    context.renderer_state.width = w;
    context.renderer_state.height = h;
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

// --------
// State management

set_scissor :: (x0 :s32, y0 : s32, x1 : s32, y1 : s32) {
    glEnable(GL_SCISSOR_TEST);
    glScissor(x0, y0, cast(u32)(x1-x0), cast(u32)(y1-y0));
}

clear_scissor :: () {
    glDisable(GL_SCISSOR_TEST);
}

clear_render_target :: (r : float, g : float, b : float, a : float) {
    glClearColor(r, g, b, a);
    glClear(GL_COLOR_BUFFER_BIT);
}

swap_buffers :: (window : *SDL_Window) {
    immediate_flush();
    SDL_GL_SwapWindow(window);
}

set_shader :: (shader : *Shader) {
    if context.renderer_state.current_shader != shader {
        if context.renderer_state.current_shader then immediate_flush();
        glUseProgram(shader.gl_program);
        context.renderer_state.current_shader = shader;

        m := orthographic_projection_matrix(0, cast(float) context.renderer_state.width, 0, cast(float) context.renderer_state.height, -1.0, 1.0);
        glUniformMatrix4fv(glGetUniformLocation(shader.gl_program, "projection"), 1, GL_TRUE, *m._11);
    }
}

set_shader_for_images :: (texture : *Texture) {
    set_shader(*texture_shader);
    immediate_flush();
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture.gl_handle);
    loc := glGetUniformLocation(context.renderer_state.current_shader.gl_program, "diffuse_texture");
    glUniform1i(loc, 0);
}

set_shader_for_color :: () {
    set_shader(*color_shader);
}

// --------
// Immediate stuff

get_space :: (nb : int) #expand {
    `state := context.renderer_state;
    if state.nb_vertices + nb >= state.MAX_VERTICES immediate_flush();
    `v := state.vertices.data + state.nb_vertices;
    state.nb_vertices += nb;
}

put_vertex :: (v : *Vertex, pos : Vector2, color : Vector4, uv : Vector2) {
    v.pos = pos;
    v.color = color;
    v.uv = uv;
}

immediate_flush :: () {
    state := context.renderer_state;
    assert(state != null, "Trying to flush, but there is no state.");
    if !state.nb_vertices return;
    assert(state.current_shader != null, "Trying to flush but no shader, was assigned");

    glBindVertexArray(immediate_vao);
    glBindBuffer(GL_ARRAY_BUFFER, immediate_vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(Vertex) * state.nb_vertices, state.vertices.data, GL_STREAM_DRAW);

    glDisable(GL_CULL_FACE);

    stride :: size_of(Vertex);
    offset : *Vertex = null;
    // Position
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, xx false, stride, xx *offset.pos);
    
    // Color
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 4, GL_FLOAT, xx false, stride, xx *offset.color);

    // UV
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 2, GL_FLOAT, xx false, stride, xx *offset.uv);

    glDrawArrays(GL_TRIANGLES, 0, xx state.nb_vertices);

    state.nb_vertices = 0;
}

immediate_quad :: (x0 : float, y0 : float, x1: float, y1 : float, color : Vector4) {
    get_space(6);
    put_vertex(*v[0], xy(x0, y0), color, xy(0, 0));
    put_vertex(*v[1], xy(x0, y1), color, xy(0, 1));
    put_vertex(*v[2], xy(x1, y1), color, xy(1, 1));

    put_vertex(*v[3], xy(x0, y0), color, xy(0, 0));
    put_vertex(*v[4], xy(x1, y1), color, xy(1, 1));
    put_vertex(*v[5], xy(x1, y0), color, xy(1, 0));
}

immediate_quad :: (x0 : float, y0 : float, x1: float, y1 : float, color : Vector4 = .{1, 1, 1, 1}, uv0 : Vector2, uv1 : Vector2) {
    get_space(6);
    put_vertex(*v[0], xy(x0, y0), color, xy(uv0.x, uv0.y));
    put_vertex(*v[1], xy(x0, y1), color, xy(uv0.x, uv1.y));
    put_vertex(*v[2], xy(x1, y1), color, xy(uv1.x, uv1.y));

    put_vertex(*v[3], xy(x0, y0), color, xy(uv0.x, uv0.y));
    put_vertex(*v[4], xy(x1, y1), color, xy(uv1.x, uv1.y));
    put_vertex(*v[5], xy(x1, y0), color, xy(uv1.x, uv0.y));
}

// --------
// Shader

load_shader :: (code : string) -> GLuint {
    make_shader :: (header : string, source : string, type : GLenum) -> v: GLuint {
        shader := glCreateShader(type);

        code : [2]*u8;
        code[0] = header.data;
        code[1] = source.data;
        len : [2]s32;
        len[0] = xx header.count;
        len[1] = xx source.count;

        glShaderSource(shader, 2, code.data, len.data);
        glCompileShader(shader);

        success : GLint;
        glGetShaderiv(shader, GL_COMPILE_STATUS, *success);

        if !success then {
            log_data: [512] u8;
            glGetShaderInfoLog(shader, log_data.count, null, log_data.data);
            log("%", to_string(log_data.data), flags=.ERROR);
            assert(false);
            return 0;
        }
        return shader;
    }

    V_HEADER :: #string __GLSL
    #version 330 core
    #define VERTEX_SHADER
    #define IN_OUT out
    __GLSL;

    F_HEADER :: #string __GLSL
    #version 330 core
    #define FRAGMENT_SHADER
    #define IN_OUT in
    __GLSL;

    shader_v := make_shader(V_HEADER, code, GL_VERTEX_SHADER); 
    defer glDeleteShader(shader_v);

    shader_f := make_shader(F_HEADER, code, GL_FRAGMENT_SHADER); 
    defer glDeleteShader(shader_v);

    program := glCreateProgram();
    glUseProgram(program);
    glAttachShader(program, shader_v);
    glAttachShader(program, shader_f);
    glLinkProgram(program);
    success : GLint;
    glGetProgramiv(program, GL_LINK_STATUS, *success);
    if !success {
        log_data: [512] u8;
        glGetProgramInfoLog(program, log_data.count, null, log_data.data);
        log("%", to_string(log_data.data), flags=.ERROR);
        assert(false);
        return 0;
    }

    return program;
}

color_shader_code :: #string __GLSL 

IN_OUT vec4 out_color;

#ifdef VERTEX_SHADER
layout (location = 0) in vec4 vert_pos;
layout (location = 1) in vec4 vert_color;
uniform mat4 projection;
    
void main() {
    gl_Position = projection * vec4(vert_pos.xy, 0.0, 1.0);
    out_color = vert_color;
}

#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER 
out vec4 color;

void main() {
    color = out_color;
}
#endif // FRAGMENT_SHADER
__GLSL;

texture_shader_code :: #string __GLSL
IN_OUT vec4 out_color;
IN_OUT vec2 out_uv;

#ifdef VERTEX_SHADER
layout (location = 0) in vec4 vert_pos;
layout (location = 1) in vec4 vert_color;
layout (location = 2) in vec2 vert_uv;
uniform mat4 projection;
    
void main() {
    gl_Position = projection * vec4(vert_pos.xy, 0.0, 1.0);
    out_color = vert_color;
    out_uv = vert_uv * vec2(1, -1); 
}

#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER 
out vec4 color;

uniform sampler2D diffuse_texture;

void main() {
    color = out_color * texture(diffuse_texture, out_uv);
}
#endif // FRAGMENT_SHADER
__GLSL;
