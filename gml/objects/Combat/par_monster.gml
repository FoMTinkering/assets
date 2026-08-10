object_create(
    "par_monster",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            z = 0;
            amt = 0;
            hit_points = 3;

            shadow_caster = SHADOW_GRID.caster_create(x, y);
            self.image_speed_backup = undefined;
            can_overlap_ari = false;

            skip_destroy_logic = false;
            insta_kill_timer = 0;

            ladder_value = true;

            var mines_overlay_values = fiddle_get("misc/mines_overlay_values");
            self.venomous_overlay_color = make_color_rgb(
                mines_overlay_values.venomous_overlay_color[0],
                mines_overlay_values.venomous_overlay_color[1],
                mines_overlay_values.venomous_overlay_color[2],
            );
            self.venomous_opacity = mines_overlay_values.venomous_opacity;
            self.frozen_overlay_color = make_color_rgb(
                mines_overlay_values.frozen_overlay_color[0],
                mines_overlay_values.frozen_overlay_color[1],
                mines_overlay_values.frozen_overlay_color[2],
            );
            self.frozen_opacity = mines_overlay_values.frozen_opacity;

            setup_push();
            setup_move_and_collide();
            self.check_collision = function(xx, yy) {
                //
                if self.can_overlap_ari == false && overlap_point(xx, yy, obj_ari) {
                    return true;
                }

                var ni = GRID.try_node_index_for_room_position(xx, yy);
                return ni == undefined || GRID.node_collideable[ni] || GRID.node_terrain_kind[ni] != TerrainKind.Ground;
            }

            setup_friction();
            setup_white_vfx();

            //
            function debug_state() {
                return self.fsm.current_state_id();
            }

            assert_neq(id[$ "config"], undefined, "no config given to `{GmObject}` -- we don't know what monster we're supposed to be!");

            hit_points = self.config.hp;
            dir = irandom_range(config.starting_dir[0], config.starting_dir[1]);

            self.sprite_index = self.config.sprite_catalogue[0][Cardinal.South];
            shadow_caster_set_sprite(shadow_caster, SHADOW_DICTIONARY.get(sprite_index));

            original_dir = dir;
            original_spawn_pos = Vec2(x, y);

            patience = new Patience(x, y, self.config[$ "aggro_radius"], self.config[$ "use_circle"] ?? false);
            patience.value = self.config.patience_acknowledgement_reset;

            aggro = false;
            acknowledgement_reset = false;
            self.knockback_move = Vec2();

            tired_effect = undefined;

            receiver = create_receiver(x, y, self.config.hurtbox, self, {
                iframes: self.config.iframes
            });
            trauma = 0;

            status_effects = new StatusEffectManager();

            self.stats_entry = {
                monster: monster_id_to_string(self.monster_id),
                damage_dealt: 0,
                damage_dealt_count: 0,
                damage_taken: 0,
                damage_taken_count: 0,
                killed_by_ari: false,
            };

            if GS_MINES_RUN != undefined && GS_MINES_FLOOR != undefined {
                array_push(GS_MINES_FLOOR.damages, self.stats_entry);
            }

            function get_cardinal() {
                return monster_vertical_cardinal_from_dir(self.dir);
            }

            function calculate_flipper() {
                if self.dir >= 90 && self.dir < 270 {
                    return -1;
                } else {
                    return 1;
                }
            }

            function process_status(damage_cap=infinity, spawn_particles=true) {
                if TICK % 60 == 0 {
                    if self.status_effects.get_effect_value(StatusEffectId.Venomous, 0) != 0 {
                        var damage = min(
                            round(self.status_effects.effects.get(StatusEffectId.Venomous).amount),
                            damage_cap,
                        );
                        self.hit_points -= damage;

                        if spawn_particles {
                            //
                            spawn_damage_numbers(
                                self,
                                self.config.damage_number_offset,
                                damage,
                                DamageFlag.WEAK,
                            );

                            //
                            create_animation_effect_on_object(self, spr_fx_monster_venom_damage, -1, self.config.status_effect_offset);
                        }
                    }

                    if self.status_effects.get_effect_value(StatusEffectId.Frozen, 0) != 0
                        && spawn_particles
                    {
                        var anim_effect = create_animation_effect_on_object(self, spr_fx_monster_ice_puff, -1, self.config.status_effect_offset);
                        anim_effect.image_alpha = 0.75;
                    }
                }

                self.status_effects.update(true);
            }

            function process_tarball_status(tarball) {
                if tarball.venomous {
                    var effect = INFUSIONS.get(Infusion.VenomSword);
                    var time = CALENDAR.unified_time();

                    self.status_effects.register(
                        StatusEffectId.Venomous,
                        tarball.damage / effect.duration_seconds,
                        time,
                        time + (GAME_SECONDS_PER_FRAME * effect.duration_seconds * 60),
                        true,
                        false
                    );
                }

                if tarball.frozen {
                    var effect = INFUSIONS.get(Infusion.IceSword);
                    var time = CALENDAR.unified_time();
                    self.status_effects.register(
                        StatusEffectId.Frozen,
                        effect.percentage,
                        time,
                        time + I32_MAX,
                        false,
                        false
                    );
                }

                if tarball.fire_oil {
                    //
                    create_animation_effect(
                        self.x + random_range(-3, 3),
                        self.y + self.config.fire_effect_offset + random_range(-3, 3),
                        self.depth - 1,
                        spr_fx_combat_fire_sword_impact,
                    );
                }
            }


            function draw() {
                var flipper = self.calculate_flipper();

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
                    yy + z,
                    image_xscale * flipper,
                    image_yscale,
                    image_angle,
                    self.image_blend,
                    image_alpha,
                );

                //
                var flat_color = undefined;
                var flat_alpha = undefined;
                if self.status_effects.get_effect_value(StatusEffectId.Venomous, 0) != 0 {
                    flat_color = self.venomous_overlay_color;
                    flat_alpha = self.venomous_opacity;
                } else if self.status_effects.get_effect_value(StatusEffectId.Frozen, 0) != 0 {
                    flat_color = self.frozen_overlay_color;
                    flat_alpha = self.frozen_opacity;
                }

                //
                if flat_color != undefined {
                    gpu_set_extra(UberShaderKind.Flat);
                    draw_sprite_ext(
                        sprite_index,
                        image_index,
                        xx,
                        yy + z,
                        image_xscale * flipper,
                        image_yscale,
                        image_angle,
                        flat_color,
                        flat_alpha,
                    );
                    gpu_reset_extra();
                }
            }

            function set_state_sprite(reset_image=true, state=undefined) {
                if state == undefined {
                    state = self.fsm.current_state_id();
                }

                self.sprite_index = self.config.sprite_catalogue[state][self.get_cardinal()];

                if reset_image {
                    self.image_index = 0;
                }
                shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));
            }

            function play_state_tango(modulate_pitch=1, state=undefined) {
                if state == undefined {
                    state = self.fsm.current_state_id();
                }

                var snd = self.config.tango_catalogue[state];
                if snd == undefined {
                    return;
                }

                return TANGO.play(snd, self.x, self.y, modulate_pitch);
            }

            function track_player() {
                self.dir = point_direction(x, y, obj_ari.x, obj_ari.y);
                self.set_state_sprite(false);
            }

            function try_spawn_stars(offset) {
                if self.tired_effect == undefined || instance_exists(self.tired_effect) == false {
                    TANGO.play("SoundEffects/Enemies/EnemyDizzy", x, y);
                    self.tired_effect = instance_create_depth(x, y, 0, obj_monster_stars, { z: offset });
                }
            }

            function try_despawn_stars() {
                if self.tired_effect != undefined && instance_exists(self.tired_effect) {
                    self.tired_effect.state = StarsState.FadeOut;
                    self.tired_effect = undefined;
                }
            }
        },
        step: function() {
            if non_cutscene_pause() {
                if self.image_speed_backup == undefined {
                    self.image_speed_backup = self.image_speed;
                }
                self.image_speed = 0;
            } else if self.image_speed_backup != undefined {
                self.image_speed = self.image_speed_backup;
                self.image_speed_backup = undefined;
            }
        },
        step_begin: function() {
            if game_paused() {
                return;
            }

            //
            self.patience.tick();
            var old_patience = self.patience.value;
            self.aggro = self.patience.aggro();
            var aggro_flipped_this_frame = self.aggro && self.patience.value > old_patience;
            self.acknowledgement_reset = aggro_flipped_this_frame && old_patience <= self.config.patience_acknowledgement_reset;

            fsm.new_tick();
        },
        step_end: function() {
            shadow_caster_set_position(self.shadow_caster, x, y);
            process_white_vfx();
        },
        draw: function() {
            self.fsm.draw();
            self.draw();
            self.fsm.draw_after();
            white_vfx();
        },
        animation_end: function() {
            fsm.anim_end();
        },
        destroy: function() {
            instance_destroy_safe(self.tired_effect);
            instance_destroy(self.receiver);
            self.patience.destroy();

            if self.fsm != undefined {
                self.fsm.destroy();
            }

            if self.skip_destroy_logic {
                return;
            }

            if is_dungeon_room(room()) {
                DUNGEON_RUNNER.on_monster_destroy(self.x div 8, self.y div 8);
            }
            game_stats_increment(GAME_STATS, "enemies_killed");
            self.stats_entry.killed_by_ari = true;
        },
        cleanup: function() {
            SHADOW_GRID.caster_remove(self.shadow_caster);

            if self.fsm != undefined {
                self.fsm.cleanup();
            }
        },
    }
);
