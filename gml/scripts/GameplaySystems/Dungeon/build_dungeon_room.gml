//
#macro DUNGEON_FLOOR_DEPTH 1150
#macro DUNGEON_SHADOW_DEPTH 1100

function build_dungeon_room(grid) {
    trace("Building a dungeon room...");

    //
    //
    //
    var ladder_index = 0;
    var all_instances = instance_get_all();
    for (var i = 0; i < array_length(all_instances); i++) {
        var inst = all_instances[i];
        if inst[$ "dungeon_init"] != undefined {
            var my_impl = undefined;
            if inst.layer != undefined && layer_exists(inst.layer) {
                var name = string_lower(layer_get_name(inst.layer));
                if string_pos("impl", name) != 0 {
                    var str = string_replace(name, "impl_", "");
                    my_impl = string_to_dungeon_impl(str);
                }
            }
            if my_impl == undefined || my_impl == DUNGEON_IMPL {
                if inst.object_index == obj_dungeon_elevator && !dungeon_level_contains_elevator(DUNGEON_FLOOR) {
                    instance_destroy(inst.id);
                    continue;
                } else if inst.object_index == obj_dungeon_ladder_down {
                    inst.ladder_choice_index = ladder_index;
                    ladder_index += 1;
                }
                inst.dungeon_init();
            } else {
                instance_destroy(inst.id);
            }
        }
    }

    if is_special_dungeon_room(room()) {
        return;
    }

    //
    background_set_color(c_black, 1.0);
    strict_layer_set_visible("Prototype", false);
    strict_layer_set_visible("Chance", false);

    //
    var biome = DUNGEON.biomes[DUNGEON_BIOME];
    var base_set = string_to_asset(fmt("tile_main_dungeon_{}_ground_base", biome.asset_insert));
    var ground_set = string_to_asset(fmt("tile_main_dungeon_{}_ground_normal", biome.asset_insert));
    var dark_set = string_to_asset(fmt("tile_main_dungeon_{}_ground_darker", biome.asset_insert));
    var bright_set = string_to_asset(fmt("tile_main_dungeon_{}_ground_brighter", biome.asset_insert));
    var ruins_set = string_to_asset(fmt("tile_main_dungeon_{}_ground_ruins", biome.asset_insert));
    var shadow_sets = [
        string_to_asset(fmt("tile_main_dungeon_{}_shadows_0", biome.asset_insert)),
        string_to_asset(fmt("tile_main_dungeon_{}_shadows_1", biome.asset_insert)),
        string_to_asset(fmt("tile_main_dungeon_{}_shadows_2", biome.asset_insert)),
        string_to_asset(fmt("tile_main_dungeon_{}_shadows_3", biome.asset_insert)),
    ];
    var wall_sets = [
        string_to_asset(fmt("tile_main_dungeon_{}_walls_bottom", biome.asset_insert)),
        string_to_asset(fmt("tile_main_dungeon_{}_walls_middle", biome.asset_insert)),
        string_to_asset(fmt("tile_main_dungeon_{}_walls_top", biome.asset_insert)),
        string_to_asset(fmt("tile_main_dungeon_{}_walls_roof", biome.asset_insert)),
    ];

    //
    var chance_map = strict_layer_tilemap_get_id(layer_get_id("Chance"));
    var lava_map = layer_create_with_tilemap("Lava", 2000, tile_dungeon_mines_lava);
    var dark_lava_map = layer_create_with_tilemap("DarkLava", 1900, tile_dungeon_mines_lava); //
    var water_map = layer_create_with_tilemap("Water", 1800, tile_dungeon_mines_water);
    var dark_water_map = layer_create_with_tilemap("DarkWater", 1700, tile_dungeon_mines_water_dark);
    var base_map = layer_create_with_tilemap("Base", 1600, base_set);
    var ground_map = layer_create_with_tilemap("Ground", 1500, ground_set);
    var dark_map = layer_create_with_tilemap("Dark", 1400, dark_set);
    var bright_map = layer_create_with_tilemap("Bright", 1300, bright_set);
    var ruins_map = layer_create_with_tilemap("Ruins", 1200, ruins_set);
    //
    var shadow_maps = [
        layer_create_with_tilemap("Shadows 0", DUNGEON_SHADOW_DEPTH, shadow_sets[0]),
        layer_create_with_tilemap("Shadows 1", DUNGEON_SHADOW_DEPTH, shadow_sets[1]),
        layer_create_with_tilemap("Shadows 2", DUNGEON_SHADOW_DEPTH, shadow_sets[2]),
        layer_create_with_tilemap("Shadows 3", DUNGEON_SHADOW_DEPTH, shadow_sets[3]),
    ];
    var number_map = layer_create_with_tilemap("Debug Numbers", -10001, tile_dungeon_number_overlay);
    strict_layer_set_visible("Debug Numbers", false);
    var overlay_map = layer_create_with_tilemap("Overlay", Game.depth + 1, wall_sets[3]);
    var wall_maps = [
        layer_create_with_tilemap("Walls 0", 1000, wall_sets[0]),
        layer_create_with_tilemap("Walls 1", 900, wall_sets[1]),
        layer_create_with_tilemap("Walls 2", 800, wall_sets[2]),
        layer_create_with_tilemap("Walls 3", -1000, wall_sets[3]),
    ];

    //
    tilemap_y(water_map, 8);
    tilemap_y(dark_water_map, 8);
    tilemap_y(lava_map, 8);
    tilemap_y(dark_lava_map, 8);
    tilemap_y(base_map, 16);
    tilemap_y(wall_maps[1], -16);
    tilemap_y(wall_maps[2], -32);
    tilemap_y(wall_maps[3], -32);
    tilemap_y(number_map, -32);

    tilemap_x(shadow_maps[1], 16);
    tilemap_y(shadow_maps[2], 16);
    tilemap_x(shadow_maps[3], 16);
    tilemap_y(shadow_maps[3], 16);

    //
    for (var i = 0; i < array_length(shadow_maps); i++) {
        strict_layer_set_visible(layer_get_id(format("Shadows {}", i)), false);
    }

    //
    var shadow_level = instance_create_depth(0, 0, DUNGEON_SHADOW_DEPTH, obj_shadow_level, {
        shadow_maps,
        shadow_map_offsets: [
            Vec2(0, 0),
            Vec2(16, 0),
            Vec2(0, 16),
            Vec2(16, 16),
        ],
        render_outlines: false,
        target_shadow_grid: SHADOW_GRID,
    });
    if DEBUG_TOOLS {
        shadow_level.name = "Level_0_Shadows";
    }

    //
    var room_info = DUNGEON_ROOMS.get(room());
    for (var yy = 0; yy < grid.dims.y div 2; yy++) {
        for (var xx = 0; xx < grid.dims.x div 2; xx++) {
            var wall_tile = da_grid_get(room_info.walls, xx, yy);
            var ground_tile = da_grid_get(room_info.ground_base, xx, yy);
            var ox = xx * 2;
            var oy = yy * 2;

            //
            tilemap_set(shadow_maps[0], wall_tile, xx, yy);
            tilemap_set(shadow_maps[1], wall_tile, xx, yy);
            tilemap_set(shadow_maps[2], wall_tile, xx, yy);
            tilemap_set(shadow_maps[3], wall_tile, xx, yy);
            tilemap_set(overlay_map, da_grid_get(room_info.black_overlay, xx, yy), xx, yy);
            tilemap_set(lava_map, da_grid_get(room_info.lava, xx, yy), xx, yy);
            tilemap_set(dark_lava_map, da_grid_get(room_info.dark_lava, xx, yy), xx, yy);
            tilemap_set(water_map, da_grid_get(room_info.water, xx, yy), xx, yy);
            tilemap_set(dark_water_map, da_grid_get(room_info.dark_water, xx, yy), xx, yy);
            tilemap_set(ground_map, ground_tile, xx, yy);
            tilemap_set(base_map, ground_tile, xx, yy);
            tilemap_set(dark_map, da_grid_get(room_info.ground_dark, xx, yy), xx, yy);
            tilemap_set(bright_map, da_grid_get(room_info.ground_bright, xx, yy), xx, yy);
            tilemap_set(ruins_map, da_grid_get(room_info.ground_ruins, xx, yy), xx, yy);
            tilemap_set(wall_maps[0], wall_tile, xx, yy);
            tilemap_set(wall_maps[1], wall_tile, xx, yy);
            tilemap_set(wall_maps[2], wall_tile, xx, yy);
            tilemap_set(wall_maps[3], wall_tile, xx, yy);
            tilemap_set(number_map, wall_tile, xx, yy);

            //
            var chance = fiddle_get("dungeons/misc/chance_tiles");
            var tile = tilemap_get(chance_map, xx, yy);

            //
            //
            var in_collision = grid.node_collideable[grid.node_index_for_cell(ox, oy)];

            var spawn = tile div 8;
            var bonus_chance = spawn == DungeonSpawn.Chest ? ARI.perk_value(Perk.Treasured) : 0;

            if bonus_chance != 0 {
                GAME_STATS.perks[$ perk_to_string(Perk.Treasured)] += 1;
            }

            if !in_collision && chance_percent(chance[tile % 8] + bonus_chance) {
                switch spawn {
                    case DungeonSpawn.EnemyImplEnemy:
                        if DUNGEON_IMPL != DungeonImpl.Enemy {
                            continue;
                        }
                        spawn = DungeonSpawn.Enemy;
                        break;
                    case DungeonSpawn.MiniBossEnemyImplEnemy:
                        if DUNGEON_IMPL != DungeonImpl.Enemy {
                            continue;
                        }
                        spawn = DungeonSpawn.MiniBossEnemy;
                        break;
                    case DungeonSpawn.VoidRock:
                    case DungeonSpawn.VoidHerb:
                    case DungeonSpawn.VoidPearl:
                        if !requirements_pass(Requirement.HasVoidSight) {
                            continue;
                        }
                        break;
                    default: break;
                }

                var candidate = biome.votes[spawn].get_candidate_votes_at_cell(grid, ox, oy).get_candidate();
                switch spawn {
                    case DungeonSpawn.Enemy:
                    case DungeonSpawn.MiniBossEnemy:
                        spawn_monster((ox + 1) * 8, (oy + 1) * 8, candidate);
                        array_push(GS_MINES_FLOOR.monsters_spawned, monster_id_to_string(candidate));
                        break;
                    case DungeonSpawn.Fish:
                    case DungeonSpawn.VoidPearl:
                        if candidate != undefined {
                            instance_create_depth((ox + 1) * 8, (oy + 1) * 8, 0, obj_fishy).initialise(new Fish(candidate));
                            array_push(GS_MINES_FLOOR.fishes_spawned, fish_id_to_string(candidate));
                        }
                        break;
                    case DungeonSpawn.Bug:
                        instance_create_depth((ox + 1) * 8, (oy + 1) * 8, 0, obj_bug).setup(candidate);
                        array_push(GS_MINES_FLOOR.bugs_spawned, item_id_to_string(candidate));
                        break;
                    case DungeonSpawn.Forageable:
                    case DungeonSpawn.VoidHerb:
                        grid.write_node(ox, oy, candidate, CropFlag.FORAGEABLE | CropFlag.SPAWN_GROWN);
                        array_push(GS_MINES_FLOOR.forageables_spawned, object_id_to_string(candidate));
                        break;
                    case DungeonSpawn.Artifact:
                        grid.write_node(ox, oy, ObjectId.DigSite);
                        GS_MINES_FLOOR.digsites += 1;
                        break;
                    default:
                        assert_neq(candidate, undefined, "Got an undefined candidate for spawn type {DungeonSpawn}", spawn);
                        if object_id_to_object_category(candidate) == ObjectCategory.Rock {
                            array_push(GS_MINES_FLOOR.rocks_spawned, object_id_to_string(candidate));
                        }
                        grid.write_node(ox, oy, candidate);
                        break;
                }
            }
        }
    }
}
