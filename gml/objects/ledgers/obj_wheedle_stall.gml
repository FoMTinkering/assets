object_create(
    "obj_wheedle_stall",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_town_stall_wheedle_sign_main,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.darkness_sprite = spr_town_stall_wheedle_sign_darkness;
            self.small_icon = spr_ui_bark_icon_coin_small;
            self.big_icon = spr_ui_bark_icon_coin;

            if SATURDAY_MARKET.stalls[NpcId.Wheedle] == false {
                instance_destroy();
                return;
            }

            self.darkness_sprite = spr_town_stall_wheedle_sign_darkness;
            self.name = "wheedles_stall";

            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    ANCHOR.spawn_menu(Menu.Store, Store.Wheedle);
                },
            );

            depth = get_instance_depth(y, -10);
        },
    }
);
