object_create(
    "obj_monster_mite",
    object_reserve("par_monster"),
    {
        sprite_index: undefined,
        create: function() {
            event_inherit(ObjectEvent.Create);

            mask_index = config.misc_sprites.ground_walk;

            with obj_monster_mite {
                if self.id != other.id {
                    self.skip_destroy_logic = true;
                    instance_destroy();
                }
            }

            //
            self.allow_shoving = false;
            can_overlap_ari = true;
            self.check_collision = function(xx, yy) {
                var ni = GRID.try_node_index_for_room_position(xx, yy);
                if ni == undefined {
                    return false;
                }

                //
                if object_id_to_object_category(GRID.node_object_id[ni]) == ObjectCategory.Rock {
                    traumatize(GRID.node_parent[ni].renderer, 0.4);
                }

                //
                if overlap_point_any(xx, yy, obj_lavaplatform) {
                    return true;
                }

                return GRID.node_terrain_kind[ni] != TerrainKind.Ground;
            }

            function snap_position() {
                //
                x = (x div 16) * 16;
                y = (y div 16) * 16;
            }
            self.snap_position();

            function distance_to_ari() {
                var d = 0;
                with obj_ari {
                    d = distance_to_point(other.x + 8, other.y + 8);
                }

                return d;
            }

            function create_spikes(property_name, make_tarball, can_overlap_ari) {
                var spike_effects = array_create(array_length(self.config.secondary_spikes), undefined);

                for (var i = 0; i < array_length(self.config.secondary_spikes); i++) {
                    var pos_x = self.x + self.config.secondary_spikes[i][0];
                    var pos_y = self.y + self.config.secondary_spikes[i][1];
                    var t = undefined;

                    var ni = GRID.try_node_index_for_room_position(pos_x, pos_y);
                    if ni == undefined || GRID.node_collideable[ni] {
                        continue;
                    }

                    if make_tarball {
                        var w = 10;
                        var h = 12;

                        t = TarballBuilder(self.x, self.y, w, h, self.config.damage)
                            .set_offset(self.config.secondary_spikes[i][0] -w / 2, self.config.secondary_spikes[i][1] -h / 2)
                            .set_parent(self)
                            .set_provenance(self.monster_id, self.stats_entry)
                            .gen()
                    }

                    spike_effects[i] = [
                        create_animation_effect(pos_x, pos_y, get_floor_depth(), self.config.misc_sprites[$ format("secondary_ground_{}", property_name)]),
                        instance_create_depth(pos_x, pos_y, get_instance_depth(pos_y), obj_monster_mite_secondary, {
                            sprite_index: self.config.misc_sprites[$ format("secondary_spike_{}", property_name)],
                            can_overlap_ari,
                        }),
                        t,
                    ];
                }

                return spike_effects;
            }

            function destroy_spikes(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if input[i] == undefined {
                        continue;
                    }

                    instance_destroy_safe(input[i][0]);
                    instance_destroy_safe(input[i][1]);
                    instance_destroy_safe(input[i][2]);
                }
            }

            ground_attack_effect = undefined;
            receiver.status = set_flag(receiver.status, ReceiverStatus.UntimedInvulnerable);

            fsm = StateMachineBuilder(MiteState.LEN)
                .add_state(
                    StateBuilder(MiteState.Idle)
                        .start(function() {
                            owner.set_state_sprite(true, MiteState.Idle);
                            owner.dir = owner.original_dir;
                        })
                        .step(function() {
                            if owner.aggro {
                                fsm.change_state(MiteState.Walk);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MiteState.Walk)
                        .start(function() {
                            to_ari = true;
                            target_x = (obj_ari.x div 16) * 16;
                            target_y = (obj_ari.y div 16) * 16;

                            owner.set_state_sprite();

                            distance = 100;
                            anim_effect_counter = 0;

                            want_attack = false;
                        })
                        .step(function() {
                            distance += owner.config.speed * owner.status_effects.get_effect_value(StatusEffectId.Frozen);

                            owner.move.x = lengthdir_x(owner.config.speed * owner.status_effects.get_effect_value(StatusEffectId.Frozen), owner.dir);
                            owner.move.y = lengthdir_y(owner.config.speed * owner.status_effects.get_effect_value(StatusEffectId.Frozen), owner.dir);

                            owner.set_state_sprite(false);
                        })
                        .end_step(function() {
                            if owner.aggro && owner.distance_to_ari() <= owner.config.attack_radius {
                                self.want_attack = true;
                            }

                            if self.distance >= 16 {
                                owner.snap_position();

                                if self.want_attack {
                                    fsm.change_state(MiteState.Windup);
                                    return;
                                }

                                if owner.aggro {
                                    self.target_x = (obj_ari.x div 16) * 16;
                                    self.target_y = (obj_ari.y div 16) * 16;
                                } else {
                                    self.target_x = owner.original_spawn_pos.x;
                                    self.target_y = owner.original_spawn_pos.y;
                                }
                                owner.dir = cardinal_to_angle(angle_to_cardinal(point_direction(owner.x, owner.y, target_x, target_y)));

                                //
                                var off_x = 8;
                                var off_y = 5;
                                if self.anim_effect_counter % 2 == 0 {
                                    if owner.dir == 90 || owner.dir == 270 {
                                        off_x += 2;
                                    } else {
                                        off_y += 2;
                                    }
                                }

                                TANGO.play(owner.config.misc_tango.form_mound, owner.x, owner.y);
                                create_animation_effect(owner.x + off_x, owner.y + off_y, get_floor_depth(), owner.config.misc_sprites.ground_walk);
                                self.anim_effect_counter += 1;
                                distance = 0;
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MiteState.Windup)
                        .start(function() {
                            if owner.distance_to_ari() <= owner.config.attack_radius {
                                owner.x = obj_ari.x;
                                owner.y = obj_ari.y;
                            } else {
                                owner.x += 8;
                                owner.y += 8;
                            }
                            owner.y += 2;
                            owner.set_state_sprite();
                            owner.play_state_tango();
                            self.windup_effect = create_animation_effect(owner.x, owner.y, get_floor_depth(), owner.config.misc_sprites.ground_windup);

                            self.spike_effects = undefined;

                            //
                            self.spike_effects = owner.config.secondary_spikes == undefined ? undefined : owner.create_spikes("windup", false, true);
                        })
                        .anim_end(function() {
                            fsm.change_state(MiteState.Attack);
                        })
                        .stop(function() {
                            instance_destroy_safe(self.windup_effect);

                            if self.spike_effects != undefined {
                                owner.destroy_spikes(self.spike_effects);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MiteState.Attack)
                        .start(function() {
                            owner.can_overlap_ari = false;
                            owner.receiver.status = remove_flag(owner.receiver.status, ReceiverStatus.UntimedInvulnerable);
                            CAMERA.add_trauma(0.3);

                            spawn_particle_rockclod_bundle(owner.x + 6, owner.y, owner.depth, owner.config.misc_sprites.giblits);
                            spawn_particle_rockclod_bundle(owner.x - 6, owner.y, owner.depth, owner.config.misc_sprites.giblits);
                            spawn_particle_rockclod_bundle(owner.x - 6, owner.y + 3, owner.depth, owner.config.misc_sprites.giblits);

                            owner.set_state_sprite();
                            owner.play_state_tango();
                            owner.ground_attack_effect = create_animation_effect(owner.x, owner.y, get_floor_depth(), owner.config.misc_sprites.ground_attack, true);

                            var bbox_dims = shape_get_dimensions(owner.config.hitbox);
                            self.tarball = TarballBuilder(owner.x, owner.y, bbox_dims[0], bbox_dims[1], owner.config.damage)
                                .set_offset(-bbox_dims[0] / 2, -bbox_dims[1] / 2)
                                .set_parent(owner)
                                .set_provenance(owner.monster_id, owner.stats_entry)
                                .gen();

                            self.spike_effects = owner.config.secondary_spikes == undefined ? undefined : owner.create_spikes("attack", true, false);
                        })
                        .step(function() {
                            if self.spike_effects != undefined {
                                for (var i = 0; i < array_length(self.spike_effects); i++) {
                                    if self.spike_effects[i] == undefined {
                                        continue;
                                    }
                                    if instance_exists(self.spike_effects[i][1])
                                        && self.spike_effects[i][1].image_index >= 2.0
                                    {
                                        //
                                        instance_destroy_safe(self.spike_effects[i][2]);
                                    } else {
                                        break;
                                    }
                                }
                            }
                        })
                        .anim_end(function() {
                            fsm.change_state(MiteState.Tired);
                        })
                        .stop(function() {
                            instance_destroy(self.tarball);

                            if self.spike_effects != undefined {
                                owner.destroy_spikes(self.spike_effects);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MiteState.Tired)
                        .start(function() {
                            owner.set_state_sprite();

                            self.spike_effects = owner.config.secondary_spikes == undefined ? undefined : owner.create_spikes("tired", false, false);
                        })
                        .step(function() {
                            if owner.image_index >= 2 {
                                owner.try_spawn_stars(-13);

                                if self.spike_effects != undefined {
                                    for (var i = 0; i < array_length(self.spike_effects); i++) {
                                        if self.spike_effects[i] == undefined {
                                            continue;
                                        }
                                        if instance_exists(self.spike_effects[i][0]) {
                                            self.spike_effects[i][0].image_alpha -= 0.1;
                                        }
                                        if instance_exists(self.spike_effects[i][1])
                                            && self.spike_effects[i][1].image_index >= 3.0
                                        {
                                            instance_destroy_safe(self.spike_effects[i][1]);
                                        }
                                    }
                                }
                            }
                        })
                        .anim_end(function() {
                            fsm.change_state(MiteState.Flee);
                        })
                        .stop(function() {
                            if self.spike_effects != undefined {
                                owner.destroy_spikes(self.spike_effects);
                            }
                            TANGO.play(owner.config.misc_tango.withdraw, owner.x, owner.y);
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MiteState.Flee)
                        .start(function() {
                            owner.receiver.status = set_flag(owner.receiver.status, ReceiverStatus.UntimedInvulnerable);
                            owner.can_overlap_ari = true;

                            owner.try_despawn_stars();
                            instance_destroy_safe(owner.ground_attack_effect);

                            owner.ground_attack_effect = undefined;
                            owner.set_state_sprite();

                            create_animation_effect(owner.x, owner.y, get_floor_depth(), owner.config.misc_sprites.ground_flee);

                            hidden = undefined;
                        })
                        .step(function() {
                            if self.hidden != undefined {
                                self.hidden -= 1;
                                if self.hidden <= 0 {
                                    fsm.change_state(MiteState.Walk);
                                }
                            }
                        })
                        .anim_end(function() {
                            if self.hidden == undefined {
                                owner.sprite_index = spr_nothing;
                                self.hidden = irandom_range(owner.config.hide_timer[0], owner.config.hide_timer[1]);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MiteState.Hurt)
                        .start(function() {
                            owner.set_state_sprite();
                            owner.receiver.drop_damage();

                            hurt_timer = irandom_range(owner.config.hurt[0], owner.config.hurt[1]);
                            owner.show_damage = 10000;
                        })
                        .step(function() {
                            if fsm.state_frame >= self.hurt_timer {
                                fsm.change_state(MiteState.Flee);
                            }
                        })
                        .stop(function() {
                            owner.show_damage = 0;
                        })
                    .spawn()
                )
                .add_state(
                    StateBuilder(MiteState.Dying)
                        .start(function() {
                            owner.set_state_sprite();
                            owner.receiver.drop_damage();

                            hurt_timer = irandom_range(owner.config.hurt[0], owner.config.hurt[1]);
                            owner.show_damage = 10000;
                            poof = false;
                            TANGO.play(owner.config.misc_tango.death, owner.x, owner.y);
                        })
                        .anim_end(function() {
                            if poof == false {
                                monster_death_poof(owner);
                                poof = true;
                                CAMERA.add_trauma(0.4);
                            }
                        })
                    .spawn()
                )
                .spawn(MiteState.Idle, self, Map());
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
            movement_and_collide(par_monster);
        },
        step_end: function() {
            if game_paused() {
                return;
            }

            shadow_caster_set_position(self.shadow_caster, x, y);
            process_white_vfx();
            shadow_caster_set_image(self.shadow_caster, self.image_index);
            shadow_caster_set_image_xscale(self.shadow_caster, self.calculate_flipper());

            var spawn_particles = false;
            switch self.fsm.current_state_id() {
                case MiteState.Attack:
                case MiteState.Tired:
                case MiteState.Flee:
                case MiteState.Hurt:
                case MiteState.Dying:
                    spawn_particles = true;
                    break;
                default:
                    spawn_particles = false;
                    break;
            }
            self.process_status(infinity, spawn_particles);

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

                    spawn_particle_rockclod_bundle(x, y, depth, self.config.misc_sprites.giblits);

                    //
                    CAMERA.camera_stop = 1;

                    if next_dmg.tarball.critical {
                        monster_critical_fx(self);
                        set_rumble(RumbleKind.SwordStrong);
                    } else {
                        set_rumble(RumbleKind.SwordWeak);
                    }

                    TANGO.play(self.config.misc_tango.strong_damage, x, y);
                }

                if took_any_damage {
                    self.patience.value = PATIENCE_DAMAGED;
                    if self.hit_points <= 0 {
                        self.fsm.change_state(MiteState.Dying);
                    } else {
                        self.fsm.change_state(MiteState.Hurt);
                    }
                }
            } else if csi != MiteState.Dying {
                self.fsm.change_state(MiteState.Dying);
                return;
            }
        },
        destroy: function() {
            event_inherit(ObjectEvent.Destroy);

            instance_destroy_safe(self.ground_attack_effect);
        },
    }
);
