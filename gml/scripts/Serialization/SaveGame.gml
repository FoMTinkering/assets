function save_game(save_path) {
    var saver = new RustSaver(save_path);
    Game.last_serde_path = save_path;

    var start_time = get_timer();

    var new_seed = randomize();

    //
    {
        var per_location_timer = get_timer();

        for (var i = 0; i < LocationId.LEN; i++) {
            var location = LOCATIONS[i];
            if location.serializable == false {
                continue;
            }

            var grid = GRIDS[i];
            grid.save(saver);
            var new_timer = get_timer();

            trace("saved {LocationId}...in {micro}!", i, new_timer - per_location_timer);

            per_location_timer = new_timer;
        }

        //
        store_loose_items_as_lost();

        var lost_items_per_location = {};
        for (var i = 0; i < LocationId.LEN; i++) {
            var grid = GRIDS[i];
            if grid == undefined {
                continue;
            }

            var data = serialize_lost_items(grid.lost_items);
            if array_length(data) != 0 {
                lost_items_per_location[$ location_id_to_string(i)] = data;
            }
        }

        //
        GRID.lost_items.clear();

        //
        lost_items_per_location.dynamic_lost_items = array_create(DYNAMIC_GRIDS.count(), undefined);
        for (var i = 0, c = DYNAMIC_GRIDS.count(); i < c; i++) {
            var dyn_grid = DYNAMIC_GRIDS.get(i);
            if dyn_grid != undefined {
                dyn_grid.save(saver);

                lost_items_per_location.dynamic_lost_items[i] = serialize_lost_items(dyn_grid.lost_items);
            }
        }
    }

    var cur_second = current_time() / 1000;
    PLAYTIME += cur_second - Game.play_time_comparator;
    Game.play_time_comparator = cur_second;

    var gamedata = {
        random_seed: string(new_seed),
        dir: instance_exists(obj_ari) ? obj_ari.dir : undefined,
        playtime: PLAYTIME,
        date: int64(CALENDAR.time),
        clock: int64(CLOCK.time),
        weather: WEATHER.serialize(),
        all_unlocks: ALL_UNLOCKS,
        story_enabled: STORY_ENABLED,
        dynamic_grid_count: DYNAMIC_GRIDS.count(),
        lost_items: lost_items_per_location,
        t2_world_facts: T2R.read_world(),
        t2_expirator: T2R.schedule_serialize_expirator(),
        scene_history: MIST.scene_history.keys(),
        scenes_played_today: MIST.scenes_played_today.keys(),
        museum_progress: serialize_array_bool(MUSEUM_PROGRESS, item_id_to_string),
        maximum_mines_level: MAXIMUM_REACHED_DUNGEON_LEVEL,
        daycare: serialize_daycare(),
        farm_expanded: FARM_EXPANDED,
        pending_day_time_speed_change: opt_and_then(PENDING_DAY_TIME_SPEED_CHANGE, day_time_speed_to_string),
        day_time_speed: day_time_speed_to_string(minutes_per_day_to_day_time_speed(MINUTES_PER_DAY) ?? DayTimeSpeed.Standard),
        seals: array_to_struct(
            array_create_ext(Seal.LEN, function(i) {
                return SEAL_INVENTORIES[i].serialize()
            }),
            seal_to_string,
        ),
        props: array_to_struct(
            array_map(PROPS.world, function(list) {
                return list.to_array();
            }),
            location_id_to_string,
        ),
        active_mist_sight: MIST_SIGHT_ACTIVE_INDEX,
        pet: PET.serialize(),
        saturday_market_vendors: serialize_array_bool(SATURDAY_MARKET.stalls, npc_id_to_string),
        fish_trap_rarity: FISH_TRAP_RARITY,
        fish_trap_timestamp: FISH_TRAP_TIMESTAMP,
    };

    var player = {
        name: ARI.name,
        farm_name: ARI.farm_name,
        birthday: ARI.birthday,
        pronouns: ARI.pronouns,
        preset_index_selected: ARI.preset_index_selected,
        stats: ARI.serialize_stats(),
        inventory: ARI.inventory.serialize(),
        armor: ARI.armor.serialize(),
        inbox: ARI.inbox.serialize(),
        skill_xp: array_to_struct(ARI.skill_xp, skill_to_string),
        perks: serialize_array_bool(ARI.perks, perk_to_string),
        spells_learned: serialize_array_bool(ARI.spells_learned, spell_to_string),
        ate_soup: ATE_SOUP,
        world_fountains: serialize_array_bool(WORLD_FOUNTAINS, location_id_to_string),
        used_wishing_well: USED_WISHING_WELL,
        floorings: DECOR.serialize_floorings(),
        wallpapers: DECOR.serialize_wallpapers(),
        size_upgrade: home_upgrade_to_string(DECOR.size_upgrade),
        upper_floor: DECOR.upper_floor,
        home_variant: home_variant_to_string(DECOR.variant),
        items_acquired: serialize_array_bool(ARI.items_acquired, item_id_to_string),
        tutorials_seen: serialize_array_bool(ARI.tutorials_seen, tutorial_to_string),
        items_sold: array_to_struct(ARI.items_sold, item_id_to_string),
        recipe_unlocks: serialize_array_bool(ARI.recipe_unlocks, item_id_to_string),
        recipes_created: serialize_array_bool(ARI.recipes_created, item_id_to_string),
        morning_recipe_unlocks: serialize_array_bool(ARI.morning_recipe_unlocks, item_id_to_string),
        legendary_fish_caught: serialize_array_bool(ARI.legendary_fish_caught, season_to_string),
        seen_cosmetics: ARI.seen_cosmetics.keys(),
        cosmetic_unlocks: ARI.cosmetic_unlocks.keys(),
        annual_item_purchase_bans: serialize_array_bool(ARI.annual_item_purchase_bans, item_id_to_string),
        pinned_spell: opt_and_then(ARI.pinned_spell, spell_to_string),
        renown_reward_inventory: RENOWN_REWARD_INVENTORY.serialize(),
        lost_and_found: LOST_AND_FOUND.serialize(),
        pending_renown_entries: ARI.pending_renown_entries.map_to(serialize_renown_entry).to_array(),
        quest_artifacts: ARI.quest_artifacts.inner,
        crown_cooldown: ARI.crown_cooldown,
        festival_date_partner: opt_and_then(ARI.festival_date_partner, npc_id_to_string),
        has_seen_treasure_level_today: ARI.has_seen_treasure_level_today,
        has_seen_ritual_level_today: ARI.has_seen_ritual_level_today,
        has_seen_arena_level_today: ARI.has_seen_arena_level_today,
        has_gossiped_today: ARI.has_gossiped_today,
        used_object_today: serialize_array_bool(ARI.used_object_today, object_id_to_string),
        date_history: apply_func(clone_value(ARI.date_history), function(v) {
            return {
                date: date_to_string(v.date),
                npc: npc_id_to_string(v.npc),
                timestamp: v.timestamp,
            };
        }),
        date_unlocks: serialize_array_bool(ARI.date_unlocks, date_to_string),
        song_unlocks: ARI.song_unlocks,
        song_overrides: array_to_struct(ARI.song_overrides, location_id_to_string),
        dyn_song_overrides: ARI.dyn_song_overrides,
        presets: apply_func(ARI.presets.to_array(), function(e) {
            return e.serialize();
        }),
        animal_variant_unlocks: apply_func(
            array_to_struct(ARI.animal_variant_unlocks, animal_kind_to_string),
            function(hash) {
                return hash.keys();
            },
        ),
        animal_cosmetic_unlocks: apply_func(
            array_to_struct(ARI.animal_cosmetic_unlocks, animal_kind_to_string),
            function(hash) {
                return hash.keys();
            },
        ),
        pet_cosmetic_sets_unlocked: ARI.pet_cosmetic_sets_unlocked,
        pet_skin_unlocks: ARI.pet_skin_unlocks,
        mount: opt_and_then(ARI.mount, function(mount) {
            return {
                kind: animal_kind_to_string(mount.kind),
                variant: mount.variant,
                sex: sex_to_string(mount.sex),
                name: mount.name,
                cosmetic: mount.cosmetic,
                mount_mirroring_animal: ARI.mount_mirroring_animal,
            };
        }),
        secret_narrows: SECRET_NARROWS,
        secret_beach: SECRET_BEACH,
        secret_tower: SECRET_TOWER,
        has_left_house_today: ARI.has_left_house_today,
        give_magic_key_seed: false,
        last_bed_used: opt_and_then(ARI.last_bed_used, function(v) {
            return {
                location_id: location_id_to_string(v.location_id),
                ni: v.ni,
            };
        }),
        save_position: serialize_location_position(ARI.save_position),
        wedding_date: ARI.wedding_date,
        proposal_date: ARI.proposal_date,
        disable_break_ups: ARI.disable_break_ups,
        disable_break_up_letters: ARI.disable_break_up_letters,
        pending_child: opt_and_then(ARI.pending_child, function(v) {
            return {
                utero: utero_to_string(v.utero),
                due_date: v.due_date,
            };
        }),
        children: apply_func(
            clone_value(ARI.children),
            function(v) {
                return {
                    id: child_id_to_string(v.id),
                    name: v.name,
                    skin_tone: child_skin_tone_to_string(v.skin_tone),
                    location: child_location_to_string(v.location),
                    stage: child_stage_to_string(v.stage),
                    birthday: v.birthday,
                };
            }
        ),
    };

    var npcs = apply_func(
        array_to_struct(NPCS, npc_id_to_string),
        function(npc) {
            return npc.serialize();
        }
    );

    var quests = {
        blackboard: QUEST_LOG.blackboard.inner,
        completed_quests: QUEST_LOG.completed.keys(),
        completion_timestamps: QUEST_LOG.completion_timestamps.inner,
        manual_quest_unlocks: MANUAL_QUEST_UNLOCKS.keys(),
        request_board_read_entries: REQUEST_BOARD_READ_ENTRIES.keys(),
        request_board: REQUEST_BOARD.to_array(),
        active_quests: array_map(QUEST_LOG.active.keys(), function(key) {
            var q = QUEST_LOG.active.get(key);
            return {
                quest_name: key,
                task_id: q.current_stage,
                blackboard: q.blackboard.inner,
            }
        }),

    }

    //
    //
    //
    var header = {
        playtime: gamedata.playtime,
        weather: gamedata.weather,
        calendar_time: gamedata.date,
        clock_time: gamedata.clock,
        name: player.name,
        farm_name: player.farm_name,
        stats: player.stats,
        preset: player.presets[player.preset_index_selected],
    };

    saver.save_file("header", header);
    saver.save_file("gamedata", gamedata);
    saver.save_file("player", player);
    saver.save_file("npcs", npcs);
    saver.save_file("quests", quests);
    saver.save_file("game_stats", GAME_STATS);
    saver.save_file("date_photos", {
        photos: array_map(DATE_PHOTOS, function(v) {
            return {
                timestamp: v.timestamp,
                photo: v.photo,
                npc: npc_id_to_string(v.npc),
                date: date_to_string(v.date),
            };
        }),
    });

    var success = saver.save_to_disk(new_game_info());
    var post_save_time = get_timer();
    trace("Save Timer: total took {micro}", post_save_time - start_time);

    if !DEBUG_ASSERTIONS {
        if success == false {
            var popup = popup_creator("misc_local/failed_to_save", "misc_local/failed_to_save_body");
            popup.create_button("misc_local/close");
            popup.spawn();
        }
    } else if success == false {
        crash("failed to save to disk!");
    }
}
