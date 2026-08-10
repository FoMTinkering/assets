object_create(
    "obj_darcys_stall",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_town_stall_darcy_ledger,
        create: function() {
            event_inherit(ObjectEvent.Create);

            if SATURDAY_MARKET.stalls[NpcId.Darcy] == false {
                instance_destroy();
                return;
            }

            self.darkness_sprite = spr_nothing;
            self.name = "darcys_stall";

            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    ANCHOR.spawn_menu(Menu.Store, Store.Darcy);
                },
            );

            depth = get_instance_depth(y, -10);
        },
    }
);
