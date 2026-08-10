//
function new_game(_baby) {
    var start_time = get_timer();
    CHECK_ACHIEVEMENTS = false

    CREATION_VERSION = clone_value(GAME_VERSION);

    ARI.name = _baby.name;
    ARI.farm_name = _baby.farm_name;
    ARI.birthday = _baby.birthday;
    ARI.pronouns = _baby.pronouns;
    ARI.presets = List(_baby.presets.first());

    //
    var spells_to_start_with = fiddle_get("misc/ari_stats/starting_spells");
    for (var i = 0; i < array_length(spells_to_start_with); i++) {
        ARI.learn_spell(string_to_spell(spells_to_start_with[i]));
    }

    T2R.new_game(ARI.name);

    GAME_STATS = GameStats();
    patch_game_stats(GAME_STATS);
    Game.play_time_comparator = current_time() / 1000;

    MINUTES_PER_DAY = fiddle_get("misc/standard_minutes_per_day");
    PENDING_DAY_TIME_SPEED_CHANGE = undefined;
    CALENDAR.time = seasons(Season.Spring);

    //
    CLOCK = new Clock();

    WEATHER.forecast = generate_forecast(Season.Spring);
    WEATHER.on_new_day();

    DYNAMIC_GRIDS = List();

    WORLD_FOUNTAINS = array_bool(LocationId.LEN);

    GRIDS = array_create(LocationId.LEN, undefined);
    trace("Pre-Grid = {micro}", get_timer() - start_time);
    var timer = get_timer();

    ARCHAEOLOGY = new Archaeology(ALL_UNLOCKS);
    FARM_EXPANDED = false;
    for (var i = 0; i < LocationId.LEN; i++) {
        if i == LocationId.Dungeon {
            continue;
        }

        var grid = initialize_grid(i);
        first_time_grid_setup(grid);

        FORAGEABLES.spawn_forageables(grid);
        ARCHAEOLOGY.spawn_dig_sites(grid);

        if i == LocationId.PriestessQuarters {
            setup_priestess_quarters(grid);
        }

        grid.is_setup = true;
        GRIDS[i] = grid;
    }
    trace("Loading Grids in NewGame took: {micro}", get_timer() - timer);

    GRID = GRIDS[gm_room_to_location_id(room())];
    hyperpath_init_local_pathfinding(GRID.dims.x, GRID.dims.y);

    var farm_grid = GRIDS[LocationId.Farm];
    setup_saved_farm(farm_grid);

    //
    for (var i = 0; i < ItemId.LEN; i++) {
        var recipe = ITEM_PROTOTYPES[i].recipe;
        if recipe != undefined && recipe.is_default {
            ARI.recipe_unlocks[i] = true;
        }
    }

    //
    ARI.cosmetic_unlocks = default_cosmetic_unlocks();
    ARI.seen_cosmetics = default_cosmetic_unlocks();
    T2R.update();
    T2R.update_daily();

    MANUAL_QUEST_UNLOCKS = HashSet();
    REQUEST_BOARD_READ_ENTRIES = HashSet();

    DECOR.size_upgrade = -1;
    DECOR.apply_house_upgrade(GRIDS[LocationId.PlayerHome], HomeUpgrade.Small);

    //
    SECRET_NARROWS = 0;
    SECRET_BEACH = 0;
    SECRET_TOWER = 0;

    //
    REQUEST_BOARD = create_request_board();
    MIST_SIGHT_ACTIVE_INDEX = undefined;

    trace("Post-Grid = {micro}", get_timer() - start_time);

    //
    if ALL_UNLOCKS {
        ARI.tutorials_seen = array_create(Tutorial.LEN, true);

        for (var i = 0; i < ItemId.LEN; i++) {
            if MUSEUM_DATA.museum_items[i] {
                register_item_to_museum(i);
            }
        }
        DECOR.apply_house_upgrade(GRIDS[LocationId.PlayerHome], HomeUpgrade.LargeWestEast);
        DECOR.variant = HomeVariant.AdobeOne;
        ARI.inventory.resize(30);
        ARI.disable_break_ups = true;
        ARI.mount = create_default_mount("giant_chicken_white");
        var inventory = fiddle_get("misc/ari_stats/starting_inventory_test_mode");
        for (var i = 0; i < array_length(inventory); i++) {
            ARI.inventory.add(string_to_item_id(inventory[i]));
        }
        ARI.set_gold(1000000);
        ARI.set_essence(1000000);
        ARI.base_stamina = 250;
        ARI.stamina_current = 250;
        ARI.base_health = 200;
        ARI.health_current = 200;
        ARI.mana_max = 16;
        ARI.mana_current = 16;
        for (var i = 0; i < Spell.LEN; i++) {
            ARI.learn_spell(i);
        }
        ARI.skill_xp = array_create(Skill.LEN, undefined);
        for (var i = 0; i < Skill.LEN; i++) {
            ARI.skill_xp[i] = MAX_SKILL_LEVEL_COSTS[i];
        }
        for (var i = 0; i < Perk.LEN; i++) {
            ARI.acquire_perk(i);
        }
        for (var i = 0; i < AnimalKind.LEN; i++) {
            var animal = ANIMAL_PROTOTYPES[i];
            var unlocks = HashSetFromArray(animal.variants.keys());
            ARI.animal_variant_unlocks[i] = unlocks;
        }
        for (var i = 0; i < AnimalKind.LEN; i++) {
            var animal = ANIMAL_PROTOTYPES[i];
            var unlocks = HashSetFromArray(animal.cosmetics.keys());
            ARI.animal_cosmetic_unlocks[i] = unlocks;
        }
        for (var i = 0; i < ItemId.LEN; i++) {
            ARI.items_acquired[i] = true;
            if ITEM_PROTOTYPES[i].recipe != undefined {
                ARI.recipe_unlocks[i] = true;
            }
            ARI.items_sold[i] = 999;
        }
        ARI.build_almanac_items_remaining();
        ARI.cosmetic_unlocks = HashSetFromArray(PLAYER_ANIMATION_DATABASE.player_assets.keys());
        ARI.seen_cosmetics = HashSetFromArray(PLAYER_ANIMATION_DATABASE.player_assets.keys());
        ARI.pet_cosmetic_sets_unlocked = PET_PROTOTYPE.cosmetic_sets.keys();
        ARI.legendary_fish_caught = array_create(Season.LEN, true);
        ARI.date_unlocks = array_create(Date.LEN, true);
        ARI.song_unlocks = struct_get_names(SONGS);
        ARI.bell_sound = "school_bell";

        //
        ARI.wedding_date = -seasons(1);
        ARI.proposal_date = -seasons(1) - days(3);

        var rune = new Child(
            ChildId.Rune,
            seasons(Season.Winter) + days(26),
            ChildSkinTone.Lighter,
        );
        rune.location = ChildLocation.InCradle;
        array_push(ARI.children, rune);

        var variant_keys = PET_PROTOTYPE.variants.keys();
        for (var i = 0; i < array_length(variant_keys); i++) {
            var variant = PET_PROTOTYPE.variants.get(variant_keys[i]);
            if variant.unlock_key != undefined && !array_contains(ARI.pet_skin_unlocks, variant.unlock_key) {
                array_push(ARI.pet_skin_unlocks, variant.unlock_key);
            }
        }

        for (var i = 0; i < NpcId.LEN; i++) {
            var npc = NPCS[i];
            npc.set_has_met();
            npc.set_heart_level(10);
            for (var j = 0; j < npc.prototype.loved_gifts.count(); j++) {
                npc.gifts_given.insert(npc.prototype.loved_gifts.get(j));
                npc.known_gift_preferences.insert(npc.prototype.loved_gifts.get(j));
            }
            for (var j = 0; j < npc.prototype.liked_gifts.count(); j++) {
                npc.gifts_given.insert(npc.prototype.liked_gifts.get(j));
                npc.known_gift_preferences.insert(npc.prototype.liked_gifts.get(j));
            }
        }

        var keys = QUESTS.keys();
        QUEST_LOG.completed = HashSetFromArray(keys);

        for (var i = 0; i < array_length(keys); i++) {
            QUEST_LOG.completion_timestamps.insert(keys[i], 0);

            var quest = QUESTS.get(keys[i]);
            quest.tasks.for_each(function(task) {
                var req = task.requirements[Requirement.SuppliedItems];
                if req != undefined {
                    for (var i = 0; i < array_length(req); i++) {
                        var this = req[i];
                        if this.type != SupplyType.Seal {
                            continue;
                        }
                        for (var j = 0; j < ItemId.LEN; j++) {
                            var count = this.items[j];
                            if count == 0 {
                                continue;
                            }
                            SEAL_INVENTORIES[this.seal].add(j, count);
                        }
                    }
                }
            });
        }

        var scenes = CUTSCENES.keys();
        for (var i = 0; i < array_length(scenes); i++) {
            MIST.mark_scene_has_played(scenes[i]);
            trigger_scene_object_removals(scenes[i]);
        }
        MIST.scenes_played_today.clear();

        var facts = fiddle_get("all_unlocks_facts");
        var keys = struct_get_names(facts);
        for (var i = 0; i < array_length(keys); i++) {
            T2R.write(keys[i], facts[$ keys[i]]);
        }

        //
        var grid = GRIDS[LocationId.EasternRoad];
        erase_object_node(grid, grid.node_index_for_cell(110, 48));

        //
        var grid = GRIDS[LocationId.PlayerHome];
        erase_object_node(grid, grid.node_index_for_cell(13, 13));
        grid.write_node_without_initializing(10, 13, ObjectId.BasicDoubleBedWalnut, Cardinal.South);
        ARI.last_bed_used = all_player_beds().first();
        grid.write_node_without_initializing(35, 13, ObjectId.BabyCradle, Cardinal.South);

        MAXIMUM_REACHED_DUNGEON_LEVEL = 100;
        ARI.renown = 100000000;

        full_start_farm_setup(farm_grid);
        expand_farm();

        PET.add_heart_points(animal_heart_level_to_points(10));
        PET.variant = "goldclod";

        SECRET_NARROWS = 3;
        SECRET_BEACH = 3;
        SECRET_TOWER = 1;
        DECOR.upper_floor = true;
    } else {
        //
        var inventory = fiddle_get("misc/ari_stats/starting_inventory");
        for (var i = 0; i < array_length(inventory); i++) {
            ARI.inventory.add(string_to_item_id(inventory[i]));
        }

        //
        var armor = fiddle_get("misc/ari_stats/starting_armor");
        ARI.armor.slot(0).add(string_to_item_id(armor.head));
        ARI.armor.slot(1).add(string_to_item_id(armor.chest));
        ARI.armor.slot(2).add(string_to_item_id(armor.legs));
        ARI.armor.slot(3).add(string_to_item_id(armor.boots));
        ARI.armor.slot(4).add(string_to_item_id(armor.accessory));

        //
        for (var i = 0; i < AnimalKind.LEN; i++) {
            var animal = ANIMAL_PROTOTYPES[i];
            var unlocks = HashSet();
            var keys = animal.variants.keys();
            for (var j = 0; j < array_length(keys); j++) {
                if animal.variants.get(keys[j]).default_unlocked {
                    unlocks.insert(keys[j]);
                }
            }
            ARI.animal_variant_unlocks[i] = unlocks;
        }

        //
        ARI.set_gold(fiddle_get("misc/ari_stats/base_gold"));

        MAXIMUM_REACHED_DUNGEON_LEVEL = 0;
    }

    //
    if world_mod_enabled(WorldMod.TownPlaza) {
        spawn_prios_on_map(GRIDS[LocationId.Town], location_id_to_gm_room(LocationId.Town), "PriorityObjectsPlazaFixed", spawn_priority_object);
        fix_plaza_footsteps();
    } else {
        spawn_prios_on_map(GRIDS[LocationId.Town], location_id_to_gm_room(LocationId.Town), "PriorityObjectsPlazaBroken", spawn_priority_object);
        spawn_prios_on_map(GRIDS[LocationId.Town], location_id_to_gm_room(LocationId.Town), "PriorityGrassPlazaBroken", spawn_priority_grass);
    }

    npcs_on_new_day();

    T2R.update_daily();

    npas_new_day();

    //
    ARI.inbox.on_new_day();

    PLAYTIME = 0;

    //
    portrait_atlas_load("PortraitsSpring");

    CHECK_ACHIEVEMENTS = true;

    trace("Created NewGame in {micro}", get_timer() - start_time);
}

