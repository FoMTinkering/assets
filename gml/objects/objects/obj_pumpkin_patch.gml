object_create(
    "obj_pumpkin_patch",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_furniture_crop_sign_pumpkin_spring,
        create: function() {
            if !FESTIVALS[FestivalId.Harvest].is_today() {
                instance_destroy();
                return;
            }

            event_inherit(ObjectEvent.Create);
            self.price = fiddle_get("misc/pumpkin_patch_price");
            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    if ARI.get_gold() < self.price {
                        play_conversation_from_path(NpcId.Hemlock, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.PumpkinPatchNoMoney]);
                    } else {
                        play_conversation_from_path(NpcId.Hemlock, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.PumpkinPatch], function(driver) {
                            if driver.prompt_index_selected == 0 {
                                HAYDEN_PUMPKINS.shuffle();
                                ARI.give_item(HAYDEN_PUMPKINS.first());
                                ARI.modify_gold(-self.price);
                            }
                        });
                    }
                },
                function() {
                    return true;
                },
            );
            depth = get_instance_depth(y);
            image_alpha = 0;

            var fiddle_data = fiddle_get("interaction/harvest_pumpkin_patch");
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
                draw_sprite_ext(spr_ui_bark_icon_coin, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            } else {
                draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_coin_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            }
        },
    }
);
