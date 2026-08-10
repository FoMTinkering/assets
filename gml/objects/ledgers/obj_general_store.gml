object_create(
    "obj_general_store",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_generalstore_store_ledger_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.darkness_sprite = spr_generalstore_store_ledger_darkness;
            self.name = "general_store";
            self.menu = Menu.Store;

            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    ANCHOR.spawn_menu(Menu.Store, Store.General);
                },
            );

            depth = get_instance_depth(y, -10);
        },
    }
);
