object_create(
    "obj_node_renderer_top",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            depth = get_instance_depth(y);
            interacting = false;
        },
        draw: function() {
            if self.interacting {
                gpu_set_extra(UberShaderKind.Overlay);
                draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, 0, image_blend, image_alpha);
                gpu_reset_extra();

                self.interacting = false;
                image_blend = c_white;
                image_alpha = 1.0;
            } else {
                draw_self();
            }
        },
    }
);
