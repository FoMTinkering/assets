object_create(
    "obj_chicken_statue",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_haydens_farm_chicken_statue_spring_off,
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
            self.high_price = fiddle_get("misc/chicken_statue/high_price");
            self.low_price = fiddle_get("misc/chicken_statue/low_price");
            self.on_sprite = CALENDAR.season() != Season.Winter ? spr_haydens_farm_chicken_statue_spring_on : spr_haydens_farm_chicken_statue_winter_on;
            self.off_sprite = CALENDAR.season() != Season.Winter ? spr_haydens_farm_chicken_statue_spring_off :spr_haydens_farm_chicken_statue_winter_off;

            sprite_index = self.off_sprite;
            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    if ARI.animal_variant_unlocks[AnimalKind.Horse].contains("giant_chicken_white") == false
                        && ARI.unlocked_all_chicken_tiers()
                        && any_item_matches(ItemId.BigEgg) == false
                    {
                        play_conversation_from_path(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.ChickenStatueEgg]);

                        return;
                    }

                    var currency_amount = ARI.inventory.item_id_quantity(ItemId.AnimalCurrency);
                    var convo = currency_amount == 0 ? GpTriggeredConversation.ChickenStatueNoCurrency : GpTriggeredConversation.ChickenStatueHasCurrency;
                    var callback = undefined;
                    if convo == GpTriggeredConversation.ChickenStatueHasCurrency {
                        callback = function(driver) {
                            if matches(driver.prompt_index_selected, 0, 1) {
                                TANGO.play("SoundEffects/Objects/UseChickenStatue");

                                //
                                var yield = poll_statue_reward(CHICKEN_STATUE_REWARDS, driver.prompt_index_selected == 0);
                                ARI.inventory.remove(ItemId.AnimalCurrency, driver.prompt_index_selected == 0 ? self.low_price : self.high_price);
                                self.sprite_index = self.on_sprite;
                                self.image_speed = 1;
                                self.prize = consume_reward(yield);

                                array_push(GAME_STATS.chicken_statue_uses, {
                                    prize: self.prize.first().pretty_print(),
                                    currency: driver.prompt_index_selected == 0 ? self.low_price : self.high_price,
                                    day: total_days(),
                                });
                            }
                            STATUE_CTX = undefined;
                        }
                    };

                    STATUE_CTX = "chicken_statue";
                    var driver = play_conversation_from_path(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[convo], callback);

                    if currency_amount < self.low_price {
                        driver.textbox.prompt_one.blackboard.insert("stay_locked", true);
                    }
                    if currency_amount < self.high_price {
                        driver.textbox.prompt_two.blackboard.insert("stay_locked", true);
                    }
                }
            );

            depth = get_instance_depth(y);
        },
        draw_end: function() {
            if ARI.animal_variant_unlocks[AnimalKind.Horse].contains("giant_chicken_white")
                || ARI.unlocked_all_chicken_tiers() == false
                || game_paused()
                || self.image_speed != 0
                || any_item_matches(ItemId.BigEgg)
            {
                return;
            }


            self.bouncer.status = InteractBounceStatus.Distant;
            self.bouncer.alpha = approach(self.bouncer.alpha, BARK_MIN_ALPHA, BARK_FADE_SPEED);

            var is_being_selected = self.bouncer.update();

            var offset_x = 0;
            var offset_y = -29;

            if is_being_selected {
                draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_chicken, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            } else {
                draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_chicken_small, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            }
        },
        animation_end: function() {
            self.sprite_index = self.off_sprite;
            self.image_speed = 0;
            drop_item_stack(self.x, self.y, self.prize);
        },
    }
);
