#macro NODE_ROOM_START -1

//
enum ToolStatus {
    //
    None,
    //
    Damage,
    //
    Dead,
}

//
//
//
enum RoomEditorCollision {
    //
    None,
    //
    Active,
    //
    Inactive,
}

//
//
function attempt_to_write_object_node(grid, top_left_x, top_left_y, size, prototype, collision, can_overlap_collision=true, target_terrain=TerrainKind.Ground, jumpable=true) {
    //
    if local_pos_is_valid(grid, top_left_x, top_left_y, size) == false {
        return undefined;
    }

    //
    for (var xx = 0; xx < size.x; xx++) {
        for (var yy = 0; yy < size.y; yy++) {
            var ni = grid.node_index_for_cell(top_left_x + xx, top_left_y + yy);

            if can_write_object_on_node(grid, ni, target_terrain, can_overlap_collision) == false {
                return undefined;
            }
        }
    }

    //
    var node = create_parent_object_node(prototype, top_left_x, top_left_y, size);

    //
    for (var xx = 0; xx < size.x; xx++) {
        for (var yy = 0; yy < size.y; yy++) {
            var this_cell_node = grid.node_index_for_cell(top_left_x + xx, top_left_y + yy);

            write_object_inst_node(grid, this_cell_node, node);

            if collision {
                set_collision_on_node(grid, top_left_x + xx, top_left_y + yy, jumpable);
            }
        }
    }

    return node;
}

function local_pos_is_valid(grid, xx, yy, size) {
    return ((xx + size.x - 1) < grid.dims.x)
        && ((yy + size.y - 1) < grid.dims.y)
        && xx >= 0
        && yy >= 0;
}

function can_write_object_on_node(grid, ni, target_terrain, can_overlap_collision=true, can_rug=false, is_rug=false) {
    if is_rug {
        var current_cat = object_id_to_object_category(grid.node_object_id[ni]);
        if grid.node_rug_id[ni] != undefined || (current_cat != undefined && current_cat != ObjectCategory.Furniture) {
            return false;
        }
    } else if grid.node_object_id[ni] != undefined {
        return false;
    }

    return (target_terrain == undefined || grid.node_terrain_kind[ni] == target_terrain)
        && (can_overlap_collision || !grid.node_collideable[ni]) //
        && (can_rug || grid.node_rug_id[ni] == undefined); //
}

function create_parent_object_node(prototype, xx, yy, size) {
    return {
        object_id: prototype.object_id,
        prototype: prototype,
        last_update: NODE_ROOM_START,
        top_left_x: xx,
        top_left_y: yy,
        write_size_x: size.x,
        write_size_y: size.y,
        renderer: undefined,
    }
}

function write_object_inst_node(grid, inst_index, parent_node) {
    grid.node_parent[inst_index] = parent_node;
    grid.node_object_id[inst_index] = parent_node.object_id;

    //
    grid.node_top_left_x[inst_index] = parent_node.top_left_x;
    grid.node_top_left_y[inst_index] = parent_node.top_left_y;
}

//
//
function erase_rug_node(grid, index) {
    if grid.node_rug_id[index] == undefined {
        return false;
    }
    erase_object_renderer(grid.node_rug_parent[index]);

    //
    var node = grid.node_rug_parent[index];
    var _x = node.top_left_x;
    var _y = node.top_left_y;


    //
    if DEBUG_ASSERTIONS {
        assert_eq(object_id_to_object_category(node.object_id), ObjectCategory.Furniture, "only furniture should be a rug!");
    }
    if node.prototype.pet_bed {
        var idx = array_pos(grid.pet_beds, node);
        array_delete(grid.pet_beds, idx, 1);
    }

    for (var xx = 0; xx < node.write_size_x; xx++) {
        for (var yy = 0; yy < node.write_size_y; yy++) {
            var this_cell_node = grid.node_index_for_cell(_x + xx, _y + yy);
            if grid.node_rug_id[this_cell_node] != undefined {
                assert(grid.node_rug_parent[this_cell_node] == node, "we tried to erase object_id {object_id} but we're a different {object_id}", grid.node_object_id[this_cell_node], node.object_id);

                grid.node_rug_parent[this_cell_node] = undefined;
                grid.node_rug_id[this_cell_node] = undefined;
            }
            if grid.node_furniture_footstep[? this_cell_node] != undefined {
                grid.node_furniture_footstep[? this_cell_node] = undefined;
            }
        }
    }

    return true;
}

