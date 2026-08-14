object_create(
    "obj_monster_rock_stack",
    object_reserve("par_monster"),
    {
        sprite_index: spr_monster_rock_stack_main_walk_south,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.lut_texture = undefined;
            self.uvs = undefined;

            homie = undefined;
            homie_attached = true;
            collided_last_frame = false;
            shadow_scale = 1;
            executed = false

            fall_speed = 0;
            override_allowed = false;
            y_offset = 0;

            //
            dependent = false;

            function get_cardinal() {
                return angle_to_cardinal(self.dir);
            }

            function calculate_flipper() {
                if angle_to_cardinal(self.dir) == Cardinal.West {
                    return -1;
                } else {
                    return 1;
                }
            }

            function homie_valid() {
                return self.homie != undefined && instance_exists(self.homie) && self.homie.fsm.current_state_id() != RockStackState.Dying
            }

            //
            //
            function can_land(xx, yy) {
                var ni = GRID.try_node_index_for_room_position(xx, yy);
                if ni == undefined {
                    return false;
                }

                return GRID.node_collideable[ni] == false && GRID.node_terrain_kind[ni] == TerrainKind.Ground;
            }

            self.check_collision = function(xx, yy) {
                var ni = GRID.try_node_index_for_room_position(xx, yy);
                if ni == undefined {
                    return true;
                }
                if self.override_allowed {
                    return false;
                }

                if self.fsm.current_state_id() == RockStackState.Launching {
                    return GRID.node_can_jump_over[ni] && GRID.node_collideable[ni] == false && GRID.node_terrain_kind[ni] != TerrainKind.Ground;
                } else {
                    return GRID.node_collideable[ni] || GRID.node_terrain_kind[ni] != TerrainKind.Ground;
                }
            }

            acknowledged = false;

            //
            if instance_number(object_index) >= 3 {
                self.fsm = undefined;
                self.skip_destroy_logic = true;
                instance_destroy();
                return;
            }

            fsm = StateMachineBuilder(RockStackState.LEN)
                .add_state(
                    StateBuilder(RockStackState.Idle)
                        .create(function() {
                            //
                            if owner[$ "position"] == undefined {
                                var config = MONSTER_PROTOTYPES[MonsterId.RockStack];
                                owner.position = RockStackPosition.Bottom;
                                owner.homie = instance_create_depth(owner.x, owner.y - 8, owner.depth - 1, obj_monster_rock_stack, {
                                    config,
                                    monster_id: MonsterId.RockStack,
                                    position: RockStackPosition.Top
                                });
                                owner.homie.homie = owner;
                                owner.homie.can_overlap_ari = false;
                                owner.homie.shadow_scale = 0;

                                //
                                owner.homie.lut_texture = owner.config.lut;
                                var uvs_full = sprite_get_uvs(owner.config.lut, 0);
                                owner.homie.uvs = [uvs_full[0], uvs_full[1]];
                            }
                        })
                        .start(function() {
                            owner.dir = 270;
                            self.stall = owner.acknowledged ? 30 : 0;
                            owner.set_state_sprite(true, RockStackState.Idle);
                            owner.can_overlap_ari = false;
                            owner.dependent = false;
                        })
                        .step(function() {
                            if self.stall > 0 {
                                self.stall -= 1;
                                return;
                            }
                            if owner.homie_valid() == false {
                                fsm.change_state(RockStackState.Walk);
                                return;
                            }

                            //
                            if collision_circle(owner.x, owner.y, owner.config.attack_radius, obj_ari) && owner.homie_valid() {
                                if owner.acknowledged {
                                    if owner.position == RockStackPosition.Bottom {
                                        fsm.change_state(RockStackState.Windup);
                                        TANGO.play("SoundEffects/Enemies/RockStack/Flash", owner.x, owner.y);
                                    }
                                } else {
                                    fsm.change_state(RockStackState.Acknowledgment);
                                    owner.homie.fsm.change_state(RockStackState.Acknowledgment);
                                }
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockStackState.Acknowledgment)
                        .start(function() {
                            owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                            if owner.position == RockStackPosition.Top {
                                owner.set_state_sprite();
                            }
                            owner.acknowledged = true;
                        })
                        .step(function() {
                            if floor(owner.image_index) >= owner.image_number - 1 {
                                fsm.change_state(RockStackState.Idle);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockStackState.Walk)
                        .start(function() {
                            self.can_change_direction = false;
                            self.wander_timer = 0;
                            self.wander_frequency = owner.config.wander_frequency;
                            owner.set_state_sprite();
                            owner.can_overlap_ari = false;
                            owner.dependent = false;
                            self.play_walk = true;
                            self.jump_speed = 0;
                            self.abandoned_init = true;
                            self.reset_direction = true;
                        })
                        .step(function() {
                            owner.set_state_sprite(false);
                            var homie_alive = owner.homie_valid();

                            if owner.z < 0 {
                                owner.z += self.jump_speed;
                                self.jump_speed += owner.config.jump_gravity;
                            } else {
                                owner.z = 0;
                            }

                            if homie_alive && owner.homie.fsm.current_state_id() == RockStackState.Hopping {
                                return;
                            }
                            var spd = owner.config.speed;
                            if homie_alive {
                                owner.dir = point_direction(owner.x, owner.y, owner.homie.x, owner.homie.y);

                                //
                                if point_distance(owner.x, owner.y, owner.homie.x, owner.homie.y) < 36 {
                                    owner.override_allowed = true;
                                }
                            } else {
                                //
                                self.wander_timer += 1;

                                if self.wander_timer % self.wander_frequency == 0 {
                                    owner.dir = irandom(360);
                                }

                                if self.abandoned_init {
                                    //
                                    owner.z = owner.y_offset;
                                    owner.y_offset = 0;
                                    self.abandoned_init = false;
                                }
                            }

                            owner.move.x = lengthdir_x(spd, owner.dir);
                            owner.move.y = lengthdir_y(spd, owner.dir);

                            if floor(owner.image_index) != 0 {
                                owner.move.set_zero();
                                if self.play_walk {
                                    TANGO.play("SoundEffects/Enemies/RockStack/Hop", owner.x, owner.y);
                                    self.play_walk = false;
                                }
                            } else {
                                self.play_walk = true;
                            }

                            if homie_alive && point_distance(owner.x, owner.y, owner.homie.x, owner.homie.y) < owner.config.hop_threshold && owner.position == RockStackPosition.Bottom {
                                fsm.change_state(RockStackState.Hopping);
                                fsm.blackboard.set("homie_location", Vec2(owner.homie.x, owner.homie.y));
                            }
                        })
                        .stop(function() {
                            owner.can_overlap_ari = false;
                            owner.override_allowed = false;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockStackState.Hopping)
                        .start(function() {
                            self.spd = Vec2();
                            self.jump_speed = owner.config.jump_speed;

                            if owner.homie_valid() {
                                owner.can_overlap_ari = true;
                                owner.dir = point_direction(owner.x, owner.y, owner.homie.x, owner.homie.y);
                                original_spd = Vec2(owner.homie.x - owner.x, owner.homie.y - owner.y);
                                original_spd.normalized();
                                original_spd.set_scale(1.2);

                                spd = original_spd.clone();

                                owner.override_allowed = true;
                            } else {
                                fsm.change_state(RockStackState.Walk);
                            }
                            owner.set_state_sprite();
                            TANGO.play("SoundEffects/Enemies/RockStack/ReStackStart", owner.x, owner.y);
                            self.lock_height = false;
                            self.homie_location = fsm.blackboard.take("homie_location");
                        })
                        .step(function() {
                            if owner.homie_valid() {
                                owner.dir = point_direction(owner.x, owner.y, owner.homie.x, owner.homie.y);
                                self.spd = Vec2(owner.homie.x - owner.x, owner.homie.y - owner.y);
                                if self.spd.is_zero() == false {
                                    self.spd.normalized();
                                    self.spd.set_scale(1.2);
                                }
                            }

                            //
                            owner.move.x = self.spd.x;
                            owner.move.y = self.spd.y;

                            owner.z += self.jump_speed;
                            self.jump_speed += owner.config.jump_gravity;

                            if owner.z >= owner.config.homie_offset && self.jump_speed > 0 && owner.homie_valid() {
                                owner.x = owner.homie.x;
                                owner.y = owner.homie.y;
                                owner.homie_attached = true;
                                owner.homie.homie_attached = true;
                                var temp_position = owner.position;
                                owner.position = owner.homie.position;
                                owner.homie.position = temp_position;
                                owner.homie.fsm.change_state(RockStackState.Idle);
                                owner.homie.dependent = true;
                                fsm.change_state(RockStackState.Idle);
                                TANGO.play("SoundEffects/Enemies/RockStack/ReStackTogether", owner.x, owner.y);
                                create_animation_effect(owner.x, owner.y + owner.config.homie_offset / 2, owner.depth, owner.config.landing_vfx);
                            }

                            if owner.z <= 0 && owner.homie_valid() == false {
                                fsm.change_state(RockStackState.Walk);
                                owner.z = 0;
                                owner.x = self.homie_location.x;
                                owner.y = self.homie_location.y;
                            }
                        })
                        .stop(function() {
                            owner.override_allowed = false;
                            owner.can_overlap_ari = false;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockStackState.Windup)
                        .start(function() {
                            owner.dir = 270;
                            owner.set_state_sprite();
                            if owner.homie_valid() {
                                owner.homie.sprite_index = owner.config.misc_sprites.windup_top;
                                owner.homie.image_index = 0;
                                create_animation_effect(owner.homie.x, owner.homie.y, owner.homie.depth - 1, owner.config.misc_sprites.windup_top_fx);
                            }
                        })
                        .step(function() {
                            if owner.hit_points > 0 && floor(owner.image_index) >= owner.image_number - 1 {
                                if owner.homie_valid() {
                                    owner.homie_attached = false;
                                    owner.homie.homie_attached = false;
                                    owner.homie.fsm.change_state(RockStackState.Launching);
                                    owner.homie.dependent = true;
                                    owner.homie.x = owner.x;
                                    owner.homie.y = owner.y;
                                    fsm.change_state(RockStackState.Catching);
                                } else {
                                    fsm.change_state(RockStackState.Walk);
                                }
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockStackState.Catching)
                        .start(function() {
                            owner.dir = 270;
                            owner.set_state_sprite();

                            if fsm.last_state_id == RockStackState.Hurt {
                                owner.image_speed = 0;
                                owner.image_index = 0;
                            }
                        })
                        .anim_end(function() {
                            owner.image_speed = 0;
                            owner.image_index = 0;
                        })
                        .stop(function() {
                            owner.image_speed = 1;
                            owner.image_index = 0;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockStackState.Launching)
                        .create(function() {
                            //
                            function on_hit(tarball) {
                                if tarball.parent_object() == obj_monster_rock_stack
                                    && owner.homie_valid()
                                    && tarball.parent_id.homie.id == owner.id
                                    && point_distance(owner.x, owner.y, tarball.parent_id.x, tarball.parent_id.y) < owner.config.execution_distance
                                {
                                    fsm.change_state(RockStackState.Dying);
                                    owner.homie.fsm.change_state(RockStackState.Dying);
                                    owner.homie.dependent = true;

                                    spawn_damage_numbers(
                                        owner,
                                        owner.config.damage_number_offset,
                                        999,
                                        DamageFlag.CRITICAL,
                                    );
                                }
                            }
                        })
                        .start(function() {
                            owner.dir = 270;
                            owner.set_state_sprite();
                            owner.shadow_scale = 1;
                            owner.can_overlap_ari = true;
                            owner.dependent = false;
                            self.rising = true;
                            self.tarball_player = undefined;
                            self.tarball_rock = undefined;
                            self.falling_timer = 0;
                            self.fell = false;
                            self.fell_stall = irandom_range(owner.config.fell_stall[0], owner.config.fell_stall[1]);
                            self.air_stall = irandom_range(owner.config.air_stall[0], owner.config.air_stall[1]);
                            self.air_wait = irandom_range(owner.config.air_wait[0], owner.config.air_wait[1]);
                            self.spd = owner.config.air_speed_starting;
                            self.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                            self.fall_spd = owner.config.fall_speed;
                            self.anim_played = false;
                            TANGO.play("SoundEffects/Enemies/RockStack/Liftoff", owner.x, owner.y);

                            self.played_warning = false;
                        })
                        .step(function() {
                            if self.rising {
                                if owner.z <= -144 {
                                    //
                                    if self.air_stall > 0 {
                                        owner.mask_index = spr_monster_rock_stack_main_walk_south;
                                        var can_land = owner.can_land(owner.x, owner.y);
                                        if can_land {
                                            self.air_stall -= 1;
                                        } else {
                                            self.air_stall = max(self.air_stall - 1, self.air_wait + 1);
                                        }

                                        if self.air_stall > self.air_wait {
                                            self.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                                            owner.move.x = lengthdir_x(self.spd, self.dir);
                                            owner.move.y = lengthdir_y(self.spd, self.dir);
                                            self.spd = clamp(self.spd + owner.config.air_speed_acceleration, 0, owner.config.air_speed_max);
                                        } else if self.played_warning == false {
                                            self.played_warning = true;
                                            TANGO.play("SoundEffects/Enemies/RockStack/DropWarning", owner.x, owner.y);
                                        }
                                    } else {
                                        self.rising = false;
                                    }
                                    owner.image_alpha = 0;
                                    owner.sprite_index = undefined;
                                    owner.mask_index = undefined;
                                    owner.y_offset = 0;
                                } else {
                                    owner.z += owner.config.rise_speed;
                                }
                            } else {
                                owner.image_alpha = 1;
                                owner.set_state_sprite();
                                owner.mask_index = spr_monster_rock_stack_main_walk_south;

                                self.falling_timer += 1;
                                if self.fell {
                                    if self.anim_played == false {
                                        owner.sprite_index = owner.config.misc_sprites.landing_top;
                                    }
                                    owner.can_overlap_ari = false;

                                    //
                                    self.fell_stall -= 1;
                                    if self.fell_stall <= 0 {
                                        fsm.change_state(RockStackState.Walk);
                                        if owner.homie_valid() {
                                            owner.homie.fsm.change_state(RockStackState.Walk);
                                            owner.homie.dependent = true;
                                        }
                                    }
                                } else {
                                    if owner.z >= 0 {
                                        self.fell = true;
                                        owner.z = 0;
                                        if self.tarball_player == undefined {
                                            self.tarball_player = TarballBuilder(owner.x, owner.y, owner.config.execution_width, owner.config.execution_height, owner.config.damage)
                                                .set_offset(-owner.config.execution_width / 2, -owner.config.execution_height / 2)
                                                .set_circle()
                                                .set_timer(6)
                                                .set_parent(owner)
                                                .set_provenance(owner.monster_id, owner.stats_entry)
                                                .gen();
                                            create_animation_effect(owner.x, owner.y, get_floor_depth() - 1, spr_fx_attack_sword_ground_pound_back);
                                            create_animation_effect(owner.x, owner.y, get_floor_depth() - 1, spr_fx_attack_sword_ground_pound_front);

                                        }
                                        if self.tarball_rock == undefined {
                                            self.tarball_rock = TarballBuilder(owner.x, owner.y, owner.config.execution_width, owner.config.execution_height, 0, CombatTarget.Enemy)
                                                .set_offset(-owner.config.execution_width / 2, -owner.config.execution_height / 2)
                                                .set_circle()
                                                .set_rockstack()
                                                .set_timer(6)
                                                .set_parent(owner.id)
                                                .notify(self)
                                                .set_provenance(owner.monster_id, owner.stats_entry)
                                                .gen();
                                            create_animation_effect(owner.x, owner.y, get_floor_depth() - 1, spr_fx_attack_sword_ground_pound_back);
                                            create_animation_effect(owner.x, owner.y, get_floor_depth() - 1, spr_fx_attack_sword_ground_pound_front);
                                        }
                                        create_animation_effect(owner.x, owner.y, owner.depth, owner.config.landing_vfx);
                                        TANGO.play("SoundEffects/Enemies/RockStack/Impact", owner.x, owner.y);
                                    } else {
                                        owner.z += self.fall_spd;
                                        self.fall_spd += owner.config.fall_acceleration;
                                    }
                                }
                            }
                        })
                        .stop(function() {
                            owner.set_state_sprite();
                            owner.image_alpha = 1;
                            owner.can_overlap_ari = false;
                            owner.z = 0;
                            if instance_exists(self.tarball_player) {
                                instance_destroy(self.tarball_player);
                                self.tarball_player = undefined;
                            }

                            if instance_exists(self.tarball_rock) {
                                instance_destroy(self.tarball_rock);
                                self.tarball_rock = undefined;
                            }

                            owner.mask_index = spr_monster_rock_stack_main_walk_south;
                            owner.y_offset = 0;
                        })
                        .anim_end(function() {
                            if owner.sprite_index == owner.config.misc_sprites.landing_top {
                                owner.set_state_sprite(true, RockStackState.Idle);
                                self.anim_played = true;
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockStackState.Hurt)
                        .start(function() {
                            owner.set_state_sprite();
                            owner.show_damage = 10000;
                        })
                        .step(function() {
                            if owner.hit_points > 0 && floor(owner.image_index) >= owner.image_number - 1 {
                                fsm.change_state(fsm.last_state_id);
                            }
                        })
                        .stop(function() {
                            owner.show_damage = 0;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockStackState.Dying)
                        .start(function() {
                            owner.trauma = 0.7;
                            owner.set_state_sprite();
                            owner.show_damage = 10000;
                            poof = false;
                            if owner.homie_valid() {
                                owner.homie.homie = undefined;
                                owner.homie.homie_attached = false;
                                owner.homie_attached = false;
                            }
                            TANGO.play("SoundEffects/Enemies/RockStack/Die", owner.x, owner.y);
                        })
                        .step(function() {
                            if poof == false && owner.image_index >= 1 {
                                monster_death_poof(owner);

                                if owner.executed {
                                    create_drops_and_essence(
                                        owner.config.super_drops,
                                        owner.config.essence,
                                        owner.x,
                                        owner.y,
                                        owner.monster_id,
                                        0
                                    );
                                }
                                poof = true;
                            }
                            CAMERA.add_trauma(0.4);
                        })
                        .spawn()
                )
                .spawn(RockStackState.Idle, self, Map());
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

            var homie_alive = self.homie_valid();
            var current_mask = self.mask_index;
            self.mask_index = spr_monster_rock_stack_main_walk_south;
            self.collided_last_frame = movement_and_collide();
            self.mask_index = current_mask;

            //
            depth = get_instance_depth(y, z);

            if self.position == RockStackPosition.Bottom
                && self.homie_attached
                && homie_alive
            {
                self.homie.x = self.x;
                self.homie.y = self.y;
                self.homie.z = -1;
                self.homie.y_offset = self.config.homie_offset;
                self.homie.shove_factor = 0;
            }

            if self.fsm.current_state_id() == RockStackState.Walk
                && self.fsm.current_state_id() != RockStackState.Hopping
                && (homie_alive && self.homie.fsm.current_state_id() != RockStackState.Hopping)
            {
                apply_friction();
                monster_outside_bounds(x, y, self);
                push_and_shove(par_monster, self.config.push_radius, self.config.push_force);
                push_from(obj_ari, self.config.pushed_radius, self.config.push_force * sqrt(obj_ari.move.sqrd_magnitude()));
            }

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

            if self.fsm.current_state_id() == RockStackState.Launching {
                var cs = self.fsm.current_state();
                if cs.air_stall <= cs.air_wait {
                    shadow_caster_set_image(self.shadow_caster, self.image_index);
                } else {
                    shadow_caster_set_image(self.shadow_caster, 0);
                }
            } else {
                shadow_caster_set_image(self.shadow_caster, self.image_index);
            }

            var flipper = 1;
            if self.dir >= 90 && self.dir < 270 {
                flipper = -1;
            }

            fsm.end_step();

            if !instance_exists(self) {
                return;
            }

            if self.hit_points <= 0 {
                if self.fsm.current_state_id() != RockStackState.Dying {
                    self.fsm.change_state(RockStackState.Dying);
                    return;
                }
            } else {
                var took_any_damage = false;

                while true {
                    var next_dmg = self.receiver.try_take_damage();
                    if next_dmg == undefined {
                        break;
                    }

                    if (self.fsm.current_state_id() == RockStackState.Launching && self.fsm.current_state().fell == false) || self.fsm.current_state_id() == RockStackState.Hopping {
                        break;
                    }

                    if next_dmg.status != ReceiverStatus.Normal {
                        continue;
                    }
                    self.process_tarball_status(next_dmg.tarball);

                    took_any_damage = true;
                    var dmg = next_dmg.tarball.damage;


                    if next_dmg.tarball.parent_object() == obj_monster_rock_stack {
                        self.dmg = 0;
                    }

                    self.hit_points -= dmg;
                    self.stats_entry.damage_taken += dmg;
                    self.stats_entry.damage_taken_count += 1;

                    if dmg != 0 {
                        spawn_damage_numbers(
                            self,
                            self.config.damage_number_offset,
                            dmg,
                            next_dmg.tarball.damage_flag(),
                        );
                    }
                    next_dmg.tarball.calculate_knockback(x, y, self.move);

                    var on_hit = self.config.misc_tango.strong_damage;

                    if next_dmg.tarball.critical {
                        monster_critical_fx(self);
                        set_rumble(RumbleKind.SwordStrong);
                    } else {
                        set_rumble(RumbleKind.SwordWeak);
                    }

                    TANGO.play(on_hit, x, y);
                }

                if took_any_damage && dmg != 0 {
                    switch self.fsm.current_state_id() {
                        case RockStackState.Walk:
                        case RockStackState.Catching:
                        case RockStackState.Idle:
                            if self.dependent {
                                self.dependent = false;
                                break;
                            }
                            self.fsm.change_state(RockStackState.Hurt);
                            break;
                        default:
                            self.show_damage = 30;
                            break;
                    }

                    self.patience.value = PATIENCE_DAMAGED;

                    if self.hit_points <= 0 {
                        self.fsm.change_state(RockStackState.Dying);
                    }
                }
            }
        },
        draw: function() {
            if self.sprite_index == undefined {
                return;
            }

            if self.lut_texture != undefined {
                shader_set_texture("u_LutTexture", self.lut_texture, 0, "u_LutTexelSize");
                gpu_set_extra(UberShaderKind.PaletteSwap, self.uvs[0], self.uvs[1], 1.0);
            }

            var flipper = self.calculate_flipper();

            //

            var xx;
            var yy;
            if self.trauma != 0.0 {
                xx = x + self.trauma * self.trauma * perlin_noise_get(0) * sign(perlin_noise_get(50) * 2.0 - 1.0);
                yy = y + self.trauma * self.trauma * perlin_noise_get(1) * sign(perlin_noise_get(100) * 2.0 - 1.0);
            } else {
                xx = x;
                yy = y;
            }

            draw_sprite_ext(
                sprite_index,
                image_index,
                xx,
                yy + self.z + self.y_offset,
                image_xscale * flipper,
                image_yscale,
                image_angle,
                image_blend,
                image_alpha,
            );

            if self.lut_texture != undefined {
                gpu_reset_extra();
            }

            white_vfx();
        },
    }
);
