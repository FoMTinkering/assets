#macro BLUEPRINT_PROTOTYPES global.__blueprints
global.__blueprints = undefined;

function create_blueprint_prototypes() {
    var output = array_create(Blueprint.LEN, undefined);

    for (var blueprint_id = 0; blueprint_id < Blueprint.LEN; blueprint_id++) {
        var fiddle_obj = fiddle_get(format("blueprints/{Blueprint}", blueprint_id));
        var size = fiddle_deserialize_vec2(fiddle_obj.size);

        //
        var turn_in_box_recipe = {};
        var keys = struct_get_names(fiddle_obj.turn_in_box_recipe);
        for (var kk = 0; kk < array_length(keys); kk++) {
            var item_id = string_to_item_id(keys[kk]);
            var count = fiddle_obj.turn_in_box_recipe[$ keys[kk]];
            assert(is_real(count));

            turn_in_box_recipe[$ item_id] = count;
        }

        output[blueprint_id] = {
            blueprint_id,
            size,
            building_on_finish: opt_and_then(fiddle_obj[$ "building_on_finish"], string_to_object_id),
            collision_grid: parse_collision_strings(size, fiddle_obj[$ "collision_grid"]),
            rule_grid: parse_rule_strings(size, fiddle_obj[$ "rule_grid"]),
            turn_in_box_recipe,
            objects: array_map(fiddle_obj.objects, function(obj) {
                return {
                    pos: fiddle_deserialize_vec2(obj.pos),
                    object_id: string_to_object_id(obj.object_id),
                    parameters: obj[$ "parameters"],
                }
            })
        };
    }

    return output;
}

function can_write_blueprint(grid, xx, yy, proto) {
    //
    if grid.parent_node != undefined {
        return false;
    }

    //
    if local_pos_is_valid(grid, xx, yy, proto.size) == false {
        return false;
    }

    if collision_rectangle(
        xx * 8,
        yy * 8,
        (xx + proto.size.x) * 8,
        (yy + proto.size.y) * 8,
        [obj_ari, obj_player_animal, obj_pet],
    ) != undefined {
        return false;
    }

    //
    for (var x_off = 0; x_off < proto.size.x; x_off++) {
        for (var y_off = 0; y_off < proto.size.y; y_off++) {
            var ni = grid.node_index_for_cell(xx + x_off, yy + y_off);
            if can_write_object_on_node(grid, ni, TerrainKind.Ground) == false {
                return false;
            }

            if grid.tile_flag_satisfies_node(ni, proto.rule_grid[# x_off, y_off]) == false {
                return false;
            }
        }
    }

    return true;
}

//
function write_blueprint_to_location(grid, xx, yy, blueprint_id, item_id) {
    var proto = BLUEPRINT_PROTOTYPES[blueprint_id];

    if can_write_blueprint(grid, xx, yy, proto) == false {
        return false;
    }

    //
    for (var x_off = 0; x_off < proto.size.x; x_off++) {
        for (var y_off = 0; y_off < proto.size.y; y_off++) {
            var col_flag = proto.collision_grid[# x_off, y_off];
            if col_flag != 0 {
                set_collision_on_node(grid, xx + x_off, yy + y_off, col_flag == 1);
            }
        }
    }

    var blueprint_fingerprint = int64(irandom(I32_MAX));
    for (var i = 0; i < array_length(proto.objects); i++) {
        var obj = proto.objects[i];

        var output = grid.write_node(xx + obj.pos.x, yy + obj.pos.y, obj.object_id, 0);
        if output == undefined {
            error(
                "failed to write `{ObjectId}` @ `{}x{}` (blueprint relative offset: {}x{}).",
                obj.object_id,
                xx + obj.pos.x,
                yy + obj.pos.y,
                obj.pos.x,
                obj.pos.y,
            );

            var maybe_object = GRID.try_node_index_for_cell(xx + obj.pos.x, yy + obj.pos.y);
            if maybe_object == undefined {
                error("no object can be written at that coordinate (it's off the map).");
            } else {
                if GRID.node_object_id[maybe_object] != undefined {
                    error("another object in the blueprint was ALREADY made there: `{ObjectId}`", GRID.node_object_id[maybe_object]);
                } else {
                    error("no object there though");
                }
                error("terrain = {TerrainKind}", GRID.node_terrain_kind[maybe_object]);
            }

            crash("we failed to write blueprint `{Blueprint}`", proto.blueprint_id);
        }

        //
        output.blueprint_top_left_x = xx;
        output.blueprint_top_left_y = yy;
        output.blueprint_id = proto.blueprint_id;
        output.blueprint_fingerprint = blueprint_fingerprint;
        output.blueprint_spawner = item_id;

        if grid.location_id == CURRENT_LOCATION_ID
            && output.renderer.shadow_caster != undefined
        {
            output.renderer.set_sprite(output.renderer.sprite_index);
        }

        if obj.parameters != undefined {
            var keys = struct_get_names(obj.parameters);
            for (var kk = 0; kk < array_length(keys); kk++) {
                output[$ keys[kk]] = clone_value(obj.parameters[$ keys[kk]]);
            }
        }

        //
        if object_id_to_object_category(obj.object_id) == ObjectCategory.Furniture
            && NODE_PROTOTYPES[obj.object_id].fence
        {
            autotile_furniture_fence_node(GRID, output);
        }
    }

    //
    for (var x_off = 0; x_off < proto.size.x; x_off++) {
        for (var y_off = 0; y_off < proto.size.y; y_off++) {
            grid.write_node(xx + x_off, yy + y_off, ObjectId.BlueprintFiller);
        }
    }

    return true;
}

//
function remove_blueprint_from_location(grid, bp_tl_x, bp_tl_y, blueprint_id) {
    var blueprint_prototype = BLUEPRINT_PROTOTYPES[blueprint_id];

    for (var xx = 0; xx < blueprint_prototype.size.x; xx++) {
        for (var yy = 0; yy < blueprint_prototype.size.y; yy++) {
            erase_object_node(grid, grid.node_index_for_cell(xx + bp_tl_x, yy + bp_tl_y));

            //
            remove_collision_on_node(grid, xx + bp_tl_x, yy + bp_tl_y);
        }
    }

    //
    for (var xx = 0; xx < blueprint_prototype.size.x; xx++) {
        for (var yy = 0; yy < blueprint_prototype.size.y; yy++) {
            erase_rug_node(grid, grid.node_index_for_cell(xx + bp_tl_x, yy + bp_tl_y));
        }
    }

    //
    return blueprint_prototype.building_on_finish;
}

//
function stable_crafting_table_node_get_turn_in_box(node) {
    var other_pos_x = node.top_left_x + node.turn_in_box_offset_x;
    var other_pos_y = node.top_left_y + node.turn_in_box_offset_y;
    var turn_in_box = GRID.node_index_for_cell(other_pos_x, other_pos_y);
    assert_eq(GRID.node_object_id[turn_in_box], ObjectId.TurnInBox);

    return GRID.node_parent[turn_in_box];
}
