object_create(
    "obj_monster_enchantern",
    object_reserve("par_monster"),
    {
        sprite_index: spr_monster_enchantern_on_idle_north,
        mask_index: string_to_asset("spr_monster_enchantern_off_collision_box"),
        create: function() {
            event_inherit(ObjectEvent.Create);

            electric_ball = undefined;
            flee_timer = 0;
            stall_timer = undefined;

            function setup_electrical_pain(notifee, on_damage_back) {
                self.play_state_tango();
                self.set_state_sprite();
                var bbox_dims = shape_get_dimensions(spr_monster_enchantern_projectile_floor_loop);
                //
                //
                var bbox_offset = shape_get_offset(spr_monster_enchantern_projectile_floor_loop);

                var tarball = TarballBuilder(x, y, bbox_dims[0], bbox_dims[1], self.config.damage)
                    .set_offset(bbox_offset[0], bbox_offset[1])
                    .set_parent(self)
                    .set_electric(self.config.electrocute_kind)
                    .set_in_air()
                    .notify(notifee)
                    .set_provenance(self.monster_id, self.stats_entry)
                    .gen();
                self.receiver.damage_back_tarball = tarball;
                self.receiver.on_damage_back = on_damage_back;
                self.receiver.status = set_flag(self.receiver.status, ReceiverStatus.DamageOnAttack);

                return tarball;
            }

            fsm = StateMachineBuilder(EnchanternState.LEN)
                .add_state(
                    StateBuilder(EnchanternState.Idle)
                        .start(function() {
                            owner.set_state_sprite(true, EnchanternState.Idle);
                            owner.dir = owner.original_dir;
                        })
                        .step(function() {
                            if owner.aggro {
                                fsm.change_state(EnchanternState.Acknowledgment);
                            }
                        })
                        .anim_end(function() {
                            //
                            if chance_percent(15) {
                                owner.original_dir = irandom(360);
                                owner.dir = owner.original_dir;
                            }
                            owner.set_state_sprite(true, EnchanternState.Idle);
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(EnchanternState.Acknowledgment)
                        .start(function() {
                            owner.set_state_sprite();
                            owner.play_state_tango();
                            duration = irandom_range(owner.config.acknowledgment[0], owner.config.acknowledgment[1]);
                            owner.track_player();
                        })
                        .step(function() {
                            if owner.stall_timer != undefined {
                                owner.stall_timer -= 1;

                                if owner.stall_timer <= 0 {
                                    fsm.change_state(EnchanternState.Flee);
                                    owner.stall_timer = undefined;
                                }
                                return;
                            }

                            owner.track_player();

                            if fsm.state_frame >= self.duration {
                                fsm.change_state(EnchanternState.FlickerOn);
                            }
                        })
                        .anim_end(function() {
                            owner.image_index = owner.image_number - 1;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(EnchanternState.FlickerOn)
                        .start(function() {
                            owner.track_player();
                            owner.set_state_sprite();
                            owner.play_state_tango();
                        })
                        .anim_end(function() {
                            fsm.change_state(EnchanternState.Charge);
                        })
                        .draw(function() {
                            with owner {
                                draw_sprite(self.config.misc_sprites.charge, self.image_index, self.x, self.y);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(EnchanternState.Charge)
                        .create(function() {
                            looping_sound = undefined;
                            function on_hit() {
                                self.hold_on_shock = fiddle_get("player/hurt_timer");
                                switch monster_vertical_cardinal_from_dir(owner.dir) {
                                    case Cardinal.North:
                                        owner.sprite_index = owner.config.misc_sprites.attack_north;
                                        break;
                                    case Cardinal.South:
                                        owner.sprite_index = owner.config.misc_sprites.attack_south;
                                        break;
                                    default: impossible("unexpected vertical cardinal");
                                }
                                owner.image_index = 1;
                            }
                        })
                        .start(function() {
                            static_frame = 0;

                            self.tarball = owner.setup_electrical_pain(self, function(tarball) {
                                if self.hold_on_shock != undefined {
                                    return false;
                                }
                                self.on_hit();

                                //
                                if is_numeric(tarball.provenance) {
                                    return false;
                                } else {
                                    ds_list_add(obj_ari.receiver.damaged, self.tarball);
                                    return true;
                                }
                            });

                            self.light = instance_create_depth(
                                owner.x,
                                owner.y,
                                owner.depth,
                                par_light,
                            );
                            self.light.tiered_light = Light.Enchantern;
                            self.light.sprite_index = LIGHTS[Light.Enchantern][0];
                            self.light.image_index = owner.image_index;

                            timer = irandom_range(owner.config.charge_timer[0], owner.config.charge_timer[1]);
                            hold_on_shock = undefined;
                            drop_ball = owner.config.drops_balls;
                            played_sound = false;
                            played_wind_down = false;

                            //
                            off = true;
                            off_timer = 4;
                            on_timer = 24;
                            current_on_timer = on_timer;

                            self.looping_sound = TANGO.play(owner.config.misc_tango.active_loop, owner.x, owner.y);
                            self.wind_down_sound = undefined;
                        })
                        .step(function() {
                            if self.hold_on_shock != undefined {
                                if owner.image_index < 1 {
                                    owner.image_index = 1;
                                }
                                self.hold_on_shock -= 1;

                                if self.hold_on_shock <= 0 {
                                    fsm.change_state(EnchanternState.Flee);
                                }

                                return;
                            }

                            owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                            owner.move.x = lengthdir_x(owner.config.charge_speed, owner.dir);
                            owner.move.y = lengthdir_y(owner.config.charge_speed, owner.dir);
                            if owner.image_index >= 3 {
                                owner.move.set_zero();
                                if self.played_sound == false {
                                    TANGO.play(owner.config.misc_tango.active_footstep, owner.x, owner.y);
                                    self.played_sound = true;
                                }
                            } else {
                                self.played_sound = false;
                                if self.drop_ball {
                                    TANGO.play(owner.config.misc_tango.spawn_orb, owner.x, owner.y);
                                    instance_create_depth(owner.x, owner.y, owner.depth, obj_monster_enchantern_projectile, {
                                        dmg: owner.config.damage,
                                        timer: irandom_range(owner.config.projectile_timer[0], owner.config.projectile_timer[1]),
                                        monster_id: owner.monster_id,
                                        stats_entry: owner.stats_entry,
                                        electrocute_kind: owner.config.electrocute_kind,
                                        sprite_database: {
                                            mask_index: owner.config.misc_sprites.proj_mask_index,
                                            main_start: owner.config.misc_sprites.proj_main_start,
                                            main_loop: owner.config.misc_sprites.proj_main_loop,
                                            main_fizzle: owner.config.misc_sprites.proj_main_fizzle,
                                        },
                                    });
                                    self.drop_ball = 0;
                                }
                            }

                            var time_left = self.timer - fsm.state_frame;
                            if time_left <= 0 {
                                if ARI.perk_active(Perk.OutOfJuice) {
                                    var data = fiddle_get("perks/out_of_juice/duration_in_frames")
                                    fsm.change_state(EnchanternState.Acknowledgment);
                                    owner.stall_timer = irandom_range(data[0], data[1]);
                                } else {
                                    fsm.change_state(EnchanternState.Flee);
                                    fsm.blackboard.insert("innocent", true);
                                }

                            } else if time_left <= 120 {
                                if self.played_wind_down == false {
                                    self.wind_down_sound = TANGO.play(owner.config.misc_tango.wind_down, owner.x, owner.y);
                                    self.played_wind_down = true;
                                }

                                if self.off {
                                    switch monster_vertical_cardinal_from_dir(owner.dir) {
                                        case Cardinal.North:
                                            owner.sprite_index = owner.config.misc_sprites.charge_off_north;
                                            break;
                                        case Cardinal.South:
                                            owner.sprite_index = owner.config.misc_sprites.charge_off_south;
                                            break;
                                        default: impossible("unexpected vertical cardinal");
                                    }
                                    self.off_timer -= 1;
                                    if self.off_timer <= 0 {
                                        self.off = false;
                                        self.off_timer = 4;
                                    }
                                } else {
                                    owner.set_state_sprite(false);
                                    self.current_on_timer -= 1;
                                    if self.current_on_timer <= 0 {
                                        self.off = true;
                                        self.on_timer = max(floor(self.on_timer * 0.8), 4);
                                        self.current_on_timer = self.on_timer;
                                    }
                                }
                            } else {
                                owner.set_state_sprite(false);
                            }
                        })
                        .end_step(function() {
                            self.light.x = owner.x;
                            self.light.y = owner.y;
                        })
                        .anim_end(function() {
                            self.drop_ball += owner.config.drops_balls;
                            owner.play_state_tango();
                        })
                        .draw(function() {
                            self.static_frame += 1 / 6;
                            with owner {
                                draw_sprite(self.config.misc_sprites.static_effect, other.static_frame, self.x, self.y);
                            }
                        })
                        .cleanup(function() {
                            if self.looping_sound != undefined {
                                TANGO.request_stop(self.looping_sound);
                            }
                        })
                        .stop(function() {
                            instance_destroy(self.tarball);
                            instance_destroy(self.light);

                            TANGO.request_stop(self.looping_sound);
                            if self.wind_down_sound != undefined {
                                TANGO.request_stop(self.wind_down_sound);
                            }
                            TANGO.play(owner.config.misc_tango.turn_off, owner.x, owner.y);

                            if instance_exists(owner.receiver) {
                                owner.receiver.damage_back_tarball = undefined;
                                owner.receiver.on_damage_back = undefined;
                                owner.receiver.status = remove_flag(owner.receiver.status, ReceiverStatus.DamageOnAttack);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(EnchanternState.Flee)
                        .start(function() {
                            owner.image_speed = 1.25;
                            owner.play_state_tango();

                            self.in_ack = fsm.blackboard.try_take("innocent", false);
                            if self.in_ack {
                                owner.set_state_sprite(true, EnchanternState.Acknowledgment);
                            } else {
                                owner.set_state_sprite(true);
                            }

                            self.played_sound = false;

                            if owner.flee_timer <= 0 {
                                owner.flee_timer = irandom_range(owner.config.flee_timer[0], owner.config.flee_timer[1]);
                            }
                        })
                        .step(function() {
                            if self.in_ack {
                                return;
                            }

                            owner.dir = point_direction(obj_ari.x, obj_ari.y, owner.x, owner.y);
                            owner.move.x = lengthdir_x(owner.config.flee_speed, owner.dir);
                            owner.move.y = lengthdir_y(owner.config.flee_speed, owner.dir);
                            if owner.image_index >= 3 {
                                owner.move.set_zero();
                                if self.played_sound == false {
                                    TANGO.play(owner.config.misc_tango.inactive_footstep, owner.x, owner.y);
                                    self.played_sound = true;
                                }
                            } else {
                                self.played_sound = false;
                            }
                            owner.set_state_sprite(false);

                            if owner.flee_timer <= 0 {
                                if owner.aggro {
                                    fsm.change_state(EnchanternState.FlickerOn);
                                } else {
                                    fsm.change_state(EnchanternState.GoHome);
                                }
                            }
                        })
                        .anim_end(function() {
                            if self.in_ack {
                                owner.dir = point_direction(obj_ari.x, obj_ari.y, owner.x, owner.y);
                                owner.set_state_sprite();
                                self.in_ack = false;
                            }
                        })
                        .stop(function() {
                            owner.image_speed = 1;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(EnchanternState.GoHome)
                        .start(function() {
                            owner.play_state_tango();
                            owner.set_state_sprite();

                            self.played_sound = false;
                        })
                        .step(function() {
                            owner.dir = point_direction(owner.x, owner.y, owner.original_spawn_pos.x, owner.original_spawn_pos.y);

                            if point_distance(owner.x, owner.y, owner.original_spawn_pos.x, owner.original_spawn_pos.y) < 2 {
                                owner.x = owner.original_spawn_pos.x;
                                owner.y = owner.original_spawn_pos.y;
                            } else {
                                owner.move.x = lengthdir_x(owner.config.flee_speed, owner.dir);
                                owner.move.y = lengthdir_y(owner.config.flee_speed, owner.dir);
                            }

                            if owner.image_index >= 3 {
                                owner.move.set_zero();

                                if self.played_sound == false {
                                    TANGO.play(owner.config.misc_tango.inactive_footstep, owner.x, owner.y);
                                    self.played_sound = true;
                                }
                            } else {
                                self.played_sound = false;
                            }
                            owner.set_state_sprite(false);
                        })
                        .anim_end(function() {
                            owner.play_state_tango();
                            if owner.aggro {
                                fsm.change_state(EnchanternState.Charge);
                            } else if point_distance(owner.x, owner.y, owner.original_spawn_pos.x, owner.original_spawn_pos.y) < 2 {
                                fsm.change_state(EnchanternState.Idle);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(EnchanternState.Hurt)
                        .start(function() {
                            owner.set_state_sprite();
                            owner.receiver.drop_damage();

                            hurt_timer = irandom_range(owner.config.hurt[0], owner.config.hurt[1]);
                            owner.show_damage = 10000;
                        })
                        .step(function() {
                            if fsm.state_frame >= self.hurt_timer {
                                if owner.flee_timer <= 0 {
                                    fsm.change_state(EnchanternState.FlickerOn);
                                } else {
                                    fsm.change_state(EnchanternState.Flee);
                                }
                            }
                        })
                        .stop(function() {
                            owner.show_damage = 0;
                        })
                    .spawn()
                )
                .add_state(
                    StateBuilder(EnchanternState.Dying)
                        .start(function() {
                            owner.trauma = 0.7;
                            owner.set_state_sprite();
                            owner.play_state_tango();

                            owner.show_damage = 10000;
                            poof = false;
                        })
                        .step(function() {
                            if poof == false && owner.image_index >= 1 {
                                monster_death_poof(owner);
                                poof = true;
                                CAMERA.add_trauma(0.4);
                            }
                        })
                        .spawn()
                )
                .spawn(EnchanternState.Idle, self, Map());
        },
        step: function() {
            event_inherit(ObjectEvent.Step);

            if game_paused() {
                if self.fsm.current_state_id() == EnchanternState.Charge {
                    TANGO.request_stop(self.fsm.current_state().looping_sound);
                }
                return;
            } else {
                var state = self.fsm.current_state();
                if self.fsm.current_state_id() == EnchanternState.Charge && TANGO.instance_alive(state.looping_sound) == false {
                    state.looping_sound = TANGO.play(self.config.misc_tango.active_loop, self.x, self.y);
                }
            }

            fsm.step();

            if !instance_exists(self) {
                return;
            }

            depth = get_instance_depth(y, z);

            apply_friction();
            self.move.set_add(self.knockback_move);
            self.knockback_move.set_scale(0.9);

            self.move.set_scale(self.status_effects.get_effect_value(StatusEffectId.Frozen));

            push_and_shove(par_monster, self.config.push_radius, self.config.push_force);
            push_from(obj_ari, self.config.pushed_radius, self.config.push_force * sqrt(obj_ari.move.sqrd_magnitude()));
            movement_and_collide(par_monster);

            monster_outside_bounds(x, y, self);

            self.flee_timer -= 1;
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

            var csi = fsm.current_state_id();

            if self.hit_points > 0 {
                var took_any_damage = false;

                while true {
                    var next_dmg = self.receiver.try_take_damage();
                    if next_dmg == undefined {
                        break;
                    }

                    self.process_tarball_status(next_dmg.tarball);

                    took_any_damage = true;
                    self.hit_points -= next_dmg.tarball.damage;
                    self.stats_entry.damage_taken += next_dmg.tarball.damage;
                    self.stats_entry.damage_taken_count += 1;

                    spawn_damage_numbers(
                        self,
                        self.config.damage_number_offset,
                        next_dmg.tarball.damage,
                        next_dmg.tarball.damage_flag(),
                    );

                    //
                    next_dmg.tarball.calculate_knockback(x, y, self.move);
                    self.move.set_scale(1.2);

                    //
                    CAMERA.camera_stop = 1;

                    var on_hit = self.config.misc_tango.weak_damage;
                    if self.hit_points <= 0 || next_dmg.tarball.heavy {
                        on_hit = self.config.misc_tango.strong_damage;
                    }
                    TANGO.play(on_hit, x, y);

                    if next_dmg.tarball.critical {
                        monster_critical_fx(self);
                        set_rumble(RumbleKind.SwordStrong);
                    } else {
                        set_rumble(RumbleKind.SwordWeak);
                    }
                }

                if took_any_damage {
                    switch csi {
                        case EnchanternState.Idle:
                        case EnchanternState.Acknowledgment:
                        case EnchanternState.Flee:
                        case EnchanternState.GoHome:
                        case EnchanternState.Charge:
                        case EnchanternState.Hurt:
                            self.fsm.change_state(EnchanternState.Hurt);
                            break;
                        case EnchanternState.FlickerOn:
                            //
                            self.image_index = self.image_index * 0.75;
                            self.show_damage = 30;
                            break;
                        case EnchanternState.Dying:
                            //
                            break;
                        default: impossible("unexpected current state id!");
                    }

                    self.patience.value = PATIENCE_DAMAGED;

                    if self.hit_points <= 0 {
                        self.fsm.change_state(EnchanternState.Dying);
                    }
                }
            } else if csi != EnchanternState.Dying {
                self.fsm.change_state(EnchanternState.Dying);
                return;
            }
        },
        destroy: function () {
            event_inherit(ObjectEvent.Destroy);

            if self.electric_ball != undefined && instance_exists(self.electric_ball) {
                instance_destroy(self.electric_ball);
            }
        },
        cleanup: function() {
            event_inherit(ObjectEvent.Cleanup);
            self.fsm.cleanup();
        },
    }
);
