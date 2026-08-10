object_create(
    "obj_furniture_previewer",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            z = 0;
            top_sprite = undefined;
            bottom_sprite = undefined;
            secondary_sprite = undefined;
            on_floor = false;
            is_success = true;
        },
        draw: function() {
            if self.sprite_index == undefined {
                return;
            }

            var c = c_white;
            if self.is_success == false {
                c = make_color_rgb(255, 155, 155);
            }

            var do_pre_multiply = self.top_sprite != undefined || self.bottom_sprite != undefined;

            if do_pre_multiply {
                gpu_set_extra(UberShaderKind.Premultiply);
                gpu_set_blendmode_ext(bm_one, bm_inv_src_alpha);
            }

            if self.bottom_sprite != undefined {
                draw_sprite_ext(self.bottom_sprite, 0, x, y, image_xscale, 1, 0, c, 0.75);
            }

            draw_sprite_ext(self.sprite_index, self.image_index, x, y, image_xscale, 1, 0, c, 0.75);

            if self.top_sprite != undefined {
                draw_sprite_ext(self.top_sprite, 0, x, y, image_xscale, 1, 0, c, 0.75);
            }

            if self.secondary_sprite != undefined {
                draw_sprite_ext(self.secondary_sprite, 0, x, y, image_xscale, 1, 0, c, 0.75);
            }

            if do_pre_multiply {
                gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);
                gpu_reset_extra();
            }

            sprite_index = undefined;
            self.top_sprite = undefined;
            self.bottom_sprite = undefined;
            self.secondary_sprite = undefined;
            self.on_floor = false;
        },
    }
);
