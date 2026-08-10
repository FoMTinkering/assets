object_create(
    "obj_dark_light_trigger",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            self.receiver = undefined;
            self.dad = undefined;
            self.dark_light = undefined;
            self.tiered_dark_light = undefined;
            self.dad_sprite = undefined;
            
            self.has_been_hit = false;
        },
        step: function() {
            if self.has_been_hit == true {
                return;
            }

            if self.dad == undefined || instance_exists(self.dad) == false {
                return;
            }

            while true {
                var next_dmg = self.receiver.try_take_damage();
                if next_dmg == undefined {
                    break;
                }

                TANGO.play("SoundEffects/Objects/CrystalLight", self.x, self.dad.y);
                self.dad.light.tiered_light =  self.tiered_dark_light;
                self.dad.light.sprite_index = LIGHTS[self.dark_light][0];
                self.dad.sprite_index = self.dad_sprite;

                Game.dark_room_light_count += 1;

                self.has_been_hit = true;

            }
        },
    }
);
