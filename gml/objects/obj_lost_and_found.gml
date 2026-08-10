object_create(
    "obj_lost_and_found",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_object_lost_and_found_box_main_closed,
        create: function() {
            if !requirements_pass(Requirement.UnlockedLostAndFound) {
                instance_destroy();
                return;
            }

            set_collision_on_node_region(GRIDS[LocationId.Town], 119, 258, 122, 259);

            event_inherit(ObjectEvent.Create);

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            self.name = "lost_and_found";
            self.big_icon = spr_ui_bark_icon_misc;
            self.small_icon = spr_ui_bark_icon_misc_small;
            self.menu = undefined;

            self.register_interaction(
                InputId.Interact,
                "misc_local/open",
                function() {
                    self.sprite_index = spr_object_lost_and_found_box_main_opening;
                    self.menu = ANCHOR.spawn_menu(Menu.Storage)
                        .set_inventories(LOST_AND_FOUND, ARI.inventory)
                        .with_pull_button(false)
                        .with_left_help_button()
                        .with_right_banner()
                        .with_left_banner()
                        .build();

                    self.menu.left_banner.help.set_tap_callback(function() {
                        spawn_tutorial(Tutorial.LostAndFound);
                    }, [], true);
                },
                function() {
                    return !LOST_AND_FOUND.is_empty();
                }
            );

            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    play_conversation_from_path(NpcId.Adeline, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectLostAndFound]);
                },
                function() {
                    return LOST_AND_FOUND.is_empty();
                }
            );

            depth = get_instance_depth(y);


            self.canvas = undefined;
        },
        step: function() {
            if self.menu != undefined && self.menu.close_requested {
                self.sprite_index = spr_object_lost_and_found_box_main_opening;
                self.image_speed = -1;
                self.menu = undefined;
            }
        },
        draw_end: function() {
            self.bouncer.status = InteractBounceStatus.Distant;
            self.bouncer.alpha = BARK_MIN_ALPHA;

            if LOST_AND_FOUND.is_empty() {
                return;
            }

            event_inherit(ObjectEvent.DrawEnd);
        },
        animation_end: function() {
            if self.sprite_index == spr_object_lost_and_found_box_main_opening {
                if self.image_speed == 1.0 {
                    self.sprite_index = spr_object_lost_and_found_box_main_opened;
                } else {
                    self.sprite_index = spr_object_lost_and_found_box_main_closed;
                }

                self.image_speed = 1.0;
            }
        },
    }
);
