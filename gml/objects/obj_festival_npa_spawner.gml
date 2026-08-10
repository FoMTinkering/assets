object_create(
    "obj_festival_npa_spawner",
    undefined,
    {
        sprite_index: spr_animal_chicken_basic_female_idle_east,
        days_old: 0.0,
        kind: "",
        sex: "",
        variant: "",
        visible: false,
        create: function() {
            function spawn_npa() {
                if !FESTIVALS[FestivalId.Animal].is_today() {
                    instance_destroy(self);
                    return;
                }

                var npa = new NonPlayerAnimal(
                    string_to_animal_kind(self.kind),
                    self.variant,
                    string_to_sex(self.sex),
                );
                npa.days_old = self.days_old;
                npa.location_position = new LocationPosition(LocationId.Town, Vec2(self.x, self.y));

                instance_create_layer(
                    self.x,
                    self.y,
                    "Instances",
                    obj_npa,
                    {
                        me: npa,
                    }
                );

                instance_destroy();
            }
        },
    }
);
