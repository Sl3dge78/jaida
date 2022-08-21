
tree := Dialog.Node.[
    Dialog.Node.{lines = .["Hello, I'm a chest!","And this is a second line!", "How many lines can you fit here?"], jumps = .[1]},
    Dialog.Node.{has_title = true, lines = .["Chest", "Hey I have a title now!"], jumps = .[2] },
    Dialog.Node.{has_title = true, lines = .["Chest", "Go back to the start?", "Yes", "No"], jumps = .[0, -1]},
];

player_get_weapon_dialog := Dialog.Node.[
    Dialog.Node.{lines = .["You found a sword!"], jumps = .[-1]}
];

player_get_weapon :: (e: *Entity, player: *Player) {
   player.can_attack = true;
   Dialog.open(player_get_weapon_dialog);

   // Remove interaction and open the chest
   e.flags = e.flags & ~.INTERACTABLE;
   x, y := tile_id_to_xy(*context.game.map_texture, 2679);
   e.sprite.x = xx x;
   e.sprite.y = xx y;
}

// Restaurant npcs
dialog_restaurant_1 := #run create_dialog("I love eating here.");

// Utils

/// Create a single line dialog
create_dialog :: (text : string) -> []Dialog.Node {
    node : Dialog.Node = .{lines = .[""], jumps = .[-1]};
    node.lines[0] = text;

    result : [1]Dialog.Node;
    result[0] = node;

    return result;
}