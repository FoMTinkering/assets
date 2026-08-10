object_create(
    "obj_inn",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_inn_ledger_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);
            if !world_mod_enabled(WorldMod.InnInterior) {
                self.sprite_index = spr_inn_ledger_spring_broken;
            }
            self.darkness_sprite = spr_inn_ledger_darkness;
            self.name = "inn"
            self.menu = Menu.Store;

            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    ANCHOR.spawn_menu(Menu.Store, Store.Inn);
                },
            );
            depth = get_instance_depth(y);
        },
    }
);
