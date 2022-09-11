
MAP_WIDTH :: 40;
MAP_HEIGHT :: 22;
MAP_LAYERS :: 4; // 3 Sprite layers, 1 collision layer
COLLISION_LAYER :: 3;

TOWN_SOUTH :: Vector2i.{0, 0};
TOWN_NORTH :: Vector2i.{0, 1};
FOREST_1 :: Vector2i.{1, 0};
MINIBOSS :: Vector2i.{0, 2};
CASTLE_ENTRANCE :: Vector2i.{1,2};
HOME :: Vector2i.{-1, 0};
CHIEFS_HOUSE :: Vector2i.{-2, 0};
DOJO :: Vector2i.{-3, 0};
HOUSE_1 :: Vector2i.{-4, 0};
RESTAURANT :: Vector2i.{-5, 0};
DUNGEON :: Vector2i.{2, 2};

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

    // Kinda dumb, but i'm to lazy to have entities load from a file
    load_entities :: (map_pos : Vector2i) {
        if map_pos == HOME { // Interior
            create_teleporter(.{14, 8}, .{12, 15.4}, TOWN_SOUTH);
            create_teleporter(.{15, 8}, .{12, 15.4}, TOWN_SOUTH);
            father := create_npc(.{21, 12}, Direction.SOUTH, *context.game.old_woman_texture);
            father.on_interact = father_interact;
        } else if map_pos == DOJO { 
            create_teleporter(.{17, 7}, .{11.5, 5.4}, TOWN_SOUTH);
            create_teleporter(.{18, 7}, .{11.5, 5.4}, TOWN_SOUTH);
            sensei := create_npc(.{19, 11}, Direction.SOUTH, *context.game.blue_samurai_texture);
            sensei.on_interact = sensei_on_interact;

            dummy := cast(*Enemy)Game.new_entity(Enemy);
            dummy.flags |= .SOLID;
            dummy.tag = .ENEMY;
            dummy.type = .STATIC;
            dummy.hit_tag = .ENEMY;
            dummy.health = 2;
            dummy.position = .{15, 12};
            dummy.sprite_sheet = *context.game.map_texture;
            dummy.on_death = dummy_death;
            x, y := tile_id_to_xy(*context.game.map_texture, 2622);
            dummy.sprite.x = xx x;
            dummy.sprite.y = xx y;
        } else if map_pos == CHIEFS_HOUSE { 
            create_teleporter(.{17, 8}, .{4, 12.4}, TOWN_SOUTH);
            create_teleporter(.{18, 8}, .{4, 12.4}, TOWN_SOUTH);
            chief := create_npc(.{17, 11}, Direction.SOUTH, *context.game.old_woman_texture);
            chief.on_interact = chief_on_interact;
        } else if map_pos == RESTAURANT { 
            create_teleporter(.{17, 8}, .{29, 15.4}, TOWN_SOUTH);
            create_teleporter(.{18, 8}, .{29, 15.4}, TOWN_SOUTH);
            create_dialog_npc(.{14, 9}, Direction.NORTH, *context.game.old_woman_texture, dialog_restaurant_1);
            create_dialog_npc(.{19, 11}, Direction.SOUTH, *context.game.old_woman_texture, dialog_restaurant_2);
        } else if map_pos == HOUSE_1 { 
            create_teleporter(.{17, 8}, .{22, 17.4}, TOWN_SOUTH);
            create_teleporter(.{18, 8}, .{22, 17.4}, TOWN_SOUTH);
        } else if map_pos == TOWN_SOUTH { // Town South
            create_teleporter(.{12, 16}, .{14.5, 8.5}, HOME); 
            create_teleporter(.{4, 13}, .{17.5, 8.5}, CHIEFS_HOUSE); 
            create_teleporter(.{11, 6}, .{17.5, 7.5}, DOJO); 
            create_teleporter(.{12, 6}, .{17.5, 7.5}, DOJO); 
            create_teleporter(.{22, 18}, .{17.5, 8.5}, HOUSE_1); 
            create_teleporter(.{29, 16}, .{17.5, 8.5}, RESTAURANT); // Restaurant
        } else if map_pos == TOWN_NORTH { // Town North
            create_bush(.{18, 14});
            create_bush(.{18, 8});
            create_bush(.{16, 8});
            create_bush(.{14, 8});
        } else if map_pos == .{1, 1} { // FOREST NORTH
            create_bush(.{5, 11});
            create_bush(.{5, 10});

            chest := Game.new_entity(Entity);
            chest.flags |= .SOLID;
            chest.flags |= .NO_SHADOW;
            chest.sprite_sheet = *context.game.map_texture;
            chest.position = .{21, 15};
            if (context.game.main_quest_state < .SWORD_OK) {
                chest.on_interact = player_get_weapon;
                x, y := tile_id_to_xy(*context.game.map_texture, 2611);
                chest.sprite.x = xx x;
                chest.sprite.y = xx y;
            } else {
                x, y := tile_id_to_xy(*context.game.map_texture, 2679);
                chest.sprite.x = xx x;
                chest.sprite.y = xx y;
            }
        } else if map_pos == FOREST_1 { 
            mush := create_enemy(.{10, 12}, *context.game.mushroom_texture, .FOLLOW);
            mush.patrol.points = .[.{10, 12}, .{20, 12}];
            mush.patrol.wait_time = 1.0;

            mush2 := create_enemy(.{17, 3}, *context.game.mushroom_texture, .FOLLOW);
            mush2.patrol.points = .[.{17, 3}, .{6, 3}];
            mush2.patrol.wait_time = 1.0;

            mush3 := create_enemy(.{21, 13}, *context.game.mushroom_texture, .FOLLOW);
            mush3.patrol.points = .[.{21, 13}, .{21, 3}];
            mush3.patrol.wait_time = .5;

            mush4 := create_enemy(.{30, 10}, *context.game.mushroom_texture, .FOLLOW);
            mush4.patrol.points = .[.{30, 10}, .{35, 10}, .{36, 4}, .{30, 4}];

            snake := create_enemy(.{14, 18}, *context.game.snake_texture, .FOLLOW);
            snake.health = 8;
            snake.damage = 2;
            snake.deaggro_dist = 6;
        } else if map_pos == MINIBOSS {
            if context.game.main_quest_state < .KEY_GOT {
                miniboss := create_enemy(.{17, 10}, *context.game.red_samurai_texture, .HUMANOID);
                miniboss.on_death = (e : *Entity) {
                    create_key(e.position);
                    Entity.generic_death(e);
                };
            }
        } else if map_pos == CASTLE_ENTRANCE {
            create_teleporter(.{33, 14}, .{19, 7.5}, DUNGEON); 

            if context.game.main_quest_state < .DOOR_OPEN {
                door := create_door(.{28, 5});
                door.tiles[0] = create_door_part(3448, .{27, 6});
                door.tiles[1] = create_door_part(3449, .{28, 6});
                door.tiles[2] = create_door_part(3450, .{29, 6});
                door.tiles[3] = create_door_part(3384, .{27, 5});
                door.tiles[4] = create_door_part(3385, .{28, 5});
                door.tiles[5] = create_door_part(3386, .{29, 5});
            } else {
                create_door_part(3640, .{27, 6}, false);
                create_door_part(3641, .{28, 6}, false);
                create_door_part(3642, .{29, 6}, false);
                create_door_part(3576, .{27, 5}, false);
                create_door_part(3577, .{28, 5}, false);
                create_door_part(3578, .{29, 5}, false);
            }
        } else if map_pos == DUNGEON {

            Game.set_spawn(CASTLE_ENTRANCE, .{33, 13});

            create_teleporter(.{18, 6}, .{33, 13.4}, CASTLE_ENTRANCE); 
            create_teleporter(.{19, 6}, .{33, 13.4}, CASTLE_ENTRANCE); 
            create_teleporter(.{20, 6}, .{33, 13.4}, CASTLE_ENTRANCE); 

            boss := Game.new_entity(Boss); 
            boss.hit_tag = .ENEMY;
            boss.position = .{19, 12};
            boss.sprite_sheet = *context.game.red_samurai_texture;
            if context.game.main_quest_state == .BOSS_KILLED {
                Boss.reset_boss(boss);
            } else {
                Dialog.open(boss_dialog_before_fight);
                boss.door[0] = create_door_part(1970, .{18, 6});
                boss.door[1] = create_door_part(1971, .{19, 6});
                boss.door[2] = create_door_part(1972, .{20, 6});
            }
        }
    }
}
