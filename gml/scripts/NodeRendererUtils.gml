#macro TRAUMATIC_NODE_RENDERERS global.__traumatic_node_renderers
TRAUMATIC_NODE_RENDERERS = List();

#macro ROT_TRAUMATIC_NODE_RENDERERS global.__rot_traumatic_node_renderers
ROT_TRAUMATIC_NODE_RENDERERS = List();

#macro SWAYING_NODE_RENDERERS global.__swaying_node_renderers
SWAYING_NODE_RENDERERS = List();

#macro COLLIDED_GRASS global.__collided_grass
COLLIDED_GRASS = List();

#macro WINDOWS global.__windows
WINDOWS = [];

#macro SPRINKLER_TIMER global.__sprinkler_time
SPRINKLER_TIMER = 120;

#macro SPRINKLER_TIMER_ARRAY global.__sprinkler_timer_array
SPRINKLER_TIMER_ARRAY = undefined;

#macro LEAVING_EOD global.__leaving_eod
LEAVING_EOD = false;

function traumatize(inst, amount) {
    inst.trauma = amount;

    if !TRAUMATIC_NODE_RENDERERS.contains(inst) {
        TRAUMATIC_NODE_RENDERERS.push(inst);
    }
}

function rot_traumatize(inst, amount) {
    inst.rotational_trauma = amount;

    if !ROT_TRAUMATIC_NODE_RENDERERS.contains(inst) {
        ROT_TRAUMATIC_NODE_RENDERERS.push(inst);
    }
}

function sway_renderer(inst, cardinal) {
    if SWAYING_NODE_RENDERERS.contains(inst) {
        return;
    }

    if inst.node.prototype.sound_on_collide != undefined {
        TANGO.play(inst.node.prototype.sound_on_collide, inst.x, inst.y);
    }

    switch cardinal {
        case Cardinal.North:
        case Cardinal.West:
            inst.sway_multiplier = 1;
            break;
        case Cardinal.South:
        case Cardinal.East:
            inst.sway_multiplier = -1;
            break;
    }

    SWAYING_NODE_RENDERERS.push(inst);
}

function collide_grass(inst) {
    inst.collided = true;

    if COLLIDED_GRASS.contains(inst) {
        return;
    }

    TANGO.play(inst.node.prototype.sound_on_collide, inst.x, inst.y);
    COLLIDED_GRASS.push(inst);
}

