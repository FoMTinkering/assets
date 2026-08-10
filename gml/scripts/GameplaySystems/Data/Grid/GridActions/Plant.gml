//
//
function can_plant_seed(xx, yy, crop_object_id) {
    var in_pq = CURRENT_LOCATION_ID == LocationId.PriestessQuarters;
    if crop_object_id == ObjectId.MagicKey {
        if !in_pq {
            return false;
        }
    } else if in_pq {
        return false;
    } else if !LOCATIONS[CURRENT_LOCATION_ID].farm {
        return false;
    }

    var prototype = NODE_PROTOTYPES[crop_object_id];

    //
    //
    if prototype.category_id != ObjectCategory.Crop
        || (CURRENT_LOCATION_ID == LocationId.Farm && prototype.seasons[CALENDAR.season()] == false)
    {
        return false;
    }

    for (var _x = xx; _x < xx + 2; _x++) {
        for (var _y = yy; _y < yy + 2; _y++) {
            var node_check = GRID.node_index_for_cell(_x, _y);
            if !can_write_object_on_node(GRID, node_check, TerrainKind.Ground) || GRID.node_terrain_ground_kind[node_check] != GroundKind.Soil {
                return false
            }
        }
    }

    return true;
}

//
//
function can_plant_sapling(grid, xx, yy, sapling_object_id) {
    if !LOCATIONS[CURRENT_LOCATION_ID].farm {
        return false;
    }

    var prototype = NODE_PROTOTYPES[sapling_object_id]
    if prototype.category_id != ObjectCategory.Tree {
        return false;
    }

    for (var i = xx; i < xx + 6; i++) {
        for (var j = yy; j < yy + 6; j++) {
            var ni = grid.try_node_index_for_cell(i, j);
            if ni == undefined {
                return false;
            }
            if !has_flag(grid.node_flags[ni], TileFlag.Placeable) {
                return false;
            }
            var good_node = grid.node_object_id[ni] == undefined
                && grid.node_terrain_kind[ni] == TerrainKind.Ground
                && grid.node_terrain_ground_kind[ni] != GroundKind.RiverBank
                && can_write_object_on_node(grid, ni, TerrainKind.Ground);
            if good_node == false {
                return false;
            }
        }
    }

    return true;
}

//
function can_plant_grass(grid, xx, yy) {
    if CURRENT_LOCATION_ID != LocationId.Farm {
        return false;
    }

    for (var _x = xx; _x < xx + 2; _x++) {
        for (var _y = yy; _y < yy + 2; _y++) {
            var node_check = grid.node_index_for_cell(_x, _y);
            if !can_write_object_on_node(grid, node_check, TerrainKind.Ground) || grid.node_terrain_ground_kind[node_check] != GroundKind.Grass {
                return false
            }
        }
    }

    return true;
}

//
function plant_seed(grid, x_pos, y_pos, crop_object_id) {
    if can_plant_seed(x_pos, y_pos, crop_object_id) == false {
        return undefined;
    }
    return grid.write_node(x_pos, y_pos, crop_object_id);
}

function plant_sapling(grid, x_pos, y_pos, sapling_object_id) {
    if can_plant_sapling(grid, x_pos, y_pos, sapling_object_id) == false {
        return undefined;
    }
    return grid.write_node(x_pos, y_pos, sapling_object_id);
}


function plant_grass(grid, xx, yy, grass_object_id) {
    if can_plant_grass(grid, xx, yy) == false {
        return false;
    }

    for (var x_off = 0; x_off < 2; x_off++) {
        for (var y_off = 0; y_off < 2; y_off++) {
            grid.write_node(xx + x_off, yy + y_off, grass_object_id);
        }
    }

    return true;
}
