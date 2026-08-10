object_create(
    "obj_balors_wagon",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_town_balor_wagon_ledger,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.darkness_sprite = spr_nothing;
            self.name = "balors_wagon";

            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    ANCHOR.spawn_menu(Menu.Store, Store.Balor, fiddle_get("misc/balor_price_markup"));
                },
            );

            depth = get_instance_depth(y, -10);

        },
    }
);
