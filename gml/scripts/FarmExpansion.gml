#macro FARM_EXPANDED global.__farm_expanded
global.__farm_expanded = undefined;

#macro NORMAL_FARM_EDGE_X 172
#macro NORMAL_FARM_EDGE_Y 126

function expand_farm() {
    FARM_EXPANDED = true;
    var coordinates = fiddle_get("misc").farm_expansion_fence_region;
    var farm_grid = GRIDS[LocationId.Farm];
    for (var xx = coordinates.top_left.x; xx < coordinates.bottom_right.x; xx++) {
        for (var yy = coordinates.top_left.y; yy < coordinates.bottom_right.y; yy++) {
            var ni = farm_grid.node_index_for_cell(xx, yy);
            erase_object_node(farm_grid, ni);
            farm_grid.node_terrain_variant[ni] = undefined;
        }
    }

    //
    farm_grid.load_objects(read_json_file("room_data/expansion_patch.json"));

    //
    var json = read_json_file("room_data/expansion_field_decorations.json");
    for (var i = 0, c = array_length(json); i < c; i++) {
        var entry = json[i];
        var ni = entry[0];
        var variant = serialized_to_main_exterior_tile_indexes(entry[1]);
        farm_grid.node_terrain_variant[ni] = variant;
    }

    //
    var cells = fiddle_get("misc/farm_expansion_collision_points");
    for (var i = 0; i < array_length(cells); i++) {
        var cell = cells[i];
        remove_collision_on_node(farm_grid, cell[0], cell[1]);
    }
}

//
//
//
//
//
//
//
//
function setup_expansion_blockers(farm_grid) {
    if FARM_EXPANDED == false {
        //
        var cells = fiddle_get("misc/farm_expansion_collision_points");
        for (var i = 0; i < array_length(cells); i++) {
            var cell = cells[i];
            set_collision_on_node(farm_grid, cell[0], cell[1], false, false);
        }
    }
}
