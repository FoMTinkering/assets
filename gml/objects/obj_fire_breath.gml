object_create(
    "obj_fire_breath",
    undefined,
    {
        sprite_index: spr_fx_dragons_breath,
        create: function() {
            self.shadow_caster = SHADOW_GRID.caster_create(self.x + self.x_offset, self.y + 10 + self.y_offset);
            shadow_caster_set_sprite(self.shadow_caster, spr_npc_shadow);
            self.has_alpha_out = false;
            self.image_speed_backup = undefined;

            self.tarball = TarballBuilder(
                    self.x,
                    self.y,
                    4,
                    4,
                    999,
                    CombatTarget.Enemy,
                )
                .set_mask_index(self.sprite_index)
                .set_can_pick_grid_objects(true)
                .set_can_chop_grid_objects(true)
                .set_can_destroy_grid_objects(true)
                .set_shield_break()
                .set_fire()
                .set_in_air()
                .notify(self)
                .set_parent(self)
                .gen();

            function on_hit(rcvr) {
                if rcvr.parent_id.object_index == obj_fire_trigger {
                    rcvr.parent_id.burn();
                } else if rcvr.parent_id.object_index == obj_pq_dragon_forge {
                    rcvr.parent_id.burn();
                }

                TANGO.play("SoundEffects/Objects/Incinerate", rcvr.x, rcvr.y);
            }

            if self.is_last_poof {
                TANGO.play("SoundEffects/Ari/DragonBreathLastPoofSpawn", self.x, self.y);
            } else if self.make_poof_sound {
                var sfx = self.owner == obj_seridia
                    ? "SoundEffects/NPCs/SeridiaSpellPoof"
                    : "SoundEffects/Ari/DragonBreathPoof";
                TANGO.play(sfx, self.x, self.y);
            }
        },
        step: function() {
            if non_cutscene_pause() {
                if self.image_speed_backup == undefined {
                    self.image_speed_backup = self.image_speed;
                }
                self.image_speed = 0;
                return;
            }
            if self.image_speed_backup != undefined {
                self.image_speed = self.image_speed_backup;
                self.image_speed_backup = undefined;
            }

            self.x_offset += self.move_x;
            self.y_offset += self.move_y;

            if self.owner != undefined && instance_exists(self.owner) {
                self.x = self.owner.x + self.x_offset;
                self.y = self.owner.y + self.y_offset;
            } else {
                self.x += self.move_x;
                self.y += self.move_y;
            }

            //
            shadow_caster_set_position(self.shadow_caster, self.x, self.y + 10);
            self.depth = get_instance_depth(self.y + 10);

            if self.has_alpha_out == false && self.image_index >= 5 {
                shadow_caster_set_alpha(self.shadow_caster, 0);
                instance_destroy(self.tarball);
                self.tarball = undefined;

                self.has_alpha_out = true;
            }
        },
        animation_end: function() {
            instance_destroy(self);
        },
        destroy: function() {
            if self.owner != undefined && instance_exists(self.owner) {
                var idx = array_pos(self.owner.fire_breath_effects, self.id);
                array_delete(self.owner.fire_breath_effects, idx, 1);
            }

            if self.tarball != undefined {
                instance_destroy(self.tarball);
            }
        },
        cleanup: function() {
            SHADOW_GRID.caster_remove(self.shadow_caster);
        },
    }
);
