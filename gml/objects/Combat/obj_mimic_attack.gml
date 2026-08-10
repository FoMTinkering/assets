object_create(
    "obj_mimic_attack",
    undefined,
    {
        sprite_index: spr_fx_monster_mimic_chomp,
        create: function() {
            //

            self.tarball = undefined;

            mimic_attack_state = MimicAttackState.Init;
        },
        step: function() {
            switch self.mimic_attack_state {
                case MimicAttackState.Init:
                    if self.image_index >= 2 {
                        self.tarball = TarballBuilder(self.x, self.y, 1, 1, self.damage, CombatTarget.Player)
                            .set_mask_index(sprite_index)
                            .set_provenance(self.monster_id, self.stats_entry)
                            .gen();

                        self.mimic_attack_state = MimicAttackState.Main;
                    }
                    break;
                case MimicAttackState.Main:
                    if self.image_index >= 5 && self.tarball != undefined && instance_exists(self.tarball) {
                        instance_destroy(self.tarball);
                        self.tarball = undefined;

                        self.mimic_attack_state = MimicAttackState.Done;
                    }
                    break;
                case MimicAttackState.Done:
                    //
                    break;
            }
        },
        animation_end: function() {
            instance_destroy(self);
        },
        destroy: function() {
            //
            if self.tarball != undefined {
                instance_destroy(self.tarball);
            }
        },
    }
);
