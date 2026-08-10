//
enum PlayerBuildingKind {
    Stable,
    Greenhouse,
    MiniMuseum,
}

function create_building_prototype(object_id, fiddle_obj) {
    var size = fiddle_deserialize_vec2(fiddle_obj.size);
    var prototype = {
        object_id: object_id,
        name: fiddle_obj.name,
        location_id: string_to_location_id(fiddle_obj.location_id),
        size,
        collision_grid: parse_collision_strings(size, fiddle_obj[$ "collision_grid"]),
        farm_plate: {
            sprite: string_to_asset(fiddle_obj.farm_plate.sprite),
            offset: fiddle_deserialize_vec2(fiddle_obj.farm_plate.offset),
        },
        offset: fiddle_deserialize_vec2(fiddle_obj.offset),

        entrance_offset: fiddle_deserialize_vec2(fiddle_obj.entrance_offset),
        door_hides_on_open: fiddle_obj.door_hides_on_open,
        door_offset: fiddle_deserialize_vec2(fiddle_obj.door_offset),
        transition_offset: fiddle_deserialize_vec2(fiddle_obj.transition_offset),
        light_bottom_offset: fiddle_deserialize_vec2(fiddle_obj.light_bottom_offset),
        light_top_offset: fiddle_deserialize_vec2(fiddle_obj.light_top_offset),
        open_door: fiddle_obj.open_door,

        door_closed: array_map(fiddle_obj.door_closed, string_to_asset),
        doorway_floor: array_map(fiddle_obj.doorway_floor, string_to_asset),

        blueprints: array_map(fiddle_obj.blueprints, string_to_item_id),
        sprites: fiddle_deserialize_season(
            fiddle_obj.sprites,
            function(sprite_array) {
                return array_map(sprite_array, string_to_asset);
            },
        ),
        tilesets: array_map(fiddle_obj[$ "tilesets"] ?? [], string_to_asset),
        ramps: opt_and_then(fiddle_obj[$ "ramps"], function(ramp) { return array_map(ramp, string_to_asset) }),
        ramp_offset: opt_and_then(fiddle_obj[$ "ramp_offset"], fiddle_deserialize_vec2),
        transparency_boxes: parse_transparency_boxes(fiddle_obj.transparency_boxes),
    };

    if fiddle_obj[$ "stable"] != undefined {
        prototype.max_occupants = fiddle_obj.stable.max_occupants;
        prototype.permitted_animal_size = string_to_animal_size(fiddle_obj.stable.permitted_animal_size);
        prototype.stall_points = List();
        prototype.incubators = fiddle_obj.stable.incubators;
        prototype.double_manger = fiddle_obj.stable.double_manger;
        prototype.manger_size = fiddle_obj.stable.manger_size;
        prototype.farm_bell = {
            idle: string_to_asset(fiddle_obj.stable.farm_bell.idle),
            ring: string_to_asset(fiddle_obj.stable.farm_bell.ring),
            offset: fiddle_deserialize_vec2(fiddle_obj.stable.farm_bell.offset)
        };
        prototype.send_animal_in_offset = fiddle_deserialize_vec2(fiddle_obj.stable.send_animal_in_offset);
        prototype.send_animal_out_offset = fiddle_deserialize_vec2(fiddle_obj.stable.send_animal_out_offset);
        prototype.exit_direction = string_to_cardinal(fiddle_obj.stable.exit_direction);
        prototype.animal_door_point = fiddle_obj.stable.animal_door_point;

        //
        for (var i = 0; i < prototype.max_occupants; i++) {
            prototype.stall_points.push(format("{LocationId}/stall_{}", prototype.location_id, i));
        }

        prototype.player_building_kind = PlayerBuildingKind.Stable;
    } else if fiddle_obj[$ "greenhouse"] != undefined {
        prototype.crop_area_start = fiddle_deserialize_vec2(fiddle_obj.greenhouse.crop_area_start);
        prototype.crop_area_end = fiddle_deserialize_vec2(fiddle_obj.greenhouse.crop_area_end);

        //
        prototype.player_building_kind = PlayerBuildingKind.Greenhouse;
    } else if fiddle_obj[$ "mini_museum"] != undefined {
        prototype.player_building_kind = PlayerBuildingKind.MiniMuseum;
    } else {
        crash("building `{ObjectId}` must have table `stable` or `greenhouse` or `mini_museum`", object_id);
    }

    return prototype;
}

