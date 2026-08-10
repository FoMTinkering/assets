object_create(
    "obj_museum_table",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_museum_displayroom_table_spring,
        key: "",
        create: function() {
            event_inherit(ObjectEvent.Create);

            var split = string_split(self.key, "/");
            self.wing = string_to_museum_wing(split[0]);
            self.set_name = split[1];

            switch self.wing {
                case MuseumWing.Archaeology:
                    self.sprite_index = spr_museum_displayroom_table_spring;
                    break;
                case MuseumWing.Fish:
                    self.sprite_index = self.set_name == "legendary"
                        ? spr_museum_displayroom_table_fish_alt_spring
                        : spr_museum_displayroom_table_fish_spring;
                    break;
                case MuseumWing.Flora:
                    self.sprite_index = spr_museum_displayroom_table_flora_spring;
                    break;
                case MuseumWing.Insect:
                    self.sprite_index = spr_museum_displayroom_table_insect_spring;
                    break;
                default:
                    crash("obj_museum_table has an unknown wing: '{}'!", self.key);
            }

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    museum_set_popup(self.wing, self.set_name);
                }
            );

            self.depth = get_instance_depth(y);
        },
    }
);
