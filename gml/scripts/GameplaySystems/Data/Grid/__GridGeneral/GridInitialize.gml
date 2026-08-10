function initialize_grid(location_id, dyn_index=undefined) {
    var room_id = location_id_to_gm_room(location_id);
    var room_dimensions = room_dimensions(room_id);
    var grid_size_x = room_dimensions[0] div 8;
    var grid_size_y = room_dimensions[1] div 8;
    var grid = new Grid(grid_size_x, grid_size_y, location_id, dyn_index);

    var extra = room_data_initialize_grid(room_id, grid);
    if extra != undefined {
        var dig_site_list = ARCHAEOLOGY.get_or_create_dig_site_list(location_id);

        for (var i = 0; i < array_length(extra.dig_site_list_generic); i++) {
            var ni = extra.dig_site_list_generic[i];
            dig_site_list.generic.push(Vec2(ni % grid_size_x, ni div grid_size_x));
        }
        for (var i = 0; i < array_length(extra.dig_site_list_special); i++) {
            var ni = extra.dig_site_list_special[i];
            dig_site_list.special.push(Vec2(ni % grid_size_x, ni div grid_size_x));
        }
        if extra.forageables != undefined {
            var candidate_list = FORAGEABLES.get_or_create_candidate_list(location_id);
            assert_defined(candidate_list,  "a `Forageable` tile is present in {LocationId}, which is not a non-Farm outside room", location_id);
            for (var i = 0; i < array_length(extra.forageables); i++) {
                var ni = extra.forageables[i];
                candidate_list.push(Vec2(ni % grid_size_x, ni div grid_size_x));
            }
        }
    }

    if location_id == LocationId.Farm {
        for (var xx = 0; xx < grid_size_x; xx+=16) {
            for (var yy = 0; yy < grid_size_y; yy+=16) {
                var ni = grid.node_index_for_cell(xx, yy);
                grid.node_grass_count[? ni] = 0;
                grid.node_colliders_count[? ni] = 0;

                grid.node_spawn_grass_timer[? ni] = irandom_range(GROW_BACK.grass_wait_range.x - 1, GROW_BACK.grass_wait_range.y);
                grid.node_spawn_colliders_timer[? ni] = irandom_range(GROW_BACK.colliders_wait_range.x - 1, GROW_BACK.colliders_wait_range.y);
            }
        }
    }

    return grid;
}

//
function first_time_grid_setup(grid)  {
    //
    random_set_seed(Game.unique_identifier);
    var room_id = location_id_to_gm_room(grid.location_id);

    spawn_prios_on_map(grid, room_id, "PriorityObjects", spawn_priority_object);
    spawn_prios_on_map(grid, room_id, priority_tileset_season(CALENDAR.season()), spawn_priority_object);
    spawn_prios_on_map(grid, room_id, "PriorityGrass", spawn_priority_grass);
    spawn_prios_on_map(grid, room_id, priority_grass_tileset_season(CALENDAR.season()), spawn_priority_grass);

    randomize();
}

function setup_saved_farm(grid) {
    var farm_data = read_json_file("starting_farms/farm.json");
    var object_list = farm_data.object_list;
    var cleaned_list = List();

    for (var i = 0, c = array_length(object_list); i < c; i++) {
        var object = object_list[i];

        var prio_present = room_data_read_tile(rm_farm, "PriorityObjects", object.top_left_x, object.top_left_y);
        if prio_present != undefined {
            continue;
        }

        cleaned_list.push(object);
    }

    var grid_data = {
        object_list: cleaned_list.to_array(),
        inventories: farm_data.inventories,
        size_x: farm_data.size_x,
        size_y: farm_data.size_y,
        location_id: LocationId.Farm,
        dyn_index: -1
    };

    grid.load(grid_data, buffer_load("starting_farms/terrain.bin"));
    room_data_initialize_post_init_flags(location_id_to_gm_room(grid.location_id), grid.node_flags);
}


//
function setup_priestess_quarters(grid) {
    for (var xx = 94; xx <= 99; xx += 2) {
        for (var yy = 92; yy <= 97; yy += 2) {
            grid.write_ground(xx, yy, GroundKind.Soil);
        }
    }
}
