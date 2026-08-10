object_create(
    "obj_noras_stall",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_town_stall_merri_sign,
        create: function() {
            event_inherit(ObjectEvent.Create);

            setup_festival_ledger(FestivalId.Spring, Store.NoraSouvenirStall, "noras_stall", "misc_local/noras_stall_name");
        },
    }
);
