object_create(
    "obj_sticky_patch",
    undefined,
    {
        sprite_index: spr_monster_sapling_blue_goo_spring,
        mask_index: string_to_asset("spr_sticky_patch"),
        create: function() {
            self.depth = get_shadow_depth() + 1 + (real(self.id) % 32);
            self.has_granted_speedup = false;

            self.slow = 0.33;
        },
        step: function() {
            self.timer -= 1;
            self.depth += FRAME_TIME;

            if self.timer <= 0 {
                self.image_alpha -= 0.05;
                if self.image_alpha <= 0 {
                    instance_destroy(self);
                }
            }
        },
        animation_end: function() {
            image_index = image_number - 1;
        },
    }
);
