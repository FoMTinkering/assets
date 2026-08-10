object_create(
    "obj_monster_clod_projectile",
    undefined,
    {
        sprite_index: spr_monster_rockclod_projectile_main,
        target_enemy: false,
        create: function() {
            self.xstart = self.x;
            self.ystart = self.y;

            //
            setup_move_and_collide(0.0);
            self.check_collision = function(xx, yy) {
                var ni = GRID.try_node_index_for_room_position(xx, yy);

                if ni == undefined {
                    return true;
                }

                //
                if GRID.node_terrain_kind[ni] != TerrainKind.Ground {
                    return false;
                }

                if GRID.node_collideable[ni] && self.life_time_ticks > 3 {
                    return true;
                }

                return false;
            }

            shadow_caster = SHADOW_GRID.caster_create(x, y);
            shadow_caster_set_sprite(shadow_caster, SHADOW_DICTIONARY.get(sprite_index));

            self.life_time_ticks = 0;

            var t = CombatTarget.Player;
            if self.target_enemy {
                t = CombatTarget.Enemy;
            } else {
                self.target_enemy = false;
            }
            self.target = t;

            var bbox_dims = shape_get_dimensions(spr_monster_clod_projectile_hitbox);
            self.tarball = TarballBuilder(x, y, bbox_dims[0], bbox_dims[1], self.dmg, t)
                .set_offset(-sprite_get_xoffset(spr_monster_clod_projectile_hitbox), -sprite_get_yoffset(spr_monster_clod_projectile_hitbox))
                .set_parent(self)
                .notify(self)
                .set_can_destroy_grid_objects(false)
                .set_provenance(self.monster_id, self.stats_entry)
                .gen();

            self.receiver = create_receiver(x, y, spr_monster_clod_projectile_hitbox, self, {
                target: t == CombatTarget.Player ? CombatTarget.Enemy : CombatTarget.Player,
            });

            function on_hit() {
                if self.receiver.current_iframes > 0 {
                    return;
                }

                //
                //
                //
                if self.target == CombatTarget.Player && ARI.invulnerable_hits > 0 {
                    self.reflect(1);
                } else {
                    CAMERA.add_trauma(0.1, 0.3);
                    TANGO.play(self.death_tango, x, y);
                }

                instance_destroy(self);
            }

            function reflect(dmg, critical=false) {
                set_rumble(RumbleKind.SwordStrong);
                var spd = Vec2(-self.spd.x * 2, -self.spd.y * 2);
                if self.parent_clod != undefined && instance_exists(self.parent_clod) && split_distance != -1 {
                    spd = Vec2(self.x - self.parent_clod.x, self.y - self.parent_clod.y).normalize();
                    spd.set_scale(-self.split_speed * 2);
                }
                var reflector = instance_create_depth(x, y, depth, object_index, {
                    target_enemy: true,
                    spd,
                    parent_clod: self.parent_clod,
                    dmg,
                    sprite_index: self.sprite_index,
                    rock_particle: self.rock_particle,
                    death_tango: self.death_tango,
                    reflect_tango: self.reflect_tango,
                    monster_id: self.monster_id,
                    stats_entry: self.stats_entry,
                    split_angle: self.split_angle,
                    split_distance: self.split_distance,
                    split_depth: 0,
                    split_speed: self.split_speed,
                    split_depreciation: self.split_depreciation
                });

                reflector.tarball.critical = critical;

                if chance_percent(ARI.perk_value(Perk.Rocking)) {
                    reflector.tarball.critical = true;
                }

                if reflector.tarball.critical {
                    reflector.tarball.damage *= 2;
                }

                reflector.receiver.current_iframes = 2;
            }

            self.captured = false;
        },
        step: function() {
            if game_paused() {
                self.image_speed = 0;
                return;
            }
            self.image_speed = 1;
            self.life_time_ticks += 1;

            self.move.x = self.spd.x;
            self.move.y = self.spd.y;

            var collision = movement_and_collide();
            if collision != MovementCollisionDirection.NONE {
                TANGO.play(self.death_tango, x, y);
                instance_destroy(self);
                return;
            }

            depth = get_instance_depth(y);
            shadow_caster_set_position(self.shadow_caster, x, y);

            if self.split_depth > 0 && point_distance(self.xstart, self.ystart, self.x, self.y) >= self.split_distance {
                self.split_depth -= 1;
                self.split_distance *= self.split_depreciation;
                var flip = -1;
                for(var i = 0; i < 2; i++) {
                    var dir = spd.normalize();
                    var radians = arctan2(dir.y, dir.x) + ((pi/180) * split_angle) * flip;
                    dir.x = cos(radians);
                    dir.y = sin(radians);
                    instance_create_depth(
                        self.x,
                        self.y,
                        self.depth - 16,
                        obj_monster_clod_projectile,
                        {
                            spd: dir.scale(self.split_speed),
                            parent_clod: self.parent_clod,
                            dmg,
                            sprite_index,
                            rock_particle,
                            death_tango,
                            reflect_tango,
                            monster_id,
                            stats_entry,
                            split_angle: self.split_angle,
                            split_distance: self.split_distance,
                            split_depth: self.split_depth,
                            split_speed: self.split_speed,
                            split_depreciation: self.split_depreciation
                        }
                    );
                    flip *= -1;
                }
                instance_destroy();
            }
        },
        step_end: function() {
            if game_paused() {
                self.image_speed = 0;
                return;
            }
            self.image_speed = 1;

            var next_dmg = self.receiver.try_take_damage();
            if next_dmg != undefined {
                TANGO.play("SoundEffects/Enemies/TakeDamageRockStrong");

                //
                if self.target_enemy == false && next_dmg.tarball.parent_object() == obj_ari {
                    TANGO.play(self.reflect_tango, x, y);
                    self.reflect(next_dmg.tarball.damage, next_dmg.tarball.critical);

                }
                instance_destroy(self);
            }
        },
        destroy: function() {
            //
            if self.captured {
                return;
            }

            CAMERA.add_trauma(0.2, 0.3);
            create_animation_effect(
                x,
                y,
                depth - 15,
                spr_fx_monster_projectile_hit
            );

            spawn_particle_rockclod_bundle(x, y, depth, self.rock_particle);
            if self.tarball != undefined && instance_exists(self.tarball) {
                instance_destroy(self.tarball);
            }
            instance_destroy(self.receiver);
        },
        cleanup: function() {
            SHADOW_GRID.caster_remove(self.shadow_caster);
        },
    }
);
