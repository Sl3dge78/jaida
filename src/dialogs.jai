
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
dialog_restaurant_2 := #run create_dialog("Too bad they only serve noodles.");

dialog_dojo_master_1 := Dialog.Node.[
    .{has_title = true, lines = .["Sensei", "I can't believe you lost your sword", "in the forest east of the village", "last night."], jumps = .[1]},
    .{has_title = true, lines = .["Sensei", "Go get it before I get mad!"], jumps = .[-1]},
];

dialog_chief_1 := Dialog.Node.[
    .{has_title = true, lines = .["Chief", "Hello there.", "Are you ready for training?"], jumps = .[1]},
    .{has_title = true, lines = .["Chief", "The dojo master seemed pretty mad", "at the meeting this morning."], jumps = .[-1]},
];

dialog_father_1 := Dialog.Node.[
    .{has_title = true, lines = .["Father", "Sleep well?", "Yes", "No"], jumps = .[1, 3]},
    .{has_title = true, lines = .["Father", "Well I didn't."], jumps = .[2]},
    .{has_title = true, lines = .["Father", "You were home late and made a lot", "of noise."], jumps = .[4]},
    .{has_title = true, lines = .["Father", "It's no surprise when you come home so late."], jumps = .[4]},
    .{has_title = true, lines = .["Father", "Anyway."], jumps = .[5]},
    .{has_title = true, lines = .["Father", "The Dojo Master was pretty mad", "at the meeting this morning.","You should go and see him."], jumps = .[-1]},
]; 
// Utils

/// Create a single line dialog
create_dialog :: (text : string) -> [..]Dialog.Node {
    node : Dialog.Node = .{lines = .[""], jumps = .[-1]};
    node.lines[0] = text;

    result : [..]Dialog.Node;
    Basic.array_add(*result, node);

    return result;
}

dialog_push_line :: (dialog: *[..]Dialog.Node, text : string) {
    node : Dialog.Node = .{lines = .[""], jumps = .[-1]};
    node.lines[0] = text;
    (<<dialog)[dialog.count - 1].jumps[0] = 1;
    Basic.array_add(dialog, node);
}