//
//
function erase_object_node(grid, index) {
    if grid.node_object_id[index] == undefined {
        return false;
    }

    return erase_object_node_by_parent(grid, grid.node_parent[index]);
}

//
//
//
//
function erase_object_node_by_parent(grid, node) {
    erase_object_node_data(grid, node);
    erase_object_renderer(node);

    return true;
}

//
function erase_object_renderer(node) {
    if node.renderer != undefined && instance_is_alive(node.renderer) {
        instance_destroy(node.renderer);
    }

    if object_id_to_object_category(node.object_id) == ObjectCategory.Furniture
        && node.child_grid != undefined
    {
        for (var xx = 0; xx < node.child_grid.dims.x; xx++) {
            for (var yy = 0; yy < node.child_grid.dims.y; yy++) {
                var cell = node.child_grid.node_index_for_cell(xx, yy);
                if node.child_grid.node_object_id[cell] == undefined {
                    continue;
                }
                erase_object_renderer(node.child_grid.node_parent[cell]);
            }
        }
    }
}

//
function erase_object_node_data(grid, node) {
    var _x = node.top_left_x;
    var _y = node.top_left_y;

    var cat = object_id_to_object_category(node.object_id);
    var ladder_candidate = node[$ "ladder_candidate"];

    if grid.location_id == LocationId.Farm
        && grid.parent_node == undefined
        && (GROW_BACK.elligible_objects[node.object_id] || cat == ObjectCategory.Grass)
    {
        var parent_boy = grid.node_index_for_cell(
            (_x div GROW_BACK.cell_size) * GROW_BACK.cell_size,
            (_y div GROW_BACK.cell_size) * GROW_BACK.cell_size
        );
        if cat == ObjectCategory.Grass {
            grid.node_grass_count[? parent_boy] -= 1;
        } else {
            grid.node_colliders_count[? parent_boy] -= 1;
        }
    }

    switch cat {
        case ObjectCategory.Furniture:
            //
            if node.child_grid != undefined {
                for (var xx = 0; xx < node.child_grid.dims.x; xx++) {
                    for (var yy = 0; yy < node.child_grid.dims.y; yy++) {
                        var cell = node.child_grid.node_index_for_cell(xx, yy);
                        if node.child_grid.node_object_id[cell] == undefined {
                            continue;
                        }
                        erase_object_node_data(node.child_grid, node.child_grid.node_parent[cell]);
                    }
                }
                node.child_grid = undefined;
            }

            if node.prototype.sprinkler != undefined {
                var idx = array_pos(grid.sprinklers, node);
                array_delete(grid.sprinklers, idx, 1);
            }

            //
            if node.old_terrain != undefined {
                //
                var idx = array_pos(grid.terrain_editors, node);
                array_delete(grid.terrain_editors, idx, 1);

                furniture_write_old_terrain(grid, _x, _y, node.prototype.size.x, node.prototype.size.y, node.old_terrain);
            }

            //
            if node.prototype.object_id == ObjectId.OcarinaSpriteStatue {
                var dyn_grid = DYNAMIC_GRIDS.get(grid.parent_node.parent_grid.dyn_index);
                dyn_grid.ocarina = undefined;
            }

            //
            if node.prototype.object_id == ObjectId.AutoFeeder {
                var dyn_grid = DYNAMIC_GRIDS.get(grid.parent_node.parent_grid.dyn_index);
                dyn_grid.auto_feeder = undefined;
            }

            if node.prototype.object_id == ObjectId.JunipersProtectionScroll {
                ARI.has_protection_scroll = false;
            }

            if node.prototype.is_crystal_resonator {
                if grid.dyn_index != undefined {
                    ARI.dyn_song_overrides[string(grid.dyn_index)] = undefined;
                } else {
                    ARI.song_overrides[grid.location_id] = undefined;
                }
                if CURRENT_LOCATION_ID == grid.location_id {
                    MUSIC_PLAYER.refresh();
                }
            }

            if node.prototype.pet_bed {
                var idx = array_pos(grid.pet_beds, node);
                array_delete(grid.pet_beds, idx, 1);
            }

            if node.prototype.pet_dish != undefined {
                var idx = array_pos(grid.pet_dishes, node);
                array_delete(grid.pet_dishes, idx, 1);
            }

            if node.prototype.activities != undefined {
                var idx = grid.activity_nodes.find_lazy(node);
                grid.activity_nodes.remove(idx);
            }
            if node.prototype.factory != undefined {
                FACTORIES.remove(FACTORIES.find_lazy(node));
            }
            var pos = STORAGE_NODES.find_lazy(node);
            if pos != undefined {
                for (var i = 0; i < node.inventory.size(); i++) {
                    var items = node.inventory.slot(i).drain();
                    if !items.is_empty() {
                        if CURRENT_LOCATION_ID == grid.location_id {
                            //
                            var max_parent = node;
                            var g = grid;
                            while g != undefined && g.parent_node != undefined {
                                max_parent = g.parent_node;
                                g = max_parent[$ "parent_grid"];
                            };

                            var live_item = drop_item_to_ground(
                                max_parent.renderer.x,
                                max_parent.renderer.y + 1,
                                node.renderer.y - max_parent.renderer.y,
                            );
                            var random_offsets = drop_item_random_dir_distance();
                            live_item.final_x = live_item.x + random_offsets[0];
                            live_item.final_y = live_item.y + random_offsets[1];

                            live_item.setup(items);
                        } else {
                            //
                            grid.lost_items.push({
                                x: node.top_left_x * 8 + (node.write_size_x * 4),
                                y: node.top_left_y * 8 + (node.write_size_y * 4),
                                items,
                            });
                        }
                    }
                }

                STORAGE_NODES.remove(pos);
            }

            //
            if node.prototype.house_stairs != undefined && IN_HOUSE_STAIR_SEGMENT == false {
                STAIR_COUNT = max(STAIR_COUNT - 1, 0);
                IN_HOUSE_STAIR_SEGMENT = true;
                var corresponding_room = get_house_corresponding_room(grid.location_id);
                erase_object_node(GRIDS[corresponding_room], GRIDS[corresponding_room].node_index_for_cell(_x, _y));
                IN_HOUSE_STAIR_SEGMENT = false;
            }

            if node.prototype.window_tiles != undefined {
                var pos = array_pos(WINDOWS, node);
                array_delete(WINDOWS, pos, 1);

                for (var xx = 0; xx < ds_grid_width(node.prototype.window_tiles); xx++) {
                    for (var yy = 0; yy < ds_grid_height(node.prototype.window_tiles); yy++) {
                        if node.prototype.window_tiles[# xx, yy] {
                            obj_exterior_window_interior.windows[# node.top_left_x + xx, node.top_left_y + yy] = false;
                        }
                    }
                }
            }

            //
            for (var i = 0; i < NpcId.LEN; i++) {
                var npc = NPCS[i];
                if npc.activity_handler.target_node == node {
                    npc.activity_handler.clear_activity();
                    npc.set_animation("idle");
                    with npc_id_to_gm_obj_id(i) {
                        self.bark_emitter.emit(BarkId.Annoyed, BarkType.Thought);
                    }
                }
            }
            break;
        case ObjectCategory.Building:
            //
            DYNAMIC_GRIDS.set(node.dyn_index, undefined);
            global.__buildings = undefined;
            break;
        default:break;
    }

    for (var xx = 0; xx < node.write_size_x; xx++) {
        for (var yy = 0; yy < node.write_size_y; yy++) {
            if cat == ObjectCategory.Tree && matches(xx, 0, 1, 4, 5) && matches(yy, 0, 1, 4, 5) {
                continue;
            }

            remove_collision_on_node(grid, _x + xx, _y + yy);

            var this_cell_node = grid.node_index_for_cell(_x + xx, _y + yy);

            if grid.node_furniture_footstep[? this_cell_node] != undefined {
                grid.node_furniture_footstep[? this_cell_node] = undefined;
            }

            if grid.node_object_id[this_cell_node] != undefined {
                assert(grid.node_parent[this_cell_node] == node, "we tried to erase object_id {object_id} but we're a different {object_id}", grid.node_object_id[this_cell_node], node.object_id);

                grid.node_parent[this_cell_node] = undefined;
                grid.node_object_id[this_cell_node] = undefined;
                grid.node_top_left_x[this_cell_node] = undefined;
                grid.node_top_left_y[this_cell_node] = undefined;
            }
        }
    }

    //
    if cat == ObjectCategory.Furniture && node.prototype.fence {
        auto_tile_fence(grid, _x, _y - 2);
        auto_tile_fence(grid, _x, _y + 2);
        auto_tile_fence(grid, _x - 2, _y);
        auto_tile_fence(grid, _x + 2, _y);
    }

    if grid.location_id == LocationId.Dungeon
        && (cat == ObjectCategory.Rock || cat == ObjectCategory.Breakable)
        && ladder_candidate
    {
        DUNGEON_RUNNER.on_object_destroy(_x, _y);
    }

    //
    if node.object_id == ObjectId.TreePineSpecial {
        set_collision_on_node_region(grid, node.top_left_x + 2, node.top_left_y, node.top_left_x + 3, node.top_left_y, false);
    }
}

//
function set_collision_on_node_region(grid, xx1, yy1, xx2, yy2, can_jump_over = false) {
    for (var xx = xx1; xx <= xx2; xx++) {
        for (var yy = yy1; yy <= yy2; yy++) {
            set_collision_on_node(grid, xx, yy, can_jump_over);
        }
    }
}

//
//
//
//
//
function set_collision_on_node(grid, xx, yy, can_jump_over=false, set_on_pathfinding=true) {
    var ni = grid.node_index_for_cell(xx, yy);
    if grid.node_is_room_editor_collision[ni] == RoomEditorCollision.Active {
        return;
    }
    grid.node_collideable[ni] = true;
    grid.node_can_jump_over[ni] = can_jump_over;

    if grid.is_setup && grid.location_id == CURRENT_LOCATION_ID && set_on_pathfinding {
        PATHFINDING.set_local_position_is_taken(
            xx,
            yy,
            true,
        );
    }
}

//
function remove_collision_on_node_region(grid, xx1, yy1, xx2, yy2) {
    for (var xx = xx1; xx <= xx2; xx++) {
        for (var yy = yy1; yy <= yy2; yy++) {
            remove_collision_on_node(grid, xx, yy);
        }
    }
}

//
//
function remove_collision_on_node(grid, xx, yy) {
    var ni = grid.node_index_for_cell(xx, yy);
    switch grid.node_is_room_editor_collision[ni] {
        case RoomEditorCollision.None:
            grid.node_collideable[ni] = false;
            grid.node_can_jump_over[ni] = undefined;
            grid.node_pathfinding_sitting[ni] = undefined;

            if grid.is_setup && grid.location_id == CURRENT_LOCATION_ID {
                PATHFINDING.set_local_position_is_taken(
                    xx,
                    yy,
                    false,
                );
            }
            break;
        case RoomEditorCollision.Active:
            //
            return;
        case RoomEditorCollision.Inactive:
            //
            grid.node_is_room_editor_collision[ni] = RoomEditorCollision.Active;
            assert_eq(grid.parent_node, undefined, "How could a RoomEditorCollision have been present on a child node?");

            //
            var room_id = location_id_to_gm_room(CURRENT_LOCATION_ID);

            grid.node_collideable[ni] = room_data_read_cell(room_id, xx, yy, CellDataRequest.Collideable);
            grid.node_can_jump_over[ni] = room_data_read_cell(room_id, xx, yy, CellDataRequest.CanJumpOver);
            grid.node_pathfinding_sitting[ni] = room_data_read_cell(room_id, xx, yy, CellDataRequest.PathfindingSitting);

            if grid.is_setup && grid.location_id == CURRENT_LOCATION_ID {
                var is_taken = false;
                if grid.node_collideable[ni] {
                    is_taken = true;
                }
                if grid.node_pathfinding_sitting[ni] {
                    is_taken = false;
                }
                PATHFINDING.set_local_position_is_taken(
                    xx,
                    yy,
                    is_taken,
                );

                var value = grid.node_pathfinding_cost[ni];
                if value != undefined  && value != 0 {
                    PATHFINDING.set_local_position_cost(xx, yy, value);
                }
            }
            break;
    }
}

//
function create_node_renderer(_x, _y, _node, _spr, _depth_offset=0, _explicit_shadow_grid=undefined) {
    var renderer = instance_create_layer(
        _x,
        _y,
        "Instances",
        obj_node_renderer
    );

    renderer.init(_node, _spr, _depth_offset, _explicit_shadow_grid);

    return renderer;
}

//
function parse_collision_strings(size, f_col_grid, obj_id) {
    //
    //
    //
    //
    //
    //

    var o = ds_grid_create(size.x, size.y);
    if f_col_grid == undefined {
        ds_grid_set_region(o, 0, 0, size.x - 1, size.y - 1, 1);
    } else if is_string(f_col_grid) {
        ds_grid_set_region(o, 0, 0, size.x - 1, size.y - 1, collision_string_to_value(string_char_at(f_col_grid, 1)));
    } else {
        assert_eq(array_length(f_col_grid), size.y, "collision_grid height mismatch ({} != {}) for {ObjectId}", array_length(f_col_grid), size.y, obj_id);
        for (var j = 0; j < size.y; j ++) {
            var str_seq = f_col_grid[j];
            assert_eq(string_length(str_seq), size.x, "collision_grid width mismatch ({} != {}) for {ObjectId}", string_length(str_seq), size.x, obj_id);
            for (var i = 0; i < size.x; i ++) {
                o[# i, j] = collision_string_to_value(string_char_at(str_seq, i + 1));
            }
        }
    }

    return o;
}

function collision_string_to_value(chr) {
    if chr == "-" {
        return -1;
    } else {
        return real(chr);
    }
}

function set_collision_grid_flag_on_node(grid, col_flag, xx, yy) {
    //
    //
    //
    //
    //
    //

    if col_flag == 0 {
        grid.node_pathfinding_sitting[grid.node_index_for_cell(xx, yy)] = false;
    } else if col_flag == -1 {
        var ni = grid.node_index_for_cell(xx, yy);
        //
        var should_evil = grid.node_is_room_editor_collision[ni] == RoomEditorCollision.Active;
        if should_evil {
            grid.node_is_room_editor_collision[ni] = RoomEditorCollision.None;
        }
        remove_collision_on_node(grid, xx, yy);
        if should_evil {
            grid.node_is_room_editor_collision[ni] = RoomEditorCollision.Inactive;
        }
    } else {
        set_collision_on_node(grid, xx, yy, col_flag == 1 || col_flag == 3, col_flag < 3);

        if col_flag >= 3 {
            grid.node_pathfinding_sitting[grid.node_index_for_cell(xx, yy)] = true;
        }
    }
}

function parse_rule_strings(size, f_rule_grid, obj_id) {
    var flag_rule = tile_rule_to_tile_flag(TileRule.PlayerDecoration);
    var rule_grid = ds_grid_create(size.x, size.y);
    if f_rule_grid == undefined {
        ds_grid_set_region(rule_grid, 0, 0, size.x - 1, size.y - 1, flag_rule);
    } else if is_string(f_rule_grid) {
        switch string_char_at(f_rule_grid, 1) {
            case "F":
                flag_rule = tile_rule_to_tile_flag(TileRule.PlayerDecoration);
                break;
            case "W":
                flag_rule = tile_rule_to_tile_flag(TileRule.PlaceableWall);
                break;
            case "A":
                //
                flag_rule = TileFlag.None;
                break;
            default:
                crash("Unexpected flag_rule token '{}' for {ObjectId}", chr_token, obj_id);
        }

        ds_grid_set_region(rule_grid, 0, 0, size.x - 1, size.y - 1, flag_rule);
    } else {
        assert_eq(array_length(f_rule_grid), size.y, "rule_grid height mismatch ({} != {}) for {ObjectId}", array_length(f_rule_grid), size.y, obj_id);
        for (var j = 0; j < size.y; j ++) {
            var str_seq = f_rule_grid[j];
            assert_eq(string_length(str_seq), size.x, "rule_grid width mismatch ({} != {}) for {ObjectId}", string_length(str_seq), size.x, obj_id);
            for (var i = 0; i < size.x; i ++) {
                var chr_token = string_char_at(str_seq, i + 1);
                switch chr_token {
                    case "F":
                        flag_rule = tile_rule_to_tile_flag(TileRule.PlayerDecoration);
                        break;
                    case "W":
                        flag_rule = tile_rule_to_tile_flag(TileRule.PlaceableWall);
                        break;
                    case "A":
                        //
                        flag_rule = TileFlag.None;
                        break;
                    default:
                        crash("Unexpected flag_rule token '{}' for {ObjectId}", chr_token, obj_id);
                }
                rule_grid[# i, j] = flag_rule;
            }
        }
    }

    return rule_grid;
}

function parse_terrain_grid(size, f_terrain_grid, obj_id) {
    var terrain_grid = ds_grid_create(size.x, size.y);

    if is_string(f_terrain_grid) {
        var terrain_kind;
        switch string_char_at(f_terrain_grid, 1) {
            case "G":
                terrain_kind = TerrainKind.Ground;
                break;
            case "W":
                terrain_kind = TerrainKind.Water;
                break;
            default: crash("Unexpected terrain_kind token '{}' for {ObjectId}", chr_token, obj_id);
        }

        ds_grid_set_region(terrain_grid, 0, 0, size.x - 1, size.y - 1, terrain_kind);
    } else {
        assert_eq(array_length(f_terrain_grid), size.y, "terrain_grid height mismatch ({} != {}) for {ObjectId}", array_length(f_terrain_grid), size.y, obj_id);
        for (var j = 0; j < size.y; j ++) {
            var str_seq = f_terrain_grid[j];
            assert_eq(string_length(str_seq), size.x, "terrain_grid width mismatch ({} != {}) for {ObjectId}", string_length(str_seq), size.x, obj_id);
            for (var i = 0; i < size.x; i ++) {
                var chr_token = string_char_at(str_seq, i + 1);
                var terrain_kind;
                switch chr_token {
                    case "G":
                        terrain_kind = TerrainKind.Ground;
                        break;
                    case "W":
                        terrain_kind = TerrainKind.Water;
                        break;
                    case "I":
                        terrain_kind = undefined;
                        break;
                    default: crash("Unexpected terrain_kind token '{}' for {ObjectId}", chr_token, obj_id);
                }
                terrain_grid[# i, j] = terrain_kind;
            }
        }
    }

    return terrain_grid;
}


//
function nearest_node_renderer(is_acceptable_node) {
    var current_distance = infinity;
    var current_candidate = undefined;
    with obj_node_renderer {
        if is_acceptable_node(self.object_id) == false {
                continue;
            }
        var dist = distance_to_object(other);
        if dist < current_distance {
            current_candidate = self;
            current_distance = dist;
        }
    }

    return current_candidate;
}

//
function poof_furniture_to_items(lost_items_list, lost_items_x, lost_items_y, grid, xx0, yy0, xx1, yy1) {
    for (var xx = xx0; xx < xx1; xx++) {
        for (var yy = yy0; yy < yy1; yy++) {
            var ni = grid.try_node_index_for_cell(xx, yy);
            if ni != undefined
                && object_id_to_object_category(grid.node_object_id[ni]) == ObjectCategory.Furniture
            {
                var old_item = find_item_prototype(grid.node_object_id[ni]);
                if old_item != undefined {
                    var item = new LiveItem(old_item.item_id);
                    if item.infusion == undefined {
                        item.infusion = try_string_to_infusion(grid.node_parent[ni].infusion);
                    }
                    lost_items_list.push({
                        x: lost_items_x,
                        y: lost_items_y,
                        items: List(item),
                    });
                }

                var node = grid.node_parent[ni];

                if node.prototype.essence_machine != undefined && node.essence_supply > 0 {
                    drop_item(essence_get_change(node), lost_items_x, lost_items_y);
                }

                if node.child_grid != undefined {
                    poof_furniture_to_items(
                        lost_items_list,
                        lost_items_x,
                        lost_items_y,
                        node.child_grid,
                        0,
                        0,
                        node.child_grid.dims.x,
                        node.child_grid.dims.y
                    );
                }

                erase_object_node(grid, ni);
            }
        }
    }
}

function get_house_corresponding_room(location_id) {
    switch location_id {
        case LocationId.PlayerHome:
            return LocationId.PlayerHomeUpperCentral;
        case LocationId.PlayerHomeWest:
            return LocationId.PlayerHomeUpperWest;
        case LocationId.PlayerHomeEast:
            return LocationId.PlayerHomeUpperEast;
        case LocationId.PlayerHomeUpperCentral:
            return LocationId.PlayerHome;
        case LocationId.PlayerHomeUpperWest:
            return LocationId.PlayerHomeWest;
        case LocationId.PlayerHomeUpperEast:
            return LocationId.PlayerHomeEast;
    }

    //
    return undefined;
}

function is_house_upper_floor(location_id) {
    return location_id == LocationId.PlayerHomeUpperCentral
        || location_id == LocationId.PlayerHomeUpperEast
        || location_id == LocationId.PlayerHomeUpperWest;
}
