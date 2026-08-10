#macro GRASS_DISTRO global.__grass_distro
global.__grass_distro = undefined;

enum MainExteriorTileIndexes {
    DirtNormal = 64,
    DirtVariantOne = 128,
    DirtVariantTwo = 192,
    DirtVariantThree = 256,
    GrassNormal = 66,
    FlowerVariantOne = 134,
    FlowerVariantTwo = 135,
    GrassVariantOne = 136,
    GrassVariantTwo = 137,
}

function write_ground_to_location(grid, top_left_x, top_left_y, ground_kind, node_callback, callback_args) {
    //
    if (top_left_x > (grid.dims.x - 2)) || (top_left_y > (grid.dims.y - 2)) {
        return false;
    }

    for (var xx = 0; xx < 2; xx++) {
        for (var yy = 0; yy < 2; yy++) {
            var ni = grid.node_index_for_cell(top_left_x + xx, top_left_y + yy);

            grid.node_terrain_kind[ni] = TerrainKind.Ground;
            grid.node_terrain_ground_kind[ni] = ground_kind;
            grid.node_terrain_is_watered[ni] = false;
            grid.node_terrain_variant[ni] = undefined;
            grid.node_terrain_tile[ni] = undefined;

            if node_callback != undefined {
                if callback_args == undefined {
                    node_callback(grid, ni);
                } else {
                    script_execute_ext(node_callback, array_concat([grid, ni], callback_args));
                }
            }
        }
    }

    return true;
}

function write_water_to_location(grid, top_left_x, top_left_y, node_callback, callback_args) {
    //
    if (top_left_x > (grid.dims.x - 2)) || (top_left_y > (grid.dims.y - 2)) {
        return false;
    }

    for (var xx = 0; xx < 2; xx++) {
        for (var yy = 0; yy < 2; yy++) {
            var ni = grid.node_index_for_cell(top_left_x + xx, top_left_y + yy);

            grid.node_terrain_kind[ni] = TerrainKind.Water;

            if node_callback != undefined {
                if callback_args == undefined {
                    node_callback(grid, ni);
                } else {
                    script_execute_ext(node_callback, array_concat([grid, ni], callback_args));
                }
            }
        }
    }

    return true;
}

//
function write_lava_to_location(grid, top_left_x, top_left_y, node_callback, callback_args) {
    //
    if (top_left_x > (grid.dims.x - 2)) || (top_left_y > (grid.dims.y - 2)) {
        return false;
    }

    for (var xx = 0; xx < 2; xx++) {
        for (var yy = 0; yy < 2; yy++) {
            var ni = grid.node_index_for_cell(top_left_x + xx, top_left_y + yy);

            grid.node_terrain_kind[ni] = TerrainKind.Lava;
            set_collision_on_node(grid, top_left_x + xx, top_left_y + yy, true);

            if node_callback != undefined {
                if callback_args == undefined {
                    node_callback(grid, ni);
                } else {
                    script_execute_ext(node_callback, array_concat([grid, ni], callback_args));
                }
            }
        }
    }

    return true;
}

function terrain_set_dirt_or_grass_variant(grid, xx, yy) {
    var ni = grid.node_index_for_cell(xx, yy);
    if grid.node_terrain[ni] == undefined {
        //
        return;
    }
    var terrain = grid.node_terrain[ni];
    assert_eq(terrain.kind, TerrainKind.Ground, "can only set dirt or grass variants for ground terrain");

    var variant = undefined;

    //
    switch terrain.ground_kind {
        case GroundKind.Dirt:
            variant = choose(
                MainExteriorTileIndexes.DirtVariantOne,
                MainExteriorTileIndexes.DirtVariantTwo,
                MainExteriorTileIndexes.DirtVariantThree,
            );
            break;

        case GroundKind.Grass:
            if GRASS_DISTRO == undefined {
                GRASS_DISTRO = grass_tile_variant_distro();
            }
            variant = GRASS_DISTRO.get_candidate();
            break;

        default:
            return;
    }

    //
    static CHECK_NO_DOUBLE = function(grid, xx, yy, variant) {
        if is_between(xx, 0, grid.dims.x) == false || is_between(yy, 0, grid.dims.y) == false {
            return false;
        }

        var ni = grid.node_index_for_cell(xx, yy);
        if grid.node_terrain[ni] == undefined {
            return false;
        }

        return grid.node_terrain_variant[ni] == variant;
    }
    if CHECK_NO_DOUBLE(grid, xx - 1, yy, variant)
        || CHECK_NO_DOUBLE(grid, xx, yy - 1, variant)
        || CHECK_NO_DOUBLE(grid, xx + 1, yy, variant)
        || CHECK_NO_DOUBLE(grid, xx, yy + 1, variant)
    {
        return;
    }


    terrain.variant = variant;
}

//
//
//
function write_terrain_tile_to_tilemap(grid, xx, yy) {
    assert_eq(grid.location_id, CURRENT_LOCATION_ID, "tried to write a tile to a wrong grid!");
    var do_it = true;

    var ni = grid.node_index_for_cell(xx, yy);

    if grid.node_terrain_ground_kind[ni] == GroundKind.Grass {
        do_it = tilemap_get(grid.grass_autotile_tilemap_id, xx div 2, yy div 2) == AUTOTILE_FULLGRASS_CELL;
    }
    if do_it {
        tilemap_set(grid.grass_variant_tilemap_id, grid.node_terrain_variant[ni], xx div 2, yy div 2);

        return true;
    }

    return false;
}

function grass_tile_variant_distro() {
    var o = new SlowVotes();
    return o
        .add_candidate(MainExteriorTileIndexes.GrassVariantOne, fiddle_get("misc/farm_data/grass_variant_rates/grass_votes"))
        .add_candidate(MainExteriorTileIndexes.GrassVariantTwo, fiddle_get("misc/farm_data/grass_variant_rates/grass_votes"))
        .add_candidate(MainExteriorTileIndexes.FlowerVariantOne, fiddle_get("misc/farm_data/grass_variant_rates/flower_votes"))
        .add_candidate(MainExteriorTileIndexes.FlowerVariantTwo, fiddle_get("misc/farm_data/grass_variant_rates/flower_votes"));
}
