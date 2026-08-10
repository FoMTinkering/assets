object_create(
    "obj_louis_stall",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_town_stall_louis_desk_ledger_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            if SATURDAY_MARKET.stalls[NpcId.Louis] == false {
                instance_destroy();
                return;
            }

            self.darkness_sprite = spr_nothing;
            self.name = "louis_stall";
            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    ANCHOR.spawn_menu(Menu.Store, Store.Louis);
                },
            );

            depth = get_instance_depth(y, -10);
        },
    }
);
