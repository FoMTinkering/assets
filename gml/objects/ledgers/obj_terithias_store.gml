object_create(
    "obj_terithias_store",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_terithia_house_ledger_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.darkness_sprite = spr_terithia_house_ledger_darkness;
            self.name = "terithias_store";
            self.menu = Menu.Store;

            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    ANCHOR.spawn_menu(Menu.Store, Store.Terithia);
                },
            );

            depth = get_instance_depth(y, -10);
        },
    }
);
