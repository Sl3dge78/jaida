
xy_to_tile_id :: inline (texture : *Simp.Texture, x : u32, y : u32) -> tile_id : u32 {
    nb_tiles_width := texture.width / TILE_SIZE;
    return xx x + y * xx nb_tiles_width;
}

tile_id_to_xy :: inline (texture : *Simp.Texture, tile_id : u32) -> x : u32 , y : u32 {
    nb_tiles_width : u32 = cast(u32)texture.width / TILE_SIZE;
    tile_x := tile_id % nb_tiles_width;
    tile_y := tile_id / nb_tiles_width;
    return tile_x, tile_y;
}

get_uv_from_texture :: (texture : *Simp.Texture, tile : Vector2i) -> uv0 : Vector2, uv1 : Vector2 {
    nb_tiles_width := texture.width / TILE_SIZE;
    nb_tiles_height := texture.height / TILE_SIZE;

    uv0 := Math.xy(cast(float)tile.x / cast(float)nb_tiles_width, cast(float)tile.y / cast(float)nb_tiles_height);
    uv1 := Math.xy(cast(float)(tile.x+1) / cast(float)nb_tiles_width, cast(float)(tile.y+1) / cast(float)nb_tiles_height);
    return uv0, uv1;
}

get_uv_from_texture :: (texture : *Simp.Texture, tile_x : int, tile_y : int) -> uv0 : Vector2, uv1 : Vector2 {
    nb_tiles_width := texture.width / TILE_SIZE;
    nb_tiles_height := texture.height / TILE_SIZE;

    uv0 := Math.xy(cast(float)tile_x / cast(float)nb_tiles_width, cast(float)tile_y / cast(float)nb_tiles_height);
    uv1 := Math.xy(cast(float)(tile_x+1) / cast(float)nb_tiles_width, cast(float)(tile_y+1) / cast(float)nb_tiles_height);
    return uv0, uv1;
}

get_uv_from_texture :: (texture : *Simp.Texture, tile : u32) -> uv0 : Vector2, uv1 : Vector2 {
    nb_tiles_width : u32 = cast(u32)(texture.width) / TILE_SIZE;
    nb_tiles_height : u32 = cast(u32)(texture.height) / TILE_SIZE;
    tile_x, tile_y := tile_id_to_xy(texture, tile);

    uv0 := Math.xy(cast(float)tile_x / cast(float)nb_tiles_width, cast(float)tile_y / cast(float)nb_tiles_height);
    uv1 := Math.xy(cast(float)(tile_x+1) / cast(float)nb_tiles_width, cast(float)(tile_y + 1) / cast(float)nb_tiles_height);
    return uv0, uv1;
}
