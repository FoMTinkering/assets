//
//
function new_day() {
    var start_time = get_timer();

    new_day_non_grid();
    new_day_grid();

    trace("it's a brand new day ({Season} {})...(and it took {micro} to get there)", CALENDAR.season(), CALENDAR.day() + 1, get_timer() - start_time);
}

//
//
function new_day_non_grid() {
    //
    Game.music_cut_off = false;
    Game.late_warning_issued = false;
    Game.turned_on_lights = false;
    Game.bell_rang = false;
    Game.animal_eat = false;
    Game.prevent_eod_music_stop = false;
    CANCEL_FESTIVALS = false;
    clear_loaded_date_photos();

    if PENDING_DAY_TIME_SPEED_CHANGE != undefined {
        MINUTES_PER_DAY = fiddle_get(format("misc/{DayTimeSpeed}_minutes_per_day", PENDING_DAY_TIME_SPEED_CHANGE));
        PENDING_DAY_TIME_SPEED_CHANGE = undefined;
    }

    //
    //
    if ARI.end_of_day_sequence == false {
        npcs_time_jump(hours(26), CLOCK.time, true);
    }

    //
    //
    var new_day_result = CALENDAR.increment_day();
    if new_day_result != NewDayResult.NormalDay {
        new_season();

        if new_day_result == NewDayResult.NewYear {
            //
            //
            new_year();
        }
    }

    CLOCK = new Clock();

    //
    //
    POST_PROCESS = post_process_by_location();

    //
    festival_new_day();

    //
    ARI.on_new_day();

    //
    //
    //
    if requirements_pass(Requirement.UnlockedLostAndFound) && CALENDAR.day_type() == Day.Monday {
        var lists = List();
        for (var i = 0; i < LocationId.LEN; i++) {
            if !LOCATIONS[i].lost_and_found {
                continue;
            }
            var grid = GRIDS[i];
            if grid != undefined {
                lists.push(grid.lost_items);
            }
        }

        for (var i = 0; i < lists.count(); i++) {
            var lost_items = lists.get(i);

            lost_items.retain(function(entry) {
                var item = entry.items.first();
                var count = entry.items.count();
                if item.prototype.tags.contains("mob_coin") {
                    return true;
                }
                if LOST_AND_FOUND.can_add(item, count) {
                    LOST_AND_FOUND.add(item, count);
                    return false;
                } else {
                    return true;
                }
            })
        }

        //
        if LOCATIONS[CURRENT_LOCATION_ID].lost_and_found {
            with obj_item {
                var item = self.items.first();
                var count = self.items.count();
                if LOST_AND_FOUND.can_add(item, count) && !item.prototype.tags.contains("mob_coin") {
                    LOST_AND_FOUND.add(item, count);
                    instance_destroy(self);
                }
            }
        }

        static DINGY_IDS = dingy_ids();
        var unacquired = [];
        for (var i = 0; i < array_length(DINGY_IDS); i++) {
            if !any_item_matches(DINGY_IDS[i]) {
                array_push(unacquired, DINGY_IDS[i]);
            }
        }
        repeat 2 {
            var item = undefined;
            if array_is_empty(unacquired) {
                item = DINGY_IDS[irandom(array_length(DINGY_IDS) - 1)];
            } else {
                var index = irandom(array_length(unacquired) - 1);
                item = unacquired[index];
                array_delete(unacquired, index, 1);
            }
            if LOST_AND_FOUND.can_add(item) {
                LOST_AND_FOUND.add(item);
            }
        }
    }

    //
    var gs_entry = {
        fed: 0,
        not_fed: 0,
        pet: 0,
        not_pet: 0,
        inside: 0,
        outside: 0,
        day: total_days(),
    };
    var buildings = get_buildings();
    for (var i = 0; i < buildings.count(); i++) {
        var building = buildings.get(i);
        if building.stable != undefined {
            var stats = building.stable.on_new_day();
            gs_entry.fed += stats.fed;
            gs_entry.not_fed += stats.not_fed;
            gs_entry.pet += stats.pet;
            gs_entry.not_pet += stats.not_pet;
            gs_entry.inside += stats.inside;
            gs_entry.outside += stats.outside;
        }
    }
    array_push(GAME_STATS.animal_eod_statuses, gs_entry);
    daycare_new_day();

    //
    if instance_exists(obj_pet) {
        instance_destroy(obj_pet);
    }

    if PET.unlocked() {
        PET.location_id = pet_valid_house_location();

        PET.job_active = false;
        PET.has_eaten = false;
        PET.has_been_pat = false;
        PET.management = PetManagement.Morning;

        //
        if ARI.held_animal_id == PET_ID {
            ARI.held_animal_id = undefined;
            ARI.held_animal_last_frame = undefined;
        }
    }

    SATURDAY_MARKET.on_new_day();
    WEATHER.weather = WEATHER.forecast[CALENDAR.day()];

    //
    T2R.update();
    T2R.update_daily();

    npcs_on_new_day();

    var spouse = ARI.spouse();
    for (var i = 0; i < array_length(ARI.children); i++) {
        var child = ARI.children[i];
        if NPCS[spouse].held_child() == undefined {
            child.set_location(ChildLocation.WithSpouse);
        }
    }

    //
    ARI.inbox.on_new_day();

    //
    REQUEST_BOARD = create_request_board();

    //
    INN_STOCK = create_store_stock(Store.Inn);
    ATE_SOUP = false;

    for (var i = 0; i < LocationId.LEN; i++) {
        WORLD_FOUNTAINS[i] = false;
    }

    //
    USED_WISHING_WELL = false;

    //
    var target_stamina = ARI.get_max_stamina();
    if ARI.perk_active(Perk.ADayWellSpent) && ARI.get_stamina() <= ARI.get_max_stamina() * 0.05 {
        target_stamina += ARI.perk_value(Perk.ADayWellSpent);
        GAME_STATS.perks[$ perk_to_string(Perk.ADayWellSpent)] += 1;
    }
    ARI.set_stamina(target_stamina, true, true);
    ARI.set_health(ARI.get_max_health(), false, true);
    ARI.modify_mana(1);
    if ARI.ancient_inspiration_time != undefined {
        ARI.ancient_inspiration_time -= 1;
    }
    ARI.has_left_house_today = false;

    npas_new_day();

    MIST.scenes_played_today.clear();
    refresh_achievements([Requirement.HasChildAtAge]);
}

