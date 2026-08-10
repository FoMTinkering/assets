object_create(
    "par_ledger",
    object_reserve("par_interactable"),
    {
        sprite_index: undefined,
        create: function() {
            //
            event_inherit(ObjectEvent.Create, par_interactable);

            self.darkness_sprite = undefined;

            needs_fiddle = true;

            self.menu = undefined;
            self.small_icon = spr_ui_bark_icon_coin_small;
            self.big_icon = spr_ui_bark_icon_coin;
        },
        draw: function() {
            if self.darkness_sprite != undefined {
                draw_sprite(self.darkness_sprite, 0, x, y);
            }

            //
            event_inherit(ObjectEvent.Draw, par_interactable);
        },
        draw_end: function() {
            self.bouncer.status = InteractBounceStatus.None;

            //
            if has_flag(PAUSE_STATUS, PauseStatus.CUTSCENE) || has_flag(PAUSE_STATUS, PauseStatus.MENU)  {
                return;
            }

            if self.needs_fiddle {
                self.needs_fiddle = false;
                var fiddle_data = fiddle_get(format("interaction/{}_offset", name));

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
                draw_sprite_ext(self.big_icon, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            } else {
                draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(self.small_icon, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            }
        },
    }
);
