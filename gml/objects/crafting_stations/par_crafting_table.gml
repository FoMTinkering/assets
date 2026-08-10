object_create(
    "par_crafting_table",
    object_reserve("par_interactable"),
    {
        sprite_index: undefined,
        create: function() {
            //
            event_inherit(ObjectEvent.Create, par_interactable);

            self.needs_fiddle = true;

            fiddle_name = undefined;
            large_icon = undefined;
            small_icon = undefined;

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });
        },
        draw_end: function() {
            self.bouncer.status = InteractBounceStatus.None;

            if MIST.running || self.can_use() == false {
                return;
            }

            if self.needs_fiddle {
                self.needs_fiddle = false;
                var fiddle_data = fiddle_get(fiddle_name);

                self.offset_x = fiddle_data[0];
                self.offset_y = fiddle_data[1];
            }

            self.bouncer.status = InteractBounceStatus.Distant;

            var target = 0;
            if distance_to_ari_interactable() < STANDARD_INTERACTION_DISTANCE {
                target = BARK_MIN_ALPHA;
            }
            self.bouncer.alpha = approach(self.bouncer.alpha, target, BARK_FADE_SPEED);

            var is_being_selected = self.bouncer.update();

            if is_being_selected {
                draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(self.large_icon, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            } else {
                draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(self.small_icon, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            }
        },
    }
);