//
//
function new_day_grid() {
    //
    random_set_seed(Game.unique_identifier + get_days(CALENDAR.time));
    for (var i = 0; i < LocationId.LEN; i++) {
        var grid = GRIDS[i];
        if grid == undefined {
            continue;
        }

        grid.new_day();
        ARCHAEOLOGY.spawn_dig_sites(grid);
        FORAGEABLES.spawn_forageables(grid);
    }

    if world_mod_enabled(WorldMod.TownPlaza) {
        spawn_prios_on_map(GRIDS[LocationId.Town], location_id_to_gm_room(LocationId.Town), "PriorityObjectsPlazaFixed", spawn_priority_object, true);
    } else {
        spawn_prios_on_map(GRIDS[LocationId.Town], location_id_to_gm_room(LocationId.Town), "PriorityObjectsPlazaBroken", spawn_priority_object, true);
        spawn_prios_on_map(GRIDS[LocationId.Town], location_id_to_gm_room(LocationId.Town), "PriorityGrassPlazaBroken", spawn_priority_grass, true);
    }

    for (var i = 0, ic = FACTORIES.count(); i < ic; i++) {
        //
        var factory = FACTORIES.get(i);
        if factory.production_request == undefined
            && factory.inventory.total_items() == factory.prototype.factory.inventory_size
        {
            factory.day_count += 1;
            if factory.day_count >= factory.prototype.factory.days_to_produce {
                var arr = factory.prototype.factory.request_data;

                var choice = undefined;
                var choice_count = 0;

                for(var j = 0, jc = array_length(arr); j < jc; j++) {
                    var request = arr[j];
                    if requirements_pass(request.requirements) {
                        choice_count += 1;
                        if irandom_range(1, choice_count) == 1 {
                            choice = request.item_id;
                        }
                    }
                }

                factory.production_request = choice;
                factory.production_tier = factory_rewards_index(factory.inventory);
                factory.day_count = 0;
            }
        }
    }

    for (var i = 0, c = DYNAMIC_GRIDS.count(); i < c; i++) {
        var grid = DYNAMIC_GRIDS.get(i);
        if grid != undefined {
            grid.new_day();
        }
    }

    if ARI.perk_active(Perk.MistSight) {
        MIST_SIGHT_ACTIVE_INDEX = MIST_SIGHT_LIST.count() == 0 ? undefined : irandom(MIST_SIGHT_LIST.count() - 1);
    }

    grow_back_new_day(GRIDS[LocationId.Farm]);
    WEATHER.on_new_day();
    randomize();

    if DEBUG_TOOLS {
        remake_room_renderers();
    }
}
