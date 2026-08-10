object_create(
    "obj_veras_stall",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_town_stall_vera_ledger_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            if SATURDAY_MARKET.stalls[NpcId.Vera] == false {
                instance_destroy();
                return;
            }

            self.darkness_sprite = spr_nothing;
            self.name = "veras_stall";

            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    ANCHOR.spawn_menu(Menu.Store, Store.Vera);
                },
            );

            depth = get_instance_depth(y, -12);
        },
    }
);
