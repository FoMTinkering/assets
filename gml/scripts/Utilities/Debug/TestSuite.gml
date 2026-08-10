#macro TS_CHAIN global.__ts_chain
TS_CHAIN = undefined;

#macro TEST_BREADCRUMB global.__test_breadcrumb
TEST_BREADCRUMB = undefined;

#macro SPILLOVER_LOGS global.__spillover_logs
SPILLOVER_LOGS = List();

#macro MENU_TEST_LOG global.__menu_test_log
MENU_TEST_LOG = HashSet();

#macro NPC_TEST_TARGET global.__npc_test_target
NPC_TEST_TARGET = undefined;

#macro SE global.__ts_spe
SE = undefined;

#macro STORY_EXECUTOR_RUNNING (SE != undefined)

#macro TS_SAVE_UPGRADE global.__ts_save_upgrade
TS_SAVE_UPGRADE = false;

#macro CURRENT_TEST_SUITE_SAVE global.__current_ts_save
CURRENT_TEST_SUITE_SAVE = undefined;

#macro TEST_SUITE_SAVE_MAPPINGS global.__test_suite_save_mappings
TEST_SUITE_SAVE_MAPPINGS = undefined;

#macro TEST_SUITE_MENU_TARGET global.__test_suite_menu_target
TEST_SUITE_MENU_TARGET = undefined;

global.__can_proceed = false;

function run_test_suite() {
    //
    clean_orphan_dumps();

    TS_CHAIN = new_chain();

    TEST_SUITE_SAVE_MAPPINGS = Map();

    //
    var output = cli_test_input();

    NPC_TEST_TARGET = opt_and_then(output.npc_test_target, string_to_npc_id);

    //
    var saves_to_load = [];
    if array_length(output.saves) > 0 {
        CUTSCENES_CAN_PLAY = false;

        var upgrade_target_path = copy_upgrade_targets();
        var paths = get_files_in_dir(upgrade_target_path);
        var latest_save_name = format("game-{}-{}", GAME_VERSION.minor, GAME_VERSION.patch);

        for (var save_idx = 0; save_idx < array_length(output.saves); save_idx++) {
            var save_to_load = output.saves[save_idx];

            //
            if save_to_load == "all" {
                for (var i = 0; i < paths.count(); i++) {
                    var input_path = paths.get(i);
                    var output_path = exact_save_path(save_idx + i, false);
                    TEST_SUITE_SAVE_MAPPINGS.insert(output_path, input_path);
                    var sav = test_suite_gather_save(input_path, output_path, save_idx + i);
                    if sav != undefined {
                        array_push(
                            saves_to_load,
                            sav
                        );
                    }
                }
                continue;
            } else if save_to_load == "latest" {
                save_to_load = latest_save_name;
            } else if save_to_load == "minors" {
                for (var i = 0; i < paths.count(); i++) {
                    var input_path = paths.get(i);
                    if string_ends_with(input_path, "-0.sav") == false {
                        continue;
                    }
                    var output_path = exact_save_path(save_idx + i, false);
                    TEST_SUITE_SAVE_MAPPINGS.insert(output_path, input_path);
                    var sav = test_suite_gather_save(input_path, output_path, save_idx + i);
                    if sav != undefined {
                        array_push(
                            saves_to_load,
                            sav
                        );
                    }
                }
                continue;
            }
            save_to_load = format("{}.sav", save_to_load);

            var idx = paths.find(function(input_path, save_to_load) {
                return string_ends_with(input_path, save_to_load);
            }, save_to_load);
            assert_neq(idx, undefined, "Couldn't find any save by name `{}`!", save_to_load);

            var input_path = paths.get(idx);
            var output_path = exact_save_path(save_idx, false);
            var sav = test_suite_gather_save(input_path, output_path, save_idx);
            if sav != undefined {
                array_push(
                    saves_to_load,
                    sav,
                );
            }
        }
    }

    var seasons = deserialize_array_bool(output.seasons, string_to_season, Season.LEN);

    info(
        "RUNNING WITH SEASONS: {}{}{}{}",
        seasons[Season.Spring] ? "Spring, " : "",
        seasons[Season.Summer] ? "Summer, " : "",
        seasons[Season.Fall] ? "Fall, " : "",
        seasons[Season.Winter] ? "Winter, " : "",
    );


    var tests_to_fire = [];

    //
    for (var i = 0; i < array_length(output.tests_to_run); i++) {
        switch output.tests_to_run[i] {
            case "all":
                tests_to_fire = array_concat(tests_to_fire, TS_TESTS.to_array());
                break;
            case "save_upgrade":
                info("Running save upgrade tests...");
                var new_tests = TS_TESTS.clone();
                new_tests.retain(function(e) {
                    return e[$ "save_upgrade"] == true;
                });
                tests_to_fire = array_concat(tests_to_fire, new_tests.to_array());
                TS_SAVE_UPGRADE = true;
                break;
            case undefined:
            case "":
            case "standard":
                info("Running standard tests...");
                new_tests = TS_TESTS.clone();
                new_tests.retain(function(e) {
                    return e[$ "exclude_from_standard"] != true;
                });
                tests_to_fire = array_concat(tests_to_fire, new_tests.to_array());
                break;
            default:
                var test = TS_TESTS.find_value(function(e, n) {
                    return e.name == n;
                }, output.tests_to_run[i]);
                assert_neq(test, undefined, "Could not find a test named '{}'!", output.tests_to_run[i]);
                array_push(tests_to_fire, test);
                break;
        }

    }

    for (var i = 0; i < array_length(output.languages); i++) {
        var language = output.languages[i];

        if array_is_empty(saves_to_load) {
            execute_suite(tests_to_fire, seasons, language);
        } else {
            for (var j = 0; j < array_length(saves_to_load); j++) {
                execute_suite(tests_to_fire, seasons, language, saves_to_load[j]);
                TS_CHAIN.append(LinkId.Function, function(j, saves_to_load) {
                    info("Saves complete: {}/{}", j + 1, array_length(saves_to_load));
                }, [j, saves_to_load]);
            }
        }
    }

    //
    TS_CHAIN.append(LinkId.Function, function() {
        directory_destroy(CONFIG_DIRECTORY);
    });

    //
    TS_CHAIN.append(LinkId.Function, function() {
        info("All tests passed successfully!");
        game_end();
    });
}

function execute_suite(tests_to_fire, seasons_to_run, language, save_bundle) {
    TS_CHAIN.append(LinkId.Function, function(language) {
        local_set_language(language);
    }, [language]);

    TS_CHAIN.append(LinkId.Function, function() {
        ANCHOR.get_menu(Menu.Title).close();
    });

    if save_bundle != undefined {
        TS_CHAIN.append(LinkId.Function, function(save_bundle) {
            trace("Loading targeted save...");
            var path = save_bundle.exact_save_path;
            CURRENT_TEST_SUITE_SAVE = TEST_SUITE_SAVE_MAPPINGS.get_or(path, path);
            Setup.enter_game(LoadState.Load({
                info: save_bundle.info,
                game_ident: save_bundle.game_ident,
                loader: new RustLoader(vault_open_vault(save_bundle.exact_save_path), save_bundle.exact_save_path),
                save_ident: undefined,
                is_manual: false,
            }));
        }, [save_bundle]);
    } else {
        TS_CHAIN.append(LinkId.Function, function() {
            //
            info("Starting a new game...");
            Setup.enter_game(LoadState.New({
                name: local_get("misc_local/default_player_name"),
                farm_name: local_get("misc_local/default_farm_name"),
                pronouns: default_pronouns(),
                presets: List(create_default_player_animation_assets()),
                preset_index_selected: 0,
                birthday: DEFAULT_ARI_BIRTHDAY,
            }));
        })
    }

    //
    TS_CHAIN.append(LinkId.Await, function() {
        return instance_exists(Game);
    });

    var current_season = Season.Spring;
    for (var i = 0; i < Season.LEN; i++) {
        if !seasons_to_run[i] {
            continue;
        }

        while current_season != i {
            TS_CHAIN.append(LinkId.Function, function() {
                __ts_advance_to_next_season();
            });
            current_season += 1;
        }

        for (var j = 0; j < array_length(tests_to_fire); j++) {
            var test = tests_to_fire[j];
            if test[$ "run_once"] == true && test[$ "ran_already"] == true {
                TS_CHAIN.append(LinkId.Function, function(test) {
                    trace("Skipping test: '{}' (marked as `run_once`)", test.name);
                }, [test]);
            } else {
                TS_CHAIN.append(LinkId.Function, function(test) {
                    trace("Executing test: '{}'...", test.name);
                }, [test]);
                test.ran_already = true;
                test.call(TS_CHAIN);
            }
        }
    }

    //
    if seasons_to_run[Season.Winter] {
        TS_CHAIN.append(LinkId.Function, function() {
            __ts_advance_to_next_season();
        });
    }

    //
    TS_CHAIN.append(LinkId.Function, function() {
        CHAIN_LIST_HOLDER = [TS_CHAIN];
        Game.exit_to_menu();
    });
    TS_CHAIN.append(LinkId.Await, function() {
        return ANCHOR.get_menu(Menu.Title) != undefined;
    });
}

function run_tool(item_id, pos, chain) {
    chain.append(LinkId.Function, function(item_id, pos) {
        use_item_fast(new LiveItem(item_id), pos);
    }, [item_id, pos]);
    chain.append(LinkId.Timer, 1);
    chain.append(LinkId.Await, function() {
        return obj_ari.fsm.check_state_inclusive(PlayerState.Default);
    });
}

//
#macro CHAIN_LIST_HOLDER global.__chain_list_holder
CHAIN_LIST_HOLDER = undefined;
#macro TS_TESTS global.__ts_tests
TS_TESTS = List();

//
function __ts_travel_to(location_id, chain) {
    chain
        .append(LinkId.Function, function(location_id) {
            if CURRENT_LOCATION_ID != location_id {
                goto_location_id(location_id, true);
            }
        }, [location_id])
        .append(LinkId.Timer, 1)
}

function __ts_advance_to_next_season() {
    repeat 28 - CALENDAR.day() {
        TS_CHAIN.insert_chain(new Chain()
            .append(LinkId.Function, function() {
                end_day(false);
                new_day();
            })
        );
    }
}

function __ts_test_crop(chain, object_id, expect_regrow) {
    __ts_travel_to(LocationId.Farm, chain);
    chain.append(LinkId.Function, function() {
        obj_ari.x = 112 * 8;
        obj_ari.y = 112 * 8;
        WEATHER.set_weather(Weather.Calm);
    });
    chain.append(LinkId.Timer, 1);
    chain.append(LinkId.Function, function(object_id, expect_regrow) {
        var grid_x = obj_ari.x div 8;
        var grid_y = obj_ari.y div 8;
        var proto = NODE_PROTOTYPES[object_id];

        for (var xx = 0; xx < 2; xx++) {
            for (var yy = 0; yy < 2; yy++) {
                //
                var ni = GRID.node_index_for_cell(grid_x + xx, grid_y + yy);
                erase_object_node(GRID, ni);
                erase_rug_node(GRID, ni);
            }
        }

        //
        GRID.write_ground(grid_x, grid_y, GroundKind.Soil);
        var parent = GRID.write_node(grid_x, grid_y, object_id);
        assert_neq(parent, undefined, "{ObjectId} failed to write at {}x{}", object_id, grid_x, grid_y);

        var ni = GRID.node_index_for_cell(grid_x, grid_y);
        for (var i = 0; i < proto.day_to_stage.count(); i++) {
            assert_eq(
                GRID.node_parent[ni].day_count,
                i,
                "Our {ObjectId} failed to increment its day count!",
                object_id,
            );
            assert_eq(
                GRID.node_parent[ni].stage,
                proto.day_to_stage.get(i),
                "Our {ObjectId} failed to grow! Expected stage {} on day {}, but got {}.",
                object_id,
                proto.day_to_stage.get(i),
                i,
                GRID.node_parent[ni].stage,
            );

            //
            water_node(GRID, grid_x, grid_y);
            assert(GRID.node_terrain_is_watered[ni], "We failed to water our {ObjectId}!", object_id);
            GRID.new_day();
        }

        var success = interact(GRID.node_parent[ni]);
        assert(success, "We failed to harvest our {ObjectId}!", object_id);
        if expect_regrow {
            assert_eq(GRID.node_object_id[ni], object_id, "We are missing our {ObjectId}!", object_id);
            assert(GRID.node_parent[ni].regrow_cycle, "{ObjectId} did not have regrow cycle set!", object_id);
            assert_eq(GRID.node_parent[ni].day_count, 0, "{ObjectId}'s day count is not 0!", object_id);
            assert_eq(
                GRID.node_parent[ni].stage,
                proto.day_to_stage.last() - 1,
                "{ObjectId} did not reset to the correct stage",
                object_id,
            );
        } else {
            assert_eq(GRID.node_object_id[ni], undefined, "An object was left behind!")
        }
    }, [object_id, expect_regrow]);
}
function disable_all_but(perk) {
    perk = is_array(perk) ? perk : [perk];
    for (var i = 0; i < Perk.LEN; i++) {
        ARI.perks_active[i] = array_contains(perk, i);
    }
}

function await_items(chain, count, item_id) {
    chain.append(LinkId.Function, function() {
        ARI.inventory.drain();
        with obj_animation_effect {
            if image_idx_func != undefined {
                image_idx_func();
                instance_destroy();
            }
        }
    });
    chain.append(LinkId.Await, function(count, item_id_check) {
        item_id_check = is_array(item_id_check) ? item_id_check : [item_id_check];
        var my_count = 0;
        with obj_item {
            self.x = obj_ari.x;
            self.y = obj_ari.y;
            if array_contains(item_id_check, item_id) {
                my_count += 1;
            }
        }
        return my_count >= count;
    }, [count, item_id]);
    chain.append(LinkId.Function, function(item_id_check) {
        item_id_check = is_array(item_id_check) ? item_id_check : [item_id_check];
        with obj_item {
            if array_contains(item_id_check, item_id) {
                //
                for (var i = 0; i < items.count(); i++) {
                    var item = items.get(i);
                    if item.auto_use {
                        use_item_fast(item);
                    } else if ARI.inventory.can_add(item) {
                        ARI.give_item(item, 1, true, true, false);
                    } else {
                        break;
                    }
                }
                instance_destroy();
            }
        }
    }, [item_id]);
}

function set_player_spell(spell, chain) {
    chain.append(LinkId.Function, function(spell) {
        ARI.set_mana(SPELLS[spell].cost);
        obj_ari.fsm.blackboard.set("spell", spell);
        obj_ari.fsm.blackboard.set("hold_to_use", false);
        obj_ari.fsm.change_state(PlayerState.Spell);
    }, [spell]);
    chain.append(LinkId.Timer, 160);
    chain.append(LinkId.Function, function(spell) {
        assert(ARI.get_mana() == 0, "Ari should have no more mana after using this spell {Spell}", spell);
    }, [spell]);
}

TS_TESTS.push({
    name: "pronoun_macro_validation",
    call: function(chain) {
        chain.append(LinkId.Function, function() {
            var errors = local_validate_macros();
            if errors != undefined {
                crash(errors);
            }
        })
    }
});

TS_TESTS.push({
    name: "unit_tests",
    call: function(chain) {
        chain.append(LinkId.Function, function() {
            assert(run_unit_tests().succeeded, "Unit tests did not pass!");
        });
    },
    save_upgrade: true,
    save_upgrade_light: true,
    run_once: true,
});

TS_TESTS.push({
    name: "kill_monsters",
    run_once: true,
    call: function(chain) {
        __ts_travel_to(LocationId.PlayerHome, chain);

        var death_state = [
            MushroomState.Dying,
            RockclodState.Dying,
            SaplingState.Dying,
            EnchanternState.Dying,
            MiteState.Dying,
            BatState.Dying,
            MimicState.Dying,
            SpiritState.Dying,
            CatState.Dying,
            RockStackState.Dying,
            StatueState.Dying,
            TomeState.Dying
        ];

        for (var i = 0; i < MonsterId.LEN; i++) {
            chain.append(LinkId.Function, function(monster) {
                spawn_monster(obj_ari.x, obj_ari.y, monster);
            }, [i]);
            chain.append(LinkId.Timer, 1);
            chain.append(LinkId.Function, function(state) {
                with par_monster {
                    fsm.change_state(state);
                }
            }, [death_state[MONSTER_PROTOTYPES[i].monster_category]]);
            chain.append(LinkId.Await, function() {
                return instance_exists(par_monster) == false;
            });
        }
    },
});

TS_TESTS.push({
    name: "water_statues",
    run_once: true,
    call: function(chain) {
        __ts_travel_to(LocationId.Farm, chain);

        chain.append(LinkId.Function, function() {
            var free_location = Vec2(124, 34);
            var ni = GRID.node_index_for_cell(free_location.x, free_location.y);

            if ni != undefined {
                erase_object_node(GRID, ni);
            }

            var statue_node = GRID.write_node(free_location.x, free_location.y, ObjectId.WaterSpriteStatueV1);

            obj_ari.x = free_location.x * 8;
            obj_ari.y = free_location.y * 8 - 4;

            //
            var selection = find_nearest_interactable(obj_ari.collision_list, obj_ari);
            assert(selection == undefined, "No interaction should've been found, but one was found: {}", selection);

            //
            ARI.inventory.slot(0).drain();
            ARI.give_item(new LiveItem(ItemId.EssenceStoneLarge), 1);
            selection = find_nearest_interactable(obj_ari.collision_list, obj_ari);
            assert(selection != undefined, "No interaction was found, but there should have been one");
            interact(selection.node);
            assert(statue_node.essence_supply > 0, "the statue node supply did not increment after the interaction");

            //
            var interactions = selection.node.renderer.interactions;
            for (var i = 0, ic = interactions.count(); i < ic; i++) {
                var interaction = interactions.get(i);
                if interaction.local_key == "misc_local/check_charge" {
                    interaction.callback();
                    break;
                }
            }

            var anchor_menu = ANCHOR.get_menu(Menu.Textbox);
            assert(anchor_menu != undefined, "Despite interacting with a charged statue, no prompt appeared for the interaction");
            anchor_menu.close(true);
            pick_node(GRID, free_location.x, free_location.y, ITEM_PROTOTYPES[ItemId.PickAxeMistril], 0, undefined, new TangoDoppel());
        });
        await_items(chain, 1, ItemId.EssenceStoneLarge);
    }
})

TS_TESTS.push({
    name: "animal_feed",
    run_once: true,
    call: function(chain) {
        __ts_travel_to(LocationId.PlayerHome, chain);
        chain.append(LinkId.Function, function() {
            obj_pet.x = 32;
            obj_pet.y = 32;

            with par_NPC {
                self.x = 32;
                self.y = 32;
            }

            ARI.inventory.slot(0).drain();
            ARI.give_item(new LiveItem(ItemId.Cherry), 1);
            ARI.held_item_index = 0;
            var animal_data = get_all_animals().get(0);

            animal_data.location_position = new LocationPosition(LocationId.PlayerHome, Vec2(obj_ari.x, obj_ari.y));

            var animal_instance = instance_create_layer(
                obj_ari.x,
                obj_ari.y,
                "Instances",
                obj_player_animal,
                {
                    me: animal_data,
                }
            );

            var selection = find_nearest_interactable(obj_ari.collision_list, obj_ari);

            assert(selection != undefined, "No interaction was found despite the player being next to the animal");

            var cback = selection.attempt_interact(true);
            assert(cback != undefined, "Animal did not give back a callback");
            cback();

            var pass = true;
            for(var i = 0; i < ARI.inventory.size(); i++) {
                var slot = ARI.inventory.slot(i);
                if slot.item != undefined && slot.item.item_id == ItemId.Cherry {
                    pass = false;
                    break;
                }
            }

            assert(pass, "The fed item didn't disappear from the inventory slot");

            animal_instance.me.has_eaten = false;
            ARI.give_item(new LiveItem(ItemId.WornTable), 1);

            var selection = find_nearest_interactable(obj_ari.collision_list, obj_ari);

            assert(selection != undefined, "No interaction was found despite the player being next to the animal");
            cback = selection.attempt_interact(true);
            assert(cback != undefined, "Animal did not give back a callback");
            cback();

            assert(ARI.inventory.slot(ARI.held_item_index).count == 1, "The fed item disappeared from the inventory slot despite being a worn table");
        });

        __ts_travel_to(LocationId.Farm, chain);

        chain.append(LinkId.Function, function() {
            var grid = GRIDS[LocationId.Farm];

            for (var xx = 0, xxc = grid.dims.x; xx < xxc; xx++) {
                for (var yy = 0, yyc = grid.dims.y; yy < yyc; yy++) {
                    var node_idx = grid.node_index_for_cell(xx, yy);
                    if object_id_to_object_category(grid.node_object_id[node_idx]) != ObjectCategory.Building {
                        erase_object_node(grid, node_idx);
                    }
                }
            }
            obj_ari.y += 200;
            obj_ari.x -= 34;

            var animal_data = get_all_animals().get(1);

            animal_data.location_position = new LocationPosition(LocationId.PlayerHome, Vec2(obj_ari.x, obj_ari.y));

            var animal_real = instance_create_layer(
                obj_ari.x,
                obj_ari.y,
                "Instances",
                obj_player_animal,
                {
                    me: animal_data,
                }
            );

            grid.write_node(obj_ari.x div 8, obj_ari.y div 8, ObjectId.Turnip, CropFlag.SPAWN_GROWN);

            animal_real.try_find_food();

            obj_ari.y -= 18;
            assert(animal_real.wants_to_eat != undefined, "Animal should be attempting to eat the turnip, but it isn't");
        });

        chain.append(LinkId.Timer, minutes(fiddle_get("misc/eat_time")) / GAME_SECONDS_PER_FRAME + 120);

        chain.append(LinkId.Function, function() {
            var grid = GRIDS[LocationId.Farm];
            with obj_player_animal {
                var node_index = grid.node_index_for_cell(obj_ari.x div 8, (obj_ari.y + 18) div 8);
                assert(grid.node_object_id[node_index] == undefined, "{ObjectId} was found where the turnip was written, but the turnip should've been eaten", grid.node_object_id[node_index]);
            }
        });
    }
});

TS_TESTS.push({
    name: "wedding_parties",
    run_once: true,
    call: function(chain) {
        chain.append(LinkId.Function, function() {
            var cache = array_create_ext(NpcId.LEN, function(i) {
                return NPCS[i].heart_points;
            });
            for (var i = 0; i < NpcId.LEN; i++) {
                if NPC_PROTOTYPES[i].dateable {
                    repeat 50 {
                        for (var j = 0; j < NpcId.LEN; j++) {
                            NPCS[j].heart_points = irandom(npc_heart_level_to_points(10));
                        }

                        var chart = wedding_party_for(i);
                        var at_ceremony = [];
                        var c_keys = struct_get_names(chart.ceremony);
                        for (var j = 0; j < array_length(c_keys); j++) {
                            array_push(at_ceremony, chart.ceremony[$ c_keys[j]]);
                        }
                        var at_reception = [];
                        var r_keys = struct_get_names(chart.reception);
                        for (var j = 0; j < array_length(r_keys); j++) {
                            array_push(at_reception, chart.reception[$ r_keys[j]]);
                        }


                        for (var j = 0; j < NpcId.LEN; j++) {
                            if NPCS[j].is_animal()
                                || j == i
                                || array_contains(NPC_PROTOTYPES[j].tags, "vendor") {
                                continue;
                            }

                            var name = npc_id_to_string(j);
                            assert(
                                array_contains(at_ceremony, name) || j == NpcId.Elsie,
                                "{NpcId} was not at the ceremony for {NpcId}! {}",
                                j,
                                i,
                                chart.ceremony,
                            );
                            assert(
                                array_contains(at_reception, name),
                                "{NpcId} was not at the reception for {NpcId}! {}",
                                j,
                                i,
                                chart.reception,
                            );
                        }
                    }
                }
            }
            for (var i = 0; i < NpcId.LEN; i++) {
                NPCS[i].heart_points = cache[i];
            }
        })
    }
})

