#macro CURRENT_DYN_INDEX (GRID.dyn_index)
#macro CURRENT_LOCATION_ID (GRID.location_id)

function get_instance_depth(yy, z_offset=0) {
    gml_pragma("forceinline");

    return floor(z_offset - yy);
}

function get_floor_depth() {
    if CURRENT_LOCATION_ID == LocationId.Dungeon {
        return DUNGEON_FLOOR_DEPTH;
    } else {
        return room_data_layer_depth(room(), "Level_0_FloorSprites");
    }
}

function get_shadow_depth() {
    if CURRENT_LOCATION_ID == LocationId.Dungeon {
        return DUNGEON_SHADOW_DEPTH;
    } else {
        return room_data_layer_depth(room(), "Level_0_Shadows");
    }
}

function fix_plaza_footsteps() {
    var g = GRIDS[LocationId.Town];

    //
    for (var xx = 20; xx < 50; xx++) {
        for (var yy = 100; yy < 119; yy++) {
            var ni = g.node_index_for_cell(xx, yy);
            g.node_footstep_kind[ni] = FootstepKind.Stone;
        }
    }
}

function get_water_depth() {
    var target;

    if room() == rm_farm {
        target = "Level_0_Clearground";
    } else if is_dungeon_room(room()) {
        target = "Water";
    } else {
        target = "Level_0_River";
    }

    assert(layer_exists(target), "Tried to set an instance to the water's depth, but the layer {} did not exist!", target);
    return layer_get_depth(layer_get_id(target));
}

//
//
enum WaterType {
    None,
    Pond,
    River,
    Ocean,
    LEN
}

//
//
function reserve_dynamic_room(_location_id) {
    var grid = initialize_grid(_location_id, DYNAMIC_GRIDS.count());
    first_time_grid_setup(grid);

    grid.is_setup = true;

    return grid;
}

//
//
function push_dynamic_room(dynamic_room_grid) {
    assert_eq(DYNAMIC_GRIDS.count(), dynamic_room_grid.dyn_index);
    DYNAMIC_GRIDS.push(dynamic_room_grid);
}

//
//
function create_dynamic_room(_location_id) {
    var grid = reserve_dynamic_room(_location_id);
    push_dynamic_room(grid);
}

function tile_forces_to_dir(tile) {
    //
    //
    //
    var index = tile mod 9;
    //
    return index == 0 ? 0 : (index - 1) * 45;
}

function tile_forces_to_level(tile) {
    return tile div 9;
}
