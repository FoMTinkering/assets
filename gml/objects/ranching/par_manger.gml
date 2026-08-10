object_create(
    "par_manger",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_barn_manger_spring,
        left: false,
        create: function() {
            //
            event_inherit(ObjectEvent.Create);
            self.visible = true;

            //
            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            //
            //
            self.inventory = [];
            self.animal_feed_size = undefined;

            self.register_interaction(
                InputId.Interact,
                "misc_local/place_animal_feed",
                function() {
                    TANGO.play("SoundEffects/Objects/PlaceFeed", x, y);
                    self.inventory[self.find_free_slot()] = ARI.inventory.slot(ARI.held_item_index).pop();
                },
                function() {
                    var held_item = ARI.held_item();
                    return held_item != undefined
                        && held_item.prototype.animal_feed != undefined
                        && held_item.prototype.animal_feed.animal_size == self.animal_feed_size
                        && self.find_free_slot() != undefined;
                },
            );

            function find_free_slot() {
                return array_index(self.inventory, undefined);
            }

            depth = get_instance_depth(y);

            var fiddle_data = fiddle_get("interaction/hay_manger_offset");
            self.offset_x = fiddle_data[0];
            self.offset_y = fiddle_data[1];
        },
        draw: function() {
            event_inherit(ObjectEvent.Draw);

            var offset_x = -22;
            var offset_y = -4;

            if array_length(self.inventory) > 4 {
                offset_x -= 15;
            }

            //
            for (var i = 0; i < array_length(self.inventory); i++) {
                var item = self.inventory[i];

                if item != undefined {
                    var spr = item.prototype.animal_feed.sprite;
                    draw_sprite(SHADOW_DICTIONARY.get(spr), 0, x + offset_x, y + offset_y);
                    draw_sprite(spr, 0, x + offset_x, y + offset_y);
                }

                offset_x += 15;
            }
        },
        draw_end: function() {
            self.bouncer.status = InteractBounceStatus.Distant;

            //
            if has_flag(PAUSE_STATUS, PauseStatus.MENU)
                || has_flag(PAUSE_STATUS, PauseStatus.CUTSCENE)
                || self.find_free_slot() == undefined
            {
                return;
            }

            var small_icon;
            var big_icon;
            if self.animal_feed_size == AnimalSize.Small {
                small_icon = spr_ui_bark_icon_place_seed_small;
                big_icon = spr_ui_bark_icon_place_seed;
            } else {
                small_icon = spr_ui_bark_icon_place_hay_small;
                big_icon = spr_ui_bark_icon_place_hay;
            }

            var target = 0;
            if distance_to_ari_interactable() < STANDARD_INTERACTION_DISTANCE {
                target = BARK_MIN_ALPHA;
            }
            self.bouncer.alpha = approach(self.bouncer.alpha, target, BARK_FADE_SPEED);
            var is_being_selected = self.bouncer.update();

            if is_being_selected {
                draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(big_icon, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            } else {
                draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(small_icon, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            }
        },
    }
);