TS_TESTS.push({
    name: "perks",
    run_once: true,
    call: function(chain) {
        __ts_travel_to(LocationId.Farm, chain);
        chain.append(LinkId.Function, function() {
            for (var xx = 0, xxc = GRID.dims.x; xx < xxc; xx++) {
                for (var yy = 0, yyc = GRID.dims.y; yy < yyc; yy++) {
                    var node_index = GRID.node_index_for_cell(xx, yy);
                    erase_object_node(GRID, node_index);
                }
            }
        });

        chain.append(LinkId.Function, function() {
            disable_all_but([Perk.TimeToEat, Perk.TimeToEatTwo, Perk.TimeToEatThree]);
            var recipe = ITEM_PROTOTYPES[ItemId.DeviledEggs].recipe.components.clone();
            var duration = recipe.get(recipe.find(function(e) {
                return e.type == RecipeComponentType.Duration;
            }));
            var time = get_modified_component_count(duration, RecipeContext.Cooking, ItemId.DeviledEggs);
            assert(time == 0, "Despite enabling time to eat one, two, and three, the duration for this recipe is {} when it should be 0", time);

            disable_all_but([Perk.HammerTiming, Perk.HammerTimingTwo, Perk.HammerTimingThree]);
            recipe = ITEM_PROTOTYPES[ItemId.BasicBookshelfOak].recipe.components.clone();
            duration = recipe.get(recipe.find(function(e) {
                return e.type == RecipeComponentType.Duration;
            }));
            time = get_modified_component_count(duration, RecipeContext.Woodcrafting, ItemId.BasicBookshelfOak);
            assert(time == 0, "Despite enabling hammer timing one, two, three, and four, the duration for this recipe is {} when it should be 0", time);

            disable_all_but([Perk.TimeSensitive, Perk.TimeSensitiveTwo, Perk.TimeSensitiveThree, Perk.TimeSensitiveFour]);
            recipe = ITEM_PROTOTYPES[ItemId.NetIron].recipe.components.clone();
            duration = recipe.get(recipe.find(function(e) {
                return e.type == RecipeComponentType.Duration;
            }));
            time = get_modified_component_count(duration, RecipeContext.Blacksmithing, ItemId.NetIron);
            assert(time == 0, "Despite enabling time sensitive one, two, three, and four, the duration for this recipe is {} when it should be 0", time);

            disable_all_but(Perk.FeedPrepper);
            recipe = ITEM_PROTOTYPES[ItemId.DogTreat].recipe.components.clone();
            duration = recipe.get(recipe.find(function(e) {
                return e.type == RecipeComponentType.Duration;
            }));
            time = get_modified_component_count(duration, RecipeContext.Milling, ItemId.DogTreat);
            assert(time == 0, "Despite enabling feed prepper, the duration for this recipe is {} when it should be 10", time);

            disable_all_but(Perk.WindDown);
            recipe = ITEM_PROTOTYPES[ItemId.Rice].recipe.components.clone();
            duration = recipe.get(recipe.find(function(e) {
                return e.type == RecipeComponentType.Duration;
            }));
            time = get_modified_component_count(duration, RecipeContext.Milling, ItemId.Rice);
            assert(time == 0, "Despite enabling wind down, the duration for this recipe is {} when it should be 10", 0);

            disable_all_but(Perk.RefinedRockery);
            recipe = ITEM_PROTOTYPES[ItemId.RefinedStone].recipe.components.clone();
            duration = recipe.get(recipe.find(function(e) {
                return e.type == RecipeComponentType.Duration;
            }));
            time = get_modified_component_count(duration, RecipeContext.Refining, ItemId.RefinedStone);
            assert(time == 0, "Despite enabling refined rockery, the duration for this recipe is {} when it should be 0", 0);
        });

        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.FeedingFrenzy);
            GRID.write_node(127, 46, ObjectId.GrassLarge);
            slash_node(GRID, 127, 46, obj_ari);
        });

        await_items(chain, 2, [ItemId.GrassSeed, ItemId.Hay]);

        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.Hay) + ARI.inventory.item_id_quantity(ItemId.GrassSeed);
            assert(total == 2, "Feeding frenzy did not result in two hay or grass seed items, count was {}", total);
        });

        chain.append(LinkId.Function, function() {
            ARI.inventory.drain();
            obj_ari.fsm.blackboard.set("remove_item_at", 0);
            ARI.give_item(ItemId.SeedTurnip);
            disable_all_but(Perk.GreenThumb);
        });
        chain.append(LinkId.Function, function() {
            use_item(new LiveItem(ItemId.SeedTurnip), Vec2(98, 52));
        });
        chain.append(LinkId.Function, function(chain) {
            chain.perk_timeout = 600;
        }, [chain]);
        chain.append(LinkId.Await, function(chain) {
            chain.perk_timeout -= 1;
            assert(chain.perk_timeout > 0, "Green thumb timed out, terrain was not watered");
            return GRID.node_terrain_is_watered[GRID.node_index_for_cell(98, 52)];
        }, [chain]);
        chain.append(LinkId.Function, function() {
            assert(GRID.node_terrain_is_watered[GRID.node_index_for_cell(98, 52)], "Despite planting a seed while using green thumb, the tile didn't get watered");
            erase_object_node(GRID, GRID.node_index_for_cell(98, 52));
        });
        chain.append(LinkId.Function, function() {
            ARI.set_stamina(ARI.get_max_stamina());
            disable_all_but(Perk.NiceSwing);
        });
        run_tool(ItemId.HoeMistril, Vec2(98, 52), chain);
        chain.append(LinkId.Await, function() {
            return instance_exists(obj_morsel);
        });
        chain.append(LinkId.Function, function() {
            with obj_morsel {
                give_resource();
            }
        });
        chain.append(LinkId.Function, function() {
            assert_eq(ARI.get_stamina(), ARI.get_max_stamina(), "Despite using nice swing, some stamina was depleted and is at {}", ARI.get_stamina());
        });
        run_tool(ItemId.HoeMistril, Vec2(98, 52), chain);

        chain.append(LinkId.Function, function() {
            ARI.set_stamina(ARI.get_max_stamina());
            disable_all_but(Perk.Refreshing);
        });
        run_tool(ItemId.WateringCanMistril, Vec2(98, 52), chain);
        chain.append(LinkId.Await, function() {
            return instance_exists(obj_morsel);
        });
        chain.append(LinkId.Function, function() {
            with obj_morsel {
                give_resource();
            }
        });
        chain.append(LinkId.Function, function() {
            assert(ARI.get_stamina() == ARI.get_max_stamina(), "Despite using refreshing, some stamina was depleted and is at {}", ARI.get_stamina());
        });
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.Ornamental);
            ARI.recipe_unlocks[ItemId.CropFauxTurnip] = false;
            ARI.recipe_unlocks[ItemId.CropFauxDaffodil] = false;
            ARI.recipes_created[ItemId.CropFauxTurnip] = false;
            ARI.recipes_created[ItemId.CropFauxDaffodil] = false;
        });

        chain.append(LinkId.Function, function() {
            var node = GRID.write_node(98, 52, ObjectId.Turnip);
            var ni = GRID.node_index_for_cell(98, 52);
            level_up_crop(node);
            level_up_crop(node);
            level_up_crop(node);
            level_up_crop(node);
            interact(node);
            erase_object_node(GRID, ni);
            node = GRID.write_node(98, 52, ObjectId.Daffodil, CropFlag.MANAGED);
            level_up_crop(node);
            level_up_crop(node);
            level_up_crop(node);
            level_up_crop(node);
            interact(node);
            erase_object_node(GRID, ni);
        });
        await_items(chain, 2, ItemId.CraftingScroll);
        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.CraftingScroll);
            assert(total == 2, "There should be 2 crafting scrolls but there are {}", total);
        });
        var arr = [
            {perk: Perk.CopperExpert, item: ItemId.CopperIngot},
            {perk: Perk.IronExpert, item: ItemId.IronIngot},
            {perk: Perk.SilverExpert, item: ItemId.SilverIngot},
            {perk: Perk.GoldExpert, item: ItemId.GoldIngot}
        ]
        for (var i = 0; i < 4; i++) {
            var data = arr[i];
            chain.append(LinkId.Function, function(perk, item) {
                var recipe = ITEM_PROTOTYPES[item].recipe.components.clone();
                var item_check = recipe.get(recipe.find(function(e) {
                    return e.type == RecipeComponentType.Item;
                }));
                var count_prior = get_modified_component_count(item_check, RecipeContext.Blacksmithing, item);
                disable_all_but(perk);
                var count_after = get_modified_component_count(item_check, RecipeContext.Blacksmithing, item);
                assert(count_after == count_prior - 1, "Despite using {Perk}, the {ItemId} still needed {} ore when it should've needed  {}", perk, item, count_after, count_prior - 1);
            }, [data.perk, data.item]);
        }
        var arr = [
            {perk : Perk.TirelessBlacksmithing, item : ItemId.CopperHelmet, infusion : Infusion.Tireless},
            {perk : Perk.HastyBlacksmithing, item : ItemId.CopperHelmet, infusion : Infusion.Hasty},
            {perk : Perk.LightweightBlacksmithing, item : ItemId.HoeCopper, infusion : Infusion.Lightweight},
            {perk : Perk.LeechBlacksmithing, item : ItemId.SwordGold, infusion : Infusion.Leeching},
            {perk : Perk.QualityCrafting, item : ItemId.BasicBookshelfOak, infusion : Infusion.Quality},
            {perk : Perk.FortifiedBlacksmithing, item : ItemId.CopperHelmet, infusion : Infusion.Fortified},
            {perk : Perk.SharpBlacksmithing, item : ItemId.SwordGold, infusion : Infusion.Sharp},
            {perk : Perk.RestorativeCooking, item : ItemId.DeviledEggs, infusion : Infusion.Restorative},
            {perk : Perk.LikableCooking, item : ItemId.DeviledEggs, infusion : Infusion.Likeable},
            {perk : Perk.SpeedyCooking, item : ItemId.DeviledEggs, infusion : Infusion.Speedy},
            {perk : Perk.LoveableCooking, item : ItemId.DeviledEggs, infusion : Infusion.Loveable},
            {perk : Perk.FairyCooking, item : ItemId.HerbSalad, infusion : Infusion.Fairy},
            {perk : Perk.MagicalMeals, item : ItemId.HerbSalad, infusion : Infusion.Magical}
        ];
        for (var i = 0, ic = array_length(arr); i < ic; i++) {
            var pack = arr[i];
            chain.append(LinkId.Function, function(pack) {
                disable_all_but(pack.perk);
                var list = ITEM_PROTOTYPES[pack.item].recipe.generate_infusions();
                var pass = false;
                for (var i = 0, c = list.count(); i < c; i++) {
                    if list.get(i).infusion == pack.infusion {
                        pass = true;
                        break;
                    }
                }
                assert(pass, "Despite using {Perk}, no {Infusion} infusion was available from the list", pack.perk, pack.infusion);
            }, [pack]);
        }

        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.Unpeatable);
            var arr = [ItemId.Peat, ItemId.Clay, ItemId.Sod];
            var node_index = GRID.node_index_for_cell(obj_ari.x div 8, obj_ari.y div 8);
            for (var i = 0; i < 3; i++) {
                GRID.write_node(obj_ari.x div 8, obj_ari.y div 8, ObjectId.DigSite);
                dig_site_attempt_dig(obj_ari.x div 8, obj_ari.y div 8, arr[i]);
                erase_object_node(GRID, node_index);
            }
        });
        await_items(chain, 2, ItemId.Peat);
        chain.append(LinkId.Function, function() {
            var peat_count = ARI.inventory.item_id_quantity(ItemId.Peat);
            assert(peat_count == 2, "Unpeatable did not result in 2 pieces of peat dropping: {}", peat_count);
        });
        await_items(chain, 2, ItemId.Clay);
        chain.append(LinkId.Function, function() {
            var clay_count = ARI.inventory.item_id_quantity(ItemId.Clay);
            assert(clay_count == 2, "Unpeatable did not result in 2 pieces of clay dropping: {}", clay_count);
        });
        await_items(chain, 2, ItemId.Sod);
        chain.append(LinkId.Function, function() {
            var sod_count = ARI.inventory.item_id_quantity(ItemId.Sod);
            assert(sod_count == 2, "Unpeatable did not result in 2 pieces of sod dropping: {}", sod_count);
        });
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.Bountiful);
            var point = Vec2(98, 52);
            assert(GRID.write_node(point.x, point.y, ObjectId.Turnip), "Failed to write the turnip");
            GRID.node_terrain_is_watered[GRID.node_index_for_cell(98, 52)] = false;
        });
        run_tool(ItemId.WateringCanMistril, Vec2(98, 52), chain);
        await_items(chain, 1, ItemId.SeedTurnip);
        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.SeedTurnip);
            assert(total == 1, "After using bountiful, there were {} seeds", total);
            erase_object_node(GRID, GRID.node_index_for_cell(98, 52));
            disable_all_but(Perk.HeavyDuty);
        });

        run_tool(ItemId.HoeMistril, Vec2(98, 52), chain);
        await_items(chain, 1, [ItemId.OreStone, ItemId.BasicWood]);
        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.OreStone) + ARI.inventory.item_id_quantity(ItemId.BasicWood);
            assert(total == 1, "After tilling and using heavy_duty, there was {} items when there should've been one!", total);
            disable_all_but(Perk.Lumberjack);
        });
        run_tool(ItemId.HoeMistril, Vec2(98, 52), chain);
        chain.append(LinkId.Function, function() {
            assert(GRID.write_node(98, 52, ObjectId.Branch), "Failed to write a branch required for testing.");
        });

        run_tool(ItemId.AxeMistril, Vec2(98, 52), chain);
        await_items(chain, 2, ItemId.BasicWood);
        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.BasicWood);
            assert(total == 2, "After using lumberjack, there was {} items when there should've been two!", total);
        });

        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.Masonry);
            GRID.write_node(98, 52, ObjectId.SmallRockStoneOne);
        });
        run_tool(ItemId.PickAxeMistril, Vec2(98, 52), chain);
        await_items(chain, 3, ItemId.OreStone);
        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.OreStone);
            assert(total >= 3, "Total is {} after using masonry, but we need at least 3", total);
        });
        chain.append(LinkId.Function, function() {
            for (var xx = 0, xxc = GRID.dims.x; xx < xxc; xx++) {
                for (var yy = 0, yyc = GRID.dims.y; yy < yyc; yy++) {
                    erase_object_node(GRID, GRID.node_index_for_cell(xx, yy));
                }
            }
            disable_all_but(Perk.Forager);
            GRID.write_node(98, 52, ObjectId.TreeOak);
            var node = GRID.node_parent[GRID.node_index_for_cell(100, 54)];
            level_up_tree(node, true);
            level_up_tree(node, true);
            level_up_tree(node, true);
        });
        run_tool(ItemId.AxeMistril, Vec2(100, 54), chain);
        chain.append(LinkId.Await, function() {
            return instance_exists(obj_falling_tree);
        });
        chain.append(LinkId.Await, function() {
            return instance_exists(obj_falling_tree) == false;
        });
        chain.append(LinkId.Function, function() {
            erase_object_node(GRID, GRID.node_index_for_cell(100, 54));
        });

        var arr = [];
        var f = fiddle_get(format("forageables/{Season}", Season.Spring));
        for (var i = 0; i < ForageableRarity.LEN; i++) {
            var a = f[$ forageable_rarity_to_string(i)];
            for (var j = 0, jc = array_length(a); j < jc; j++) {
                array_push(arr, string_to_item_id(a[j]));
            }
        }
        await_items(chain, 1, arr);
        chain.append(LinkId.Function, function() {
            var total = 0;
            var f = fiddle_get(format("forageables/{Season}", Season.Spring));
            for (var i = 0; i < ForageableRarity.LEN; i++) {
                var arr = f[$ forageable_rarity_to_string(i)];
                for (var j = 0, jc = array_length(arr); j < jc; j++) {
                    total += ARI.inventory.item_id_quantity(string_to_item_id(arr[j]));
                }
            }
            assert(total == 1, "After using Forager, there should be 1 forageable but theres {}", total);
            erase_object_node(GRID, GRID.node_index_for_cell(100, 54));
        });

        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.PreparedPicker);
            GRID.write_node(98, 52, ObjectId.Daffodil, CropFlag.SPAWN_GROWN | CropFlag.MANAGED);
            process_crop_harvest(GRID.node_parent[GRID.node_index_for_cell(98, 52)], Cardinal.North);
            erase_object_node(GRID, GRID.node_index_for_cell(98, 52));
        });
        await_items(chain, 1, ItemId.SeedDaffodil);
        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.SeedDaffodil);
            assert(total == 1, "After using prepared picker, we had {} seeds and should've had 1", total);
        });
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.Natural);
            var written_node = GRID.write_node(98, 52, ObjectId.TreeOak);
            assert_defined(written_node, "failed to write an oak tree");
            level_up_tree(written_node, true);
            level_up_tree(written_node, true);
            level_up_tree(written_node, true);
        });
        run_tool(ItemId.AxeMistril, Vec2(100, 54), chain);
        chain.append(LinkId.Await, function() {
            return instance_exists(obj_falling_tree);
        });
        chain.append(LinkId.Await, function() {
            return instance_exists(obj_falling_tree) == false;
        });
        await_items(chain, 1, ItemId.HardWood);
        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.HardWood);
            assert(total == 1, "After using Natural, we had {} hardwood but should've had 1", total);
            erase_object_node(GRID, GRID.node_index_for_cell(100, 54));
        });
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.IronHound);
            GRID.write_node(98, 52, ObjectId.NodeIron);
        });
        run_tool(ItemId.PickAxeMistril, Vec2(98, 52), chain);
        await_items(chain, 2, ItemId.OreIron);

        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.OreIron);
            assert(total >= 2, "After using Iron Hound, we had {} but we should've had at least 2", total);
        });
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.TrueBlue);
            GRID.write_node(98, 52, ObjectId.NodeSapphire);
        });
        run_tool(ItemId.PickAxeMistril, Vec2(98, 52), chain);
        await_items(chain, 2, ItemId.OreSapphire);
        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.OreSapphire);
            assert(total >= 2, "After using True Blue, we had {} but we should've had at least 2", total);
        });
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.SilverSeeker);
            GRID.write_node(98, 52, ObjectId.NodeSilver);
            GRID.node_parent[GRID.node_index_for_cell(98, 52)].hitpoints = 1;
        });
        run_tool(ItemId.PickAxeMistril, Vec2(98, 52), chain);
        await_items(chain, 2, ItemId.OreSilver);
        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.OreSilver);
            assert(total >= 2, "After using Silver Seeker, we had {} but we should've had at least 2", total);
        });
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.GoodAsGold);
            GRID.write_node(98, 52, ObjectId.NodeGold);
            GRID.node_parent[GRID.node_index_for_cell(98, 52)].hitpoints = 1;
        });
        run_tool(ItemId.PickAxeMistril, Vec2(98, 52), chain);
        await_items(chain, 2, ItemId.OreGold);
        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.OreGold);
            assert(total >= 2, "After using Good As Gold, we had {} but we should've had at least 2", total);
        });
        chain.append(LinkId.Function, function() {
            ARI.set_gold(0);
            disable_all_but(Perk.PrizeWinning);
            GRID.write_node(98, 52, ObjectId.Turnip);
            var node = GRID.node_parent[GRID.node_index_for_cell(98, 52)];
            //
            level_up_crop(node);
            level_up_crop(node);
            level_up_crop(node);
            level_up_crop(node);
            interact(node);
        });
        await_items(chain, ITEM_PROTOTYPES[ItemId.Turnip].value.bin * fiddle_get("perks/prize_winning/percent"), ItemId.MobCoin);
        chain.append(LinkId.Function, function() {
            var gold_check = ITEM_PROTOTYPES[ItemId.Turnip].value.bin * fiddle_get("perks/prize_winning/percent");
            assert(ARI.get_gold() == gold_check, "After using Prize Winning we should've had {} gold but only had {}", gold_check, ARI.get_gold());
        });
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.AppealingReeling);
            var inst = instance_create_depth(obj_ari.x, obj_ari.y - 36, obj_ari.depth - 5, obj_bobber);
            assert(inst.mask_index == animation_to_shape(string_to_asset(fiddle_get("perks/appealing_reeling/mask"))), "Despite using appealing_reeling, the bobber's mask is {}", asset_to_string(inst.mask_index));
            instance_destroy(inst);
            disable_all_but(Perk.AppealingReelingTwo);
            inst = instance_create_depth(obj_ari.x, obj_ari.y - 36, obj_ari.depth - 5, obj_bobber);
            assert(inst.mask_index == animation_to_shape(string_to_asset(fiddle_get("perks/appealing_reeling_two/mask"))), "Despite using appealing_reeling_two, the bobber's mask is {}", asset_to_string(inst.mask_index));
            instance_destroy(inst);
        });
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.EarthlyEssence);
        });
        chain.append(LinkId.Function, function() {
            GRID.write_node(98, 52, ObjectId.Turnip);
            var node = GRID.node_parent[GRID.node_index_for_cell(98, 52)];
            level_up_crop(node);
            level_up_crop(node);
            level_up_crop(node);
            level_up_crop(node);
            interact(node);
        });
        await_items(chain, 1, ItemId.SeedMysteryBag);
        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.SeedMysteryBag);
            assert(total == 1, "Despite using earthly essence, there is {} mystery seeds when there should've been one", total);
            erase_object_node(GRID, GRID.node_index_for_cell(98, 52));
        });
        __ts_travel_to(LocationId.PlayerHome, chain);
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.MistSight);
            new_day();
        });
        chain.append(LinkId.Function, function() {
            assert(MIST_SIGHT_ACTIVE_INDEX != undefined, "Despite using new day, no mist sight active index was defined");
            goto_location_id(MIST_SIGHT_LIST.get(MIST_SIGHT_ACTIVE_INDEX).location_id, true);
        });
        chain.append(LinkId.Function, function(chain) {
            chain.perk_timeout = 600;
        }, [chain]);
        chain.append(LinkId.Await, function(chain) {
            chain.perk_timeout -= 1;
            assert(chain.perk_timeout > 0, "Mist sight timed out, there was no active mist sight at the location {LocationId}", CURRENT_LOCATION_ID);
            return instance_exists(obj_mist_spot);
        }, [chain]);
        __ts_travel_to(LocationId.PlayerHome, chain);
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.ADayWellSpent);
            var stamina_target = ARI.get_max_stamina() + ARI.perk_value(Perk.ADayWellSpent);
            ARI.set_stamina(0);
            new_day();
            assert(ARI.get_stamina() == stamina_target, "After running new day using a day well spent, ARI's stamina was {} but should've been {}", ARI.get_stamina(), stamina_target);
        });
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.WesternRuinsScholar);
            new_day();
            var grid = GRIDS[LocationId.WesternRuins];
            var sites = 0;
            for (var xx = 0, xxc = grid.dims.x; xx < xxc; xx++) {
                for (var yy = 0, yyc = grid.dims.y; yy < yyc; yy++) {
                    var node_index = grid.node_index_for_cell(xx, yy);
                    if grid.node_object_id[node_index] == ObjectId.DigSite {
                        sites += 1;
                        erase_object_node(grid, grid.node_index_for_cell(xx, yy));
                    }
                }
            }
            var target_amount = LOCATIONS[LocationId.WesternRuins].special_dig_sites + LOCATIONS[LocationId.WesternRuins].dig_sites + ARI.perk_value(Perk.WesternRuinsScholar);
            assert(sites == target_amount, "Despite using western ruins scholar, there were {} sites when there should've been {}", sites, target_amount);

            disable_all_but(Perk.EasternRoadScholar);
            new_day();
            var grid = GRIDS[LocationId.EasternRoad];
            var sites = 0;
            for (var xx = 0; xx < grid.dims.x; xx++) {
                for (var yy = 0; yy < grid.dims.y; yy++) {
                    var node_index = grid.node_index_for_cell(xx, yy);
                    if grid.node_object_id[node_index] == ObjectId.DigSite {
                        sites += 1;
                        erase_object_node(grid, grid.node_index_for_cell(xx, yy));
                    }
                }
            }
            var target_amount = LOCATIONS[LocationId.EasternRoad].special_dig_sites + LOCATIONS[LocationId.EasternRoad].dig_sites + ARI.perk_value(Perk.EasternRoadScholar);
            assert(sites == target_amount, "Despite using western ruins scholar, there were {} sites when there should've been {}", sites, target_amount);
            disable_all_but(Perk.FormerFarmers);
            new_day();
            var grid = GRIDS[LocationId.Farm];
            var sites = 0;
            for (var xx = 0; xx < grid.dims.x; xx += 2) {
                for (var yy = 0; yy < grid.dims.y; yy += 2) {
                    var node_index = grid.node_index_for_cell(xx, yy);
                    if grid.node_object_id[node_index] == ObjectId.DigSite {
                        sites += 1;
                    }
                }
            }
            assert(sites == LOCATIONS[LocationId.Farm].dig_sites + 1, "Despite using former farmer, there were {} sites when there should've been {}", sites, LOCATIONS[LocationId.Farm].dig_sites + 1);
            disable_all_but(Perk.WellWatered);
            water_chunk(grid, 98, 52);
            grid.write_node(98, 52, ObjectId.Turnip);
            new_day();
            assert(GRIDS[LocationId.Farm].node_terrain_is_watered[GRIDS[LocationId.Farm].node_index_for_cell(98, 52)], "Despite using WellWatered, the watered node was unwatered over night");
        });

        var arr = [Perk.WelcomeHome, Perk.WelcomeHomeTwo];
        for (var j = 0; j < 2; j++) {
            chain.append(LinkId.Function, function(perk) {
                disable_all_but(perk);
                var grid = GRIDS[LocationId.Farm];
                var animals = get_all_animals();
                for (var i = 0, ic = animals.count(); i < ic; i++) {
                    var animal = animals.get(i);
                    animal.stable.deregister(animal);
                }
                erase_object_node(grid, grid.node_index_for_cell(98, 52));
                var barn = grid.write_node(98, 52, ObjectId.SmallBarn, 0);
                var a = new PlayerAnimal(AnimalKind.Cow, "red", Sex.Male);
                var b = new PlayerAnimal(AnimalKind.Cow, "gold", Sex.Female);
                barn.stable.register(a);
                barn.stable.register(b);
                a.days_old = a.prototype.breeding.days_until_adult;
                b.days_old = b.prototype.breeding.days_until_adult;
                a.breeding_with = b.idx;
                b.breeding_with = a.idx;
                a.ate_breeding_treat = true;
                b.ate_breeding_treat = true;
                barn.stable.on_new_day();
                for (var i = 0, ic = barn.stable.incubating_fetuses.count(); i < ic; i++) {
                    var fetus = barn.stable.incubating_fetuses.get(i);
                    fetus.days = ANIMAL_PROTOTYPES[fetus.animal.kind].breeding.incubation_days;
                }
                barn.stable.on_new_day();
                var pass = false;
                for (var i = 0; i < barn.stable.stalls.count(); i++) {
                    var animal = barn.stable.stalls.get(i);
                    if animal != undefined && animal.is_baby() && animal.heart_points == animal_heart_level_to_points(ARI.perk_value(perk)) {
                        pass = true;
                        break;
                    }
                }
                assert(pass, "Despite using {Perk} the animal had {} heart points when it should've had {}", perk, animal.heart_points, animal_heart_level_to_points(ARI.perk_value(perk)));
                erase_object_node(grid, grid.node_index_for_cell(98, 52));
            }, [arr[j]]);
        }
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.CloseBond);
            var animals = get_all_animals();
            var grid = GRIDS[LocationId.Farm];
            for (var i = 0, ic = animals.count(); i < ic; i++) {
                animal.stable.deregister(animals.get(i));
            }
            var a = new PlayerAnimal(AnimalKind.Cow, "red", Sex.Male);
            a.has_been_pat = true;
            a.has_eaten = true;
            var barn = grid.write_node(98, 52, ObjectId.SmallBarn, 0);
            barn.stable.register(a);
            barn.stable.on_new_day();
            assert(a.heart_points == ARI.perk_value(Perk.CloseBond), "Despite using Close Bond, the animal had {} hearts when it should've had {}", a.heart_points, ARI.perk_value(Perk.CloseBond));
            barn.stable.deregister(a);
            erase_object_node(grid, grid.node_index_for_cell(98, 52));
        });

        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.GeminiSeason);
            var grid = GRIDS[LocationId.Farm];
            var animals = get_all_animals();
            for (var i = 0, ic = animals.count(); i < ic; i++) {
                var animal = animals.get(i);
                animal.stable.deregister(animal);
            }
            var barn = grid.write_node(98, 52, ObjectId.SmallBarn, 0);
            var a = new PlayerAnimal(AnimalKind.Cow, "red", Sex.Male);
            var b = new PlayerAnimal(AnimalKind.Cow, "gold", Sex.Female);
            barn.stable.register(a);
            barn.stable.register(b);
            a.days_old = a.prototype.breeding.days_until_adult;
            b.days_old = b.prototype.breeding.days_until_adult;
            a.breeding_with = b.idx;
            b.breeding_with = a.idx;
            a.ate_breeding_treat = true;
            b.ate_breeding_treat = true;
            barn.stable.on_new_day();
            for (var i = 0, ic = barn.stable.incubating_fetuses.count(); i < ic; i++) {
                var fetus = barn.stable.incubating_fetuses.get(i);
                fetus.days = ANIMAL_PROTOTYPES[fetus.animal.kind].breeding.incubation_days;
            }
            barn.stable.on_new_day();
            var total = get_all_animals().count()
            assert(total == 4, "Despite having two animals breed after using gemini season, there were {} animals when there should've been 4!", total);
            erase_object_node(grid, grid.node_index_for_cell(98, 52));
            var animals = get_all_animals();
            for (var i = 0, ic = animals.count(); i < ic; i++) {
                var animal = animals.get(i);
                animal.stable.deregister(animal);
            }
        });
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.CurrencyOfCareTwo);
            var barn = GRIDS[LocationId.Farm].write_node(98, 52, ObjectId.SmallBarn, 0);
            var a = new PlayerAnimal(AnimalKind.Cow, "red", Sex.Male);
            a.days_old = a.prototype.breeding.days_until_adult;
            a.has_been_pat = true;
            a.has_eaten = true;
            a.production_days = a.prototype.production.male.days_to_produce;
            barn.stable.register(a);
            barn.stable.on_new_day();
            var grid = DYNAMIC_GRIDS.get(barn.dyn_index);
            var pass = false;
            for (var i = 0, ic = grid.lost_items.count(); i < ic; i++) {
                var item = grid.lost_items.get(i).items.get(0);
                if item.item_id == ItemId.AnimalCurrency {
                    pass = true;
                    break;
                }
            }
            assert(pass, "Despite using currency of care two, no animal currency was found in the barn");
            barn.stable.deregister(a);
            ARI.inventory.drain();
            var arr = [
                {kind_one: AnimalKind.Chicken, kind_two: AnimalKind.Cow, perk: Perk.BarnyardBounty},
                {kind_one: AnimalKind.Duck, kind_two: AnimalKind.Horse, perk: Perk.BarnyardBountyTwo},
                {kind_one: AnimalKind.Sheep, kind_two: AnimalKind.Rabbit, perk: Perk.BarnyardBountyThree},
            ];
            for (var i = 0; i < 3; i++) {
                var data = arr[i];
                disable_all_but(data.perk);
                a = new PlayerAnimal(data.kind_one, "red", Sex.Male);
                a.days_old = a.prototype.breeding.days_until_adult;
                a.has_been_pat = true;
                a.has_eaten = true;
                a.production_days = a.prototype.production.male.days_to_produce;
                barn.stable.register(a);

                b = new PlayerAnimal(data.kind_two, "red", Sex.Male);
                b.days_old = b.prototype.breeding.days_until_adult;
                b.has_been_pat = true;
                b.has_eaten = true;
                b.production_days = b.prototype.production.male.days_to_produce;
                barn.stable.register(b);
                barn.stable.on_new_day();
                var passes = 0;
                for (var j = 0, jc = grid.lost_items.count(); j < jc; j++) {
                    var item = grid.lost_items.get(j).items.get(0);
                    if (item.item_id == a.prototype.production.male.normal_product || item.item_id == b.prototype.production.male.normal_product) && grid.lost_items.get(j).items.count() == 2 {
                        passes += 1;
                    }
                }
                assert(passes == 2, "Despite using {Perk}, there were only {} passing checks but 2 should've passed", data.perk, passes);
                barn.stable.deregister(a);
                barn.stable.deregister(b);
                grid.lost_items = List();
            }
            erase_object_node(GRIDS[LocationId.Farm], GRIDS[LocationId.Farm].node_index_for_cell(98, 52));
            var animals = get_all_animals();
            for (var i = 0, ic = animals.count(); i < ic; i++) {
                var animal = animals.get(i);
                animal.stable.deregister(animal);
            }
        });
        __ts_travel_to(LocationId.Farm, chain);
        chain.append(LinkId.Function, function() {
            with obj_item {
                instance_destroy();
            }
            WEATHER.set_weather(Weather.Calm);
            obj_ari.x = 98 * 8 + 32;
            obj_ari.y = 52 * 8 - 32;
            disable_all_but(Perk.CurrencyOfCare);
            var animal_real = instance_create_layer(
                obj_ari.x - 32,
                obj_ari.y + 32,
                "Instances",
                obj_player_animal,
                {
                    me: new PlayerAnimal(AnimalKind.Cow, "red", Sex.Male),
                }
            );
            GRID.write_node(98, 52, ObjectId.Turnip, CropFlag.SPAWN_GROWN);
            animal_real.try_find_food();
        });
        chain.append(LinkId.Await, function() {
            return instance_exists(obj_item);
        })
        chain.append(LinkId.Await, function() {
            with obj_item {
                self.x = obj_ari.x;
                self.y = obj_ari.y;
            }
            return instance_exists(obj_item) == false;
        })
        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.AnimalCurrency);
            assert(total == NODE_PROTOTYPES[ObjectId.Turnip].currency, "After using Currency of Care there should be {} animal beads but there are only {}", NODE_PROTOTYPES[ObjectId.Turnip].currency, total);
            instance_destroy(obj_player_animal);
        });

        chain.append(LinkId.Function, function() {
            var barn = GRIDS[LocationId.Farm].write_node(98, 52, ObjectId.SmallBarn, 0);
            disable_all_but([Perk.CurrencyOfCareThree, Perk.CurrencyOfCare]);

            var a = new PlayerAnimal(AnimalKind.Cow, "red", Sex.Male);
            barn.stable.register(a);
            instance_create_layer(
                obj_ari.x,
                obj_ari.y,
                "Instances",
                obj_player_animal,
                {
                    me: a,
                }
            );
            ARI.inventory.drain();
            ARI.give_item(ItemId.HerbSalad);
            ARI.set_held_item_index(0);
            var selection = find_nearest_interactable(obj_ari.collision_list, obj_ari);
            assert(selection != undefined, "No interaction was found despite the player being next to the animal");
            var cback = selection.attempt_interact(true);
            assert(cback != undefined, "Animal did not give back a callback");
            cback();
        });
        chain.append(LinkId.Await, function() {
            return instance_exists(obj_item);
        });
        chain.append(LinkId.Await, function() {
            with obj_item {
                self.x = obj_ari.x;
                self.y = obj_ari.y;
            }
            return instance_exists(obj_item) == false;
        });
        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.AnimalCurrency);
            var stars = ITEM_PROTOTYPES[ItemId.HerbSalad].stars * 2;
            assert(total == stars, "Despite using currency of care three, we only got {} animal beads and should've had {}", total, stars);
        });

        chain.append(LinkId.Function, function() {
            enter_dungeon();
        });
        chain.append(LinkId.Timer, 60);
        chain.append(LinkId.Function, function() {
            ARI.inventory.drain();
            disable_all_but(Perk.Stoneturner);
            GRID.write_node(12, 36, ObjectId.SmallRockStoneOne);

        });
        run_tool(ItemId.PickAxeMistril, Vec2(12, 36), chain);
        chain.append(LinkId.Await, function() {
            return instance_exists(obj_item);
        });
        chain.append(LinkId.Await, function() {
            return instance_exists(obj_item) == false;
        });
        chain.append(LinkId.Function, function(chain) {
            chain.perk_timeout = 600;
        }, [chain]);
        chain.append(LinkId.Await, function(chain) {
            var pass = false;
            for (var i = 0, ic = ARI.inventory.slots.count(); i < ic; i++) {
                if ARI.inventory.slot(i).item == undefined {
                    continue;
                }
                if ARI.inventory.slot(i).item.prototype.tags.contains("archaeology") {
                    pass = true;
                    break;
                }
            }
            chain.perk_timeout -= 1;
            return pass || chain.perk_timeout <= 0;
        }, [chain]);
        chain.append(LinkId.Function, function() {
            var pass = false;
            for (var i = 0, ic = ARI.inventory.slots.count(); i < ic; i++) {
                if ARI.inventory.slot(i).item.prototype.tags.contains("archaeology") {
                    pass = true;
                    break;
                }
            }
            ARI.inventory.drain();
            assert(pass, "No artifact was gained after using stone turner.");
        });
        chain.append(LinkId.Function, function() {
            disable_all_but(Perk.MaterialWorld);
            GRID.write_node(12, 36, ObjectId.Barrel)
            slash_node(GRID, 12, 36, obj_ari)

        });
        await_items(chain, 2, [ItemId.BasicWood, ItemId.Glass]);
        chain.append(LinkId.Function, function() {
            var total = ARI.inventory.item_id_quantity(ItemId.BasicWood) + ARI.inventory.item_id_quantity(ItemId.Glass);
            assert(total == 4, "Despite using material world, we got {} pieces of wood/glass, but should've gotten 4", total);
        });
    }
});

