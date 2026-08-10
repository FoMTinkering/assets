function load_game(loader) {
    if vault_validate(loader.vault_id) == false {
        warn("Checksums test failed! Save has been tampered...");
        checksum_set_save_is_tampered(true);
    } else {
        checksum_set_save_is_tampered(false);
    }

    trace("Loading save: {}", loader.save_path);
    Game.last_serde_path = loader.save_path;
    var start_time = get_timer();

    var core_time = get_timer();
    var gamedata = loader.load_file("gamedata");
    var files = {
        gamedata,
        info: loader.load_file("info"),
        player: loader.load_file("player"),
        quests: loader.load_file("quests"),
        npcs: loader.load_file("npcs"),
        game_stats: loader.load_file("game_stats", true),
        dyn_grids: array_create(gamedata.dynamic_grid_count, undefined),
        grids: array_create(LocationId.LEN, undefined),
        farm_buffer: loader.load_farm_buffer(),
        date_photos: loader.load_file("date_photos"),
    };

    for (var i = 0; i < files.gamedata.dynamic_grid_count; i++) {
        var dyn_name = create_dynamic_grid_file_name(i);
        files.dyn_grids[i] = loader.has_file(dyn_name)
            ? loader.load_file(dyn_name)
            : undefined;
    }

    for (var i = 0; i < LocationId.LEN; i++) {
        var grid_name = location_id_to_string(i);
        files.grids[i] = loader.has_file(grid_name)
            ? loader.load_file(grid_name)
            : undefined;
    }

    if loader.cannot_be_ran {
        return;
    }

    trace("Loaded files in {ms}.", get_timer() - core_time);

    CHECK_ACHIEVEMENTS = false;

    CREATION_VERSION = files.info.creation_version;

    random_set_seed(real(files.gamedata.random_seed));
    PENDING_DAY_TIME_SPEED_CHANGE = opt_and_then(files.gamedata.pending_day_time_speed_change, string_to_day_time_speed);
    CANCEL_FESTIVALS = files.gamedata[$ "cancel_festivals"] ?? false;
    ALL_UNLOCKS = files.gamedata.all_unlocks;
    STORY_ENABLED = files.gamedata.story_enabled;
    CALENDAR.time = int64(real(files.gamedata.date));
    CLOCK = new Clock();
    CLOCK.set_time(int64(real(files.gamedata.clock)));
    PLAYTIME = files.gamedata.playtime;
    FARM_EXPANDED = files.gamedata.farm_expanded;
    GAME_STATS = files.game_stats;

    //
    MINUTES_PER_DAY = fiddle_get(format("misc/{}_minutes_per_day", files.gamedata.day_time_speed));

    //
    var player_time = get_timer();
    ARI.name = files.player.name;
    ARI.farm_name = files.player.farm_name;
    ARI.birthday = files.player.birthday;
    ARI.pronouns = files.player.pronouns;
    ARI.presets = ListFromArray(apply_func(files.player.presets, player_animation_assets_deserialize));
    ARI.preset_index_selected = files.player.preset_index_selected;

    //
    //
    //
    //
    //
    ARI.last_bed_used = opt_and_then(files.player[$ "last_bed_used"], function(v) {
        return {
            location_id: string_to_location_id(v.location_id),
            ni: v.ni,
        };
    });
    ARI.save_position = opt_and_then(files.player[$ "save_position"], deserialize_location_position);
    ARI.player_dir_game_start = files.gamedata.dir;
    ARI.deserialize_stats(files.player.stats);
    ARI.inventory.deserialize(files.player.inventory);
    ARI.armor.deserialize(files.player.armor);
    apply_struct_to_array(ARI.skill_xp, files.player.skill_xp, string_to_skill);
    for (var i = 0; i < Skill.LEN; i++) {
        ARI.skill_xp[i] = clamp(ARI.skill_xp[i], 0, MAX_SKILL_LEVEL_COSTS[i]);
    }
    ARI.perks = deserialize_array_bool(files.player.perks, try_string_to_perk, Perk.LEN);
    ARI.cosmetic_unlocks = HashSetFromArray(files.player.cosmetic_unlocks);
    ARI.seen_cosmetics = HashSetFromArray(files.player.seen_cosmetics);
    ARI.inbox.deserialize(files.player.inbox);
    ARI.crown_cooldown = files.player.crown_cooldown;
    ARI.has_seen_treasure_level_today = files.player.has_seen_treasure_level_today;
    ARI.has_seen_ritual_level_today = files.player.has_seen_ritual_level_today;
    ARI.has_seen_arena_level_today = files.player.has_seen_arena_level_today;
    ARI.has_gossiped_today = files.player.has_gossiped_today;
    ARI.used_object_today = files.player["used_object_today"] != undefined
        ? deserialize_array_bool(files.player.used_object_today, string_to_object_id, ObjectId.LEN)
        : array_bool(ObjectId.LEN);
    ARI.date_history = apply_func(files.player.date_history, function(v) {
        v.date = string_to_date(v.date);
        v.npc = string_to_npc_id(v.npc);
        return v;
    });
    ARI.pending_renown_entries = ListFromArray(files.player.pending_renown_entries)
        .map(deserialize_renown_entry);
    ARI.spells_learned = deserialize_array_bool(
        files.player.spells_learned,
        string_to_spell,
        Spell.LEN,
    );
    ARI.set_pinned_spell(opt_and_then(files.player.pinned_spell, string_to_spell));

    apply_struct_to_array(
        ARI.animal_variant_unlocks,
        files.player.animal_variant_unlocks,
        string_to_animal_kind,
        HashSetFromArray,
    );
    apply_struct_to_array(
        ARI.animal_cosmetic_unlocks,
        files.player.animal_cosmetic_unlocks,
        string_to_animal_kind,
        HashSetFromArray,
    );
    ARI.pet_cosmetic_sets_unlocked = files.player.pet_cosmetic_sets_unlocked;
    ARI.pet_skin_unlocks = files.player.pet_skin_unlocks;

    ARI.items_acquired = deserialize_array_bool(
        files.player.items_acquired,
        try_string_to_item_id,
        ItemId.LEN,
    );
    ARI.build_almanac_items_remaining();

    ARI.tutorials_seen = deserialize_array_bool(
        files.player.tutorials_seen,
        string_to_tutorial,
        Tutorial.LEN,
    );
    ARI.legendary_fish_caught = deserialize_array_bool(
        files.player.legendary_fish_caught,
        string_to_season,
        Season.LEN,
    );

    ARI.recipe_unlocks = deserialize_array_bool(
        files.player.recipe_unlocks,
        try_string_to_item_id,
        ItemId.LEN,
    );

    ARI.recipes_created = deserialize_array_bool(
        files.player.recipes_created,
        try_string_to_item_id,
        ItemId.LEN,
    );

    ARI.morning_recipe_unlocks = deserialize_array_bool(
        //
        //
        files.player[$ "morning_recipe_unlocks"] ?? [],
        try_string_to_item_id,
        ItemId.LEN,
    );

    ARI.date_unlocks = deserialize_array_bool(
        files.player.date_unlocks,
        string_to_date,
        Date.LEN,
    );

    ARI.song_unlocks = files.player["song_unlocks"] ?? [];
    var overrides = files.player["song_overrides"] ?? {};
    var keys = struct_get_names(overrides);
    for (var i = 0 ; i < array_length(keys); i++) {
        ARI.song_overrides[string_to_location_id(keys[i])] = overrides[keys[i]];
    }
    ARI.dyn_song_overrides = files.player["dyn_song_overrides"] ?? {};

    ARI.disable_break_ups = files.player["disable_break_ups"] ?? false;
    ARI.disable_break_up_letters = files.player["disable_break_up_letters"] ?? false;

    apply_struct_to_array(
        ARI.items_sold,
        files.player.items_sold,
        try_string_to_item_id,
    );

    ARI.annual_item_purchase_bans = deserialize_array_bool(
        files.player.annual_item_purchase_bans,
        try_string_to_item_id,
        ItemId.LEN,
    );
    //
    //
    ARI.has_left_house_today = files.player[$ "has_left_house_today"] ?? true;

    ARI.wedding_date = files.player[$ "wedding_date"];
    ARI.proposal_date = files.player[$ "proposal_date"];

    ARI.pending_child = opt_and_then(files.player["pending_child"], function(v) {
        v.utero = string_to_utero(v.utero);
        return v;
    });

    ARI.has_protection_scroll = files.player["has_protection_scroll"] ?? false;

    ARCHAEOLOGY = new Archaeology();
    RENOWN_REWARD_INVENTORY.deserialize(files.player.renown_reward_inventory);
    LOST_AND_FOUND.deserialize(files.player.lost_and_found);
    ATE_SOUP = files.player.ate_soup;
    WORLD_FOUNTAINS = deserialize_array_bool(
        files.player.world_fountains,
        try_string_to_location_id,
        LocationId.LEN
    );
    USED_WISHING_WELL = files.player.used_wishing_well;
    DECOR.floorings = deserialize_floorings(files.player.floorings);
    DECOR.wallpapers = deserialize_wallpapers(files.player.wallpapers);
    DECOR.upper_floor = files.player.upper_floor;
    DECOR.variant = opt_and_then(files.player["home_variant"], string_to_home_variant) ?? HomeVariant.StoneCottage;

    ARI.quest_artifacts = MapWrap(files.player.quest_artifacts);
    ARI.festival_date_partner = opt_and_then(files.player[$ "festival_date_partner"], string_to_npc_id);

    SECRET_BEACH = files.player[$ "secret_beach"] ?? 0;
    SECRET_NARROWS = files.player[$ "secret_narrows"] ?? 0;
    SECRET_TOWER = files.player[$ "secret_tower"] ?? 0;

    trace("Loaded player in {ms}.", get_timer() - player_time);

    //
    var grid_time = get_timer();
    DYNAMIC_GRIDS = ListFromArray(array_create(files.gamedata.dynamic_grid_count, undefined));
    for (var i = 0; i < files.gamedata.dynamic_grid_count; i++) {
        var grid_file = files.dyn_grids[i];
        if grid_file == undefined {
            continue;
        }
        var location_id = string_to_location_id(grid_file.location_id);
        trace("Loading {LocationId}<{}>", location_id, grid_file.dyn_index);
        grid = initialize_grid(
            location_id,
            grid_file.dyn_index,
        );
        DYNAMIC_GRIDS.set(i, grid);

        //
        grid.load(grid_file);
        grid.is_setup = true;
    }

    GRIDS = array_create(LocationId.LEN, undefined);
    for (var i = 0; i < LocationId.LEN; i++) {
        //
        if i == LocationId.Dungeon {
            continue;
        }

        var grid_file = files.grids[i];
        var grid = initialize_grid(i);

        //
        if i == LocationId.PlayerHome {
            DECOR.size_upgrade = -1;
            DECOR.apply_house_upgrade(grid, string_to_home_upgrade(files.player.size_upgrade));
        }

        //
        if i == LocationId.Farm {
            room_data_initialize_post_init_flags(location_id_to_gm_room(grid.location_id), grid.node_flags);
        } else if i == LocationId.PriestessQuarters {
            setup_priestess_quarters(grid);
        }

        var location = LOCATIONS[i];
        if location.serializable && struct_names_count(grid_file) != 0
            || (TEST_SUITE && i == LocationId.Aldaria && loader.has_file("aldaria"))
        {
            trace("loading {LocationId}", i);
            var terrain_buffer = i == LocationId.Farm ? files.farm_buffer : undefined;
            grid.load(grid_file, terrain_buffer);
        } else {
            //
            first_time_grid_setup(grid);
        }
        load_npc_farms(grid);

        grid.is_setup = true;
        GRIDS[i] = grid;
    }

    GRID = GRIDS[gm_room_to_location_id(room())];

    //
    var mount = files.player[$ "mount"];
    if mount != undefined {
        ARI.mount = create_default_mount("mistmare");
        ARI.mount.kind = string_to_animal_kind(mount.kind);
        ARI.mount.variant = mount.variant;
        ARI.mount.sex = string_to_sex(mount.sex);
        ARI.mount.name = mount.name;
        ARI.mount.cosmetic = mount.cosmetic;
        ARI.mount.mount_mirroring_animal = mount[$ "mount_mirroring_animal"];
        ARI.mount.prototype = ANIMAL_PROTOTYPES[ARI.mount.kind];
    }


    //
    var lost_item_per_location = files.gamedata.lost_items;
    if lost_item_per_location != undefined {
        for (var i = 0; i < LocationId.LEN; i++) {
            if i == LocationId.Dungeon {
                continue;
            }

            var lost_items = lost_item_per_location[$ location_id_to_string(i)];
            if is_nullish(lost_items) {
                continue;
            }

            GRIDS[i].lost_items = deserialize_lost_items(lost_items);
        }

        //
        for (var i = 0; i < array_length(lost_item_per_location.dynamic_lost_items); i++) {
            var items = lost_item_per_location.dynamic_lost_items[i];
            var dyn_grid = DYNAMIC_GRIDS.get(i);
            if is_nullish(items) || dyn_grid == undefined {
                continue;
            }
            dyn_grid.lost_items = deserialize_lost_items(items);
        }
    }

    //
    //
    //
    for (var i = 0, ic = array_length(files.quests.active_quests); i < ic; i++) {
        var quest = files.quests.active_quests[i];

        //
        if quest.quest_name == "find_the_magic_key"
            && quest.task_id == 4
            && any_item_matches(ItemId.SeedMagicKey) == false
        {
            var priestess_grid = GRIDS[LocationId.PriestessQuarters];
            var found_crop = false;
            for (var xx = 94; xx < 100; xx +=2) {
                for (var yy = 92; yy < 98; yy += 2) {
                    var ni = priestess_grid.node_index_for_cell(xx, yy);
                    if priestess_grid.node_object_id[ni] == ObjectId.MagicKey {
                        found_crop = true;
                        break;
                    }
                }

                if found_crop {
                    break;
                }
            }

            if found_crop == false {
                error("Detected MagicKey softlock. Giving a new MagicKeySeed...");
                GRIDS[LocationId.PlayerHome].lost_items.push({
                    x: 180,
                    y: 190,
                    items: ListFromArray([new LiveItem(ItemId.SeedMagicKey)])
                });
            }
        }
    }

    trace("Loaded grids in {s}.", get_timer() - grid_time);

    for (var i = 0; i < array_length(files.quests.active_quests); i++) {
        var quest_blob = files.quests.active_quests[i];

        if !DEBUG_ASSERTIONS && QUESTS.contains_key(quest_blob.quest_name) == false {
            array_delete(files.quests.active_quests, i, 1);
            i -= 1;
            continue;
        }
        var success = QUEST_LOG.start(quest_blob.quest_name, quest_blob.task_id);
        assert(success, "quest `{}` couldn't not be started.", quest_blob.quest_name);

        var q = QUEST_LOG.active.get(quest_blob.quest_name);

        //
        //
        q.blackboard.inner = quest_blob.blackboard;
    }
    for (var i = 0, c = array_length(files.quests.completed_quests); i < c; i++) {
        QUEST_LOG.completed.insert(files.quests.completed_quests[i]);
    }
    QUEST_LOG.blackboard.inner = files.quests.blackboard;
    QUEST_LOG.completion_timestamps = MapWrap(files.quests.completion_timestamps);
    MANUAL_QUEST_UNLOCKS = HashSetFromArray(files.quests.manual_quest_unlocks);
    REQUEST_BOARD_READ_ENTRIES = HashSetFromArray(files.quests.request_board_read_entries);

    //
    //
    if files.quests[$ "request_board"] == undefined {
        REQUEST_BOARD = create_request_board();
    } else {
        if !DEBUG_ASSERTIONS {
            for (var i = 0; i < array_length(files.quests.request_board); i++) {
                if CONTENT_REGISTRY.validate_quest(files.quests.request_board[i]) == undefined {
                    array_delete(files.quests.request_board, i, 1);
                    i -= 1;
                }
            }
        }
        REQUEST_BOARD = ListFromArray(files.quests.request_board);
    }

    //
    WEATHER.deserialize(files.gamedata.weather);
    WEATHER.on_new_day();

    //
    if files.gamedata[$ "pet"] != undefined {
        PET.deserialize(files.gamedata[$ "pet"], CLOCK.time);
    }

    //
    var npc_time = get_timer();
    T2R.new_game(ARI.name);

    for (var i = 0; i < NpcId.LEN; i++) {
        var npc = NPCS[i];
        npc.deserialize(files.npcs[$ npc_id_to_string(i)]);

        npc.brain_dead = T2R.schedule_current_action_has_arrived(i);
    }

    T2R.update_daily();
    var keys = struct_get_names(files.gamedata.t2_world_facts);
    for (var i = 0; i < array_length(keys); i++) {
        var wf_name = keys[i];
        var wf_value = files.gamedata.t2_world_facts[$ wf_name];

        if matches(wf_name, "date_time", "day_time", "ari_birthday", "ari_name", "is_ari_birthday") {
            continue;
        }
        T2R.write(wf_name, wf_value);
    }
    T2R.schedule_deserialize_expirator(files.gamedata.t2_expirator);
    T2R.update();

    //
    //
    for (var i = 0; i < NpcId.LEN; i++) {
        var npc = NPCS[i];
        if npc.is_roommate() {
            npc.brain_dead = false;
        }
    }

    ARI.children = opt_and_then(files.player["children"], function(v) {
        apply_func(v, function(v) {
            var c = new Child(
                string_to_child_id(v.id),
                v.birthday,
                string_to_child_skin_tone(v.skin_tone)
            );
            c.name = v.name;
            c.stage = string_to_child_stage(v.stage);
            c.set_location(string_to_child_location(v.location));
            return c;
        });

        return v;
    }) ?? [];
    report_children_facts();

    trace("Loaded t2 and npcs in {ms}.", get_timer() - npc_time);

    apply_struct_to_array(
        PROPS.world,
        files.gamedata.props,
        string_to_location_id,
        ListFromArray
    );

    DAYCARE = deserialize_daycare(files.gamedata.daycare);
    for (var i = 0; i < array_length(files.gamedata.museum_progress); i++) {
        var item = try_string_to_item_id(files.gamedata.museum_progress[i]);
        if item != undefined {
            register_item_to_museum(item);
        }
    }

    MIST.scene_history = HashSetFromArray(files.gamedata.scene_history);
    MIST.scenes_played_today = HashSetFromArray(files.gamedata[$ "scenes_played_today"] ?? []);

    MAXIMUM_REACHED_DUNGEON_LEVEL = files.gamedata.maximum_mines_level;

    Game.play_time_comparator = current_time() / 1000;

    MIST_SIGHT_ACTIVE_INDEX = files.gamedata.active_mist_sight;

    GS_MINES_RUN = undefined;

    FISH_TRAP_RARITY = files.gamedata[$ "fish_trap_rarity"];
    FISH_TRAP_TIMESTAMP = files.gamedata[$ "fish_trap_timestamp"];

    for (var i = 0; i < Seal.LEN; i++) {
        SEAL_INVENTORIES[i].deserialize(files.gamedata.seals[$ seal_to_string(i)]);
    }

    SATURDAY_MARKET.on_new_day(
        opt_and_then(files.gamedata[$ "saturday_market_vendors"], function(data) {
            return deserialize_array_bool(data, try_string_to_npc_id, NpcId.LEN);
        })
    );

    npas_new_day();

    DATE_PHOTOS = array_map(files.date_photos.photos, function(v) {
        return {
            photo: v.photo,
            photo_decompressed: undefined,
            timestamp: v.timestamp,
            npc: string_to_npc_id(v.npc),
            date: string_to_date(v.date),
        };
    });

    //
    array_push(
        GAME_STATS.load_logs,
        {
            version: version_to_string(GAME_VERSION),
            day: total_days(),
        },
    );

    //
    portrait_atlas_load(season_to_portrait_atlas(CALENDAR.season()));

    CHECK_ACHIEVEMENTS = true;
    refresh_achievements();

    trace("Finished load in {s}.", get_timer() - start_time);
}
