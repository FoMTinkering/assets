//
function load_npc_farms(grid) {
    if LOCATIONS[grid.location_id].npc_farm == false {
        return;
    }

    for (var xx = 0; xx < grid.dims.x; xx++) {
        for (var yy = 0; yy < grid.dims.y; yy++) {
            var ni = grid.node_index_for_cell(xx, yy);

            if has_flag(grid.node_flags[ni], TileFlag.NpcFarm)
                && grid.node_object_id[ni] != undefined
                && object_id_to_object_category(grid.node_object_id[ni]) == ObjectCategory.Crop
            {
                grid.write_ground(xx, yy, GroundKind.Soil, function(grid, ni) {
                    grid.node_terrain_is_watered[ni] = true;
                });
            }
        }
    }
}

function npc_farming_new_day(grid) {
    for (var ni = 0; ni < grid.node_len; ni++) {
        if grid.node_terrain[ni] == undefined || grid.node_terrain_kind[ni] != TerrainKind.Ground {
            continue;
        }

        if grid.node_object_id[ni] != undefined
            && object_id_to_object_category(grid.node_object_id[ni]) == ObjectCategory.Crop
        {
            grid.node_terrain_is_watered[ni] = true;
        }
    }
}