TS_TESTS.push({
    name: "apply_decor",
    run_once: true,
    call: function(chain) {
        __ts_travel_to(LocationId.PlayerHome, chain);
        chain.append(LinkId.Function, function() {
            var wp_one = ITEM_PROTOTYPES[ItemId.CavernRockWallpaper];
            var fl_one = ITEM_PROTOTYPES[ItemId.CavernRockFlooring];
            assert(DECOR.apply_wallpaper(wp_one.wallpaper, wp_one.door_mold, true, Infusion.Quality), "Tileset {} is not a valid tile set name.  Found on item {ItemId}", wp_one.wallpaper, ItemId.CavernRockWallpaper);
            assert(DECOR.apply_flooring(fl_one.flooring, true, Infusion.Quality), "Tileset {} is not a valid tile set name.  Found on item {ItemId}", fl_one.flooring, ItemId.CavernRockWallpaper);

            //
            assert_neq(DECOR.wallpapers[$ "player_home"], undefined);
            var wallpaper_data = DECOR.wallpapers[$ "player_home"];
            assert_eq(wallpaper_data.wallpaper, wp_one.wallpaper);
            assert_eq(wallpaper_data.door_mold_sprite, wp_one.door_mold);
            assert_eq(wallpaper_data.infusion, Infusion.Quality);

            //
            assert_neq(DECOR.floorings[$ "player_home"], undefined);
            var flooring_data = DECOR.floorings[$ "player_home"];
            assert_eq(flooring_data.flooring, fl_one.flooring);
            assert_eq(flooring_data.infusion, Infusion.Quality);

            for (var i = 0; i < ItemId.LEN; i++) {
                var proto = ITEM_PROTOTYPES[i];
                if proto[$ "wallpaper"] != undefined {
                    assert(DECOR.apply_wallpaper(proto.wallpaper, proto.door_mold), "Tileset {} is not a valid tile set name.  Found on item {ItemId}", proto.wallpaper,  i);
                }
                if proto[$ "flooring"] != undefined {
                    assert(DECOR.apply_flooring(proto.flooring), "Tileset {} is not a valid tile set name.  Found on item {ItemId}", proto.flooring,  i);
                }
            }
        });
    }
});

