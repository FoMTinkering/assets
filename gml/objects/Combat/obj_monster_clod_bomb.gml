object_create(
    "obj_monster_clod_bomb",
    undefined,
    {
        sprite_index: undefined,
        target_enemy: false,
        mask_index: string_to_asset("spr_monster_rockclod_projectile_main"),
        create: function() {
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
                if self.target == CombatTarget.Player {
                    boom(true);
                    create_animation_effect(x, y, depth + 1, spr_fx_poof1_dirt_once);
                }  else {
                    TANGO.play(self.death_tango, x, y);
                }
                instance_destroy(self);
            }

            //
            function boom(damage_player) {
                new_world_chain()
                    .append(LinkId.Timer, self.delay)
                    .append(LinkId.Function, function(damage_player, dmg, xx, yy, bomb_radius) {
                        TarballBuilder(
                            xx - bomb_radius * 0.5,
                            yy - bomb_radius * 0.5,
                            bomb_radius,
                            bomb_radius,
                            dmg,
                            damage_player ? CombatTarget.Player : CombatTarget.Enemy,
                        )
                        .set_can_pick_grid_objects(true)
                        .set_can_chop_grid_objects(true)
                        .set_can_destroy_grid_objects(true)
                        .set_in_air()
                        .set_timer(3)
                        .gen();
                    }, [damage_player, dmg, self.x, self.y, self.bomb_radius])
            }

            captured = false;
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

            depth = get_instance_depth(y);
            shadow_caster_set_position(self.shadow_caster, x, y);

            if movement_and_collide() != MovementCollisionDirection.NONE {
                TANGO.play(self.death_tango, x, y);
                boom(false);
                instance_destroy(self);
            }
        },
        step_end: function() {
            if game_paused() {
                self.image_speed = 0;
                return;
            }
            self.image_speed = 1;

            if self.receiver.try_take_damage() != undefined {
                if tarball != undefined && instance_exists(tarball) && tarball.target == CombatTarget.Player {
                    boom(true);
                }
                TANGO.play("SoundEffects/Enemies/TakeDamageRockStrong");
                instance_destroy(self);
            }
        },
        destroy: function() {
            if self.captured {
                return;
            }
            CAMERA.add_trauma(0.3);
            create_animation_effect(
                x,
                y,
                depth - 15,
                bomb_fx
            );

            TANGO.play("SoundEffects/Objects/Explosion", x, y);

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
