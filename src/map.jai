
MAP_WIDTH :: 40;
MAP_HEIGHT :: 22;
MAP_LAYERS :: 4; // 3 Sprite layers, 1 collision layer
COLLISION_LAYER :: 3;

Map_Type :: [MAP_LAYERS][MAP_WIDTH*MAP_HEIGHT]u32;

Map :: struct {
    tiles : Map_Type;

    draw_layer :: (layer : u32, using map : Map, texture : *Simp.Texture, cam : Vector2) {
        Simp.set_shader_for_images(texture);
        y := 0;
        for tiles[layer] {
            map_coord := xy(cast(float32)(it_index % MAP_WIDTH), cast(float32)(it_index / MAP_WIDTH));
            x0, y0 := Map.map_to_screen(cam, map_coord + Vector2.{-0.5, -0.5});
            x1, y1 := Map.map_to_screen(cam, map_coord + Vector2.{0.5, 0.5});

            uv0, uv1 := get_uv_from_texture(texture, it); 

            Simp.immediate_quad(
                p0 = make_vector2(xx x0, xx y0),
                p1 = make_vector2(xx x1, xx y0),
                p2 = make_vector2(xx x1, xx y1),
                p3 = make_vector2(xx x0, xx y1),
                uv0 = uv0, uv1 = make_vector2(uv1.x, uv0.y), uv2 = uv1, uv3 = make_vector2(uv0.x, uv1.y));
        }
    }

    set_tile :: (using map : Map, tile : Vector2, layer : u32, value : u32) {
        if tile.x < MAP_WIDTH && tile.y < MAP_HEIGHT && tile.x >= 0 && tile.y >= 0 {
            tiles[layer][cast(int)tile.x + cast(int)tile.y * MAP_WIDTH] = value;
        }
    }

    // Allocates a temporary string
    get_map_file_name :: (world_pos : Vector2i) -> string {
        pos_fmt := Basic.tprint("res/maps/%_%.map", cast(int)world_pos.x, cast(int)world_pos.y);
        return pos_fmt;
    }

    save :: (using map : Map, world_pos : Vector2i) {
        Basic.log("world_pos: % %", world_pos, get_map_file_name(world_pos));
        if !File.write_entire_file(get_map_file_name(world_pos), tiles.data, MAP_LAYERS * MAP_WIDTH * MAP_HEIGHT * size_of(type_of(tiles[0][0]))){
            Basic.log_error("Unable to save map!");
        }
        Basic.log("Saved!");
    }

    load :: (using map : Map, world_pos : Vector2i) -> bool {
        map_file, success := File.file_open(get_map_file_name(world_pos));
        if !success {
            Basic.log_error("Unable to open map file!");
            return false;
        }
        defer File.file_close(*map_file);
        File.file_read(*map_file, tiles.data, MAP_LAYERS * MAP_WIDTH * MAP_HEIGHT * size_of(type_of(tiles[0][0])));
        Basic.log("Loaded map at %.", world_pos);
        return true;
    }

    // @Speed : This is dumb
    exists :: (world_pos : Vector2i) -> bool {
        map_file, success := File.file_open(get_map_file_name(world_pos));
        if success then File.file_close(*map_file);
        return success;
    }

    // @Debug : Bounds check?
    get_collision_at :: (using map : Map, pos : Vector2) -> u32 {
        x : int = xx round(pos.x);
        if x < 0 || x >= MAP_WIDTH  then return 1;
        y : int = xx round(pos.y);
        if y < 0 || y >= MAP_HEIGHT then return 1;

        return map.tiles[COLLISION_LAYER][x + y * MAP_WIDTH];
    }

    map_to_screen :: inline (cam : Vector2, pos : Vector2) -> x : int, y : int {
        x : int = xx ((pos.x + cam.x) * TILE_SIZE * ZOOM);
        y : int = xx ((pos.y + cam.y) * TILE_SIZE * ZOOM);
        return x, y;
    }
    
    screen_to_map :: inline (cam : Vector2, x : int, y : int) -> Vector2 {
        result := xy(xx x, xx y);
        result /= cast(float32)(TILE_SIZE * ZOOM);
        result -= cam;
        result += Vector2.{0.5, 0.5};
        return result;
    }
}
