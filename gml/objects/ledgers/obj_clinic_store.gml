object_create(
    "obj_clinic_store",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_clinic_f1_ledger_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.darkness_sprite = spr_clinic_f1_ledger_darkness;
            self.name = "valens_clinic";
            self.menu = Menu.Store;

            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    ANCHOR.spawn_menu(Menu.Store, Store.ValensClinic);
                },
            );

            depth = get_instance_depth(y);
        },
    }
);
