
MAP_WIDTH :: 40;
MAP_HEIGHT :: 22;
MAP_LAYERS :: 4; // 3 Sprite layers, 1 collision layer
COLLISION_LAYER :: 3;

Map_Type :: [MAP_LAYERS][MAP_WIDTH*MAP_HEIGHT]u32;

Map :: struct {
    tiles : Map_Type;

    draw_layer :: (layer : u32, using map : Map, texture : *Renderer.Texture, cam : Vector2) {
        Renderer.set_shader_for_images(texture);
        y := 0;
        for tiles[layer] {
            map_coord := xy(cast(float32)(it_index % MAP_WIDTH), cast(float32)(it_index / MAP_WIDTH));
            x0, y0 := world_to_screen(cam, map_coord + Vector2.{-0.5, -0.5});
            x1, y1 := world_to_screen(cam, map_coord + Vector2.{0.5, 0.5});

            uv0, uv1 := get_uv_from_texture(texture, it); 

            Renderer.immediate_quad(
                x0 = xx x0, y0 = xx y0, 
                x1 = xx x1, y1 = xx y1,
                uv0 = uv0, uv1 = uv1);
        }
    }

    set_tile :: (using map : Map, tile : Vector2, layer : u32, value : u32) {
        if tile.x < MAP_WIDTH && tile.y < MAP_HEIGHT && tile.x >= 0 && tile.y >= 0 {
            tiles[layer][cast(int)tile.x + cast(int)tile.y * MAP_WIDTH] = value;
        }
    }

    save :: (using map : Map) {
        if !File.write_entire_file("map.bin", tiles.data, MAP_LAYERS * MAP_WIDTH * MAP_HEIGHT * size_of(type_of(tiles[0][0]))){
            Basic.log_error("Unable to save map!");
        }
        Basic.log("Saved!");
    }

    load :: (using map : Map) {
        map_file, success := File.file_open("map.bin");
        if !success {
            Basic.log_error("Unable to open map file!");
            return;
        }
        defer File.file_close(*map_file);
        File.file_read(*map_file, tiles.data, MAP_LAYERS * MAP_WIDTH * MAP_HEIGHT * size_of(type_of(tiles[0][0])));
        Basic.log("Loaded!");
    }

    // @Debug : Bounds check?
    get_collision_at :: (using map : Map, pos : Vector2) -> u32 {
        x : int = xx round(pos.x);
        if x < 0 || x > MAP_WIDTH  then return 1;
        y : int = xx round(pos.y);
        if y < 0 || y > MAP_HEIGHT then return 1;
        return map.tiles[COLLISION_LAYER][x + y * MAP_WIDTH];
    }
}
