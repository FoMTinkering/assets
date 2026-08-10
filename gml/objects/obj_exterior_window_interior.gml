object_create(
    "obj_exterior_window_interior",
    undefined,
    {
        sprite_index: spr_arrow_up,
        create: function() {
            depth = room_data_layer_depth(room(), "Level_0_Walls") - 1;
            windows = ds_grid_create(room_width() div 8, room_height() div 8);
            ds_grid_clear(self.windows, false);
            horizon_line = self.y div 8;

            self.lut_texture = spr_fx_window_bg_lut;
            var uvs_full = sprite_get_uvs(spr_fx_window_bg_lut, 0);
            self.uvs = [uvs_full[0], uvs_full[1]];
            self.lut_column_idx = 1;
            sprite_index = spr_window_fx_clear_sky;
            stars_counter = 0;
            star_strength = 0.57;
        },
        step: function() {
            if !instance_exists(Game) {
                return;
            }
            if WEATHER.is_inclement() {
                if CALENDAR.season() == Season.Winter {
                    self.sprite_index = spr_window_fx_snow;
                } else {
                    self.sprite_index = spr_window_fx_rain;
                }
            } else {
                self.sprite_index = spr_window_fx_clear_sky;
            }

            //
            var working_time = POST_PROCESS_TIME_OVERRIDE ?? CLOCK.time;

            //
            var chosen_time = 0;
            var next_time = 1;
            for (var i = 0; i < array_length(WINDOW_BACKING_TIMES); i++) {
                next_time = i;

                if WINDOW_BACKING_TIMES[i][0] > working_time {
                    break;
                }
                chosen_time = i;
            }

            if chosen_time == next_time {
                self.lut_column_idx = WINDOW_BACKING_TIMES[chosen_time][1];
            } else {
                var lerp_amount = inverse_lerp(working_time, WINDOW_BACKING_TIMES[next_time][0], WINDOW_BACKING_TIMES[chosen_time][0]);
                self.lut_column_idx = lerp(WINDOW_BACKING_TIMES[chosen_time][1], WINDOW_BACKING_TIMES[next_time][1], lerp_amount);
            }
        },
        draw: function() {
            //
            gpu_set_extra(UberShaderKind.WindowFill, self.uvs[0], self.uvs[1], real(self.lut_column_idx));
            shader_set_texture("u_LutTexture", self.lut_texture, 0, "u_LutTexelSize");

            for (var window_color = 0; window_color < 6; window_color++) {
                var yy = self.horizon_line - 6 + window_color;

                for (var xx = 0; xx < ds_grid_width(self.windows); xx++) {
                    if self.windows[# xx, yy] {
                        draw_sprite_part(
                            self.sprite_index,
                            self.image_index,
                            (xx % 2) * 8,
                            window_color * 8,
                            8,
                            8,
                            xx * 8,
                            yy * 8
                        );
                    }
                }
            }

            gpu_reset_extra();

            if self.lut_column_idx > 20 && WEATHER.is_inclement() == false {
                var star_str = min(self.lut_column_idx - 20, 1.0) * self.star_strength;
                gpu_set_blendmode_ext(bm_src_alpha, bm_one);
                for (var window_color = 1; window_color <= 6; window_color++) {
                    var yy = self.horizon_line - 6 + window_color;

                    for (var xx = 0; xx < ds_grid_width(self.windows); xx++) {
                        if self.windows[# xx, yy] {
                            draw_sprite_part(
                                spr_window_fx_stars,
                                self.stars_counter,
                                (xx % 5) * 8,
                                (window_color - 1) * 8,
                                8,
                                8,
                                xx * 8,
                                yy * 8,
                                c_white,
                                star_str
                            );
                        }
                    }
                }
                self.stars_counter += 0.05;
                self.stars_counter %= sprite_get_number(spr_window_fx_stars);

                gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);
            }
        },
    }
);
