object_create(
    "obj_rain_droplet",
    undefined,
    {
        sprite_index: spr_rain_splash,
        create: function() {
            x = irandom_range(CAMERA.cam_pos.x, CAMERA.right());
            y = irandom_range(CAMERA.cam_pos.y, CAMERA.bottom());
            depth = floor(-y);
        },
        animation_end: function() {
            x = irandom_range(CAMERA.cam_pos.x, CAMERA.right());
            y = irandom_range(CAMERA.cam_pos.y, CAMERA.bottom());
            depth = floor(-y);
        },
    }
);
