
object_create(
    "obj_zorels_stall",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_town_stall_zorel_sign_main,
        create: function() {
            event_inherit(ObjectEvent.Create);

            if SATURDAY_MARKET.stalls[NpcId.Zorel] == false {
                instance_destroy();
                return;
            }

            self.darkness_sprite = spr_nothing;
            self.name = "zorels_stall";

            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    ANCHOR.spawn_menu(Menu.Store, Store.Zorel);
                },
            );

            depth = get_instance_depth(y, -10);
        },
    }
);