//
function start_character_creation(preset, callback, creation=true) {
    var canvas = ANCHOR.canvas(ANCHOR.screen_canvas)
        .set_layer(AnchorLayer.AboveFader)
        .set_align(Align.Center, Align.Middle)
        .set_size_to_minspec()
        .set_alpha(0)

    var nodes = create_journal_nodes(canvas);
    var menu = ANCHOR.spawn_menu(Menu.Customization, nodes, ARI, preset, creation);

    menu.continue_button = ANCHOR.nine_slice(ANCHOR.screen_canvas);

    menu.continue_button
        .set_align(Align.RightIn, Align.BottomIn)
        .set_size(74, 21)
        .set_xy(-6, -4)
        .set_layer(AnchorLayer.Popup)
        .set_sprites_from_key("spr_ui_button_chunky_arrow")
        .set_label("customization_continue_button")
        .set_think_callback(function(continue_button, canvas) {
            var blocking_menu = ANCHOR.get_menu(Menu.Popup) ?? ANCHOR.get_menu(Menu.Calendar);
            var is_blocked = blocking_menu == undefined ? false : !blocking_menu.close_requested;

            continue_button.set_alpha(is_blocked ? 0 : canvas.get_alpha());
            continue_button.set_unlocked(!is_blocked);
        }, [menu.continue_button, canvas])
        .set_tap_callback(function(menu, callback) {
            menu.request_hide(30);
            new_chain().append(LinkId.Await, function(menu, callback) {
                var menu = ANCHOR.get_menu(Menu.Customization);
                if menu.internal_chain == undefined {
                    callback();
                    menu.close();
                    ANCHOR.free_node(menu.continue_button);
                    return true;
                }
                return false;
            }, [menu, callback])

        }, [menu, callback])
        .add_text_label("misc_local/start_game", COMMON_LUT, CommonLutIndex.Dark)
        .add_glyph(InputId.SecondaryInteract)

    menu.canvas = canvas;
    menu.request_show(30);

    return menu;
}
