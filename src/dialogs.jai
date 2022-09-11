// Utils

/// Create a single line dialog
create_dialog :: (text : string) -> [..]Dialog.Node {
    node : Dialog.Node = .{text = .[""], choices = .[.{"", -1}]};
    node.text[0] = text;

    result : [..]Dialog.Node;
    Basic.array_add(*result, node);

    return result;
}

dialog_push_line :: (dialog: *[..]Dialog.Node, text : string) {
    node : Dialog.Node = .{text = .[""], choices = .[.{"", -1}]};
    node.text[0] = text;
    (<<dialog)[dialog.count - 1].choices[0] = .{"", 1};
    Basic.array_add(dialog, node);
}

// Example
tree := Dialog.Node.[
    Dialog.Node.{text = .["Hello, I'm a chest!","And this is a second line!", "How many lines can you fit here?"], choices = .[.{"", 1}]},
    Dialog.Node.{text = .["Chest", "Hey I have a title now!"], choices = .[.{"", 2}] },
    Dialog.Node.{text = .["Chest", "Go back to the start?", "Yes", "No"], choices = .[.{"", 0}, .{"", -1}]},
];

player_get_weapon_dialog := Dialog.Node.[
    Dialog.Node.{text = .["You found a sword!"], choices = .[.{"", -1}]}
];

player_get_weapon :: (e: *Entity, player: *Player) {
   player.can_attack = true;
   Dialog.open(player_get_weapon_dialog);

   // Remove interaction and open the chest
   e.on_interact = null;
   x, y := tile_id_to_xy(*context.game.map_texture, 2679);
   e.sprite.x = xx x;
   e.sprite.y = xx y;

   context.game.main_quest_state = .SWORD_OK;
}

// Dojo master
dialog_dojo_master_1 := Dialog.Node.[
    .{title = "Sensei", text = .["I can't believe you lost your sword", "in the forest east of the village", "last night."], choices = .[.{"", 1}]},
    .{title = "Sensei", text = .["Go get it before I get mad!"], choices = .[.{"", -1}]},
];

dialog_dojo_master_2 := Dialog.Node.[
    .{title = "Sensei", text = .["Good. You found your sword.", "Let's see if you still know how", "to use it."], choices = .[.{"", 1}]},
    .{title = "Sensei", text = .["Hit the dummy using what", "I taught you."], choices = .[.{"", -1}]},
];

dialog_dojo_master_3 := Dialog.Node.[
    .{title = "Sensei", text = .["That will do."], choices = .[.{"", 1}]},
    .{title = "Sensei", text = .["Go and see the chief.", "She has something to tell you."], choices = .[.{"", -1}]},
];

dialog_dojo_master_good_luck := Dialog.Node.[
    .{title = "Sensei", text = .["Good luck."], choices = .[.{"", -1}]},
];

dialog_dojo_master_complete := Dialog.Node.[
    .{title = "Sensei", text = .["You've done it, well done!", "I'm proud to be your Sensei."], choices = .[.{"", 1}]},
    .{title = "Sensei", text = .["Even though you're late to", "most training sessions..."], choices = .[.{"", -1}]},
];

// Chief
dialog_chief_1 := Dialog.Node.[
    .{title = "Chief", text = .["Hello there.", "Have you done your daily training?"], choices = .[.{"", 1}]},
    .{title = "Chief", text = .["The dojo master seemed pretty mad", "at the meeting this morning."], choices = .[.{"", -1}]},
];

dialog_chief_start_quest := Dialog.Node.[
    .{title = "Chief", text = .["You've done your training?"], choices = .[.{"", 1}]},
    .{title = "Chief", text = .["Good."], choices = .[.{"", 2}]},
    .{title = "Chief", text = .["Listen. All of us at the village,", "we've lost trust in you."], choices = .[.{"", 3}]},
    .{title = "Chief", text = .["You're always late, always partying", "with your friends..."], choices = .[.{"", 4}]},
    .{title = "Chief", text = .["We're really worried that you", "don't have what it takes."], choices = .[.{"", 5}]},
    .{title = "Chief", text = .["So we've setup a test for you."], choices = .[.{"", 6}]},
    .{title = "Chief", text = .["Go to the dungeon to the north-east,", "and kill the boss."], choices = .[.{"", 7}]},
    .{title = "Chief", text = .["If you can do this, it'll prove to", "everyone that you can still", "be useful."], choices = .[.{"", 8}]},
    .{title = "Chief", text = .["And I hope that in the process", "you'll understand how fun it can be."], choices = .[.{"", -1}]},
];

dialog_chief_good_luck := Dialog.Node.[
    .{title = "Chief", text = .["Good luck."], choices = .[.{"", -1}]},
];

dialog_chief_end := Dialog.Node.[
    .{title = "Chief", text = .["You did it."], choices = .[.{"", 1}]},
    .{title = "Chief", text = .["You killed the boss."], choices = .[.{"", -1}]},
    .{title = "Chief", text = .["Well done", "Please feel free to enjoy yourself"], choices = .[.{"", -1}]},
];

// Father
dialog_father_1 := Dialog.Node.[
    .{title = "Father", text = .["Sleep well?"], choices = .[.{"Yes", 1}, .{"No", 3}]},
    .{title = "Father", text = .["Well I didn't."], choices = .[.{"", 2}]},
    .{title = "Father", text = .["You were home late and made a lot", "of noise."], choices = .[.{"", 4}]},
    .{title = "Father", text = .["It's no surprise when you come", "home so late."], choices = .[.{"", 4}]},
    .{title = "Father", text = .["Anyway."], choices = .[.{"", 5}]},
    .{title = "Father", text = .["The Dojo Master was pretty mad", "at the meeting this morning.","You should go and see him."], choices = .[.{"", -1}]},
]; 

dialog_father_good_luck := Dialog.Node.[
    .{title = "Father", text = .["Let me heal you."], choices = .[.{"", 1}]}, 
    .{title = "Father", text = .["Good luck on your quest."], choices = .[.{"", -1}]},
]; 

dialog_father_end := Dialog.Node.[
    .{title = "Father", text = .["The chief told me the news."], choices = .[.{"", 1}]},
    .{title = "Father", text = .["Well done. I'm proud to be your", "father."], choices = .[.{"", -1}]},
]; 

// Restaurant npcs
dialog_restaurant_1 := #run create_dialog("I love eating here.");
dialog_restaurant_2 := #run create_dialog("Too bad they only serve noodles.");


no_key_dialog := Dialog.Node.[
    Dialog.Node.{text = .["You need a key to open this door."], choices = .[.{"", -1}]}
    ];

// Boss
boss_dialog_before_fight := Dialog.Node.[
    .{title = "Boss", text = .["You've made it."], choices = .[.{"", 1}]},
    .{title = "Boss", text = .["Now fight!"], choices = .[.{"", -1}]},
];

boss_dialog_after_fight := Dialog.Node.[
    .{title = "Boss", text = .["Well done."], choices = .[.{"", 1}]},
    .{title = "Boss", text = .["I'll tell the news to the sensei."], choices = .[.{"", 2}]},
    .{title = "Boss", text = .["You are not so bad after all."], choices = .[.{"", -1}]},
];

boss_dialog_repeat := Dialog.Node.[
    .{title = "Boss", text = .["That was a good fight."], choices = .[.{"", 1}]},
    .{title = "Boss", text = .["I'll tell the news to the sensei."], choices = .[.{"", -1}]},
];
