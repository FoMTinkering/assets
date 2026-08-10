object_create(
    "obj_animal_souvenir_booth",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_town_animal_festival_booth_ledger_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.darkness_sprite = spr_town_animal_festival_booth_ledger_darkness;

            setup_festival_ledger(FestivalId.Animal, Store.NoraSouvenirStall, "noras_stall", "misc_local/noras_stall_name");
        },
    }
);
