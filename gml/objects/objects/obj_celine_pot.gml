object_create(
    "obj_celine_pot",
    undefined,
    {
        sprite_index: spr_celinecottage_seed_pot_spring,
        create: function() {
            function refresh_sprite() {
                var run_grow_animation = MIST.blackboard.try_take("grow_plant", false);
                self.image_speed = run_grow_animation ? 1 : 0;
                if requirements_pass(Requirement.CelinePlantStageThreeRomantic) {
                    self.sprite_index = run_grow_animation
                        ? spr_celinecottage_seed_pot_sprout_spring_opening4_romance
                        : spr_celinecottage_seed_pot_sprout_spring_open4_romance;
                } else if requirements_pass(Requirement.CelinePlantStageThreeBestFriend) {
                    self.sprite_index = run_grow_animation
                        ? spr_celinecottage_seed_pot_sprout_spring_opening4_friendship
                        : spr_celinecottage_seed_pot_sprout_spring_open4_friendship;
                } else if requirements_pass(Requirement.CelinePlantStageTwo) {
                    self.sprite_index = run_grow_animation
                        ? spr_celinecottage_seed_pot_sprout_spring_opening2
                        : spr_celinecottage_seed_pot_sprout_spring_open_2;
                } else if requirements_pass(Requirement.CelinePlantStageOne) {
                    self.sprite_index = run_grow_animation
                        ? spr_celinecottage_seed_pot_sprout_spring_opening
                        : spr_celinecottage_seed_pot_sprout_spring_open;
                } else if requirements_pass(Requirement.CelinePlantStageZero) {
                    self.sprite_index = spr_celinecottage_seed_pot_sprout_spring_opening;
                } else {
                    self.sprite_index = spr_nothing;
                }
            }
            self.refresh_sprite();
        },
        step: function() {
            depth = get_instance_depth(self.y);
            if MIST.blackboard.get_or("grow_plant", false) {
                self.refresh_sprite();
            }
        },
        animation_end: function() {
            self.refresh_sprite();
        },
    }
);
