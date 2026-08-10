object_create(
    "obj_stillwell_challenge_board",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_town_stall_plaza_challenge_board_main,
        create: function() {
            event_inherit(ObjectEvent.Create);
            self.mask_index = spr_mask_requestboard;

            if SATURDAY_MARKET.stalls[NpcId.Stillwell] == false {
                instance_destroy();
                return;
            }
            trace("keep gaming gaming gaming")

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            self.register_interaction(
                InputId.Interact,
                "misc_local/use",
                spawn_stillwell_challenge_menu,
            );
            depth = get_instance_depth(y);

            var fiddle_data = fiddle_get("interaction/challenge_board_offset");
            self.bounce_x_offset = fiddle_data[0];
            self.bounce_y_offset = fiddle_data[1];
        },
        draw_end: function() {
            if available_stillwell_challenge() == undefined || MIST.running {
                return;
            }

            self.bouncer.status = InteractBounceStatus.Distant;
            self.bouncer.alpha = BARK_MIN_ALPHA;

            var is_being_selected = self.bouncer.update();

            if is_being_selected {
                draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_exclamation_mark, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            } else {
                draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_exclamation_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            }
        },
    }
);
