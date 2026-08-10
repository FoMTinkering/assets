object_create(
    "obj_dungeon_ladder_up",
    object_reserve("par_ladder"),
    {
        sprite_index: spr_main_dungeon_prototype_instance_door_ladder_up,
        state: LadderState.Spawned,
    }
);
