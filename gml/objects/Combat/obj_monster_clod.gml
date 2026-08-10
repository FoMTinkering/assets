object_create(
    "obj_monster_clod",
    object_reserve("par_monster"),
    {
        sprite_index: spr_monster_rockclod_main_idle_south,
        mask_index: string_to_asset("spr_monster_clod_projectile_collisionbox"),
        create: function() {
            event_inherit(ObjectEvent.Create);

            collided_last_frame = false;
            collision_debounce = 0;
            knockback_big = undefined;
            bomb_ammo = config.bomb_ammo;
            bomb_patience = 0;
            bomb_stagger = false;
            landing = false;
            fall_speed = 0;
            mask_index = self.config.launcher ? self.config.collision_jump : self.config.collision_default;
            loot_drop = Vec2(self.x, self.y);
            falling_to_death = false;

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

            function walk_or_windup() {
                if self.aggro && point_distance(self.x, self.y, obj_ari.x, obj_ari.y) < self.config.attack_radius {
                    self.fsm.change_state(RockclodState.Windup);
                } else {
                    self.fsm.change_state(RockclodState.Walk);
                }
            }

            self.check_collision = function(xx, yy) {
                var ni = GRID.try_node_index_for_room_position(xx, yy);

                if self.fsm.current_state_id() == RockclodState.Flying &&
                    ni != undefined &&
                    GRID.node_can_jump_over[ni] &&
                    GRID.node_object_id[ni] == undefined {
                    return false;
                }

                return ni == undefined || GRID.node_collideable[ni];
            }

            fsm = StateMachineBuilder(RockclodState.LEN)
                .add_state(
                    StateBuilder(RockclodState.Idle)
                        .start(function() {
                            owner.set_state_sprite(true, RockclodState.Idle);
                            owner.dir = owner.original_dir;
                            if owner.config.attack_sequence_turn != -1 {
                                self.blackboard.set("attack_angle", 0)
                            }
                        })
                        .step(function() {
                            if owner.aggro {
                                fsm.change_state(RockclodState.Acknowledgment);
                            }
                        })
                        .anim_end(function() {
                            //
                            if chance_percent(15) {
                                owner.original_dir = irandom_range(180, 360);
                                owner.dir = owner.original_dir;
                            }
                            owner.set_state_sprite();
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockclodState.Acknowledgment)
                        .start(function() {
                            owner.track_player();
                            owner.play_state_tango();
                            duration = irandom_range(owner.config.acknowledgment[0], owner.config.acknowledgment[1]);
                        })
                        .step(function() {
                            owner.track_player();

                            if fsm.state_frame >= self.duration {
                                owner.walk_or_windup();
                            }
                        })
                        .anim_end(function() {
                            owner.image_index = owner.image_number - 1;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockclodState.Walk)
                        .start(function() {
                            target_x = obj_ari.x;
                            target_y = obj_ari.y;

                            owner.play_state_tango();
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

                            if floor(owner.image_index) != 0 {
                                owner.move.set_zero();
                            }
                            owner.set_state_sprite(false);
                        })
                        .end_step(function() {
                            //
                            if owner.acknowledgement_reset {
                                fsm.change_state(RockclodState.Acknowledgment);
                            }
                        })
                        .anim_end(function() {
                            if owner.aggro
                                && point_distance(owner.x, owner.y, self.target_x, self.target_y) < owner.config.attack_radius
                            {
                                fsm.change_state(RockclodState.Windup);
                            } else if point_distance(owner.x, owner.y, self.target_x, self.target_y) < 1 {
                                owner.x = self.target_x;
                                owner.y = self.target_y;

                                fsm.change_state(RockclodState.Idle);
                            } else {
                                owner.play_state_tango();
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockclodState.Windup)
                        .create(function() {
                            self.attack_count = 0;
                            self.attack_angle = 0;
                        })
                        .start(function() {
                            self.blackboard.set("is_bomb", owner.config.bomber && owner.bomb_ammo > 0 && (chance_percent(owner.config.bomb_chance) || owner.bomb_patience >= owner.config.bomb_force_limit) && owner.bomb_stagger);
                            self.bomb_stall = owner.config.bomb_stall;

                            if self.blackboard.get("is_bomb") {
                                TANGO.play("SoundEffects/Enemies/Rockclod/BombChargeUp", owner.x, owner.y);
                                create_animation_effect_on_object(owner, spr_fx_monster_rockclod_bomb_windup_smoke, -1, 0);
                            }

                            if owner.config.launcher {
                                TANGO.play("SoundEffects/Enemies/Rockclod/JumpChargeUp", owner.x, owner.y);
                            }

                            owner.set_state_sprite();
                            owner.play_state_tango();

                            timer = irandom_range(owner.config.windup[0], owner.config.windup[1]);

                            if fsm.last_state_id == RockclodState.Attack {
                                self.attack_count += 1;
                                timer *= 0.5;
                            } else {
                                self.attack_count = 1;
                                if owner.config.attack_sequence_turn != -1 {
                                    self.attack_angle = 0;
                                }
                            }
                            if owner.config.attack_sequence_turn != -1 {
                                var dir_vec = Vec2(obj_ari.x - owner.x, obj_ari.y - owner.y);
                                if dir_vec.is_zero() == false {
                                    dir_vec.normalize();
                                }
                                var radian_angle = arctan2(dir_vec.y, dir_vec.x) + (pi/180) * self.attack_angle;
                                dir_vec.x = cos(radian_angle);
                                dir_vec.y = sin(radian_angle);
                                owner.dir = point_direction(0, 0, dir_vec.x, dir_vec.y);
                                owner.image_speed = owner.config.attack_sequence_image_speed;
                                self.blackboard.set("projectile_dir", dir_vec);
                                self.attack_angle += owner.config.attack_sequence_turn;
                            }
                            if self.attack_count < owner.config.attack_sequence {
                                self.blackboard.insert("return_to_windup", true);
                            }
                        })
                        .step(function() {
                            if self.blackboard.get("is_bomb") == true && self.bomb_stall > 0 {
                                self.bomb_stall -= 1;
                                return;
                            }

                            if owner.config.attack_sequence_turn == -1 {
                                owner.track_player();
                            }

                            if fsm.last_state_id == RockclodState.Attack
                                && self.fsm.state_frame >= self.timer
                                && owner.knockback_big == undefined
                            {
                                fsm.change_state(self.owner.config.launcher ? RockclodState.Flying : RockclodState.Attack);

                            }
                        })
                        .anim_end(function() {
                            if owner.knockback_big == undefined && !(self.blackboard.get("is_bomb") == true && self.bomb_stall > 0) {
                                fsm.change_state(self.owner.config.launcher ? RockclodState.Flying : RockclodState.Attack);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockclodState.Attack)
                        .start(function() {
                            var dir_vec = Vec2(obj_ari.x - owner.x, obj_ari.y - owner.y);

                            if dir_vec.is_zero() == false {
                                dir_vec.normalized();
                            }

                            if owner.config.attack_sequence_turn != -1 {
                                dir_vec = self.blackboard.set("projectile_dir", dir_vec);
                                owner.dir = point_direction(0, 0, dir_vec.x, dir_vec.y);
                            }

                            if owner.config.launcher {
                                TANGO.play("SoundEffects/Enemies/Rockclod/Jump", owner.x, owner.y);
                            }

                            owner.set_state_sprite();
                            owner.play_state_tango();
                            var is_bomb = self.blackboard.take("is_bomb");
                            var spd = dir_vec.clone();
                            if is_bomb {
                                spd.set_scale(owner.config.bomb_projectile_speed);
                            } else {
                                spd.set_scale(owner.config.projectile_speed);
                            }
                            spd.set_scale(owner.status_effects.get_effect_value(StatusEffectId.Frozen));
                            var offset = dir_vec.scale(4);
                            var perp = dir_vec.perpendicular();

                            var half = (owner.config.attack_legion / 2) - 0.5;
                            var n = half * -4;

                            for (var i = 0; i < owner.config.attack_legion; i++) {
                                var offset_to_the_offset = perp.scale(n + 4 * i);
                                if is_bomb {
                                    TANGO.play("SoundEffects/Enemies/Rockclod/BombSpit", owner.x, owner.y);
                                    instance_create_depth(
                                    owner.x + offset.x + offset_to_the_offset.x,
                                    owner.y + offset.y + offset_to_the_offset.y,
                                    owner.depth - 16,
                                    obj_monster_clod_bomb,
                                    {
                                        spd,
                                        parent_clod: owner.id,
                                        monster_id: owner.monster_id,
                                        stats_entry: owner.stats_entry,
                                        dmg: owner.config.damage * 2,
                                        rock_particle: owner.config.misc_sprites.rock_particle,
                                        death_tango: owner.config.misc_tango.projectile_break,
                                        reflect_tango: owner.config.misc_tango.projectile_reflect,
                                        bomb_radius: owner.config.bomb_radius,
                                        sprite_index: owner.config.bomb_sprite,
                                        bomb_fx: owner.config.bomb_sprite_fx,
                                        delay: owner.config.bomb_delay
                                    });

                                    owner.bomb_ammo -= 1;
                                    owner.bomb_patience = 0;
                                } else {
                                    instance_create_depth(
                                        owner.x + offset.x + offset_to_the_offset.x,
                                        owner.y + offset.y + offset_to_the_offset.y,
                                        owner.depth - 16,
                                        obj_monster_clod_projectile,
                                        create_clod_projectile(spd, owner.id, owner.monster_id, owner.stats_entry, owner.config),
                                    );
                                    owner.bomb_patience += 1;
                                }
                                owner.bomb_stagger = !owner.bomb_stagger;
                            }
                            if owner.config.attack_radial_degree != 0 {
                                var dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);

                                var high_dir = Vec2(dcos(dir + 45), -dsin(dir + 45));
                                instance_create_depth(
                                    owner.x + high_dir.x * 4,
                                    owner.y + high_dir.y * 4,
                                    owner.depth - 16,
                                    obj_monster_clod_projectile,
                                    create_clod_projectile(high_dir.scale(owner.config.projectile_speed * owner.status_effects.get_effect_value(StatusEffectId.Frozen)), owner.id, owner.monster_id, owner.stats_entry, owner.config),
                                );

                                var low_dir = Vec2(dcos(dir - 45), -dsin(dir - 45));
                                instance_create_depth(
                                    owner.x + low_dir.x * 4,
                                    owner.y + low_dir.y * 4,
                                    owner.depth - 16,
                                    obj_monster_clod_projectile,
                                    create_clod_projectile(low_dir.scale(owner.config.projectile_speed * owner.status_effects.get_effect_value(StatusEffectId.Frozen)), owner.id, owner.monster_id, owner.stats_entry, owner.config),
                                );
                            }
                        })
                        .step(function() {
                            if floor(owner.image_index) == 1 && self.blackboard.get_or("return_to_windup", false) {
                                self.blackboard.take("return_to_windup");
                                fsm.change_state(RockclodState.Windup);
                            }
                        })
                        .anim_end(function() {
                            owner.image_speed = 1;
                            fsm.change_state(RockclodState.Tired);
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockclodState.Tired)
                        .start(function() {
                            //
                            owner.set_state_sprite();

                            timer = irandom_range(owner.config.tired[0], owner.config.tired[1]);
                        })
                        .step(function() {
                            if fsm.state_frame >= self.timer {
                                owner.walk_or_windup();
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockclodState.Flying)
                        .create(function() {
                            function on_hit(tarball) {
                                var po = tarball.parent_object();
                                if tarball.target == CombatTarget.Enemy {
                                    if (po == obj_monster_clod_projectile || po == obj_monster_enchantern_projectile || po == obj_monster_bat_sonic_attack || (po == obj_monster_clod && tarball.parent_id.fsm.current_state_id() == RockclodState.Flying))
                                        && self.reflected && self.reflection_cd == 0
                                    {
                                        self.reflected = false;
                                        self.reflection_cd = 5;
                                        if self.tarball != undefined && instance_exists(self.tarball) {
                                            self.tarball.target = CombatTarget.Player;
                                        }
                                        owner.dir += 180;
                                        self.spd.set_scale(-1);
                                    } else {
                                        owner.fsm.change_state(RockclodState.Dying);
                                        owner.move.x = 0
                                        owner.move.y = 0
                                        spawn_damage_numbers(
                                            owner,
                                            owner.config.damage_number_offset,
                                            999,
                                            DamageFlag.HEAVY
                                        );
                                    }
                                } else {
                                    var ni = GRID.try_node_index_for_room_position(owner.x, owner.y);

                                    if ni == undefined || GRID.node_terrain_kind[ni] != TerrainKind.Ground {
                                        owner.falling_to_death = true;
                                        owner.fall_speed = 0;
                                    }
                                    owner.fsm.change_state(RockclodState.Tired);
                                }
                                create_animation_effect(owner.x, owner.y + owner.z, owner.depth + 1, spr_fx_poof1_dirt_once);
                                owner.landing = true;
                                owner.fall_speed = 0;
                            }
                        })
                        .start(function() {
                            create_animation_effect(owner.x, owner.y, owner.depth + 1, spr_fx_poof1_dirt_once);
                            TANGO.play("SoundEffects/Enemies/Rockclod/Jump", owner.x, owner.y);
                            owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                            owner.can_overlap_ari = true;
                            owner.landing = false;
                            owner.z = 0;
                            owner.mask_index = owner.config.collision_jump;
                            owner.set_state_sprite(false);

                            self.spd = Vec2(lengthdir_x(owner.config.launch_speed, owner.dir), lengthdir_y(owner.config.launch_speed, owner.dir));
                            owner.move.x = self.spd.x;
                            owner.move.y = self.spd.y;
                            self.tarball = TarballBuilder(owner.x, owner.y, 12, 12, owner.config.damage)
                                .set_offset(-6, -12)
                                .set_parent(owner)
                                .notify(self)
                                .set_critical(true)
                                .set_provenance(owner.monster_id, owner.stats_entry)
                                .gen();
                            self.reflected = false;
                            self.reflection_cd = 0;
                            self.jump_speed = owner.config.jump_speed;
                        })
                        .step(function() {
                            if fsm.state_frame % 10 == 0 {
                                TANGO.play("SoundEffects/Enemies/Rockclod/MidAirSpin", owner.x, owner.y);
                            }

                            if self.reflection_cd > 0 {
                                self.reflection_cd -= 1;
                            }

                            if self.owner.z >= self.owner.config.jump_cap {
                                owner.z += self.jump_speed;
                                self.jump_speed += owner.config.jump_gravity;
                            }

                            owner.move.x = spd.x;
                            owner.move.y = spd.y;
                            var ni = GRID.try_node_index_for_room_position(owner.x, owner.y);

                            if ni != undefined && GRID.node_terrain_kind[ni] == TerrainKind.Ground {
                                owner.loot_drop.x = owner.x;
                                owner.loot_drop.y = owner.y;
                            }

                        })
                        .stop(function() {
                            if self.tarball != undefined && instance_exists(self.tarball) {
                                instance_destroy(self.tarball);
                                self.tarball = undefined;
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockclodState.Hurt)
                        .start(function() {
                            spawn_particle_rockclod_bundle(owner.x, owner.y, owner.depth, owner.config.misc_sprites.rock_particle);
                            owner.set_state_sprite();
                            owner.receiver.drop_damage();

                            hurt_timer = irandom_range(owner.config.hurt[0], owner.config.hurt[1]);
                            owner.show_damage = 10000;
                        })
                        .step(function() {
                            if fsm.state_frame >= self.hurt_timer {
                                owner.walk_or_windup();
                            }
                        })
                        .stop(function() {
                            owner.show_damage = 0;
                            owner.knockback_big = undefined;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(RockclodState.Dying)
                        .start(function() {
                            owner.trauma = 0.7;
                            owner.set_state_sprite();

                            var ni = GRID.try_node_index_for_room_position(owner.x, owner.y);

                            if owner.falling_to_death {
                                create_animation_effect(owner.x, owner.y, owner.depth - 1, spr_fx_reel_fish_splash_bottom);
                                create_animation_effect(owner.x, owner.y, owner.depth - 1, spr_fx_reel_fish_splash_top);
                                TANGO.play("SoundEffects/Enemies/Rockclod/RockclodFallInPit", owner.x, owner.y);
                                owner.image_alpha = 0;
                            }

                            owner.play_state_tango();

                            owner.show_damage = 10000;
                            poof = false;

                            TANGO.play(owner.config.misc_tango.death, owner.x, owner.y);
                        })
                        .step(function() {
                            var frame_limit = owner.falling_to_death ? owner.image_number - 2 : 1;
                            if poof == false && owner.image_index >= frame_limit {
                                monster_death_poof(owner, owner.falling_to_death ? owner.loot_drop : undefined);
                                poof = true;
                                if owner.config.death_explosion_count != -1 {
                                    new_world_chain(undefined, CURRENT_LOCATION_ID)
                                    .append(LinkId.Timer, owner.config.death_explosion_delay)
                                    .append(LinkId.Function, function(data) {
                                        var angle = point_direction(data.x, data.y, obj_ari.x, obj_ari.y);
                                        for (var i = 0; i < data.config.death_explosion_count; i++) {
                                            var dir = Vec2(dcos(angle), -dsin(angle));
                                            instance_create_depth(
                                                data.x + dir.x * 4,
                                                data.y + dir.y * 4,
                                                data.depth - 16,
                                                obj_monster_clod_projectile,
                                                create_clod_projectile(dir.scale(data.config.death_explosion_speed), undefined, data.monster_id, data.stats_entry, data.config),
                                            );
                                            angle += data.explosion_angle;
                                        }
                                    }, [{
                                        config: owner.config,
                                        x: owner.x,
                                        y: owner.y,
                                        depth: owner.depth,
                                        explosion_angle: owner.config.death_explosion_angle,
                                        monster_id: owner.monster_id,
                                        stats_entry: owner.stats_entry,
                                    }]);
                                }
                                CAMERA.add_trauma(0.4);
                            }
                        })
                        .spawn()
                )
                .spawn(RockclodState.Idle, self, Map());
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

            //
            if self.knockback_big != undefined {
                if self.collided_last_frame != MovementCollisionDirection.NONE && self.collision_debounce <= 0 {
                    var anim_effect = create_animation_effect(x, y + z, self.depth + 1, spr_fx_poof1_dirt_once);
                    anim_effect.alpha_tween_amount = 0.05;

                    if has_flag(self.collided_last_frame, MovementCollisionDirection.HORIZONTAL) {
                        if sign(self.knockback_big.x) == 1 {
                            anim_effect.image_angle = 90;
                        } else {
                            anim_effect.image_angle = 270;
                        }

                        self.knockback_big.x *= -1;
                    }

                    if has_flag(self.collided_last_frame, MovementCollisionDirection.VERTICAL) {
                        if sign(self.knockback_big.y) == 1 {
                            anim_effect.image_angle = 0;
                        } else {
                            anim_effect.image_angle = 180;
                        }

                        self.knockback_big.y *= -1;
                    }

                    self.collision_debounce = 2;
                }

                self.collision_debounce -= 1;

                self.move.x = self.knockback_big.x;
                self.move.y = self.knockback_big.y;
                self.knockback_big.set_scale(self.config.knockback_friction);

                //
                if self.knockback_big.sqrd_magnitude() < 0.1 {
                    self.knockback_big = undefined;
                }
            }

            apply_friction();
            push_and_shove(par_monster, self.config.push_radius, self.config.push_force);
            push_from(obj_ari, self.config.pushed_radius, self.config.push_force * sqrt(obj_ari.move.sqrd_magnitude()));

            self.move.set_scale(self.status_effects.get_effect_value(StatusEffectId.Frozen));

            self.collided_last_frame = movement_and_collide();
            var state = self.fsm.current_state_id();
            if self.collided_last_frame && state == RockclodState.Flying {
                    if self.fsm.current_state().reflected {
                        spawn_damage_numbers(
                            self,
                            self.config.damage_number_offset,
                            999,
                            DamageFlag.HEAVY
                        );
                        self.fsm.change_state(RockclodState.Dying);
                    } else {
                        var ni = GRID.try_node_index_for_room_position(self.x, self.y);
                        self.fsm.change_state(RockclodState.Tired);
                        self.landing = true;
                        self.fall_speed = 0;
                        if ni == undefined || GRID.node_terrain_kind[ni] != TerrainKind.Ground {
                            self.falling_to_death = true;
                        }
                }

                TANGO.play("SoundEffects/Enemies/Rockclod/Hop", self.x, self.y);
                create_animation_effect(self.x, self.y + self.z, self.depth + 1, spr_fx_poof1_dirt_once);
            }


            if self.landing && self.z < 0 {
                self.fall_speed += self.config.jump_gravity;
                self.z = clamp(self.z + self.fall_speed, -9999, 0);
                if self.z == 0 && self.falling_to_death && state != RockclodState.Dying {
                    self.fsm.change_state(RockclodState.Dying);
                }
            }

            if state != RockclodState.Flying && state != RockclodState.Dying {
                monster_outside_bounds(x, y, self);
            }
        },
        step_end: function() {
            if game_paused() {
                return;
            }

            shadow_caster_set_position(self.shadow_caster, x, y);
            process_white_vfx();
            shadow_caster_set_image(self.shadow_caster, self.image_index);
            self.process_status(1);

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
                if self.fsm.current_state_id() != RockclodState.Dying {
                    self.fsm.change_state(RockclodState.Dying);
                    return;
                }
            } else {
                var took_any_damage = false;

                while true {
                    var next_dmg = self.receiver.try_take_damage();
                    if next_dmg == undefined {
                        break;
                    }

                    if next_dmg.status != ReceiverStatus.Normal {
                        continue;
                    }

                    if next_dmg.tarball.parent_object() == obj_monster_clod_bomb {
                        continue;
                    }

                    self.process_tarball_status(next_dmg.tarball);

                    if self.fsm.current_state_id() == RockclodState.Flying {
                        var state = self.fsm.current_state();
                        if state.reflected == false && state.reflection_cd == 0 {
                            state.reflection_cd = 5;
                            state.reflected = true;
                            if state.tarball != undefined && instance_exists(state.tarball) {
                                state.tarball.target = CombatTarget.Enemy;
                                state.tarball.damage *= 2;
                            }
                            state.spd.set_scale(-self.config.reflect_speed);
                            TANGO.play(self.config.misc_tango.weak_damage, self.x, self.y);
                            self.dir += 180;
                        }
                        create_animation_effect(self.x, self.y + self.z, self.depth + 1, spr_fx_poof1_dirt_once);
                        continue;
                    }

                    took_any_damage = true;

                    var from_projectile = next_dmg.tarball.parent_object() == obj_monster_clod_projectile
                        || next_dmg.tarball.parent_object() == obj_fire_breath
                        || next_dmg.tarball.parent_object() == obj_monster_clod
                        || next_dmg.tarball.instant_kill;
                    var dmg = from_projectile ? next_dmg.tarball.damage : 1;
                    self.hit_points -= dmg;
                    self.stats_entry.damage_taken += dmg;
                    self.stats_entry.damage_taken_count += 1;

                    spawn_damage_numbers(
                        self,
                        self.config.damage_number_offset,
                        dmg,
                        next_dmg.tarball.damage_flag() | (from_projectile ? DamageFlag.HEAVY : DamageFlag.WEAK),
                    );
                    next_dmg.tarball.calculate_knockback(x, y, self.move);

                    var on_hit = self.config.misc_tango.weak_damage;

                    if next_dmg.tarball.parent_object() == obj_monster_clod_projectile {
                        TANGO.play(self.config.misc_tango.hit_by_projectile, x, y);
                        on_hit = self.config.misc_tango.strong_damage;
                    }
                    if self.hit_points <= 0 || next_dmg.tarball.heavy {
                        on_hit = self.config.misc_tango.strong_damage;
                    }

                    if next_dmg.tarball.critical {
                        monster_critical_fx(self);
                        set_rumble(RumbleKind.SwordStrong);
                    } else {
                        set_rumble(RumbleKind.SwordWeak);
                    }

                    TANGO.play(on_hit, x, y);
                }

                if took_any_damage {
                    switch self.fsm.current_state_id() {
                        case RockclodState.Dying:
                            //
                            break;
                        case RockclodState.Flying:
                            self.show_damage = 30;
                            break;
                        default:
                            //
                            knockback_big = Vec2(
                                x - obj_ari.x,
                                y - obj_ari.y,
                            );
                            knockback_big.normalized();
                            knockback_big.set_scale(self.config.knockback_multiplier);
                            if self.fsm.current_state_id() == RockclodState.Windup {
                                spawn_particle_rockclod_bundle(x, y, depth, self.config.misc_sprites.rock_particle);
                                self.show_damage = 30;
                            } else {
                                self.fsm.change_state(RockclodState.Hurt);
                            }
                            break;
                    }

                    self.patience.value = PATIENCE_DAMAGED;

                    if self.hit_points <= 0 {
                        self.fsm.change_state(RockclodState.Dying);
                    }
                }
            }
        },
    }
);
