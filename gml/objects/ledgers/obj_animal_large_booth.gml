object_create(
    "obj_animal_large_booth",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_town_animal_festival_booth_ledger_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.darkness_sprite = spr_town_animal_festival_booth_ledger_darkness;
            self.small_icon = spr_ui_bark_icon_cow_small;
            self.big_icon = spr_ui_bark_icon_cow;

            if !FESTIVALS[FestivalId.Animal].is_today() {
                instance_destroy();
                return;
            }

            self.name = "small_animal_booth"
            self.register_interaction(
                InputId.Interact,
                "misc_local/select_animal",
                function() {
                    animal_festival_selection_popup(AnimalSize.Large);
                },
                function() {
                    return QUEST_LOG.active.contains_key("the_animal_festival");
                }
            );

            depth = get_instance_depth(y, -10);
        },
    }
);