TS_TESTS.push({
    name: "write_furniture",
    run_once: true,
    call: function(chain) {
        __ts_travel_to(LocationId.PlayerHome, chain);
        chain.append(LinkId.Function, function() {
            obj_ari.x = 200;
            obj_ari.y = 200;

            //
            if instance_exists(obj_pet) {
                instance_destroy(obj_pet);
            }

            //
            for (var xx = 0; xx < GRID.dims.x; xx++) {
                for (var yy = 0; yy < GRID.dims.y; yy++) {
                    erase_object_node(GRID, GRID.node_index_for_cell(xx, yy));
                    erase_rug_node(GRID, GRID.node_index_for_cell(xx, yy));
                }
            }

            var furniture_names = struct_get_names(fiddle_get("object_prototypes/furniture"));
            var hybrids = List();
            var walls = List();
            var simple_tables = List();

            for (var i = 0, c = array_length(furniture_names); i < c; i++) {
                if furniture_names[i] == "default" {
                    continue;
                }

                var node_proto = NODE_PROTOTYPES[string_to_object_id(furniture_names[i])];

                if node_proto.window_tiles
                    || node_proto.destructable == false
                    || !array_contains(node_proto.placeable_locations, CURRENT_LOCATION_ID)
                {
                    continue;
                }

                if node_proto.sub_grid != undefined {
                    var is_simple = true;

                    for (var xx = 0, limit_x = ds_grid_width(node_proto.sub_grid); xx < limit_x; xx++) {
                        for (var yy = 0, limit_y = ds_grid_height(node_proto.sub_grid); yy < limit_y; yy++) {
                            if node_proto.sub_grid[# xx, yy] == 0 {
                                is_simple = false;
                            }
                        }
                    }

                    if is_simple {
                        simple_tables.push(furniture_names[i]);
                    }
                }

                var rule_g = node_proto.rule_grid;
                var has_w = false;
                var has_f = false;

                for (var xx = 0, limit_x = ds_grid_width(rule_g); xx < limit_x; xx++) {
                    for (var yy = 0, limit_y = ds_grid_height(rule_g); yy < limit_y; yy++) {
                        if has_flag(rule_g[# xx, yy], TileFlag.Placeable) {
                            has_f = true;
                        }
                        if has_flag(rule_g[# xx, yy], TileFlag.PlaceableWall) {
                            has_w = true;
                        }
                    }
                }

                if has_f && has_w {
                    hybrids.push(furniture_names[i]);
                    continue;
                }

                if has_w && !has_f {
                    walls.push(furniture_names[i]);
                    continue;
                }

                assert_neq(GRID.write_node(10, 14, string_to_object_id(furniture_names[i])), undefined, "Tried to write object {} but failed", furniture_names[i]);

                var ni = GRID.node_index_for_cell(10, 14);

                if GRID.node_rug_id[ni] != undefined {
                    assert(erase_rug_node(GRID, ni), "Tried to erase object {} but failed", furniture_names[i]);
                } else {
                    assert(erase_object_node(GRID, ni), "Tried to erase object {} but failed", furniture_names[i]);
                }
            }

            for (var i = 0, c = simple_tables.count(); i < c; i++) {
                with (obj_item) {
                    instance_destroy();
                }
                var object_id = string_to_object_id(simple_tables.get(i));
                assert_defined(GRID.write_node(12, 15, object_id), "We tried to write {ObjectId} but failed", object_id);
                assert_defined(GRID.write_node(12, 15, ObjectId.BakeryCuttingBoardCoffee), "We tried writing {ObjectId} on top of {ObjectId} but failed", ObjectId.BakeryCuttingBoardCoffee, object_id);

                //
                repeat 3 {
                    pick_node(GRID, 12, 15, ITEM_PROTOTYPES[ItemId.PickAxeMistril], 0, undefined, new TangoDoppel());
                }

                //
                var count = 0;

                with (obj_item) {
                    if self.item_id == ItemId.BakeryCuttingBoardCoffee || self.item_id == find_item_prototype(object_id).item_id {
                        count++;
                    }
                }

                assert(count == 2, "We tried cleaning up {ItemId} and {ItemId} but didn't with success", find_item_prototype(object_id).item_id, ItemId.BakeryCuttingBoardCoffee)
            }

            for (var i = 0, c = walls.count(); i < c; i++) {
                var object_id = string_to_object_id(walls.get(i));
                var node_proto = NODE_PROTOTYPES[object_id];
                assert(node_proto.size.y >= 7, fmt("All wall based furniture must occupy at least 7 tiles vertically, object was {ObjectId}, size was {}", object_id, node_proto.size.y));
                assert_neq(GRID.write_node(10, 6, object_id), undefined, "Tried to write object {} but failed", walls.get(i));
                assert(erase_object_node(GRID, GRID.node_index_for_cell(10, 6)), "Tried to erase object {} but failed", walls.get(i));
            }

            for (var i = 0, c = hybrids.count(); i < c; i++) {
                var object_id = string_to_object_id(hybrids.get(i));
                assert_neq(GRID.write_node(10, 15 - (NODE_PROTOTYPES[object_id].size.y), object_id), undefined, "Tried to write object {} but failed", hybrids.get(i));
                assert(erase_object_node(GRID, GRID.node_index_for_cell(10, 15 - (NODE_PROTOTYPES[object_id].size.y))), "Tried to erase object {} but failed", hybrids.get(i));
            }

            //
            for (var xx = 0; xx < GRID.dims.x; xx++) {
                for (var yy = 0; yy < GRID.dims.y; yy++) {
                    erase_object_node(GRID, GRID.node_index_for_cell(xx, yy));
                }
            }
        });
    }
})

TS_TESTS.push({
    name: "check_furniture_depths",
    run_once: true,
    call: function(chain) {
        __ts_travel_to(LocationId.PlayerHome, chain);
        chain.append(LinkId.Timer, 5);
        chain.append(LinkId.Function, function() {
            obj_ari.x = 200;
            obj_ari.y = 200;
            //
            for (var xx = 0; xx < GRID.dims.x; xx++) {
                for (var yy = 0; yy < GRID.dims.y; yy++) {
                    erase_object_node(GRID, GRID.node_index_for_cell(xx, yy));
                    erase_rug_node(GRID, GRID.node_index_for_cell(xx, yy));
                }
            }

            var simple_tables = List();

            for (var i = 0; i < ObjectId.LEN; i++) {
                if object_id_to_object_category(i) == ObjectCategory.Furniture
                    && i != ObjectId.BoxSmallV1
                    && i != ObjectId.BoxSmallV2
                    && i != ObjectId.DingyPileOfNewspapersV1
                    && i != ObjectId.DingyPileOfNewspapersV2
                    && NODE_PROTOTYPES[i].sub_grid != undefined
                    && NODE_PROTOTYPES[i].destructable
                {
                    simple_tables.push(i);
                }
            }
            var bad_boy_list = List();
            for (var i = 0, c = simple_tables.count(); i < c; i++) {
                for (var n = 0; n < Cardinal.LEN; n++) {
                    if n == Cardinal.West {
                        continue;
                    }
                    var ni = GRID.node_index_for_cell(10, 14);
                    var success = undefined;
                    var break_it = false;
                    erase_object_node(GRID, ni);
                    assert(GRID.write_node(10, 14, simple_tables.get(i), n) != undefined, "Failed to write {ObjectId}", simple_tables.get(i));
                    for (var xx = GRID.node_parent[ni].top_left_x; xx < GRID.node_parent[ni].top_left_x + GRID.node_parent[ni].write_size_x; xx++) {
                        for (var yy = GRID.node_parent[ni].top_left_y + GRID.node_parent[ni].write_size_y - 1; yy >= GRID.node_parent[ni].top_left_y; yy--) {
                            if GRID.node_parent[ni].child_grid.node_object_id[GRID.node_parent[ni].child_grid.node_index_for_cell(xx - 10, yy - 14)] == undefined {
                                success = GRID.write_node(xx, yy, ObjectId.BasicOilLampGrey, n);
                                if success != undefined {
                                    if -success.renderer.depth >= (GRID.node_parent[ni].top_left_y + GRID.node_parent[ni].write_size_y) * 8 {
                                        bad_boy_list.push({
                                            direction: n,
                                            object: simple_tables.get(i),
                                            positions: fmt("render value final: {}. position checked: {}", -success.renderer.depth, (GRID.node_parent[ni].top_left_y + GRID.node_parent[ni].write_size_y) * 8)
                                        });
                                    }
                                    break_it = true;
                                    break;
                                }
                            }
                        }
                        if break_it {
                            break;
                        }
                    }
                    assert(success != undefined, "Attempted to write {ObjectId} to {ObjectId}, but failed.", ObjectId.BasicOilLampGrey, simple_tables.get(i));
                    erase_object_node(GRID, GRID.node_index_for_cell(10, 14));
                }
            }

            if bad_boy_list.count() != 0 {
                for (var m = 0; m < bad_boy_list.count(); m++) {
                    var bb = bad_boy_list.get(m);
                    error("Object {ObjectId} caused out of bounds depth while facing {Cardinal}", bb.object, bb.direction);
                    error("{}", bb.positions);
                }
                error("Some furniture has incorrect depth depth offsets, check output for more details.");
                crash("Some furniture has incorrect depth depth offsets, check output for more details.", true);
            }

            for (var xx = 0; xx < GRID.dims.x; xx++) {
                for (var yy = 0; yy < GRID.dims.y; yy++) {
                    erase_object_node(GRID, GRID.node_index_for_cell(xx, yy));
                    erase_rug_node(GRID, GRID.node_index_for_cell(xx, yy));
                }
            }
        });
        chain.append(LinkId.Timer, 1);
    }
})

TS_TESTS.push({
    name: "player_home_safe_position",
    run_once: true,
    call: function(chain) {
        __ts_travel_to(LocationId.PlayerHome, chain);

        chain.append(LinkId.Function, function() {
            instance_activate_object(obj_roomtransition);
        });
        chain.append(LinkId.Timer, 1);
        chain.append(LinkId.Function, function() {
            var old_size = DECOR.size_upgrade;
            assert_eq(instance_number(obj_roomtransition), 4);

            for (var test_size_upgrade = 0; test_size_upgrade < HomeUpgrade.LargeWest; test_size_upgrade++) {
                DECOR.size_upgrade = test_size_upgrade;
                var fallback_position = player_home_safe_position(CURRENT_LOCATION_ID);
                fallback_position.x -= 8;
                fallback_position.y += 4;
                //
                var found = false;
                var object_found = false;
                for (var i = 0; i < 5; i++) {
                    var o = instance_find(obj_roomtransition, i);
                    if o.home_upgrade_key == test_size_upgrade {
                        object_found = true;
                        break;
                    }
                }
                if o.x == fallback_position.x && o.y == fallback_position.y {
                    found = true;
                }
                assert(object_found, "door for upgrade key {HomeUpgrade} not found.", test_size_upgrade);
                assert(
                    found,
                    "fallback position when Size Upgrade: {bool} was {}, but this didn't correspond to any obj_roomtransition!",
                    DECOR.size_upgrade,
                    fallback_position
                );
            }

            DECOR.size_upgrade = old_size;
            DECOR.setup_room(GRID);
        });
        __ts_travel_to(LocationId.PlayerHomeEast, chain)
        chain.append(LinkId.Function, function() {
            assert_eq(instance_number(obj_roomtransition), 1);
            var found = false;
            var object_found = instance_find(obj_roomtransition, 0);
            var fallback_position = player_home_safe_position(CURRENT_LOCATION_ID);
            fallback_position.y -= 8;
            fallback_position.x -= 23;
            if object_found.x == fallback_position.x && object_found.y == fallback_position.y {
                found = true;
            }
            assert(found,"fallback position for PlayerHomeEast is invalid: {}", fallback_position);
        })
        __ts_travel_to(LocationId.PlayerHomeWest, chain)
        chain.append(LinkId.Function, function() {
            assert_eq(instance_number(obj_roomtransition), 1);
            var found = false;
            var object_found = instance_find(obj_roomtransition, 0);
            var fallback_position = player_home_safe_position(CURRENT_LOCATION_ID);
            fallback_position.x += 8;
            fallback_position.y -= 8;
            if object_found.x == fallback_position.x && object_found.y == fallback_position.y {
                found = true;
            }
            assert(found,"fallback position for PlayerHomeWest is invalid: {}", fallback_position);
        });
    }
})

TS_TESTS.push({
    name: "request_board",
    run_once: true,
    call: function(chain) {

        //
        //
        chain.append(LinkId.Function, function() {
            //
            //
            static YEAR_ADDITION = years(10);
            CALENDAR.time += YEAR_ADDITION;
            var old_quest_log = QUEST_LOG;
            QUEST_LOG = new QuestLog();
            QUEST_LOG.completed = HashSetFromArray(QUESTS.keys());

            //
            REQUEST_BOARD = create_request_board();
            var missing_keys = ListFromArray(REQUEST_BOARD_ENTRIES.keys())
                .drain(function(key) {
                    return REQUEST_BOARD.has(key);
                });
            if !missing_keys.is_empty() {
                crash("The following quests never made it onto the notice board: {}", missing_keys);
            }

            //
            QUEST_LOG = old_quest_log;
        })
    }
});

TS_TESTS.push({
    name: "regrow_growth",
    run_once: true,
    call: function(chain) {
        __ts_test_crop(chain, ObjectId.Strawberry, true);
    }
});

TS_TESTS.push({
    name: "non_regrow_growth",
    run_once: true,
    call: function(chain) {
        __ts_test_crop(chain, ObjectId.Turnip, false);
    }
});

TS_TESTS.push({
    name: "Tree growth test",
    run_once: true,
    call: function(chain) {
        __ts_travel_to(LocationId.Farm, chain);
        chain.append(LinkId.Function, function() {
            obj_ari.x = 700;
            obj_ari.y = 700;
        });
        chain.append(LinkId.Timer,1);
        chain.append(LinkId.Function,function() {
            var anchor_x = obj_ari.x div 8;
            var anchor_y = obj_ari.y div 8;
            for(var xx = anchor_x - 10; xx < anchor_x + 10; xx++) {
                for(var yy = anchor_y - 10; yy < anchor_y + 10; yy++) {
                    var ni = GRID.node_index_for_cell(xx,yy);
                    erase_object_node(GRID,ni);
                }
            }
            var ni = GRID.node_index_for_cell(anchor_x,anchor_y);
            erase_object_node(GRID,ni);
            GRID.write_ground(anchor_x,anchor_y, GroundKind.Soil);
            GRID.write_node(anchor_x,anchor_y,ObjectId.TreeCherry);
            var node_check = GRID.node_index_for_cell(anchor_x+2,anchor_y+2);
            for(var i = 0; i < 14; i++) {
                switch(GRID.node_parent[node_check].day_count) {
                    case 0:
                    case 1:
                    case 2:
                        assert_eq(GRID.node_parent[node_check].stage,0,"We didn't reach the expected stage for this tree");
                        break;
                    case 3:
                    case 4:
                    case 5:
                        assert_eq(GRID.node_parent[node_check].stage,1,"We didn't reach the expected stage for this tree");
                        break;
                    case 6:
                    case 7:
                    case 8:
                        assert_eq(GRID.node_parent[node_check].stage,2,"We didn't reach the expected stage for this tree");
                        break;
                    case 9:
                    case 10:
                    case 11:
                        assert_eq(GRID.node_parent[node_check].stage,3,"We didn't reach the expected stage for this tree");
                        break;
                    case 12:
                    case 13:
                    case 14:
                        assert_eq(GRID.node_parent[node_check].stage,4,"We didn't reach the expected stage for this tree");
                        break;

                    default: impossible("Unexpected node.parent.day_count {}",GRID.node_parent[node_check].day_count);
                }
                GRID.new_day();
            }
            create_tree_renderer(GRID.node_parent[node_check]);
            assert(GRID.node_parent[node_check].has_fruit,"For some reason, this tree doesn't have fruit!");
            var success = interact(GRID.node_parent[node_check]);
            assert(success, "Interaction with tree didn't succeed");
            assert(GRID.node_parent[node_check].has_fruit == false,"For some reason, this tree still has fruit!");
        });
    }
});

TS_TESTS.push({
    name: "ranching",
    run_once: true,
    call: function(chain) {
        //
        chain.append(LinkId.Function, function() {
            //
            static MAKE_ANIMAL = function(kind, sex, age, building) {
                var variants = ANIMAL_PROTOTYPES[kind].variants.keys();
                var cosmetics = ANIMAL_PROTOTYPES[kind].cosmetics.keys();
                var variant = undefined;
                while true {
                    variant = variants[irandom(array_length(variants) - 1)];
                    if ANIMAL_PROTOTYPES[kind].variants.get(variant).acquirable {
                        break;
                    }
                }
                var animal = new PlayerAnimal(kind, variant, sex);
                animal.days_old = age;
                animal.heart_points = animal_heart_level_to_points(10);
                if !array_is_empty(cosmetics) {
                    animal.cosmetic = cosmetics[irandom(array_length(cosmetics) - 1)];
                }
                building.stable.register(animal);
            }

            //
            ARI.perks[Perk.GeminiSeason] = false;

            //
            erase_object_node(GRIDS[LocationId.Farm], GRIDS[LocationId.Farm].node_index_for_cell(72, 52));
            erase_rug_node(GRIDS[LocationId.Farm], GRIDS[LocationId.Farm].node_index_for_cell(72, 52));
            var building = GRIDS[LocationId.Farm].write_node(72, 52, ObjectId.LargeBarn, 0);
            assert_neq(building, undefined, "we couldn't make a barn");

            //
            MAKE_ANIMAL(AnimalKind.Cow, Sex.Male, 5, building);
            MAKE_ANIMAL(AnimalKind.Cow, Sex.Female, 5, building);

            //
            assert_eq(building.stable.animals().count(), 2);

            //
            var male = building.stable.animals().find_value(function(animal) {
                return animal.kind == AnimalKind.Cow && animal.can_breed() && animal.sex == Sex.Male;
            });
            assert_neq(male, undefined, "Failed to find a male cow for breeding!");
            var female = building.stable.animals().find_value(function(animal) {
                return animal.kind == AnimalKind.Cow && animal.can_breed() && animal.sex == Sex.Female;
            });
            assert_neq(female, undefined, "Failed to find a female cow for breeding!");

            //
            male.ate_breeding_treat = true;
            female.ate_breeding_treat = true;
            male.breeding_with = female.idx;
            female.breeding_with = male.idx;

            //
            var pairs = building.stable.gather_breeding_pairs();
            assert(pairs.count() == 1, "Incorrect number of breeding pairs: {}", pairs.count());

            //
            run_debug_animal_progression(1);
            assert_eq(male.ate_breeding_treat, false);
            assert_eq(female.ate_breeding_treat, false);
            assert_eq(male.breeding_with, undefined);
            assert_eq(female.breeding_with, undefined);

            //
            assert_eq(male.is_incubating, true);
            assert_eq(female.is_incubating, true);

            //
            run_debug_animal_progression(99);

            //
            assert_eq(male.ate_breeding_treat, false);
            assert_eq(female.ate_breeding_treat, false);
            assert_eq(male.breeding_with, undefined);
            assert_eq(female.breeding_with, undefined);

            //
            assert_eq(male.is_incubating, false);
            assert_eq(female.is_incubating, false);

            //
            assert_eq(building.stable.animals().count(), 3, "Unexpected number of animals!");

            //
            ARI.perks[Perk.GeminiSeason] = true;

            //
            with obj_farm_bell {
                self.bell_out();
            }
        });
    }
});

TS_TESTS.push({
    name: "Interactions",
    run_once: true, //
    call: function(chain) {
        __ts_travel_to(LocationId.Farm, chain);
        chain.append(LinkId.Function, function() {
            obj_ari.x = 700;
            obj_ari.y = 700;
        });
        chain.append(LinkId.Timer, 1);
        chain.append(LinkId.Function, function() {
            var anchor_x = obj_ari.x div 8;
            var anchor_y = obj_ari.y div 8;
            var new_inst = instance_create_layer(
                obj_ari.x + 10,
                obj_ari.y,
                "Instances",
                npc_id_to_gm_obj_id(NpcId.March)
            );
            //
            new_inst.initialize(NPCS[NpcId.March], NpcState.Default);
            obj_ari.set_cardinal(Cardinal.East);

            var interactable = find_nearest_interactable(obj_ari.collision_list, obj_ari);
            assert_eq(interactable, new_inst, "We tried to interact with March whos right next to us, but for some reason it didn't work");
            instance_destroy(new_inst);

            //
            var mailbox_node = GRID.node_index_for_cell(anchor_x + 1,anchor_y);
            erase_object_node(GRID,mailbox_node);
            GRID.write_node(anchor_x+1, anchor_y, ObjectId.Mailbox);
            var interactable = find_nearest_interactable(obj_ari.collision_list, obj_ari);
            assert_eq(GRID.node_parent[mailbox_node].renderer,interactable,"We tried to interact with the mailbox which is right next to us, but for some reason it didn't work");
            erase_object_node(GRID,mailbox_node);
        });
    }
});

TS_TESTS.push({
    name: "tools",
    call: function(chain) {
        //
        __ts_travel_to(LocationId.Farm, chain);

        chain.append(LinkId.Function, function() {
            obj_ari.x = 700;
            obj_ari.y = 700;
            WEATHER.set_weather(Weather.Calm);
        });

        chain.append(LinkId.Timer, 1);

        //
        static WRITE_SET = function() {
            var offset = Vec2();
            TS_OBJECT_POSITIONS.clear();
            for (var i = 0; i < TS_OBJECT_LIST.count(); i++) {
                var obj_id = TS_OBJECT_LIST.get(i);
                var ax = ((obj_ari.x) div 8) + offset.x;
                var ay = ((obj_ari.y) div 8) + offset.y;
                for (var xx = 0; xx < 6; xx++) {
                    for (var yy = 0; yy < 6; yy++) {
                        var node_check = GRID.node_index_for_cell(ax + xx, ay + yy);
                        erase_object_node(GRID, node_check);
                    }
                }
                GRID.write_ground(ax,ay, GroundKind.Soil);

                var real_object = GRID.write_node(ax,ay,obj_id);
                if real_object != undefined {
                    offset.x += ceil(real_object.write_size_x/2)*2;
                    //
                    if real_object.write_size_x > 2 {
                        TS_OBJECT_POSITIONS.push(Vec2(ax+1,ay+1));
                    } else {
                        TS_OBJECT_POSITIONS.push(Vec2((ax div 2) * 2, (ay div 2) * 2));
                    }
                }
            }
        }

        static CLEAN_SET = function() {
            var _min = TS_OBJECT_POSITIONS.first();
            var _max = TS_OBJECT_POSITIONS.last();
            for(var xx = _min.x; xx < _max.x; xx++) {
                var node_check = GRID.node_index_for_cell(xx,_min.y);
                erase_object_node(GRID, node_check)
                node_check = GRID.node_index_for_cell(xx,_min.y+1);
                erase_object_node(GRID, node_check)
                node_check = GRID.node_index_for_cell(xx,_min.y-1);
                erase_object_node(GRID, node_check)
            }
        }

        for (var t = 0; t < TS_TOOLS_LIST.count(); t++) {
            var tool_data = TS_TOOLS_LIST.get(t);
            chain
                .append(LinkId.Function, function(tool_data) {
                    trace("Testing {}",item_id_to_string(tool_data.tool));
                },[tool_data])
                .append(LinkId.Function, WRITE_SET)
                .append(LinkId.Function, function(chain, tool_data) {
                    var inner_chain = new Chain();

                    for (var i = 0; i < TS_OBJECT_POSITIONS.count(); i++) {
                        inner_chain
                            .append(LinkId.Function, function(i, tool_data) {
                                //
                                ARI.modify_stamina(9999);
                                var tool = tool_data.tool;
                                var object_position = TS_OBJECT_POSITIONS.get(i);
                                tool_data.pre_assertion(object_position);

                                var success = use_item_fast(tool, object_position);
                                assert_eq(success, UseItemSuccess.None, "we couldn't use item {ItemId}", tool);
                            }, [i, tool_data])
                            //
                            .append(LinkId.Timer, tool_data["wait_time"] ?? 5)
                            //
                            .append(LinkId.Await, function() {
                                return obj_ari.fsm.check_state_inclusive(PlayerState.Default);
                            })
                            //
                            .append(LinkId.Function, function(i, tool_data) {
                                var object_position = TS_OBJECT_POSITIONS.get(i);
                                tool_data.post_assertion(object_position);
                            }, [i, tool_data])
                    }

                    chain.insert_chain(inner_chain);
                }, [chain, tool_data])
                .append(LinkId.Function, CLEAN_SET)
        }
    }
});


TS_TESTS.push({
    name: "pet_and_ranch_pet_animals",
    run_once: true,
    call: function(chain) {
        __ts_travel_to(LocationId.PlayerHomeEast, chain);
        chain.append(LinkId.Function, function() {
            spawn_pet();
        })
        chain.append(LinkId.Function, function() {
            obj_pet.x = obj_ari.x;
            obj_pet.y = obj_ari.y;
            obj_pet.me.heart_points = 0;

            var selection = find_nearest_interactable(obj_ari.collision_list, obj_ari);
            assert(selection != undefined, "despite the pet being next to the player, no interaction was found")
            var cback = selection.attempt_interact(true);
            assert(cback != undefined, "despite attempting an interaction on a valid selection, no callback was returned");
            cback();
            assert(obj_pet.me.has_been_pat, "despite being picked up, the pet isn't pat!");
            assert(obj_pet.me.heart_points > 0, "despite being picked up, the pets heart points haven't gone up!");
            obj_pet.put_down();
            obj_pet.x = 32;
            obj_pet.y = 32;
        });
        chain.append(LinkId.Function, function() {
            var animal_a = new PlayerAnimal(AnimalKind.Chicken, "white", Sex.Male);
            animal_a.location_position = new LocationPosition(LocationId.PlayerHomeEast, Vec2(obj_ari.x, obj_ari.y));
            var animal_b = new PlayerAnimal(AnimalKind.Cow, "spotted", Sex.Male);
            animal_b.location_position = new LocationPosition(LocationId.PlayerHomeEast, Vec2(obj_ari.x, obj_ari.y));
            var animals_test = [
                animal_a,
                animal_b
            ];


            for (var i = 0; i < 2; i++) {
                var animal = animals_test[i];
                animal.heart_points = 0;
                animal.has_been_pat = false;
                spawn_animal(animal);
                var selection = find_nearest_interactable(obj_ari.collision_list, obj_ari);
                assert(selection != undefined, "despite the pet being next to the player, no interaction was found")
                var cback = selection.attempt_interact(true);
                assert(cback != undefined, "despite attempting an interaction on a valid selection, no callback was returned");
                cback();
                assert(animal.heart_points > 0, "despite petting the animal, it's heart_points didn't increase");
                assert(animal.has_been_pat, "despite petting the animal, it remains un-pat");
                instance_destroy(animal.instance);
            }
        });
    }
});

TS_TESTS.push({
    name: "pet",
    run_once: true,
    exclude_from_standard: true,
    call: function(chain) {
        __ts_travel_to(LocationId.PlayerHome, chain);

        for (var i = PetJob.Wood; i < PetJob.LEN; i++) {
            chain.append(LinkId.Function, function() {
                obj_pet.x = 183;
                obj_pet.y = 305;
                trace("Testing pet jobs during calm weather");
                WEATHER.set_weather(Weather.Calm);
            })
            chain.append(LinkId.Function, function() {
                assert(instance_exists(obj_pet), "No instance of a player pet has been found in the morning.");
            })
            //
            chain.append(LinkId.Function, function(job) {
                pet_update_at_time(CLOCK.time);
                PET_TEST_MENU_INTERACTION(job);
                CLOCK.jump(hours(11));
            }, [i]);
            chain.append(LinkId.Await, function() {
                return ANCHOR.get_menu(Menu.Journal) == undefined;
            });
            chain.append(LinkId.Function, function() {
                assert(!instance_exists(obj_pet), "No instance of a player pet should be found during the job, but one was found");
                CLOCK.jump(hours(19));
            });
            chain.append(LinkId.Function, function() {
                assert(instance_exists(obj_pet), "Pet should be back from it's job, but isn't in the room with Ari!");
            });
            chain.append(LinkId.Function, function() {
                end_day(false);
                new_day();
                pet_on_room_start();
            });
        }

        for (var i = PetJob.Wood; i < PetJob.LEN; i++) {
            __ts_travel_to(LocationId.PlayerHome, chain);
            chain.append(LinkId.Function, function() {
                WEATHER.set_weather(Weather.Calm);
                trace("Testing pet jobs during calm weather with player at job location");
            })
            chain.append(LinkId.Function, function() {
                assert(instance_exists(obj_pet), "No instance of a player pet has been found in the morning.");
                CLOCK.jump(hours(11));
            })
            chain.append(LinkId.Function, PET_TEST_MENU_INTERACTION, [i]);
            chain.append(LinkId.Await, function() {
                return ANCHOR.get_menu(Menu.Journal) == undefined;
            });
            __ts_travel_to(PET_PROTOTYPE.job_setup_data[i].location_id, chain);
            chain.append(LinkId.Function, function() {
                assert(instance_exists(obj_pet), "No instance of a player pet was found during a job in the same location at {LocationId}", CURRENT_LOCATION_ID);
                CLOCK.jump(hours(19));
            });
            __ts_travel_to(LocationId.PlayerHome, chain);
            chain.append(LinkId.Function, function() {
                assert(instance_exists(obj_pet), "Pet should be home despite its job, but it was found in {LocationId}", CURRENT_LOCATION_ID);
            });
            chain.append(LinkId.Function, function() {
                end_day(false);
                new_day();
                pet_on_room_start();
            });
        }

        for (var i = PetJob.Wood; i < PetJob.LEN; i++) {
            __ts_travel_to(LocationId.PlayerHome, chain);
            chain.append(LinkId.Function, function() {
                trace("Testing pet jobs during inclement weather");
                WEATHER.set_weather(Weather.Inclement);
            });
            chain.append(LinkId.Function, function() {
                assert(instance_exists(obj_pet), "No instance of a player pet has been found in the morning.");
            });

            chain.append(LinkId.Function, function(job) {
                pet_update_at_time(CLOCK.time);
                PET_TEST_MENU_INTERACTION(job);
                CLOCK.jump(hours(11));
            }, [i]);
            chain.append(LinkId.Await, function() {
                return ANCHOR.get_menu(Menu.Journal) == undefined;
            });
            chain.append(LinkId.Function, function() {
                assert(instance_exists(obj_pet), "No instance of a player pet has been found in the player home during the evening, but it's raining outside");
                CLOCK.jump(hours(19));
            });
            chain.append(LinkId.Function, function() {
                assert(instance_exists(obj_pet), "No instance of a player pet has been found in the player home at night, but it's raining outside");
            });
            chain.append(LinkId.Function, function() {
                end_day(false);
                new_day();
                pet_on_room_start();
            });
        }

        __ts_travel_to(LocationId.Farm, chain);
        chain.append(LinkId.Function, function() {
            WEATHER.set_weather(Weather.Calm);
            obj_ari.y += 48;
            obj_ari.x += 32;
            trace("Testing no job, player on farm");
            PET_TEST_MENU_INTERACTION(0);
        });
        chain.append(LinkId.Await, function() {
            return ANCHOR.get_menu(Menu.Journal) == undefined;
        });
        chain.append(LinkId.Function, function() {
            assert(!instance_exists(obj_pet), "An instance of obj_pet was found, but PET should be inside with no job");
            CLOCK.jump(hours(11));
        });
        chain.append(LinkId.Function, function() {
            assert(instance_exists(obj_pet), "No instance of obj_pet was found, but obj_pet should be on the farm with the player!");
            CLOCK.jump(hours(19));
        });
        chain.append(LinkId.Function, function() {
            assert(!instance_exists(obj_pet), "An instance of obj_pet was found in the night with no job, but PET should be inside with no job");
        });

        chain.append(LinkId.Function, function() {
            end_day(false);
            new_day();
            pet_on_room_start();
        });
        __ts_travel_to(LocationId.PlayerHome, chain);
        chain.append(LinkId.Function, function() {
            trace("Testing pet held");
            obj_pet.fsm.change_state(PetState.Held);
        });
        chain.append(LinkId.Function, function() {
            assert(instance_exists(obj_pet), "The pet is being held in the morning, but the pet isn't in the same room!");
            CLOCK.jump(hours(10) + minutes(59));
        });
        chain.append(LinkId.Timer, 120);
        chain.append(LinkId.Function, function() {
            assert(instance_exists(obj_pet), "The pet is being held in the evening, but the pet isn't in the same room!");
            CLOCK.jump(hours(18) + minutes(59));
        })
        chain.append(LinkId.Timer, 120);
        chain.append(LinkId.Function, function() {
            assert(instance_exists(obj_pet), "The pet is being held in the night, but the pet isn't in the same room!");
        });
    }
});

TS_TESTS.push({
    name: "all_locations",
    call: function(chain) {
        for (var i = 0; i < LocationId.LEN; i++) {
            if matches(
                i,
                LocationId.Aldaria,
                LocationId.SmallCoop,
                LocationId.SmallBarn,
                LocationId.MediumCoop,
                LocationId.MediumBarn,
                LocationId.LargeCoop,
                LocationId.LargeBarn,
                LocationId.Dungeon
            ) {
                continue;
            }
            if is_dungeon_room(location_id_to_gm_room(i)) {
                continue;
            }
            __ts_travel_to(i, chain);
        }
    },
    save_upgrade: true,
    save_upgrade_light: true,
});

TS_TESTS.push({
    name: "weather",
    call: function(chain) {
        chain
            .append(LinkId.Function, function() {
                WEATHER.set_weather(Weather.Inclement);
            })
            .append(LinkId.Timer, 180)
            .append(LinkId.Function, function() {
                WEATHER.set_weather(Weather.HeavyInclement);
            })
            .append(LinkId.Timer, 180)
            .append(LinkId.Function, function() {
                if !matches(CALENDAR.season(), Season.Spring, Season.Fall) {
                    return;
                }
                WEATHER.set_weather(Weather.Special);
            })
            .append(LinkId.Timer, 180)
            .append(LinkId.Function, function() {
                WEATHER.set_weather(Weather.Calm);
            })
    }
});

TS_TESTS.push({
    name: "dungeons",
    run_once: true,
    call: function(chain) {
        chain.append(LinkId.Function, function(chain) {
            randomize();
            trace("Starting a dungeon run with random seed {}", random_get_seed());
            enter_dungeon(0, DUNGEON_FLOOR_COUNT);

            var count = DUNGEON_FLOOR_COUNT;
            for (var i = 0; i < array_length(DUNGEON_RUNNER.side_levels); i++) {
                if DUNGEON_RUNNER.side_levels[i] != undefined {
                    count += 1;
                }
            }
            repeat count {
                chain.insert_chain(new Chain()
                    .append(LinkId.Function, function() {
                        DUNGEON_RUNNER.proceed("cheater", true);
                    })
                    .append(LinkId.Timer, 1)
                );
            }
        }, [chain])
    }
});

TS_TESTS.push({
    name: "schedule_execution",
    call: function(chain) {
        //
        chain.append(LinkId.Function, function() {
            end_day(false);
            new_day();
        });
        //
        //
        //
        //
        __ts_travel_to(LocationId.Town, chain);
        for (var i = 0; i < 16; i++) {
            chain
                .append(LinkId.Function, function() {
                    CLOCK.jump(CLOCK.time + hours(1));
                })
                .append(LinkId.Timer, FPS / 6);
        }
    }
});

function ts_test_date(date, npc_id, chain) {
    static HARNESS = function(npc_id, expected) {
        assert_eq(
            NPCS[npc_id].can_go_on_dates(npc_id) && ari_eligible_for_date(npc_id),
            expected,
            "{NpcId} eligibility is incorrectly {bool}!",
            npc_id,
            !expected,
        );
    }

    //
    chain.append(LinkId.Function, function() {
        ELIGIBLE_DATE_DAYS = array_create_ext(Day.LEN, identity);
    });

    //
    var control_npc_id = npc_id == NpcId.Adeline ? NpcId.Celine : NpcId.Adeline;

    chain.append(LinkId.Function, function(control_npc_id, npc_id) {
        BUGGER.execute_command(format("goto {NpcId}", npc_id));
        NPCS[npc_id].set_heart_level(10);
        T2R.write(format("{NpcId}_status", npc_id), "dating");
        NPCS[control_npc_id].set_heart_level(10);
        T2R.write(format("{NpcId}_status", control_npc_id), "dating");
    }, [control_npc_id, npc_id]);

    chain.append(LinkId.Timer, 1);

    chain.append(LinkId.Function, function(npc_id, date) {
        var menu = date_selection_ui(npc_id);
        for (var i = 0; i < array_length(menu.pilot.map); i++) {
            var node = menu.pilot.map[i][0];
            if node.get_label() == date_to_string(date) {
                ANCHOR.tap_node(node);
                break;
            }
        }
    }, [npc_id, date]);

    chain.append(LinkId.Await, function() {
        var textbox = ANCHOR.get_menu(Menu.Textbox);
        if textbox == undefined {
            return false;
        }

        if textbox.state == TextboxState.Say && !textbox.interacted {
            textbox.driver.prompt_index_selected = TS_TEXTBOX_PROMPT_INDEX();
            textbox.interact();
        }


        return textbox.driver.state == ConversationDriverState.Finished;
    });

    chain.append(LinkId.Await, function() {
        return MIST.is_running();
    });

    chain.append(LinkId.Await, function() {
        return !MIST.is_running();
    });

    //
    chain.append(LinkId.Await, function() {
        var popup = ANCHOR.get_menu(Menu.Popup);
        if popup == undefined {
            return false;
        }
        ANCHOR.tap_node(popup.buttons.first());
        return true;
    });

    chain.append(LinkId.Timer, 10);

    chain.append(LinkId.Await, function(npc_id, control_npc_id, HARNESS) {
        //
        var popup = ANCHOR.get_menu(Menu.Popup);
        if popup == undefined {
            return false;
        }
        ANCHOR.tap_node(popup.buttons.first());

        //
        HARNESS(npc_id, false);
        HARNESS(control_npc_id, false);

        //
        //
        var history = array_last(ARI.date_history);
        history.timestamp -= days(1);

        HARNESS(npc_id, false);
        HARNESS(control_npc_id, true);

        //
        ARI.date_history = [];
        HARNESS(npc_id, true);
        HARNESS(control_npc_id, true);

        return true;
    }, [npc_id, control_npc_id, HARNESS]);
}

TS_TESTS.push({
    name: "date_all",
    exclude_from_standard: true,
    call: function(chain) {
        for (var i = 0; i < NpcId.LEN; i++) {
            if !NPC_PROTOTYPES[i].dateable {
                continue;
            }

            for (var j = 0; j < Date.LEN; j++) {
                //
                if DATES[j].unlisted  {
                    continue;
                }

                ts_test_date(j, i, chain);
            }
        }
    }
});

TS_TESTS.push({
    name: "artifact_replicas",
    run_once: true,
    call: function() {
        for (var i = 0; i < ItemId.LEN; i++) {
            if ITEM_PROTOTYPES[i].tags.contains("archaeology") {
                assert_neq(
                    try_string_to_item_id(format("artifact_replica_{ItemId}", i)),
                    undefined,
                    format("Artifact '{ItemId}' does not have a replica!", i),
                );
            }
        }
    }
})

TS_TESTS.push({
    name: "spells",
    run_once: true,
    exclude_from_standard: true,
    call: function(chain) {
        __ts_travel_to(LocationId.PlayerHome, chain);
        chain.append(LinkId.Function, function() {
            ARI.set_health(1);
            ARI.set_stamina(1);
        });
        set_player_spell(Spell.FullRestore, chain);
        chain.append(LinkId.Function, function() {
            assert(ARI.get_health() == ARI.get_max_health(), "After full restore ari is not at full health");
            assert(ARI.get_stamina() == ARI.get_max_stamina(), "After full restore ari is not at full stamina");
        });

        set_player_spell(Spell.SummonRain, chain);
        chain.append(LinkId.Function, function() {
            assert(WEATHER.current_weather == Weather.HeavyInclement, "After summon rain the weather isn't heavy inclement!");
        });
        __ts_travel_to(LocationId.Farm, chain);

        chain.append(LinkId.Function, function() {
            for (var xx = 0, xxc = GRID.dims.x; xx < xxc; xx++) {
                for (var yy = 0, yyc = GRID.dims.y; yy < yyc; yy++) {
                    erase_object_node(GRID, GRID.node_index_for_cell(xx, yy));
                }
            }
            obj_ari.y += 240;
            var x_check = obj_ari.x div 8;
            var y_check = obj_ari.y div 8;
            for (var xx = x_check - 1, xxc = x_check + 3; xx < xxc; xx++) {
                for (var yy = y_check - 1, yyc = y_check + 3; yy < yyc; yy++) {
                    GRID.write_node(xx, yy, ObjectId.Turnip);
                }
            }

        });

        set_player_spell(Spell.Growth, chain);

        chain.append(LinkId.Timer, 180);
        chain.append(LinkId.Function, function() {
            var x_check = obj_ari.x div 8;
            var y_check = obj_ari.y div 8;
            for (var xx = x_check - 1, xxc = x_check + 3; xx < xxc; xx++) {
                for (var yy = y_check - 1, yyc = y_check + 3; yy < yyc; yy++) {
                    var node = GRID.node_parent[GRID.node_index_for_cell(xx, yy)];
                    assert(node.stage == node.prototype.day_to_stage.last(), "despite going through the growth spell, the turnip is still at stage {}", node.stage);
                }
            }
        });

        //
        chain.append(LinkId.Function, function() {
            //
            obj_ari.x += 300;
            var x_check = obj_ari.x div 8;
            var y_check = obj_ari.y div 8;
            for (var xx = x_check - 1, xxc = x_check + 3; xx < xxc; xx++) {
                for (var yy = y_check - 1, yyc = y_check + 3; yy < yyc; yy++) {
                    erase_object_node(GRID, GRID.node_index_for_cell(xx, yy));
                }
            }


            for (var xx = x_check - 1, xxc = x_check + 3; xx < xxc; xx++) {
                for (var yy = y_check - 1, yyc = y_check + 3; yy < yyc; yy++) {
                    GRID.write_node(xx, yy, ObjectId.GrassSmall);
                }
            }
        });

        set_player_spell(Spell.Growth, chain);
        chain.append(LinkId.Function, function() {
            var x_check = obj_ari.x div 8;
            var y_check = obj_ari.y div 8;
            for (var xx = x_check - 1, xxc = x_check + 3; xx < xxc; xx++) {
                for (var yy = y_check - 1, yyc = y_check + 3; yy < yyc; yy++) {
                    var object_id = GRID.node_object_id[GRID.node_index_for_cell(xx, yy)];
                    assert(object_id == ObjectId.GrassLarge, "Despite being hit by a growth spell, grass small ended up as {ObjectId}", object_id);
                }
            }
        });

        //
        chain.append(LinkId.Function, function() {
            var x_check = obj_ari.x div 8;
            var y_check = obj_ari.y div 8;
            for (var xx = x_check - 1, xxc = x_check + 3; xx < xxc; xx++) {
                for (var yy = y_check - 1, yyc = y_check + 3; yy < yyc; yy++) {
                    erase_object_node(GRID, GRID.node_index_for_cell(xx, yy));
                }
            }
            GRID.write_node(x_check + 1, y_check, ObjectId.TreeOak);
        });
        set_player_spell(Spell.Growth, chain);
        chain.append(LinkId.Function, function() {
            var x_check = obj_ari.x div 8;
            var y_check = obj_ari.y div 8;
            var node = GRID.node_parent[GRID.node_index_for_cell(x_check + 2, y_check)];
            assert(node.stage == 1, "For some reason the tree's stage is {} when it should be one after a growth spell", node.stage);
        });
        set_player_spell(Spell.Growth, chain);
        chain.append(LinkId.Function, function() {
            var x_check = obj_ari.x div 8;
            var y_check = obj_ari.y div 8;
            var node = GRID.node_parent[GRID.node_index_for_cell(x_check + 2, y_check)];
            assert(node.stage == 2, "For some reason the tree's stage is {} when it should be two after a growth spell", node.stage);
        });
        set_player_spell(Spell.Growth, chain);
        chain.append(LinkId.Function, function() {
            var x_check = obj_ari.x div 8;
            var y_check = obj_ari.y div 8;
            var node = GRID.node_parent[GRID.node_index_for_cell(x_check + 2, y_check)];
            assert(node.stage == 3, "For some reason the tree's stage is {} when it should be three after a growth spell", node.stage);
        });


        //
        chain.append(LinkId.Function, function() {
            var x_check = obj_ari.x div 8;
            var y_check = obj_ari.y div 8;
            erase_object_node(GRID, GRID.node_index_for_cell(x_check + 2, y_check));
            GRID.write_node(x_check, y_check, ObjectId.BlueberryBush);
            var node = GRID.node_parent[GRID.node_index_for_cell(x_check, y_check)]
            interact(node);
            assert(node.day_count == 0, "After being interacted with, the blueberry bush's day count didn't change");
        });

        set_player_spell(Spell.Growth, chain);

        chain.append(LinkId.Function, function() {
            var x_check = obj_ari.x div 8;
            var y_check = obj_ari.y div 8;
            var node = GRID.node_parent[GRID.node_index_for_cell(x_check, y_check)];
            assert(node.day_count == node.prototype.regrow_days, "For some reason the bush's daycount is {} when it should be {} after a growth spell", node.day_count, node.prototype.regrow_days);
            erase_object_node(GRID, GRID.node_index_for_cell(x_check, y_check));
            GRID.write_node(x_check, y_check + 2, ObjectId.SmallRockStoneOne);
            GRID.write_node(x_check, y_check + 4, ObjectId.WornTable);
        });

        set_player_spell(Spell.FireBreath, chain);
        chain.append(LinkId.Timer, fiddle_get("player").fire_breath_time_cap);
        chain.append(LinkId.Function, function() {
            var x_check = obj_ari.x div 8;
            var y_check = obj_ari.y div 8;
            assert(ARI.status_effects.get_effect_value(StatusEffectId.FlameBreath, 0) == 0, "Flame breath should no longer be active but still has {} frames to go", ARI.status_effects.get_effect_value(StatusEffectId.FlameBreath, 0));
            assert(GRID.node_object_id[GRID.node_index_for_cell(x_check, y_check + 2)] == undefined, "Flame breath should've destroyed the rock but didn't");
            assert(GRID.node_object_id[GRID.node_index_for_cell(x_check, y_check + 4)] == undefined, "Flame breath should've destroyed the table but didn't");
        });

        //
        chain.append(LinkId.Function, function() {
            var itinerary = create_dungeon_itinerary();
            itinerary.get(60).impl = DungeonImpl.Standard;
            itinerary.get(60).gm_room = rm_mines_lava_61;
            DUNGEON_RUNNER = new DungeonRunner(itinerary, 60);
            goto_gm_room(rm_mines_lava_61, true);
        });
        chain.append(LinkId.Timer, 120);
        set_player_spell(Spell.SummonRain, chain);
        chain.append(LinkId.Function, function() {
            assert(instance_exists(obj_lavaplatform), "Despite casting rain inside, there are no lavaplatforms");
            assert(WEATHER.current_weather == Weather.HeavyInclement, "Despite casting rain inside, the weather is {Weather} and not Heavy Inclement", WEATHER.current_weather);
        });
    }
});

TS_TESTS.push({
    name: "poll_statues",
    run_once: true,
    call: function(chain) {
        //
        //
        for (var i = 0; i < 100; i++) {
            chain
                .append(LinkId.Function, function() {
                    poll_statue_reward(CHICKEN_STATUE_REWARDS, true);
                });
        }

        //
        for (var i = 0; i < 100; i++) {
            chain
                .append(LinkId.Function, function() {
                    poll_statue_reward(CHICKEN_STATUE_REWARDS, false);
                });
        }

        //
        //
        for (var i = 0; i < 100; i++) {
            chain
                .append(LinkId.Function, function() {
                    poll_statue_reward(WISHING_WELL_REWARDS, true);
                });
        }

        //
        for (var i = 0; i < 100; i++) {
            chain
                .append(LinkId.Function, function() {
                    poll_statue_reward(WISHING_WELL_REWARDS, false);
                });
        }

    }
});

TS_TESTS.push({
    name: "talking_and_gifting",
    call: function(chain) {
        //
        chain
            .append(LinkId.Function, function() {
                BUGGER.execute_command("goto celine");
            })
            .append(LinkId.Timer, 1)
            .append(LinkId.Function, function() {
                var next_conversation = T2R.request_conversation(NpcId.Celine);
                if next_conversation != undefined {
                    obj_celine.talk(next_conversation);
                }
            })
            .append(LinkId.Timer, 60)
            .append(LinkId.Function, function() {
                ANCHOR.get_menu(Menu.Textbox).close();
            })
            .append(LinkId.Await, function() {
                return ANCHOR.get_menu(Menu.Textbox) == undefined;
            })
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
            .append(LinkId.Function, function() {
                T2R.conversation_end();
                obj_celine.receive_gift(new LiveItem(ItemId.Tulip), true);
                obj_celine.me.gift_flag = true;
            })
            .append(LinkId.Timer, 60)
            .append(LinkId.Function, function() {
                ANCHOR.get_menu(Menu.Textbox).close();
            })
            .append(LinkId.Await, function() {
                return ANCHOR.get_menu(Menu.Textbox) == undefined;
            })
            .append(LinkId.Function, function() {
                T2R.conversation_end();
                obj_celine.receive_gift(new LiveItem(ItemId.Tulip));
                obj_celine.me.gift_flag = true;
            })
            .append(LinkId.Timer, 60)
            .append(LinkId.Function, function() {
                ANCHOR.get_menu(Menu.Textbox).close();
            })
            .append(LinkId.Await, function() {
                return ANCHOR.get_menu(Menu.Textbox) == undefined;
            })
            .append(LinkId.Function, function() {
                T2R.conversation_end();
                obj_celine.receive_gift(new LiveItem(ItemId.OreStone));
                obj_celine.me.gift_flag = true;
            })
            .append(LinkId.Timer, 60)
            .append(LinkId.Function, function() {
                ANCHOR.get_menu(Menu.Textbox).close();
            })
            .append(LinkId.Await, function() {
                return ANCHOR.get_menu(Menu.Textbox) == undefined;
            })
    }
});

TS_TESTS.push({
    name: "menus",
    save_upgrade: true,
    save_upgrade_light: false,
    call: function(chain) {
        for (var menu_iter = 0; menu_iter < Menu.LEN; menu_iter++) {
            var data = MENUS.get(menu_iter);
            var should_skip = !data.run_tests
                || (data.run_test_once && MENU_TEST_LOG.contains(string(menu_iter)));
            if should_skip {
                chain.append(LinkId.Function, function(menu_iter) {
                    trace("skipping {Menu}...", menu_iter);
                }, [menu_iter]);
                continue;
            }

            if menu_iter == Menu.Customization && TS_SAVE_UPGRADE {
                //
                //
                continue;
            }


            MENU_TEST_LOG.insert(string(menu_iter));

            var menus = List();
            chain.append(LinkId.Function, function(menu_iter) {
                trace("testing {Menu}...", menu_iter);
                TEST_SUITE_MENU_TARGET = menu_iter;
            }, [menu_iter]);

            //
            var uses_journal = matches(
                menu_iter,
                Menu.Almanac, Menu.Map, Menu.Player, Menu.Animal,
                Menu.Relationships, Menu.Settings, Menu.Spellcasting,
                Menu.Customization,
            );
            #macro TEST_SUITE_JOURNAL global.__test_suite_journal
            if uses_journal {
                chain.append(LinkId.Function, function(menus) {
                    TEST_SUITE_JOURNAL = ANCHOR.spawn_menu(Menu.Journal);
                    TEST_SUITE_JOURNAL.set_active_sub_menu(Menu.Player);
                    menus.push(TEST_SUITE_JOURNAL);
                }, [menus])
            }

            switch menu_iter {
                case Menu.Relationships:
                    chain.append(LinkId.Function, function(chain) {
                        TEST_SUITE_JOURNAL.set_active_sub_menu(Menu.Relationships);
                        var pilot = TEST_SUITE_JOURNAL.sub_menu.pilot;
                        for (var i = 0; i < array_length(pilot.map); i++) {
                            var node = pilot.map[i][0];
                            chain.insert_chain(new Chain()
                                .append(LinkId.Function, function(node) {
                                    TEST_BREADCRUMB = npc_id_to_string(node.board_get("npc_id"));
                                    ANCHOR.tap_node(node);
                                }, [node])
                                .append(LinkId.Timer, 1)
                            );
                        }
                    }, [chain]);
                    break;
                case Menu.Almanac:
                    chain.append(LinkId.Function, function() {
                        TEST_SUITE_JOURNAL.set_active_sub_menu(Menu.Almanac)
                        var menu = ANCHOR.get_menu(Menu.Almanac);
                        for (var i = 0; i < menu.categories.count(); i++) {
                            ANCHOR.tap_node(menu.categories.get(i));
                        }
                    })
                    break;
                case Menu.Animal:
                    chain.append(LinkId.Function, function() {
                        TEST_SUITE_JOURNAL.set_active_sub_menu(Menu.Animal)
                        var menu = ANCHOR.get_menu(Menu.Animal);
                        for (var i = 0; i < array_length(menu.left_pilot.map); i++) {
                            ANCHOR.tap_node(menu.left_pilot.map[i][0]);
                        }
                    })
                    break;
                case Menu.Map:
                    chain.append(LinkId.Function, function() {
                        TEST_SUITE_JOURNAL.set_active_sub_menu(Menu.Map)
                    })
                    break;
                case Menu.Spellcasting:
                    chain.append(LinkId.Function, function() {
                        TEST_SUITE_JOURNAL.set_active_sub_menu(Menu.Spellcasting);
                    })
                    break;
                case Menu.Popup:
                    //
                    //
                    //
                    #macro TEST_SUITE_TOOLTIP global.__test_suite_tooltip
                    for (var j = 0; j < ItemId.LEN; j++) {
                        chain
                            .append(LinkId.Function, function(j) {
                                static MAX_HEIGHT = fiddle_get("ui/misc/max_tooltip_height");
                                TEST_BREADCRUMB = item_id_to_string(j);
                                var item = new LiveItem(j);

                                switch j {
                                    case ItemId.RecipeScroll:
                                        item.inner_item = ItemId.BlackberryJam;
                                        break;
                                    case ItemId.CraftingScroll:
                                        item.inner_item = ItemId.TileRoofFenceV1;
                                        break;
                                    case ItemId.Cosmetic:
                                        item.cosmetic = "dress_maid";
                                        break;
                                    case ItemId.AnimalCosmetic:
                                        item.animal_cosmetic = {
                                            animal: AnimalKind.Chicken,
                                            cosmetic: "flower_crown",
                                        }
                                        break;
                                    case ItemId.PetCosmetic:
                                        item.pet_cosmetic_set_name = "halo";
                                        break;
                                    default: break;
                                }

                                TEST_SUITE_TOOLTIP = create_tooltip(item);

                                if TEST_SUITE_TOOLTIP.backplate.get_height() > MAX_HEIGHT {
                                    var n = TEST_SUITE_TOOLTIP.body_text;
                                    SPILLOVER_LOGS.push({
                                        node: n.display(),
                                        menu: "tooltip",
                                        max_size: MAX_HEIGHT,
                                        my_size: TEST_SUITE_TOOLTIP.backplate.get_height(),
                                    });
                                }
                            }, [j])
                            .append(LinkId.Timer, 1)
                            .append(LinkId.Function, function() {
                                TEST_SUITE_TOOLTIP.close();
                            })
                    }
                    break;
                case Menu.Dingaling:
                    chain
                        .append(LinkId.Function, function() {
                            ANCHOR
                                .get_menu(Menu.Dingaling)
                                .create_skill_dingaling(Skill.Farming, 1);
                        })
                        .append(LinkId.Timer, 120)
                        .append(LinkId.Function, function() {
                            ANCHOR
                                .get_menu(Menu.Dingaling)
                                .create_heart_dingaling(NpcId.Adeline, 1);
                        })
                        .append(LinkId.Timer, 120);
                    break;
                case Menu.DragonShrine:
                    //
                    #macro TEST_SUITE_DS_MENU global.__test_suite_ds_menu

                    global.TS_DS_TRAVERSE_CATEGORIES = function(chain) {
                        var pilot = TEST_SUITE_DS_MENU.category_pilot;
                        for (var i = 0; i < array_length(pilot.map); i++) {
                            for (var j = 0; j < array_length(pilot.map[i]); j++) {
                                var node = pilot.map[i][j];
                                chain.insert_chain(new Chain()
                                    .append(LinkId.Function, function(node) {
                                        ANCHOR.tap_node(node);
                                    }, [node])
                                    .append(LinkId.Await, function() {
                                        return TEST_SUITE_DS_MENU.chain == undefined;
                                    })
                                    .append(LinkId.Function, global.TS_DS_TRAVERSE_ENTRIES, [chain])
                                    .append(LinkId.Function, function() {
                                        TEST_SUITE_DS_MENU.create_category_nodes(TEST_SUITE_DS_MENU.scroller.canvas.board_get("skill_id"));
                                        TEST_SUITE_DS_MENU.scroller.free();
                                    })
                                    .append(LinkId.Await, function() {
                                        return TEST_SUITE_DS_MENU.chain == undefined;
                                    })
                                );
                            }
                        }
                    }

                    global.TS_DS_TRAVERSE_ENTRIES = function(chain) {
                        var pilot = TEST_SUITE_DS_MENU.tier_pilot;
                        for (var i = 0; i < array_length(pilot.map); i++) {
                            for (var j = 0; j < array_length(pilot.map[i]); j++) {
                                var node = pilot.map[i][j];
                                if !node.is_unlocked() || node.soft_locked {
                                    continue;
                                }
                                chain.insert_chain(new Chain()
                                    .append(LinkId.Function, function(node) {
                                        ANCHOR.tap_node(node);
                                    }, [node])
                                    .append(LinkId.Timer, 1)
                                    .append(LinkId.Function, function() {
                                        ANCHOR.tap_node(TEST_SUITE_DS_MENU.entry_popup.buttons.last());
                                        ANCHOR.tap_node(TEST_SUITE_DS_MENU.entry_popup.buttons.first());
                                    })
                                    .append(LinkId.Await, function() {
                                        return ANCHOR.get_menu(Menu.Popup) == undefined;
                                    })
                                );
                            }
                        }
                    }

                    chain.append(LinkId.Function, function() {
                        ARI.modify_essence(100000);
                    });

                    //
                    for (var variant = 0; variant < ShrineMenuVariant.LEN; variant++) {

                        //
                        chain.append(LinkId.Function, function(variant) {
                            ARI.perks = array_create(Perk.LEN, false);
                            TEST_SUITE_DS_MENU = ANCHOR.spawn_menu(Menu.DragonShrine, variant);
                        }, [variant]);

                        if variant == ShrineMenuVariant.Horse {
                            chain.append(LinkId.Function, global.TS_DS_TRAVERSE_ENTRIES, [chain]);
                        } else {
                            chain.append(LinkId.Function, global.TS_DS_TRAVERSE_CATEGORIES, [chain, variant]);
                        }

                        chain.append(LinkId.Function, function() {
                            TEST_SUITE_DS_MENU.close();
                        })

                        chain.append(LinkId.Await, function() {
                            return ANCHOR.get_menu(Menu.DragonShrine) == undefined;
                        });
                    }
                    break;
                case Menu.Settings:
                    var category_keys = [
                        "gameplay",
                        "display",
                        "audio",
                        "accessibility",
                        "controls",
                        "exit_cat",
                    ];
                    chain.append(LinkId.Function, function(menus) {
                        #macro TEST_SUITE_SETTINGS global.__test_suite_settings
                        TEST_SUITE_SETTINGS = ANCHOR.spawn_menu(Menu.Settings, TEST_SUITE_JOURNAL, TEST_SUITE_JOURNAL);
                        menus.push(TEST_SUITE_SETTINGS);
                    }, [menus])
                    for (var j = 0; j < array_length(category_keys); j++) {
                        chain.append(LinkId.Timer, 1);
                        chain.append(LinkId.Function, function(key) {
                            ANCHOR.tap_node(TEST_SUITE_SETTINGS.categories[$ key]);
                        }, [category_keys[j]]);
                    }
                    break;
                case Menu.QuestLog:
                    chain
                        .append(LinkId.Function, function(menus, chain) {
                            #macro __QUEST_TEST_RESET_DATA global.____quest_test_reset_data
                            __QUEST_TEST_RESET_DATA = {
                                board: REQUEST_BOARD,
                                active: QUEST_LOG.active,
                                completed: QUEST_LOG.completed,
                            }
                            REQUEST_BOARD = ListFromArray(QUESTS.keys());
                            QUEST_LOG.active = Map();
                            QUEST_LOG.completed = HashSet();

                            var menu = spawn_request_board_menu();
                            menus.push(menu.journal);
                            for (var i = 0; i < array_length(menu.left_pilot.map); i++) {
                                var node = menu.left_pilot.map[i][0];
                                chain.insert_chain(new Chain()
                                    .append(LinkId.Function, function(node) {
                                        TEST_BREADCRUMB = node.board_get("quest_name");
                                        ANCHOR.tap_node(node);
                                    }, [node])
                                    .append(LinkId.Timer, 1)
                                );
                            }

                        }, [menus, chain])
                        .append(LinkId.Timer, 15);

                    //
                    chain.append(LinkId.Function, function() {
                        QUEST_LOG.completed = HashSet();

                        var _qnames = QUESTS.keys();

                        for (var i = 0, c = array_length(_qnames); i < c; i++) {
                            QUEST_LOG.start(_qnames[i]);
                        }
                    }).append(LinkId.Timer, 15);

                    chain.append(LinkId.Function, function() {
                        REQUEST_BOARD = __QUEST_TEST_RESET_DATA.board;
                        QUEST_LOG.active = __QUEST_TEST_RESET_DATA.active;
                        QUEST_LOG.completed = __QUEST_TEST_RESET_DATA.completed;
                    })
                    break;
                case Menu.Spellcasting:
                    chain.append(LinkId.Function, function(menus) {
                        var menu = ANCHOR.spawn_menu(Menu.Spellcasting, TEST_SUITE_JOURNAL, TEST_SUITE_JOURNAL);
                         for (var i = 0; i < array_length(menu.left_pilot.map); i++) {
                            var node = menu.left_pilot.map[i][0];
                            chain.insert_chain(new Chain()
                                .append(LinkId.Function, function(node) {
                                    ANCHOR.tap_node(node);
                                }, [node])
                                .append(LinkId.Timer, 1)
                            );
                        }
                    }, [menus])
                    break;
                case Menu.Customization:
                    #macro TS_CUSTOMIZATION global.__ts_customization
                    chain.append(LinkId.Function, function(menus) {
                        TEST_SUITE_JOURNAL.set_active_sub_menu(Menu.Customization);
                        TS_CUSTOMIZATION = ANCHOR.get_menu(Menu.Customization);
                    }, [menus]);
                    chain.append(LinkId.Timer, 20);

                    var harness = function(slot, asset, color_index) {
                        TS_CHAIN
                            .append(LinkId.Function, function(slot) {
                                ANCHOR.tap_node(find_node(slot));
                            }, [slot])
                            .append(LinkId.Timer, 20)
                            .append(LinkId.Function, function() {
                                var removal = find_node("removal_square");
                                if removal != undefined {
                                    ANCHOR.tap_node(removal);
                                }
                            })
                            .append(LinkId.Timer, 20)
                            .append(LinkId.Function, function(asset) {
                                ANCHOR.tap_node(find_node(asset));
                            }, [asset])
                            .append(LinkId.Timer, 20)

                        if color_index != undefined {
                            TS_CHAIN
                                .append(LinkId.Function, function(color_index) {
                                    ANCHOR.tap_node(find_node(format("color_square_{}", color_index)));
                                }, [color_index])
                                .append(LinkId.Timer, 20)
                        }
                    }

                    harness("skin_slot", "tone_1");
                    harness("eyes_slot", "eyes_default", 1);
                    harness("hair_slot", "hair_straight_long_fringed", 44);
                    harness("facial_hair_slot", "beard_thick", 2);
                    harness("face_gear_slot", "face_gear_glasses", 4);
                    harness("head_gear_slot", "head_bandana", 6);
                    harness("top_slot", "dress_sleeveless_basic", 8);
                    harness("back_slot", "back_gear_basic_backpack", 1);
                    harness("bottom_slot", "pants_basic", 10);
                    harness("feet_slot", "shoes_boots", 3);

                    TS_CHAIN
                        .append(LinkId.Function, function() {
                            ANCHOR.tap_node(find_node("preset_button"));
                        })
                        .append(LinkId.Timer, 20)
                        .append(LinkId.Function, function() {
                            ANCHOR.tap_node(find_node("body_frame_1"));
                        })
                        .append(LinkId.Timer, 20)
                        .append(LinkId.Function, function() {
                            ANCHOR.tap_node(find_node("body_frame_1"));
                        })
                        .append(LinkId.Timer, 20)
                        .append(LinkId.Function, function() {
                            ANCHOR.tap_node(find_node("preset_button"));
                        })
                        .append(LinkId.Timer, 20)
                        .append(LinkId.Function, function() {
                            ANCHOR.hover_node(find_node("body_frame_1"));
                            ANCHOR.tap_node(find_node("trash"));
                        })
                        .append(LinkId.Timer, 20)
                         .append(LinkId.Function, function() {
                            ANCHOR.tap_node(find_node("body_frame_0"));
                        })
                        .append(LinkId.Timer, 20)
                    break;
                case Menu.Inbox:
                    chain.append(LinkId.Function, function(chain, menus) {
                        var keys = LETTERS.keys();
                        ARI.inbox.contents.clear();
                        for (var i = 0; i < array_length(keys); i++) {
                            ARI.inbox.push_mail(keys[i]);
                        }

                        var menu = ANCHOR.spawn_menu(Menu.Inbox);
                        for (var i = 0; i < array_length(menu.left_pilot.map); i++) {
                            var node = menu.left_pilot.map[i][0];
                            chain.insert_chain(new Chain()
                                .append(LinkId.Function, function(node) {
                                    ANCHOR.tap_node(node);
                                }, [node])
                                .append(LinkId.Timer, 1)
                            );
                        }

                        menus.push(menu);
                    }, [chain, menus]);
                    break;
                case Menu.Adoption:
                    chain.append(LinkId.Function, function(menus) {
                        menus.push(ANCHOR.spawn_menu(Menu.Adoption));
                    }, [menus])
                    for (var j = 0; j < AnimalKind.LEN; j++) {
                        chain.append(LinkId.Function, function(j) {
                            if !animal_is_unlocked(j) {
                                return;
                            }
                            var menu = ANCHOR.get_menu(Menu.Adoption);
                            menu.left_pilot.set_position(0, j);
                            ANCHOR.tap_node(menu.left_pilot.get());
                        }, [j])
                        chain.append(LinkId.Timer, 1);
                    }
                    break;
                case Menu.Museum:
                    chain.append(LinkId.Function, function(chain, menus) {
                        var menu = ANCHOR.spawn_menu(Menu.Museum);
                        menus.push(menu);
                        for (var j = 0; j < array_length(menu.wing_pilot.map); j++) {
                            var column = menu.wing_pilot.map[j];
                            for (var k = 0; k < array_length(column); k++) {
                                var node = column[k];
                                chain.insert_chain(new Chain()
                                    .append(LinkId.Function, function(node) {
                                        ANCHOR.tap_node(node);
                                    }, [node])
                                    .append(LinkId.Timer, 30)
                                    .append(LinkId.Function, function(chain, menu) {
                                        var inner_chain = new Chain();
                                        for (var i = 0; i < array_length(menu.set_pilot.map); i++) {
                                            inner_chain.append(LinkId.Function, function(node) {
                                                ANCHOR.tap_node(node);
                                            }, [menu.set_pilot.map[i][0]])
                                            inner_chain.append(LinkId.Timer, 1);
                                        }

                                        chain.insert_chain(inner_chain);
                                    }, [chain, menu])
                                    .append(LinkId.Function, function(menu) {
                                        ANCHOR.free_children(menu.left_header);
                                        ANCHOR.free_children(menu.left_body);
                                        ANCHOR.free_children(menu.right_body);
                                        menu.enter_wing_selection();
                                    }, [menu])
                                    .append(LinkId.Timer, 15)
                                );
                            }
                        }
                    }, [chain, menus])
                    break;
                case Menu.Store:
                    #macro TS_STORE_MENU global.__ts_store_menu

                    for (var j = 0; j < Store.LEN; j++) {
                        chain
                            .append(LinkId.Function, function(store, chain) {
                                TS_STORE_MENU = ANCHOR.spawn_menu(Menu.Store, store);

                                var count = TS_STORE_MENU.categories.count();
                                if count > 1 {
                                    repeat count {
                                        chain.insert_chain(new Chain()
                                            .append(LinkId.Function, function() {
                                                ANCHOR.tap_node(TS_STORE_MENU.carousel.arrow_right_button);
                                            })
                                            .append(LinkId.Timer, 1)
                                        );
                                    }
                                }
                            }, [j, chain])
                            .append(LinkId.Function, function() {
                                TS_STORE_MENU.close();
                            })
                    }
                    break;
                case Menu.Crafting:
                    #macro TS_CRAFTING_MENU global.__ts_crafting_menu

                    var ui_data = [
                        WOODCRAFTING_UI_DATA,
                        COOKING_UI_DATA,
                        BLACKSMITHING_UI_DATA,
                        MILLING_UI_DATA,
                        REFINING_UI_DATA,
                        DRAGON_FORGING_UI_DATA,
                    ];
                    for (var j = 0; j < array_length(ui_data); j++) {
                        var data = ui_data[j];
                        chain.append(LinkId.Await, function() {
                            return instance_exists(obj_ari) ;
                        })
                        chain
                            .append(LinkId.Function, function(data, chain) {
                                var obj = data == COOKING_UI_DATA ? ObjectId.AdeptKitchen : undefined;
                                TS_CRAFTING_MENU = spawn_crafting_menu(data, obj_ari.x, obj_ari.y, obj);

                                assert(TS_CRAFTING_MENU.sub_data.get("categories").first().name == "misc_local/all_items");

                                chain.insert_chain(new Chain()
                                    .append(LinkId.Function, function(chain) {
                                        TS_CRAFTING_MENU.select_category(0);
                                        ANCHOR.set_active_pilot(TS_CRAFTING_MENU.left_pilot);
                                        for (var j = 0; j < array_length(TS_CRAFTING_MENU.left_pilot.map); j++) {
                                            var column = TS_CRAFTING_MENU.left_pilot.map[j];
                                            for (var k = 0; k < array_length(column); k++) {
                                                var node = column[k];
                                                if node == undefined || !node.blackboard.contains_key("item_id") {
                                                    continue;
                                                }

                                                chain.insert_chain(new Chain()
                                                    .append(LinkId.Function, function(node) {
                                                        TEST_BREADCRUMB = item_id_to_string(node.board_take("item_id"));
                                                        node.set_tap_sound(undefined); //
                                                        TS_CRAFTING_MENU.left_pilot.force_select(node);
                                                        ANCHOR.hover_node(node);
                                                        ANCHOR.tap_node(node);
                                                    }, [node])
                                                    .append(LinkId.Timer, 1)
                                                );
                                            }
                                        }
                                    }, [chain])
                                );

                            }, [data, chain])
                            .append(LinkId.Function, function() {
                                TS_CRAFTING_MENU.close();
                            })
                    }
                    break;
                case Menu.Calendar:
                    #macro TS_CALENDAR_MENU global.__ts_calendar_menu
                    chain
                        .append(LinkId.Function, function() {
                            TS_CALENDAR_MENU = spawn_calendar_ui(CALENDAR.time)
                                .with_today(CALENDAR.time)
                                .build();
                        })
                        .append(LinkId.Timer, 5)
                        .append(LinkId.Function, function() {
                            TS_CALENDAR_MENU.close();
                            TS_CALENDAR_MENU = undefined;
                        })
                        .append(LinkId.Await, function() {
                            return ANCHOR.get_menu(Menu.Calendar) == undefined;
                        })
                    break;
                case Menu.Gossip:
                    //
                    //
                    chain.append(LinkId.Function, function() {
                        for (var i = 0; i < NpcId.LEN; i++) {
                            NPCS[i].known_gift_preferences.clear();
                        }
                    })

                    //
                    repeat 50 {
                        chain.append(LinkId.Function, function() {
                            CALENDAR.time += seasons(1);
                            var gossip = get_gossip_selections();
                            var menu = ANCHOR.spawn_menu(Menu.Gossip);
                            menu.display_selections(gossip);
                            menu.cards.for_each(function(card) {
                                while run_chain(card.intro_chain) == false {}
                            });
                        })
                        chain.append(LinkId.Timer, 5);
                        chain.append(LinkId.Function, function() {
                            var menu = ANCHOR.get_menu(Menu.Gossip);
                            var node = menu.pilot.map[0][0];
                            ANCHOR.tap_node(node);
                            while run_chain(menu.chain) == false {}
                            while run_chain(menu.chain) == false {}
                        })
                        chain.append(LinkId.Timer, 5);
                        chain.append(LinkId.Function, function() {
                            ANCHOR.get_menu(Menu.Gossip).close();
                        })
                        chain.append(LinkId.Await, function() {
                            return ANCHOR.get_menu(Menu.Gossip) == undefined;
                        });
                    }
                    chain.append(LinkId.Function, function() {
                        var current_season = CALENDAR.season();

                        //
                        CALENDAR.time += (current_season - Season.Spring) * seasons(1);
                    })

                    break;
                //
                default:
                    chain.append(LinkId.Function, function(menus, menu_iter) {
                        if ANCHOR.get_menu(menu_iter) == undefined {
                            var menu = ANCHOR.spawn_menu(menu_iter);
                            menus.push(menu);
                        }
                    }, [menus, menu_iter])
                    break;
            }
            chain.append(LinkId.Timer, 5); //
            chain.append(LinkId.Function, function(menus) {
                for (var i = 0; i < menus.count(); i++) {
                    menus.get(i).close();
                }
            }, [menus])
            chain.append(LinkId.Await, function(menus) {
                for (var i = 0; i < menus.count(); i++) {
                    if ANCHOR.open_menus.has(menus.get(i)) {
                        return false;
                    }
                }

                return true;
            }, [menus]);
        }

        //
        chain.append(LinkId.Timer, 60);

        //
        chain.append(LinkId.Function, function() {
            var all_clean = ANCHOR.detect_lost_nodes().is_empty();
            if !all_clean {
                BUGGER.execute_command("anchor detect_lost_nodes"); //
                trace(
                    "Open menus: {}",
                    ANCHOR.open_menus
                        .map_to(function(e) {
                            return menu_to_string(e.type);
                        })
                        .join(", "),
                );
                crash("Menu tests passed, but lost nodes were detected!");
            }
        });

        chain.append(LinkId.Function, function() {
            if !SPILLOVER_LOGS.is_empty() {
                var spillies = SPILLOVER_LOGS.map_to(function(log) {
                    return format("'{}' @ {} (max size {}, they are {})", log.node, log.menu ?? "unknown_menu", log.max_size, log.my_size);
                });

                if spillies.is_empty() == false {
                    trace("### SPILLOVERS ###\n\n{}", spillies.join("\n"));

                    if local_language() == "eng" {
                        crash("Spillovers were detected during test! See above for details.");
                    }
                }
            }
        });
    }
});

TS_TESTS.push({
    name: "museum_donations",
    run_once: true,
    call: function(chain) {
        chain
            .append(LinkId.Function, function() {
                MUSEUM_PROGRESS = array_bool(ItemId.LEN);
                var results = List();
                for (var i = 0; i < ItemId.LEN; i++) {
                    if MUSEUM_DATA.museum_items[i] {
                        var result = donate_item_to_museum(i);
                        results.push(result);
                    }
                }
                handle_donation_ui_for_results(results, false);
            })
    }
});

TS_TESTS.push({
    name: "renown_rewards",
    run_once: true,
    call: function(chain) {
        chain.append(LinkId.Function, function() {
            RENOWN.rewards.for_each(function(reward) {
                consume_reward(reward).for_each(ARI.give_item);
            });
        })
    }
});


TS_TESTS.push({
    name: "roommate_jumps",
    run_once: true,
    call: function(chain) {
        //
        __ts_travel_to(LocationId.PlayerHomeWest, chain);

        static TEST_JUMP = function(time_range, expected_flags, expected_at_farm) {
            static ALL_FLAGS = [
                "rjt_a_d",
                "rjt_b_a",
                "rjt_b_d",
                "rjt_c_a",
                "rjt_c_d",
                "rjt_d_a",
                "rjt_d_d",
                "rjt_e_a",
                "rjt_e_d",
                "rjt_f_a",
            ];

            TS_CHAIN.append(LinkId.Function, function(time_range, ALL_FLAGS) {
                trace("Testing time range {time}-{time}", time_range[0], time_range[1]);
                T2R.write("rjt_active", true);

                new_day_non_grid();

                //
                T2R.schedule_deserialize_expirator("{}");
                CALENDAR.time = 0;
                T2R.update();
                T2R.update_daily();
                npcs_on_new_day(true);

                //
                for (var i = 0; i < array_length(ALL_FLAGS); i++) {
                    T2R.write(ALL_FLAGS[i], false);
                }

                if time_range[0] != hours(6) {
                    CLOCK.jump(time_range[0]);
                }
            }, [time_range, ALL_FLAGS]);

            TS_CHAIN.append(LinkId.Timer, 1);
            TS_CHAIN.append(LinkId.Function, function(time_range) {
                CLOCK.jump(time_range[1]);
            }, [time_range]);
            TS_CHAIN.append(LinkId.Timer, 1);
            TS_CHAIN.append(LinkId.Function, function(time_range, expected_flags, ALL_FLAGS, expected_at_farm) {

                for (var i = 0; i < array_length(ALL_FLAGS); i++) {
                    var expected = array_contains(expected_flags, ALL_FLAGS[i]);
                    assert_eq(
                        T2R.read(ALL_FLAGS[i]),
                        expected,
                        "{} in time range {time}-{time} was not {bool}!\nAll flags:\n{}",
                        ALL_FLAGS[i],
                        time_range[0],
                        time_range[1],
                        expected,
                        ListFromArray(ALL_FLAGS)
                            .map_to(function(f) {
                                return format("{}: {bool}", f, T2R.read(f));
                            })
                            .join("\n"),
                    );
                }

                assert_eq(
                    NPCS[NpcId.Juniper].at_farm(),
                    expected_at_farm,
                    "juniper at_farm in time range {time}-{time} was not {bool}!",
                    time_range[0],
                    time_range[1],
                    expected_at_farm,
                );

                T2R.write("rjt_active", false);
                T2R.write("rjt_start_write", false);
                T2R.write("rjt_end_write", false);
            }, [time_range, expected_flags, ALL_FLAGS, expected_at_farm]);
        }

        //
        TEST_JUMP([hours(6), hours(7)], [], true)
        TEST_JUMP([hours(6), hours(9)], [], true)
        TEST_JUMP([hours(6), hours(11)], ["rjt_a_d", "rjt_b_a", "rjt_b_d", "rjt_c_a"], false)
        TEST_JUMP([hours(6), hours(13) + minutes(30)], ["rjt_a_d", "rjt_b_a", "rjt_b_d", "rjt_c_a"], false);
        TEST_JUMP([hours(6), hours(15)], ["rjt_a_d", "rjt_b_a", "rjt_b_d", "rjt_c_a", "rjt_c_d", "rjt_d_a"], false);
        TEST_JUMP([hours(6), hours(20)], ["rjt_a_d", "rjt_b_a", "rjt_b_d", "rjt_c_a", "rjt_c_d", "rjt_d_a", "rjt_d_d", "rjt_e_a", "rjt_e_d", "rjt_f_a"], true);

        //
        //
        TEST_JUMP(
            [hours(13) + minutes(30), hours(20)],
            ["rjt_a_d", "rjt_b_a", "rjt_b_d", "rjt_c_a", "rjt_c_d", "rjt_d_a", "rjt_d_d", "rjt_e_a", "rjt_e_d", "rjt_f_a"],
            true,
        );

        //
        //
        TEST_JUMP(
            [hours(13) + minutes(30), hours(24)],
            ["rjt_a_d", "rjt_b_a", "rjt_b_d", "rjt_c_a", "rjt_c_d", "rjt_d_a", "rjt_d_d", "rjt_e_a", "rjt_e_d", "rjt_f_a"],
            true,
        );

        TS_CHAIN.append(LinkId.Function, function() {
            T2R.schedule_deserialize_expirator("{}");
            CALENDAR.time = hours(6);
            CLOCK.time = hours(6);
            T2R.update();
            T2R.update_daily();
            npcs_on_new_day(true);
        });
    }
});

TS_TESTS.push({
    name: "sleep_and_save",
    call: function(chain) {
        //
        __ts_travel_to(LocationId.PlayerHome, chain);

        //
        chain.append(LinkId.Function, function() {
            CLOCK.jump(hours(24));
            GRIDS[LocationId.Aldaria].lost_items.push({
                x: 222,
                y: 111,
                items: ListFromArray([new LiveItem(ItemId.MobCoin)]),
            });
            ARI.name = "Ari Unit Test";
        });

        //
        chain
            .append(LinkId.Function, function() {
                CLOCK.jump(hours(26));
            })
            .append(LinkId.Await, function() {
                var menu = ANCHOR.get_menu(Menu.Eod);
                if menu != undefined {
                    menu.end_sequence();
                    return true;
                }
                return false;
            })
            .append(LinkId.Await, function() {
                return !LOAD_SEQUENCE.is_active() && !game_paused() && SCREEN_FADER.is_in();
            })
    },
    save_upgrade: true,
    save_upgrade_light: true,
});

TS_TESTS.push({
    name: "exit",
    call: function(chain) {
        //
        chain.append(LinkId.Function, function(chain) {
            CHAIN_LIST_HOLDER = [chain];
            Game.exit_to_menu();
        }, [chain]);

        //
        chain.append(LinkId.Await, function() {
            return ANCHOR.get_menu(Menu.Title) != undefined;
        })
    }
});

TS_TESTS.push({
    name: "load",
    call: function(chain) {
        //
        chain.append(LinkId.Function, function() {
            ANCHOR.get_menu(Menu.Title).close();
            var last_played_save_path = Setup.save_manager.get_saves_ordered()[0];
            Setup.enter_game(LoadState.Load(Setup.save_manager.manifest.get(last_played_save_path)));
        });

        //
        chain.append(LinkId.Await, function() {
            return instance_exists(Game);
        });

        chain.append(LinkId.Function, function() {
            var lost_items = GRIDS[LocationId.Aldaria].lost_items;
            var found = false;
            for(var i = 0, ic = lost_items.count(); i < ic; i++) {
                if lost_items.get(i).items.get(0).item_id == ItemId.MobCoin {
                    found = true;
                    break;
                }
            }
            assert(found, "Item serialization failed to save shards properly: {}", lost_items);
        })
    }
});

TS_TESTS.push({
    name: "items",
    run_once: true, //
    call: function(chain) {
        var locations = [LocationId.Farm, LocationId.PlayerHome];
        for (var i = 0; i < array_length(locations); i++) {
            __ts_travel_to(locations[i], chain);
            //
            chain.append(LinkId.Function, function() {
                //
                for (var i = 0; i < ARI.inventory.size(); i++) {
                    if ARI.inventory.slot(i).count != 0 {
                        ARI.inventory.slot(i).drain();
                    }
                }
            })
            for (var j = 0; j < ItemId.LEN; j++) {
                chain
                    .append(LinkId.Function, function(i) {
                        TEST_BREADCRUMB = item_id_to_string(i);
                        var item = new LiveItem(i);
                        switch i {
                            case ItemId.RecipeScroll:
                                item.inner_item = ItemId.BlackberryJam;
                                break;
                            case ItemId.CraftingScroll:
                                item.inner_item = ItemId.TileRoofFenceV1;
                                break;
                            case ItemId.Cosmetic:
                                item.cosmetic = "dress_maid";
                                break;
                            case ItemId.AnimalCosmetic:
                                item.animal_cosmetic = {
                                    animal: AnimalKind.Chicken,
                                    cosmetic: "flower_crown",
                                }
                                break;
                            case ItemId.PetCosmetic:
                                item.pet_cosmetic_set_name = "halo";
                                break;
                            default: break;
                        }
                        ARI.give_item(item, 1, false, false);
                    }, [j])
                    .append(LinkId.Timer, 1) //
                    .append(LinkId.Function, function() {
                        ARI.inventory.slot(0).drain();
                    })
            }
        }

        //
        chain.append(LinkId.Function, function() {
            TEST_BREADCRUMB = "throwing_item";
            obj_ari.fsm.blackboard.set("items_thrown", List(new LiveItem(ItemId.Acorn)));
            obj_ari.fsm.change_state(PlayerState.ThrowItem);
        }).append(LinkId.Await, function() {
            return !obj_ari.fsm.check_state_inclusive(PlayerState.ThrowItem);
        });


        for (var i = 0; i < Infusion.LEN; i++) {
            //
            chain.append(LinkId.Function, function(infusion) {
                var item = new LiveItem(ItemId.Apple);
                item.infusion = infusion;
                TEST_BREADCRUMB = format("{}", item);

                use_item_fast(item);
            }, [i]).append(LinkId.Await, function() {
                return !obj_ari.fsm.check_state_inclusive(PlayerState.Tool);
            })
        }

        //
        chain.append(LinkId.Function, function() {
            TEST_BREADCRUMB = "recipe_scroll";
            use_item_fast(new LiveItem(ItemId.RecipeScroll, ItemId.CrunchyChickpeas));
        })

        chain.append(LinkId.Timer, 5);

        chain.append(LinkId.Function, function() {
            var menu = ANCHOR.get_menu(Menu.Popup);
            if menu != undefined {
                menu.close();
            }
        })

    }
});

TS_TESTS.push({
    name: "gold_total",
    run_once: true,
    call: function(chain) {
        chain.append(LinkId.Function, function() {
            shipping_bins().get(0).inventory.add(ItemId.Oarfish, 100);
            sell_shipping_bin_items();
            assert(game_stats_get_income_total() >= 10000, "Expected game stats get income total to return at least 10000, but instead it returned {}", game_stats_get_income_total());
        })
    },
    save_upgrade: true,
    save_upgrade_light: true,
})

TS_TESTS.push({
    name: "barks",
    run_once: true,
    call: function(chain) {
        //
        chain
            .append(LinkId.Function, function() {
                BUGGER.execute_command("goto celine");
            })
            .append(LinkId.Timer, 1);
        for (var i = 0; i < BarkId.LEN; i++) {
            chain
                .append(LinkId.Function, function(i) {
                    obj_celine.bark_emitter.emit(i, choose(BarkType.Thought, BarkType.Speech), true);
                }, [i])
                .append(LinkId.Timer, 1)
        }
        chain.append(LinkId.Timer, 120);
    }
});

TS_TESTS.push({
    name: "general_cutscenes",
    exclude_from_standard: true,
    call: function(chain) {
        var keys = ListFromArray(CUTSCENES.keys())
            .retain(function(e) {
                return CUTSCENES.get(e).test_target == SceneTestTarget.General;
            });

        var scenes_to_test = keys.count();
        for (var i = 0; i < scenes_to_test; i++) {
            var key = keys.get(i);

            chain.
                append(LinkId.Function, function(key, index, total) {
                    trace("Running scene {}/{}: {}", index + 1, total, key);
                    MIST.run_scene(key);
                }, [key, i, scenes_to_test])
                .append(LinkId.Await, function() {
                    if MIST.runtime != undefined {
                        MIST.runtime.native_environment.define(
                            "__textbox_interacted",
                            new NativeCallable(MIST.runtime).set_call(__ts_mist_textbox_interacted),
                        )
                        return true;
                    }
                    return false;
                })
                .append(LinkId.Await, function() {
                    return !MIST.is_running();
                })
                .append(LinkId.Timer, 1)
        }
    }
});

TS_TESTS.push({
    name: "main_story",
    exclude_from_standard: true,
    call: function(chain) {
        SE = new StoryExecutor(chain);

        //

        SE.wait(5);

        //
        SE.play_out_scene("prologue");

        //
        SE.next(function() {
            var menu = ANCHOR.get_menu(Menu.Customization);
            assert_neq(menu, undefined, "Character customization not running!");
            ANCHOR.tap_node(find_node("customization_continue_button"));
        });
        SE.wait(10);

        //
        SE.play_out_scene("day_zero");
        SE.wait(10);

        //
        SE.goto_scene_trigger("farm_introduction");
        SE.play_out_scene("farm_introduction");

        //
        SE.goto_scene_trigger("adeline_quest_board");
        SE.next(function() {
            //
            QUEST_LOG.start("greet_the_townsfolk");
        });
        SE.play_out_scene("adeline_quest_board");

        //
        var quest = QUESTS.get("greet_the_townsfolk");
        var req = quest.tasks.first().requirements[Requirement.MetNpc];
        for (var i = 0; i < array_length(req); i++) {
            SE.talk_to(req[i]);
        }
        SE.turn_in_quest(NpcId.Adeline, "greet_the_townsfolk");

        //
        SE.end_day(); //

        //
        SE.goto_scene_trigger("the_unusual_tree_pt_1");
        SE.play_out_scene("the_unusual_tree_pt_1");

        //
        SE.accept_from_request_board("do_a_bro_a_favor");
        SE.turn_in_quest(NpcId.Olric, "do_a_bro_a_favor");
        SE.play_out_scene("do_a_bro_a_favor");
        SE.assert_quest_complete("do_a_bro_a_favor");

        //
        SE.open_letter("museum_donation_wanted");
        SE.goto_scene_trigger("museum_donation_wanted");
        SE.play_out_scene("museum_donation_wanted");
        SE.assert_quest_complete("museum_donation_wanted");

        //
        SE.end_day("the_unusual_tree_pt_2"); //

        SE.end_day(); //

        //
        SE.accept_from_request_board("somethings_bugging_me");
        SE.goto_scene_trigger("somethings_bugging_me");
        SE.play_out_scene("somethings_bugging_me");
        SE.assert_quest_complete("somethings_bugging_me");

        SE.end_day(); //

        //
        SE.accept_from_request_board("stinky_stamina_potion");
        SE.fulfill_quest("stinky_stamina_potion");
        SE.turn_in_quest(NpcId.Juniper, "stinky_stamina_potion");
        SE.play_out_scene("stinky_stamina_potion");
        SE.assert_quest_complete("stinky_stamina_potion");

        //
        SE.open_letter("friday_at_the_sleeping_dragon_inn");
        SE.clock_jump("8:00pm");
        SE.turn_in_quest(NpcId.Reina, "friday_at_the_sleeping_dragon_inn");

        SE.end_day(); //
        SE.end_day(); //
        SE.end_day("pet_dream"); //

        SE.goto_scene_trigger("pet_arrival");
        SE.play_out_scene("pet_arrival");

        //
        SE.open_letter("repair_the_bridge");
        SE.assert_quest_active("repair_the_bridge");
        SE.goto_scene_trigger("repair_the_bridge_pt_1");
        SE.play_out_scene("repair_the_bridge_pt_1");
        SE.fulfill_quest("repair_the_bridge");
        SE.turn_in_quest(NpcId.Adeline, "repair_the_bridge");
        SE.play_out_scene("repair_the_bridge_pt_2");
        SE.assert_world_mod_enabled(WorldMod.Bridge);

        SE.end_day(); //
        SE.end_day(); //

        //
        SE.open_letter("crafting_tutorial");
        SE.fulfill_quest("crafting_tutorial");
        SE.turn_in_quest(NpcId.Ryis, "crafting_tutorial");
        SE.play_out_scene("crafting_tutorial");
        SE.assert_quest_complete("crafting_tutorial");

        //
        SE.open_letter("replenishing_mistrias_food_reserves_1");
        SE.assert_quest_active("replenishing_mistrias_food_reserves_1");
        SE.goto_scene_trigger("replenishing_mistrias_food_reserves_1");
        SE.play_out_scene("replenishing_mistrias_food_reserves_1");
        SE.fulfill_quest("replenishing_mistrias_food_reserves_1");
        SE.end_day(); //
        SE.turn_in_quest(NpcId.Adeline, "replenishing_mistrias_food_reserves_1");

        SE.end_day(); //
        SE.end_day(); //

        //
        SE.accept_from_request_board("jos_cooking_class");
        SE.goto_scene_trigger("jos_cooking_class");
        SE.play_out_scene("jos_cooking_class");
        SE.assert_quest_complete("jos_cooking_class");

        //
        SE.open_letter("greet_the_vendors");
        SE.assert_quest_active("greet_the_vendors");
        SE.talk_to(NpcId.Darcy);
        SE.talk_to(NpcId.Merri);
        SE.talk_to(NpcId.Vera);
        SE.talk_to(NpcId.Louis);
        SE.turn_in_quest(NpcId.Nora, "greet_the_vendors");

        SE.end_day(); //

        //
        SE.goto_scene_trigger("spring_festival_setup");
        SE.play_out_scene("spring_festival_setup");
        SE.assert_quest_active("the_spring_festival");

        //
        SE.open_letter("repair_the_mill");
        SE.assert_quest_active("repair_the_mill");
        SE.goto_scene_trigger("repair_the_mill_pt_1");
        SE.play_out_scene("repair_the_mill_pt_1");
        SE.fulfill_quest("repair_the_mill");
        SE.turn_in_quest(NpcId.Adeline, "repair_the_mill");
        SE.play_out_scene("repair_the_mill_pt_2");
        SE.assert_world_mod_enabled(WorldMod.Mill);

        SE.end_day(); //

        //
        SE.open_letter("tea_with_hayden");
        SE.assert_quest_active("tea_with_hayden");
        SE.goto_scene_trigger("tea_with_hayden");
        SE.play_out_scene("tea_with_hayden");
        SE.assert_quest_complete("tea_with_hayden");

        SE.end_day(); //
        SE.end_day(); //

        //
        SE.goto_scene_trigger("spring_festival_morning");
        SE.play_out_scene("spring_festival_morning");
        SE.goto_scene_trigger("spring_festival_no_place");
        SE.play_out_scene("spring_festival_no_place");

        //
        SE.open_letter("repair_the_summit_stairs");
        SE.assert_quest_active("repair_the_summit_stairs");
        SE.goto_scene_trigger("repair_the_summit_stairs");
        SE.play_out_scene("repair_the_summit_stairs");
        SE.assert_world_mod_enabled(WorldMod.NarrowsStairs);

        //
        SE.end_day(); //
        SE.end_day(); //
        SE.end_day(); //
        SE.open_letter("repair_the_general_store");
        SE.assert_quest_active("repair_the_general_store");
        SE.goto_scene_trigger("repair_the_general_store_pt_1");
        SE.play_out_scene("repair_the_general_store_pt_1");
        SE.fulfill_quest("repair_the_general_store");
        SE.turn_in_quest(NpcId.Adeline, "repair_the_general_store");
        SE.play_out_scene("repair_the_general_store_pt_2");
        SE.assert_world_mod_enabled(WorldMod.GeneralStoreInterior);
        SE.assert_world_mod_enabled(WorldMod.GeneralStoreExterior);

        //
        SE.end_day(); //
        SE.end_day(); //
        SE.end_day(); //
        SE.open_letter("repair_the_beach_bridge");
        SE.assert_quest_active("repair_the_beach_bridge");
        SE.goto_scene_trigger("repair_the_beach_bridge_pt_1");
        SE.play_out_scene("repair_the_beach_bridge_pt_1");
        SE.fulfill_quest("repair_the_beach_bridge");
        SE.turn_in_quest(NpcId.Terithia, "repair_the_beach_bridge");
        SE.play_out_scene("repair_the_beach_bridge_pt_2");
        SE.assert_world_mod_enabled(WorldMod.BeachBridge);

        //
        SE.end_day(); //
        SE.end_day(); //
        SE.open_letter("replenishing_mistrias_food_reserves_2");
        SE.assert_quest_active("replenishing_mistrias_food_reserves_2");
        SE.goto_scene_trigger("replenishing_mistrias_food_reserves_2_pt_1");
        SE.play_out_scene("replenishing_mistrias_food_reserves_2_pt_1");
        SE.fulfill_quest("replenishing_mistrias_food_reserves_2");
        SE.turn_in_quest(NpcId.Adeline, "replenishing_mistrias_food_reserves_2");
        SE.play_out_scene("replenishing_mistrias_food_reserves_2_pt_2");

        //
        SE.end_day(); //
        SE.end_day(); //
        SE.open_letter("repair_haydens_barn");
        SE.assert_quest_active("repair_haydens_barn");
        SE.goto_scene_trigger("repair_haydens_barn_pt_1");
        SE.play_out_scene("repair_haydens_barn_pt_1");
        SE.fulfill_quest("repair_haydens_barn");
        SE.turn_in_quest(NpcId.Adeline, "repair_haydens_barn");
        SE.play_out_scene("repair_haydens_barn_pt_2");

        //
        SE.end_day("find_the_weathervane_setup"); //
        SE.goto_scene_trigger("find_the_weathervane");
        SE.play_out_scene("find_the_weathervane");
        SE.assert_world_mod_enabled(WorldMod.HorseStatue);
        SE.goto("narrows/reveal_mistmare_horse_spawn");
        SE.next(function() {
            ARI.inventory.slot(0).drain();
        });
        SE.interact_with(obj_weathervane_item, "misc_local/inspect");
        SE.await(function() {
            //
            if !instance_exists(obj_item) {
                return true;
            }
            obj_ari.x = obj_item.x;
            obj_ari.y = obj_item.y;
            return false;
        });
        SE.turn_in_quest(NpcId.Hayden, "find_the_weathervane");

        //
        SE.end_day(); //
        SE.end_day(); //
        SE.open_letter("repair_the_inn");
        SE.assert_quest_active("repair_the_inn");
        SE.goto_scene_trigger("repair_the_inn_pt_1");
        SE.play_out_scene("repair_the_inn_pt_1");
        SE.fulfill_quest("repair_the_inn");
        SE.turn_in_quest(NpcId.Adeline, "repair_the_inn");
        SE.play_out_scene("repair_the_inn_pt_2");
        SE.assert_world_mod_enabled(WorldMod.InnInterior);
        SE.assert_world_mod_enabled(WorldMod.InnExterior);

        SE.next(function() {
            ARI.set_renown(renown_level_total_cost(20));
        });
        SE.end_day(); //
        SE.end_day(); //
        SE.end_day(); //
        SE.open_letter("lost_and_found");
        SE.assert_quest_active("lost_and_found");
        SE.goto_scene_trigger("lost_and_found");
        SE.play_out_scene("lost_and_found");
        SE.assert_quest_complete("lost_and_found");

        SE.next(function() {
            ARI.set_renown(renown_level_total_cost(30));
        });
        SE.end_day(); //
        SE.open_letter("apiaries_and_terrariums");
        SE.assert_quest_active("apiaries_and_terrariums");
        SE.goto_scene_trigger("apiaries_and_terrariums");
        SE.play_out_scene("apiaries_and_terrariums");
        SE.fulfill_quest("apiaries_and_terrariums");
        SE.end_day(); //
        SE.turn_in_quest(NpcId.Adeline, "apiaries_and_terrariums");
        SE.assert_quest_complete("apiaries_and_terrariums");

        //
        SE.next(function() {
            ARI.set_renown(renown_level_total_cost(55));
            fulfill_requirement(Requirement.OpenedMines);
        });
        SE.end_day(); //
        SE.open_letter("stone_refinery");
        SE.assert_quest_active("stone_refinery");
        SE.goto_scene_trigger("stone_refinery_pt_1");
        SE.play_out_scene("stone_refinery_pt_1");
        SE.fulfill_quest("stone_refinery");
        SE.turn_in_quest(NpcId.Adeline, "stone_refinery");
        SE.play_out_scene("stone_refinery_pt_2");
        SE.assert_world_mod_enabled(WorldMod.StoneRefinery);

        //
        SE.accept_from_request_board("cop_some_ore");
        SE.fulfill_quest("cop_some_ore");
        SE.turn_in_quest(NpcId.March, "cop_some_ore");
        SE.play_out_scene("cop_some_ore");

        //
        SE.next(function() {
            ARI.set_renown(renown_level_total_cost(65));
        });
        SE.end_day(); //
        SE.open_letter("upgrade_the_saturday_market");
        SE.assert_quest_active("upgrade_the_saturday_market");
        SE.turn_in_quest(NpcId.Adeline, "upgrade_the_saturday_market");
        SE.play_out_scene("upgrade_the_saturday_market");
        SE.fulfill_quest("upgrade_the_saturday_market");
        SE.turn_in_quest(NpcId.Adeline, "upgrade_the_saturday_market");

        //
        SE.next(function() {
            ARI.set_renown(renown_level_total_cost(70));
        });
        SE.end_day(); //
        SE.open_letter("upgrade_the_carpenters_shop");
        SE.assert_quest_active("upgrade_the_carpenters_shop");
        SE.goto_scene_trigger("upgrade_the_carpenters_shop_pt_1");
        SE.play_out_scene("upgrade_the_carpenters_shop_pt_1");
        SE.fulfill_quest("upgrade_the_carpenters_shop");
        SE.turn_in_quest(NpcId.Adeline, "upgrade_the_carpenters_shop");
        SE.play_out_scene("upgrade_the_carpenters_shop_pt_2");
        SE.assert_world_mod_enabled(WorldMod.CarpentersShopInterior);
        SE.assert_world_mod_enabled(WorldMod.CarpentersShopExterior);

        //
        SE.next(function() {
            //
            ARI.birthday = 0;
        })
        SE.accept_from_request_board("gossip_for_elsie");
        SE.talk_to(NpcId.Balor);
        SE.talk_to(NpcId.Juniper);
        SE.next(function() {
            //
            T2R.write("Conversations/Tutorial Dialogue/furniture/furniture_pickaxe_dell", true);
        })
        SE.talk_to(NpcId.Dell);
        SE.turn_in_quest(NpcId.Elsie, "gossip_for_elsie");

        //
        SE.next(function() {
            ARI.set_renown(renown_level_total_cost(80));
        });
        SE.end_day(); //
        SE.open_letter("upgrade_the_saturday_market_plaza");
        SE.assert_quest_active("upgrade_the_saturday_market_plaza");
        SE.goto_scene_trigger("upgrade_the_saturday_market_plaza");
        SE.play_out_scene("upgrade_the_saturday_market_plaza");
        SE.fulfill_quest("upgrade_the_saturday_market_plaza");
        SE.turn_in_quest(NpcId.Adeline, "upgrade_the_saturday_market_plaza");

        //
        SE.end_day(); //
        SE.end_day(); //
        SE.open_letter("meet_the_new_vendors");
        SE.assert_quest_active("meet_the_new_vendors");
        SE.talk_to(NpcId.Zorel);
        SE.talk_to(NpcId.Stillwell);
        SE.turn_in_quest(NpcId.Nora, "meet_the_new_vendors");

        //
        SE.next(function() {
            ARI.set_renown(renown_level_total_cost(90));
        })
        SE.end_day(); //
        SE.open_letter("repair_the_bell_tower");
        SE.assert_quest_active("repair_the_bell_tower");
        SE.goto_scene_trigger("repair_the_bell_tower_pt_1");
        SE.play_out_scene("repair_the_bell_tower_pt_1");
        SE.assert_world_mod_enabled(WorldMod.BellTowerBellBroken);
        SE.fulfill_quest("repair_the_bell_tower");
        SE.turn_in_quest(NpcId.Adeline, "repair_the_bell_tower");
        SE.play_out_scene("repair_the_bell_tower_pt_2");
        SE.assert_world_mod_enabled(WorldMod.BellTowerDoor);
        SE.assert_world_mod_enabled(WorldMod.BellTower);

        //
        SE.next(function() {
            ARI.set_renown(renown_level_total_cost(100));
        });
        SE.end_day(); //
        SE.goto("farm");
        SE.goto("town");
        SE.goto_scene_trigger("mistril_rank");
        SE.play_out_scene("mistril_rank");

        SE.end_day(); //
        SE.open_letter("complete_the_museum_incomplete");
        SE.assert_quest_active("complete_the_museum");
        SE.next(function() {
            for (var i = 0; i < ItemId.LEN; i++) {
                if MUSEUM_DATA.museum_items[i] {
                    register_item_to_museum(i);
                }
            }

            T2R.write("completed_museum", requirements_pass(ACHIEVEMENTS[Achievement.CelebratedCurator]));
        });
        SE.turn_in_quest(NpcId.Errol, "complete_the_museum");

        //

        chain.append(LinkId.Function, function() {
            var missing_quests = List();
            var keys = QUESTS.keys();
            for (var i = 0; i < array_length(keys); i++) {
                if !QUEST_LOG.completed.contains(keys[i]) && QUESTS.get(keys[i]).test_target == QuestTestTarget.MainStory {
                    missing_quests.push(keys[i]);
                }
            }

            var missing_scenes = List();
            var keys = scenes_in_test_target(SceneTestTarget.MainStory);
            for (var i = 0; i < array_length(keys); i++) {
                if keys[i] == "mistril_rank" {
                    continue;
                }
                if !MIST.scene_history.contains(keys[i]) {
                    missing_scenes.push(keys[i]);
                }
            }

            if !missing_quests.is_empty() {
                crash("The following quests were not covered by the test:\n{}", missing_quests.join(", "));
            }

            if !missing_scenes.is_empty() {
                crash("The following scenes were not covered by the test:\n{}", missing_scenes.join(", "));
            }
        })
    },
});

TS_TESTS.push({
    name: "dragon_story",
    exclude_from_standard: true,
    call: function(chain) {
        SE = new StoryExecutor(chain);

        SE.wait(5);
        SE.play_out_scene("prologue");
        SE.next(function() {
            var menu = ANCHOR.get_menu(Menu.Customization);
            assert_neq(menu, undefined, "Character customization not running!");
            ANCHOR.tap_node(find_node("customization_continue_button"));
        });
        SE.wait(10);
        SE.play_out_scene("day_zero");
        SE.wait(10);
        SE.next(function() {
            //
            MIST.scene_history.insert("farm_introduction");
            MIST.scene_history.insert("adeline_quest_board");
            MIST.scene_history.insert("the_unusual_tree_pt_1");
            MIST.scene_history.insert("the_unusual_tree_pt_2");
            MIST.scene_history.insert("pet_dream");
            MIST.scene_history.insert("pet_arrival");
        })

        SE.end_day(); //
        SE.end_day(); //
        SE.end_day(); //
        SE.end_day(); //
        SE.end_day(); //
        SE.open_letter("unlocking_the_mines_pt_1");
        SE.assert_quest_active("unlocking_the_mines_pt_1");
        SE.goto_scene_trigger("unlocking_the_mines_pt_1");
        SE.play_out_scene("unlocking_the_mines_pt_1");

        SE.next(function() {
            ARI.set_renown(renown_level_total_cost(10));
        });
        SE.end_day(); //
        SE.open_letter("unlocking_the_mines_pt_2");
        SE.assert_quest_active("unlocking_the_mines_pt_2");
        SE.goto_scene_trigger("unlocking_the_mines_pt_2");
        SE.play_out_scene("unlocking_the_mines_pt_2");

        //
        SE.traverse_dungeon(10);
        SE.end_day("full_restore"); //

        //
        SE.traverse_dungeon(20);
        SE.play_out_scene("water_seal");
        SE.assert_quest_active("the_water_tablet");
        SE.turn_in_quest(NpcId.Eiland, "the_water_tablet");
        SE.play_out_scene("translating_the_water_tablet");
        SE.traverse_dungeon(20);
        SE.fulfill_quest("the_water_tablet");
        SE.interact_with(obj_seal_tablet, "misc_local/interact");
        SE.next(function() {
            var menu = ANCHOR.get_menu(Menu.Storage);
            ANCHOR.tap_node(menu.button);
        });
        SE.play_out_scene("break_water_seal");
        SE.assert_quest_complete("the_water_tablet");
        SE.end_day(); //
        SE.goto_scene_trigger("post_water_seal");
        SE.play_out_scene("post_water_seal");

        //
        SE.traverse_dungeon(40);
        SE.play_out_scene("earth_seal");
        SE.assert_quest_active("the_earth_tablet");
        SE.turn_in_quest(NpcId.Juniper, "the_earth_tablet");
        SE.play_out_scene("translating_the_earth_tablet");
        SE.traverse_dungeon(40);
        SE.fulfill_quest("the_earth_tablet");
        SE.interact_with(obj_seal_tablet, "misc_local/interact");
        SE.next(function() {
            var menu = ANCHOR.get_menu(Menu.Storage);
            ANCHOR.tap_node(menu.button);
        });
        SE.play_out_scene("break_earth_seal");
        SE.assert_quest_complete("the_earth_tablet");
        SE.end_day(); //
        SE.goto_scene_trigger("post_earth_seal");
        SE.play_out_scene("post_earth_seal");

        //
        SE.traverse_dungeon(60);
        SE.play_out_scene("fire_seal");
        SE.turn_in_quest(NpcId.Juniper, "the_fire_tablet");
        SE.play_out_scene("translating_the_fire_tablet");
        SE.assert_quest_complete("the_fire_tablet");
        SE.end_day(); //
        SE.end_day(); //
        SE.open_letter("procuring_the_sealing_scroll");
        SE.assert_quest_active("procuring_the_sealing_scroll");
        SE.goto_scene_trigger("procuring_the_sealing_scroll");
        SE.play_out_scene("procuring_the_sealing_scroll");
        SE.fulfill_quest("procuring_the_sealing_scroll");
        SE.turn_in_quest(NpcId.Balor, "procuring_the_sealing_scroll");
        SE.assert_quest_complete("procuring_the_sealing_scroll");
        SE.end_day(); //
        SE.goto_scene_trigger("delivering_the_sealing_scroll");
        SE.play_out_scene("delivering_the_sealing_scroll");
        SE.assert_quest_complete("delivering_the_sealing_scroll");
        SE.assert_quest_active("breaking_the_fire_seal");
        SE.traverse_dungeon(60);
        SE.fulfill_quest("breaking_the_fire_seal");
        SE.interact_with(obj_seal_tablet, "misc_local/interact");
        SE.next(function() {
            var menu = ANCHOR.get_menu(Menu.Storage);
            ANCHOR.tap_node(menu.button);
        });
        SE.play_out_scene("break_fire_seal");
        SE.assert_quest_complete("breaking_the_fire_seal");
        SE.next(function() {
            ARI.set_stamina(ARI.get_max_stamina());
            ARI.set_health(ARI.get_max_health());
        });
        SE.goto_scene_trigger("caldarus_recovery");
        SE.play_out_scene("caldarus_recovery");

        //
        SE.traverse_dungeon(80);
        SE.play_out_scene("break_ruins_seal_pt_1");
        SE.assert_quest_active("creating_the_void_mass");
        SE.fulfill_quest("creating_the_void_mass");
        SE.interact_with(obj_seal_tablet, "misc_local/interact");
        SE.next(function() {
            var menu = ANCHOR.get_menu(Menu.Storage);
            ANCHOR.tap_node(menu.button);
        });
        SE.play_out_scene("break_ruins_seal_pt_2");
        SE.assert_quest_complete("creating_the_void_mass");
        SE.assert_quest_active("breaking_the_ruins_seal");
        SE.fulfill_quest("breaking_the_ruins_seal");
        SE.wait(30);
        SE.interact_with(obj_void_ari, "misc_local/interact");
        SE.next(function() {
            var menu = ANCHOR.get_menu(Menu.Storage);
            ANCHOR.tap_node(menu.button);
        });
        SE.play_out_scene("break_ruins_seal_pt_3");
        SE.assert_quest_complete("breaking_the_ruins_seal");

        //
        SE.traverse_dungeon(10);
        SE.play_out_scene("priestess_quarters_pt_1");
        SE.assert_quest_active("find_the_magic_key");
        SE.interact_with(obj_pq_nw_shelf, "misc_local/inspect");
        SE.play_out_textbox();
        SE.next(function() {
            var pos = trellis_point("priestess_quarters/ari_blacksmithing");
            obj_ari.x = pos.x;
            obj_ari.y = pos.y;
            obj_ari.face_dir(Cardinal.East * 90);
            cast_spell(Spell.FireBreath);
        });
        SE.wait(30);
        SE.play_out_scene("unlock_pq_ne");
        SE.next(function() {
            obj_ari.x = 775;
            obj_ari.y = 145;
        });
        SE.interact_with(obj_seal_tablet, "misc_local/inspect");
        SE.play_out_textbox();
        SE.wait(60);
        SE.fulfill_quest("find_the_magic_key");
        SE.interact_with(obj_seal_tablet, "misc_local/interact");
        SE.next(function() {
            ARI.inventory.slot(0).drain();
            var menu = ANCHOR.get_menu(Menu.Storage);
            ANCHOR.tap_node(menu.button);
        });
        SE.wait(120);
        SE.next(function() {
            var pos = Vec2(96, 94);
            obj_ari.x = (pos.x - 1) * 8;
            obj_ari.y = pos.y * 8;
            use_item(ItemId.HoeCopper, pos);
        });
        SE.wait(60);
        SE.next(function() {
            assert_eq(ARI.inventory.item_id_quantity(ItemId.SeedMagicKey), 1);
            plant_seed(GRID, 96, 94, ObjectId.MagicKey);
        });
        SE.wait(60);
        SE.next(function() {
            cast_spell(Spell.Growth);
        });
        SE.wait(60);
        SE.interact_with(obj_node_renderer, "misc_local/harvest");
        SE.wait(60);
        SE.next(function() {
            ARI.inventory.slot(0).drain();
            obj_ari.x += 8;
        });
        SE.wait(60);
        SE.interact_with(obj_pq_door, "misc_local/unlock_door");
        SE.play_out_scene("priestess_quarters_pt_2");
        SE.assert_quest_complete("find_the_magic_key");

        //
        SE.traverse_dungeon(10);
        SE.play_out_scene("dragon_tablet_pt_1");
        SE.assert_quest_active("the_dragonsworn_tablet");
        SE.interact_with(obj_seal_tablet, "misc_local/inspect");
        SE.play_out_scene("dragon_tablet_pt_2");
        SE.next(function() {
            NPCS[NpcId.Juniper].set_heart_level(8);
            NPCS[NpcId.Eiland].set_heart_level(8);
            MIST.scene_history.insert("juniper_eight_hearts");
            MIST.scene_history.insert("eiland_eight_hearts");
        });
        SE.goto("juniper");
        SE.turn_in_quest(NpcId.Juniper, "the_dragonsworn_tablet");
        SE.play_out_scene("dragon_tablet_pt_3");
        SE.goto("seridias_chamber");
        SE.interact_with(obj_seal_tablet, "misc_local/inspect");
        SE.play_out_textbox();
        SE.assert_quest_complete("the_dragonsworn_tablet");
        SE.wait(20);
        SE.next(function() {
            ANCHOR.tap_node(ANCHOR.get_menu(Menu.Popup).buttons.get(0));
        });
        SE.wait(20);
        SE.next(function() {
            ANCHOR.tap_node(ANCHOR.get_menu(Menu.Popup).buttons.get(0));
        });
        SE.wait(20);
        SE.next(function() {
            ANCHOR.tap_node(ANCHOR.get_menu(Menu.Popup).buttons.get(0));
        });
        SE.wait(20);
        SE.next(function() {
            ANCHOR.tap_node(ANCHOR.get_menu(Menu.Popup).buttons.get(0));
        });
        SE.wait(20);
        SE.assert_quest_active("breaking_the_final_seal");
        SE.fulfill_quest("breaking_the_final_seal");
        SE.interact_with(obj_seal_tablet, "misc_local/interact");
        SE.next(function() {
            var menu = ANCHOR.get_menu(Menu.Storage);
            ANCHOR.tap_node(menu.button);
        });
        SE.next(function() {
            ANCHOR.tap_node(ANCHOR.get_menu(Menu.Popup).buttons.get(1));
        });
        SE.wait(20);
        SE.play_out_scene("dragon_tablet_pt_4");
        SE.assert_quest_complete("breaking_the_final_seal");
        SE.play_out_eod();

        chain.append(LinkId.Function, function() {
            var missing_quests = List();
            var keys = QUESTS.keys();
            for (var i = 0; i < array_length(keys); i++) {
                if !QUEST_LOG.completed.contains(keys[i]) && QUESTS.get(keys[i]).test_target == QuestTestTarget.DragonStory {
                    missing_quests.push(keys[i]);
                }
            }

            var missing_scenes = List();
            var keys = scenes_in_test_target(SceneTestTarget.DragonStory);
            for (var i = 0; i < array_length(keys); i++) {
                if !MIST.scene_history.contains(keys[i]) {
                    missing_scenes.push(keys[i]);
                }
            }

            if !missing_quests.is_empty() {
                crash("The following quests were not covered by the test:\n{}", missing_quests.join(", "));
            }

            if !missing_scenes.is_empty() {
                crash("The following scenes were not covered by the test:\n{}", missing_scenes.join(", "));
            }
        })
    },
});

TS_TESTS.push({
    name: "festivals",
    exclude_from_standard: true,
    call: function(chain) {
        SE = new StoryExecutor(chain);

        //

        SE.wait(5);

        //
        SE.play_out_scene("prologue");

        //
        SE.next(function() {
            var menu = ANCHOR.get_menu(Menu.Customization);
            assert_neq(menu, undefined, "Character customization not running!");
            ANCHOR.tap_node(find_node("customization_continue_button"));
        });
        SE.wait(10);

        //
        SE.play_out_scene("day_zero");
        SE.wait(10);

        SE.next(function() {
            MIST.scene_history.insert("farm_introduction");
            MIST.scene_history.insert("adeline_quest_board");
            MIST.scene_history.insert("the_unusual_tree_pt_1");
            MIST.scene_history.insert("the_unusual_tree_pt_2");
            MIST.scene_history.insert("pet_dream");
            MIST.scene_history.insert("pet_arrival");
        })

        //
        SE.skip_to_date("fall 7");
        SE.goto_scene_trigger("harvest_festival_setup");
        SE.play_out_scene("harvest_festival_setup");
        SE.skip_to_date("fall 10");
        SE.goto_scene_trigger("harvest_festival_morning");
        SE.play_out_scene("harvest_festival_morning");
        SE.goto_scene_trigger("harvest_festival_no_place");
        SE.play_out_scene("harvest_festival_no_place");
        SE.execute("npc set_heart_level juniper 0");
        SE.goto("juniper");
        SE.interact_with(obj_juniper, "misc_local/interact_dance");
        SE.play_out_textbox();
        SE.execute("npc set_heart_level celine 4");
        SE.goto("celine");
        SE.interact_with(obj_celine, "misc_local/interact_dance");
        SE.play_out_textbox();
        SE.play_out_scene("harvest_festival_dance");

        //
        SE.skip_to_date("winter 7");
        SE.goto_scene_trigger("animal_festival_upcoming_ineligible_year_one");
        SE.play_out_scene("animal_festival_upcoming_ineligible_year_one");
        SE.end_day(); //
        SE.end_day(); //
        SE.end_day(); //
        SE.assert_quest_active("the_animal_festival");
        SE.talk_to(NpcId.Josephine);
        SE.turn_in_quest(NpcId.Josephine, "the_animal_festival");
        SE.play_out_scene("the_animal_festival");

        //
        SE.skip_to_date("spring 14");
        SE.goto_scene_trigger("spring_festival_setup_year_2");
        SE.play_out_scene("spring_festival_setup_year_2");
        SE.assert_quest_active("the_spring_festival");

        //

        chain.append(LinkId.Function, function() {
            var missing_quests = List();
            var keys = QUESTS.keys();
            for (var i = 0; i < array_length(keys); i++) {
                if !QUEST_LOG.completed.contains(keys[i]) && QUESTS.get(keys[i]).test_target == QuestTestTarget.Festivals {
                    missing_quests.push(keys[i]);
                }
            }

            if !missing_quests.is_empty() {
                crash("The following quests were not covered by the test:\n{}", missing_quests.join(", "));
            }
        })
    },
});

TS_TESTS.push({
    name: "shooting_star",
    exclude_from_standard: true,
    call: function(chain) {
        SE = new StoryExecutor(chain);

        //
        SE.skip_to_date("summer 28");
        SE.goto_scene_trigger("shooting_star_blocked");
        SE.play_out_scene("shooting_star_blocked");

        SE.next(function() {
            fulfill_requirement(Requirement.UnlockedSummit);
            fulfill_requirement(Requirement.BrokeFireSeal);
            fulfill_requirement(Requirement.ClosedFinalSeal);

            T2R.write("caldarus_home", true);
            T2R.write("caldarus_is_human", true);
            T2R.write("seridia_is_human", true);
            T2R.write("caldarus_seridia_town", true);

            MIST.scene_history.insert("caldarus_recovery");
        })

        //
        SE.skip_to_date("summer 28");
        SE.goto_scene_trigger("shooting_star_morning");
        SE.play_out_scene("shooting_star_morning");
        SE.clock_jump("8:00pm");
        SE.goto("summit");
        SE.play_out_scene("shooting_star_solo");
        SE.play_out_eod();

        //
        for (var npc = 0; npc < NpcId.LEN; npc++) {
            if NPC_PROTOTYPES[npc].dateable {
                var control = npc == NpcId.Juniper ? NpcId.Adeline : NpcId.Juniper;
                SE.skip_to_date("summer 28");
                SE.next(function(npc) {
                    NPCS[npc].set_heart_level(npc == NpcId.Seridia ? 6 : 4);
                }, [npc]);
                SE.next(function(control) {
                    NPCS[control].set_heart_level(0);
                }, [control])
                SE.goto_scene_trigger("shooting_star_morning");
                SE.play_out_scene("shooting_star_morning");
                SE.goto(npc_id_to_string(control));
                SE.interact_with(npc_id_to_gm_obj_id(control), "misc_local/interact_invite");
                SE.play_out_textbox();
                SE.goto(npc_id_to_string(npc));
                SE.interact_with(npc_id_to_gm_obj_id(npc), "misc_local/interact_invite");
                SE.play_out_textbox();
                SE.clock_jump("8:00pm");
                SE.goto(npc_id_to_string(npc));
                SE.interact_with(npc_id_to_gm_obj_id(npc), "misc_local/go_to_festival");
                SE.next(function() {
                    ANCHOR.tap_node(ANCHOR.get_menu(Menu.Popup).buttons.get(1));
                });
                SE.play_out_scene(format("shooting_star_{NpcId}", npc));
                SE.play_out_eod();
            }
        }

        //
        SE.skip_to_date("summer 28");
        SE.next(function() {
            NPCS[NpcId.Celine].set_heart_level(8);
        });
        SE.goto_scene_trigger("shooting_star_morning");
        SE.play_out_scene("shooting_star_morning");
        SE.goto("celine");
        SE.interact_with(obj_celine, "misc_local/interact_invite");
        SE.play_out_textbox();
        SE.clock_jump("8:00pm");
        SE.goto("summit"); //
        SE.play_out_scene("shooting_star_romantic");
        SE.play_out_eod();

        chain.append(LinkId.Function, function() {
            var missing_scenes = List();
            var keys = scenes_in_test_target(SceneTestTarget.ShootingStar);
            for (var i = 0; i < array_length(keys); i++) {
                if !MIST.scene_history.contains(keys[i]) {
                    missing_scenes.push(keys[i]);
                }
            }

            if !missing_scenes.is_empty() {
                crash("The following scenes were not covered by the test:\n{}", missing_scenes.join(", "));
            }
        })
    }
});

TS_TESTS.push({
    name: "dateable_progression",
    exclude_from_standard: true,
    call: function(chain) {
        SE = new StoryExecutor(chain);

        SE.next(function() {
            fulfill_requirement(Requirement.Sleep);
            ARI.inventory.resize(30);
        });

        static LETTER_QUEST = function(npc, heart_level, scene_name, letter_name, quest_name, npc_to_turn_into) {
            quest_name = quest_name == undefined ? letter_name : quest_name;
            SE.execute(format("npc set_heart_level {} {}", npc, heart_level));
            SE.end_day();
            SE.open_letter(letter_name);
            SE.assert_quest_active(quest_name);
            if npc_to_turn_into != undefined {
                SE.turn_in_quest(npc_to_turn_into, quest_name);
            } else {
                SE.goto_scene_trigger(scene_name);
            }
            SE.play_out_scene(scene_name);
            SE.assert_quest_complete(quest_name);
        }

        static BOARD_QUEST = function(npc, heart_level, scene_name, quest_name, npc_to_turn_into) {
            SE.execute(format("npc set_heart_level {} {}", npc, heart_level));
            SE.end_day();
            SE.accept_from_request_board(quest_name);
            SE.assert_quest_active(quest_name);
            if npc_to_turn_into != undefined {
                SE.turn_in_quest(npc_to_turn_into, quest_name);
            } else {
                SE.goto_scene_trigger(scene_name);
            }
            SE.play_out_scene(scene_name);
            SE.assert_quest_complete(quest_name);
        }

        static DATING_TUTORIAL = function() {
            SE.end_day();
            SE.goto_scene_trigger("elsie_dating_tutorial");
            SE.play_out_scene("elsie_dating_tutorial");
        }

        static TEST_MARRIAGE_AND_CHILDREN = function(npc, ten_heart_item, actually_line, choice_line) {
            SE.next(function(npc) {
                for (var i = 0; i < NpcId.LEN; i++) {
                    if i == npc {
                        NPCS[npc].set_heart_level(10);
                    } else {
                        T2R.write(format("{NpcId}_status", i), undefined);
                        NPCS[i].set_heart_level(irandom(10));
                    }
                }

                ARI.inventory.slot(0).drain();

                var grid = GRIDS[LocationId.PlayerHome];
                erase_object_node(grid, grid.node_index_for_cell(13, 13));
                grid.write_node(10, 13, ObjectId.BasicDoubleBedWalnut, Cardinal.South);
                ARI.last_bed_used = all_player_beds().first();
            }, [npc]);
            SE.skip_to_date("spring 1"); //
            SE.goto_scene_trigger("engagement_tutorial");
            SE.play_out_scene("engagement_tutorial");
            SE.next(function() {
                assert_eq(ARI.inventory.slot(0).item.item_id, ItemId.EngagementRingRecipeScroll);
                assert(!ARI.recipe_unlocks[ItemId.EngagementRing]);
                use_item_fast(ARI.inventory.slot(0).item);
            });
            SE.wait(1);
            SE.next(function() {
                var menu = ANCHOR.get_menu(Menu.Popup);
                if menu != undefined {
                    ANCHOR.tap_node(menu.buttons.first());
                }
                assert(ARI.recipe_unlocks[ItemId.EngagementRing]);
                ARI.give_item(ItemId.EngagementRing, 5);
                TS_TEXTBOX_PROMPT_INDEX = function() {
                    return 1; //
                };
            })
            SE.goto(npc_id_to_string(npc));
            SE.interact_with(npc_id_to_gm_obj_id(npc), "misc_local/propose");
            SE.play_out_textbox();
            SE.play_out_scene(format("{NpcId}_ten_hearts", npc));
            SE.next(function(npc, ten_heart_item) {
                var npc = NPCS[npc];
                assert_eq(
                    ANCHOR.get_menu(Menu.Calendar),
                    undefined,
                    "Calendar should not have opened!",
                );
                assert_eq(
                    ARI.inventory.item_id_quantity(ItemId.EngagementRing),
                    5,
                    "Rings should not have been cleaned up!",
                );
                assert_eq(
                    ARI.inventory.item_id_quantity(ten_heart_item),
                    1,
                    "Did not receive ten heart item!",
                );
                assert(!npc.is_fiance(), "Should not be engaged!");
                assert_eq(ARI.proposal_date, undefined);
                assert_eq(ARI.wedding_date, undefined);
                TS_TEXTBOX_PROMPT_INDEX = function() {
                    return 0; //
                };
            }, [npc, ten_heart_item]);
            SE.goto(npc_id_to_string(npc));
            SE.interact_with(npc_id_to_gm_obj_id(npc), "misc_local/propose");
            SE.play_out_textbox();
            SE.play_out_scene(format("{NpcId}_ten_hearts", npc));
            SE.next(function(npc, ten_heart_item) {
                ANCHOR.get_menu(Menu.Calendar).close();
                var npc = NPCS[npc];
                assert_eq(
                    ARI.inventory.item_id_quantity(ItemId.EngagementRing),
                    0,
                    "Rings should have been cleaned up!",
                );
                assert_eq(
                    ARI.inventory.item_id_quantity(ten_heart_item),
                    1,
                    "Should only have one ten heart item!",
                );
                assert(npc.is_fiance(), "Should be engaged!");
                assert_neq(ARI.proposal_date, undefined);
                assert_neq(ARI.wedding_date, undefined);
            }, [npc, ten_heart_item]);
            SE.skip_to_date("4"); //
            SE.end_day();
            SE.play_out_scene("wedding");
            SE.next(function(npc) {
                var npc = NPCS[npc];
                assert(npc.is_spouse(), "Should be married!");
                ARI.inventory.slot(0).drain();

            }, [npc]);
            SE.play_out_eod();
            SE.skip_to_date("13");
            SE.end_day("great_bird_0");
            SE.next(function() {
                assert_eq(
                    ARI.inventory.item_id_quantity(ItemId.MysticalFeather),
                    1,
                    "Should have a mystical feather!",
                );
            });

            static TEST_STORK_CYCLE = function(npc, actually_line, choice_line, index) {
                SE.next(function() {
                    MIST.scene_history.remove("great_bird_1");

                    //
                    ARI.inventory.slot(0).drain();
                    ARI.give_item(ItemId.MysticalFeather);
                });
                SE.goto(npc_id_to_string(npc));
                SE.interact_with(npc_id_to_gm_obj_id(npc), "misc_local/discuss");
                SE.next(function() {
                    TS_TEXTBOX_PROMPT_INDEX = function() {
                        return 1; //
                    }
                });
                SE.play_out_textbox();
                SE.next(function() {
                    assert_eq(
                        ARI.inventory.item_id_quantity(ItemId.MysticalFeather),
                        1,
                        "Should have a mystical feather!",
                    );
                });
                SE.interact_with(npc_id_to_gm_obj_id(npc), "misc_local/discuss");
                SE.next(function() {
                    TS_TEXTBOX_PROMPT_INDEX = function() {
                        return 0; //
                    }
                });
                SE.play_out_textbox();
                SE.next(function(npc, actually_line, choice_line, index) {
                    assert(T2R.read("pending_stork_visit"));
                    assert_eq(
                        ARI.inventory.item_id_quantity(ItemId.MysticalFeather),
                        0,
                        "Should not have a mystical feather!",
                    );
                    global.__actually_line = actually_line;
                    global.__choice_line = choice_line;
                    global.__choice = index;
                    TS_TEXTBOX_PROMPT_INDEX = function(line) {
                        if line == global.__actually_line {
                            return 1; //
                        }
                        if line == global.__choice_line {
                            return global.__choice;
                        }
                        return 0;
                    }
                }, [npc, actually_line, choice_line, index]);
                SE.end_day("great_bird_1");
                SE.skip_to_date("12");
                SE.end_day();
                if NPC_PROTOTYPES[npc].can_carry_child {
                    switch index {
                        case 0:
                            SE.play_out_scene("stork_delivery");
                            break;
                        case 1:
                            SE.play_out_scene("player_delivery");
                            break;
                        case 2:
                            SE.play_out_scene("spouse_delivery");
                            break;
                    }
                } else if index == 0 {
                    SE.play_out_scene("player_delivery");
                } else {
                    SE.play_out_scene("stork_delivery");
                }

                SE.next(function() {
                    assert_eq(array_length(ARI.children), 1, "Should have on child!");
                    ARI.children = [];
                    ARI.inventory.slot(0).drain();
                    ARI.give_item(ItemId.MysticalFeather);
                })
            }

            TEST_STORK_CYCLE(npc, actually_line, choice_line, 0);
            TEST_STORK_CYCLE(npc, actually_line, choice_line, 1);
            if NPC_PROTOTYPES[npc].can_carry_child {
                TEST_STORK_CYCLE(npc, actually_line, choice_line, 2);
            }
        }

        switch NPC_TEST_TARGET {
            case NpcId.Adeline:
                LETTER_QUEST("adeline", 2, "adeline_two_hearts", "the_smell_of_drying_ink");
                LETTER_QUEST("adeline", 4, "adeline_four_hearts", "a_rewarding_choice");
                LETTER_QUEST("adeline", 6, "adeline_six_hearts", "chief_inspector");
                TS_TEXTBOX_PROMPT_INDEX = function() { return 1; };
                LETTER_QUEST("adeline", 8, "adeline_eight_hearts", "lost_track_of_time_ssna", "lost_track_of_time");
                DATING_TUTORIAL();
                TEST_MARRIAGE_AND_CHILDREN(NpcId.Adeline, ItemId.AdelinesLifetimePlanner, "7", "14");
                break;
            case NpcId.Balor:
                SE.simulate_quest("repair_the_bridge");
                SE.next(function() {
                    fulfill_requirement(Requirement.RepairedEasternRoadBridge);
                });
                BOARD_QUEST("balor", 4, "balor_two_hearts", "tall_dark_and_mysterious", NpcId.Balor);
                LETTER_QUEST("balor", 4, "balor_four_hearts", "an_open_book");
                SE.next(function() {
                    shipping_bins().first().inventory.add(ItemId.OreRuby, 999);
                })
                LETTER_QUEST("balor", 6, "balor_six_hearts", "lemonade_from_lemons");
                TS_TEXTBOX_PROMPT_INDEX = function() { return 1; };
                LETTER_QUEST("balor", 8, "balor_eight_hearts", "for_good_ssa", "for_good");
                DATING_TUTORIAL();
                TEST_MARRIAGE_AND_CHILDREN(NpcId.Balor, ItemId.BalorsPolishedGem, "6", "13");
                break;
            case NpcId.Caldarus:
                SE.next(function() {
                    fulfill_requirement(Requirement.UnlockedDeepWoods);
                    fulfill_requirement(Requirement.ClosedFinalSeal);
                });
                TS_TEXTBOX_PROMPT_INDEX = function() { return 1; };
                LETTER_QUEST("caldarus", 8, "caldarus_eight_hearts", "life_in_this_form");
                DATING_TUTORIAL();
                TEST_MARRIAGE_AND_CHILDREN(NpcId.Caldarus, ItemId.CaldarusDragonswornStatue, "7", "15");
                break;
            case NpcId.Celine:
                LETTER_QUEST("celine", 2, "celine_two_hearts", "the_unusual_seed");
                LETTER_QUEST("celine", 4, "celine_four_hearts", "water_and_soil");
                LETTER_QUEST("celine", 6, "celine_six_hearts", "a_change_of_greenery");
                SE.simulate_quest("repair_the_summit_stairs");
                TS_TEXTBOX_PROMPT_INDEX = function() { return 1; };
                LETTER_QUEST("celine", 8, "celine_eight_hearts", "a_lost_flower");
                DATING_TUTORIAL();
                TEST_MARRIAGE_AND_CHILDREN(NpcId.Celine, ItemId.CelinesRevivedFlower, "8", "16");
                break;
            case NpcId.Eiland:
                LETTER_QUEST("eiland", 2, "eiland_two_hearts", "the_stele");
                LETTER_QUEST("eiland", 4, "eiland_four_hearts", "the_ruins");
                LETTER_QUEST("eiland", 6, "eiland_six_hearts", "the_manor");
                TS_TEXTBOX_PROMPT_INDEX = function() { return 1; };
                SE.next(function() {
                    fulfill_requirement(Requirement.UnlockedDeepWoods);
                });
                LETTER_QUEST("eiland", 8, "eiland_eight_hearts", "the_glade");
                DATING_TUTORIAL();
                TEST_MARRIAGE_AND_CHILDREN(NpcId.Eiland, ItemId.EilandsLegacyStele, "6", "13");
                break;
            case NpcId.Hayden:
                LETTER_QUEST("hayden", 2, "hayden_two_hearts", "a_get_together");
                LETTER_QUEST("hayden", 4, "hayden_four_hearts", "extra_feed");
                LETTER_QUEST("hayden", 6, "hayden_six_hearts", "real_fine_day");
                SE.simulate_quest("repair_the_mill");
                TS_TEXTBOX_PROMPT_INDEX = function() { return 1; };
                LETTER_QUEST("hayden", 8, "hayden_eight_hearts", "a_little_while_longer_ssna", "a_little_while_longer");
                DATING_TUTORIAL();
                TEST_MARRIAGE_AND_CHILDREN(NpcId.Hayden, ItemId.HaydensCarvedNest, "7", "14");
                break;
            case NpcId.Juniper:
                BOARD_QUEST("juniper", 2, "juniper_two_hearts", "becoming_junipers_guinea_pig");
                LETTER_QUEST("juniper", 4, "juniper_four_hearts", "horsing_around");
                LETTER_QUEST("juniper", 6, "juniper_six_hearts", "working_like_a_dog");
                SE.simulate_quest("the_earth_tablet");
                SE.next(function() {
                    ARI.inventory.slot(0).drain();
                    ARI.give_item(ItemId.BreathOfFire);
                });
                TS_TEXTBOX_PROMPT_INDEX = function() { return 1; };
                LETTER_QUEST("juniper", 8, "juniper_eight_hearts", "potions_and_errands", "potions_and_errands", NpcId.Juniper);
                DATING_TUTORIAL();
                TEST_MARRIAGE_AND_CHILDREN(NpcId.Juniper, ItemId.JunipersProtectionScroll, "8", "17");
                break;
            case NpcId.March:
                LETTER_QUEST("march", 2, "march_two_hearts", "surprise_me");
                SE.next(function() {
                    fulfill_requirement(Requirement.SaturdayMarketUnlocked);
                });
                LETTER_QUEST("march", 4, "march_four_hearts", "many_hands_make_light_work");
                LETTER_QUEST("march", 6, "march_six_hearts", "shield_of_the_realm");
                SE.next(function() {
                    fulfill_requirement(Requirement.BrokeFireSeal);
                })
                SE.execute("npc set_heart_level march 8");
                SE.end_day();
                SE.goto_scene_trigger("march_eight_hearts");
                TS_TEXTBOX_PROMPT_INDEX = function() { return 1; };
                SE.play_out_scene("march_eight_hearts");
                DATING_TUTORIAL();
                TEST_MARRIAGE_AND_CHILDREN(NpcId.March, ItemId.MarchsMistrianShield, "8", "16");
                break;
            case NpcId.Reina:
                LETTER_QUEST("reina", 2, "reina_two_hearts", "pie_in_the_sky");
                LETTER_QUEST("reina", 4, "reina_four_hearts", "shopping_buddy");
                LETTER_QUEST("reina", 6, "reina_six_hearts", "farm_fresh_sous_chef");
                TS_TEXTBOX_PROMPT_INDEX = function() { return 1; };
                LETTER_QUEST("reina", 8, "reina_eight_hearts", "the_aldarian_cooking_contest");
                DATING_TUTORIAL();
                TEST_MARRIAGE_AND_CHILDREN(NpcId.Reina, ItemId.ReinasCookbookManuscript, "9", "17");
                break;
            case NpcId.Ryis:
                SE.next(function() {
                    ARI.inventory.slot(0).drain();
                    ARI.give_item(ItemId.BasicWood, 15);
                });
                LETTER_QUEST("ryis", 2, "ryis_two_hearts", "bird_song", "bird_song", NpcId.Landen);
                LETTER_QUEST("ryis", 4, "ryis_four_hearts", "a_sapling");
                LETTER_QUEST("ryis", 6, "ryis_six_hearts", "a_birdhouse");
                TS_TEXTBOX_PROMPT_INDEX = function() { return 1; };
                LETTER_QUEST("ryis", 8, "ryis_eight_hearts", "a_duet");
                DATING_TUTORIAL();
                TEST_MARRIAGE_AND_CHILDREN(NpcId.Ryis, ItemId.RyisHawthornTree, "8", "17");
                break;
            case NpcId.Seridia:
                SE.next(function() {
                    fulfill_requirement(Requirement.BrokeFireSeal);
                    fulfill_requirement(Requirement.SeridiaTransformed);
                    T2R.write("seridia_is_human", true);
                    T2R.write("caldarus_seridia_town", true);
                })
                SE.end_day();
                TS_TEXTBOX_PROMPT_INDEX = function() { return 1; };
                LETTER_QUEST("seridia", 8, "seridia_eight_hearts", "whatever_your_heart_desires");
                DATING_TUTORIAL();
                TEST_MARRIAGE_AND_CHILDREN(NpcId.Seridia, ItemId.SeridiasDragonswornArmor, "10", "18");
                break;
            case NpcId.Valen:
                BOARD_QUEST("valen", 2, "valen_two_hearts", "the_annual_check_up");
                SE.next(function() {
                    ARI.inventory.slot(0).drain();
                    ARI.give_item(ItemId.Peat);
                });
                LETTER_QUEST("valen", 4, "valen_four_hearts", "batch_312", "batch_312", NpcId.Valen);
                LETTER_QUEST("valen", 6, "valen_six_hearts", "an_outside_consultant");
                TS_TEXTBOX_PROMPT_INDEX = function() { return 1; };
                LETTER_QUEST("valen", 8, "valen_eight_hearts", "the_panacea");
                DATING_TUTORIAL();
                TEST_MARRIAGE_AND_CHILDREN(NpcId.Valen, ItemId.ValensPanaceaJar, "8", "16");
                break;
            default:
                crash("a valid `npc_test_target` must be given for the `dateable_progression` test");
                break;
        }
    }
});

//
function PET_TEST_MENU_INTERACTION(job) {
    ANCHOR.spawn_menu(Menu.Journal);
    var menu = ANCHOR.spawn_menu(Menu.Animal);
    var journal_menu = ANCHOR.get_menu(Menu.Journal);
    journal_menu.set_active_sub_menu(Menu.Animal);
    menu.select_animal(PET);
    ANCHOR.tap_node(menu.job_field);
    var popup = ANCHOR.get_menu(Menu.Popup);
    ANCHOR.tap_node(popup.pilot.map[job][0]);
    journal_menu.close();
};


function test_suite_grid_load_failure(object_id, location_id, xx, yy) {
    if location_id != LocationId.Aldaria {
        crash("failed to write {ObjectId} @ {LocationId}::{}x{}", object_id, location_id, xx, yy);
    }
}

function WAIT_HERE(chain) {
    chain.push({
        name: "wait",
        call: function(chain) {
            chain.append(LinkId.Function, function() {
                CLOCK.time_stopped = false;
                error("TIME STOPPED -- WE ARE WAITING -- PLEASE INPUT `ts_proceed` to BUGGER");
            });
            chain.append(LinkId.Await, function() {
                return global.__can_proceed;
            });
            chain.append(LinkId.Function, function() {
                global.__can_proceed = false;
                CLOCK.time_stopped = true;
            })
        }
    });
}

#macro TS_TEXTBOX_PROMPT_INDEX global.__ts_textbox_prompt_index
TS_TEXTBOX_PROMPT_INDEX = function(line_name) {
    return 0;
};

function __ts_mist_textbox_interacted() {
    var driver = MIST.runtime.blackboard.get("driver");
    driver.prompt_index_selected = TS_TEXTBOX_PROMPT_INDEX(driver.current_line.line_id);
    var state = driver.textbox.state;
    return matches(state, TextboxState.Say, TextboxState.Ask, TextboxState.Info);
}

//
function setup_test_suite_utils() {
    #macro TS_OBJECT_POSITIONS global.__ts_object_positions
    global.__ts_object_positions = List();

    #macro TS_OBJECT_LIST global.__ts_object_list
    global.__ts_object_list = ListFromArray([
        ObjectId.GrassMedium,
        ObjectId.GrassLarge,
        ObjectId.GrassSmall,
        ObjectId.RockCopper,
        ObjectId.Weed,
        ObjectId.Branch,
        ObjectId.Strawberry,
        ObjectId.Corn,
        ObjectId.BorderFence,
        ObjectId.StumpApple,
        ObjectId.BasicWoodChestLight,
        ObjectId.TreeCherry,
        ObjectId.DigSite,
    ]);

    #macro TS_TOOLS_LIST global.__ts_tools_list

    global.__ts_tools_list = ListFromArray([
        {
            tool: ItemId.PickAxeMistril,
            pre_assertion: function(object_position) {
                object_id = GRID.node_object_id[GRID.node_index_for_cell(object_position.x,object_position.y)];
            },
            post_assertion: function(object_position) {
                var ni = GRID.node_index_for_cell(object_position.x,object_position.y);
                if object_id == undefined {
                    //
                    return true;
                }
                var object_category = object_id_to_object_category(object_id);
                if object_category == ObjectCategory.Rock {
                    assert(GRID.node_object_id[ni] == undefined, "We tried picking {}, but for some reason its still there!",object_id_to_string(object_id));
                }
            }
        },
        {
            tool: ItemId.ShovelMistril,
            pre_assertion: function(object_position) {
                //
                var ni = GRID.node_index_for_cell(object_position.x,object_position.y);
                GRID.write_ground(object_position.x,object_position.y,GroundKind.Soil);
                //
                ground_kind = GRID.node_terrain_ground_kind[ni];
                object_id = GRID.node_object_id[ni];
            },
            post_assertion: function(object_position) {
                var ni = GRID.node_index_for_cell(object_position.x,object_position.y);
                if object_id == undefined || (object_id != undefined && object_id_to_object_category(object_id) == ObjectCategory.Grass) {
                    switch ground_kind {
                        case GroundKind.Grass:
                            assert(GRID.node_terrain_ground_kind[ni] == GroundKind.Dirt, "For some reason, we tried to shovel grass and this tile isn't dirt..");
                            break;
                        case GroundKind.Dirt:
                            assert(GRID.node_terrain_ground_kind[ni] == GroundKind.Grass, "For some reason, we tried to shovel dirt and this tile isn't grass..");
                            break;
                        case GroundKind.Soil:
                            assert(GRID.node_terrain_ground_kind[ni] == GroundKind.Grass, "For some reason, we tried to shovel dirt and this tile isn't grass..");
                            break;
                        case GroundKind.RiverBank:
                            impossible("can't get here because of `can_shovel_node`");
                    }
                }
            }
        },
        {
            tool: ItemId.AxeMistril,
            pre_assertion: function(object_position) {
                var ni = GRID.node_index_for_cell(object_position.x,object_position.y);
                object_id = GRID.node_object_id[ni];
            },
            post_assertion: function(object_position) {
                var ni = GRID.node_index_for_cell(object_position.x,object_position.y);
                //
                if object_id != undefined && (object_id == ObjectId.Branch || object_id_to_object_category(object_id) == ObjectCategory.Tree){
                    //
                    assert(GRID.node_object_id[ni] == undefined, "We axed a {}, and for some reason its still there..",object_id_to_string(object_id));
                }
            }
        },
        {
            tool: ItemId.HoeMistril,
            pre_assertion: function(object_position) {
                var ni = GRID.node_index_for_cell(object_position.x,object_position.y);
                object_id = GRID.node_object_id[ni];
                terrain_ground_kind = GRID.node_terrain_ground_kind[ni];
            },
            post_assertion: function(object_position) {
                var ni = GRID.node_index_for_cell(object_position.x,object_position.y);
                if object_id == undefined {
                    if terrain_ground_kind == GroundKind.Dirt {
                        assert(GRID.node_terrain_ground_kind[ni] == GroundKind.Soil, "We hoed to make dirt into soil.. but for some reason it's not soil");
                    }
                    if terrain_ground_kind == GroundKind.Soil {
                        assert(GRID.node_terrain_ground_kind[ni] == GroundKind.Dirt, "We hoed to make dirt into soil.. but for some reason it's not soil");
                    }
                }
            }
        },
        {
            tool: ItemId.WateringCanMistril,
            pre_assertion: function(object_position) {
                self.waterable = can_water_node(GRID, GRID.node_index_for_cell(object_position.x, object_position.y));
            },
            wait_time: FPS * 2,
            post_assertion: function(object_position) {
                if self.waterable {
                    var ni = GRID.node_index_for_cell(object_position.x, object_position.y);
                    assert(GRID.node_terrain_is_watered[ni], "we failed to water a tile!");
                }
            }
        }
    ]);
}

function test_suite_gather_save(input_path, output_path, game_ident) {
    var input_fname = filename_name(input_path);

    //
    trace("Loading info for upgrade target '{}' at game_id `{}`...", input_fname, game_ident);

    //
    if file_exists(output_path) {
        file_delete(output_path);
    }
    file_copy(input_path, output_path);
    assert(file_exists(output_path), "we failed to copy over our save!");

    var vault = vault_open_vault(output_path);

    var loader = new RustLoader(
        vault,
        output_path,
    );
    var save_info = loader.load_file("info");
    if save_info.version[$ "pre"] == undefined {
        save_info.version.pre = undefined;
    }

    if !version_is_ahead(TEST_TARGET_VERSION, save_info.version) {
        info("{SemVer} is already at or beyond {SemVer}...aborting test", save_info.version, TEST_TARGET_VERSION);
        return undefined;
    }

    trace("Updating '{}' from `{SemVer}` to `{SemVer}`", input_fname, save_info.version, TEST_TARGET_VERSION);
    var saver = apply_save_patches(save_info.version, TEST_TARGET_VERSION, loader);
    assert_neq(saver, undefined, "We failed to patch the upgrade target!");
    assert(saver.save_to_disk(save_info));
    loader.close_vault();

    return {
        info: save_info,
        game_ident,
        exact_save_path: output_path,
    };
}
