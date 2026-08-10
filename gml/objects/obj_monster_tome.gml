object_create(
    "obj_monster_tome",
    object_reserve("par_monster"),
    {
        sprite_index: spr_monster_flying_tome_main_idle_south,
        create: function() {
            event_inherit(ObjectEvent.Create);
            depth = get_instance_depth(y, z);
            self.check_collision = function(xx, yy) {
                if self.can_overlap_ari == false && overlap_point(xx, yy, obj_ari) {
                    return true;
                }

                var ni = GRID.try_node_index_for_room_position(xx, yy);
                return ni == undefined || (GRID.node_collideable[ni] && GRID.node_can_jump_over[ni] == false);
            }

            can_overlap_ari = true;
            collision_data_last_frame = MovementCollisionDirection.NONE;

            function normalized_cardinal() {
                return round(self.dir / 90) mod 4;
            }

            self.z = self.config.height;
            self.light = instance_create_depth(self.x, self.y, self.depth, obj_light_xs);
            self.mask_index = spr_monster_flying_tome_main_idle_south;

            self.receiver.offset = Vec2Zero();
            self.reflected = false;
            fsm = StateMachineBuilder(TomeState.LEN)
                .add_state(StateBuilder(TomeState.Idle)
                    .create(function() {
                        self.acknowledged = false;
                    })
                    .start(function() {
                        owner.set_state_sprite(true, TomeState.Idle);
                    })
                    .step(function() {
                        if self.acknowledged == false {
                            fsm.change_state(TomeState.Acknowledgment);
                            self.acknowledged = true;
                        } else {
                            fsm.change_state(TomeState.Windup);
                        }
                    })
                    .spawn()
                )
                .add_state(StateBuilder(TomeState.Acknowledgment)
                    .start(function() {
                        owner.play_state_tango();
                        owner.set_state_sprite(true, TomeState.Acknowledgment);
                    })
                    .step(function() {
                        if fsm.state_frame >= owner.config.acknowledgment {
                            fsm.change_state(TomeState.Idle);
                        }
                    })
                    .spawn()
                )
                .add_state(StateBuilder(TomeState.Windup)
                    .start(function() {
                        owner.set_state_sprite();
                        need_vfx = true;
                    })
                    .step(function() {
                        owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                        owner.set_state_sprite(false, TomeState.Windup);

                        if self.need_vfx
                            && owner.image_index >= owner.config.flash_sfx_frame_start
                        {
                            self.need_vfx = false;
                            owner.play_state_tango();
                        }
                    })
                    .anim_end(function() {
                        fsm.blackboard.insert("attack", true);
                        if owner.hit_points > 0 {
                            fsm.change_state(TomeState.Flying);
                        }
                    })
                    .spawn()
                )
                .add_state(StateBuilder(TomeState.Flying)
                    .create(function() {
                        owner.reflected = false;
                    })
                    .start(function() {
                        self.attack = fsm.blackboard.take("attack");
                        owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                        self.current_speed = owner.config.flying_speed;
                        self.play_chomp = true;

                        if self.attack == false {
                            owner.dir += 180;
                            self.current_speed = owner.config.flying_speed * 3;
                        }

                        on_hit = function() {
                            fsm.change_state(TomeState.GentleStun);
                            owner.knockback_move = Vec2(owner.x - obj_ari.x, owner.y - obj_ari.y);
                            owner.knockback_move.normalized();
                            owner.knockback_move.set_scale(owner.config.on_hit_knockback);
                        }

                        if self.attack {
                            owner.set_state_sprite(true, TomeState.Flying);
                            self.tarball = TarballBuilder(owner.x, owner.y, 16, 16, owner.config.damage)
                                .set_offset(-8, -8)
                                .set_parent(owner)
                                .set_in_air()
                                .notify(self)
                                .set_provenance(owner.monster_id, owner.stats_entry)
                                .gen();
                        } else {
                            self.tarball = undefined;
                        }
                    })
                    .step(function() {
                        if self.play_chomp && owner.image_index >= 1 {
                            owner.play_state_tango();
                            self.play_chomp = false;
                        }

                        owner.dir -= min(
                            abs(angle_difference(owner.dir, point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y))), owner.config.steering
                        ) * sign(angle_difference(owner.dir, point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y)));
                        owner.dir %= 360;
                        owner.move = Vec2(lengthdir_x(self.current_speed, owner.dir), lengthdir_y(self.current_speed, owner.dir));

                        if fsm.state_frame >= owner.config.flying_timeout {
                            fsm.change_state(TomeState.Idle);
                        }
                    })
                    .anim_end(function() {
                        self.play_chomp = self.attack;
                    })
                    .stop(function() {
                        if self.tarball != undefined {
                            instance_destroy(self.tarball);
                            self.tarball = undefined;
                        }
                    })
                    .spawn()
                )
                .add_state(StateBuilder(TomeState.GentleStun)
                    .start(function() {
                        owner.set_state_sprite();
                        owner.play_state_tango();
                    })
                    .step(function() {
                        if fsm.state_frame >= owner.config.idle_override_len {
                            fsm.change_state(TomeState.Windup);
                        }
                    })
                    .spawn()
                )
                .add_state(StateBuilder(TomeState.Stunned)
                    .start(function() {
                        self.blink_timing = owner.config.blink_timing;
                        self.landed = false;
                        owner.dir = 270;
                        owner.can_overlap_ari = false;
                        owner.play_state_tango();
                    })
                    .step(function() {
                        if owner.z < 0 {
                            owner.z += 1;

                            if owner.z >= 0 {
                                owner.try_spawn_stars(-16);
                                TANGO.play("SoundEffects/Enemies/EnemyDizzy", owner.x, owner.y);
                                var ni = GRID.try_node_index_for_room_position(owner.x, owner.y);
                                if ni == undefined || GRID.node_terrain_kind[ni] != TerrainKind.Ground {
                                    fsm.blackboard.set("fell_to_death", true);
                                    fsm.change_state(TomeState.Dying);
                                } else {
                                    owner.set_state_sprite(true, TomeState.Stunned);
                                    self.landed = true;
                                    create_animation_effect(owner.x, owner.y, owner.depth, spr_fx_small_monster_land);
                                }
                                owner.z = 0;
                            }
                        }

                        if fsm.state_frame > owner.config.stun_star_duration {
                            owner.try_despawn_stars();

                            if owner.sprite_index != owner.config.misc_sprites.stun_attack_start {
                                owner.sprite_index = owner.config.misc_sprites.stun_attack_start;
                                TANGO.play(owner.config.misc_tango.struggle, owner.x, owner.y);
                            }

                            if fsm.state_frame % self.blink_timing == 0 {
                                owner.image_speed = 1;
                                owner.image_index = 0;
                                self.blink_timing -= 5;
                            }
                        }

                        if fsm.state_frame - owner.config.stun_star_duration > owner.config.stun_blink_duration {
                            fsm.change_state(TomeState.StunAttack);
                        }
                    })
                    .anim_end(function() {
                        if self.landed {
                            owner.image_index = sprite_get_number(owner.sprite_index);
                            owner.image_speed = 0;
                        }
                    })
                    .stop(function() {
                        owner.try_despawn_stars();
                        owner.image_speed = 1;
                    })
                    .spawn()
                )
                .add_state(StateBuilder(TomeState.StunAttack)
                    .start(function() {
                        owner.set_state_sprite();
                        self.wind_vfx = create_animation_effect(owner.x, owner.y, owner.depth, spr_fx_monster_flying_tome_wind_attack_loop);
                        self.wind_vfx.live_on_anim_end = true;
                        self.wind_vfx.image_alpha = 0;
                        self.tarball = undefined;
                        self.tornado_sfx = undefined;
                        self.set_loop = true;
                    })
                    .step(function() {
                        if self.wind_vfx != undefined && instance_exists(self.wind_vfx) {
                            self.wind_vfx.depth = owner.depth + 1;
                            if fsm.state_frame >= owner.config.wind_attack_duration {
                                if self.tarball != undefined && instance_exists(self.tarball) {
                                    instance_destroy(self.tarball);
                                }

                                if self.wind_vfx.image_alpha > 0 {
                                    self.wind_vfx.image_alpha -= 0.05;
                                }

                                if owner.sprite_index != owner.config.misc_sprites.stunned_end {
                                    owner.sprite_index = owner.config.misc_sprites.stunned_end;
                                    owner.image_index = 0;
                                }
                            } else {
                                self.wind_vfx.image_alpha = clamp(self.wind_vfx.image_alpha + 0.1, 0, 1);

                                if self.tarball == undefined && self.wind_vfx.image_alpha > 0.2 {
                                    self.tarball = TarballBuilder(owner.x, owner.y, owner.config.get_up_attack_radius, owner.config.get_up_attack_radius, owner.config.damage)
                                        .set_offset(-owner.config.get_up_attack_radius / 2, -owner.config.get_up_attack_radius)
                                        .set_parent(owner)
                                        .set_in_air()
                                        .set_provenance(owner.monster_id, owner.stats_entry)
                                        .gen();
                                    self.tornado_sfx = owner.play_state_tango();
                                }

                                owner.receiver.offset.y = owner.z - 8;
                                owner.light.y = owner.y + owner.z - 18;
                            }
                        }
                    })
                    .anim_end(function() {
                        if self.set_loop {
                            owner.sprite_index = owner.config.misc_sprites.stunned_loop;
                            self.set_loop = false;
                        } else if owner.sprite_index == owner.config.misc_sprites.stunned_end {
                            owner.z = owner.config.height;
                            fsm.change_state(TomeState.Idle);
                            if self.wind_vfx != undefined && instance_exists(self.wind_vfx) {
                                self.wind_vfx.live_on_anim_end = false;
                            }
                        }
                    })
                    .stop(function() {
                        if self.tarball != undefined && instance_exists(self.tarball) {
                            instance_destroy(self.tarball);
                        }

                        if self.wind_vfx != undefined && instance_exists(self.wind_vfx) {
                            self.wind_vfx.live_on_anim_end = false;
                        }

                        if self.tornado_sfx != undefined {
                            TANGO.request_stop(self.tornado_sfx);
                        }

                        owner.can_overlap_ari = true;
                    })
                    .spawn()
                )
                .add_state(StateBuilder(TomeState.Hurt)
                    .start(function() {
                        owner.set_state_sprite(true, TomeState.Hurt);
                    })
                    .step(function() {
                        if fsm.state_frame >= owner.config.hurt_frames {
                            fsm.change_state(TomeState.Idle);
                        }
                    })
                    .spawn()
                )
                .add_state(StateBuilder(TomeState.Dying)
                    .start(function() {
                        owner.play_state_tango();
                        owner.set_state_sprite(true, TomeState.Dying);
                        CAMERA.add_trauma(0.2);
                        owner.play_state_tango();
                        self.real_pos = Vec2(owner.x, owner.y);
                        self.poof = false;
                        self.trauma = 0.5;
                        owner.show_damage = 10000;

                        if fsm.blackboard.try_take("fell_to_death") != undefined {
                            owner.sprite_index = owner.config.misc_sprites.pit_kill;
                        }
                    })
                    .step(function() {
                        if poof == false && fsm.state_frame >= 60 {
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
                .spawn(TomeState.Idle, self, Map());
        },
        step: function() {
            event_inherit(ObjectEvent.Step);

            if game_paused() {
                return;
            }

            if self.light != undefined && instance_exists(self.light) {
                self.light.x = self.x;
                self.light.y = self.y + self.z - 8;
                self.light.depth = self.depth - 1;
            }

            self.receiver.offset.y = self.z;

            fsm.step();

            if !instance_exists(self) {
                return;
            }

            depth = get_instance_depth(y, z);

            apply_friction();
            self.move.set_scale(self.status_effects.get_effect_value(StatusEffectId.Frozen));
            self.move.set_add(self.knockback_move);
            self.knockback_move.set_scale(0.9);

            push_and_shove(par_monster, self.config.push_radius, self.config.push_force);
            push_from(obj_ari, self.config.pushed_radius, self.config.push_force * sqrt(obj_ari.move.sqrd_magnitude()));
            var result = movement_and_collide(par_monster);

            if result && self.fsm.current_state_id() == TomeState.Flying && self.hit_points > 0 {
                if self.reflected {
                    self.fsm.change_state(TomeState.Stunned);
                    self.reflected = false;
                } else if self.fsm.state_frame > 15 {
                    self.fsm.blackboard.insert("idle_override_len", self.config.idle_override_len);

                    var knocked = false;
                    if has_flag(result, MovementCollisionDirection.HORIZONTAL) {
                        knocked = true;
                        if self.dir >= 90 && self.dir < 270 {
                            self.knockback_move = Vec2(1, 0);
                        } else {
                            self.knockback_move = Vec2(-1, 0);
                        }
                    } else if has_flag(result, MovementCollisionDirection.VERTICAL) {
                        knocked = true;
                        if self.dir >= 0 && self.dir < 180 {
                            self.knockback_move = Vec2(0, 1);
                        } else {
                            self.knockback_move = Vec2(0, -1);
                        }
                    }

                    if knocked {
                        self.knockback_move.normalized();
                        self.knockback_move.set_scale(self.config.on_hit_knockback * 0.5);
                    }

                    self.fsm.change_state(TomeState.GentleStun);
                }
            }
        },
        step_end: function() {
            if game_paused() {
                return;
            }

            self.process_status();

            shadow_caster_set_position(self.shadow_caster, x, y);
            process_white_vfx();
            shadow_caster_set_image(self.shadow_caster, self.image_index);

            var flipper = 1;
            if self.dir >= 90 && self.dir < 270 {
                flipper = -1;
            }
            shadow_caster_set_image_xscale(self.shadow_caster, flipper);

            fsm.end_step();

            if !instance_exists(self) {
                return;
            }

            var csi = fsm.current_state_id();

            if self.hit_points > 0 {
                var took_any_damage = false;

                while true {
                    var next_dmg = self.receiver.try_take_damage();
                    if next_dmg == undefined {
                        break;
                    }

                    if next_dmg.status != ReceiverStatus.Normal {
                        continue;
                    }
                    took_any_damage = true;
                    self.hit_points -= next_dmg.tarball.damage;
                    self.stats_entry.damage_taken += next_dmg.tarball.damage;
                    self.stats_entry.damage_taken_count += 1;

                    self.process_tarball_status(next_dmg.tarball);

                    spawn_damage_numbers(
                        self,
                        self.config.damage_number_offset + self.z,
                        next_dmg.tarball.damage,
                        next_dmg.tarball.damage_flag(),
                    );

                    TANGO.play(self.config.misc_tango.strong_damage, x, y);
                    next_dmg.tarball.calculate_knockback(x, y, self.move);

                    CAMERA.camera_stop = 1;

                    if next_dmg.tarball.critical {
                        monster_critical_fx(self);
                        set_rumble(RumbleKind.SwordStrong);
                    } else {
                        set_rumble(RumbleKind.SwordWeak);
                    }
                }

                if took_any_damage {
                    spawn_particle_blood(self.x, self.y + self.z, depth, self.config.misc_sprites.giblet);
                    self.show_damage = 30;
                    switch csi {
                        case TomeState.Idle:
                        case TomeState.Acknowledgment:
                        case TomeState.Hurt:
                        case TomeState.GentleStun:
                            self.fsm.change_state(TomeState.Hurt);
                            break;
                        case TomeState.Flying:
                            self.fsm.blackboard.insert("attack", false);
                            self.reflected = true;
                            self.sprite_index = self.get_cardinal() == Cardinal.North ? self.config.misc_sprites.hurt_alt_north : self.config.misc_sprites.hurt_alt_south;
                            self.fsm.change_state(TomeState.Flying);
                            break;
                        case TomeState.Stunned:
                        case TomeState.StunAttack:
                        case TomeState.Windup:
                        case TomeState.Dying:
                            break;
                        default: impossible("unexpected current state id!");
                    }

                    self.patience.value = PATIENCE_DAMAGED;

                    if self.hit_points <= 0 {
                        self.fsm.change_state(TomeState.Dying);
                    }
                }
            } else if csi != TomeState.Dying {
                self.fsm.change_state(TomeState.Dying);
            }
        },
        destroy: function() {
            event_inherit(ObjectEvent.Destroy);

            if self.light != undefined && instance_exists(self.light) {
                instance_destroy(self.light);
                self.light = undefined;
            }
        },
    }
);
