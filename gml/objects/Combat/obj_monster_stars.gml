object_create(
    "obj_monster_stars",
    undefined,
    {
        sprite_index: spr_fx_monster_stars,
        create: function() {
            //
            self.image_alpha = 0;
            self.state = StarsState.FadeIn;
            self.depth = get_instance_depth(y, z);
        },
        step: function() {
            switch self.state {
                case StarsState.FadeIn:
                    self.image_alpha += 0.1;
                    if self.image_alpha >= 1 {
                        self.state = StarsState.Normal;
                    }
                    break;
                case StarsState.Normal:
                    self.image_alpha = 1;
                    break;
                case StarsState.FadeOut:
                    self.image_alpha -= 0.1;

                    if self.image_alpha <= 0 {
                        instance_destroy(self);
                    }
                    break;
            }
        },
        draw: function() {
            draw_sprite_ext(self.sprite_index, self.image_index, x, y + z, 1, 1, 0, image_blend, image_alpha);
        },
    }
);
