chief_on_interact :: (self: *Entity, player: *Player) {
    dialog : []Dialog.Node;
    if context.game.main_quest_state == {
        case .START; #through;
        case .SWORD_OK; dialog = dialog_chief_1;
        case .TRAINING_OK; { 
            dialog = dialog_chief_start_quest;
            context.game.main_quest_state = .QUEST_ACCEPTED;
        }
        case .BOSS_KILLED; {
            dialog = dialog_chief_end;
        }
        case; dialog = dialog_chief_good_luck;
    }
    Dialog.open(dialog);
}

sensei_on_interact :: (self: *Entity, player: *Player) {
    dialog : []Dialog.Node;
    if context.game.main_quest_state == {
        case .START; dialog = dialog_dojo_master_1;
        case .SWORD_OK; dialog = dialog_dojo_master_2;
        case .TRAINING_OK; dialog = dialog_dojo_master_3;
        case .BOSS_KILLED;  dialog = dialog_dojo_master_complete;
        case; dialog = dialog_dojo_master_good_luck;
    }
    Dialog.open(dialog);
}

dummy_death :: (self: *Entity) {
    x, y := tile_id_to_xy(*context.game.map_texture, 3056);
    self.sprite.x = xx x;
    self.sprite.y = xx y;
    self.on_death = null;
    self.hit_tag = .NONE;
    if context.game.main_quest_state == .SWORD_OK then context.game.main_quest_state = .TRAINING_OK;
}

father_interact :: (self: *Entity, player: *Player) {
    player.health = 4;
     if context.game.main_quest_state == { 
        case .START; {
            Dialog.open(dialog_father_1);
        }
        case .BOSS_KILLED; {
            Dialog.open(dialog_father_end);
        }
        case; {
            Dialog.open(dialog_father_good_luck);
        }
    }
}