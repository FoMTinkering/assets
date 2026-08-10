#macro PRIORITY_OBJECTS global.__priority_objects
global.__priority_objects = undefined;

#macro PRIORITY_GRASS global.__priority_grass
global.__priority_grass = undefined;

//
function create_priority_objects() {
    var fiddle_priority = fiddle_get("priority_objects");
    var priority_default = fiddle_priority[$ "default"];

    var priority_objects = array_create(168, undefined);

    //
    var names = struct_get_names(fiddle_priority);
    for (var i = 0, c = array_length(names); i < c; i++) {
        var name = names[i];
        if name == "default" {
            continue;
        }

        //
        var obj = clone_value(priority_default);
        patch_object(fiddle_priority[$ name], obj);

        //
        if matches(obj[$ "object_id"], undefined, false) {
            continue;
        }

        obj.object_id = apply_func(obj.object_id, string_to_object_id);

        //
        if is_array(obj.object_id) {
            var category = object_id_to_object_category(obj.object_id[0]);
            for (var j = 0; j < array_length(obj.object_id); j++) {
                var this_cat = object_id_to_object_category(obj.object_id[j]);
                if this_cat != category {
                    crash("proto #{} had variant object category possibility ({ObjectCategory} & {ObjectCategory})", name, category, this_cat)
                }
            }

            //
            obj.category = category;
        } else {
            obj.category = object_id_to_object_category(obj.object_id);
        }

        obj.pos_offset = fiddle_deserialize_vec2(obj.pos_offset);
        obj.variant = fiddle_deserialize_vec2(obj.variant);

        priority_objects[real(name)] = obj;
    }

    return priority_objects;
}

//
function create_priority_grass() {
    var fiddle_priority = fiddle_get("priority_grass");
    var names = struct_get_names(fiddle_priority);
    var priority_grass = array_create(array_length(names), undefined);

    for (var i = 0, c = array_length(names); i < c; i++) {
        var name = names[i];
        priority_grass[real(name)] = string_to_object_id(fiddle_priority[$ name]);
    }

    return priority_grass;
}

function spawn_prios_on_map(grid, room_id, tileset, func, extra_param=false) {
    var prios = room_data_read_tilemap(room_id, tileset);

    //
    for (var i = 0; i < array_length(prios); i++) {
        var val = (prios[i] >> 32) & U32_MAX;
        var cell = prios[i] & U32_MAX;
        func(grid, val, cell % grid.dims.x, cell div grid.dims.x, extra_param);
    }
}

//
//
//
//
//
//
function spawn_priority_object(grid, tile, xx, yy, reset=false) {
    var ni = grid.node_index_for_cell(xx, yy);
    if (tile == undefined || tile == 0) || (reset && has_flag(grid.node_flags[ni], TileFlag.ResistsReset)) {
        return undefined;
    }

    var tile_index = tile;
    var proto = PRIORITY_OBJECTS[tile_index];
    if proto == undefined {
        error("we don't know how to make: {} at {}x{} in {LocationId}", tile_index, xx div 2, yy div 2, grid.location_id);
        return undefined;
    }

    //
    if reset {
        var offset_x = proto.pos_offset.x;
        var offset_y = proto.pos_offset.y;

        //
        if proto.category == ObjectCategory.Tree {
            offset_x += 2;
            offset_y += 2;

            var current_node_present = grid.node_index_for_cell(xx + offset_x, yy + offset_y);
            if object_id_to_object_category(grid.node_object_id[current_node_present]) == ObjectCategory.Stump {
                erase_object_node(grid, current_node_present);
            }
        }

        if grid.node_object_id[grid.node_index_for_cell(xx + offset_x, yy + offset_y)] == proto.object_id {
            return undefined;
        }
    }

    var object_id = proto.object_id;
    var is_farm = false;
    var ctx = undefined;
    switch proto.category {
        case ObjectCategory.Crop:
            var node_check = grid.node_index_for_cell(xx,yy);
            if has_flag(grid.node_flags[node_check], TileFlag.NpcFarm) {
                grid.write_ground(xx, yy, GroundKind.Soil);
                water_chunk(grid, xx, yy);
                is_farm = true;
            }
            ctx = CropFlag.MANAGED | CropFlag.SPAWN_GROWN;
            if has_flag(grid.node_flags[node_check], TileFlag.NpcFarm) {
                ctx |= CropFlag.NO_HARVEST;
                ctx &= ~CropFlag.SPAWN_GROWN;
            }
            break;
        case ObjectCategory.Furniture:
            if object_id == ObjectId.WornChair {
                ctx = furniture_object_cardinal_to_rotation(object_id, Cardinal.West);
            }
            break;
        default:
            //
            break;
    }

    var node = grid.write_node(xx + proto.pos_offset.x, yy + proto.pos_offset.y, object_id, ctx);
    if node == undefined {
        warn("couldn't make {ObjectId}/{} at {}x{} ({}x{}) in {LocationId}", object_id, tile_index, xx + proto.pos_offset.x, yy + proto.pos_offset.y, xx div 2, yy div 2, grid.location_id);
        return undefined;
    }

    if object_id == ObjectId.Campfire || object_id == ObjectId.WornFireplace {
        node.is_on = true;
    }

    if matches(proto.category, ObjectCategory.Tree, ObjectCategory.Breakable, ObjectCategory.Grass, ObjectCategory.Rock) {
        node.variant_idx = irandom_range(proto.variant.x * 100, proto.variant.y * 100 - 1) / 100;
    }

    if proto.category == ObjectCategory.Tree {
        tree_node_initialize_at_stage(grid, node, proto.stage);

        //
        if reset {
            node.has_fruit = false;
        }
        node.override_protection = true;
    }

    if proto.category == ObjectCategory.Crop && node != undefined {
        if has_flag(ctx, CropFlag.SPAWN_GROWN) {
            assert_eq(node.day_count, node.prototype.day_to_stage.count() - 1);
        }

        if is_farm {
            crop_node_new_day(grid, node);
        }
    }

    if proto.journal_on_top {
        var output = grid.write_node(xx + proto.pos_offset.x, yy + proto.pos_offset.y, ObjectId.Journal);
        assert_neq(output, undefined, "We couldn't spawn the journal succesfully.");
        if output == undefined {
            trace("we couldn't write the journal! tried at coord: {}x{}", xx + proto.pos_offset.x + 1, yy + proto.pos_offset.y);
        }
    }

    return node;
}

//
function spawn_priority_grass(grid, tile, xx, yy) {
    if tile == undefined || tile == 0 {
        return undefined;
    }

    var tile_index = tile;
    var target_object_id = PRIORITY_GRASS[tile_index];

    return grid.write_node(xx, yy, target_object_id);
}

function priority_tileset_season(season) {
    switch season {
        case Season.Spring: return "PriorityObjectsSpring";
        case Season.Summer: return "PriorityObjectsSummer";
        case Season.Fall: return "PriorityObjectsFall";
        case Season.Winter: return "PriorityObjectsWinter";
    }
}

function priority_grass_tileset_season(season) {
    switch season {
        case Season.Spring: return "PriorityGrassSpring";
        case Season.Summer: return "PriorityGrassSummer";
        case Season.Fall: return "PriorityGrassFall";
        case Season.Winter: return "PriorityGrassWinter";
    }
}
