//
function can_water_node(grid, ni) {
    var waterable_soil = grid.node_terrain_kind[ni] == TerrainKind.Ground
        && grid.node_terrain_ground_kind[ni] == GroundKind.Soil
        && grid.node_terrain_is_watered[ni] == false
        && grid.node_rug_id[ni] == undefined;
    var waterable_lava = grid.node_terrain_kind[ni] == TerrainKind.Lava
        && grid.node_collideable[ni]
        && grid.node_can_jump_over[ni];

    return waterable_soil || waterable_lava;
}

function water_transform_lava(grid, x_pos, y_pos) {
    var inst_index = grid.node_index_for_cell(x_pos, y_pos);
    assert(grid.node_terrain_kind[inst_index] == TerrainKind.Lava);

    //
    var tlx = (x_pos div 2) * 2;
    var tly = (y_pos div 2) * 2;
    remove_collision_on_node_region(grid, tlx, tly, tlx + 1, tly + 1);

    for (var xx = tlx; xx < tlx + 2; xx++) {
        for (var yy = tly; yy < tly + 2; yy++) {
            var ni = grid.node_index_for_cell(xx, yy);
            grid.node_terrain_kind[ni] = TerrainKind.Ground;
            grid.node_terrain_ground_kind[ni] = GroundKind.Dirt;
        }
    }

    instance_create_depth((x_pos * 8) + 8, (y_pos * 8) + 8, 0, obj_lavaplatform);
}

//
function water_chunk(grid, x_pos, y_pos, water=true) {
    assert(x_pos % 2 == 0 && y_pos % 2 == 0, "Odd coordinate given, you can only chunk on even positions.  Coordinate was {}x{}", x_pos, y_pos);
    for (var xx = 0; xx < 2; xx++) {
        for (var yy = 0; yy < 2; yy++) {
            grid.node_terrain_is_watered[grid.node_index_for_cell(x_pos + xx, y_pos + yy)] = water;
        }
    }
}

//
function water_node(grid, x_pos, y_pos) {
    var inst_index = grid.node_index_for_cell(x_pos, y_pos);

    if can_water_node(grid, inst_index) == false {
        //
        //
        //
        //
        return false;
    }

    switch grid.node_terrain_kind[inst_index] {
        case TerrainKind.Ground:
            if grid.node_terrain_is_watered[inst_index] {
                return false;
            }

            water_chunk(grid, x_pos, y_pos);
            grid.update_tilemap_for_node((x_pos div 2) * 2, (y_pos div 2) * 2);
            set_rumble(RumbleKind.ToolWeak);
            break;
        case TerrainKind.Lava:
            water_transform_lava(grid, x_pos, y_pos);
            TANGO.play("SoundEffects/Objects/MakeLavaRock", x_pos * 8, y_pos * 8);
            set_rumble(RumbleKind.ToolStrong);
            break;
        default: impossible("Unexpected TerrainKind: {TerrainKind}", grid.node_terrain_kind[inst_index]);
    }
    var water_sfx =  fiddle_get("tool_fx/water");
    TANGO.play(water_sfx.main_sfx);
    return true;
}

function water_all(grid, crops_only=false) {
    //
    for (var xx = 0; xx < grid.dims.x; xx += 2) {
        for (var yy = 0; yy < grid.dims.y; yy += 2) {
            var ni = grid.node_index_for_cell(xx, yy);
            if crops_only && (grid.node_object_id[ni] == undefined
                || object_id_to_object_category(grid.node_object_id[ni]) != ObjectCategory.Crop)
            {
                continue;
            }
            if can_water_node(grid, ni) {
                if grid.node_terrain_kind[ni] == TerrainKind.Ground {
                    water_chunk(grid, xx, yy);
                } else if grid.node_terrain_kind[ni] == TerrainKind.Lava {
                    water_transform_lava(grid, xx, yy);
                }
            }
        }
    }

    if LOCATIONS[grid.location_id].farm && grid.location_id == CURRENT_LOCATION_ID {
        //
        //
        for (var xx = 0; xx < grid.dims.x; xx += 2) {
            for (var yy = 0; yy < grid.dims.y; yy += 2) {
                grid.auto_tile_tile(xx, yy);
            }
        }
    }
}
