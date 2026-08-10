object_create(
    "obj_wishing_well",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_easternroad_wishing_well_spring,
        create: function() {
            //
            event_inherit(ObjectEvent.Create);

            //
            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            self.mask_index = self.sprite_index;
            self.image_speed = 0;
            self.prize = undefined;
            self.high_price = fiddle_get("misc/wishing_well/high_price");
            self.low_price = fiddle_get("misc/wishing_well/low_price");

            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    var tesserae = ARI.get_gold();
                    var callback = undefined;
                    callback = function(driver) {
                        if matches(driver.prompt_index_selected, 0, 1) {
                            USED_WISHING_WELL = true;
                            //
                            var yield = poll_statue_reward(WISHING_WELL_REWARDS, driver.prompt_index_selected == 0);
                            var spend = driver.prompt_index_selected == 0 ? self.low_price : self.high_price;
                            ARI.modify_gold(-spend);
                            with obj_wishing_well_head {
                                self.sprite_index = spr_easternroad_dragon_head_spring_on;
                                self.image_speed = 1;
                                TANGO.play("SoundEffects/Objects/UseChickenStatue");
                            }
                            self.prize = consume_reward(yield);

                            array_push(GAME_STATS.wishing_well_uses, {
                                prize: self.prize.first().pretty_print(),
                                cost: driver.prompt_index_selected == 0 ? self.low_price : self.high_price,
                                day: total_days(),
                            });
                        }
                        STATUE_CTX = undefined;
                    }

                    STATUE_CTX = "wishing_well";
                    var driver = play_conversation_from_path(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.WishingWellInteraction], callback);

                    if tesserae < self.low_price {
                        driver.textbox.prompt_one.blackboard.insert("stay_locked", true);
                    }
                    if tesserae < self.high_price {
                        driver.textbox.prompt_two.blackboard.insert("stay_locked", true);
                    }
                },
                function() {
                    return !USED_WISHING_WELL;
                }
            );

            depth = get_instance_depth(y);

            if CALENDAR.season() == Season.Winter {
                sprite_index = spr_easternroad_wishing_well_winter;
            }
        },
    }
);