function run_node_renderer_utils() {
    TRAUMATIC_NODE_RENDERERS.retain(function(inst) {
        if !instance_exists(inst) {
            return false;
        }

        inst.draw_x_offset = inst.trauma * inst.trauma * perlin_noise_get(0) * sign(perlin_noise_get(50) * 2.0 - 1.0);
        inst.draw_y_offset = inst.trauma * inst.trauma * perlin_noise_get(1) * sign(perlin_noise_get(100) * 2.0 - 1.0);

        inst.trauma = approach(inst.trauma, 0, FRAME_TIME);

        return inst.trauma != 0;
    });

    ROT_TRAUMATIC_NODE_RENDERERS.retain(function(inst) {
        if !instance_exists(inst) {
            return false;
        }

        inst.rot = inst.rotational_trauma_range * inst.rotational_trauma * inst.rotational_trauma * perlin_noise_get(0) * sign(perlin_noise_get(50) * 2.0 - 1.0);
        inst.rotational_trauma = approach(inst.rotational_trauma, 0, FRAME_TIME);

        return inst.rot != 0;
    });

    SWAYING_NODE_RENDERERS.retain(function(inst) {
        if !instance_exists(inst) {
            return false;
        }

        inst.sway_counter += 0.2;
        inst.rot = sin(inst.sway_counter) * 10 * inst.sway_multiplier;
        if inst.sway_counter >= pi {
            inst.sway_counter = 0;
            inst.rot = 0;
            return false;
        }

        return true;
    });

    COLLIDED_GRASS.retain(function(inst) {
        if !instance_exists(inst) {
            return false;
        }

        if inst.collided {
            //
            if instance_full_time(inst) + inst.counter_spd < inst.counter_max {
                instance_set_full_time(inst, instance_full_time(inst) + inst.counter_spd);
            }
        } else if instance_full_time(inst) != 0 {
            if inst.count_back {
                if instance_full_time(inst) - inst.counter_spd <= 0 {
                    instance_set_full_time(inst, 0);
                    inst.count_back = false;
                    return false;
                } else {
                    instance_set_full_time(inst, instance_full_time(inst) - inst.counter_spd);
                }
            } else {
                //
                if (instance_full_time(inst) + inst.counter_spd) < inst.counter_max {
                    instance_set_full_time(inst, instance_full_time(inst) + inst.counter_spd);
                } else {
                    inst.count_back = true;
                }
            }
        }

        //
        instance_set_full_time(inst.grass_back, instance_full_time(inst));

        inst.collided = false;

        return true;
    });

    if instance_exists(obj_ari)
        && game_paused() == false
        && (WEATHER.is_inclement() == false || LOCATIONS[CURRENT_LOCATION_ID].outdoor == false)
    {
        SPRINKLER_TIMER -= 1;
        if (SPRINKLER_TIMER % 60) == 0 {
            //
            var range_to_sprinkle = SPRINKLER_TIMER div 60;

            for (var i = 0; i < array_length(GRID.sprinklers); i++) {
                var sprinkler = GRID.sprinklers[i];
                var inst = sprinkler.renderer;
                if sprinkler.essence_supply <= 0 || inst == undefined {
                    continue;
                }

                if range_to_sprinkle < sprinkler.prototype.sprinkler {
                    //
                    //
                    //
                    //
                    if range_to_sprinkle == (sprinkler.prototype.sprinkler - 1) {
                        var should_sprinkle = false;
                        var check_range = sprinkler.prototype.sprinkler * 2;

                        for (var xx = -check_range; xx <= check_range; xx += 2) {
                            //
                            if should_sprinkle {
                                break;
                            }
                            for (var yy = -check_range; yy <= check_range; yy += 2) {
                                var ni = GRID.node_index_for_cell(sprinkler.top_left_x + xx, sprinkler.top_left_y + yy);

                                if GRID.node_terrain_is_watered[ni] == false
                                    && GRID.node_terrain_kind[ni] == TerrainKind.Ground
                                    && GRID.node_terrain_ground_kind[ni] == GroundKind.Soil
                                {
                                    should_sprinkle = true;
                                    break;
                                }
                            }
                        }

                        inst.sprinkle_this_cycle = should_sprinkle;
                    }

                    if inst.sprinkle_this_cycle == false {
                        continue;
                    }

                    //
                    if SPRINKLER_TIMER <= 0 {
                        inst.sprinkle_this_cycle = false;
                    }

                    var did_work = false;
                    var range = (sprinkler.prototype.sprinkler - range_to_sprinkle) * 2;
                    for (var xx = -range; xx <= range; xx += 2) {
                        for (var yy = -range; yy <= range; yy += 2) {
                            //
                            if !(yy == -range || yy == range || xx == range || xx == -range) {
                                continue;
                            }

                            var ni = GRID.node_index_for_cell(sprinkler.top_left_x + xx, sprinkler.top_left_y + yy);
                            if GRID.node_terrain_kind[ni] == TerrainKind.Ground
                                && GRID.node_terrain_ground_kind[ni] == GroundKind.Soil
                            {
                                var play_sound = !did_work;
                                did_work = true;

                                new_world_chain(undefined, CURRENT_LOCATION_ID)
                                    .append(LinkId.Timer, 12)
                                    .append(LinkId.Function, function(x_pos, y_pos, inst_depth, play_sound) {
                                        //
                                        var anim_effect = create_animation_effect(
                                            x_pos,
                                            y_pos,
                                            inst_depth,
                                            spr_water_effect
                                        );

                                        anim_effect.image_idx = 3;
                                        anim_effect.play_sound = play_sound;
                                        anim_effect.image_idx_func = method(anim_effect, function() {
                                            //
                                            var rx = (self.x - 8) div 8;
                                            var ry = (self.y - 8) div 8;

                                            //
                                            //
                                            //
                                            rx = (rx div 2) * 2;
                                            ry = (ry div 2) * 2;

                                            water_chunk(GRID, rx, ry);

                                            GRID.update_tilemap_for_node(rx, ry);
                                            TANGO.play(fiddle_get("tool_fx/water/main_sfx"));
                                            if self.play_sound {
                                                TANGO.play("SoundEffects/Objects/WaterSpriteActivate", self.x, self.y);
                                            }
                                        });
                                    }, [(sprinkler.top_left_x + xx) * 8 + 8, (sprinkler.top_left_y + yy) * 8 + 8, inst.depth, play_sound]);
                            }
                        }
                    }

                    if did_work {
                        inst.track_index = true;
                    }

                    //
                    var ni = GRID.node_index_for_cell(sprinkler.top_left_x, sprinkler.top_left_y);
                    var was_watered = GRID.node_terrain_is_watered[ni];
                    water_chunk(GRID, (sprinkler.top_left_x div 2) * 2, (sprinkler.top_left_y div 2) * 2);
                    if was_watered == false {
                        GRID.update_tilemap_for_node(sprinkler.top_left_x, sprinkler.top_left_y);
                    }
                }
            }
        }

        //
        for (var i = 0; i < array_length(GRID.sprinklers); i++) {
            var sprinkler = GRID.sprinklers[i];
            var inst = sprinkler.renderer;
            if inst != undefined && inst[$ "track_index"] {
                var modded_time = SPRINKLER_TIMER % 60;
                var current_frame_time = 0;
                if modded_time > 0 {
                    current_frame_time = 60 -(SPRINKLER_TIMER % 60);
                }
                var estimated_index = game_frame_to_frame_timings_image_index(current_frame_time + SPRINKLER_TIMER_ARRAY[0], SPRINKLER_TIMER_ARRAY);
                if estimated_index == undefined {
                    inst.track_index = false;
                    inst.image_index = 0;
                } else {
                    inst.image_index = estimated_index;
                }
            }
        }

        //
        if SPRINKLER_TIMER <= 0 {
            SPRINKLER_TIMER = 120;
        }
    }
}
