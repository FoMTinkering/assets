object_create(
    "obj_elsies_stall",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_town_stall_merri_sign,
        create: function() {
            event_inherit(ObjectEvent.Create);

            setup_festival_ledger(FestivalId.Spring, Store.ElsieSpringFestival, "elsies_stall", "misc_local/elsies_stall_name");
        },
    }
);
