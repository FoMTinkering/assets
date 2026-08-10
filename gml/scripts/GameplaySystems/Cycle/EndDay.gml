//
function end_day(spawn_eod_menu=true, held_point_of_interest=undefined) {
    trace("Ending {Season} {}...", CALENDAR.season(), CALENDAR.day() + 1);

    //
    MIST.on_end_day();
    SATURDAY_MARKET.on_end_day();
    festival_end_day();

    //
    with par_animal {
        self.fsm.change_state(AnimalState.Idle);
    }

    //
    var animals = get_all_animals();
    for (var i = 0; i < animals.count(); i++) {
        var animal = animals.get(i);
        if animal.is_home() && !animal.has_eaten {
            animal_try_to_eat_from_stable(animal, animal.stable);
        }
    }

    //
    var grids_to_check = [GRIDS[LocationId.Farm]];
    var buildings = get_buildings();
    for (var i = 0; i < buildings.count(); i++) {
        var building = buildings.get(i);
        if building.prototype.player_building_kind == PlayerBuildingKind.Greenhouse {
            array_push(grids_to_check, DYNAMIC_GRIDS.get(building.dyn_index));
        }
    }

    for (var grid_i = 0; grid_i < array_length(grids_to_check); grid_i++) {
        var grid = grids_to_check[grid_i];

        if LOCATIONS[grid.location_id].outdoor && WEATHER.is_inclement() {
            for (var i = 0; i < array_length(grid.sprinklers); i++) {
                var sprinkler = grid.sprinklers[i];
            }
        } else {
            for (var i = 0; i < array_length(grid.sprinklers); i++) {
                var sprinkler = grid.sprinklers[i];

                if sprinkler.essence_supply > 0 {
                    var did_work = false;

                    var range = sprinkler.prototype.sprinkler * 2;
                    for (var xx = -range; xx <= range; xx++) {
                        for (var yy = -range; yy <= range; yy++) {
                            var ni = grid.node_index_for_cell(sprinkler.top_left_x + xx, sprinkler.top_left_y + yy);
                            if grid.node_terrain_kind[ni] == TerrainKind.Ground
                                && grid.node_terrain_ground_kind[ni] == GroundKind.Soil
                            {
                                grid.node_terrain_is_watered[ni] = true;
                                did_work = true;
                            }
                        }
                    }

                    sprinkler.essence_supply = max(0, sprinkler.essence_supply - did_work);
                }
            }
        }
    }

    //
    {
        for (var i = 0; i < DYNAMIC_GRIDS.count(); i++) {
            var dyn_grid = DYNAMIC_GRIDS.get(i);
            if dyn_grid == undefined || dyn_grid.ocarina == undefined {
                continue;
            }

            dyn_grid.ocarina.activated_today = false;
        }
    }

    //
    pet_update_at_time(hours(26), false);

    //
    if ARI.has_spouse() {
        var bed = player_bed();
        T2R.write(
            "spouse_slept_in_double_bed_night_before",
            bed != undefined && GRIDS[bed.location_id].node_parent[bed.ni].prototype.bed_kind == BedKind.Double,
        );
    }

    //
    if spawn_eod_menu {
        new_chain().append(LinkId.Await, function() {
            return !MIST.running;
        }).append(LinkId.Function, function(held_point_of_interest) {
            var menu = ANCHOR.spawn_menu(Menu.Eod);
            menu.held_point_of_interest = held_point_of_interest;
            menu.init();
        }, [held_point_of_interest]);
    }

    Game.animal_eat_exit = false;
}
