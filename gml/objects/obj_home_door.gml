object_create(
    "obj_home_door",
    undefined,
    {
        sprite_index: spr_carpenter_house_f2_doorway2_spring,
        create: function() {
            depth = get_instance_depth(y) + 1;
        },
    }
);
