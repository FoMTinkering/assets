object_create(
    "obj_exterior_light",
    object_reserve("par_light"),
    {
        sprite_index: undefined,
        festival: "",
        inherent_light: "",
        visible: false,
        create: function() {
            //
            //
            //
            event_inherit(ObjectEvent.Create);

            self.visible = false;
            self.show = false;
            self.image_alpha = 0.0;

            time_offset = irandom(180);

            function turn_on() {
                self.show = true;
                self.light_insert.visible = true;
            }
        },
        step: function() {
            if self.show && self.time_offset >= 0 {
                if self.time_offset == 0 {
                    self.light_insert.image_alpha = 1.0;
                    self.image_alpha = 1.0;

                    //
                    if CURRENT_LOCATION_ID == LocationId.Farm && Game.player_home_light_count < 3 {
                        self.image_alpha = 1.0 - power(0.25, Game.player_home_light_count);
                        self.light_insert.image_alpha = self.image_alpha;
                    }

                }
                self.time_offset -= 1;
            }
        },
    }
);
