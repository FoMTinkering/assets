object_create(
    "obj_monster_sap",
    object_reserve("par_monster"),
    {
        sprite_index: undefined,
        mask_index: string_to_asset("spr_monster_sapling_main_idle_south"),
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.check_collision = function(xx, yy) {
                //
                if self.can_overlap_ari == false && overlap_point(xx, yy, obj_ari) {
                    return true;
                }

                var ni = GRID.try_node_index_for_room_position(xx, yy);
                //
                if self.free_fly
                    && ni != undefined
                    && self.fsm.current_state_id() == SaplingState.Attack
                    && (GRID.node_object_id[ni] != undefined || GRID.node_can_jump_over[ni])
                {
                    return false;
                }

                return ni == undefined || GRID.node_collideable[ni] || GRID.node_terrain_kind[ni] != TerrainKind.Ground;
            }

            free_fly = self.config.free_fly;
            hyper_armor = self.config.hyper_armor;

            if self.hyper_armor > 0 {
                function set_state_sprite(reset_image=true, state=undefined) {
                    if state == undefined {
                        state = self.fsm.current_state_id();
                    }
                    self.sprite_index = self.config.sprite_catalogue[state][self.get_cardinal()];
                    self.skull_sapling_skull_sprite_update();

                    if reset_image {
                        self.image_index = 0;
                    }
                    shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));
                }

                skull_sapling_skull_sprite_update = function() {
                    switch self.hyper_armor {
                        case 2:
                            var spr_name = asset_to_string(self.sprite_index);
                            spr_name = string_replace(
                                spr_name,
                                "main",
                                "skull"
                            );
                            self.sprite_index = string_to_asset(spr_name);
                            break;
                        case 1:
                            var spr_name = asset_to_string(self.sprite_index);
                            spr_name = string_replace(
                                spr_name,
                                "main",
                                "partial_skull"
                            );
                            self.sprite_index = string_to_asset(spr_name);
                            break;
                        default:
                            //
                            break;
                    }
                }
            } else {
                skull_sapling_skull_sprite_update = function() {
                    //
                }
            }

            fsm = StateMachineBuilder(SaplingState.LEN)
                .add_state(
                    StateBuilder(SaplingState.Idle)
                        .start(function() {
                            owner.set_state_sprite(true, SaplingState.Idle);
                            owner.dir = owner.original_dir;
                            in_variant = false;
                        })
                        .step(function() {
                            if owner.aggro {
                                if owner.acknowledgement_reset {
                                    fsm.change_state(SaplingState.Acknowledgment);
                                } else {
                                    fsm.change_state(SaplingState.Walk);
                                }
                            }
                        })
                        .anim_end(function() {
                            if chance_percent(25) && self.in_variant == false {
                                owner.sprite_index = owner.config.misc_sprites.idle_variant;
                                owner.skull_sapling_skull_sprite_update();
                                owner.image_index = 0;
                                shadow_caster_set_sprite(owner.shadow_caster, SHADOW_DICTIONARY.get(owner.sprite_index));
                                self.in_variant = true;
                            } else {
                                self.in_variant = false;

                                //
                                if chance_percent(15) {
                                    owner.original_dir = irandom(360);
                                    owner.dir = owner.original_dir;
                                }
                                owner.set_state_sprite(true, SaplingState.Idle);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(SaplingState.Acknowledgment)
                        .start(function() {
                            owner.set_state_sprite();
                            owner.play_state_tango();
                            duration = irandom_range(owner.config.acknowledgment[0], owner.config.acknowledgment[1]);
                            owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);

                            last_frame = 0;
                        })
                        .step(function() {
                            //
                            owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);
                            owner.set_state_sprite(false);

                            if fsm.state_frame >= self.duration {
                                fsm.change_state(SaplingState.Walk);
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
                    StateBuilder(SaplingState.Walk)
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

                            var sticky_multiplier = overlap_point(owner.x, owner.y, obj_sticky_patch) == undefined ? 1 : 1.5;

                            owner.dir = point_direction(owner.x, owner.y, target_x, target_y);
                            owner.move.x = lengthdir_x(owner.config.speed * sticky_multiplier, owner.dir);
                            owner.move.y = lengthdir_y(owner.config.speed * sticky_multiplier, owner.dir);

                            owner.set_state_sprite(false);
                        })
                        .end_step(function() {
                            if owner.aggro
                                && point_distance(owner.x, owner.y, self.target_x, self.target_y) < owner.config.attack_radius
                            {
                                fsm.change_state(SaplingState.Windup);
                            } else if point_distance(owner.x, owner.y, self.target_x, self.target_y) < 1 {
                                owner.x = self.target_x;
                                owner.y = self.target_y;

                                fsm.change_state(SaplingState.Idle);
                            }

                            //
                            if owner.acknowledgement_reset {
                                fsm.change_state(SaplingState.Acknowledgment);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(SaplingState.Windup)
                        .start(function() {
                            owner.mask_index = owner.config.collision_box_jump;
                            duration = irandom_range(owner.config.windup[0], owner.config.windup[1]);
                            owner.set_state_sprite();
                            owner.play_state_tango();
                        })
                        .step(function() {
                            //
                            owner.dir = point_direction(owner.x, owner.y, obj_ari.x, obj_ari.y);

                            if fsm.state_frame >= self.duration {
                                fsm.change_state(SaplingState.Attack);
                            }
                        })
                        .stop(function() {
                            fsm.blackboard.insert("target_x", obj_ari.x);
                            fsm.blackboard.insert("target_y", obj_ari.y);
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(SaplingState.Attack)
                        .create(function() {
                            function on_hit() {
                                //
                                var new_target = self.spd.scale(-16);
                                if owner.config.free_fly {
                                    var fly_dir = point_direction(owner.x, owner.y, owner.x + self.spd.x, owner.y + self.spd.y);
                                    new_target = Vec2(lengthdir_x(abs(owner.config.jump_speed * 3), fly_dir), lengthdir_y(abs(owner.config.jump_speed * 3), fly_dir))
                                }
                                owner.dir = point_direction(owner.x, owner.y, new_target.x + obj_ari.x, new_target.y + obj_ari.y);

                                self.blackboard.insert("target_x", new_target.x + obj_ari.x);
                                self.blackboard.insert("target_y", new_target.y + obj_ari.y);
                                self.blackboard.insert("inhibit_free_fly", true);

                                self.fsm.change_state(SaplingState.Attack);
                            }
                        })
                        .start(function() {
                            owner.can_overlap_ari = true;
                            owner.set_state_sprite();

                            jump_speed = owner.config.jump_speed;
                            if fsm.last_state_id == SaplingState.Attack {
                                jump_speed *= 0.75;
                            }

                            target_x = fsm.blackboard.take("target_x");
                            target_y = fsm.blackboard.take("target_y");
                            self.acknowledge_post_attack = fsm.blackboard.try_take("acknowledge_post_attack", false);

                            self.try_inhibit_free_fly = fsm.blackboard.try_take("inhibit_free_fly", false);

                            //
                            //
                            //
                            //
                            spd = Vec2(target_x - owner.x, target_y - owner.y);
                            if spd.sqrd_magnitude() > (owner.config.max_jump_radius * owner.config.max_jump_radius) {
                                spd.normalized(owner.config.max_jump_radius);
                            }
                            owner.play_state_tango(
                                clamp(inverse_lerp(sqrt(spd.sqrd_magnitude()), owner.config.attack_radius, 0), 0.8, 1.2)
                            );

                            var scaler = owner.config.jump_zx_factor;
                            if fsm.last_state_id == SaplingState.Attack {
                                scaler *= 0.5;
                            }
                            spd.set_scale(1.0 / scaler);

                            if fsm.last_state_id == SaplingState.Attack {
                                var card = monster_vertical_cardinal_from_dir(owner.dir);
                                switch card {
                                    case Cardinal.North:
                                        owner.sprite_index = owner.config.misc_sprites.hit_back_north;
                                        break;
                                    case Cardinal.South:
                                        owner.sprite_index = owner.config.misc_sprites.hit_back_south;
                                        break;
                                }
                                owner.skull_sapling_skull_sprite_update();
                                owner.image_index = 0;
                            } else {
                                var bbox_dims = shape_get_dimensions(owner.config.hitbox);
                                self.pivot = Vec2(-bbox_dims[0] / 2, -bbox_dims[1]);
                            }

                            if owner.config.free_fly {
                                TANGO.play("SoundEffects/Enemies/Sapling/SaplingBigJump", owner.x, owner.y);
                            }

                            self.tarball = undefined;
                            self.landing = false;
                            self.counter = 0;
                        })
                        .step(function() {
                            if self.try_inhibit_free_fly {
                                var ni = GRID.try_node_index_for_room_position(owner.x, owner.y);
                                //
                                if ni != undefined
                                    && GRID.node_terrain_kind[ni] != undefined
                                {
                                    self.try_inhibit_free_fly = false;
                                    owner.free_fly = false;
                                }
                            }

                            if self.tarball == undefined && self.owner.z > -28 {
                                var bbox_dims = shape_get_dimensions(owner.config.hitbox);

                                self.tarball = TarballBuilder(owner.x, owner.y, bbox_dims[0], bbox_dims[1], owner.config.damage)
                                    .set_offset(self.pivot.x, self.pivot.y)
                                    .set_parent(owner)
                                    .set_in_air()
                                    .notify(self)
                                    .set_provenance(owner.monster_id, owner.stats_entry)
                                    .gen();
                            }
                            if fsm.last_state_id == SaplingState.Attack {
                                owner.image_index = 0;
                            }

                            if self.landing {
                                self.counter -= 1;

                                if self.counter <= 0 {
                                    if self.acknowledge_post_attack {
                                        fsm.change_state(SaplingState.Acknowledgment);
                                    } else {
                                        fsm.change_state(SaplingState.Tired);
                                    }
                                }
                                return;
                            }

                            owner.move.x = spd.x * owner.config.air_speed_modifier;
                            owner.move.y = spd.y * owner.config.air_speed_modifier;

                            owner.z += self.jump_speed;
                            self.jump_speed += owner.config.jump_gravity * owner.config.air_speed_modifier;

                            owner.z = min(owner.z, 0);

                            if owner.z >= 0 {
                                owner.z = 0;

                                create_animation_effect_on_object(owner, spr_fx_small_monster_land, 1);
                                var card = monster_vertical_cardinal_from_dir(owner.dir);
                                switch card {
                                    case Cardinal.North:
                                        owner.sprite_index = owner.config.misc_sprites.landing_north;
                                        break;
                                    case Cardinal.South:
                                        owner.sprite_index = owner.config.misc_sprites.landing_south;
                                        break;
                                }
                                owner.skull_sapling_skull_sprite_update();
                                owner.image_index = 0;
                                shadow_caster_set_sprite(owner.shadow_caster, SHADOW_DICTIONARY.get(owner.sprite_index));
                                TANGO.play(owner.config.misc_tango.land, owner.x, owner.y);

                                self.landing = true;
                                self.counter = owner.config.landing;

                                if self.owner.config.sticky {
                                    instance_create_depth(owner.x, owner.y, get_shadow_depth() + 1, obj_sticky_patch, { timer: 300 });
                                }
                            }

                            if self.tarball != undefined && self.landing {
                                instance_destroy(self.tarball);
                                self.tarball = undefined;
                            }
                        })
                        .stop(function() {
                            owner.mask_index = owner.config.collision_box_default;
                            owner.can_overlap_ari = false;
                            if self.tarball != undefined {
                                instance_destroy(self.tarball);
                            }

                            owner.free_fly = owner.config.free_fly;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(SaplingState.Tired)
                        .start(function() {
                            //
                            var flipper = 1;
                            if owner.dir >= 90 && owner.dir < 270 {
                                flipper = -1;
                            }
                            owner.dir = 270 + flipper;
                            owner.set_state_sprite();

                            timer = irandom_range(owner.config.tired[0], owner.config.tired[1]);
                            owner.try_spawn_stars(-13);
                        })
                        .step(function() {
                            if fsm.state_frame >= self.timer {
                                fsm.change_state(SaplingState.Walk);
                            }
                        })
                        .stop(function() {
                            owner.try_despawn_stars();
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(SaplingState.Hurt)
                        .start(function() {
                            owner.set_state_sprite();
                            CAMERA.add_trauma(0.1);

                            started_in_air = owner.z > 1;
                            spd = owner.config.jump_gravity;

                            //
                            owner.show_damage = 10000;

                            //
                            owner.mask_index = owner.config.collision_box_default;
                        })
                        .step(function() {
                            //
                            owner.z = approach(owner.z, 0, self.spd);
                            self.spd += owner.config.jump_gravity;

                            if fsm.state_frame >= owner.config.hurt && owner.hit_points <= 0 {
                                if owner.config.sap_children > 0 {
                                    fsm.change_state(SaplingState.Dying);
                                } else {
                                    fsm.change_state(SaplingState.Splitting);
                                }
                            }

                            if self.started_in_air && owner.z == 0 {
                                //
                                create_animation_effect_on_object(owner, spr_fx_small_monster_land, 1);
                                self.started_in_air = false;
                            }
                        })
                        .anim_end(function() {
                            fsm.change_state(SaplingState.Walk);
                        })
                        .stop(function() {
                            //
                            owner.z = 0;
                            owner.show_damage = 0;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(SaplingState.Dying)
                        .start(function() {
                            CAMERA.add_trauma(0.2);
                            owner.set_state_sprite();
                            owner.play_state_tango();

                            real_pos = Vec2(owner.x, owner.y);
                            poof = false;

                            trauma = 0.5;
                            owner.show_damage = 10000;
                            windup = undefined;

                            if self.owner.config.death_bits != undefined {
                                spawn_cool_debris(owner.x, owner.y, owner.depth - 32, self.owner.config.death_bits);
                            }
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
                ).add_state(
                    StateBuilder(SaplingState.Splitting)
                        .start(function() {
                            self.trauma = 0.5;
                            self.real_pos = Vec2(owner.x, owner.y);
                            owner.set_state_sprite();
                            TANGO.play("SoundEffects/Enemies/Sapling/ChargeUp");
                        })
                        .step(function() {
                            if instance_exists(obj_ari) == false {
                                return;
                            }

                            owner.x = self.real_pos.x + self.trauma * self.trauma * perlin_noise_get(0) * sign(perlin_noise_get(50) * 2.0 - 1.0);
                            owner.y = self.real_pos.y + self.trauma * self.trauma * perlin_noise_get(1) * sign(perlin_noise_get(100) * 2.0 - 1.0);
                            if self.fsm.state_frame >= owner.config.sap_children_birth_timer {
                                var dir_vec = Vec2(obj_ari.x - owner.x, obj_ari.y - owner.y);
                                dir_vec.normalized();
                                var perp = dir_vec.perpendicular();
                                var n = (owner.config.sap_children / 2 - 0.5) * -4;
                                create_animation_effect(owner.x, owner.y - 8, owner.depth, spr_fx_poof2_dirt_once);
                                for (var i = 0; i < self.owner.config.sap_children; i++) {
                                    var offset_to_the_offset = perp.scale(n + 4 * i).scale(self.owner.config.sap_children_birth_distance / 2);
                                    var sapling = spawn_monster(owner.x, owner.y, string_to_monster_id(owner.config.sap_children_species));
                                    sapling.receiver.current_iframes = 3;
                                    sapling.aggro = true;
                                    sapling.skip_destroy_logic = true;

                                    var sap_bb = sapling.fsm.blackboard;
                                    sap_bb.insert("target_x", owner.x + offset_to_the_offset.x);
                                    sap_bb.insert("target_y", owner.y + offset_to_the_offset.y);
                                    sap_bb.insert("acknowledge_post_attack", owner.y + offset_to_the_offset.y);
                                    sapling.fsm.change_state_instant(SaplingState.Attack);
                                }
                                instance_destroy(owner);
                            }
                        })
                        .spawn()
                )
                .spawn(SaplingState.Idle, self, Map());
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
            self.move.set_add(self.knockback_move);
            self.knockback_move.set_scale(0.9);

            push_and_shove(par_monster, self.config.push_radius, self.config.push_force);
            push_from(obj_ari, self.config.pushed_radius, self.config.push_force * sqrt(obj_ari.move.sqrd_magnitude()));
            movement_and_collide(par_monster);

            //
            if self.config.free_fly == false {
                monster_outside_bounds(x, y, self);
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
                    var dmg = next_dmg.tarball.damage;
                    var dmg_flag = next_dmg.tarball.damage_flag();
                    var on_hit = self.config.misc_tango.strong_damage;

                    if self.hyper_armor > 0 {
                        dmg = 1;
                        dmg_flag |= DamageFlag.WEAK;
                        on_hit = self.config.misc_tango.hyper_armor_hit;
                    }

                    self.hit_points -= dmg;
                    self.stats_entry.damage_taken += dmg;
                    self.stats_entry.damage_taken_count += 1;

                    self.process_tarball_status(next_dmg.tarball);

                    spawn_damage_numbers(
                        self,
                        self.config.damage_number_offset,
                        dmg,
                        dmg_flag,
                    );

                    var let_it_rain = true;
                    if (csi == SaplingState.Windup || csi == SaplingState.Attack || next_dmg.tarball.heavy)
                        && self.hit_points > 0
                    {
                        //
                        if self.hyper_armor <= 0 {
                            on_hit = self.config.misc_tango.weak_damage;
                        }
                        let_it_rain = false;
                    }

                    TANGO.play(on_hit, x, y);
                    next_dmg.tarball.calculate_knockback(x, y, self.move);

                    if let_it_rain {
                        spawn_particle_blood(x, y, depth, self.config.misc_sprites.sap_particle);
                    }

                    //
                    CAMERA.camera_stop = 1;

                    if next_dmg.tarball.heavy || (csi == SaplingState.Attack && self.hyper_armor <= 0) {
                        self.knockback_move.set(self.move);
                        self.knockback_move.set_scale(0.4);
                        self.fsm.change_state(SaplingState.Hurt);
                    }

                    if next_dmg.tarball.critical {
                        monster_critical_fx(self);
                        set_rumble(RumbleKind.SwordStrong);
                    } else {
                        set_rumble(RumbleKind.SwordWeak);
                    }
                }

                if took_any_damage {
                    if self.hyper_armor > 0 {
                        spawn_cool_debris(self.x, self.y, self.depth - 32, self.config.misc_sprites.skull_bits);
                        self.show_damage = 30;
                    } else {
                        switch csi {
                            case SaplingState.Idle:
                            case SaplingState.Acknowledgment:
                            case SaplingState.Walk:
                            case SaplingState.Tired:
                            case SaplingState.Attack:
                                self.fsm.change_state(SaplingState.Hurt);
                                break;
                            case SaplingState.Windup:
                                //
                                self.show_damage = 30;
                                break;
                            case SaplingState.Hurt:
                                //
                                image_index = self.image_index * 0.75;
                                break;
                            case SaplingState.Dying:
                                //
                                break;
                            default: impossible("unexpected current state id!");
                        }
                    }

                    self.hyper_armor -= 1;
                    self.set_state_sprite(false);
                    self.patience.value = PATIENCE_DAMAGED;

                    if self.hit_points <= 0 {
                        self.fsm.change_state(SaplingState.Hurt);
                    }
                }
            } else {
                if self.config.sap_children > 0 {
                    if csi != SaplingState.Splitting {
                        self.fsm.change_state(SaplingState.Splitting);
                    }
                } else if csi != SaplingState.Dying {
                    self.fsm.change_state(SaplingState.Dying);
                }
            }
        },
    }
);
