#macro GROW_BACK global.__grow_back
global.__grow_back = undefined;

function GrowBack() constructor {
    var f = fiddle_get("grow_back");
    //
    elligible_objects = array_create(ObjectId.LEN, false);
    elligible_object_choice = array_create_ext(Season.LEN, function() {
        return new SlowVotes();
    });

    for (var i = 0; i < array_length(f.elligible_objects); i++) {
        var f_entry = f.elligible_objects[i];
        var o = string_to_object_id(f_entry.candidate);
        elligible_objects[o] = true;

        if f_entry[$ "season"] == undefined {
            for (var s = 0; s < Season.LEN; s++) {
                elligible_object_choice[s].add_candidate(o, f_entry.votes);
            }
        } else {
            elligible_object_choice[string_to_season(f_entry[$ "season"])].add_candidate(o, f_entry.votes);
        }
    }

    cell_size = f.cell_size;
    max_colliders = f.max_colliders;
    colliders_to_spawn_new_season = f.colliders_to_spawn_new_season;
    grass_wait_range = fiddle_deserialize_vec2(f.grass_wait_range);
    max_grass_spawned_per_day = f.max_grass_spawned_per_day;
    colliders_wait_range = fiddle_deserialize_vec2(f.colliders_wait_range);
    max_colliders_spawned_per_day = f.max_colliders_spawned_per_day;
}

function grow_back_new_day(farm_grid) {
    if ARI.perk_active(Perk.DeliberateDebrisTwo) {
        return;
    }
    //
    var grid_dims_x = farm_grid.dims.x;
    var grid_dims_y = NORMAL_FARM_EDGE_Y;
    if FARM_EXPANDED == false {
        grid_dims_x = NORMAL_FARM_EDGE_X;
    }
    var x_width = (grid_dims_x div GROW_BACK.cell_size) + 1;
    var y_width = (grid_dims_y div GROW_BACK.cell_size) + 1;

    var subtraction_amount = 1;
    if ARI.perk_active(Perk.DeliberateDebris) {
        subtraction_amount -= 0.5;
        GAME_STATS.perks[$ perk_to_string(Perk.DeliberateDebris)] += 1;
    }

    for (var xx = 0; xx < x_width; xx++) {
        for (var yy = 0; yy < y_width; yy++) {
            var parent_node = farm_grid.node_index_for_cell(xx * GROW_BACK.cell_size, yy * GROW_BACK.cell_size);

            //
            if farm_grid.node_colliders_count[? parent_node] < GROW_BACK.max_colliders
                && farm_grid.node_spawn_colliders_timer[? parent_node] <= 0
                && farm_grid.node_colliders_count[? parent_node] > 0
            {
                spawn_grow_back_colliders(farm_grid, xx * GROW_BACK.cell_size, yy * GROW_BACK.cell_size, farm_grid.node_colliders_count[? parent_node]);
                farm_grid.node_spawn_colliders_timer[? parent_node] = irandom_range(GROW_BACK.colliders_wait_range.x, GROW_BACK.colliders_wait_range.y) + 1;
            }
            farm_grid.node_spawn_colliders_timer[? parent_node] -= subtraction_amount;

            //
            if farm_grid.node_spawn_grass_timer[? parent_node] <= 0 {
                spawn_grow_back_grass(farm_grid, xx * GROW_BACK.cell_size, yy * GROW_BACK.cell_size, farm_grid.node_grass_count[? parent_node]);
                farm_grid.node_spawn_grass_timer[? parent_node] = irandom_range(GROW_BACK.grass_wait_range.x, GROW_BACK.grass_wait_range.y) + 1;
            }

            farm_grid.node_spawn_grass_timer[? parent_node] -= subtraction_amount;
        }
    }
}

function spawn_grow_back_grass(grid, root_x, root_y, grass_count) {
    var grass_to_spawn = floor((grass_count / 80) * GROW_BACK.max_grass_spawned_per_day);
    grass_to_spawn = clamp(grass_to_spawn, 1, GROW_BACK.max_grass_spawned_per_day);

    repeat grass_to_spawn {
        repeat GROW_BACK.cell_size * GROW_BACK.cell_size {
            var xx = irandom_range(0, 15) + root_x;
            var yy = irandom_range(0, 15) + root_y;
            var n = grid.try_node_index_for_cell(xx, yy);
            if n == undefined || has_flag(grid.node_flags[n], TileFlag.Wilderness) == false {
                continue;
            }

            //
            if grid.write_node(xx, yy, ObjectId.GrassSmall) != undefined {
                break;
            }
        }
    }
}

function spawn_grow_back_colliders(grid, root_x, root_y, colliders_count) {
    var colliders_to_spawn = floor((colliders_count / GROW_BACK.max_colliders) * GROW_BACK.max_colliders_spawned_per_day);
    colliders_to_spawn = clamp(colliders_to_spawn, 1, GROW_BACK.max_colliders_spawned_per_day);
    var system_votes = GROW_BACK.elligible_object_choice[CALENDAR.season()];

    repeat colliders_to_spawn {
        var success = false;
        repeat GROW_BACK.cell_size * GROW_BACK.cell_size {
            var xx = irandom_range(0, 7) * 2 + root_x;
            var yy = irandom_range(0, 7) * 2 + root_y;
            var n = grid.try_node_index_for_cell(xx, yy);
            if n == undefined || has_flag(grid.node_flags[n], TileFlag.Wilderness) == false {
                continue;
            }

            var success = false;
            repeat 10 {
                if grid.write_node(xx, yy, system_votes.get_candidate()) != undefined {
                    success = true;
                    break;
                }
            }
            if success {
                break;
            }
        }
    }
}

//
//
function spawn_new_season_colliders(grid) {
    var colliders_spawned = 0;
    var system_votes = GROW_BACK.elligible_object_choice[CALENDAR.season()];

    repeat 1000 {
        var pos_x = irandom_range(0, (grid.dims.x - 1) div 2) * 2;
        var pos_y = irandom_range(0, (grid.dims.y - 1) div 2) * 2;

        var ni = grid.try_node_index_for_cell(pos_x, pos_y);
        if ni == undefined || has_flag(grid.node_flags[ni], TileFlag.Wilderness) == false {
            continue;
        }
        var cat_present = object_id_to_object_category(grid.node_object_id[ni]);
        if cat_present != undefined && cat_present != ObjectCategory.Grass {
            continue;
        }

        //
        var others_are_grass = true;
        for (var xx = 0; xx < 2; xx++) {
            for (var yy = 0; yy < 2; yy++) {
                var other_ni = grid.try_node_index_for_cell(pos_x + xx, pos_y + yy);
                if other_ni == undefined {
                    others_are_grass = false;
                    break;
                }
                var other_cat_present = object_id_to_object_category(grid.node_object_id[other_ni]);
                if other_cat_present != undefined && other_cat_present != ObjectCategory.Grass {
                    others_are_grass = false;
                    break;
                }
            }

            if others_are_grass == false {
                break;
            }
        }

        //
        if others_are_grass == false {
            continue;
        }

        for (var xx = 0; xx < 2; xx++) {
            for (var yy = 0; yy < 2; yy++) {
                erase_object_node(grid, grid.node_index_for_cell(pos_x + xx, pos_y + yy));
            }
        }

        //
        repeat 10 {
            var success = grid.write_node(pos_x, pos_y, system_votes.get_candidate());
            if success != undefined {
                colliders_spawned += 1;
                break;
            }
        }

        if colliders_spawned >= GROW_BACK.colliders_to_spawn_new_season {
            break;
        }
    }

    trace("GrowBack spawned in {} colliders", colliders_spawned);
}
