object_create(
    "obj_harvest_pie",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_town_harvest_festival_table_spring,
        create: function() {
            if !FESTIVALS[FestivalId.Harvest].is_today() {
                instance_destroy();
                return;
            }

            event_inherit(ObjectEvent.Create);

            self.register_interaction(
                InputId.Interact,
                "misc_local/interact",
                function() {
                    callback = function(driver) {
                        if driver.prompt_index_selected == 0 {
                            use_item_fast(ItemId.HarvestDayPie);
                        }
                    };
                    play_conversation_from_path(NpcId.Hemlock, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.HarvestPie], callback, []);
                },
                function() {
                    return true;
                },
            );
            depth = get_instance_depth(y, -11);

            var fiddle_data = fiddle_get("interaction/harvest_pie_offset");
            self.bounce_x_offset = fiddle_data[0];
            self.bounce_y_offset = fiddle_data[1];
        },
        draw_end: function() {
            self.bouncer.status = InteractBounceStatus.None;

            //
            if has_flag(PAUSE_STATUS, PauseStatus.CUTSCENE) || has_flag(PAUSE_STATUS, PauseStatus.MENU)  {
                return;
            }
            self.bouncer.status = InteractBounceStatus.Distant;

            var target = 0;
            if distance_to_ari_interactable() < STANDARD_INTERACTION_DISTANCE {
                target = BARK_MIN_ALPHA;
            }
            self.bouncer.alpha = approach(self.bouncer.alpha, target, BARK_FADE_SPEED);

            var is_being_selected = self.bouncer.update();

            if is_being_selected {
                draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_hungry, 4, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            } else {
                draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_hungry, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset - 2, 1, 1, 0, c_white, self.bouncer.alpha);
            }
        },
    }
);
