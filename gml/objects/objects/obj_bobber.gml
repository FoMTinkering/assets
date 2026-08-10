object_create(
    "obj_bobber",
    undefined,
    {
        sprite_index: spr_tool_lure_old_cast,
        create: function() {
            self.xstart = self.x;
            self.ystart = self.y;

            FISHING.subscribe(id);

            self.has_landed = false;

            //
            if ARI.perk_active(Perk.AppealingReelingTwo) {
                GAME_STATS.perks[$ perk_to_string(Perk.AppealingReelingTwo)] += 1;
                mask_index = string_to_asset(fiddle_get("perks/appealing_reeling_two/mask"));
            } else if ARI.perk_active(Perk.AppealingReeling) {
                GAME_STATS.perks[$ perk_to_string(Perk.AppealingReeling)] += 1;
                mask_index = string_to_asset(fiddle_get("perks/appealing_reeling/mask"));
            } else {
                mask_index = spr_tool_lure_old_cast;
            }

            function set_sprite(_sprite) {
                sprite_index = _sprite;
                image_index = 0;
            }
            function fish_escape() {
                if self.bait_prototype == undefined {
                    self.anim_effects.push(
                        create_animation_effect_on_object(obj_bobber, spr_fx_reel_fish_splash_top, -1, 0)
                    );
                    self.set_sprite(spr_tool_lure_old_water_idle);
                }
            }

            //
            //
            //
            self.anim_effects = List();

            function prune_anim_effects() {
                for (var i = self.anim_effects.count()-1; i >= 0; i--) {
                    if(!instance_exists(self.anim_effects.get(i))) {
                        self.anim_effects.remove(i);
                    }
                }
            };

            function clear_anim_effects() {
                self.prune_anim_effects();
                for (var i = self.anim_effects.count() - 1; i >= 0; i--) {
                    self.anim_effects.get(i).release_object();
                    self.anim_effects.remove(i);
                }
            }

            //
            self.fsm = StateMachineBuilder(BobberState.LEN)
                .add_state(StateBuilder(BobberState.Cast)
                    .start(function() {
                        self.land_pos = Vec2(
                            (FISHING.fishing_grid_position.x + 0.5) * OBJECT_CELL_SIZE,
                            (FISHING.fishing_grid_position.y + 0.5) * OBJECT_CELL_SIZE
                        );
                        self.air_time = 1;
                        self.counter = 0;
                        //
                        var dist = point_distance(obj_ari.x, obj_ari.y, self.land_pos.x, self.land_pos.y);
                        if dist > OBJECT_CELL_SIZE * 6 {
                            self.air_time = dist * 0.7;
                            self.height = 30;
                            self.bias = 0.8;
                        } else {
                            self.air_time = dist;
                            self.height = 20;
                            self.bias = 0.9;
                        }
                    })
                    .step(function() {
                        self.counter += 1;

                        //
                        var at = clamp(self.counter / self.air_time, 0, 1);
                        self.owner.x = lerp(self.owner.xstart, self.land_pos.x, at);
                        if at <= 0.5 {
                            var v = self.bias;
                            var t = 2 * at;
                            var b = t / ((1 / v - 2) * (1 - t) + 1);
                            self.owner.y = lerp(self.owner.ystart, self.owner.ystart - self.height, b);
                        } else {
                            var v = 1 - self.bias;
                            var t = 2 * at - 1;
                            var b = t / ((1 / v - 2) * (1 - t) + 1);
                            self.owner.y = lerp(self.owner.ystart - self.height, self.land_pos.y, b);
                        }

                        if self.counter > self.air_time {
                            if self.owner.bait_prototype != undefined && self.owner.has_landed == false {
                                FISH_CONDITION_DATA.all_any_size = true;

                                var inst = instance_nearest(self.land_pos.x, self.land_pos.y, obj_fish_spawner);
                                if inst == undefined {
                                    //
                                    FISH_CONDITION_DATA.water_type = WaterType.Pond;
                                } else {
                                    FISH_CONDITION_DATA.water_type = inst.water_kind;
                                }
                                FISH_CONDITION_DATA.bait = self.owner.bait_prototype;

                                var distribution = DUNGEON_RUNNER != undefined
                                    ? DUNGEON.biomes[DUNGEON_BIOME].votes[DungeonSpawn.Fish]
                                    : FISH_DISTRIBUTIONS;

                                var fish_id = distribution.get_candidate_votes_at_cell(GRID, FISHING.fishing_grid_position.x, FISHING.fishing_grid_position.y).get_candidate();

                                FISH_CONDITION_DATA.bait = undefined;
                                FISH_CONDITION_DATA.all_any_size = false;

                                var ae = create_animation_effect(self.land_pos.x, self.land_pos.y, self.owner.depth - 1, self.owner.bait_prototype.attract.land_sprite);
                                ae.image_idx = sprite_get_number(self.owner.bait_prototype.attract.land_sprite) - 1;
                                ae.image_idx_func = method(ae, function() {
                                    instance_destroy(self);
                                });

                                //
                                //
                                new_world_chain(undefined, CURRENT_LOCATION_ID)
                                    .append(LinkId.Timer, 70)
                                    .append(LinkId.Function, function(xx, yy, z) {
                                        create_animation_effect(xx, yy, z, spr_part_sparkle_anglers_eye);
                                    }, [self.owner.x, self.owner.y, self.owner.depth - 1])
                                    .append(LinkId.Function, function(fish_id, land_pos, item) {
                                        if fish_id == undefined {
                                            create_notification("misc_local/no_fish");
                                            obj_ari.fsm.change_state(PlayerState.Default);
                                            drop_item(item, FISHING.fishing_grid_position.x * 8, FISHING.fishing_grid_position.y * 8);
                                            return;
                                        }
                                        var fish = instance_create_depth(land_pos.x, land_pos.y, 0, obj_fishy);
                                        fish.initialise(new Fish(fish_id));
                                        fish.image_alpha = 0;
                                        var init_xx = choose(-1, 1);
                                        var init_yy = choose(-1, 1);
                                        var breaker = false;

                                        for (var xx = init_xx; xx != -sign(init_xx); xx += -sign(init_xx)) {
                                            for (var yy = init_yy; yy != -sign(init_yy); yy += -sign(init_yy)) {
                                                if xx == 0 && yy == 0 {
                                                    continue;
                                                }

                                                var ni = GRID.node_index_for_cell(FISHING.fishing_grid_position.x + xx, FISHING.fishing_grid_position.y + yy);
                                                if GRID.node_terrain_kind[ni] == TerrainKind.Water {
                                                    fish.x = (FISHING.fishing_grid_position.x + xx) * 8 + irandom_range(2, 6);
                                                    fish.y = (FISHING.fishing_grid_position.y + yy) * 8 + irandom_range(2, 6);
                                                    breaker = true;
                                                    break;
                                                }
                                            }

                                            if breaker {
                                                break;
                                            }
                                        }

                                        fish.dir = point_direction(fish.x, fish.y, land_pos.x, land_pos.y);
                                        fish.facing_dir = fish.dir;

                                        var state = fish.fsm.current_state();
                                        state.travel_time = 30;
                                        state.change_dir_countdown = 180;
                                    }, [fish_id, self.land_pos, self.owner.bait_prototype.item_id]);
                            } else if self.owner.bait_prototype == undefined {
                                self.owner.anim_effects.push(
                                    create_animation_effect_on_object(obj_bobber, spr_fx_lure_range, -1, 0)
                                );

                                self.fsm.change_state(BobberState.InWater);
                            }

                            //
                            self.owner.has_landed = true;
                            self.owner.x = floor(self.land_pos.x);
                            self.owner.y = floor(self.land_pos.y);
                        }

                        self.owner.depth = get_instance_depth(self.owner.y, -18);
                    })
                    .draw(function() {
                        draw_sprite_ext(
                            self.owner.sprite_index,
                            self.owner.image_index,
                            self.owner.x,
                            lerp(
                                obj_ari.y,
                                self.land_pos.y,
                                self.counter / self.air_time
                            ),
                            self.owner.image_xscale,
                            self.owner.image_yscale,
                            self.owner.image_angle,
                            c_black,
                            0.3
                        );
                        draw_sprite_ext(
                            owner.sprite_index,
                            owner.image_index,
                            owner.x,
                            owner.y,
                            owner.image_xscale,
                            owner.image_yscale,
                            0,
                            owner.image_blend,
                            owner.image_alpha,
                        );
                    })
                    .stop(function() {
                        self.blackboard.set("land_pos", self.land_pos);
                        self.owner.prune_anim_effects();
                    })
                    .spawn()
                )
                .add_state(StateBuilder(BobberState.InWater)
                    .create(function() {
                        self.move = Vec2();
                    })
                    .start(function() {
                        set_rumble(RumbleKind.BobberInWater);

                        //
                        self.start_pos = self.blackboard.take("land_pos");

                        //
                        self.max_dist_from_land = 60;

                        //
                        self.owner.set_sprite(spr_tool_lure_old_water_land);

                        self.owner.depth = get_water_depth() - 2;
                    })
                    .step(function() {
                        self.move.set_val(0, 0);

                        //
                        var _force = GRID.node_force[GRID.node_index_for_room_position(self.owner.x, self.owner.y)];
                        if _force != undefined && _force != 0 && point_distance(self.start_pos.x, self.start_pos.y, self.owner.x, self.owner.y) < self.max_dist_from_land {
                            self.current_tile = _force;
                            self.water_current_dir = tile_forces_to_dir(self.current_tile);
                            if self.water_current_dir != 0 {
                                var _dir = tile_forces_to_dir(self.current_tile);
                                self.move.x += lengthdir_x(WATER_FLOW_SPEED, _dir);
                                self.move.y += lengthdir_y(WATER_FLOW_SPEED, _dir);
                            }
                        }

                        var _force = self.blackboard.try_take("force");
                        if(_force != undefined) {
                            self.move.set_add(_force);
                        }

                        if (
                            GRID.node_terrain_kind[GRID.node_index_for_cell(
                                (self.owner.x + self.move.x) div OBJECT_CELL_SIZE,
                                (self.owner.y + self.move.y) div OBJECT_CELL_SIZE,
                            )] == TerrainKind.Water
                        ) {
                            //
                            self.owner.x += self.move.x;
                            self.owner.y += self.move.y;
                        }

                    })
                    .draw(function() {
                        draw_sprite_ext(
                            owner.sprite_index,
                            owner.image_index,
                            owner.x,
                            owner.y,
                            owner.image_xscale,
                            owner.image_yscale,
                            0,
                            owner.image_blend,
                            owner.image_alpha,
                        );

                        //
                        if self.owner.sprite_index == spr_tool_lure_old_bite_start {
                            with self.owner {
                                draw_sprite(spr_fx_lure_bite_loop, self.image_index, self.x, self.y);
                            }
                        }
                    })
                    .stop(function() {
                        self.owner.prune_anim_effects();
                    })
                    .spawn()
                )
                .add_state(StateBuilder(BobberState.Reel)
                    .create(function() {
                        self.end_pos = Vec2();
                        self.start_pos = Vec2();
                        self.offset = Vec2();
                    })
                    .start(function() {
                        self.air_time = 1;
                        self.counter = 0;
                        self.owner.clear_anim_effects();

                        var fish_size = self.blackboard.try_take("fish_size");
                        if fish_size != undefined {
                            create_animation_effect(self.owner.x, self.owner.y, self.owner.depth - 1, spr_fx_reel_fish_splash_bottom);
                            create_animation_effect(self.owner.x, self.owner.y, self.owner.depth - 1, spr_fx_reel_fish_splash_top);
                            var _icon = self.blackboard.take("icon");
                            self.owner.set_sprite(_icon);
                            switch fish_size {
                                case FishSize.Small:
                                    self.air_time = 45;
                                    self.arc_height = 55;
                                    break;

                                case FishSize.Medium:
                                    self.air_time = 50;
                                    self.arc_height = 52;
                                    break;

                                case FishSize.Large:
                                case FishSize.Giant:
                                    self.air_time = 55;
                                    self.arc_height = 48;
                                    break;

                                default:
                                    impossible("Unexpected fish size {}", fish_size);
                            }
                            self.offset.set_val(
                                - (sprite_get_width(_icon) / 2),
                                - (sprite_get_height(_icon) / 2) - 3
                            );
                        } else {
                            create_animation_effect(self.owner.x, self.owner.y, self.owner.depth - 1, spr_fx_lure_reel_in_lure);
                            self.owner.set_sprite(spr_tool_lure_old_cast);
                            self.air_time = 30;
                            self.arc_height = 30;
                        }

                        self.start_pos.set_val(self.owner.x, self.owner.y);
                        self.counter = 0;
                        self.end_pos.set_val(obj_ari.x + 9, obj_ari.y - 17);
                    })
                    .step(function() {
                        //
                        self.counter += 1;

                        var at = clamp(self.counter / self.air_time, 0, 1);

                        self.owner.x = lerp(self.start_pos.x, self.end_pos.x, at);
                        self.owner.y = lerp(self.start_pos.y, self.end_pos.y, at) - (sin(at*pi) * self.arc_height);
                        self.owner.depth = get_instance_depth(self.owner.y, -18);
                    })
                    .draw(function() {
                        draw_sprite_ext(
                            self.owner.sprite_index,
                            self.owner.image_index,
                            self.owner.x + self.offset.x,
                            lerp(
                                self.start_pos.y,
                                self.end_pos.y,
                                self.counter / self.air_time
                            ) + self.offset.y,
                            self.owner.image_xscale,
                            self.owner.image_yscale,
                            self.owner.image_angle,
                            c_black,
                            0.3
                        );

                        draw_sprite_ext(
                            self.owner.sprite_index,
                            self.owner.image_index,
                            self.owner.x + self.offset.x,
                            self.owner.y + self.offset.y,
                            self.owner.image_xscale,
                            self.owner.image_yscale,
                            self.owner.image_angle,
                            self.owner.image_blend,
                            self.owner.image_alpha
                        );

                        if self.counter >= self.air_time {
                            obj_ari.fsm.change_state(PlayerState.Default);
                        }
                    })
                    .stop(function() {
                        self.owner.prune_anim_effects();
                    })
                    .spawn()
                )
                .spawn(
                    BobberState.Cast,
                    self,
                    MapWrap({})
                );

        },
        step: function() {
            if game_paused() {
                return;
            }

            self.fsm.step();
        },
        step_begin: function() {
            if game_paused() {
                return;
            }
            var nibble_data = FISHING.get_subscriber(id);

            if self.bait_prototype == undefined {
                switch nibble_data.kind {
                    case FishingEvent.Nibble:
                        self.anim_effects.push(create_animation_effect_on_object(obj_bobber, spr_fx_lure_nibble_med, -1, 0));
                        self.set_sprite(spr_tool_lure_old_water_nibble_med);
                        nibble_data.kind = FishingEvent.None;
                        break;
                    case FishingEvent.Bite:
                        var ae = create_animation_effect(obj_bobber.x, obj_bobber.y - 12, get_instance_depth(self.y, -1), spr_ui_bark_bubble_speak_open);
                        ae.lifetime_frames = (48 / 40) * 60;
                        self.anim_effects.push(ae);
                        ae = create_animation_effect(obj_bobber.x, obj_bobber.y - 12, get_instance_depth(self.y, - 2), spr_ui_bark_icon_exclamation_mark);
                        ae.lifetime_frames = (48 / 40) * 60;
                        self.anim_effects.push(ae);
                        nibble_data.kind = FishingEvent.None;
                        break;
                    case FishingEvent.Caught:
                        self.fsm.blackboard.set("icon", nibble_data.value.item.get_ui_icon());
                        self.fsm.blackboard.set("fish_size", nibble_data.value.size);
                        self.set_sprite(spr_tool_lure_old_bite_start);
                        nibble_data.kind = FishingEvent.None;
                        break;
                }
            }

            self.fsm.new_tick();
        },
        draw: function() {
            self.fsm.draw();
        },
        animation_end: function() {
            if self.bait_prototype != undefined {
                return;
            }

            switch sprite_index {
                case spr_tool_lure_old_water_land:
                    self.set_sprite(spr_tool_lure_old_water_idle);
                    break;
                case spr_tool_lure_old_water_nibble_med:
                    self.set_sprite(spr_tool_lure_old_water_idle);
                    break;
                case spr_tool_lure_old_bite_start:
                    self.set_sprite(spr_tool_lure_old_bite_loop);
                    break;
                case spr_tool_lure_old_bite_end:
                    self.set_sprite(spr_tool_lure_old_cast);
                    break;
            }
        },
    }
);
