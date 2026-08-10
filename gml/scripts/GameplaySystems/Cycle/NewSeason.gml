//
function new_season() {
    var start_time = get_timer();
    var season = CALENDAR.season();

    WEATHER.forecast = generate_forecast(season);
    GRIDS[LocationId.Farm].wilt_crops(season);

    var old_season = go_back_a_season(season);

    portrait_atlas_unload(season_to_portrait_atlas(old_season));
    portrait_atlas_load(season_to_portrait_atlas(season));

    //
    for (var i = 0; i < LocationId.LEN; i++) {
        if LOCATIONS[i].outdoor == false {
            continue;
        }

        var room_id = location_id_to_gm_room(i);

        var grid = GRIDS[i];
        grid.wilt_trees_and_forageables(season, old_season);

        //
        var prios = room_data_read_tilemap(room_id, priority_tileset_season(old_season));
        for (var j = 0; j < array_length(prios); j++) {
            erase_object_node(grid, prios[j] & U32_MAX);
        }

        //
        var prio_grass = room_data_read_tilemap(room_id, priority_grass_tileset_season(old_season));
        for (var j = 0; j < array_length(prio_grass); j++) {
            erase_object_node(grid, prio_grass[j] & U32_MAX);
        }

        //
        spawn_prios_on_map(grid, room_id, priority_tileset_season(season), spawn_priority_object);
        spawn_prios_on_map(grid, room_id, priority_grass_tileset_season(season), spawn_priority_grass);
    }

    //
    var grid = GRIDS[LocationId.Farm];
    for (var xx = 0; xx < grid.dims.x; xx += 2) {
        for (var yy = 0; yy < grid.dims.y; yy += 2) {
            var ni = grid.node_index_for_cell(xx, yy);
            if grid.node_object_id[ni] == undefined {
                continue;
            }
            if grid.node_parent[ni].prototype[$ "factory"] == undefined {
                continue;
            }
            //
            grid.node_parent[ni].production_request = undefined;
            grid.node_parent[ni].day_count = 999;
        }
    }

    //
    spawn_new_season_colliders(GRIDS[LocationId.Farm]);

    trace(
        "Progressed to {Season} (and it took {micro} to get there)",
        season,
        get_timer() - start_time,
    );
}

function season_to_portrait_atlas(season) {
    switch season {
        case Season.Spring:
            return "PortraitsSpring";
        case Season.Summer:
            return "PortraitsSummer";
        case Season.Fall:
            return "PortraitsAutumn";
        case Season.Winter:
            return "PortraitsWinter";
    }
}
