object_create(
    "obj_damage_number",
    undefined,
    {
        create: function() {
            //
            self.sprite_index = string_to_asset(format("spr_fx_crit_{}", asset_local_insert()));
            image_blend = c_white;
            self.font_name = undefined;
            self.font = undefined;
            if has_flag(self.damage_flag, DamageFlag.HEAVY) || has_flag(self.damage_flag, DamageFlag.CRITICAL) {
                self.font_name = "skill_font";
                image_blend = c_yellow;
            } else {
                self.font_name = "damage_numbers";
            }
            self.font = SPRITE_FONTS[$ self.font_name];

            digit = string(abs(damage));
            if damage == 0 || has_flag(self.damage_flag, DamageFlag.WEAK) {
                image_blend = make_color_rgb(186, 177, 177);
            }

            position_ease = new Ease(EaseId.BackOut, y + 13, y, 20);
            frame = 0;
            image_alpha = 0.3;
            shake = Vec2();

            target_frame = 30;

            if has_flag(self.damage_flag, DamageFlag.CRITICAL) {
                target_frame = 40;
                base_rainbow = [(irandom_range(-100, 100) * 12) % 256, 120, 255];
                image_blend = make_color_hsv(base_rainbow[0], base_rainbow[1], base_rainbow[2]);
            }
        },
        step: function() {
            self.frame += 1;

            if self.frame < self.target_frame {
                self.image_alpha += 0.1;

                if self.frame < (self.target_frame / 2) {
                    if (self.kind == DamageNumber.Damage) && (self.frame % 4 == 0) {
                        self.shake.x = irandom_range(-1, 1);
                        self.shake.y = irandom_range(-1, 1);
                    }
                } else {
                    self.shake.x = 0;
                    self.shake.y = 0;
                }
            } else {
                self.image_alpha -= 0.1;

                if self.image_alpha < 0.1 {
                    instance_destroy(self);
                    return;
                }
            }
            self.image_alpha = clamp(image_alpha, 0.0, 1.0);

            self.y = self.position_ease.calculate_value(self.frame);

            if has_flag(self.damage_flag, DamageFlag.CRITICAL) {
                self.base_rainbow[0] += 12;
                self.base_rainbow[0] %= 256;

                image_blend = make_color_hsv(base_rainbow[0], base_rainbow[1], base_rainbow[2]);
            }

            //
            if self.frame < 10 {
                image_index = 0;
            }
        },
        draw: function() {
            //
        },
        draw_end: function() {
            var xx = x + shake.x;
            var yy = y + shake.y;

            var w = sprite_font_width(self.digit, self.font_name);

            if self.kind != DamageNumber.Damage {
                var symbol;
                if self.kind == DamageNumber.Health {
                    symbol = "&";
                } else {
                    symbol = "p";
                }

                w += self.font.characters[$ symbol];
                xx -= w / 2;

                draw_sprite_ext(
                    self.font.sprite,
                    string_pos(symbol, self.font.order) - 1,
                    xx,
                    yy,
                    1,
                    1,
                    0,
                    c_white,
                    image_alpha
                );

                xx += self.font.characters[$ symbol];
            } else {
                xx -= w / 2;
            }

            for (var i = 1; i <= string_length(self.digit); i++) {
                var char = string_char_at(self.digit, i);
                draw_sprite_ext(
                    self.font.sprite,
                    string_pos(char, self.font.order) - 1,
                    xx,
                    yy,
                    1,
                    1,
                    0,
                    self.image_blend,
                    image_alpha
                );
                xx += self.font.characters[$ char];
            }

            if has_flag(self.damage_flag, DamageFlag.CRITICAL) && self.frame >= 10 {
                xx -= w / 2;
                draw_sprite_ext(sprite_index, image_index, xx, yy, 1, 1, 0, c_white, image_alpha);
            }
        },
    }
);
