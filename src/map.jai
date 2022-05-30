
MAP_WIDTH :: 40;
MAP_HEIGHT :: 22;
MAP_LAYERS :: 3;

Map_Type :: [MAP_LAYERS][MAP_WIDTH*MAP_HEIGHT]u32;

Map :: struct {
    tiles : Map_Type;

    // @Cleanup : rename this
    get_tile_from_pixel :: inline (x : int, y : int) -> x: int, y: int {
        return x / (TILE_SIZE * ZOOM), y / (TILE_SIZE * ZOOM);
    }

    draw :: (using map : Map, texture : *Renderer.Texture, cam : Vector2) {
        Renderer.set_shader_for_images(texture);
        y := 0;
        for layer : tiles {
            for tiles[0] {
                x := it_index % MAP_WIDTH;
                y := it_index / MAP_WIDTH;
                x0 := xy(xx (x * TILE_SIZE * ZOOM) + cam.x, xx (y * TILE_SIZE * ZOOM) + cam.y); 
                x1 := xy(x0.x + TILE_SIZE * ZOOM, x0.y + TILE_SIZE * ZOOM);

                uv0, uv1 := get_uv_from_texture(texture, it); 

                Renderer.immediate_quad(
                    x0 = x0.x, y0 = x0.y, 
                    x1 = x1.x, y1 = x1.y,
                    uv0 = uv0, uv1 = uv1);
            }
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
}
