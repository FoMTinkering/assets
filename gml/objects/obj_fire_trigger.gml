object_create(
    "obj_fire_trigger",
    undefined,
    {
        sprite_index: spr_pixel,
        cutscene: "cutscene_basement",
        create: function() {
            function burn() {
                if self.can_burn() {
                    instance_destroy();
                    instance_destroy(self.receiver);
                    MIST.run_scene(self.cutscene);
                }
            }

            self.receiver = create_receiver(x, y, sprite_index, id, {
                target: CombatTarget.Enemy
            });

            self.receiver.image_xscale = image_xscale;
            self.receiver.image_yscale = image_yscale;
        },
        step_end: function() {
            self.receiver.try_take_damage();
        },
    }
);
