object_create(
    "obj_harvest_souvenir_booth",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_town_animal_festival_booth_ledger_spring,
        create: function() {
            if !FESTIVALS[FestivalId.Harvest].is_today() {
                instance_destroy();
                return;
            }

            event_inherit(ObjectEvent.Create);

            self.darkness_sprite = spr_town_harvest_festival_booth_ledger_darkness;

            setup_festival_ledger(FestivalId.Harvest, Store.NoraSouvenirStall, "noras_stall", "misc_local/noras_stall_name");
        },
    }
);
