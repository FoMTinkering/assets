object_create(
    "obj_monster_statue",
    object_reserve("par_monster"),
    {
        sprite_index: undefined,
        mask_index: string_to_asset("spr_monster_living_griffin_statue_main_idle_south"),
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.x = self.x div 16 * 16;
            self.y = self.y div 16 * 16;

            self.home = Vec2(self.x, self.y);

            self.tumble_spd = undefined;
            self.tumble_spd_scale = 0;
            self.tumble_spd_reduction = undefined;
            self.tumble_hits = 0;
            self.reflected = -1;

            self.tumbled = false;
            self.hardened = false;

            function traumatize(amount) {
                var distance = point_distance(self.x, self.y, obj_ari.x, obj_ari.y);
                distance -= self.config.trauma_range_full;

                amount *= 1.0 - clamp(inverse_lerp(distance, self.config.trauma_range_buffer, 0), 0, 1);

                CAMERA.add_trauma(amount);
            }

            setup_move_and_collide(1.0);
            fsm = StateMachineBuilder(StatueState.LEN)
                .add_state(
                    StateBuilder(StatueState.Acknowledgment)
                        .start(function() {
                            owner.set_state_sprite();
                            self.original_pos = Vec2(owner.x, owner.y);
                            self.jspd_current = -5;
                            self.grav = 0;
                            owner.play_state_tango();
                            TANGO.play(owner.config.misc_tango.presentation, owner.x, owner.y);
                        })
                        .step(function() {
                            if self.jspd_current < 0 {
                                owner.z += self.jspd_current;
                                self.jspd_current += owner.config.jump_speed_gain;
                            }
                            if self.grav < 3 {
                                self.grav += owner.config.gravity_gain;
                            }
                            if owner.z < 0 {
                                owner.z += self.grav;

                                if owner.z >= 0 {
                                    owner.z = 0;
                                    owner.traumatize(0.5);

                                    fsm.change_state(StatueState.Chase);
                                }
                            }
                        })
                        .anim_end(function() {
                            owner.image_speed = 0;
                            owner.image_index = sprite_get_number(owner.sprite_index) - 1;
                        })
                        .stop(function() {
                            owner.x = self.original_pos.x;
                            owner.y = self.original_pos.y;
                            owner.image_speed = 1;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(StatueState.Idle)
                        .create(function() {
                            self.acknowledged = false;
                        })
                        .start(function() {
                            owner.set_state_sprite(true, StatueState.Idle);
                        })
                        .step(function() {
                            if owner.aggro {
                                if owner.acknowledgement_reset && self.acknowledged == false {
                                    self.acknowledged = true;
                                    fsm.change_state(StatueState.Acknowledgment);
                                } else {
                                    fsm.change_state(StatueState.Chase);
                                }
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(StatueState.Chase)
                        .start(function() {
                            owner.can_overlap_ari = true;
                            owner.tumble_hits = 0;
                            owner.set_state_sprite();
                            self.time = 0;
                            self.jspd_current = 0;
                            if owner.tumbled {
                                self.jspd_current = -2;
                                owner.tumbled = false;
                                owner.play_state_tango();
                            }
                            self.grav = 0;
                            self.move_position = false;
                            self.move_x = 0;
                            self.move_y = 0;
                            self.chase_rate = owner.config.chase_rate;
                            self.path = undefined;
                            self.stuck = 0;
                            self.previous_jump = Vec2Zero();
                            //
                            self.priority = 0;

                            self.go_home = false;

                            self.tarball = undefined;

                            self.on_hit = function() {
                                self.fsm.change_state(StatueState.Tumbling);

                                owner.tumble_spd = Vec2(owner.x - obj_ari.x, owner.y - obj_ari.y).normalize();
                                owner.tumble_spd.set_scale(owner.config.tumble_hit_speed);
                                owner.tumble_spd_scale = owner.config.tumble_hit_speed;
                                TANGO.play("SoundEffects/Enemies/GriffinStatue/HitsAri", owner.x, owner.y);
                            }

                            var bbox_dims = shape_get_dimensions(owner.config.hitbox);
                            var w = bbox_dims[0];
                            var h = bbox_dims[1];
                            self.tarball = TarballBuilder(owner.x, owner.y, w + 2, h + 2, owner.config.damage)
                                .set_parent(owner)
                                .notify(self)
                                .set_in_air()
                                .set_offset(-w * 0.5 - 2, -h * 0.5 - 2)
                                .set_can_pick_grid_objects(true)
                                .set_can_destroy_grid_objects(true)
                                .set_provenance(owner.monster_id, owner.stats_entry)
                                .gen();
                        })
                        .step(function() {
                            if self.jspd_current < 0 {
                                owner.z += self.jspd_current;
                                self.jspd_current += owner.config.jump_speed_gain;
                                if self.jspd_current >= 0 {
                                    self.jspd_current = 0;
                                    self.move_position = true;
                                }
                            } else {
                                if self.grav < 3 {
                                    self.grav += owner.config.gravity_gain;
                                }
                                if owner.z < 0 {
                                    owner.z += self.grav;
                                }
                            }

                            if ARI.get_health() <= 0 {
                                return;
                            }

                            if self.move_position {
                                var sign_x = sign(self.move_x);
                                var sign_y = sign(self.move_y);

                                for (var i = 0; i < owner.config.move_speed; i++) {
                                    if self.move_x != 0 {
                                        self.move_x -= sign(self.move_x);
                                        owner.move.x += sign(self.move_x);
                                    }
                                    if self.move_y != 0 {
                                        self.move_y -= sign(self.move_y);
                                        owner.move.y += sign(self.move_y);
                                    }
                                }

                                if self.move_x == 0 && self.move_y == 0 {
                                    self.move_position = false;
                                    owner.traumatize(0.5);

                                    TANGO.play("SoundEffects/Enemies/GriffinStatue/StompGround", owner.x, owner.y);
                                    var ae = create_animation_effect(owner.x, owner.y + 8, -I32_MAX, choose(spr_fx_poof1_dirt_once, spr_fx_poof2_dirt_once));
                                    ae.image_alpha = 0.5;
                                    if irandom(1) == 0 {
                                        ae = create_animation_effect(owner.x + choose(8, -8), owner.y + choose(12, -12), -I32_MAX, choose(spr_fx_poof1_dirt_once, spr_fx_poof2_dirt_once));
                                        ae.image_alpha = 0.5;
                                    }
                                    owner.image_index = 1;
                                }
                            } else if self.jspd_current == 0 {
                                self.time += 1;

                                if self.time % self.chase_rate == 0 {
                                    if point_distance(owner.x, owner.y, self.previous_jump.x, self.previous_jump.y) < 8 {
                                        self.priority = clamp(self.priority + 1, 0, 2);
                                    } else {
                                        self.priority = 0;
                                    }

                                    self.previous_jump = Vec2(owner.x, owner.y);
                                    self.jspd_current = -2;
                                    owner.image_speed = 1;
                                    owner.image_index = 0;

                                    var dist = Vec2(abs(owner.x - obj_ari.x), abs(owner.y - obj_ari.y));
                                    var sign_x = sign(obj_ari.x - owner.x);
                                    var sign_y = sign(obj_ari.y - owner.y);
                                    switch priority {
                                        case 0:
                                            if dist.x > dist.y && self.move_y == 0 {
                                                self.move_x = 24 * sign_x;
                                            } else if self.move_x == 0 {
                                                self.move_y = 24 * sign_y;
                                            }
                                            break;
                                        case 1:
                                            self.move_x = 24 * sign_x;
                                            break;
                                        case 2:
                                            self.move_y = 24 * sign_y;
                                            break;
                                    }
                                }
                            }

                            if owner.z < 0 && owner.image_index > 0 {
                                owner.image_index = 0;
                            }

                            if owner.z > 0 {
                                owner.z = 0;
                                if priority > 0 {
                                    //
                                    owner.move.x += irandom_range(-3, 3);
                                    owner.move.y += irandom_range(-3, 3);
                                }
                            }
                        })
                        .anim_end(function() {
                            owner.image_speed = 0;
                            owner.image_index = sprite_get_number(owner.sprite_index) - 1;
                        })
                        .stop(function() {
                            owner.can_overlap_ari = false;

                            if self.tarball != undefined && instance_exists(self.tarball) {
                                instance_destroy(self.tarball);
                                self.tarball = undefined;
                            }
                            owner.image_speed = 1;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(StatueState.Tumbling)
                        .start(function() {
                            owner.set_state_sprite();
                            owner.play_state_tango();
                            self.grav = 0;
                        })
                        .step(function() {
                            if owner.tumble_spd == undefined {
                                return;
                            }

                            if self.grav < 3 {
                                self.grav += owner.config.gravity_gain;
                            }

                            if owner.z < 0 {
                                owner.z += self.grav;
                                if owner.z > 0 {
                                    owner.z = 0;
                                }
                            }

                            owner.move.x = owner.tumble_spd.x;
                            owner.move.y = owner.tumble_spd.y;
                            if owner.tumble_spd_scale < 1 {
                                owner.image_speed = lerp(owner.image_speed, 0, 0.05);
                            }

                            if owner.tumble_spd_scale <= 0 {
                                fsm.change_state(StatueState.Chase);
                                owner.tumble_spd = undefined;
                            }
                        })
                        .stop(function() {
                            owner.image_speed = 1;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(StatueState.Dying)
                        .start(function() {
                            owner.set_state_sprite();
                            real_pos = Vec2(owner.x, owner.y);
                            trauma = 0.5;
                            owner.show_damage = 1000000;
                            self.poof = false;
                            owner.play_state_tango();
                        })
                        .step(function() {
                            owner.x = self.real_pos.x + self.trauma * self.trauma * perlin_noise_get(0) * sign(perlin_noise_get(50) * 2.0 - 1.0);
                            owner.y = self.real_pos.y + self.trauma * self.trauma * perlin_noise_get(1) * sign(perlin_noise_get(100) * 2.0 - 1.0);
                            self.trauma = approach(self.trauma, 0, FRAME_TIME);
                            if fsm.state_frame >= owner.config.dying_frames && self.poof == false {
                                monster_death_poof(owner);
                                self.poof = true;
                            }
                        })
                        .spawn()
                )
                .spawn(StatueState.Idle, self, Map());
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

            apply_friction();
            self.move.set_scale(self.status_effects.get_effect_value(StatusEffectId.Frozen));
            var move_result = movement_and_collide();

            if self.tumble_spd != undefined {
                if move_result != MovementCollisionDirection.NONE
                    && self.fsm.current_state_id() == StatueState.Tumbling
                    && self.reflected <= 0
                {
                    self.reflected = 2;
                    if has_flag(move_result, MovementCollisionDirection.HORIZONTAL) {
                        self.tumble_spd = Vec2(self.tumble_spd.x * -1, self.tumble_spd.y);
                    } else if has_flag(move_result, MovementCollisionDirection.VERTICAL){
                        self.tumble_spd = Vec2(self.tumble_spd.x, self.tumble_spd.y * -1);
                    }
                } else {
                    self.reflected -= 1;
                }

                if self.tumble_spd_scale > 0 {
                    self.tumble_spd_scale -= self.config.tumble_spd_reduction;
                    self.tumble_spd.normalized();
                    self.tumble_spd.set_scale(self.tumble_spd_scale);
                }
            }
        },
        step_end: function() {
            shadow_caster_set_position(self.shadow_caster, x, y);
            shadow_caster_set_image(self.shadow_caster, self.image_index);

            if game_paused() {
                return;
            }

            self.process_status();
            process_white_vfx();

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

                    self.show_damage = 30;

                    if next_dmg.status != ReceiverStatus.Normal {
                        continue;
                    }

                    spawn_particle_blood(self.x, self.y, self.depth, self.config.misc_sprites.particle);
                    took_any_damage = true;
                    self.hit_points -= next_dmg.tarball.damage;
                    self.stats_entry.damage_taken += next_dmg.tarball.damage;
                    self.stats_entry.damage_taken_count += 1;

                    self.process_tarball_status(next_dmg.tarball);

                    spawn_damage_numbers(
                        self,
                        self.config.damage_number_offset,
                        next_dmg.tarball.damage,
                        next_dmg.tarball.damage_flag(),
                    );

                    next_dmg.tarball.calculate_knockback(x, y, self.move);

                    //
                    CAMERA.camera_stop = 1;


                    if next_dmg.tarball.critical {
                        monster_critical_fx(self);
                        set_rumble(RumbleKind.SwordStrong);
                    } else {
                        set_rumble(RumbleKind.SwordWeak);
                    }
                }

                if took_any_damage {
                    TANGO.play(self.config.misc_tango.damage, self.x, self.y);
                    self.tumble_spd = Vec2(self.x - obj_ari.x, self.y - obj_ari.y).normalize();
                    self.tumble_spd.set_scale(self.config.tumble_hit_speed);
                    self.tumble_spd_scale = self.config.tumble_hit_speed;
                    switch csi {
                        case StatueState.Idle:
                        case StatueState.Acknowledgment:
                        case StatueState.Tumbling:
                        case StatueState.Chase:
                            self.tumbled = true;
                            self.tumble_hits += 1;
                            self.fsm.change_state(StatueState.Tumbling);
                            break;
                        case StatueState.Dying:
                            //
                            break;
                        default: impossible("unexpected current state id!");
                    }

                    self.patience.value = PATIENCE_DAMAGED;

                    if self.hit_points <= 0 {
                        self.fsm.change_state(StatueState.Dying);
                    }
                }
            }
        },
    }
);
