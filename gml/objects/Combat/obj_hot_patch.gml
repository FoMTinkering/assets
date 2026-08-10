object_create(
    "obj_hot_patch",
    undefined,
    {
        sprite_index: spr_monster_mushroom_acid_patch_spring_start,
        create: function() {
            self.depth = get_shadow_depth() + 1 + (real(self.id) % 32);

            self.tarball = TarballBuilder(self.x - 16, self.y - 16, 32, 32, self.damage)
                .set_acid()
                .set_provenance(self.owner.monster_id, self.owner.stats_entry)
                .gen();

            self.slow = 0.66;
            self.has_granted_speedup = false;
            self.image_alpha = 0.75;
        },
        step: function() {
            //
            if instance_exists(self.tarball) {
                self.tarball.already_hit_array = [];
            }

            self.timer -= 1;
            if self.timer <= 0 {
                self.image_alpha -= 0.05;
                if self.image_alpha <= 0 {
                    instance_destroy(self);
                    return;
                }
            }

            self.depth += FRAME_TIME;

            if instance_exists(obj_ari) && overlap_instance_any(self.x, self.y, obj_ari.receiver) {
                self.sprite_index = spr_monster_mushroom_acid_patch_spring_pulse;
            } else {
                self.sprite_index = spr_monster_mushroom_acid_patch_spring_start;
                self.image_index = self.image_number - 1;
            }
        },
        animation_end: function() {
            if self.sprite_index == spr_monster_mushroom_acid_patch_spring_start {
                image_index = image_number - 1;
            }
        },
        destroy: function() {
            if instance_exists(self.tarball) {
                instance_destroy(self.tarball);
            }
        },
    }
);
