object_create(
    "obj_monster_bat",
    object_reserve("par_monster"),
    {
        sprite_index: undefined,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.check_collision = function(xx, yy) {
                //
                if self.can_overlap_ari == false && overlap_point(xx, yy, obj_ari) {
                    return true;
                }

                var ni = GRID.try_node_index_for_room_position(xx, yy);
                return ni == undefined || (GRID.node_collideable[ni] && GRID.node_can_jump_over[ni] == false);
            }

            can_overlap_ari = true;
            collision_data_last_frame = MovementCollisionDirection.NONE;

            function snap_position() {
                self.x = round(self.x / 16) * 16;
                self.y = round(self.y / 16) * 16;
            }
            self.snap_position();

            function distance_to_ari() {
                var d = 0;
                with obj_ari {
                    d = distance_to_point(other.x + 8, other.y + 8);
                }

                return d;
            }

            function normalized_cardinal() {
                return round(self.dir / 90) mod 4;
            }

            function sparkle() {
                create_animation_effect(self.x, self.y + self.z, self.depth, spr_fx_monster_essence_bat_sparkle);
                TANGO.play(self.config.misc_tango.magic_particles, self.x, self.y);
            }

            //
            mask_index = spr_monster_essence_bat_mask_index;

            //
            self.z -= 6;

            fsm = StateMachineBuilder(BatState.LEN)
                .add_state(
                    StateBuilder(BatState.Idle)
                        .start(function() {
                            owner.set_state_sprite(true, BatState.Idle);
                            owner.dir = owner.original_dir;
                        })
                        .step(function() {
                            if owner.aggro {
                                if owner.acknowledgement_reset {
                                    fsm.change_state(BatState.Acknowledgment);
                                } else {
                                    fsm.change_state(BatState.Walk);
                                }
                            }
                        })
                        .anim_end(function() {
                            //
                            if chance_percent(15) {
                                owner.original_dir = irandom(360);
                                owner.dir = owner.original_dir;
                            }
                            owner.set_state_sprite(true, BatState.Idle);
                            owner.play_state_tango();
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(BatState.Acknowledgment)
                        .start(function() {
                            owner.set_state_sprite();
                            owner.play_state_tango();
                            duration = irandom_range(owner.config.acknowledgment[0], owner.config.acknowledgment[1]);

                            last_frame = 0;
                        })
                        .step(function() {
                            //
                            owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                            owner.set_state_sprite(false);

                            if fsm.state_frame >= self.duration {
                                fsm.change_state(BatState.Walk);
                            }

                            //
                            if floor(owner.image_index) == 0 && last_frame != 0 {
                                owner.image_index = last_frame;
                            } else {
                                last_frame = floor(owner.image_index);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(BatState.Walk)
                        .start(function() {
                            to_ari = true;

                            owner.set_state_sprite();
                            want_attack = true;

                            reconsider = 0;
                            owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);

                            var target_x_corner = round(owner.x / 16) * 16;
                            var target_y_corner = round(owner.y / 16) * 16;

                            self.move_dir = point_direction(owner.x, owner.y, target_x_corner, target_y_corner);

                            self.sparkle_timer = 60;
                        })
                        .step(function() {
                            self.reconsider += 1;

                            if self.reconsider >= 16 {
                                //
                                var raw_dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);

                                var raw_cardinal = round(raw_dir / 90) mod 4;
                                var current_cardinal = owner.normalized_cardinal();

                                if !(cardinal_is_vertical(raw_cardinal) xor cardinal_is_vertical(current_cardinal))
                                    || abs(angle_difference(cardinal_to_angle(owner.normalized_cardinal()), raw_dir)) > 80.0
                                {
                                    owner.dir = raw_dir;
                                }

                                var normalized_x_corner = round(owner.x / 16) * 16;
                                var normalized_y_corner = round(owner.y / 16) * 16;
                                var target_x_corner = normalized_x_corner + lengthdir_x(16, cardinal_to_angle(owner.normalized_cardinal()));
                                var target_y_corner = normalized_y_corner + lengthdir_y(16, cardinal_to_angle(owner.normalized_cardinal()));

                                self.move_dir = point_direction(owner.x, owner.y, target_x_corner, target_y_corner);
                                self.reconsider = 0;
                            }

                            if owner.collision_data_last_frame != MovementCollisionDirection.NONE {
                                owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                                self.move_dir = owner.dir;
                            }

                            self.sparkle_timer -= 1;
                            if self.sparkle_timer <= 0 {
                                owner.sparkle();
                                self.sparkle_timer = 60;
                            }

                            owner.move.x = lengthdir_x(owner.config.speed, self.move_dir);
                            owner.move.y = lengthdir_y(owner.config.speed, self.move_dir);

                            owner.set_state_sprite(false);
                        })
                        .end_step(function() {
                            var xx_diff = abs(owner.x - obj_ari.x);
                            var yy_diff = abs(owner.y - obj_ari.y);

                            var value;
                            if xx_diff > yy_diff {
                                value = xx_diff;
                                if yy_diff > 8 {
                                    return;
                                }
                            } else {
                                value = yy_diff;

                                if xx_diff > 8 {
                                    return;
                                }
                            }

                            if value <= owner.config.attack_radius {
                                fsm.change_state(BatState.Windup);
                            }
                        })
                        .anim_end(function() {
                            owner.play_state_tango();
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(BatState.Windup)
                        .start(function() {
                            owner.set_state_sprite();
                            self.windup_sound = owner.play_state_tango();

                            duration = irandom_range(owner.config.windup_duration[0], owner.config.windup_duration[1]);
                        })
                        .step(function() {
                            //
                            owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                            owner.set_state_sprite(false);

                            if fsm.state_frame >= self.duration {
                                fsm.change_state(BatState.Attack);
                            }
                        })
                        .draw(function() {
                            var card = owner.normalized_cardinal();
                            if card == Cardinal.North {
                                with owner {
                                    draw_sprite(self.config.misc_sprites.breath_north, self.image_index, self.x, self.y + self.z);
                                }
                            }
                        })
                        .draw_after(function() {
                            var breath_sprite = undefined;
                            switch owner.normalized_cardinal() {
                                case Cardinal.East:
                                    breath_sprite = owner.config.misc_sprites.breath_east;
                                    break;
                                case Cardinal.West:
                                    breath_sprite = owner.config.misc_sprites.breath_west;
                                    break;
                                case Cardinal.North:
                                    //
                                    break;
                                case Cardinal.South:
                                    breath_sprite = owner.config.misc_sprites.breath_south;
                                    break;
                            }

                            if breath_sprite != undefined {
                                draw_sprite_ext(breath_sprite, owner.image_index, owner.x, owner.y + owner.z, 1, 1, 0, c_white, 1);
                            }
                        })
                        .stop(function() {
                            TANGO.request_stop(self.windup_sound);
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(BatState.Flee)
                        .start(function() {
                            owner.image_speed = 1.25;
                            owner.play_state_tango();
                            owner.set_state_sprite();

                            self.flee_timer = irandom_range(owner.config.flee_timer[0], owner.config.flee_timer[1]);
                            if fsm.blackboard.try_take("short_flee", false) {
                                self.flee_timer *= 0.25;
                            }
                        })
                        .step(function() {
                            owner.dir = point_direction(obj_ari.x, obj_ari.y, owner.x, owner.y);
                            owner.move.x = lengthdir_x(owner.config.flee_speed, owner.dir);
                            owner.move.y = lengthdir_y(owner.config.flee_speed, owner.dir);

                            if (fsm.state_frame % 60) == 0 {
                                owner.sparkle();
                            }

                            if fsm.state_frame >= self.flee_timer {
                                fsm.change_state(BatState.Acknowledgment);
                            }
                        })
                        .anim_end(function() {
                            owner.play_state_tango();
                        })
                        .stop(function() {
                            owner.image_speed = 1;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(BatState.Attack)
                        .start(function() {
                            owner.set_state_sprite();
                            owner.play_state_tango();

                            self.made_projectile = false;
                            self.made_variant_projectiles = false;

                            self.in_idle = false;
                            duration = irandom_range(owner.config.attack_duration[0], owner.config.attack_duration[1]);
                            knockback = owner.config.knockback;
                        })
                        .step(function() {
                            //
                            if self.made_projectile == false {
                                owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                                self.looking_dir = owner.dir;
                            }

                            if self.made_projectile == false && owner.image_index >= 5 {
                                self.made_projectile = true;

                                var offset_x = lengthdir_x(16, cardinal_to_angle(owner.normalized_cardinal()));
                                var offset_y = lengthdir_y(16, cardinal_to_angle(owner.normalized_cardinal()));
                                var secondary_offset = owner.normalized_cardinal() == Cardinal.North || owner.normalized_cardinal() == Cardinal.South ? 180 : 0;
                                instance_create_depth(
                                    owner.x + offset_x,
                                    owner.y + offset_y - 6,
                                    -1000,
                                    obj_monster_bat_sonic_attack,
                                    {
                                        dir: cardinal_to_angle(owner.normalized_cardinal()),
                                        damage: owner.config.damage,
                                        monster_id: owner.monster_id,
                                        stats_entry: owner.stats_entry,
                                        mask_index: spr_fx_monster_essence_bat_sonic_attack,
                                        dir_offset: secondary_offset,
                                        tango_asset: owner.config.misc_tango.projectile_spawn
                                    }
                                );

                                if owner.config.variant_attack {
                                    instance_create_depth(
                                        owner.x + lengthdir_x(16, cardinal_to_angle(owner.normalized_cardinal()) + 45) + lengthdir_x(16, cardinal_to_angle(owner.normalized_cardinal()) + 90),
                                        owner.y + lengthdir_y(16, cardinal_to_angle(owner.normalized_cardinal()) + 45) + lengthdir_y(16, cardinal_to_angle(owner.normalized_cardinal()) + 90) - 6,
                                        -1000,
                                        obj_monster_bat_sonic_attack,
                                        {
                                            dir: cardinal_to_angle(owner.normalized_cardinal()) + 45,
                                            damage: owner.config.damage,
                                            monster_id: owner.monster_id,
                                            stats_entry: owner.stats_entry,
                                            sprite_index: spr_fx_monster_essence_bat_sonic_attack_diagonal,
                                            mask_index: spr_fx_monster_essence_bat_sonic_attack,
                                            dir_offset: 45 + secondary_offset,
                                            tango_asset: owner.config.misc_tango.projectile_spawn
                                        }
                                    );

                                    instance_create_depth(
                                        owner.x + lengthdir_x(16, cardinal_to_angle(owner.normalized_cardinal()) - 45) - lengthdir_x(16, cardinal_to_angle(owner.normalized_cardinal()) + 90),
                                        owner.y + lengthdir_y(16, cardinal_to_angle(owner.normalized_cardinal()) - 45) - lengthdir_y(16, cardinal_to_angle(owner.normalized_cardinal()) + 90) - 6,
                                        -1000,
                                        obj_monster_bat_sonic_attack,
                                        {
                                            dir: cardinal_to_angle(owner.normalized_cardinal()) - 45,
                                            damage: owner.config.damage,
                                            monster_id: owner.monster_id,
                                            stats_entry: owner.stats_entry,
                                            sprite_index: spr_fx_monster_essence_bat_sonic_attack_diagonal,
                                            mask_index: spr_fx_monster_essence_bat_sonic_attack,
                                            dir_offset: 225 + secondary_offset,
                                            tango_asset: owner.config.misc_tango.projectile_spawn
                                        }
                                    );
                                }
                            }

                            if self.made_projectile {
                                owner.move.x = lengthdir_x(self.knockback, self.looking_dir - 180);
                                owner.move.y = lengthdir_y(self.knockback, self.looking_dir - 180);

                                self.knockback *= owner.config.knockback_decline;
                            }

                            if self.in_idle {
                                self.duration -= 1;
                                if self.duration <= 0 {
                                    fsm.change_state(BatState.Flee);
                                }
                            }
                        })
                        .anim_end(function() {
                            if self.in_idle == false {
                                self.in_idle = true;
                                owner.set_state_sprite(true, BatState.Idle);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(BatState.Hurt)
                        .start(function() {
                            owner.set_state_sprite();
                            CAMERA.add_trauma(0.1);
                            owner.show_damage = 1000;
                        })
                        .step(function() {
                            if fsm.state_frame >= 1 && owner.hit_points <= 0 {
                                fsm.change_state(BatState.Dying);
                            }
                        })
                        .anim_end(function() {
                            fsm.blackboard.insert("short_flee", true);
                            fsm.change_state(BatState.Flee);
                        })
                        .stop(function() {
                            owner.show_damage = 0;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(BatState.Dying)
                        .start(function() {
                            real_pos = Vec2(owner.x, owner.y);
                            CAMERA.add_trauma(0.2);
                            owner.set_state_sprite();
                            owner.play_state_tango();

                            poof = false;
                            trauma = 0.5;
                            owner.show_damage = 10000;
                        })
                        .step(function() {
                            if poof == false && owner.image_index >= 1 {
                                monster_death_poof(owner);
                                poof = true;
                            } else {
                                owner.x = self.real_pos.x + self.trauma * self.trauma * perlin_noise_get(0) * sign(perlin_noise_get(50) * 2.0 - 1.0);
                                owner.y = self.real_pos.y + self.trauma * self.trauma * perlin_noise_get(1) * sign(perlin_noise_get(100) * 2.0 - 1.0);

                                self.trauma = approach(self.trauma, 0, FRAME_TIME);
                            }
                        })
                        .spawn()
                )
                .spawn(BatState.Idle, self, Map());
        },
        step: function() {
            event_inherit(ObjectEvent.Step);

            if game_paused() {
                return;
            }

            fsm.step();

            if !instance_exists(self) {
                return;
            }

            depth = get_instance_depth(y, z);
            self.move.set_scale(self.status_effects.get_effect_value(StatusEffectId.Frozen));
            self.collision_data_last_frame = movement_and_collide(par_monster);
        },
        step_end: function() {
            if game_paused() {
                return;
            }

            shadow_caster_set_position(self.shadow_caster, x, y);
            process_white_vfx();
            shadow_caster_set_image(self.shadow_caster, self.image_index);
            self.process_status();

            var flipper = 1;
            if self.dir >= 90 && self.dir < 270 {
                flipper = -1;
            }
            shadow_caster_set_image_xscale(self.shadow_caster, flipper);

            fsm.end_step();
            if instance_exists(self) == false {
                return;
            }
            var csi = fsm.current_state_id();

            if self.hit_points > 0 {
                while true {
                    var next_dmg = self.receiver.try_take_damage();
                    if next_dmg == undefined {
                        break;
                    }

                    if next_dmg.status != ReceiverStatus.Normal {
                        continue;
                    }

                    self.process_tarball_status(next_dmg.tarball);
                    self.hit_points -= next_dmg.tarball.damage;

                    spawn_damage_numbers(
                        self,
                        self.config.damage_number_offset,
                        next_dmg.tarball.damage,
                        next_dmg.tarball.damage_flag(),
                    );

                    var on_hit = self.config.misc_tango.strong_damage;
                    if csi == BatState.Attack && self.hit_points > 0 {
                        on_hit = self.config.misc_tango.weak_damage;
                    }

                    TANGO.play(on_hit, x, y);
                    next_dmg.tarball.calculate_knockback(x, y, self.move);

                    //
                    CAMERA.camera_stop = 1;

                    self.knockback_move.set(self.move);
                    self.knockback_move.set_scale(0.4);
                    self.fsm.change_state(BatState.Hurt);

                    if next_dmg.tarball.critical {
                        monster_critical_fx(self);
                    }
                    self.patience.value = PATIENCE_DAMAGED;
                }
            } else if csi != BatState.Dying {
                self.fsm.change_state(BatState.Dying);
            }
        },
    }
);
