object_create(
    "obj_bird_landing_position",
    undefined,
    {
        sprite_index: spr_pixel,
        visible: false,
        create: function() {
            occupied = undefined;
            spook_bird = false;

            var offset = image_yscale;
            if offset == 1 {
                offset = 0;
            }
            y += offset;
            shadow_offset = -offset;
        },
    }
);
