
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
