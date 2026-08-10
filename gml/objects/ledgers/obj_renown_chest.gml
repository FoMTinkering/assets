object_create(
    "obj_renown_chest",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_town_renown_chest_spring_closed,
        create: function() {
            event_inherit(ObjectEvent.Create);

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            self.name = "renown_chest";
            self.big_icon = spr_ui_bark_icon_gift;
            self.small_icon = spr_ui_bark_icon_gift_small;

            self.register_interaction(
                InputId.Interact,
                "misc_local/collect_rewards",
                function() {
                    ANCHOR.spawn_menu(Menu.RenownChest);
                    self.sprite_index = spr_town_renown_chest_spring_opening;
                },
                function() {
                    return !RENOWN_REWARD_INVENTORY.is_empty();
                }
            );

            depth = get_instance_depth(y);
        },
        step: function() {
            if ANCHOR.get_menu(Menu.RenownChest) == undefined
                && self.sprite_index == spr_town_renown_chest_spring_opened
            {
                self.sprite_index = spr_town_renown_chest_spring_opening;
                self.image_speed = -1;
            }
        },
        draw_end: function() {
            self.bouncer.status = InteractBounceStatus.Distant;
            self.bouncer.alpha = BARK_MIN_ALPHA;

            if RENOWN_REWARD_INVENTORY.is_empty() {
                return;
            }

            event_inherit(ObjectEvent.DrawEnd);

        },
        animation_end: function() {
            if self.sprite_index == spr_town_renown_chest_spring_opening {
                if self.image_speed == 1.0 {
                    self.sprite_index = spr_town_renown_chest_spring_opened;
                } else {
                    self.sprite_index = spr_town_renown_chest_spring_closed;
                }

                self.image_speed = 1.0;
            }
        },
    }
);
