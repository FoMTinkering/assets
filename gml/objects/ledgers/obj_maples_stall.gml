object_create(
    "obj_maples_stall",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_town_stall_merri_sign,
        create: function() {
            event_inherit(ObjectEvent.Create);

            setup_festival_ledger(FestivalId.Spring, Store.MapleSpringFestival, "maples_stall", "misc_local/maples_stall_name");
        },
    }
);
