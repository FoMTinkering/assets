object_create(
    "par_light",
    undefined,
    {
        sprite_index: undefined,
        festival: "",
        inherent_light: "",
        visible: false,
        create: function() {
            var fest = festival == "" ? undefined : string_to_festival_id(festival);
            z = 0;

            if fest != undefined && FESTIVALS[fest].is_today() == false {
                instance_destroy();
                return;
            }

            //
            tiered_light = undefined;

            show = true;

            if object_index != par_light && object_index != obj_exterior_light {
                tiered_light = string_to_light(self.inherent_light);
                self.sprite_index = LIGHTS[tiered_light][0];
            }

            depth_override = false;
        },
        step: function() {
            image_speed = !non_cutscene_pause();
            if self.depth_override == false {
                depth = get_instance_depth(y, z);
            }
        },

        //
        draw: function() {}
    }
);
