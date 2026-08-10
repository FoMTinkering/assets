object_create(
    "obj_shooting_star_particle",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            //
            //
            //
            //

            self.light = instance_create_layer(
                x,
                y,
                "Lighting",
                par_light,
                {
                    sprite_index: light_sprite,
                }
            );
            self.light.show = false;
        },
        step: function() {
            y += self.fall_speed;

            self.light.y = self.y;
            if self.light.visible == false
                && self.image_index > 0.25
            {
                self.light.show = true;
                self.light.image_alpha = 1.0;
            }

            switch floor(self.image_index) {
                case 3:
                    self.light.image_alpha = 0.75;
                    break;
                case 4:
                    self.light.image_alpha = 0.5;
                    break;
                case 5:
                case 6:
                case 7:
                    self.light.image_alpha = 0.2;
                    break;
            }
        },
        animation_end: function() {
            instance_destroy(self);
            instance_destroy(self.light);
        },
    }
);
