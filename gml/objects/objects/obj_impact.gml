object_create(
    "obj_impact",
    undefined,
    {
        sprite_index: undefined,
        create: function() {

        },
        animation_end: function() {
            instance_destroy();
        },
    }
);
