object_create(
    "obj_monster_cat",
    object_reserve("par_monster"),
    {
        sprite_index: undefined,
        mask_index: string_to_asset("spr_monster_sapling_main_idle_south"),
        create: function() {
            event_inherit(ObjectEvent.Create);
            watered = false;
            light_damage = 0;
            time_in_light = 0;
            tween_to_column = undefined;
            tween_time = undefined;
            column = undefined;
            lut_texture = self.config.misc_sprites.lut;
            var uvs_full = sprite_get_uvs(self.config.misc_sprites.lut, 0);
            uvs = [uvs_full[0], uvs_full[1]];

            freezer_audio_handle = undefined;

            fsm = StateMachineBuilder(CatState.LEN)
                .add_state(
                    StateBuilder(CatState.Idle)
                        .create(function() {
                            self.acknowledged = false;
                        })
                        .start(function() {
                            owner.set_state_sprite(true, CatState.Idle);
                            TANGO.play("SoundEffects/Enemies/EnemyAlerted", owner.x, owner.y);
                        })
                        .step(function() {
                            if owner.aggro {
                                if self.acknowledged {
                                    fsm.change_state(CatState.Walk);
                                } else {
                                    fsm.change_state(CatState.Acknowledgment);
                                    self.acknowledged = true;
                                }
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(CatState.Acknowledgment)
                        .start(function() {
                            owner.set_state_sprite();
                            duration = owner.config.acknowledgment_duration;
                        })
                        .step(function() {
                            duration -= 1;
                            if duration <= 0 {
                                fsm.change_state(CatState.Idle);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(CatState.Walk)
                        .start(function() {
                            spd = owner.config.walk_speed;
                            owner.set_state_sprite();
                        })
                        .step(function() {
                            var dir = undefined;

                            if owner.aggro {
                                if point_distance(owner.x, owner.y, obj_ari.x, obj_ari.y) > owner.config.charge_range {
                                    dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                                } else {
                                    fsm.change_state(CatState.Windup);
                                }
                            } else {
                                dir = point_direction(owner.x, owner.y, owner.original_spawn_pos.x, owner.original_spawn_pos.y);

                                if point_distance(owner.x, owner.y, owner.original_spawn_pos.x, owner.original_spawn_pos.y) <= 1 {
                                    owner.x = owner.original_spawn_pos.x;
                                    owner.y = owner.original_spawn_pos.y;
                                    owner.dir = 270;

                                    fsm.change_state(CatState.Idle);
                                }
                            }

                            if dir != undefined {
                                owner.move.x = lengthdir_x(spd, dir);
                                owner.move.y = lengthdir_y(spd, dir);
                                owner.dir = dir;
                                owner.set_state_sprite(false);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(CatState.Windup)
                        .start(function() {
                            owner.set_state_sprite();
                            TANGO.play("SoundEffects/Enemies/LavaCat/PounceWarning", owner.x, owner.y);
                            duration = irandom_range(owner.config.windup_duration[0], owner.config.windup_duration[1]);
                        })
                        .step(function() {
                            owner.set_state_sprite(false);
                            owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                            if fsm.state_frame >= duration {
                                fsm.change_state(CatState.Attack);
                            }
                        })
                        .stop(function() {
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(CatState.Attack)
                        .start(function() {
                            //
                            //
                            //
                            //
                            speed_indexes = [2, 3, 1, 0, 0];
                            owner.can_overlap_ari = true;
                            owner.image_speed = 0;
                            owner.set_state_sprite(false);
                            spd = owner.config.attack_movement_speed;
                            duration = irandom_range(owner.config.attack_stall_duration[0], owner.config.attack_stall_duration[1]);
                            dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                            TANGO.play("SoundEffects/Enemies/LavaCat/PounceAttack", owner.x, owner.y);
                            self.tarball = TarballBuilder(owner.x, owner.y, 16, 16, owner.config.damage)
                                .set_offset(-8, -16)
                                .set_parent(owner)
                                .set_critical(true)
                                .set_provenance(owner.monster_id, owner.stats_entry)
                                .notify(self)
                                .gen();

                            function on_hit() {
                                TANGO.play("SoundEffects/Enemies/LavaCat/ShompHit", owner.x, owner.y);
                            }
                        })
                        .step(function() {
                            owner.image_index = self.speed_indexes[clamp(floor(self.spd), 0, 4)];
                            if self.spd > 0 {
                                self.spd -= owner.config.attack_movement_deccel;
                                if self.spd < owner.config.attack_movement_gate {
                                    self.spd -= owner.config.attack_movement_gate_deccel;
                                }
                                self.spd = clamp(self.spd, 0, owner.config.attack_movement_speed);
                            } else if duration > 0 {
                                duration -= 1;
                            } else {
                                fsm.change_state(CatState.Tired);
                            }

                            if self.spd == 0 && self.tarball != undefined && instance_exists(self.tarball) {
                                instance_destroy(self.tarball);
                                self.tarball = undefined;
                            }

                            owner.dir = self.dir;
                            owner.move.x = lengthdir_x(self.spd, self.dir);
                            owner.move.y = lengthdir_y(self.spd, self.dir);
                        })
                        .stop(function() {
                            if self.tarball != undefined && instance_exists(self.tarball) {
                                instance_destroy(self.tarball);
                                self.tarball = undefined;
                            }
                            owner.image_speed = 1;
                            owner.can_overlap_ari = false;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(CatState.Tired)
                        .start(function() {
                            owner.set_state_sprite();
                            duration = owner.config.tired_duration
                        })
                        .step(function() {
                            if duration > 0 {
                                duration -= 1;
                            } else {
                                fsm.change_state(CatState.Idle);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(CatState.Hurt)
                        .start(function() {
                            owner.set_state_sprite();
                            duration = owner.config.hurt_duration;
                            owner.show_damage = 10000;
                        })
                        .step(function() {
                            if duration > 0 {
                                duration -= 1;
                            } else {
                                fsm.change_state(CatState.Idle);
                            }
                        })
                        .stop(function() {
                            owner.show_damage = 0;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(CatState.Petrified)
                    .start(function() {
                        if owner.freezer_audio_handle != undefined {
                            TANGO.request_stop(owner.freezer_audio_handle);
                            owner.freezer_audio_handle = undefined;
                        }

                        if owner.config.light_hater != undefined {
                            owner.light_damage = -owner.config.light_hater.light_health;
                        }
                        owner.image_speed = 0;
                        owner.image_alpha = 0;
                        duration = owner.config.petrified_duration;
                        petrification_rate = 6;
                        trauma = 0.5;
                        if owner.column == undefined {
                            owner.column = 0;
                        }
                        self.offset = Vec2(0,0);
                        self.play_sfx = true;
                        create_animation_effect(owner.x, owner.y, owner.depth - 1, spr_fx_monster_lava_cat_steam);
                        TANGO.play("SoundEffects/Enemies/LavaCat/TurnToStone", owner.x, owner.y);
                    })
                    .step(function() {
                        if duration > 0 {
                            duration -= 1;
                            if duration <= owner.config.petrified_shakes {
                                if self.play_sfx {
                                    TANGO.play("SoundEffects/Enemies/LavaCat/UnfreezeShake", owner.x, owner.y);
                                    self.play_sfx = false;
                                }

                                self.offset.x = self.trauma * self.trauma * perlin_noise_get(0) * sign(perlin_noise_get(50) * 2.0 - 1.0);
                                self.offset.y = self.trauma * self.trauma * perlin_noise_get(0) * sign(perlin_noise_get(50) * 2.0 - 1.0)
                                CAMERA.add_trauma(0.01);
                                if owner.column > 4 && fsm.state_frame % (petrification_rate * 2) == 0 {
                                    owner.column -= 1;
                                }
                            } else if owner.column < 10 && fsm.state_frame % petrification_rate == 0 {
                                owner.column += 1;
                            }
                        } else {
                            fsm.change_state(CatState.Windup);
                        }
                    })
                    .stop(function() {
                        repeat(3) {
                            spawn_particle_rockclod_bundle(owner.x + irandom_range(-3, 3), owner.y + irandom_range(-3, 3), owner.depth, owner.config.misc_sprites.lava_bits_stone);
                        }
                        owner.image_speed = 1;
                        owner.image_alpha = 1;
                        if owner.hit_points > 0 {
                            owner.column = undefined;
                        }
                        TANGO.play("SoundEffects/Enemies/LavaCat/BreakShell", owner.x, owner.y);
                    })
                    .spawn()
                )
                .add_state(
                    StateBuilder(CatState.Dying)
                        .start(function() {
                            CAMERA.add_trauma(0.2);
                            owner.set_state_sprite();
                            owner.play_state_tango();

                            real_pos = Vec2(owner.x, owner.y);
                            poof = false;

                            trauma = 0.5;
                            owner.show_damage = 10000;

                            self.duration = sprite_get_number(owner.sprite_index) - 1;

                            if owner.column != undefined {
                                owner.image_alpha = 0;
                                self.duration = owner.config.petrification_death_duration;
                                switch owner.get_cardinal() {
                                    case Cardinal.North:
                                        owner.sprite_index = owner.config.misc_sprites.petrified_hurt_north;
                                        break;
                                    default:
                                        owner.sprite_index = owner.config.misc_sprites.petrified_hurt_south;
                                        break;
                                }
                            }

                            TANGO.play("SoundEffects/Enemies/LavaCat/Die", owner.x, owner.y);
                        })
                        .step(function() {
                            if poof == false && self.duration <= 0 {
                                monster_death_poof(owner);
                                poof = true;
                            } else {
                                owner.x = self.real_pos.x + self.trauma * self.trauma * perlin_noise_get(0) * sign(perlin_noise_get(50) * 2.0 - 1.0);
                                owner.y = self.real_pos.y + self.trauma * self.trauma * perlin_noise_get(1) * sign(perlin_noise_get(100) * 2.0 - 1.0);
                                self.trauma = approach(self.trauma, 0, FRAME_TIME);
                                self.duration -= 1;
                            }
                        })
                        .spawn()
                )
                .spawn(CatState.Idle, self, Map());

            //
            if instance_number(object_index) >= 3 {
                self.skip_destroy_logic = true;
                instance_destroy(self);
            }
        },
        step: function() {
            event_inherit(ObjectEvent.Step);

            if game_paused() {
                if self.freezer_audio_handle != undefined {
                    TANGO.request_stop(self.freezer_audio_handle);
                }
                return;
            } else if self.freezer_audio_handle != undefined && TANGO.instance_alive(self.freezer_audio_handle) == false {
                self.freezer_audio_handle = TANGO.play("SoundEffects/Enemies/LavaCat/VoidTakeLightDamage", self.x, self.y);
            }

            if self.config.light_hater != undefined && fsm.current_state_id() != CatState.Petrified {
                var found_light = -1;
                var nearest_light = instance_nearest(self.x, self.y, par_light);
                if nearest_light != undefined && nearest_light.tiered_light != undefined {
                    //
                    var dist = min(
                        min(
                            point_distance(self.bbox_left, self.bbox_top, nearest_light.x, nearest_light.y),
                            point_distance(self.bbox_right, self.bbox_top, nearest_light.x, nearest_light.y),
                        ),
                        min(
                            point_distance(self.bbox_left, self.bbox_bottom, nearest_light.x, nearest_light.y),
                            point_distance(self.bbox_right, self.bbox_bottom, nearest_light.x, nearest_light.y),
                        ),
                    );
                    if dist < max(0, (LIGHT_SIZES[nearest_light.tiered_light] * 0.5) + self.config.light_hater.buffer) {
                        if obj_ari.dark_mines_light == nearest_light {
                            found_light = self.config.light_hater.player_value;
                        } else {
                            found_light = self.config.light_hater.neutral_value;
                        }
                    }
                }

                if ARI.status_effects.effects.get(StatusEffectId.SacredLight) != undefined {
                    found_light = 3;
                }

                if self.light_damage < 0 {
                    found_light = 1;
                }

                if found_light > 0 {
                    self.time_in_light += 1;
                } else {
                    self.time_in_light = 0;
                }

                self.light_damage = clamp(
                    self.light_damage + found_light,
                    -self.config.light_hater.light_health,
                    self.config.light_hater.light_health,
                );

                if self.light_damage >= self.config.light_hater.light_health {
                    self.fsm.change_state(CatState.Petrified);
                }

                self.column = self.light_damage div self.config.light_hater.pre_petrified_buckets;
                if self.column <= 0 {
                    self.column = undefined;
                }
                if self.time_in_light != 0
                    && (self.light_damage > 0)
                    && (self.time_in_light % self.config.light_hater.pre_petrified_steam) == 0
                {
                    create_animation_effect(self.x, self.y, self.depth - 1, spr_fx_monster_lava_cat_steam);
                    if self.freezer_audio_handle == undefined {
                        self.freezer_audio_handle = TANGO.play("SoundEffects/Enemies/LavaCat/VoidTakeLightDamage", self.x, self.y);
                    }
                }
                if self.time_in_light != 0
                    && (self.light_damage > 0)
                    && (self.time_in_light % self.config.light_hater.pre_petrified_flash) == 0
                {
                    self.tween_to_column = 6;
                    self.tween_time = TICK + 20;
                }

                if self.freezer_audio_handle != undefined
                    && found_light <= 0
                {
                    TANGO.request_stop(self.freezer_audio_handle);
                    self.freezer_audio_handle = undefined;
                }
            }

            if self.tween_to_column != undefined {
                self.column = sin((self.tween_time - TICK) * pi / 20) * tween_to_column;
                if TICK >= self.tween_time  {
                    self.tween_to_column = undefined;
                }
            }

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
            movement_and_collide(par_monster);

            monster_outside_bounds(x, y, self);

            if self.watered {
                self.fsm.change_state(CatState.Petrified);
                self.watered = false;
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

                    self.process_tarball_status(next_dmg.tarball);

                    if next_dmg.status != ReceiverStatus.Normal {
                        continue;
                    }
                    took_any_damage = true;
                    var damage = next_dmg.tarball.damage * (self.fsm.current_state_id() == CatState.Petrified ? 2 : 1);
                    self.hit_points -= damage;
                    self.stats_entry.damage_taken += damage;
                    self.stats_entry.damage_taken_count += 1;
                    spawn_damage_numbers(
                        self,
                        self.config.damage_number_offset,
                        damage,
                        self.fsm.current_state_id() == CatState.Petrified ? DamageFlag.CRITICAL : next_dmg.tarball.damage_flag(),
                    );

                    var on_hit = self.fsm.current_state_id() == CatState.Petrified ? self.config.misc_tango.strong_damage : self.config.misc_tango.weak_damage;

                    TANGO.play(on_hit, x, y);
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
                    switch csi {
                        case CatState.Idle:
                        case CatState.Acknowledgment:
                        case CatState.Walk:
                        case CatState.Tired:
                            spawn_particle_blood(x, y, depth, self.config.misc_sprites.lava_bits);
                            self.fsm.change_state(CatState.Hurt);
                            break;
                        case CatState.Hurt:
                            //
                            spawn_particle_blood(x, y, depth, self.config.misc_sprites.lava_bits);
                            break;
                        case CatState.Petrified:
                            spawn_particle_blood(x, y, depth, self.config.misc_sprites.lava_bits_stone);
                            self.show_damage = 30;
                            break;
                        case CatState.Windup:
                        case CatState.Attack:
                            self.show_damage = 30;
                            break;
                        case CatState.Dying:
                            //
                            break;
                        default: impossible("unexpected current state id!");
                    }

                    self.patience.value = PATIENCE_DAMAGED;

                    if self.hit_points <= 0 {
                        self.fsm.change_state(CatState.Dying);
                    }
                }
            } else if self.fsm.current_state_id() != CatState.Dying {
                self.fsm.change_state(CatState.Dying);
            }
        },
        draw: function() {
            if self.column == undefined {
                self.draw();
            } else {
                shader_set_texture("u_LutTexture", self.lut_texture, 0, "u_LutTexelSize");
                gpu_set_extra(UberShaderKind.PaletteSwap, self.uvs[0], self.uvs[1], self.column);
                draw_sprite_ext(
                    self.sprite_index,
                    self.image_index,
                    self.x,
                    self.y + self.z,
                    self.calculate_flipper(),
                    self.image_yscale,
                    self.image_angle,
                    self.image_blend,
                    1
                );
                gpu_reset_extra();
            }
            white_vfx();
        },
        cleanup: function() {
            event_inherit(ObjectEvent.Cleanup);

            if self.freezer_audio_handle != undefined {
                TANGO.force_stop(self.freezer_audio_handle);
            }
        },
    }
);
