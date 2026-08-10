object_create(
    "obj_monster_spirit",
    object_reserve("par_monster"),
    {
        sprite_index: spr_monster_flame_spirit_main_idle_south,
        create: function() {
            event_inherit(ObjectEvent.Create);

            projectiles = array_create(self.config.belt_size, undefined);
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

            function generate_fireball(xx, yy, object_depth, dir, config) {
                return instance_create_depth(xx, yy, object_depth, obj_monster_spirit_projectile, {
                    turn_rate: config.projectile_turn_rate,
                    life_time: irandom_range(config.projectile_life_time[0], config.projectile_life_time[1]),
                    sprite_index: config.misc_sprites.projectile,
                    spd: config.projectile_speed * status_effects.get_effect_value(StatusEffectId.Frozen),
                    damage: config.projectile_damage,
                    is_shield: config.belt_size != 0,
                    fade_in_rate: config.fade_in_rate,
                    fade_in_clamp: config.fade_in_clamp,
                    goal_dir: dir,
                    projectile_fx: config.misc_sprites.projectile_fx,
                    oscillate_in_air: false,
                });
            }

            function get_coordinate_near_player() {
                var xx = obj_ari.x;
                var yy = obj_ari.y;

                if self.aggro == false {
                    return self.original_spawn_pos.clone();
                }

                repeat 100 {
                    var player_distance = irandom_range(config.teleport_distance_from_player[0], config.teleport_distance_from_player[1]);
                    var dir = irandom(360);
                    var pos_x = xx + lengthdir_x(player_distance, dir);
                    var pos_y = yy + lengthdir_y(player_distance, dir);
                    var ni = GRID.try_node_index_for_cell(pos_x div 8, pos_y div 8);
                    if ni == undefined {
                        continue;
                    }
                    if !GRID.node_collideable[ni]
                        && GRID.node_terrain_kind[ni] == TerrainKind.Ground
                    {
                        return Vec2(pos_x, pos_y);
                    }
                }

                return Vec2(xx, yy);
            }

            self.light = instance_create_depth(self.x, self.y, self.depth, par_light);
            self.light.tiered_light = Light.FlameSpirit;
            self.light.sprite_index = LIGHTS[Light.FlameSpirit][0];
            self.light.image_speed = 0;

            fsm = StateMachineBuilder(SpiritState.LEN)
                .add_state(
                    StateBuilder(SpiritState.Idle)
                        .create(function() {
                            self.acknowledged = false;
                        })
                        .start(function() {
                            owner.set_state_sprite(true, SpiritState.Idle);
                            duration = irandom_range(owner.config.idle_duration[0], owner.config.idle_duration[1]);
                        })
                        .step(function() {
                            if collision_circle(owner.x, owner.y, owner.config.attack_radius, obj_ari) {
                                duration -= 1;
                                if duration <= 0 {
                                    if !self.acknowledged {
                                        fsm.change_state(SpiritState.Acknowledgment);
                                        self.acknowledged = true;
                                    } else {
                                        fsm.change_state(SpiritState.Teleport);
                                    }
                                }
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(SpiritState.Recovery)
                        .start(function() {
                            owner.set_state_sprite(true, SpiritState.Idle);
                            duration = irandom_range(owner.config.tired_duration[0], owner.config.tired_duration[1]);
                        })
                        .step(function() {
                            if self.fsm.state_frame >= self.duration {
                                fsm.change_state(SpiritState.Teleport);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(SpiritState.Acknowledgment)
                        .start(function() {
                            owner.set_state_sprite();
                            duration = irandom_range(owner.config.acknowledgment[0], owner.config.acknowledgment[1]);
                            owner.play_state_tango();
                        })
                        .step(function() {
                            duration -= 1;
                            if duration <= 0 {
                                fsm.change_state(SpiritState.Teleport);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(SpiritState.Teleport)
                        .start(function() {
                            owner.set_state_sprite();
                            owner.light.tiered_light = Light.FlameSpiritDisappear;
                            owner.light.sprite_index = LIGHTS[Light.FlameSpiritDisappear][0];
                            owner.light.image_index = 0;
                            owner.can_overlap_ari = true;
                            teleport_target = owner.get_coordinate_near_player();
                            teleport_stall = -1;
                            TANGO.play("SoundEffects/Enemies/FlameSprite/Disappear", owner.x, owner.y);
                        })
                        //
                        .step(function() {
                            if self.teleport_stall >= 0 {
                                self.teleport_stall -= 1;

                                if self.teleport_stall <= 0 && owner.sprite_index != owner.config.misc_sprites.teleport_in {
                                    owner.sprite_index = owner.config.misc_sprites.teleport_in;
                                    owner.image_speed = 1;
                                    owner.image_index = 0;
                                    owner.light.tiered_light = Light.FlameSpiritAppear;
                                    owner.light.sprite_index = LIGHTS[Light.FlameSpiritAppear][0];
                                    owner.can_overlap_ari = false;
                                    TANGO.play("SoundEffects/Enemies/FlameSprite/Appear", owner.x, owner.y);
                                    shadow_caster_set_sprite(owner.shadow_caster, SHADOW_DICTIONARY.get(owner.sprite_index), true);
                                }
                            }
                        })
                        .anim_end(function() {
                            if owner.sprite_index == owner.config.misc_sprites.teleport_out {
                                owner.x = self.teleport_target.x;
                                owner.y = self.teleport_target.y;
                                owner.image_index = owner.image_number - 1;
                                owner.image_speed = 0;
                                self.teleport_stall = irandom_range(owner.config.teleport_duration[0], owner.config.teleport_duration[1]);
                            } else if owner.sprite_index == owner.config.misc_sprites.teleport_in {
                                fsm.change_state(SpiritState.Windup);
                            }
                        })
                        .stop(function() {
                            owner.image_speed = 1;
                            owner.light.tiered_light = Light.FlameSpirit;
                            owner.light.sprite_index = LIGHTS[Light.FlameSpirit][0];
                            owner.can_overlap_ari = false;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(SpiritState.Windup)
                        .start(function() {
                            owner.set_state_sprite();
                            fsm.blackboard.set("windup_tango", TANGO.play("SoundEffects/Enemies/FlameSprite/ChargeUp", owner.x, owner.y));
                            self.length = 0;
                            self.angle = 0;
                            self.shot = 0;

                            self.needs_belt = owner.config.belt_size != 0;
                        })
                        .step(function() {
                            if self.fsm.state_frame < owner.config.pre_attack_wait {
                                return;
                            }

                            if self.needs_belt {
                                self.needs_belt = false;

                                for (var i = 0; i < owner.config.belt_size; i++) {
                                    if owner.projectiles[i] != undefined && instance_exists(owner.projectiles[i]) {
                                        instance_destroy(owner.projectiles[i]);
                                    }
                                    var projectile = owner.generate_fireball(owner.x, owner.y, owner.depth, point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y + 4), owner.config);
                                    projectile.spd = 0;
                                    projectile.image_alpha = 0;
                                    owner.projectiles[i] = projectile;
                                }
                            }

                            self.angle += owner.config.rotation_speed * owner.status_effects.get_effect_value(StatusEffectId.Frozen);
                            self.length = lerp(self.length, owner.config.projectile_distance, 0.01 * owner.status_effects.get_effect_value(StatusEffectId.Frozen));

                            for (var i = array_length(owner.projectiles) - 1; i >= 0; i--) {
                                var projectile = owner.projectiles[i];
                                if projectile == undefined {
                                    continue;
                                }

                                if instance_exists(projectile) {
                                    if projectile.spd == 0 {
                                        projectile.x = owner.x + lengthdir_x(self.length + 6, self.angle + (i + 1) * (360 / owner.config.belt_size));
                                        projectile.y = owner.y + lengthdir_y(self.length + 6, self.angle + (i + 1) * (360 / owner.config.belt_size)) - 4;

                                        //
                                        if projectile.light != undefined && instance_exists(projectile.light) {
                                            projectile.light.x = projectile.x;
                                            projectile.light.y = projectile.y - 5;
                                        }
                                    }
                                } else {
                                    owner.projectiles[i] = undefined;
                                }
                            }

                            if (fsm.state_frame > (120 + owner.config.pre_attack_wait)) && (fsm.state_frame % owner.config.shot_rate < 1) {
                                var projectile = owner.projectiles[self.shot];
                                if projectile != undefined {
                                    projectile.spd = owner.config.projectile_speed;

                                    var miss = 0;
                                    if point_distance(projectile.x, projectile.y, owner.x, owner.y) >=
                                        point_distance(obj_ari.x, obj_ari.y, owner.x, owner.y)
                                    {
                                        miss = -90;
                                    }
                                    projectile.goal_dir = point_direction(projectile.x, projectile.y, obj_ari.x, obj_ari.y) + miss;

                                    owner.projectiles[self.shot] = undefined;
                                }
                                self.shot += 1;
                            }

                            if owner.config.belt_size != 0 && self.shot > (owner.config.belt_size - 1) {
                                self.fsm.change_state(SpiritState.Recovery);
                            }
                        })
                        .anim_end(function() {
                            if owner.config.belt_size == 0 {
                                self.fsm.change_state(SpiritState.Attack);
                            }
                        })
                        .stop(function() {
                            for (var i = array_length(owner.projectiles) - 1; i >= 0; i--) {
                                var projectile = owner.projectiles[i];
                                if projectile != undefined && instance_exists(projectile) {
                                    instance_destroy(projectile);
                                }
                                owner.projectiles[i] = undefined;
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(SpiritState.Attack)
                        .start(function() {
                            TANGO.play("SoundEffects/Enemies/FlameSprite/SpawnProjectile", owner.x, owner.y);
                            owner.set_state_sprite();
                            projectile = owner.generate_fireball(owner.x, owner.y, owner.depth, point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y), owner.config);
                        })
                        .anim_end(function() {
                            self.fsm.change_state(SpiritState.Tired);
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(SpiritState.Tired)
                        .start(function() {
                            duration = irandom_range(owner.config.tired_duration[0], owner.config.tired_duration[1]);
                            owner.set_state_sprite();
                        })
                        .step(function() {
                            duration -= 1;

                            if duration <= 0 {
                                owner.fsm.change_state(SpiritState.Idle);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(SpiritState.Hurt)
                    .start(function() {
                        owner.set_state_sprite();
                        CAMERA.add_trauma(0.1);
                        owner.show_damage = 10000;
                        owner.stop_windup_tango();
                    })
                    .anim_end(function() {
                        self.fsm.change_state(SpiritState.Teleport);
                    })
                    .stop(function() {
                        owner.show_damage = 0;
                    })
                    .spawn()
                )
                .add_state(
                    StateBuilder(SpiritState.Dying)
                        .start(function() {
                            CAMERA.add_trauma(0.2);
                            owner.set_state_sprite();
                            owner.play_state_tango();

                            real_pos = Vec2(owner.x, owner.y);
                            poof = false;

                            trauma = 0.5;
                            owner.show_damage = 10000;
                            TANGO.play("SoundEffects/Enemies/FlameSprite/Die", owner.x, owner.y);
                        })
                        .step(function() {
                            if self.poof == false && owner.image_index >= 1 {
                                monster_death_poof(owner);
                                self.poof = true;
                            } else {
                                owner.x = self.real_pos.x + self.trauma * self.trauma * perlin_noise_get(0) * sign(perlin_noise_get(50) * 2.0 - 1.0);
                                owner.y = self.real_pos.y + self.trauma * self.trauma * perlin_noise_get(1) * sign(perlin_noise_get(100) * 2.0 - 1.0);
                                self.trauma = approach(self.trauma, 0, FRAME_TIME);
                            }
                        })
                        .spawn()
                )
                .spawn(SpiritState.Idle, self, Map());

            //
            if instance_number(object_index) >= 3 {
                self.skip_destroy_logic = true;
                instance_destroy();
            }
        },
        step: function() {
            event_inherit(ObjectEvent.Step);

            if non_cutscene_pause() {
                return;
            }

            fsm.step();

            if !instance_exists(self) {
                return;
            }

            shadow_caster_set_image(self.shadow_caster, self.image_index);

            self.move.x += self.knockback_speed.x;
            self.move.y += self.knockback_speed.y;
            self.knockback_speed.set_scale(self.config.knockback_friction);

            //
            if self.knockback_speed.sqrd_magnitude() < 0.1 {
                self.knockback_speed.set_zero();
            }

            apply_friction();
            push_and_shove(par_monster, self.config.push_radius, self.config.push_force);
            push_from(obj_ari, self.config.pushed_radius, self.config.push_force * sqrt(obj_ari.move.sqrd_magnitude()));
            movement_and_collide(par_monster);

            if self.light != undefined && instance_exists(self.light) {
                self.light.x = self.x;
                self.light.y = self.y;

                if self.light.tiered_light != Light.FlameSpirit {
                    self.light.image_index = self.image_index;
                }
            }

            self.trauma = approach(self.trauma, 0, FRAME_TIME);
            depth = get_instance_depth(y, z);
            monster_outside_bounds(x, y, self);

            //
            if self.patience.use_circle {
                self.patience.pos.x = self.x - self.patience.diameter / 2;
                self.patience.pos.y = self.y - self.patience.diameter / 2;
            }
        },
        step_end: function() {
            if game_paused() {
                return;
            }

            shadow_caster_set_position(self.shadow_caster, x, y);
            process_white_vfx();
            self.process_status();

            fsm.end_step();

            if !instance_exists(self) {
                return;
            }

            if self.hit_points <= 0 {
                if self.fsm.current_state_id() != SpiritState.Dying {
                    self.fsm.change_state(SpiritState.Dying);
                    return;
                }
            } else while true {
                var next_dmg = self.receiver.try_take_damage();
                if next_dmg == undefined {
                    break;
                }

                self.process_tarball_status(next_dmg.tarball);

                var current_state = self.fsm.current_state_id();

                if current_state == SpiritState.Teleport || current_state == SpiritState.Attack {
                    break;
                }
                self.patience.value = PATIENCE_DAMAGED;


                self.hit_points -= next_dmg.tarball.damage;
                self.stats_entry.damage_taken += next_dmg.tarball.damage;
                self.stats_entry.damage_taken_count += 1;


                next_dmg.tarball.calculate_knockback(x, y, self.knockback_speed);
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

                if self.hit_points <= 0.0 {
                    self.fsm.change_state(SpiritState.Dying);
                    break;
                } else {
                    switch self.fsm.current_state_id() {
                        case SpiritState.Idle:
                        case SpiritState.Teleport:
                        case SpiritState.Attack:
                        case SpiritState.Tired:
                        case SpiritState.Acknowledgment:
                        case SpiritState.Recovery:
                            self.fsm.change_state(SpiritState.Hurt);
                            break;

                        case SpiritState.Hurt:
                            self.image_index = 0;
                            break;
                        case SpiritState.Windup:
                            break;
                        default: crash("unexpected state!")
                    }
                }
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
