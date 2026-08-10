object_create(
    "obj_monster_bat_sonic_boom",
    undefined,
    {
        sprite_index: spr_fx_player_combat_sonic_boom,
        create: function() {
            //
            TANGO.play("SoundEffects/Enemies/EssenceBat/SonicBoom", self.x, self.y);

            self.tarball = undefined;
            self.process_frame = -1;

            function on_hit() {
                //
            }
        },
        step: function() {
            var new_frame = floor(self.image_index);

            if new_frame != self.process_frame {
                self.process_frame = new_frame;

                switch self.process_frame {
                    case 0:
                        self.tarball = TarballBuilder(self.x, self.y, 1, 1, self.damage, CombatTarget.Enemy)
                            .set_mask_index(spr_fx_player_combat_sonic_boom_damage_zero)
                            .set_can_destroy_grid_objects(true)
                            .gen();
                        break;
                    case 2:
                        instance_destroy(self.tarball);
                        self.tarball = undefined;
                        break;
                    case 4:
                        self.tarball = TarballBuilder(self.x, self.y, 1, 1, self.damage, CombatTarget.Enemy)
                            .set_mask_index(spr_fx_player_combat_sonic_boom_damage_one)
                            .set_can_destroy_grid_objects(true)
                            .gen();
                        break;
                    case 6:
                        instance_destroy(self.tarball);
                        self.tarball = undefined;
                        break;
                    case 8:
                        self.tarball = TarballBuilder(self.x, self.y, 1, 1, self.damage, CombatTarget.Enemy)
                            .set_mask_index(spr_fx_player_combat_sonic_boom_damage_two)
                            .set_can_destroy_grid_objects(true)
                            .gen();
                        break;
                    case 12:
                        instance_destroy(self.tarball);
                        self.tarball = undefined;
                        break;
                }
            }
        },
        animation_end: function() {
            instance_destroy(self);
        },
        destroy: function() {
            if self.tarball != undefined {
                instance_destroy(self.tarball);
                self.tarball = undefined;
            }
        },
    }
);
