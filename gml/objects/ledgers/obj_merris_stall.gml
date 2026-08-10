object_create(
    "obj_merris_stall",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_town_stall_merri_sign,
        create: function() {
            event_inherit(ObjectEvent.Create);

            if SATURDAY_MARKET.stalls[NpcId.Merri] == false {
                instance_destroy();
                return;
            }

            self.darkness_sprite = spr_nothing;
            self.name = "merris_stall";

            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    ANCHOR.spawn_menu(Menu.Store, Store.Merri);
                },
            );

            depth = get_instance_depth(y, -10);
        },
    }
);
