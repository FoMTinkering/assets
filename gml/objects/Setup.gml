var setup_obj = object_create(
    "Setup",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            depth = -14999;

            if TEST_SUITE {
                FORMAT_PREFIX = function() {
                    var hex = int_to_hex_string(TICK % 256, 2);
                    return fmt("[{} | {}] ", hex, time_since_boot_str());
                }
            } else {
                FORMAT_PREFIX = function() {
                    var hex = int_to_hex_string(TICK % 256, 2);
                    return fmt("[{}]", hex);
                }
            }

            //
            camera_set_view_size(NORMAL_MINSPEC_WIDTH, NORMAL_MINSPEC_HEIGHT);
            camera_set_view_pos(0, 0);
            strict_layer_set_visible("Instances", true);
            strict_layer_set_visible("Assets", false);
            strict_layer_set_visible("Clouds", false);
            strict_layer_set_visible("Mountains", false);
            background_set_color(c_black, 1.0);

            trace("Starting Setup Create...");
            var timer = get_timer();

            //
            randomize();
            CHAINS = new ChainManager();

            CREATION_VERSION = undefined;
            HUD_TARGET = undefined;
            checksum_set_save_is_tampered(undefined);

            ACHIEVEMENT_CACHE = array_create_ext(Achievement.LEN, function(i) {
                return steam_achievement_is_unlocked(achievement_to_string(i));
            });

            if FROM_GAME {
                TAXI.location_current = undefined;

                //
                SCREEN_FADER.snap_out();
                SCREEN_FADER.fade_in();

                POST_PROCESS = new PostProcessor(POST_PROCESS_DATABASE.world);
                POST_PROCESS.update(hours(12));
                if CHAIN_LIST_HOLDER != undefined {
                    CHAINS.chains = CHAIN_LIST_HOLDER;
                }
            } else {
                if RUN_TATTLETALE {
                    exception_state(create_world_error_context);
                }
                CONTENT_REGISTRY = new ContentRegistry();
                GAME_VERSION = string_to_version(os_get_version());

                var ttv = environment_get_variable("TEST_TARGET_VERSION");
                if ttv == undefined {
                    TEST_TARGET_VERSION = {
                        major: GAME_VERSION.major,
                        minor: GAME_VERSION.minor,
                        patch: GAME_VERSION.patch + 1,
                        pre: undefined,
                    };
                } else {
                    TEST_TARGET_VERSION = string_to_version(ttv);
                }
                initialize_fiddle_movement_speed();

                var generated_settings_file = !file_exists(SETTINGS_PATH);
                SETTINGS = load_settings();

                REQUIREMENT_ALIASES = load_requirement_aliases();
                REQ_CHECK = create_req_check();

                try {
                    local_set_language(SETTINGS.get("language"));
                } catch(_) {
                    local_set_language("eng");
                }
                PRONOUNS = load_pronouns();
                load_locations();

                FOCUS = new Focus();

                MUSIC_PLAYER = new SceneAudioPlayer(menu_music_selector);
                AMBIENCE_PLAYER = new SceneAudioPlayer(menu_ambience_selector);
                AMBIENCE_PLAYER.play_all_children = true;
                AMBIENCE_PLAYER.crossfade = true;

                GAMEPADS_LAST_FRAME = gamepads_connected();

                INPUT = new Input();
                try {
                    BINDINGS = saved_bindings_to_bindings(SETTINGS.get("bindings"));
                } catch (e) {
                    warn("Failed to load bindings! Using defaults... ({})", e);
                    BINDINGS = saved_bindings_to_bindings(default_input_id_bindings());
                }

                //
                SETTINGS.set("bindings", BINDINGS.serialize());

                DISPLAY = create_display();
                CAMERA = DISPLAY.create_camera();
                POST_PROCESS_DATABASE = setup_post_process_database();
                POST_PROCESS = new PostProcessor(POST_PROCESS_DATABASE.world);
                POST_PROCESS.update(hours(12));

                if DEBUG_TOOLS {
                    window_raise();
                }

                //

                //
                SHADOW_DICTIONARY = ShadowDictionary();
                SPRITE_FONTS = load_sprite_fonts();
                TEXT_STYLES = load_text_styles();
                MENUS = load_menus();
                create_anchor();
                TANGO = new Tango();
                NODE_PROTOTYPES = create_node_prototypes();
                BLUEPRINT_PROTOTYPES = create_blueprint_prototypes();
                PRIORITY_OBJECTS = create_priority_objects();
                PRIORITY_GRASS = create_priority_grass();
                CURSOR = new Cursor(
                    steam_on_deck()
                        ? CursorRender.None
                        : (SETTINGS.get("native_cursor") ? CursorRender.Software : CursorRender.OnGpu)
                );
                PAUSE_STATUS = PauseStatus.EMPTY;
                OUTLINE_DICTIONARY = generate_sprite_remap_dictionary("animation/outlines.json");

                TAXI = new Taxi();
                frame_finish(execute_at_end_of_frame);

                INFUSIONS = load_infusions();
                ITEM_PROTOTYPES = create_item_prototypes();

                T2R = new T2r();
                PLAYER_ANIMATION_DATABASE = new PlayerAnimationDatabase();
                CUTSCENES = load_cutscenes();

                DUNGEON_ROOMS = load_dungeon_rooms();

                var data = load_bugs();
                BUGS = data.bugs;
                BUG_DISTRIBUTION = data.distribution;
                WORLD_MODS = load_world_mods();
                FISH = create_fish_prototypes();
                FISH_DISTRIBUTIONS = create_fish_distributions();
                DIVESPOT_DISTRIBUTION = create_divespot_distributions();
                FISH_CHEST = create_fish_chests();
                WEATHER_PROTOTYPES = load_weather();

                WEATHER_COUNTS = load_weather_counts();
                LOAD_SEQUENCE = new LoadSequence();
                ACTIVITIES = load_activities();
                ROUTINES = load_routines();
                BARK_PROTOTYPES = load_bark_prototypes();
                BARK_OPENING_INFO = load_bark_opening_info();
                BARK_CLOSING_INFO = load_bark_closing_info();
                DRAGON_SHRINE_DATA = load_dragon_shrine_data();
                MUSEUM_DATA = museum_parse_sets();
                WOODCRAFTING_UI_DATA = load_crafting_ui_data("woodcrafting");
                COOKING_UI_DATA = load_cooking_ui_data();
                BLACKSMITHING_UI_DATA = load_crafting_ui_data("blacksmithing");
                MILLING_UI_DATA = load_crafting_ui_data("milling");
                REFINING_UI_DATA = load_crafting_ui_data("refining");
                DRAGON_FORGING_UI_DATA = load_crafting_ui_data("dragon_forging");
                CUSTOMIZATION_UI_DATA = load_customization_ui_data();
                ANIMAL_PROTOTYPES = load_animals();
                PET_PROTOTYPE = load_pet_prototype();
                NON_PLAYER_ANIMAL_PROTOTYPES = load_npa_prototypes();
                SPELLS = load_spells();
                QUEST_TAG_REGISTRATIONS = load_quest_tag_registrations();
                QUESTS = load_quests();
                QUESTS_BY_CATEGORY = gather_quests_by_category();
                CROWN_QUESTS = load_crown_quests();
                TALI_CHALLENGES = load_tali_challenges();
                STILLWELL_CHALLENGES = load_stillwell_challenges();
                LETTERS = load_letters();
                RENOWN = load_renown();
                FESTIVALS = load_festivals();
                STORES = load_stores();
                CHICKEN_STATUE_REWARDS = parse_statue_rewards("chicken_statue");
                WISHING_WELL_REWARDS = parse_statue_rewards("wishing_well");
                MONSTER_PROTOTYPES = create_monster_prototypes();
                GROW_BACK = new GrowBack();
                NPC_PROTOTYPES = load_npc_prototypes();
                CAMEO_PROTOTYPES = load_cameo_prototypes();
                ACHIEVEMENTS = parse_achievements();
                ACHIEVEMENTS_USING_REQUIREMENT = gather_achievement_requirement_usage();
                CHILDREN = load_children_prototypes();
                create_fiddle_parsers();
                initialize_xp_values();
                preload_button_sprite_cache();
                SPRINKLER_TIMER_ARRAY = create_frame_timings_data(spr_object_water_sprite_statue_v1_spring);
                ELIGIBLE_DATE_DAYS = apply_func(fiddle_get("misc/date_days"), string_to_day);
                ELIGIBLE_DATE_STATUSES = fiddle_get("misc/statuses_eligible_for_dates");
                DATES = load_dates();
                MAP_HUBS = load_map_hubs();
                SONGS = load_songs();
                BELL_SOUNDS = load_bell_sounds();

                //
                if DEBUG_ASSERTIONS {
                    var true_quests = HashSetFromArray(QUESTS.keys());
                    var true_scenes = HashSetFromArray(CUTSCENES.keys());
                    var true_letters = HashSetFromArray(LETTERS.keys());

                    var registry_quests = HashSetFromArray(CONTENT_REGISTRY.quests);
                    var registry_scenes = HashSetFromArray(CONTENT_REGISTRY.cutscenes);
                    var registry_letters = HashSetFromArray(CONTENT_REGISTRY.letters);

                    var extra_quests = true_quests.find_missing(registry_quests);
                    var missing_quests = registry_quests.find_missing(true_quests);

                    var extra_scenes = true_scenes.find_missing(registry_scenes);
                    var missing_scenes = registry_scenes.find_missing(true_scenes);

                    var extra_letters = true_letters.find_missing(registry_letters);
                    var missing_letters = registry_letters.find_missing(true_letters);


                    var theres_something = !extra_quests.is_empty()
                        || !missing_quests.is_empty()
                        || !extra_scenes.is_empty()
                        || !missing_scenes.is_empty()
                        || !extra_letters.is_empty()
                        || !missing_letters.is_empty();

                    if theres_something {
                        crash(
                            "Discrepancies were detected within ContentRegistry:\n\nextra_quests: {}\nmissing_quests: {}\nextra_scenes: {}\nmissing_scenes: {}\nextra_letters: {}\nmissing_letters: {}",
                            extra_quests.join(", "),
                            missing_quests.join(", "),
                            extra_scenes.join(", "),
                            missing_scenes.join(", "),
                            extra_letters.join(", "),
                            missing_letters.join(", "),
                        );
                    }
                }

                if DEBUG_TOOLS {
                    BUGGER = new Bugger();
                    bugger_initialize();
                }

                save_settings();

                trace("Completed Setup in {micro}!", get_timer() - timer);
            }

            MUSIC_PLAYER.selector = menu_music_selector;
            AMBIENCE_PLAYER.selector = menu_ambience_selector;

            MUSIC_PLAYER.refresh();
            AMBIENCE_PLAYER.refresh();

            //
            self.save_manager = new SaveManager();

            CAMERA.on_room_start();
            ANCHOR.on_room_start();

            self.load_menu_data = List();
            var saves = self.save_manager.get_saves_ordered();
            var any_fail = false;
            for (var i = 0; i < array_length(saves); i++) {
                var path = saves[i];
                var load_bundle = self.save_manager.manifest.get(path);
                var loader = load_bundle.loader;
                var fail = false;

                var header = loader.load_file("header");

                if header == undefined {
                    fail = true;
                } else {
                    try {
                        var info = loader.load_file("info");

                        //
                        if version_is_ahead(string_to_version("0.11.6"), info.version) {
                            zero_eleven_six_hair_patch(header.preset);
                        }

                        header.preset = player_animation_assets_deserialize(header.preset);
                        header.load_bundle = load_bundle;
                        header.path = path;
                        self.load_menu_data.push(header);
                    } catch(e) {
                        fail = true;
                        warn("Header had corrupt data at '{}'!", path);
                    }
                }

                if fail {
                    loader.mark_invalid();
                    self.save_manager.manifest.remove(path);
                    any_fail = true;
                }
            }

            if any_fail || self.save_manager.bad_vaults || self.save_manager.bad_saves {
                DISPLAY_INVALID_SAVE_POPUP = 2;
            }

            if generated_settings_file && local_language() != "eng" {
                //
                //
                //
                DISPLAY_BETA_LANGUAGE_WARNING = true;
            }

            //
            var menu = ANCHOR.spawn_menu(Menu.Title);
            menu.start();

            function enter_game(load_state) {
                //
                DISPLAY.set_expansion(SETTINGS.get(window_is_fullscreen() ? "fscreen_expansion" : "window_expansion"));

                var is_manual_save = false;
                var run_prologue = false;
                var location_position = undefined;

                switch load_state.type {
                    case LoadStateId.New:
                        is_manual_save = false;
                        run_prologue = STORY_ENABLED;
                        location_position = run_prologue
                            ? new LocationPosition(LocationId.AdelinesOffice, Vec2Zero())
                            : new LocationPosition(
                                LocationId.PlayerHome,
                                ALL_UNLOCKS ? Vec2(102, 125) : Vec2(120, 125),
                            );
                        break;
                    case LoadStateId.Load:
                        is_manual_save = load_state.is_manual_save;
                        var player_data = load_state.loader.load_file("player");
                        if player_data != undefined && player_data[$ "position"] != undefined {
                            //
                            location_position = new LocationPosition(
                                string_to_location_id(player_data.home_location),
                                array_to_vec2(player_data.position),
                            )
                        } else {
                            location_position = deserialize_location_position(player_data.save_position);
                        }
                        break;
                    default: impossible("unexpected load_state type: {}", load_state.type)
                }
                self.cached_load_state = load_state;

                TAXI.enter_world(is_manual_save, run_prologue, location_position);
                //
                new_chain().append(
                    LinkId.Await,
                    function() {
                        if !is_world_room(room()) {
                            return false;
                        }

                        var load_state = Setup.cached_load_state;

                        //
                        //
                        //
                        //
                        //
                        //
                        //
                        //
                        //
                        //
                        //
                        //
                        //
                        //
                        //
                        instance_destroy(Setup);

                        //
                        instance_create_depth(0, 0, 0, Game, { load_state } );

                        //
                        with Game {
                            object_event(object("Game"), ObjectEvent.RoomStart)();
                        }

                        //
                        LOAD_SEQUENCE.finish();

                        return true;
                    }
                );
                return false;
            }

            switch AUTO_START {
                case "new":
                    menu.enter_game(LoadState.New({
                        name: "Ari",
                        farm_name: "Mistgrove Farm",
                        pronouns: default_pronouns(),
                        presets: List(create_default_player_animation_assets()),
                        preset_index_selected: 0,
                        birthday: DEFAULT_ARI_BIRTHDAY,
                    }));
                    break;
                case "continue":
                    var saves = Setup.save_manager.get_saves_ordered();
                    if array_length(saves) == 0 {
                        warn("Tried to auto start but no save to continue!");
                    } else {
                        var data_bundle = Setup.save_manager.manifest.get(saves[0]);
                        menu.enter_game(LoadState.Load(data_bundle));
                    }
                    break;
                default: //
            }

            self.manual_crash_timer = 0;
            draw_post_process(DISPLAY.on_draw_post_process);
            draw_to_screen(DISPLAY.on_draw_gui);

            if FROM_GAME == false && TEST_SUITE {
                setup_test_suite_utils();
                run_test_suite();
            }
            FROM_GAME = false;
        },
        step_begin: function() {
            TICK++;

            INPUT.begin_frame();

            if DEBUG_TOOLS {
                BUGGER.update();
            }
            CHAINS.on_begin_step();
            ANCHOR.on_begin_step();
        },
        step_end: function() {
            CURSOR.step();
            CAMERA.update();
            GLYPH_GUIDE.process();

            FOCUS.on_end_step();

            MUSIC_PLAYER.on_step();
            AMBIENCE_PLAYER.on_step();

            if keyboard_check(vk_control) && keyboard_check(vk_shift) && keyboard_check(vk_f12) {
                self.manual_crash_timer += 1;
                if self.manual_crash_timer >= 30 {
                    var crash_kind = environment_get_variable("MISTRIA_TEST_CRASH");
                    switch crash_kind {
                        case "script":
                            crash("Test Crash");
                            break;
                        case "native":
                            __native_crash("Test Crash");
                            break;
                        default:
                            self.manual_crash_timer = 0;
                            warn("unknown crash kind: {}", crash_kind);
                            break;
                    }
                }
            } else {
                self.manual_crash_timer = 0;
            }
        },
        room_start: function() {
            if is_world_room(room()) {
                //
                return;
            }
        },
    }
);

//
//
object_persists_on_room_change(setup_obj);
