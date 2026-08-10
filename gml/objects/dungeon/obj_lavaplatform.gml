object_create(
    "obj_lavaplatform",
    undefined,
    {
        sprite_index: spr_dungeon_mines_platform_lava_creating,
        create: function() {
            self.depth = get_floor_depth();
        },
        animation_end: function() {
            if(sprite_index == spr_dungeon_mines_platform_lava_creating) {
                sprite_index = spr_dungeon_mines_platform_lava_idle;
            }

            self.mask_index = spr_dungeon_mines_platform_lava_idle;
        },
    }
);
