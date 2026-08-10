object_create(
    "obj_lightning",
    undefined,
    {
        sprite_index: spr_lightning,
        create: function() {

            pwr = 0;
            timer_max = 10;
            timer = timer_max;
        },
        step: function() {

            --timer;
            if (timer == 0) instance_destroy();
        },
        draw: function() {
            gpu_set_blendmode_ext(bm_src_alpha, bm_one);
            draw_sprite_ext(sprite_index, 0, x, y, 1, 1, 0, c_white, random_range(0.85, 1));
            gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);
        },
    }
);