function can_write_building(grid, top_left_x, top_left_y, proto, care_about_ari=true) {
    //
    if local_pos_is_valid(grid, top_left_x, top_left_y, proto.size) == false {
        return false;
    }

    var aris_position_x;
    var aris_position_y;

    if instance_exists(obj_ari) && care_about_ari {
        aris_position_x = obj_ari.x div 8;
        aris_position_y = obj_ari.y div 8;
    } else {
        aris_position_x = -infinity;
        aris_position_y = -infinity;
    }

    //
    for (var xx = 0; xx < proto.size.x; xx++) {
        for (var yy = 0; yy < proto.size.y; yy++) {
            var ni = grid.node_index_for_cell(top_left_x + xx, top_left_y + yy);

            var on_ari = (top_left_x + xx) == aris_position_x && (top_left_y + yy) == aris_position_y;

            if on_ari || can_write_object_on_node(grid, ni, TerrainKind.Ground) == false {
                return false;
            }
        }
    }

    return true;
}

function write_building_to_location(grid, xx, yy, proto, ctx) {
    if can_write_building(grid, xx, yy, proto, false) == false {
        return undefined;
    }

    var node = attempt_to_write_object_node(grid, xx, yy, proto.size, proto, false);
    if node == undefined {
        return undefined;
    }

    //
    var variant;
    var dyn_index;
    if is_struct(ctx) {
        variant = ctx.variant;
        dyn_index = ctx.dyn_index;
    } else {
        variant = ctx;

        //
        //
        var dynamic_grid = reserve_dynamic_room(proto.location_id);
        dyn_index = dynamic_grid.dyn_index;
        push_dynamic_room(dynamic_grid);
    }

    //
    for (var x_off = 0; x_off < proto.size.x; x_off++) {
        for (var y_off = 0; y_off < proto.size.y; y_off++) {
            var col_flag = proto.collision_grid[# x_off, y_off];
            set_collision_grid_flag_on_node(grid, col_flag, xx + x_off, yy + y_off);
        }
    }

    node.name = local_get(node.prototype.name);
    node.variant = variant;
    node.dyn_index = dyn_index;

    switch node.prototype.player_building_kind {
        case PlayerBuildingKind.Stable:
            node.stable = new Stable(node);
            break;
        case PlayerBuildingKind.Greenhouse:
            node.stable = undefined;

            //
            var my_grid = DYNAMIC_GRIDS.get(dyn_index);
            my_grid.is_setup = false;

            //
            for (var grid_xx = 0; grid_xx < my_grid.dims.x; grid_xx+=2) {
                for (var grid_yy = 0; grid_yy < my_grid.dims.y; grid_yy+=2) {
                    my_grid.write_ground(grid_xx, grid_yy, GroundKind.RiverBank);
                }
            }

            //
            for (var grid_xx = node.prototype.crop_area_start.x; grid_xx < node.prototype.crop_area_end.x; grid_xx+=2) {
                for (var grid_yy = node.prototype.crop_area_start.y; grid_yy < node.prototype.crop_area_end.y; grid_yy+=2) {
                    my_grid.write_ground(grid_xx, grid_yy, GroundKind.Soil);
                }
            }
            my_grid.is_setup = true;

            //
            //
            //
            //
            //
            node.greenhouse_watered_positions = undefined;

            break;
        case PlayerBuildingKind.MiniMuseum:
            node.stable = undefined;
            break;
    }

    //
    global.__buildings = undefined;

    return node;
}

function create_building_renderer(node) {
    var xx = node.top_left_x * 8 + node.prototype.offset.x;
    var yy = node.top_left_y * 8 + node.prototype.offset.y;

    //
    var r = create_node_renderer(
        xx,
        yy,
        node,
        node.prototype.sprites[CALENDAR.season()][node.variant],
    );

    var targets_to_destroy = List();

    //
    {
        var transition = instance_create_depth(xx + node.prototype.transition_offset.x, yy + node.prototype.transition_offset.y, 0, obj_roomtransition);
        //
        transition.image_xscale = sprite_get_width(node.prototype.door_closed[node.variant]) > 32 ? 2 : 1;
        transition.visible = false;

        //
        transition.destination_id = node.prototype.location_id;

        if array_length(node.prototype.tilesets) != 0 {
            transition.tileset = node.prototype.tilesets[node.variant];
        }

        transition.dyn_index = node.dyn_index;

        targets_to_destroy.push(transition);
    }

    //
    {
        var door = instance_create_depth(
            xx + node.prototype.door_offset.x,
            yy + node.prototype.door_offset.y,
            r.depth,
            obj_door,
            {
                sprite_index: node.prototype.door_closed[node.variant],
                door_hides_on_open: node.prototype.door_hides_on_open,
                stable_door: true,
            }
        );
        door.fade = node.prototype.player_building_kind != PlayerBuildingKind.Stable
            || node.prototype.ramps != undefined;
        door.setup_floor_shadow(node.prototype.doorway_floor[node.variant]);
        door.visible = false;
        door.floor_sprite.visible = false;
        door.floor_sprite.depth = get_shadow_depth();
        door.doorway_light_bottom.visible = false;
        door.doorway_light_top.visible = false;

        r.door = door;
        targets_to_destroy.push(door);
    }

    if node.prototype.player_building_kind == PlayerBuildingKind.Stable {
        if node.prototype.ramps != undefined {
            var ramp = instance_create_layer(
                xx + node.prototype.ramp_offset.x,
                yy + node.prototype.ramp_offset.y,
                "Instances",
                obj_assetobject,
                {
                    sprite_index: node.prototype.ramps[node.variant],
                }
            );
            r.ramp = ramp;
            targets_to_destroy.push(ramp);
        }

        //
        var farm_bell = instance_create_layer(
            xx + node.prototype.farm_bell.offset.x,
            yy + node.prototype.farm_bell.offset.y,
            "Instances",
            obj_farm_bell,
            {
                node,
                sprite_index: node.prototype.farm_bell.idle,
                idle_sprite: node.prototype.farm_bell.idle,
                ringing_sprite: node.prototype.farm_bell.ring,
                visible: false,
            }
        );
        farm_bell.visible = false;
        r.farm_bell = farm_bell;
        targets_to_destroy.push(farm_bell);
    }

    var farm_plate = instance_create_layer(
        xx + node.prototype.farm_plate.offset.x,
        yy + node.prototype.farm_plate.offset.y,
        "Instances",
        obj_farm_plate,
        {
            node,
            sprite_index: node.prototype.farm_plate.sprite,
            visible: false,
        }
    );
    r.farm_plate = farm_plate;
    targets_to_destroy.push(farm_plate);

    r.draw_func = method(r, function(flag) {
        if flag == NodeDrawFlag.EMPTY {
            gpu_set_depth_test(cmpfunc_lessequal);
        }

        self.door.image_alpha = self.image_alpha;
        self.farm_plate.image_alpha = self.image_alpha;
        self.door.floor_sprite.image_alpha = self.image_alpha;

        //
        self.door.doorway_light_bottom.image_alpha = self.image_alpha * 0.5;
        self.door.doorway_light_top.image_alpha = self.image_alpha * 0.5;

        var old_depth = gpu_get_depth();
        with self.door {
            gpu_set_depth(self.depth);
            if flag == NodeDrawFlag.EMPTY {
                //
                //
                object_event(self.object_index, ObjectEvent.Draw)();
            } else {
                draw_self();
            }
        }

        with self.farm_plate {
            gpu_set_depth(self.depth);
            if flag == NodeDrawFlag.EMPTY {
                object_event(self.object_index, ObjectEvent.Draw)();
            } else {
                draw_self();
            }
        }

        if self[$ "farm_bell"] != undefined {
            self.farm_bell.image_alpha = self.image_alpha;
            with self.farm_bell {
                gpu_set_depth(self.depth);
                if flag == NodeDrawFlag.EMPTY {
                    object_event(self.object_index, ObjectEvent.Draw)();
                } else {
                    draw_self();
                }
            }
        }
        if self[$ "ramp"] != undefined {
            self.ramp.image_alpha = self.image_alpha;
            with self.ramp {
                gpu_set_depth(self.depth);
                draw_self();
            }
        }
        with self.door.floor_sprite {
            gpu_set_depth(self.depth);
            draw_self();
        }

        gpu_set_depth_test(cmpfunc_lessequal, false);
        with self.door.doorway_light_bottom {
            gpu_set_depth(self.depth);
            draw_self();
        }

        with self.door.doorway_light_top {
            gpu_set_depth(self.depth + 1.0);
            draw_self();
        }
        gpu_set_depth_test(cmpfunc_always, true);
        gpu_set_depth(old_depth);
    });

    r.targets_to_destroy = targets_to_destroy;
    node.renderer = r;

    for (var i = 0; i < array_length(node.prototype.transparency_boxes); i++) {
        var transparency_box = node.prototype.transparency_boxes[i];
        //
        //
        //
        instance_create_depth(
            node.top_left_x * 8 + transparency_box.offset.x,
            node.top_left_y * 8 + transparency_box.offset.y,
            0,
            obj_transparency_detector,
            {
                image_xscale: transparency_box.size.x,
                image_yscale: transparency_box.size.y,
                renderer: node.renderer,
            }
        );
    }
}

#macro BUILDING_NAME_MAX_WIDTH 138

//
function building_icon(building) {
    return ITEM_PROTOTYPES[building.prototype.blueprints[building.variant]].icon_sprite;
}

function building_send_animal_out_x(building) {
    return building.top_left_x * 8
        + building.prototype.offset.x
        + building.prototype.entrance_offset.x
        + building.prototype.send_animal_out_offset.x;
}

function building_send_animal_out_y(building) {
    return building.top_left_y * 8
        + building.prototype.offset.y
        + building.prototype.entrance_offset.y
        + building.prototype.send_animal_out_offset.y;
}

function building_send_animal_in_x(building) {
    return building.top_left_x * 8
        + building.prototype.offset.x
        + building.prototype.entrance_offset.x
        + building.prototype.send_animal_in_offset.x;
}

function building_send_animal_in_y(building) {
    return building.top_left_y * 8
        + building.prototype.offset.y
        + building.prototype.entrance_offset.y
        + building.prototype.send_animal_in_offset.y;
}

function record_greenhouse_watered_positions(building) {
    var x_dims = (building.prototype.crop_area_end.x - building.prototype.crop_area_start.x) / 2;
    var y_dims = (building.prototype.crop_area_end.y - building.prototype.crop_area_start.y) / 2;

    //
    var output = array_create(x_dims * y_dims / 4);

    var grid = DYNAMIC_GRIDS.get(building.dyn_index);
    //
    for (var grid_xx = building.prototype.crop_area_start.x; grid_xx < building.prototype.crop_area_end.x; grid_xx+=2) {
        for (var grid_yy = building.prototype.crop_area_start.y; grid_yy < building.prototype.crop_area_end.y; grid_yy+=2) {
            var ni = grid.node_index_for_cell(grid_xx, grid_yy);
            var output_idx = (grid_yy - building.prototype.crop_area_start.y) * x_dims * 0.5 + (grid_xx - building.prototype.crop_area_start.x) * 0.5;
            output[output_idx] = grid.node_terrain_is_watered[ni];
        }
    }

    return output;
}

function apply_greenhouse_watered_positions(building, positions) {
    var x_dims = (building.prototype.crop_area_end.x - building.prototype.crop_area_start.x) / 2;
    var grid = DYNAMIC_GRIDS.get(building.dyn_index);

    for (var i = 0; i < array_length(positions); i++) {
        if positions[i] {
            var normalized_position_x = (i % x_dims) * 2;
            var normalized_position_y = (i div x_dims) * 2;

            water_chunk(
                grid,
                normalized_position_x + building.prototype.crop_area_start.x,
                normalized_position_y + building.prototype.crop_area_start.y,
            );
        }
    }
}
