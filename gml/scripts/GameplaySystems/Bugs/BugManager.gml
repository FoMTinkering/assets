enum BugMovementType {
    Fly,
    FlyWave,
    Crawl,
    Jump,
    LEN,
}

enum BugSpawnType {
    Default,
    Canopy,
    Rock,
    Grass,
    LEN,
}

enum BugAttraction {
    None,
    Light,
    Copper,
    CrystalBerries,
}

//
function net_target_in_tile(xx, yy) {
    return collision_rectangle(xx * 8, yy * 8, xx * 8 + 16, yy * 8 + 16, obj_bug) != undefined
        || collision_rectangle(xx * 8, yy * 8, xx * 8 + 16, yy * 8 + 16, obj_monster_clod_bomb) != undefined
        || collision_rectangle(xx * 8, yy * 8, xx * 8 + 16, yy * 8 + 16, obj_monster_clod_projectile) != undefined;
}

function spawn_bug_object(xx, yy, bug, spawn_canopy=true) {
    var inst = instance_create_depth(xx, yy, 0, obj_bug);
    inst.setup(bug, spawn_canopy);
    return instance_exists(inst) ? inst : undefined;
}

function spawn_bug(x_cell, y_cell, spawn_type=BugSpawnType.Default) {
    BUG_CONDITION_DATA.spawn_type = spawn_type;
    var votes = BUG_DISTRIBUTION.get_candidate_votes_at_cell(GRID, x_cell, y_cell);
    var bug_candidate = votes.get_candidate();
    reset_bug_condition_data();
    if bug_candidate != undefined {
        var inst = spawn_bug_object(x_cell * 8, y_cell * 8, bug_candidate, spawn_type == BugSpawnType.Canopy);
        return inst != undefined && instance_exists(inst) ? inst : undefined;
    }
    return undefined;
}

function spawn_bugs_on_room_start() {
    if LOCATIONS[CURRENT_LOCATION_ID].bug_tag != BugTag.NONE
        && LOCATIONS[CURRENT_LOCATION_ID].bug_tag != BugTag.MINES
    {
        var failures = 0;
        var amount_to_spawn = round(LOCATIONS[CURRENT_LOCATION_ID].bugs
            * WEATHER_PROTOTYPES[WEATHER.weather].bug_spawn_multiplier);
        BUG_CONDITION_DATA.spawn_type = BugSpawnType.Default;

        repeat amount_to_spawn {
            var bug_candidate = BUG_DISTRIBUTION.get_candidate_votes_at_cell(GRID, 0, 0).get_candidate();

            //
            if bug_candidate == undefined {
                return;
            }
            var bug_data = BUGS.get(bug_candidate);
            repeat 100 {
                var xx;
                var yy;

                if GRID.location_id == LocationId.Farm {
                    xx = irandom_range(5, FARM_EXPANDED ? GRID.dims.x : NORMAL_FARM_EDGE_X);
                    yy = irandom_range(25, NORMAL_FARM_EDGE_Y);
                } else if bug_data.can_spawn_on_water {
                    if LOCATIONS[CURRENT_LOCATION_ID].bug_water_boxes == undefined {
                        xx = irandom(GRID.dims.x - 1);
                        yy = irandom(GRID.dims.y - 1);
                    } else {
                        var bounds = LOCATIONS[CURRENT_LOCATION_ID].bug_water_boxes.get_candidate();
                        xx = irandom_range(bounds[0].x, bounds[1].x);
                        yy = irandom_range(bounds[0].y, bounds[1].y);
                    }
                } else {
                    if LOCATIONS[CURRENT_LOCATION_ID].bug_boxes == undefined {
                        xx = irandom(GRID.dims.x - 1);
                        yy = irandom(GRID.dims.y - 1);
                    } else {
                        var bounds = LOCATIONS[CURRENT_LOCATION_ID].bug_boxes.get_candidate();
                        xx = irandom_range(bounds[0].x, bounds[1].x);
                        yy = irandom_range(bounds[0].y, bounds[1].y);
                    }
                }

                //
                if test_condition(GRID, Condition.NoCollisionAtCell, xx, yy) == false {
                    continue;
                }

                if bug_data.can_spawn_on_water {
                    if GRID.node_terrain_kind[GRID.node_index_for_cell(xx, yy)] != TerrainKind.Water {
                        continue;
                    }
                } else if GRID.node_terrain_kind[GRID.node_index_for_cell(xx, yy)] != TerrainKind.Ground
                    || GRID.node_terrain_kind[GRID.node_index_for_cell(xx, yy)] == GroundKind.RiverBank
                {
                    continue;
                }

                var inst = instance_create_depth(xx * 8, yy * 8, 0, obj_bug);
                inst.setup(bug_candidate);
                break;
            }
        }

        reset_bug_condition_data();
        return failures;
    }
}
