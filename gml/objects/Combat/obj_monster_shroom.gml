object_create(
    "obj_monster_shroom",
    object_reserve("par_monster"),
    {
        sprite_index: spr_monster_mushroom_main_idle_south,
        mask_index: string_to_asset("spr_monster_mushroom_collision_box"),
        create: function() {
            event_inherit(ObjectEvent.Create);

            knockback_speed = Vec2();

            function stop_windup_tango() {
                var tango_idx = self.fsm.blackboard.try_take("windup_tango");
                if tango_idx != undefined {
                    TANGO.request_stop(tango_idx);
                }
            }

            //
            //
            function look_south() {
                var flipper = 1;
                if self.dir >= 90 && self.dir < 270 {
                    flipper = -1;
                }
                self.dir = 270 + flipper;
            }

            function should_hide() {
                var point_dist = point_distance(obj_ari.x, obj_ari.y, x, y);
                if point_dist > config.hide_radius {
                    return false;
                }

                var point_dir = point_direction(obj_ari.x, obj_ari.y, x, y);
                return abs(angle_difference(point_dir, obj_ari.dir)) < 90;
            }

            //
            function debug_state() {
                return mushroom_state_to_string(self.fsm.current_state_id());
            }

            fsm = StateMachineBuilder(MushroomState.LEN)
                .add_state(
                    StateBuilder(MushroomState.Idle)
                        .create(function() {
                            self.asleep = true;
                        })
                        .start(function() {
                            if self.asleep {
                                owner.sprite_index = owner.config.misc_sprites.sleep;
                                owner.image_index = 0;
                                shadow_caster_set_sprite(owner.shadow_caster, SHADOW_DICTIONARY.get(owner.sprite_index));
                            } else {
                                owner.set_state_sprite(true, MushroomState.Idle);
                            }
                            owner.dir = owner.original_dir;
                            in_variant = false;
                        })
                        .step(function() {
                            if owner.aggro {
                                if owner.acknowledgement_reset {
                                    fsm.change_state(MushroomState.Acknowledgment);
                                } else {
                                    fsm.change_state(MushroomState.Walk);
                                }
                            }

                            if owner.image_alpha != 1 && fsm.state_frame >= owner.config.aggro_fade_in_timer {
                                owner.image_alpha = clamp(owner.image_alpha + owner.config.fade_in_rate, 0, 1);
                            }

                            if owner.should_hide() {
                                fsm.change_state(MushroomState.Shell);
                            }
                        })
                        .anim_end(function() {
                            //
                            if self.asleep == false {
                                if chance_percent(15) {
                                    owner.original_dir = irandom_range(180, 360);
                                    owner.dir = owner.original_dir;
                                }
                                owner.set_state_sprite(true, MushroomState.Idle);
                            }
                        })
                        .stop(function() {
                            self.asleep = false;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MushroomState.Acknowledgment)
                        .start(function() {
                            owner.set_state_sprite();
                            duration = irandom_range(owner.config.acknowledgment[0], owner.config.acknowledgment[1]);
                            owner.play_state_tango();
                            owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);

                        })
                        .step(function() {
                            if fsm.state_frame >= self.duration {
                                if owner.should_hide() || owner.config.fade_in_rate != 0 {
                                    fsm.change_state(MushroomState.Shell);
                                } else {
                                    fsm.change_state(MushroomState.Walk);
                                }
                            }

                        })
                        .anim_end(function() {
                            owner.image_index = owner.image_number - 1;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MushroomState.Walk)
                        .start(function() {
                            to_ari = true;
                            target_x = obj_ari.x;
                            target_y = obj_ari.y;

                            owner.set_state_sprite();
                        })
                        .step(function() {
                            if owner.aggro {
                                self.target_x = obj_ari.x;
                                self.target_y = obj_ari.y;
                            } else {
                                self.target_x = owner.original_spawn_pos.x;
                                self.target_y = owner.original_spawn_pos.y;
                            }

                            owner.dir = point_direction(owner.x, owner.y, target_x, target_y);
                            owner.move.x = lengthdir_x(owner.config.speed, owner.dir);
                            owner.move.y = lengthdir_y(owner.config.speed, owner.dir);
                            owner.set_state_sprite(false);

                            if owner.should_hide() {
                                fsm.change_state(MushroomState.Shell);
                            }
                        })
                        .end_step(function() {
                            if owner.aggro
                                && point_distance(owner.x, owner.y, self.target_x, self.target_y) < owner.config.attack_radius
                            {
                                fsm.change_state(MushroomState.WindupSlide);
                            } else if point_distance(owner.x, owner.y, self.target_x, self.target_y) < 1 {
                                owner.x = self.target_x;
                                owner.y = self.target_y;

                                fsm.change_state(MushroomState.Idle);
                            }

                            //
                            if owner.acknowledgement_reset {
                                fsm.change_state(MushroomState.Acknowledgment);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MushroomState.WindupSlide)
                        .start(function() {
                            owner.set_state_sprite();
                            self.blackboard.insert("windup_tango", owner.play_state_tango());
                            spd = owner.config.speed;
                            if owner.config.fade_in_rate != 0 {
                                TANGO.play("SoundEffects/Enemies/Mushroom/Reappear", owner.x, owner.y);
                            }
                        })
                        .step(function() {
                            owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);

                            if point_distance(owner.x, owner.y, obj_ari.x, obj_ari.y) < 8 {
                                self.spd = 0;
                            }
                            owner.move.x = lengthdir_x(self.spd, owner.dir);
                            owner.move.y = lengthdir_y(self.spd, owner.dir);

                            self.spd *= owner.config.windup_friction;

                            if self.spd < 0.1 {
                                fsm.change_state(MushroomState.Windup);
                            }
                        })
                        .stop(function() {
                            if fsm.next_state == undefined || fsm.next_state.state_id != MushroomState.Windup {
                                owner.stop_windup_tango();
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MushroomState.Windup)
                        .start(function() {
                            owner.set_state_sprite();
                            duration = 0;
                            spd = owner.config.speed;

                            owner.image_index = 1;
                            var windup_durations = owner.config.windup;
                            if windup_durations == -1 {
                                self.windup = undefined;
                            } else {
                                self.windup = irandom_range(windup_durations[0], windup_durations[1]);
                            }
                        })
                        .step(function() {
                            if self.windup != undefined && self.fsm.state_frame >= self.windup {
                                fsm.change_state(MushroomState.Attack);
                            }
                        })
                        .anim_end(function() {
                            if self.windup == undefined {
                                fsm.change_state(MushroomState.Attack);
                            }
                        })
                        .stop(function() {
                            if fsm.next_state == undefined || fsm.next_state.state_id != MushroomState.Attack {
                                owner.stop_windup_tango();
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MushroomState.Attack)
                        .start(function() {
                            owner.set_state_sprite();
                            owner.play_state_tango();
                            owner.image_alpha = 1;

                            self.tarball = TarballBuilder(owner.x - 25, owner.y - 28, 52, 52, owner.config.damage)
                                .set_circle()
                                .set_provenance(owner.monster_id, owner.stats_entry)
                                .gen();

                            create_animation_effect(owner.x, owner.y, owner.depth, owner.config.misc_sprites.attack_vfx);

                            if owner.config.spew_lava {
                                TANGO.play("SoundEffects/Enemies/PuddleSpawn", owner.x, owner.y);
                                instance_create_depth(owner.x, owner.y, get_shadow_depth() + 1, obj_hot_patch, {
                                    timer: owner.config.lava_timer,
                                    owner,
                                    damage: owner.config.lava_damage
                                });
                            }
                        })
                        .anim_end(function() {
                            fsm.change_state(MushroomState.Tired);
                        })
                        .stop(function() {
                            instance_destroy(self.tarball);
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MushroomState.Tired)
                        .start(function() {
                            //
                            owner.look_south();
                            owner.set_state_sprite();

                            timer = irandom_range(owner.config.tired[0], owner.config.tired[1]);
                        })
                        .step(function() {
                            if fsm.state_frame >= self.timer {
                                if owner.should_hide() || owner.config.fade_in_rate != 0 {
                                    fsm.change_state(MushroomState.Shell);
                                } else {
                                    fsm.change_state(MushroomState.Walk);
                                }
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MushroomState.Shell)
                        .start(function() {
                            //
                            owner.look_south();

                            if owner.config.fade_out_rate != 0 {
                                TANGO.play("SoundEffects/Enemies/Mushroom/Disappear", owner.x, owner.y);
                            }

                            if fsm.last_state_id == MushroomState.Shell || fsm.last_state_id == MushroomState.WiggleExit {
                                owner.sprite_index = owner.config.misc_sprites.shell_hit;
                                owner.image_index = 0;
                                shadow_caster_set_sprite(owner.shadow_caster, SHADOW_DICTIONARY.get(owner.sprite_index));
                            } else {
                                owner.set_state_sprite();
                            }

                            owner.receiver.drop_damage();
                            stop_animating = false;

                            if self.blackboard.try_take("bounce_player", false) {
                                //
                                var opposite_dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);

                                new_chain()
                                    .append(LinkId.Timer, 12)
                                    .append(LinkId.Function, function(opposite_dir, bounce_noise) {
                                        TANGO.play(bounce_noise, obj_ari.x, obj_ari.y);

                                        obj_ari.fsm.blackboard.insert("spd", Vec2(
                                            lengthdir_x(4, opposite_dir),
                                            lengthdir_y(4, opposite_dir),
                                        ));
                                        obj_ari.fsm.change_state(PlayerState.Knockback);
                                    }, [opposite_dir, owner.config.misc_tango.bounce_off]);
                            } else {
                                owner.play_state_tango();
                            }
                        })
                        .step(function() {
                            if owner.should_hide() == false
                                && fsm.state_frame >= 60
                            {
                                fsm.change_state(MushroomState.Walk);
                            }
                        })
                        .anim_end(function() {
                            owner.image_index = owner.image_number - 1;
                        })
                        .stop(function() {
                            if fsm.next_state == undefined || fsm.next_state.state_id != MushroomState.Shell {
                                TANGO.play(owner.config.misc_tango.un_shell, owner.x, owner.y);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MushroomState.Dying)
                        .start(function() {
                            owner.trauma = 0.7;

                            //
                            owner.look_south();
                            owner.play_state_tango();

                            if self.fsm.last_state_id != MushroomState.Wiggle {
                                owner.set_state_sprite();
                            }
                            owner.show_damage = I32_MAX;
                            poof = false;
                        })
                        .step(function() {
                            if poof == false && (owner.image_index >= 1 || fsm.state_frame >= 4) {
                                poof = true;
                                monster_death_poof(owner);
                                CAMERA.add_trauma(0.4);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MushroomState.Wiggle)
                        .start(function() {
                            //
                            owner.look_south();
                            owner.play_state_tango();

                            owner.sprite_index = owner.config.misc_sprites.enter_wiggle;
                            owner.image_index = 2;
                            jump_speed = owner.config.flip_jump_speed;

                            if fsm.last_state_id == MushroomState.Shell {
                                owner.image_index = 0;
                            }
                            in_entrance_anim = true;
                            hits = 1;
                            timer = irandom_range(owner.config.wiggle[0], owner.config.wiggle[1]);
                        })
                        .step(function() {
                            owner.z += self.jump_speed;
                            self.jump_speed += owner.config.jump_gravity;
                            owner.z = min(owner.z, 0);

                            if self.in_entrance_anim  {
                                if owner.z < 0 && owner.image_index >= 4 {
                                    owner.image_index = 4;
                                }
                            } else {
                                if owner.z == 0 && fsm.state_frame >= self.timer {
                                    fsm.change_state(MushroomState.WiggleExit);
                                }

                                if owner.show_damage <= 0 && owner.sprite_index == owner.config.misc_sprites.hurt_wiggle {
                                    owner.set_state_sprite();
                                }
                            }
                        })
                        .anim_end(function() {
                            if self.in_entrance_anim {
                                owner.set_state_sprite();
                                self.in_entrance_anim = false;
                                self.timer += fsm.state_frame;
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MushroomState.WiggleExit)
                        .start(function() {
                            owner.look_south();
                            owner.set_state_sprite();
                        })
                        .step(function() {
                            if owner.image_index >= 2 {
                                owner.show_damage = 0;
                            }
                        })
                        .anim_end(function() {
                            if owner.config.fade_in_rate != 0 {
                                fsm.change_state(MushroomState.Shell);
                            } else {
                                fsm.change_state(MushroomState.Walk);
                            }
                        })
                        .spawn()
                )
                //
                //
                //
                //
                .add_state(
                    StateBuilder(MushroomState.Explode)
                        .start(function() {
                            owner.look_south();
                            owner.set_state_sprite();

                            perform_effect = 0;
                            effect_max = 20;
                            effect = self.effect_max;
                            //
                        })
                        .step(function() {
                            //
                                self.effect -= 1;
                                self.perform_effect -= 1;

                                if self.effect <= 0 {
                                    self.effect_max -= 2;

                                    if self.effect_max <= 4 {
                                        trace("takes: {}", fsm.state_frame);

                                        //
                                    } else {
                                        self.effect = self.effect_max;
                                        self.perform_effect = 4;
                                    }
                                }
                            //
                        })
                        .draw(function() {
                            if self.perform_effect > 0 {
                                crash("this won't work with our current sword oil problems!");
                                gpu_set_extra(UberShaderKind.Flat);
                                owner.image_blend = c_red;
                                owner.image_alpha = 0.8;
                                owner.draw();
                                owner.image_blend = c_white;
                                owner.image_alpha = 1.0;
                                gpu_reset_extra();
                            }
                        })
                        .anim_end(function() {
                            //
                            //
                            //
                        })
                        .spawn()
                )
                .spawn(MushroomState.Idle, self, Map());
        },
        step: function() {
            event_inherit(ObjectEvent.Step);

            if game_paused() {
                return;
            }

            var state = self.fsm.current_state_id();

            if state == MushroomState.Shell {
                image_alpha = clamp(image_alpha - config.fade_out_rate, 0, 1);
            } else if state == MushroomState.Windup || state == MushroomState.WindupSlide {
                image_alpha = clamp(image_alpha + config.fade_in_rate, 0, 1);
            }

            shadow_caster_set_alpha(self.shadow_caster, image_alpha > self.config.shadow_threshold ? 1 : 0);


            fsm.step();

            if !instance_exists(self) {
                return;
            }

            self.move.x += self.knockback_speed.x;
            self.move.y += self.knockback_speed.y;
            self.knockback_speed.set_scale(self.config.knockback_friction);

            //
            if self.knockback_speed.sqrd_magnitude() < 0.1 {
                self.knockback_speed.set_zero();
            }

            self.move.set_scale(self.status_effects.get_effect_value(StatusEffectId.Frozen));

            apply_friction();
            push_and_shove(par_monster, self.config.push_radius, self.config.push_force);
            push_from(obj_ari, self.config.pushed_radius, self.config.push_force * sqrt(obj_ari.move.sqrd_magnitude()));
            movement_and_collide(par_monster);

            self.trauma = approach(self.trauma, 0, FRAME_TIME);
            depth = get_instance_depth(y, z);
            monster_outside_bounds(x, y, self);
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

            if !instance_exists(self) {
                return;
            }

            if self.hit_points <= 0 {
                if self.fsm.current_state_id() != MushroomState.Dying {
                    self.fsm.change_state(MushroomState.Dying);
                    return;
                }
            } else while true {
                var next_dmg = self.receiver.try_take_damage();
                if next_dmg == undefined {
                    break;
                }

                var shield_break = has_flag(next_dmg.tarball.flags, CombatFlag.ShieldBreak);
                var current_state = self.fsm.current_state_id();
                self.patience.value = PATIENCE_DAMAGED;

                if current_state != MushroomState.Shell || shield_break || next_dmg.tarball.instant_kill {
                    self.process_tarball_status(next_dmg.tarball);

                    self.hit_points -= next_dmg.tarball.damage;
                    self.image_alpha = 1;
                    self.stats_entry.damage_taken += next_dmg.tarball.damage;
                    self.stats_entry.damage_taken_count += 1;

                    next_dmg.tarball.calculate_knockback(x, y, self.knockback_speed);
                    self.knockback_speed.scale(self.config.knockback_multiplier);

                    if current_state == MushroomState.Wiggle || self.hit_points <= 0 {
                        self.knockback_speed.scale(0.2);
                    }

                    spawn_damage_numbers(
                        self,
                        self.config.damage_number_offset,
                        next_dmg.tarball.damage,
                        next_dmg.tarball.damage_flag(),
                    );

                    TANGO.play(self.config.misc_tango.strong_damage, x, y);
                    self.show_damage = 30;

                    if next_dmg.tarball.critical {
                        monster_critical_fx(self);
                        set_rumble(RumbleKind.SwordStrong);
                    } else {
                        set_rumble(RumbleKind.SwordWeak);
                    }
                } else {
                    spawn_damage_numbers(
                        self,
                        self.config.damage_number_offset,
                        0,
                        next_dmg.tarball.damage_flag(),
                    );
                    set_rumble(RumbleKind.SwordWeak);
                }

                if self.hit_points <= 0.0 {
                    self.fsm.change_state(MushroomState.Dying);
                    break;
                } else if shield_break {
                    self.fsm.change_state(MushroomState.Wiggle);
                } else {
                    switch self.fsm.current_state_id() {
                        case MushroomState.Idle:
                        case MushroomState.Acknowledgment:
                        case MushroomState.Windup:
                        case MushroomState.WindupSlide:
                        case MushroomState.Walk:
                        case MushroomState.Tired:
                        case MushroomState.Attack:
                            self.fsm.change_state(MushroomState.Wiggle);
                            break;
                        case MushroomState.Dying:
                        case MushroomState.Explode:
                            //
                            break;
                        case MushroomState.Wiggle:
                            //
                            self.trauma = 0.5;
                            self.fsm.state_frame *= 0.5;
                            var statum = self.fsm.current_state();

                            statum.jump_speed = self.config.flip_jump_speed;
                            statum.hits += 1;

                            if statum.hits >= 3 {
                                self.fsm.blackboard.set("bounce_player", true);
                                self.fsm.change_state(MushroomState.Shell);
                            } else {
                                sprite_index = self.config.misc_sprites.hurt_wiggle;
                            }
                            break;
                        case MushroomState.Shell:
                        case MushroomState.WiggleExit:
                            if next_dmg.tarball.parent_object() == obj_ari
                                && obj_ari.fsm.current_state_id() == PlayerState.Sword
                            {
                                self.fsm.blackboard.set("bounce_player", true);
                                self.fsm.change_state(MushroomState.Shell);
                            }
                            break;
                        default: crash("unexpected state!")
                    }
                }
            }
        },
    }
);
