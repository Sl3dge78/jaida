chief_on_interact :: (self: *Entity, player: *Player) {
    dialog : []Dialog.Node;
    if context.game.main_quest_state == {
        case .START; dialog = dialog_chief_1;
        case .TRAINING_OK; dialog = dialog_chief_2;
        case; dialog = dialog_chief_3;
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
        case; dialog = dialog_dojo_master_4;
    }
    Dialog.open(dialog);
}