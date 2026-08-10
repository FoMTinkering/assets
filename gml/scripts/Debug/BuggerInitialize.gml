//
if DEBUG_TOOLS == false {
    return;
}

function bugger_initialize() {
    BUGGER
        .add_command(
            BuggerCommand("help")
                .author("gabe")
                .process(function () {
                    BUGGER.cli.post("Here is a list of available commands:");
                    var s = "";
                    var keys = BUGGER.commands.keys();
                    for (var i = 0; i < array_length(keys); i++) {
                        s += fmt("{}, ", keys[i]);
                    }
                    BUGGER.cli.post(s);
                })
        )
        .add_command(
            BuggerCommand("fulfill_requirement")
                .arg(BuggerArgument("requirement").values(get_all_keys(Requirement.LEN, requirement_to_string)))
                .process(function(args) {
                    var requirement = string_to_requirement(args.requirement);
                    assert(requirement_is_alias(requirement), "This command can only be used on aliases!");
                    fulfill_requirement(requirement, true);
                })
        )
        .add_command(
            BuggerCommand("unfulfill_requirement")
                .arg(BuggerArgument("requirement").values(get_all_keys(Requirement.LEN, requirement_to_string)))
                .process(function(args) {
                    var requirement = string_to_requirement(args.requirement);
                    assert(requirement_is_alias(requirement), "This command can only be used on aliases!");
                    unfulfill_requirement(requirement, true);
                })
        )
        .add_command(
            BuggerCommand("world_mod_enable")
                .arg(BuggerArgument("world_mod").values(get_all_keys(WorldMod.LEN, world_mod_to_string)))
                .process(function(args) {
                    var world_mod = WORLD_MODS[string_to_world_mod(args.world_mod)];
                    for (var i = 0; i < Requirement.LEN; i++) {
                        if world_mod.requirements[i] != undefined {
                            fulfill_requirement(i, world_mod.requirements[i]);
                        }
                    }
                    setup_room();
                })
        )
        .add_command(
            BuggerCommand("world_mod_disable")
                .arg(BuggerArgument("world_mod").values(get_all_keys(WorldMod.LEN, world_mod_to_string)))
                .process(function(args) {
                    var world_mod = WORLD_MODS[string_to_world_mod(args.world_mod)];
                    for (var i = 0; i < Requirement.LEN; i++) {
                        if world_mod.requirements[i] != undefined {
                            unfulfill_requirement(i, world_mod.requirements[i]);
                        }
                    }
                    setup_room();
                })
        )
        .add_command(
            BuggerCommand("check_mist_spot")
            .author("joel")
            .process(function() {
                if MIST_SIGHT_ACTIVE_INDEX != undefined {
                    var mist_sight = MIST_SIGHT_LIST.get(MIST_SIGHT_ACTIVE_INDEX);
                    BUGGER.cli.echo("Mist spot is at {LocationId}: {}x{}", mist_sight.location_id, mist_sight.pos.x, mist_sight.pos.y);
                } else {
                    BUGGER.cli.echo("There is no active mist spot right now");
                }
            })
        )
        .add_command(
            BuggerCommand("create_mist_spot")
            .author("joel")
            .process(function() {
                instance_create_depth(obj_ari.x, obj_ari.y, 0, obj_mist_spot, {
                    index: 0
                });
            })
        )
        .add_command(
            BuggerCommand("noclip")
                .author("john carmack")
                .help("Toggles Ari's collision checking")
                .process(function () {
                    obj_ari.no_clip = !obj_ari.no_clip;
                })
        )
        .add_command(
            BuggerCommand("where")
                .process(function() {
                    if instance_exists(obj_ari) {
                        if CURRENT_DYN_INDEX == undefined {
                            BUGGER.cli.echo("{LocationId} @ {}x{}, grid: {}x{}", CURRENT_LOCATION_ID, obj_ari.x, obj_ari.y, obj_ari.x div 8, obj_ari.y div 8);
                        } else {
                            BUGGER.cli.echo("{LocationId}<{}> @ {}x{}, grid: {}x{}", CURRENT_LOCATION_ID, CURRENT_DYN_INDEX, obj_ari.x, obj_ari.y, obj_ari.x div 8, obj_ari.y div 8);
                        }
                    } else {
                        if CURRENT_DYN_INDEX == undefined {
                            BUGGER.cli.echo("{LocationId} @ NO_ARI", CURRENT_LOCATION_ID);
                        } else {
                            BUGGER.cli.echo("{LocationId}<{}> @ NO_ARI", CURRENT_LOCATION_ID, CURRENT_DYN_INDEX);
                        }
                    }
                })
        )
        .add_command(
            BuggerCommand("motherlode")
                .process(function () {
                    ARI.modify_gold(50000);
                })
        )
        .add_command(
            BuggerCommand("rosebud")
                .process(function () {
                    ARI.modify_gold(1000);
                })
        )
        .add_command(
            BuggerCommand("transform")
                .help("Shows all origin points")
                .process(function () {
                    obj_cosmic_debug.transforms = !obj_cosmic_debug.transforms;
                })
        )
        .add_command(
            BuggerCommand("show_collision_box")
                .help("Shows the collision boxes for Ari and NPCs")
                .process(function () {
                    obj_cosmic_debug.show_cbs = !obj_cosmic_debug.show_cbs;
                })
        )
        .add_command(
            BuggerCommand("refresh_achievements")
            .process(function() {
                refresh_achievements();
            })
        )
        .add_command(
            BuggerCommand("reset_achievements")
            .process(function() {
                for (var i = 0; i < Achievement.LEN; i++) {
                    steam_reset_stats();
                }
            })
        )
        .add_command(
            BuggerCommand("check_locked_achievements")
            .process(function() {
                var out = ListFromArray(array_create_ext(Achievement.LEN, identity))
                    .retain(function(i) {
                        return !ACHIEVEMENT_CACHE[i];
                    })
                    .map(achievement_to_string)
                    .join(",");

                trace("Locked Achievements: {}", out);
            })
        )
        .add_command(
            BuggerCommand("find")
                .author("jack")
                .arg(BuggerArgument("find_kind").values(["forageables", "dig_sites", "bugs", "ari"]))
                .process(function(o) {
                    switch o.find_kind {
                        case "forageables":
                            var stamp = irandom(I32_MAX);
                            var found_any = false;
                            for (var xx = 0; xx < GRID.dims.x; xx++) {
                                for (var yy = 0; yy < GRID.dims.y; yy++) {
                                    var ni = GRID.node_index_for_cell(xx, yy);
                                    if object_id_to_object_category(GRID.node_object_id[ni]) != ObjectCategory.Crop
                                        || has_flag(GRID.node_parent[ni].ctx, CropFlag.FORAGEABLE) == false
                                        || GRID.node_parent[ni].last_update == stamp
                                    {
                                        continue;
                                    }

                                    GRID.node_parent[ni].last_update = stamp;
                                    var found_any = true;

                                    BUGGER.cli.echo("{ObjectId} @ cell {}x{}", GRID.node_object_id[ni], xx, yy);
                                }
                            }
                            if found_any {
                                BUGGER.cli.echo("note: ARI @ cell {}x{}", obj_ari.x div 8, obj_ari.y div 8);
                            } else {
                                BUGGER.cli.echo("no forageables in room");
                            }
                            break;
                        case "dig_sites":
                            var stamp = irandom(I32_MAX);
                            var found_any = false;
                            for (var xx = 0; xx < GRID.dims.x; xx++) {
                                for (var yy = 0; yy < GRID.dims.y; yy++) {
                                    var ni = GRID.node_index_for_cell(xx, yy);
                                    if object_id_to_object_category(GRID.node_object_id[ni]) != ObjectCategory.DigSite
                                        || GRID.node_parent[ni].last_update == stamp
                                    {
                                        continue;
                                    }
                                    GRID.node_parent[ni].last_update = stamp;
                                    found_any = true;

                                    BUGGER.cli.echo("{ObjectId} @ cell {}x{}", GRID.node_object_id[ni], xx, yy);
                                }
                            }
                            if found_any {
                                BUGGER.cli.echo("note: ARI @ cell {}x{}", obj_ari.x div 8, obj_ari.y div 8);
                            } else {
                                BUGGER.cli.echo("no dig_sites in room");
                            }
                            break;
                        case "bugs":
                            var found_any = false;
                            with obj_bug {
                                BUGGER.cli.echo("{ItemId} @ {}x{}", self.item_id, self.x, self.y);
                                found_any = true;
                            }
                            if found_any {
                                BUGGER.cli.echo("note: ARI @ {}x{}", obj_ari.x, obj_ari.y);
                            } else {
                                BUGGER.cli.echo("no bugs in room");
                            }
                            break;
                        case "ari":
                                BUGGER.cli.echo("Heeere's ARI! {}x{} ({}x{})", obj_ari.x, obj_ari.y, obj_ari.x div 8, obj_ari.y div 8);
                        break;
                        default:
                            BUGGER.cli.echo("We can't find `{}`", o.find_kind);
                            break;
                    }
                })
        )
        .add_command(
            BuggerCommand("water_all")
                .author("jack")
                .help("waters all crops")
                .process(function() {
                    var g = GRIDS[LocationId.Farm];

                    for (var xx = 0; xx < g.dims.x; xx += 2) {
                        for (var yy = 0; yy < g.dims.y; yy += 2) {
                            var ni = g.node_index_for_cell(xx, yy);

                            if object_id_to_object_category(g.node_object_id[ni]) != ObjectCategory.Crop
                                || g.node_terrain_is_watered[ni]
                            {
                                continue;
                            }
                            water_chunk(g, xx, yy);
                        }
                    }
                })
        )
        .add_command(
            BuggerCommand("rock_drop_chance")
            .author("joel")
            .help("shows the drop chance results after attempting to drop items 50,000 times from a specific rock")
            .process(function() {
                var rocks = [];
                for (var i = 0; i < ObjectId.LEN; i++) {
                    if NODE_PROTOTYPES[i].category_id == ObjectCategory.Rock {
                        var pass = false;
                        var bundle = NODE_PROTOTYPES[i].drop_bundle;
                        for (var j = 0, jc = bundle.drops.count(); j < jc; j++) {
                            var drop = bundle.drops.get(j);
                            if drop.perfect_pick_chance != 0 {
                                pass = true;
                            }
                        }
                        if pass {
                            array_push(rocks, NODE_PROTOTYPES[i]);
                        }
                    }
                }

                var drop = undefined;
                var list = undefined;
                var total_items_dropped = 0;
                var arr = array_create(ItemId.LEN, 0);
                var mask = array_create(ItemId.LEN, true);
                var k = 0;
                for (var i = 0, ic = array_length(rocks); i < ic; i++) {
                    var bundle = rocks[i].drop_bundle;
                    trace("Testing {ObjectId}...", rocks[i].object_id);

                    repeat 100000 {
                        list = bundle.choose_drop();
                        //
                        for (var k = 0, kc = list.count(); k < kc; k++) {
                            drop = list.get(k);
                            if mask[drop.item_id] {
                                arr[drop.item_id] += 1;
                                mask[drop.item_id] = false;
                            }
                        }
                        for (var k = 0; k < ItemId.LEN; k++) {
                            mask[k] = true;
                        }
                    }

                    for (var k = 0; k < ItemId.LEN; k++) {
                        if arr[k] != 0 {
                            trace("Chance that {ItemId} appears in the bundle: {}%", k, arr[k]/100000 * 100);
                        }
                    }
                    arr = array_create(ItemId.LEN, 0);
                    total_items_dropped = 0;
                    trace("___________________________________")
                }

            })
        )
        .add_command(
            BuggerCommand("new_day")
                .help("Runs the entire `new_day` algorithm as if you were in the game.")
                .arg(BuggerArgument("code").optional(1))
                .process(function (o) {
                    repeat real(o.code) {
                        end_day(false);
                        sell_shipping_bin_items();
                        new_day();
                    }

                    npcs_on_room_start();
                })
        )
        .add_command(
            BuggerCommand("manana")
                .author("jack")
                .help("Manana, my dudes. Advances time forward without doing any of the grid stuff.")
                .arg(BuggerArgument("code").optional(1).values(
                    array_concat(get_all_keys(Day.LEN, day_to_string), get_all_keys(Season.LEN, season_to_string))
                ))
                .arg(BuggerArgument("opt_date").optional())
                .process(function(args) {
                    var amt = 1;

                    var day_of_the_week = try_string_to_day(args.code);
                    if day_of_the_week != undefined {
                        amt = wrap(day_of_the_week - CALENDAR.day_type(), Day.LEN);
                        if amt == 0 {
                            amt = Day.LEN;
                        }
                    } else {
                        var season = try_string_to_season(args.code);
                        if season != undefined {
                            amt = wrap(season - (CALENDAR.season() % Season.LEN), Season.LEN);
                            //
                            //
                            //
                            if amt == 0 && (args.opt_date == undefined || CALENDAR.day() + 1 >= real(args.opt_date)) {
                                amt = Season.LEN;
                            }
                            amt *= 28;
                            amt -= CALENDAR.day();

                            if args.opt_date != undefined {
                                amt += real(args.opt_date) - 1;
                            }
                        } else {
                            amt = real(args.code);
                        }
                    }

                    for (var i = 0; i < amt; i++) {
                        end_day(false);
                        sell_shipping_bin_items();
                        new_day_non_grid();
                    }

                    npcs_on_room_start();
                })
        )
        .add_command(
            BuggerCommand("version")
                .author("jack")
                .process(function () {
                    BUGGER.cli.post(GAME_VERSION);
                })
        )
        .add_command(
            BuggerCommand("v")
                .author("jack")
                .process(function () {
                    BUGGER.cli.post(GAME_VERSION);
                })
        )
        .add_command(
            BuggerCommand("send_letter")
                .arg(BuggerArgument("letter").values(LETTERS.keys()))
                .process(function(args) {
                    ARI.inbox.push_mail(args.letter);
                })
        )
        .add_command(
            BuggerCommand("home_variant")
                .arg(BuggerArgument("variant").values(get_all_keys(HomeVariant.LEN, home_variant_to_string)))
                .process(function(args) {
                    DECOR.variant = string_to_home_variant(args.variant);
                    if CURRENT_LOCATION_ID == LocationId.Farm {
                        setup_room();
                    }
                })
        )
        .add_command(
            BuggerCommand("wallpaper")
                .arg(BuggerArgument("tile_set").values(get_all_furniture_tile_sets()))
                .process(function(args) {
                    if !is_home_location(CURRENT_LOCATION_ID) {
                        return;
                    }

                    var tset = string_to_asset(format("tile_furniture_{}", args.tile_set));

                    tilemap_tileset(strict_layer_tilemap_get_id("Level_0_Walls"), tset);
                    tilemap_tileset(strict_layer_tilemap_get_id("Level_1_Ceiling"), tset);
                })
        )
        .add_command(
            BuggerCommand("flooring")
                .arg(BuggerArgument("tile_set").values(get_all_furniture_tile_sets()))
                .process(function(args) {
                    if !is_home_location(CURRENT_LOCATION_ID) {
                        return;
                    }

                    var tset = string_to_asset(format("tile_furniture_{}", args.tile_set));

                    tilemap_tileset(strict_layer_tilemap_get_id("Level_0_Floor"), tset);
                })
        )
        .add_command(
            BuggerCommand("upgrade")
                .arg(BuggerArgument("upgrade").optional(true).values(get_all_keys(HomeUpgrade.LEN, home_upgrade_to_string)))
                .process(function(args) {
                    DECOR.size_upgrade = string_to_home_upgrade(args.upgrade);
                    if is_home_location(CURRENT_LOCATION_ID) {
                        return;
                    }

                    DECOR.apply_house_upgrade(GRIDS[LocationId.PlayerHome], DECOR.size_upgrade);
                })
        )
        .add_command(
            BuggerCommand("decor")
                .arg(BuggerArgument("tile_set").values(get_all_furniture_tile_sets()))
                .process(function(args) {
                    if !is_home_location(CURRENT_LOCATION_ID) {
                        return;
                    }

                    var tset = string_to_asset(format("tile_furniture_{}", args.tile_set));

                    tilemap_tileset(strict_layer_tilemap_get_id("Level_0_Floor"), tset);
                    tilemap_tileset(strict_layer_tilemap_get_id("Level_0_Walls"), tset);
                    tilemap_tileset(strict_layer_tilemap_get_id("Level_1_Ceiling"), tset);
                })
        )
        .add_command(
            BuggerCommand("farm")
                .subcommand(
                    BuggerCommand("expand")
                        .help("Opens up ye olde farm")
                        .process(function() {
                            expand_farm();

                            if CURRENT_LOCATION_ID == LocationId.Farm {
                                CAMERA.room_view_bound_width = room_width();
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("clear")
                        .help("Clears the entire farm")
                        .process(function() {
                            var farm = GRIDS[LocationId.Farm];
                            for (var xx = 0; xx < farm.dims.x; xx++) {
                                for (var yy = 0; yy < farm.dims.y; yy++) {
                                    erase_object_node(farm, farm.node_index_for_cell(xx, yy));
                                }
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("clear_main")
                        .help("Clears the main area of the farm")
                        .process(function() {
                            var farm = GRIDS[LocationId.Farm];
                            for (var xx = 0; xx < 174; xx++) {
                                for (var yy = 0; yy < 124; yy++) {
                                    erase_object_node(farm, farm.node_index_for_cell(xx, yy));
                                }
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("fill")
                        .help("Fills the farm with one object, as much as possible")
                        .arg(BuggerArgument("object_id").values(get_all_keys(ObjectId.LEN, object_id_to_string)))
                        .process(function(args) {
                            var farm = GRIDS[LocationId.Farm];
                            for (var xx = 0; xx < farm.dims.x; xx++) {
                                for (var yy = 0; yy < farm.dims.y; yy++) {
                                    farm.write_node(xx, yy, string_to_object_id(args.object_id));
                                }
                            }
                        })
                )
        )
        .add_command(
            BuggerCommand("npc")
                .author("gabe")
                .subcommand(
                    BuggerCommand("whitelist")
                        .help("Whitelists an NPC for processing. If any NPC is whitelisted, others will not run any logic.")
                        .arg(BuggerArgument("npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .process(function(args) {
                            NPC_WHITELIST = array_create(NpcId.LEN, false);
                            NPC_WHITELIST[string_to_npc_id(args.npc)] = true;
                        })
                )
                .subcommand(
                    BuggerCommand("clear_whitelist")
                        .help("Clears the NPC whitelist, re-enabling them all to run.")
                        .process(function() {
                            NPC_WHITELIST = array_create(NpcId.LEN, true);
                            BUGGER.cli.echo("Whitelist is now empty. All NPCs are running.");
                        })
                )
                .subcommand(
                    BuggerCommand("play_animation")
                        .arg(BuggerArgument("npc").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .arg(BuggerArgument("animation").help("The name of the animation, as it appears in the TOML file."))
                        .process(function(args) {
                            NPCS[string_to_npc_id(string_lower(args.npc))].set_animation(args.animation);
                        })
                )
                .subcommand(
                    BuggerCommand("set_routine")
                        .help("Turns on a Routine for an NPC.")
                        .arg(BuggerArgument("npc").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .arg(BuggerArgument("routine").help("The name of the routine").values(get_all_keys(Routine.LEN, routine_to_string)))
                        .process(function(args) {
                            var npc = NPCS[string_to_npc_id(args.npc)];
                            npc.activity_handler.set_routine(string_to_routine(args.routine));
                        })
                )
                .subcommand(
                    BuggerCommand("request_activity")
                        .help("Request the NPC to perform the given activity.")
                        .arg(BuggerArgument("npc").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .arg(BuggerArgument("activity").help("The name of the activity").values(get_all_keys(Activity.LEN, activity_to_string)))
                        .process(function(args) {
                            var npc = NPCS[string_to_npc_id(args.npc)];
                            npc.activity_handler.request_activity(string_to_activity(args.activity));
                        })
                )
                .subcommand(
                    BuggerCommand("end_activity")
                        .help("Marks the current activity as passed its expiration time.")
                        .arg(BuggerArgument("npc").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .process(function(args) {
                            var npc = NPCS[string_to_npc_id(args.npc)];
                            npc.activity_handler.end_time = 0;
                        })
                )
                .subcommand(
                    BuggerCommand("set_heart_level")
                        .help("Sets the heart level of an NPC.")
                        .arg(BuggerArgument("npc").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .arg(BuggerArgument("hearts").help("The number of hearts"))
                        .process(function(args) {
                            var npc = NPCS[string_to_npc_id(string_lower(args.npc))];
                            npc.set_heart_level(real(args.hearts));
                            npc.report_hearts();
                            T2R.write_most_liked_npc();
                        })
                )
                .subcommand(
                    BuggerCommand("set_spouse")
                        .help("Sets your spouse. This will trigger a new day!")
                        .arg(BuggerArgument("npc").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .process(function(args) {
                            var old_spouse = ARI.spouse();
                            if old_spouse != undefined {
                                T2R.write(format("{NpcId}_status", old_spouse), "best_friend");
                                NPCS[old_spouse].report_relationship();
                            }

                            ARI.children = [];
                            ARI.pending_child = undefined;

                            process_marriage(string_to_npc_id(args.npc));
                            BUGGER.execute_command("manana");
                        })
                )
        )
        .add_command(
            BuggerCommand("prop")
                .author("j")
                .subcommand(
                    BuggerCommand("spawn")
                        .arg(BuggerArgument("location").values(get_all_keys(LocationId.LEN, location_id_to_string)))
                        .arg(BuggerArgument("name").help("The name of the npc"))
                        .process(function(o) {
                            PROPS.create_prop(o.name, string_to_location_id(o.location));
                        })
                )
                .subcommand(
                    BuggerCommand("destroy")
                        .arg(BuggerArgument("location").values(get_all_keys(LocationId.LEN, location_id_to_string)))
                        .arg(BuggerArgument("name").help("The name of the trellis point where we spawn the prop"))
                        .process(function(o) {
                            PROPS.destroy_prop(o.name, string_to_location_id(o.location));
                        })
                )
        )
        .add_command(
            BuggerCommand("t2")
                .author("j")
                .subcommand(
                    BuggerCommand("status")
                        .arg(BuggerArgument("npc_id").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .process(function(o) {
                            if o.npc_id == undefined {
                                error("NPC_ID was not defined! Don't crash the game!");
                                return;
                            }

                            var npc_id = string_to_npc_id(o.npc_id);
                            var npc = NPCS[npc_id];
                            var conversation_name = T2R.request_conversation(npc_id);

                            BUGGER.cli.echo(
                                "{NpcId}:\n    conversation `{}`\n    schedule: `{}`\n    can_talk: {bool}, can_gift: {bool}\nwhere: {}, simulated: {}",
                                npc_id, conversation_name, T2R.schedule_name(npc_id), npc.talk_flag, npc.gift_flag, npc.location_position, npc.simulated_distance_traveled,
                            );
                        })
                )
                .subcommand(
                    BuggerCommand("whyc")
                        .help("Checks each requirement of a given line, giving a report on each one.")
                        .arg(BuggerArgument("npc_id").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .arg(BuggerArgument("conversation_name").help("The name of the conversation").values(T2R.conversation_names()))
                        .process(function(o) {
                            if o.npc_id == undefined {
                                error("NPC_ID was not defined! Don't crash the game!");
                                return;
                            }

                            var found_convo = T2R.fuzzy_search_conversation(string_to_npc_id(o.npc_id), o.conversation_name);
                            if found_convo == undefined {
                                BUGGER.cli.post(format("`{}` didn't match any conversations", found_convo));
                                return;
                            }

                            var output = T2R.why_conversation(string_to_npc_id(o.npc_id), found_convo);
                            BUGGER.cli.echo(output);
                        })
                )
                .subcommand(
                    BuggerCommand("whys")
                        .help("Checks each requirement of a given schedule")
                        .arg(BuggerArgument("npc_id").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .arg(BuggerArgument("schedule_name").help("The name of the conversation").values(T2R.schedule_names()))
                        .process(function(o) {
                            if o.npc_id == undefined {
                                error("NPC_ID was not defined! Don't crash the game!");
                                return;
                            }

                            var found_sched = T2R.fuzzy_search_schedule(string_to_npc_id(o.npc_id), o.schedule_name);
                            if found_sched == undefined {
                                BUGGER.cli.post(format("`{}` didn't match any schedule_name", found_sched));
                                return;
                            }

                            var output = T2R.why_schedule(string_to_npc_id(o.npc_id), found_sched);
                            BUGGER.cli.echo(output);
                        })
                )
                .subcommand(
                    BuggerCommand("converse")
                        .help("Talk to an NPC!")
                        .arg(BuggerArgument("npc_id").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .arg(BuggerArgument("conversation_name").help("The name of the conversation").values(T2R.conversation_names()))
                        .arg(BuggerArgument("conversation_kind").help("The kind of conversation").values(get_all_keys(ConversationKind.DateAcceptance + 1, conversation_kind_to_string)).optional("normal"))
                        .process(function(o) {
                            if o.npc_id == undefined {
                                error("NPC_ID was not defined! Don't crash the game!");
                                return;
                            }

                            if o.conversation_name == undefined {
                                o.conversation_name = T2R.request_conversation(string_to_npc_id(o.npc_id));
                            } else {
                                var found_convo = T2R.fuzzy_search_conversation(string_to_npc_id(o.npc_id), o.conversation_name, string_to_conversation_kind(o.conversation_kind));
                                if found_convo == undefined {
                                    BUGGER.cli.post(format("`{}` didn't match any conversations", found_convo));
                                    return;
                                } else {
                                    o.conversation_name = found_convo;
                                }
                            }

                            var driver = new ConversationDriver(string_to_npc_id(o.npc_id), o.conversation_name);
                            driver.proceed_conversation();
                        })
                )
                .subcommand(
                    BuggerCommand("schedule")
                        .help("Immediately changes an NPC's schedule to the requested one. This can produce problems!")
                        .arg(BuggerArgument("npc_id").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .arg(BuggerArgument("schedule_name").help("The name of the schedule").values(T2R.schedule_names()))
                        .process(function(o) {
                            if o.npc_id == undefined {
                                error("NPC_ID was not defined! Don't crash the game!");
                                return;
                            }

                            var npc = string_to_npc_id(o.npc_id);

                            if o.schedule_name == undefined {
                                o.schedule_name = T2R.request_schedule(npc);
                            } else {
                                var found_schedule = T2R.fuzzy_search_schedule(string_to_npc_id(o.npc_id), o.schedule_name);
                                if found_schedule == undefined {
                                    BUGGER.cli.post(format("`{}` didn't match any conversations", found_schedule));
                                    return;
                                } else {
                                    o.schedule_name = found_schedule;
                                }
                            }

                            NPCS[npc].schedule_name = o.schedule_name;
                            var output = T2R.schedule_start(npc, o.schedule_name);
                            trace("output = {}", output);
                        })
                )
                .subcommand(
                    BuggerCommand("list_all")
                        .help("Prints ALL conversations by an NPC, sorted.")
                        .arg(BuggerArgument("npc_id").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .process(function(o) {
                            if o.npc_id == undefined {
                                error("NPC_ID was not defined! Don't crash the game!");
                                return;
                            }
                            var npc_id = npc_id_to_string(string_to_npc_id(o.npc_id));
                            t2_list_conversations(npc_id, false);
                            BUGGER.cli.echo("-printed to terminal");
                        })
                )
                .subcommand(
                    BuggerCommand("list_valid")
                        .help("Prints CURRENTLY VALID conversations by an NPC, in RANDOM order.")
                        .arg(BuggerArgument("npc_id").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .process(function(o) {
                            if o.npc_id == undefined {
                                error("NPC_ID was not defined! Don't crash the game!");
                                return;
                            }
                            var npc_id = npc_id_to_string(string_to_npc_id(o.npc_id));
                            t2_list_conversations(npc_id, true);
                            BUGGER.cli.echo("-printed to terminal");
                        })
                )
                .subcommand(
                    BuggerCommand("can_talk")
                        .help("Mark an NPC as able to talk")
                        .arg(BuggerArgument("npc_id").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .process(function(o) {
                            if o.npc_id == undefined {
                                error("NPC_ID was not defined! Don't crash the game!");
                                return;
                            }

                            //
                            var npc_id = string_to_npc_id(o.npc_id);
                            process_t2_action(T2Action.CanTalk(npc_id), npc_id);
                        })
                )
                .subcommand(
                    BuggerCommand("converse_all")
                        .help("Zips you around the world to talk to everyone.")
                        .process(function() {
                            var chain = new_chain();
                            for (var i = 0; i < NpcId.LEN; i++) {
                                var npc = NPCS[i];
                                if npc.talk_flag {
                                    chain
                                        .append(LinkId.Function, function(npc) {
                                            BUGGER.execute_command(fmt("t2 converse {}", npc_id_to_string(npc)));
                                        }, [i])
                                        .append(LinkId.Timer, 2)
                                        .append(LinkId.Await, function() {
                                            return ANCHOR.get_menu(Menu.Textbox) == undefined;
                                        })
                                }
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("can_gift")
                        .help("Mark an NPC as able to talk")
                        .arg(BuggerArgument("npc_id").help("The name of the npc").values(get_all_keys(NpcId.LEN, npc_id_to_string)))
                        .process(function(o) {
                            if o.npc_id == undefined {
                                error("NPC_ID was not defined! Don't crash the game!");
                                return;
                            }

                            //
                            var npc_id = string_to_npc_id(o.npc_id);
                            NPCS[npc_id].gift_flag = true;
                        })
                )
                .subcommand(
                    BuggerCommand("write")
                        .arg(BuggerArgument("wf_name").values(T2R.world_fact_names()))
                        .arg(BuggerArgument("wf_value"))
                        .process(function(o) {
                            var wf_value = undefined;
                            try {
                                wf_value = real(o.wf_value);
                            } catch(_) {
                                if o.wf_value != undefined {
                                    if o.wf_value == "true" {
                                        wf_value = 1.0;
                                    } else if o.wf_value == "false" {
                                        wf_value = 0.0;
                                    } else {
                                        wf_value = o.wf_value;
                                    }
                                }
                            }

                            T2R.write(o.wf_name, wf_value);
                            BUGGER.cli.post(format("`{}` set to `{}`", o.wf_name, wf_value));
                        })
                )
                .subcommand(
                    BuggerCommand("read")
                        .arg(BuggerArgument("wf_name").values(T2R.world_fact_names()))
                        .process(function(o) {
                            var wf = T2R.read(o.wf_name);
                            BUGGER.cli.echo("`{}` is `{}`", o.wf_name, wf);
                        })
                )
                .subcommand(
                    BuggerCommand("world")
                        .process(function() {
                            var world = T2R.read_world();
                            BUGGER.cli.echo("{JSON}", world);
                        })
                )
        )
        .add_command(
            BuggerCommand("pathfind")
                .author("j")
                .subcommand(
                    BuggerCommand("cost")
                        .help("shows the `cost` of each cell")
                        .process(function() {
                            obj_cosmic_debug.show_pathfind = !obj_cosmic_debug.show_pathfind;
                        })
                )
                .subcommand(
                    BuggerCommand("collision")
                        .process(function() {
                            obj_cosmic_debug.show_pathfind_collision = !obj_cosmic_debug.show_pathfind_collision;
                        })
                )
                .subcommand(
                    BuggerCommand("path")
                        .process(function() {
                            obj_cosmic_debug.show_pathfind_paths = !obj_cosmic_debug.show_pathfind_paths;
                            BUGGER.cli.post(format("Showing paths: {bool}", obj_cosmic_debug.show_pathfind_paths));
                        })
                )
        )
        .add_command(
            BuggerCommand("grid")
                .author("jack")
                .subcommand(
                    BuggerCommand("collision")
                        .help("shows all collisions and helpfully demolishes the frame rate")
                        .process(function() {
                            obj_cosmic_debug.show_collisions = !obj_cosmic_debug.show_collisions;
                        })
                )
                .subcommand(
                    BuggerCommand("static_collision")
                        .help("shows the static collision data")
                        .process(function() {
                            obj_cosmic_debug.show_static_collisions = !obj_cosmic_debug.show_static_collisions;
                        })
                )
                .subcommand(
                    BuggerCommand("objects")
                        .help("shows all objects and helpfully demolishes the frame rate")
                        .process(function() {
                            obj_cosmic_debug.show_objects = !obj_cosmic_debug.show_objects;
                        })
                )
                .subcommand(
                    BuggerCommand("rugs")
                        .help("shows all rugs")
                        .process(function() {
                            obj_cosmic_debug.show_rugs = !obj_cosmic_debug.show_rugs;
                        })
                )
                .subcommand(
                    BuggerCommand("child_objects")
                        .help("shows all objects and helpfully demolishes the frame rate")
                        .process(function() {
                            obj_cosmic_debug.show_objects_sub_layer = !obj_cosmic_debug.show_objects_sub_layer;
                        })
                )
                .subcommand(
                    BuggerCommand("name")
                        .help("shows the object name your mouse hovers over")
                        .process(function() {
                            obj_cosmic_debug.names = !obj_cosmic_debug.names;
                        })
                )
                .subcommand(
                    BuggerCommand("describe")
                        .help("describes what you hover in the log")
                        .process(function() {
                            obj_cosmic_debug.describe = !obj_cosmic_debug.describe;
                        })
                )
                .subcommand(
                    BuggerCommand("terrain")
                        .help("shows all terrain")
                        .process(function() {
                            obj_cosmic_debug.show_terrain = !obj_cosmic_debug.show_terrain;
                        })
                )
                .subcommand(
                    BuggerCommand("footsteps")
                        .help("shows all footsteps")
                        .process(function() {
                            obj_cosmic_debug.show_footsteps = !obj_cosmic_debug.show_footsteps;
                        })
                )
                .subcommand(
                    BuggerCommand("lava")
                        .help("shows all lava")
                        .process(function() {
                            obj_cosmic_debug.show_lava = !obj_cosmic_debug.show_lava;
                        })
                )
                .subcommand(
                    BuggerCommand("activity_positions")
                        .help("shows all activity positions")
                        .process(function() {
                            obj_cosmic_debug.show_activity_positions = !obj_cosmic_debug.show_activity_positions;
                        })
                )
                .subcommand(
                    BuggerCommand("shop_vac")
                        .help("For when you water too much water")
                        .process(function() {
                            var xx = obj_ari.x div 8;
                            var yy = obj_ari.y div 8;
                            var ni = GRID.try_node_index_for_cell(xx, yy);

                            if ni == undefined {
                                return;
                            }

                            if GRID.node_terrain_kind[ni] == TerrainKind.Ground {
                                water_chunk((xx div 2) * 2, (yy div 2) * 2, GRID, false);
                                GRID.update_tilemap_for_node((xx div 2) * 2, (yy div 2) * 2);
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("watered")
                        .help("shows all watering")
                        .process(function() {
                            obj_cosmic_debug.show_watered = !obj_cosmic_debug.show_watered;
                        })
                )
                .subcommand(
                    BuggerCommand("autotile")
                        .help("runs the autotiler!")
                        .process(function() {
                            for (var xx = 0; xx < GRID.dims.x; xx += 2) {
                                for (var yy = 0; yy < GRID.dims.y; yy += 2) {
                                    GRID.auto_tile_tile(xx, yy);
                                }
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("serialize")
                        .help("serialize the grid")
                        .process(function() {
                            create_serialization_data(GRID);
                        })
                )
                .subcommand(
                    BuggerCommand("forageable")
                    .arg(BuggerArgument("object_id").help("The Object to write to.").values(get_all_keys(ObjectId.LEN, object_id_to_string)))
                    .help("for writing forageables specifically")
                    .arg(BuggerArgument("managed").optional())
                    .arg(BuggerArgument("forageable").optional())
                    .arg(BuggerArgument("spawn_grown").optional())
                    .process(function(args) {
                        var object_id = string_to_object_id(args.object_id);
                        var ctx = CropFlag.EMPTY;

                        if args.managed {
                            ctx |= CropFlag.MANAGED
                        }
                        if args.forageable {
                            ctx |= CropFlag.FORAGEABLE
                        }
                        if args.spawn_grown {
                            ctx |= CropFlag.SPAWN_GROWN
                        }

                        var xx = obj_ari.x div 8;
                        var yy = obj_ari.y div 8;

                        var node = GRID.write_node(xx, yy, object_id, ctx);

                        if node == undefined {
                            error("couldn't write {object_id} correctly!", object_id);
                        } else {
                            trace("successfully wrote {object_id} to {}x{}", object_id, obj_ari.x div 8, obj_ari.y div 8);
                        }
                    })
                )
                .subcommand(
                    BuggerCommand("write")
                        .help("writes a thing!")
                        .arg(BuggerArgument("object_id").help("The Object to write to.").values(get_all_keys(ObjectId.LEN, object_id_to_string)))
                        .arg(BuggerArgument("ctx").help("Context sensitive value for object ids").values(["east", "south", "west", "north", "crop", "forageable", "npc_crop"]).optional(undefined))
                        .arg(BuggerArgument("age").help("Amount of times to run new_day on the object").optional(0))
                        .process(function(args) {
                            var object_id = string_to_object_id(args.object_id);
                            var ctx = undefined;
                            var cat = object_id_to_object_category(object_id);
                            var xx = obj_ari.x div 8;
                            var yy = obj_ari.y div 8;
                            switch cat {
                                case ObjectCategory.Crop:
                                    ctx = CropFlag.FORAGEABLE | CropFlag.SPAWN_GROWN;
                                    break;
                                case ObjectCategory.Furniture:
                                    ctx = string_to_cardinal(args.ctx);
                                    break;
                                case ObjectCategory.Tree:
                                    xx -= 2;
                                    yy -= 2;
                                    break;
                                default:
                                    break;
                            }

                            var node = GRID.write_node(xx, yy, object_id, ctx);

                            if node == undefined {
                                error("couldn't write {object_id} correctly!", object_id);
                            } else {
                                //
                                for (var i = 0; i < args.age; i++) {
                                    if cat == ObjectCategory.Crop {
                                        crop_node_new_day(GRID, node);
                                    } else if cat == ObjectCategory.Tree {
                                        tree_node_new_day(GRID, node);
                                    }
                                }

                                if matches(cat, ObjectCategory.Tree, ObjectCategory.Breakable, ObjectCategory.Grass, ObjectCategory.Rock)
                                    && args.ctx != undefined
                                {
                                    node.variant_idx = real(args.ctx);

                                    instance_destroy(node.renderer);
                                    GRID.initialize_node_renderer(node);
                                }

                                trace("successfully wrote {object_id} to {}x{}", object_id, obj_ari.x div 8, obj_ari.y div 8);
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("erase")
                        .help("erases a node which you are pointing at")
                        .process(function() {
                            var ni = GRID.try_node_index_for_room_position(mouse_x(), mouse_y());
                            var success = false;
                            if ni != undefined {
                                if erase_object_node(GRID, ni) {
                                    BUGGER.cli.echo("Erased an Object at {}x{}", mouse_x() div 8, mouse_y() div 8);
                                    success = true;
                                }
                                if erase_rug_node(GRID, ni) {
                                    BUGGER.cli.echo("Erased a Rug at {}x{}", mouse_x() div 8, mouse_y() div 8);
                                    success = true;
                                }
                            }

                            if success == false {
                                BUGGER.cli.echo("Nothing to erase at {}x{}", mouse_x() div 8, mouse_y() div 8);
                            }
                        })
                )
        )
        .add_command(BuggerCommand("spawn_menu")
            .author("gabe")
            .help("Spawns the menu with the given name.")
            .arg(BuggerArgument("menu").values(get_all_keys(Menu.LEN, menu_to_string)))
            .arg(BuggerArgument("extra").optional())
            .process(function(args) {
                switch args.menu {
                    case "blacksmithing":
                        spawn_crafting_menu(BLACKSMITHING_UI_DATA);
                        break;
                    case "dragon_forging":
                        spawn_crafting_menu(DRAGON_FORGING_UI_DATA);
                        break;
                    case "cooking":
                        var menu = spawn_crafting_menu(COOKING_UI_DATA, obj_ari.x, obj_ari.y, ObjectId.AdeptKitchen);
                        menu.object_coordinates.x = obj_ari.x;
                        menu.object_coordinates.y = obj_ari.y;
                        break;
                    case "milling":
                        spawn_crafting_menu(MILLING_UI_DATA);
                        break;
                    case "request_board":
                        spawn_request_board_menu();
                        break;
                    case "tali_challenge_board":
                        spawn_tali_challenge_menu();
                        break;
                    case "woodcrafting":
                        var menu = spawn_crafting_menu(WOODCRAFTING_UI_DATA);
                        menu.object_coordinates.x = obj_ari.x;
                        menu.object_coordinates.y = obj_ari.y;
                        break;
                    case "refining":
                        spawn_crafting_menu(REFINING_UI_DATA);
                        break;
                    case "store":
                        ANCHOR.spawn_menu(Menu.Store, string_to_store(args.extra));
                        break;
                    case "dragon_shrine":
                        var variant = string_to_shrine_menu_variant(args.extra ?? "caldarus");
                        ANCHOR.spawn_menu(Menu.DragonShrine, variant);
                        break;
                    case "ryis_store":
                        var inst = instance_create_depth(0, 0, 0, obj_ryis_store);
                        inst.spawn_menu();
                        instance_destroy(inst);
                        break;
                    case "new_item_popup":
                        new_item_popup(string_to_item_id(args.extra));
                        break;
                    case "museum_donation":
                        spawn_museum_donation_menu();
                        break;
                    case "calendar":
                        spawn_calendar_ui(CALENDAR.time)
                            .with_today(CALENDAR.time)
                            .build();
                        break;
                    default:
                        var menu = string_to_menu(args.menu);
                        ANCHOR.spawn_menu(menu, true, true);
                        break;
                }
            })
        )
        .add_command(
            BuggerCommand("dungeon")
                .author("gabe")
                .process(function () {
                    if is_dungeon_room(room()) {
                        DUNGEON_RUNNER.proceed("cheater");
                    } else {
                        enter_dungeon();
                    }
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
                //
                //
                //
                //
                //
                //
                //
                //
                .subcommand(
                    BuggerCommand("enter")
                        .help("shortcut for entering the mines dungeon")
                        .process(function() {
                            enter_dungeon();
                        })
                )
                .subcommand(
                    BuggerCommand("goto")
                        .help("teleport to a specific mining room, supply the room name, and OPTIONALLY the type")
                        .arg(BuggerArgument("room").help("The gm room to go to (without `rm_mines_`)").values(get_all_mines_room_names()))
                        .arg(BuggerArgument("floor").help("The floor to start on").optional(1))
                        .arg(BuggerArgument("impl").help("The DungeonImpl to use").optional("standard").values(get_all_keys(DungeonImpl.LEN, dungeon_impl_to_string)))
                        .process(function(args) {
                            var room_name = format("rm_mines_{}", args.room);
                            var rm = string_to_asset(room_name);
                            var impl = string_to_dungeon_impl(args.impl);

                            var level_ranges = fiddle_get("dungeons/level_ranges");

                            var flr = real(args.floor);
                            if level_ranges[$ room_name] == undefined {
                                flr = clamp(flr, 1, MAX_DUNGEON_FLOOR);
                            } else {
                                var level_range = level_ranges[$ room_name];
                                flr = clamp(flr, level_range[0], level_range[1]);
                            }

                            var overrides = fiddle_get("dungeons/level_overrides");
                            if overrides[$ room_name] != undefined {
                                flr = overrides[$ room_name];
                            }
                            flr -= 1;
                            var itinerary = create_dungeon_itinerary();
                            itinerary.get(flr).impl = impl;
                            itinerary.get(flr).gm_room = rm;
                            DUNGEON_RUNNER = new DungeonRunner(itinerary, flr);
                            goto_gm_room(rm, true);
                        })
                )
                .subcommand(BuggerCommand("proceed")
                    .help("Proceeds to the next level of the dungeon.")
                    .process(function() {
                        DUNGEON_RUNNER.proceed("cheater");
                    })
                )
                .subcommand(BuggerCommand("spawn_ladder")
                    .help("Spawns a ladder in this dungeon room near Ari.")
                    .process(function() {
                        DUNGEON_RUNNER.spawn_ladder(obj_ari.x div 8, obj_ari.y div 8);
                    })
                )
                .subcommand(
                    BuggerCommand("chance_overlay")
                        .help("toggles the chance layer overlay")
                        .process(function() {
                            strict_layer_set_visible("Chance", !layer_get_visible("Chance"));
                        })
                )
                .subcommand(
                    BuggerCommand("number_overlay")
                        .help("toggles the number layer overlay")
                        .process(function() {
                            strict_layer_set_visible("Debug Numbers", !layer_get_visible("Debug Numbers"));
                        })
                )
                .subcommand(
                    BuggerCommand("prototype_overlay")
                        .help("toggles the prototype layer overlay")
                        .process(function() {
                            strict_layer_set_visible("Prototype", !layer_get_visible("Prototype"));
                        })
                )
        )
        .add_command(
            BuggerCommand("ranching")
                .author("gabe")
                .subcommand(
                    BuggerCommand("buildings")
                        .help("shows some building positions")
                        .process(function() {
                            obj_cosmic_debug.show_building_points = !obj_cosmic_debug.show_building_points;
                        })
                )
                .subcommand(
                    BuggerCommand("spawn_npa")
                    .help("Spawn a non playable animal (npa)")
                    .arg(BuggerArgument("animal_kind").values(get_all_keys(AnimalKind.LEN, animal_kind_to_string)))
                    .arg(BuggerArgument("sex").values(get_all_keys(Sex.LEN, sex_to_string)))
                    .process(function(args) {
                        var kind = string_to_animal_kind(args.animal_kind);
                        var arr = ANIMAL_PROTOTYPES[kind].variants.keys();

                        var npa = new NonPlayerAnimal(
                            kind,
                            arr[irandom_range(0, array_length(arr) - 1)],
                            string_to_sex(args.sex),
                        );

                        npa.location_position = new LocationPosition(CURRENT_LOCATION_ID, Vec2(obj_ari.x, obj_ari.y));

                        instance_create_layer(
                            obj_ari.x,
                            obj_ari.y,
                            "Instances",
                            obj_npa,
                            {
                                me: npa,
                            }
                        );
                    })
                )
                .subcommand(
                    BuggerCommand("pet_all")
                        .help("Pets all the animals you own.")
                        .process(function() {
                            get_all_animals().for_each(function(animal) {
                                if animal.can_pet() {
                                    animal.pet();
                                }
                            });
                            BUGGER.cli.post("Pet all animals!");
                        })
                )
                .subcommand(
                    BuggerCommand("feed_all")
                        .help("Feeds all the animals you own.")
                        .process(function() {
                            get_all_animals().for_each(function(animal) {
                                animal.feed(ItemId.UltimateHay);
                            });
                            BUGGER.cli.post("Fed all animals!");
                        })
                )
                .subcommand(
                    BuggerCommand("roll_breed")
                        .help("Tests out breeding a bunch of times and prints the results.")
                        .arg(BuggerArgument("animal_kind").values(get_all_keys(AnimalKind.LEN, animal_kind_to_string)))
                        .arg(BuggerArgument("variant_a"))
                        .arg(BuggerArgument("variant_b"))
                        .arg(BuggerArgument("rolls").optional(1))
                        .process(function(args) {
                            var kind = string_to_animal_kind(args.animal_kind);
                            var var_a = ANIMAL_PROTOTYPES[kind].variants.get(args.variant_a);
                            var var_b = ANIMAL_PROTOTYPES[kind].variants.get(args.variant_b);
                            var rolls = List();
                            repeat args.rolls {
                                rolls.push(roll_animal_breeding(
                                    kind,
                                    new PlayerAnimal(kind, args.variant_a, Sex.Female),
                                    new PlayerAnimal(kind, args.variant_b, Sex.Male),
                                ));
                            };
                            var header = format(
                                "## Rolling breeding for {Local} (tier {}) and {Local} (tier {}) ##",
                                var_a.name,
                                var_a.tier,
                                var_b.name,
                                var_b.tier,
                            );

                            var results = rolls
                                .map(function(result) {
                                    var variant = ANIMAL_PROTOTYPES[result.kind].variants.get(result.variant);
                                    return format("{Local} (tier {})", variant.name, variant.tier);
                                })
                                .join("\n");

                            trace("{}\n\n{}", header, results);
                        })
                )
                .subcommand(
                    BuggerCommand("progress")
                        .help("Feeds and pets all animals, then runs a 'new day' for them.")
                        .arg(BuggerArgument("days").help("The number of days to go forward.").optional(1))
                        .process(function(args) {
                            run_debug_animal_progression(args.days);
                            BUGGER.cli.echo("Progressed animals {} times.", args.days);
                        })
                )
                .subcommand(
                    BuggerCommand("unlock_all_variants")
                        .process(function() {
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
                        })
                )
                .subcommand(
                    BuggerCommand("unlock_variant")
                        .arg(BuggerArgument("animal_kind").help("The breed of animal").values(get_all_keys(AnimalKind.LEN, animal_kind_to_string)))
                        .arg(BuggerArgument("variant").help("The variant name of animal"))
                        .process(function(args) {
                            ARI.animal_variant_unlocks[string_to_animal_kind(args.animal_kind)].insert(args.variant);
                        })
                )
                .subcommand(
                    BuggerCommand("spawn")
                        .help("Spawns a free-roaming animal.")
                        .arg(BuggerArgument("kind").help("The breed of animal").values(get_all_keys(AnimalKind.LEN, animal_kind_to_string)))
                        .arg(BuggerArgument("variant").help("The variant of the animal. Defaults to the first one.").optional())
                        .arg(BuggerArgument("sex").help("The sex of the animal. Defaults to female one.").optional("female"))
                        .arg(BuggerArgument("is_baby").help("Whether or not the animal is a baby. Defaults to false.").optional("false"))
                        .arg(BuggerArgument("stable").help("Adds to the farm building with the matching name.").optional())
                        .process(function(args) {
                            var kind = string_to_animal_kind(args.kind);

                            var variant = args.variant != undefined
                                ? args.variant
                                : ANIMAL_PROTOTYPES[kind].variants.keys()[0];

                            var object = undefined;
                            if args.stable != undefined {
                                var building = get_buildings().find(function(building, name) {
                                    return building.name == name;
                                }, args.stable);
                                var animal = new PlayerAnimal(kind, variant, string_to_sex(args.sex ?? Sex.Male));
                                building.stable.register(animal);
                                object = obj_player_animal;
                            } else {
                                var animal = new NonPlayerAnimal(kind, variant, string_to_sex(args.sex ?? Sex.Male));
                                animal.location_position = new LocationPosition(
                                    CURRENT_LOCATION_ID,
                                    Vec2(obj_ari.x, obj_ari.y),
                                    CURRENT_DYN_INDEX,
                                );
                                NON_PLAYER_ANIMALS.push(animal);
                                object = obj_npa;
                            }

                            if !args.is_baby {
                                animal.days_old = 10;
                            }

                            instance_create_layer(
                                animal.location_position.pos.x,
                                animal.location_position.pos.y,
                                "Instances",
                                object,
                                {
                                    me: animal,
                                }
                            );
                        })
                )
                .subcommand(
                    BuggerCommand("create_all")
                        .help("Spawns one of every permutation of animal. Beware.")
                        .process(function() {
                            var c = 0;
                            for (var i = 0; i < AnimalKind.LEN; i++) {
                                var data = ANIMAL_PROTOTYPES[i];
                                var variants = data.variants.keys();
                                for (var j = 0; j < array_length(variants); j++) {
                                    var variant = variants[j];
                                    BUGGER.execute_command(format("ranching spawn {AnimalKind} {} male false", i, variant));
                                    BUGGER.execute_command(format("ranching spawn {AnimalKind} {} female false", i, variant));
                                    BUGGER.execute_command(format("ranching spawn {AnimalKind} {} male true", i, variant));
                                    c += 3;
                                }
                            }
                            BUGGER.cli.echo("Spawned {} animals", c);
                        })
                )
                .subcommand(
                    BuggerCommand("status")
                        .help("Outputs various points of data about your buildings and animals.")
                        .process(function() {
                            var output = "\n";
                            output += "### Ranch Status ###\n\n";
                            output += "# Buildings #\n";
                            output += get_buildings()
                                .filter_map(function(v) {
                                    if v.prototype.player_building_kind == PlayerBuildingKind.Stable {
                                        return v;
                                    } else {
                                        return undefined;
                                    }
                                })
                                .map_to(function(building) {
                                    var title = format(
                                        "[{LocationId} ({int})]",
                                        building.prototype.location_id,
                                        building.dyn_index,
                                    );
                                    var position = format("Position: {}x{}", building.top_left_x, building.top_left_y);
                                    var occupancy = format(
                                        "Occupancy: {}/{}",
                                        building.stable.animals().count(),
                                        building.prototype.max_occupants,
                                    );
                                    return format("{}\n{}\n{}", title, position, occupancy);
                                })
                                .join("\n\n");

                            output += "\n\n# Animals #\n";
                            output += get_all_animals(true)
                                .map_to(function(animal) {
                                    var level = points_to_animal_heart_level(animal.heart_points);
                                    var progress;
                                    if points_at_max_animal_heart_level(animal.heart_points) {
                                        progress = 1;
                                    } else {
                                        var current_points = animal_heart_level_to_points(level);
                                        var target_points = animal_heart_level_to_points(level + 1);
                                        var distance = target_points - current_points;
                                        var measure = animal.heart_points - current_points;
                                        progress = measure / distance;
                                    }
                                    var items = List(
                                        format("[{AnimalKind}]", animal.kind),
                                        format("Name: {}", animal.name),
                                        format("Sex: {Sex}", animal.sex),
                                        format("Variant: {}", animal.variant),
                                        format("Location: {}", animal.location_position),
                                        format("Days Old: {}", animal.days_old),
                                        format("Hearts: {}", level),
                                        format("Heart Progress: {}%", progress * 100),
                                        format(
                                            "Home ID: {}",
                                            animal.stable != undefined
                                                ? animal.stable.building.dyn_index
                                                : "No home"
                                        ),
                                        format("Eaten: {bool}", animal.has_eaten),
                                        format("Pat: {bool}", animal.has_been_pat),
                                        format("Incubating: {bool}", animal.is_incubating),
                                        format("Has Eaten Breeding Treet: {bool}", animal.ate_breeding_treat),
                                        format("Breeding Partner Assigned: {}", animal.breeding_with),
                                        format("WIP Production Days: {}", animal.production_days),
                                    );
                                    return items.join("\n");
                                })
                                .join("\n\n");

                            trace(output);
                            BUGGER.cli.post("Information has been printed on the output.")
                        })
                )
        )
        .add_command(
            BuggerCommand("clock")
                .help("Tools for setting the clock throughout the day.")
                .author("jack")
                .subcommand(
                    BuggerCommand("jump")
                        .help("Jumps the clock forward to the time specified")
                        .arg(
                            BuggerArgument("hour")
                                .help("Sets the current hour. Must be less than 27.")
                        )
                        .arg(
                            BuggerArgument("minute")
                                .help("Sets the current minute. Must be less than 61")
                        )
                        .process(function(_values) {
                            var time = parse_time(_values.hour);
                            if time == undefined {
                                _values.hour = real(_values.hour);
                                _values.minute = real(_values.minute);
                                if CLOCK.hour() >= 12 && _values.hour < 12 {
                                    _values.hour += 12;
                                }

                                time = hours(_values.hour) + minutes(_values.minute);

                                if (time > hours(27)) {
                                    BUGGER.cli.echo("Please do not set any hours above 27. You set {}.", clock_time_to_string(time));
                                    return;
                                }

                                if (CLOCK.time > time) {
                                    BUGGER.cli.echo("We cannot go backwards");
                                    return;
                                }
                            }

                            BUGGER.cli.echo("Jumping to {}", clock_time_to_string(time));
                            CLOCK.jump(time);
                        })
                )
                .subcommand(
                    BuggerCommand("toggle")
                        .help("toggles the clocks tick state. don't mess with it")
                        .process(function() {
                            CLOCK.time_stopped = !CLOCK.time_stopped;
                            BUGGER.cli.echo(format("Clock is ticking? {bool}", !CLOCK.time_stopped));
                        })
                )
                .subcommand(
                    BuggerCommand("show_minutes")
                        .help("shows minutes in the clock widget")
                        .process(function() {
                            SHOW_MINUTES_ON_UI = !SHOW_MINUTES_ON_UI;
                            BUGGER.cli.echo(format("Showing minutes: {bool}", SHOW_MINUTES_ON_UI));
                        })
                )
        )
        .add_command(
            BuggerCommand("goto")
                .help("Teleports you to the given location, trellis point, position, or Npc.")
                .arg(
                    BuggerArgument("name")
                        .help("The name of the location, trellis point, or npc.")
                        .values(get_all_destination_keys())
                )
                .process(function (_my_options) {
                    if TAXI.is_traveling() {
                        BUGGER.cli.post("You are already traveling! Try it again.");
                        return;
                    }
                    var name = string_lower(_my_options.name);
                    var npc = try_string_to_npc_id(name);
                    if npc != undefined {
                        var npc_data = NPCS[npc];
                        if CURRENT_LOCATION_ID == npc_data.location_position.location_id {
                            obj_ari.x = npc_data.location_position.pos.x;
                            obj_ari.y = npc_data.location_position.pos.y;
                            return;
                        } else {
                            goto_location_id(npc_data.location_position.location_id, true);
                            //
                            new_chain()
                                .append(LinkId.Timer, 2)
                                .append(LinkId.Function, function(npc_data) {
                                    obj_ari.x = npc_data.location_position.pos.x;
                                    obj_ari.y = npc_data.location_position.pos.y;
                                }, [npc_data])
                            return;
                        }
                    } else if try_string_to_location_id(name) != undefined {
                        var location_id = string_to_location_id(name);
                        if CURRENT_LOCATION_ID == location_id {
                            BUGGER.cli.post("You're already there!");
                        } else {
                            var floor_target = undefined;
                            switch location_id {
                                case LocationId.WaterSeal:
                                    floor_target = 20;
                                    break;
                                case LocationId.EarthSeal:
                                    floor_target = 40;
                                    break;
                                case LocationId.FireSeal:
                                    floor_target = 60;
                                    break;
                                case LocationId.RuinsSeal:
                                    floor_target = 80;
                                    break;
                                case LocationId.VoidSeal:
                                    floor_target = 80;
                                    new_chain().append(LinkId.Await, function() {
                                        if DUNGEON_RUNNER == undefined || TAXI.is_traveling() {
                                            return false;
                                        }
                                        goto_location_id(LocationId.VoidSeal);
                                        return true;
                                    });
                                    break;
                                case LocationId.PriestessQuarters:
                                    floor_target = 90;
                                    break;
                                case LocationId.SeridiasChamber:
                                    floor_target = 100;
                                    break;
                                default:
                                    goto_location_id(location_id, true);
                                    return;
                            }
                            enter_dungeon(floor_target - 1);
                        }
                    } else if name == "bed" {
                        var pos = player_wake_position();
                        goto_location_id(pos.location_id, true)
                            .set_exact_position(pos.pos.x, pos.pos.y)
                    } else {
                        //
                        var coords = string_split(name, "x");
                        if array_length(coords) > 1 {
                            obj_ari.x = real(coords[0]) * 8;
                            obj_ari.y = real(coords[1]) * 8;
                        } else {
                            try {
                                var pos = trellis_point_location_position(name);
                                goto_location_id(pos.location_id, true).set_exact_position(pos.pos.x, pos.pos.y);
                                return;
                            } catch (e) {
                                BUGGER.cli.post("Location not found!");
                            };
                        }
                    }
                })
        )
        .add_command(
            BuggerCommand("display")
                .help("Various commands to get and set camera information")
                .author("Gabe && Jack")
                .subcommand(
                    BuggerCommand("info")
                        .help("Prints stats about the current display state")
                        .process(function() {
                            var inf = DISPLAY.readout();
                            BUGGER.cli.echo(inf);
                        })
                )
                .subcommand(
                    BuggerCommand("sizes")
                        .help("shows sizes available in window mode on this monitor")
                        .process(function() {
                            trace("{}", DISPLAY.window_sizes());
                            trace("max expansion: {}", DISPLAY.max_expansion_amount());
                            trace("max expansion: {}", DISPLAY.max_expansion_looks_decent());
                        })
                )
                .subcommand(
                    BuggerCommand("fullscreen")
                        .help("Toggles showing fullscreen && saves it to the settings.")
                        .process(function() {
                            if window_is_fullscreen() {
                                DISPLAY.set_windowed(
                                    SETTINGS.get("window_x"),
                                    SETTINGS.get("window_y"),
                                    SETTINGS.get("window_expansion"),
                                );
                                SETTINGS.set("open_fscreen", 0);
                            } else {
                                DISPLAY.set_fullscreen(
                                    SETTINGS.get("fscreen_expansion"),
                                );
                                SETTINGS.set("open_fscreen", 1);
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("size")
                        .help("Set the window size of the Camera")
                        .arg(BuggerArgument("x"))
                        .arg(BuggerArgument("y"))
                        .process(function (_options) {
                            try {
                                var settings = SETTINGS; //
                                DISPLAY.offset_x = 0;
                                DISPLAY.offset_y = 0;
                                if window_is_fullscreen() {
                                    settings.set("fscreen_expansion", 0);

                                    DISPLAY.set_fullscreen(0);
                                } else {
                                    settings.set("window_x", real(_options.x));
                                    settings.set("window_y", real(_options.y));
                                    settings.set("window_expansion", 0);

                                    DISPLAY.set_windowed(real(_options.x), real(_options.y), 0);
                                }
                                save_settings();
                            } catch(e) {
                                error("error: {}", e);
                                BUGGER.cli.echo("Invalid size.");
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("force")
                        .help("Forces a window resizing, to test new calculations.")
                        .arg(BuggerArgument("forced_size"))
                        .process(function (_options) {
                            try {
                                DISPLAY.force_resize = real(_options.forced_size);
                                BUGGER.cli.echo("Force resize has been set to {}", DISPLAY.force_resize);
                            } catch(_) {
                                BUGGER.cli.echo("Force resize has been turned off.");
                                DISPLAY.force_resize = undefined;
                            }

                            DISPLAY.calculate_view_size();
                        })
                )
                .subcommand(
                    BuggerCommand("expansion")
                        .help("Attempts to expand a thing by the thing.")
                        .arg(BuggerArgument("expansion_amount"))
                        .process(function (_options) {
                            try {
                                var expansion_amount = real(_options.expansion_amount);
                                if DISPLAY.set_expansion(expansion_amount) == false {
                                    BUGGER.cli.echo("That expansion amount was too big; please try a smaller amount.");
                                } else {
                                    BUGGER.cli.echo("Expansion amount set to {}", expansion_amount);
                                    if window_is_fullscreen() {
                                        SETTINGS.set("fscreen_expansion", expansion_amount);
                                        DISPLAY.set_fullscreen(DISPLAY.expansion);
                                    } else {
                                        SETTINGS.set("window_expansion", expansion_amount);
                                        var output = window_get_output_dimensions();
                                        DISPLAY.set_windowed(output[0], output[1], DISPLAY.expansion);
                                    }
                                }
                            } catch(_) {
                                BUGGER.cli.echo("Please use a normal number for the expansion amount what's wrong with you");
                                return;
                            }
                        })
                )
        )
        .add_command(
            BuggerCommand("show_room_name")
                .process(function() {
                    obj_cosmic_debug.show_room_name = !obj_cosmic_debug.show_room_name;
                })
        )
        .add_command(
            BuggerCommand("toggle_layer")
                .arg(BuggerArgument("layer_name"))
                .process(function(args) {
                    layer_set_visible(args.layer_name, !layer_get_visible(args.layer_name));
                })
        )
        .add_command(
            BuggerCommand("bomb_radius")
                .process(function() {
                    obj_cosmic_debug.bomb_radius = !obj_cosmic_debug.bomb_radius;
                })
        )
        .add_command(
            BuggerCommand("combat")
                .subcommand(
                    BuggerCommand("spawn")
                        .help("Spawns a monster!")
                        .arg(BuggerArgument("monster").help("The string name of the spell").values(get_all_keys(MonsterId.LEN, monster_id_to_string)))
                        .arg(BuggerArgument("on_mouse").help("If `true` or `1`, then we'll spawn on the mouse position"))
                        .process(function(o) {
                            var xx = mouse_x();
                            var yy = mouse_y();
                            if o.on_mouse != "true" && o.on_mouse != "1" {
                                xx = obj_ari.x;
                                yy = obj_ari.y;
                            }

                            spawn_monster(xx, yy, string_to_monster_id(o.monster));
                        })
                )
                .subcommand(
                    BuggerCommand("god_mode")
                        .help("Makes you invulnerable")
                        .process(function() {
                            obj_ari.god_mode = !obj_ari.god_mode;
                        })
                )
                .subcommand(
                    BuggerCommand("wimp")
                        .help("Makes you bad at doing damage")
                        .process(function() {
                            obj_ari.wimp_mode = !obj_ari.wimp_mode;
                        })
                )
                .subcommand(
                    BuggerCommand("crit")
                        .help("Makes you really good at getting critical")
                        .process(function() {
                            obj_ari.crit = !obj_ari.crit;
                        })
                )
                .subcommand(
                    BuggerCommand("hitbox")
                        .help("Toggles displaying hitboxes, the things which hit.")
                        .process(function() {
                            obj_cosmic_debug.hitbox = !obj_cosmic_debug.hitbox;
                        })
                )
                .subcommand(
                    BuggerCommand("hurtbox")
                        .help("Toggles displaying hurtboxes, the things which hurt.")
                        .process(function() {
                            obj_cosmic_debug.hurtbox = !obj_cosmic_debug.hurtbox;
                        })
                )
                .subcommand(
                    BuggerCommand("collision")
                        .help("Shows the collision boxes")
                        .process(function () {
                            obj_cosmic_debug.enemy_collision = !obj_cosmic_debug.enemy_collision;
                        })
                )
                .subcommand(
                    BuggerCommand("aggro")
                        .help("Toggles displaying aggro boxes for enemies")
                        .process(function() {
                            obj_cosmic_debug.aggro_box = !obj_cosmic_debug.aggro_box;
                        })
                )
                .subcommand(
                    BuggerCommand("state")
                        .help("Toggles displaying states for enemies")
                        .process(function() {
                            obj_cosmic_debug.enemy_state = !obj_cosmic_debug.enemy_state;
                        })
                )
                .subcommand(
                    BuggerCommand("patience")
                        .help("Toggles displaying states for enemies")
                        .process(function() {
                            obj_cosmic_debug.enemy_patience = !obj_cosmic_debug.enemy_patience;
                        })
                )
                .subcommand(
                    BuggerCommand("transform")
                        .help("Toggles displaying transforms for enemies")
                        .process(function() {
                            obj_cosmic_debug.enemy_transform = !obj_cosmic_debug.enemy_transform;
                        })
                )
        )
        .add_command(
            BuggerCommand("interact")
                .help("Interact!!!!!")
                .process(function() {
                    obj_cosmic_debug.draw_interact_boxes = !obj_cosmic_debug.draw_interact_boxes;
                })
        )
        .add_command(
            BuggerCommand("transparency")
                .help("Show transparency detectors")
                .process(function() {
                    obj_cosmic_debug.draw_transparency_detectors = !obj_cosmic_debug.draw_transparency_detectors;
                })
        )
        .add_command(
            BuggerCommand("crash")
            .process(function() {
                for (var i = INTERACTABLES.count() - 1; i >= 0; i--) {
                    var interactable = INTERACTABLES.get(i);
                    trace("Interactable id: {}", interactable);
                    trace("Instance exists: {}", instance_exists(interactable));
                }
            })
        )
        .add_command(
            BuggerCommand("cosmic")
                .help("toggle a key in cosmic debug")
                .arg(
                    BuggerArgument("key")
                        .help("The name")
                        .values(
                            [
                                "tile_selection",
                                "new_tile_indicator",
                                "transform",
                                "names",
                                "obj_transform",
                                "obj_depth_transform",
                            ]
                        )
                )
                .process(function(o) {
                    var name = o.key;
                    obj_cosmic_debug[$ name] = !obj_cosmic_debug[$ name];
                })
        )
        .add_command(
            BuggerCommand("spells")
                .help("Learn and cast spells")
                .subcommand(
                    BuggerCommand("cast")
                        .help("casts a spell")
                        .arg(BuggerArgument("spell").help("The string name of the spell").values(get_all_keys(Spell.LEN, spell_to_string)))
                        .process(function (opts) {
                            obj_ari.fsm.blackboard.set("spell", string_to_spell(opts.spell));
                            obj_ari.fsm.change_state(PlayerState.Spell);
                            BUGGER.cli.echo("Casting {}", opts.spell);
                        })
                )
                .subcommand(
                    BuggerCommand("learn")
                        .help("learn a spell")
                        .arg(BuggerArgument("spell").help("The string name of the spell").values(get_all_keys(Spell.LEN, spell_to_string)))
                        .process(function (opts) {
                            ARI.learn_spell(string_to_spell(opts.spell));
                        })
                )
                .subcommand(
                    BuggerCommand("learn_all")
                        .help("learn all spells")
                        .process(function () {
                            for (var i = 0; i < Spell.LEN; i++) {
                                ARI.learn_spell(i);
                            }
                        })
                )
        )
        .add_command(
            BuggerCommand("mount")
                .arg(BuggerArgument("species").values(get_all_keys(AnimalKind.LEN, animal_kind_to_string)))
                .arg(BuggerArgument("sex").values(get_all_keys(Sex.LEN, sex_to_string)))
                .process(function() {
                    assert_neq(ARI.mount, undefined);
                    obj_ari.fsm.change_state(PlayerState.MountDefault);
                })
        )
        .add_command(
            BuggerCommand("show_instance_bbox")
                .process(function() {
                    obj_cosmic_debug.show_object_cull_ranges = !obj_cosmic_debug.show_object_cull_ranges;
                })
        )
        .add_command(
            BuggerCommand("test")
                .arg(BuggerArgument("value"))
                .process(function(_o) {
                    DISPLAY.gamma = real(_o.value);
                })
        )
        .add_command(
            BuggerCommand("profile_message")
                .arg(BuggerArgument("value").optional())
                .process(function(_o) {
                    profile_message(_o.value ?? "Bugger Message!");
                })
        )
        .add_command(
            BuggerCommand("test_2")
                .arg(BuggerArgument("value"))
                .process(function(_o) {
                    var cache = MIST.blackboard.get("par_asset_cache");
                    if instance_exists(obj_ari) {
                        ARI.animation_assets().assets.for_each(function(asset) {
                            obj_ari.par.remove_asset(asset.name);
                        })
                    }
                    ARI.presets.set(ARI.preset_index_selected, cache);
                    if instance_exists(obj_ari) {
                        obj_ari.par.render_hair = active_preset.should_render_hair();
                        ARI.animation_assets().assets.for_each(function(asset) {
                            obj_ari.par.set_asset(asset.name, asset.lut_index);
                        })
                    }

                })
        )
        .add_command(
            BuggerCommand("minutes_per_day")
                .arg(BuggerArgument("value"))
                .process(function(o) {
                    MINUTES_PER_DAY = real(o.value);
                    BUGGER.cli.echo("A Day will take {} real minutes, and GAME_SECONDS_PER_FRAME = {}", MINUTES_PER_DAY, GAME_SECONDS_PER_FRAME);
                })
        )
        .add_command(
            BuggerCommand("schlep")
                .subcommand(
                    BuggerCommand("export")
                        .help("Exports a schlep batch. Note that this needs the 'schlep_tools' feature enabled!")
                        .arg(BuggerArgument("language_key").help("the shorthand key for the language"))
                        .arg(BuggerArgument("file_name").help("the output filename"))
                        .arg(BuggerArgument("include_missing").help("includes missing keys if set to 1"))
                        .arg(BuggerArgument("include_outdated").help("includes outdated keys if set to 1"))
                        .arg(BuggerArgument("include_unrecognized").help("includes unrecognized keys if set to 1"))
                        .arg(BuggerArgument("include_valid").help("includes valid keys if set to 1"))
                        .process(function(opts) {
                            schlep_export(
                                opts.language_key,
                                opts.file_name,
                                opts.include_missing == "1",
                                opts.include_outdated == "1",
                                opts.include_unrecognized == "1",
                                opts.include_valid == "1",
                            );
                        })
                )
                .subcommand(
                    BuggerCommand("import")
                        .help("Imports a schlep batch. Note that this needs the 'schlep_tools' feature enabled!")
                        .arg(BuggerArgument("language_key").help("the shorthand key for the language"))
                        .arg(BuggerArgument("file_name").help("the input filename"))
                        .process(function(opts) {
                            schlep_import(opts.language_key, opts.file_name);
                        })
                )
                .subcommand(
                    BuggerCommand("triage")
                        .help("Heuristically detects trivial reasons keys are marked as outdated in an attempt to identify those that just need remapping.")
                        .arg(BuggerArgument("language_key").help("the shorthand key for the language"))
                        .arg(BuggerArgument("file_name").help("the output filename for the report"))
                        .process(function(opts) {
                            schlep_triage(opts.language_key, opts.file_name);
                        })
                )
                .subcommand(
                    BuggerCommand("forgive")
                        .help("Takes a triage report and marks the previous_source of its capitalization and whitespace keys as up to date with the current source. Note that this needs the 'schlep_tools' feature enabled!")
                        .arg(BuggerArgument("language_key").help("the shorthand key for the language"))
                        .arg(BuggerArgument("file_name").help("the input filename"))
                        .process(function(opts) {
                            schlep_forgive(opts.language_key, opts.file_name);
                        })
                )
                .subcommand(
                    BuggerCommand("remap")
                        .help("Takes a toml file of key remaps and updates the given language's meta files. Note that this needs the 'schlep_tools' feature enabled!")
                        .arg(BuggerArgument("language_key").help("the shorthand key for the language"))
                        .arg(BuggerArgument("file_name").help("the input filename"))
                        .process(function(opts) {
                            schlep_remap(opts.language_key, opts.file_name);
                        })
                )
        )
        .add_command(
            BuggerCommand("gc")
                .subcommand(
                    BuggerCommand("status")
                    .process(function() {
                        BUGGER.cli.echo("GC is Automatic: {bool}", gc_is_enabled());
                        BUGGER.cli.echo("Memory used: {}gb", MEMORY_USED / 1000000000);
                        BUGGER.cli.echo("Emergency Timer: {}", MEMORY_EMERGENCY_TIMER);
                    })
                )
                .subcommand(
                    BuggerCommand("gc")
                    .process(function() {
                        manual_gc_cycle();
                    })
                )
                .subcommand(
                    BuggerCommand("time")
                        .arg(BuggerArgument("d"))
                        .process(function(o) {
                            gc_target_frame_time(real(o.d));
                            BUGGER.cli.echo("Gc gets {}ms", real(o.d) / 1000);
                        })
                )
        )
        .add_command(
            BuggerCommand("cull")
                .help("Helpers for the culling")
                .author("Jack")
                .subcommand(
                    BuggerCommand("test")
                        .process(function() {
                            var old_camera_size = Vec2(CAMERA.view_width, CAMERA.view_height);

                            //
                            DISPLAY.force_resize = 1;
                            DISPLAY.calculate_view_size();

                            //
                            CAMERA.cull_offset_x = (CAMERA.view_width - old_camera_size.x) / 2;
                            CAMERA.cull_offset_y = (CAMERA.view_height - old_camera_size.y) / 2;
                            CAMERA.cull_width = old_camera_size.x;
                            CAMERA.cull_height = old_camera_size.y;
                            CAMERA.room_view_bound_width = 100000;
                            CAMERA.room_view_bound_height = 1000000;
                            CAMERA.x_buffer = -100000;
                            CAMERA.y_buffer = -100000;

                            obj_cosmic_debug.show_camera_range = true;
                            obj_cosmic_debug.show_cull_range = true;
                            obj_cosmic_debug.show_object_cull_ranges = true;
                            obj_cosmic_debug.show_shadow_chunks = true;
                            obj_cosmic_debug.show_activated_shadow_chunks = true;
                        })
                )
                .subcommand(
                    BuggerCommand("set")
                        .arg(BuggerArgument("x_off"))
                        .arg(BuggerArgument("y_off"))
                        .arg(BuggerArgument("width"))
                        .arg(BuggerArgument("height"))
                        .process(function(o) {
                            CAMERA.cull_offset_x = real(o.x_off);
                            CAMERA.cull_offset_y = real(o.y_off);
                            CAMERA.cull_width = real(o.width);
                            CAMERA.cull_height = real(o.height);
                        })
                )
                .subcommand(
                    BuggerCommand("reset")
                        .process(function() {
                            CAMERA.cull_width = CAMERA.view_width;
                            CAMERA.cull_height = CAMERA.view_height;
                            CAMERA.cull_offset_x = 0;
                            CAMERA.cull_offset_y = 0;

                            CAMERA.room_view_bound_width = room_width();
                            CAMERA.room_view_bound_height = room_height();

                            if room() == rm_farm {
                                CAMERA.room_view_bound_width = 1504;
                                CAMERA.room_view_bound_height = 1136;
                            }

                            var cam_info = fiddle_get("camera");
                            CAMERA.x_buffer = cam_info.x_buffer;
                            CAMERA.y_buffer = cam_info.y_buffer;

                            obj_cosmic_debug.show_camera_range = false;
                            obj_cosmic_debug.show_cull_range = false;
                            obj_cosmic_debug.show_object_cull_ranges = false;
                            obj_cosmic_debug.show_shadow_chunks = false;
                            obj_cosmic_debug.show_activated_shadow_chunks = false;
                        })
                )
        )
        .add_command(
            BuggerCommand("camera")
                .help("Change how the Camera moves and what not")
                .author("Jack")
                .subcommand(
                    BuggerCommand("cull")
                        .arg(BuggerArgument("x_off"))
                        .arg(BuggerArgument("y_off"))
                        .arg(BuggerArgument("width"))
                        .arg(BuggerArgument("height"))
                        .process(function(o) {
                            CAMERA.cull_offset_x = real(o.x_off);
                            CAMERA.cull_offset_y = real(o.y_off);
                            CAMERA.cull_width = real(o.width);
                            CAMERA.cull_height = real(o.height);
                        })
                )
                .subcommand(
                    BuggerCommand("cull_reset")
                        .process(function() {
                            CAMERA.cull_width = CAMERA.view_width;
                            CAMERA.cull_height = CAMERA.view_height;
                        })
                )
                .subcommand(
                    BuggerCommand("detach")
                        .help("shows sizes available in window mode on this monitor")
                        .process(function() {
                            CAMERA.follow_point(obj_ari.x, obj_ari.y);
                        })
                )
                .subcommand(
                    BuggerCommand("attach")
                        .help("shows sizes available in window mode on this monitor")
                        .process(function() {
                            CAMERA.follow_instance(obj_ari);
                        })
                )
                .subcommand(
                    BuggerCommand("center_room")
                        .arg(BuggerArgument("x_offset"))
                        .arg(BuggerArgument("y_offset"))
                        .process(function(o) {
                            var xx = room_width() / 2;
                            var yy = room_height() / 2;

                            CAMERA.follow_point(xx + (o[$ "x_offset"] ?? 0), yy + (o[$ "y_offset"] ?? 0));
                        })
                )
                .subcommand(
                    BuggerCommand("status")
                        .process(function() {
                            trace("Camera Position: {} / internal_pos: {}", CAMERA.cam_pos, CAMERA.internal_cam_pos);
                            trace("Tracking towards: {}x{}", CAMERA.target_x - CAMERA.view_width / 2, CAMERA.target_y - CAMERA.view_height / 2);
                        })
                )
                .subcommand(
                    BuggerCommand("set_trauma")
                        .help("Checks what mode the camera is in, and other info.")
                        .arg(
                            BuggerArgument("trauma")
                                .help("The amount of trauma to give")
                        )
                        .process(function (o) {
                            CAMERA.add_trauma(real(o.trauma), 1.0);

                            BUGGER.cli.echo("Set Camera Trauma to {}", o.trauma);
                        })
                )
                .subcommand(
                    BuggerCommand("set_trauma_param")
                        .help("Sets the trauma MaxOffset parameters.")
                        .arg(
                            BuggerArgument("x_offset")
                                .help("The x_offset of trauma to give")
                        )
                        .arg(
                            BuggerArgument("y_offset")
                                .help("The y_offset of trauma to give")
                        )
                        .process(function (o) {
                            CAMERA.max_offset.x = real(o.x_offset);
                            CAMERA.max_offset.y = real(o.y_offset);

                            BUGGER.cli.echo("Set Camera Max Offset to {}", CAMERA.max_offset);
                        })
                )
        )
        .add_command(
            BuggerCommand("pet")
                .help("Pet data")
                .author("Jack")
                .subcommand(
                    BuggerCommand("status")
                        .process(function() {
                            if PET.unlocked() == false {
                                BUGGER.cli.echo("Pet is not unlocked!");
                                return;
                            }

                            BUGGER.cli.echo("{}: {PetKind}, {PetManagement}, {LocationId}, {PetJob}, Active: {bool}", PET.name, PET.pet_kind(), PET.management, PET.location_id, PET.job, PET.job_active);
                            if instance_exists(obj_pet) {
                                BUGGER.cli.echo("{PetState} at {}x{}, deferred_job_active: {}", obj_pet.fsm.current_state_id(), obj_pet.x, obj_pet.y, obj_pet.deferred_job_active_status);
                            }

                            for (var i = 0; i < PetKind.LEN; i++) {
                                BUGGER.cli.echo("Cosmetics available for {PetKind}: {}", i, pet_cosmetics_available(i, ARI.pet_cosmetic_sets_unlocked));
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("unlock")
                        .process(function() {
                            MIST.scene_history.insert("pet_arrival");
                            BUGGER.cli.echo("Pet is unlocked!");
                        })
                )
                .subcommand(
                    BuggerCommand("unlock_cosmetic_set")
                        .arg(BuggerArgument("cosmetic_set").help("the cosmetic set to unlock").values(PET_PROTOTYPE.cosmetic_sets.keys()))
                        .process(function(o) {
                            if PET_PROTOTYPE.cosmetic_sets.contains_key(o.cosmetic_set) == false {
                                BUGGER.cli.echo("{} is not a valid set name!", o.cosmetic_set);
                                return;
                            }
                            array_push(ARI.pet_cosmetic_sets_unlocked, o.cosmetic_set);
                        })
                )
                .subcommand(
                    BuggerCommand("where")
                        .process(function() {
                            if PET.unlocked() {
                                if instance_exists(obj_pet) {
                                    BUGGER.cli.echo("{LocationId} - {}x{}", PET.location_id, obj_pet.x, obj_pet.y);
                                } else {
                                    BUGGER.cli.echo("{LocationId}", PET.location_id);
                                }
                            } else {
                                BUGGER.cli.echo("Pet is not available!");
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("variant")
                        .arg(BuggerArgument("variant").help("the variant to set").values(PET_PROTOTYPE.variants.keys()))
                        .process(function(o) {
                            if PET.unlocked() {
                                //
                                //
                                PET.variant = o.variant;
                                PET.cosmetic = undefined;
                                if instance_exists(obj_pet) {
                                    obj_pet.on_alteration();
                                }
                            } else {
                                BUGGER.cli.echo("Pet is not available!");
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("cosmetic")
                        .arg(BuggerArgument("cosmetic").help("the cosmetic to set").values(PET_PROTOTYPE.cosmetics.keys()))
                        .process(function(o) {
                            if PET.unlocked() {
                                var cosmetic = PET_PROTOTYPE.cosmetics.get(o.cosmetic);
                                if cosmetic == undefined {
                                    BUGGER.cli.echo("That cosmetic doesn't exist!");
                                    return;
                                }
                                if cosmetic.pet_kind == PET.pet_kind() {
                                    PET.cosmetic = o.cosmetic;
                                    if instance_exists(obj_pet) {
                                        obj_pet.on_alteration();
                                    }
                                } else {
                                    BUGGER.cli.echo("Cosmetic `{}` requires {PetKind}, but the Pet is current a {PetKind}", o.cosmetic, cosmetic.pet_kind, PET.pet_kind());
                                }
                            } else {
                                BUGGER.cli.echo("Pet is not available!");
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("job")
                        .arg(BuggerArgument("job").help("the job to set").values(get_all_keys(PetJob.LEN, pet_job_to_string)))
                        .process(function(o) {
                            if PET.unlocked() {
                                var job = try_string_to_pet_job(o.job);
                                if job == undefined {
                                    BUGGER.cli.echo("That job doesn't exist!");
                                    return;
                                }

                                if PET.job == job {
                                    BUGGER.cli.echo("That's already their job!");
                                    return;
                                }

                                if PET.job_active {
                                    if instance_exists(obj_pet) {
                                        instance_destroy(obj_pet);
                                    }
                                    PET.job = job;
                                    PET.location_id = location_for_job(PET.job);
                                    PET.job_active = true;
                                    BUGGER.cli.echo("Pet has switched to {PetJob}!", PET.job);
                                } else {
                                    PET.job = job;
                                    BUGGER.cli.echo("Pet will switch to {PetJob} tomorrow!");
                                }
                            } else {
                                BUGGER.cli.echo("Pet is not available!");
                            }
                        })
                )
        )
        .add_command(
            BuggerCommand("system")
                .help("Low level general system commands")
                .author("Gabe")
                .subcommand(
                    BuggerCommand("crash")
                        .help("Crashes the game to test crash reporting features")
                        .process(function () {
                            obj_cosmic_debug.trigger_crash = "testing crash";
                        })
                )
                .subcommand(
                    BuggerCommand("collect_cycle")
                        .process(function() {
                            gc_collect();
                            MEMORY_USED = undefined;
                        })
                )
                .subcommand(
                    BuggerCommand("resource_counts")
                        .help("Prints all resource counts")
                        .process(function () {
                            BUGGER.cli.echo("{}", debug_event("ResourceCounts", true));
                        })
                )
                .subcommand(
                    BuggerCommand("mem_dump")
                        .help("Prints all memory information gm has")
                        .process(function () {
                            var mem_info = debug_event("DumpMemory", true);
                            BUGGER.cli.echo("allocated {}gb (free: {}gb)", mem_info.totalUsed / 1000000000, mem_info.free / 1000000000);
                        })
                )
                .subcommand(
                    BuggerCommand("debug_overlay")
                        .help("Shows or hides the gm provided debug overlay")
                        .process(function () {
                            show_debug_overlay(!is_debug_overlay_open(), true);
                        })
                )
                .subcommand(
                    BuggerCommand("gc_enable")
                        .help("Enable GMS's garbage collector")
                        .process(function () {
                            gc_enable(true);
                        })
                )
                .subcommand(
                    BuggerCommand("gc_disable")
                        .help("Disable GMS's garbage collector")
                        .process(function () {
                            gc_enable(false);
                        })
                )
                .subcommand(
                    BuggerCommand("gc_collect")
                        .process(function () {
                            gc_collect();
                        })
                )
                .subcommand(
                    BuggerCommand("gc_info")
                        .help("Prints information about the garbage collector's status")
                        .process(function () {
                            var _info = gc_get_stats();
                            BUGGER.cli.post(fmt("Objects Touched: {}", _info.objects_touched));
                            BUGGER.cli.post(
                                fmt("Objects Collected: {}", _info.objects_collected)
                            );
                            BUGGER.cli.post(fmt("Traversal Time: {}", _info.traversal_time));
                            BUGGER.cli.post(fmt("Collection Time: {}", _info.collection_time));
                            BUGGER.cli.post(fmt("GC Frame: {}", _info.gc_frame));
                            BUGGER.cli.post(
                                fmt("Generation Collected: {}", _info.generation_collected)
                            );
                            BUGGER.cli.post(
                                fmt("Number of Generations: {}", _info.num_generations)
                            );
                            for (var i = 0; i < _info.num_generations; i++) {
                                BUGGER.cli.post(
                                    fmt(
                                        "Objects In Generation {}: {}",
                                        string(i),
                                        _info.num_objects_in_generation[i]
                                    )
                                );
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("mem_info")
                        .help("Prints information about current dynamic memory resources.")
                        .process(function () {
                            static COUNT = function(ds_type) {
                                var n = 0;
                                for (var i = 0; i < 9999; i++) {
                                    n += ds_exists(i, ds_type);
                                }
                                return n;
                            }

                            BUGGER.cli.echo("Lists: {}", COUNT(ds_type_list));
                            BUGGER.cli.echo("Maps: {}", COUNT(ds_type_map));
                            BUGGER.cli.echo("Queues: {}", COUNT(ds_type_queue));
                            BUGGER.cli.echo("Prio Queues: {}", COUNT(ds_type_priority));
                            BUGGER.cli.echo("Stacks: {}", COUNT(ds_type_stack));
                            BUGGER.cli.echo("Chains: {}", array_length(CHAINS.chains));
                        })
                )
        )
        .add_command(BuggerCommand("artifact")
            .subcommand(BuggerCommand("roll")
                .process(function() {
                    var output = ARCHAEOLOGY.choose_random_artifact();
                    BUGGER.cli.echo("Chose {ItemId}", output);
                })
            )
            .subcommand(BuggerCommand("monte_carlo")
                .arg(BuggerArgument("json").help("if true, will print in JSON").optional(false))
                .process(function(args) {
                    var print_json = bool(args.json);

                    var o = {};
                    var total = 0;
                    repeat 50000 {
                        var winner = ARCHAEOLOGY.choose_random_artifact();
                        ARI.active_pursuit = false;
                        if ARI.perks[Perk.Pursuit] && matches(winner, ItemId.Sod, ItemId.Peat, ItemId.Clay, ItemId.Shards, ItemId.ShardMass) {
                            ARI.active_pursuit = true;
                        }
                        var winner_str = item_id_to_string(winner);

                        if o[$ winner_str] == undefined {
                            o[$ winner_str] = 0;
                        }

                        o[$ winner_str] += 1;
                        total += 1;
                    }
                    var keys = struct_get_names(o);
                    var o2 = {};
                    for (var i = 0; i < array_length(keys); i++) {
                        var key = keys[i];

                        o2[$ key] = format("{}%", (o[$ key] / total) * 100.0);

                        if print_json == false {
                            BUGGER.cli.echo("{}. {} {}, {}", i + 1, key, o[$ key], o2[$ key]);
                        }
                    }

                    if print_json {
                        BUGGER.cli.echo("{json}", { raw: o, percent: o2 });
                    }
                })
            )
            .subcommand(BuggerCommand("pursuit")
                .process(function() {
                    ARI.active_pursuit = true;

                    var table = ARCHAEOLOGY.location_loot_tables[CURRENT_LOCATION_ID].get_candidate_votes_at_cell(
                        GRID,
                        0,
                        0
                    );
                    for (var i = 0; i < table.votes.candidates.count(); i++) {
                        var candidate = table.votes.candidates.get(i);
                        BUGGER.cli.echo("{}. {ItemId} = {}", i, candidate.candidate_id, candidate.votes);
                    }

                    ARI.active_pursuit = false;
                    var table = ARCHAEOLOGY.location_loot_tables[CURRENT_LOCATION_ID].get_candidate_votes_at_cell(
                        GRID,
                        0,
                        0
                    );
                    for (var i = 0; i < table.votes.candidates.count(); i++) {
                        var candidate = table.votes.candidates.get(i);
                        BUGGER.cli.echo("{}. {ItemId} = {}", i, candidate.candidate_id, candidate.votes);
                    }               })
            )
        )
        .add_command(BuggerCommand("fish")
            .subcommand(BuggerCommand("reset")
                .process(function() {
                    with obj_fishy {
                        instance_destroy();
                    }
                    with obj_fish_school {
                        instance_destroy();
                    }
                    with obj_divespot {
                        instance_destroy();
                    }
                    //
                    with obj_fish_spawner {
                        object_event(object("obj_fish_spawner"), ObjectEvent.Create)();
                    }
                    setup_all_fish_spawners();
                })
            )
            .subcommand(BuggerCommand("nameplate")
                .process(function() {
                    FISH_SHOULD_DRAW_NAME = !FISH_SHOULD_DRAW_NAME;
                    BUGGER.cli.echo("FISH_SHOULD_DRAW_NAME set to {bool}", FISH_SHOULD_DRAW_NAME);
                })
            )
            .subcommand(BuggerCommand("show_spawners")
                .process(function() {
                    var vis = false;
                    with obj_fish_spawner {
                        visible = !visible;
                        vis = visible;
                    }
                    if layer_exists("Meta") {
                        strict_layer_set_visible("Meta", vis);
                    }
                    if layer_exists("FishSpawners") {
                        strict_layer_set_visible("FishSpawners", vis);
                    }
                    BUGGER.cli.echo("spawner_visibility set to {bool}", vis);
                })
            )
            .subcommand(BuggerCommand("votes")
                .arg(BuggerArgument("spawn_kind").help("the spawn kind").values(get_all_keys(FishSpawn.LEN, fish_spawn_to_string)))
                .arg(BuggerArgument("fish_size").help("the fish size to spawn").values(get_all_keys(FishSize.LEN, fish_size_to_string)))
                .process(function(args) {
                    var inst = overlap_point(mouse_x(), mouse_y(), obj_fish_spawner);
                    if inst == undefined {
                        BUGGER.cli.echo("failed to find a spawner at mouse position!");
                        return;
                    }
                    var spawn_kind = string_to_fish_spawn(args.spawn_kind);
                    var fish_size;
                    if spawn_kind != FishSpawn.Divespot {
                        fish_size = string_to_fish_size(args.fish_size);
                    }  else {
                        fish_size = undefined;
                    }
                    var spawn_output = populate_fish(spawn_kind, fish_size, inst.water_kind, inst.x, inst.y);

                    BUGGER.cli.echo("Votes for {WaterType}, {FishSpawn}, {FishSize} in {LocationId}/{Season} @ {}: (total is {})", inst.water_kind, spawn_kind, fish_size, CURRENT_LOCATION_ID, CALENDAR.season(), clock_time_to_string(CLOCK.time), spawn_output.votes.total);
                    for (var i = 0; i < spawn_output.votes.candidates.count(); i++) {
                        var candidate_data = spawn_output.votes.candidates.get(i);

                        BUGGER.cli.echo("{FishId}: {}", candidate_data.candidate_id, candidate_data.votes);
                    }
                })
            )
            .subcommand(BuggerCommand("spawn")
                .arg(BuggerArgument("spawn_kind").help("the spawn kind").values(get_all_keys(FishSpawn.LEN, fish_spawn_to_string)))
                .process(function(args) {
                    var inst = overlap_point(mouse_x(), mouse_y(), obj_fish_spawner);
                    if inst == undefined {
                        BUGGER.cli.echo("failed to find a spawner at mouse position!");
                        return;
                    }
                    var spawn_kind = string_to_fish_spawn(args.spawn_kind);
                    var output;
                    switch spawn_kind {
                        case FishSpawn.Fish:
                            output = spawn_fish(inst);
                            break;
                        case FishSpawn.School:
                            output = spawn_fish_school(inst);
                            break;
                        case FishSpawn.Divespot:
                            output = spawn_divespot(inst);
                            break;
                    }
                    if output != undefined && instance_exists(output) {
                        output.x = mouse_x();
                        output.y = mouse_y();
                    }
                })
            )
            .subcommand(BuggerCommand("monte_carlo")
                .arg(BuggerArgument("spawn_kind").help("the spawn kind").values(get_all_keys(FishSpawn.LEN, fish_spawn_to_string)))
                .arg(BuggerArgument("fish_size").help("the fish size to spawn").values(get_all_keys(FishSize.LEN, fish_size_to_string)))
                .arg(BuggerArgument("json").help("if true, will print in JSON").optional(false))
                .process(function(args) {
                    var inst = overlap_point(mouse_x(), mouse_y(), obj_fish_spawner);
                    if inst == undefined {
                        BUGGER.cli.echo("failed to find a spawner at mouse position!");
                        return;
                    }
                    var spawn_kind = string_to_fish_spawn(args.spawn_kind);
                    var fish_size;
                    if spawn_kind != FishSpawn.Divespot {
                        fish_size = string_to_fish_size(args.fish_size);
                    }  else {
                        fish_size = undefined;
                    }
                    var spawn_output = populate_fish(spawn_kind, fish_size, inst.water_kind, inst.x, inst.y);

                    var print_json = bool(args.json);

                    var o = {};
                    var total = 0;
                    repeat 100000 {
                        var winner = spawn_output.get_candidate();
                        var winner_str = fish_id_to_string(winner);

                        if o[$ winner_str] == undefined {
                            o[$ winner_str] = 0;
                        }

                        o[$ winner_str] += 1;
                        total += 1;
                    }
                    var keys = struct_get_names(o);
                    var o2 = {};
                    for (var i = 0; i < array_length(keys); i++) {
                        var key = keys[i];

                        o2[$ key] = format("{}%", (o[$ key] / total) * 100.0);

                        if print_json == false {
                            BUGGER.cli.echo("{}. {} {}, {}", i + 1, key, o[$ key], o2[$ key]);
                        }
                    }

                    if print_json {
                        BUGGER.cli.echo("{json}", { raw: o, percent: o2 });
                    }
                })
            )
            .subcommand(BuggerCommand("size_monte_carlo")
                .arg(BuggerArgument("spawn_kind").help("the spawn kind").values(get_all_keys(FishSpawn.LEN, fish_spawn_to_string)))
                .arg(BuggerArgument("json").help("if true, will print in JSON").optional(false))
                .process(function(args) {
                    var instance = overlap_point(mouse_x(), mouse_y(), obj_fish_spawner);
                    if instance == undefined {
                        BUGGER.cli.echo("failed to find a spawner at mouse position!");
                        return;
                    }

                    var print_json = bool(args.json);

                    var o = {};
                    var total = 0;
                    repeat 100000 {
                        var winner = instance.fish_votes.get_candidate();
                        var winner_str = fish_size_to_string(winner);

                        if o[$ winner_str] == undefined {
                            o[$ winner_str] = 0;
                        }

                        o[$ winner_str] += 1;
                        total += 1;
                    }
                    var keys = struct_get_names(o);
                    var o2 = {};
                    for (var i = 0; i < array_length(keys); i++) {
                        var key = keys[i];

                        o2[$ key] = format("{}%", (o[$ key] / total) * 100.0);

                        if print_json == false {
                            BUGGER.cli.echo("{}. {} {}, {}", i + 1, key, o[$ key], o2[$ key]);
                        }
                    }

                    if print_json {
                        BUGGER.cli.echo("{json}", { raw: o, percent: o2 });
                    }
                })
            )
            .subcommand(BuggerCommand("size_votes")
                .arg(BuggerArgument("spawn_kind").help("the spawn kind").values(get_all_keys(FishSpawn.LEN, fish_spawn_to_string)))
                .process(function(args) {
                    var inst = overlap_point(mouse_x(), mouse_y(), obj_fish_spawner);
                    if inst == undefined {
                        BUGGER.cli.echo("failed to find a spawner at mouse position!");
                        return;
                    }
                    var spawn_kind = string_to_fish_spawn(args.spawn_kind);

                    BUGGER.cli.echo("Size Votes for {WaterType}, {FishSpawn}: (total is {})", inst.water_kind, spawn_kind, inst.fish_votes.total);
                    for (var i = 0; i < inst.fish_votes.candidates.count(); i++) {
                        var candidate_data = inst.fish_votes.candidates.get(i);

                        BUGGER.cli.echo("{FishSize}: {}", candidate_data.candidate_id, candidate_data.votes);
                    }
                })
            )
        )
        .add_command(
            BuggerCommand("player")
                .help("stuff about the player")
                .author("cos")
                .subcommand(
                    BuggerCommand("status_effect")
                        .help("Adds a status effect to the player")
                        .arg(BuggerArgument("effect").help("the status effect to apply").values(get_all_keys(StatusEffectId.LEN, status_effect_id_to_string)))
                        .arg(BuggerArgument("minutes").help("duration of the effect in minutes"))
                        .arg(BuggerArgument("percent").help("the amount"))
                        .process(function(args) {
                            ARI.status_effects.register(
                                string_to_status_effect_id(args.effect),
                                real(args.percent),
                                CALENDAR.unified_time() + minutes(real(args.minutes)),
                                CALENDAR.unified_time(),
                            );
                            BUGGER.cli.echo("{}% {} applied for {} minutes", args.percent, args.effect, args.minutes);
                        })
                )
                .subcommand(
                    BuggerCommand("armor")
                        .help("View armor information")
                        .process(function() {
                            var has_any = false;
                            var total_defense = 0;
                            for (var i = 0; i < ARI.armor.size(); i++) {
                                var item = ARI.armor.slot(i).item;
                                if item != undefined {
                                    BUGGER.cli.echo("{ItemId}: Defense {}", item.item_id, item.prototype.defense);
                                    has_any = true;
                                    total_defense += item.prototype.defense;
                                }
                            }

                            if has_any {
                                BUGGER.cli.echo("Total Defense: {}", total_defense);
                            } else {
                                BUGGER.cli.echo("No armor on")
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("set_armor")
                        .help("Set an item name. We'll figure out the slot.")
                        .arg(BuggerArgument("item").optional().help("The skill perk to set").values(get_all_keys(ItemId.LEN, item_id_to_string)))
                        .process(function(o) {
                            var item = new LiveItem(string_to_item_id(o.item));

                            //
                            for (var i = 0; i < ARI.armor.size(); i++) {
                                if item.prototype.tags.satisfies(ARI.armor.slot(i).required_tags) {
                                    ARI.armor.slot(i).pop();
                                    ARI.armor.slot(i).push(item);
                                }
                            }
                        })
                )
                .subcommand(
                    BuggerCommand("remove_armor")
                        .arg(BuggerArgument("slot").values(["head", "chest", "hands", "legs", "boots"]))
                        .process(function(o) {
                            var slot = 0;
                            switch o.slot {
                                case "head":
                                    slot = 0;
                                    break;
                                case "chest":
                                    slot = 1;
                                    break;
                                case "hands":
                                    slot = 2;
                                    break;
                                case "legs":
                                    slot = 3;
                                    break;
                                case "boots":
                                    slot = 4;
                                    break;
                                default:
                                    crash("unknown slot!");
                                    break;
                            }
                            ARI.armor.slot(slot).pop();
                        })
                )
                .subcommand(
                    BuggerCommand("grant_mount")
                        .help("Gives Ari the default mount.")
                        .process(function() {
                            ARI.mount = create_default_mount();
                        })
                )
                .subcommand(
                    BuggerCommand("give_child")
                        .arg(BuggerArgument("child").values(get_all_keys(ChildId.LEN, child_id_to_string)))
                        .process(function(opts) {
                            trigger_birth(string_to_child_id(opts.child));
                        })
                )
                .subcommand(
                    BuggerCommand("clear_children")
                        .process(function() {
                            //
                            var held = ARI.held_child();
                            if held != undefined {
                                held.set_location(ChildLocation.InCradle);
                            }
                            ARI.children = [];
                            report_children_facts();
                        })
                )
                .subcommand(
                    BuggerCommand("set_gold")
                        .help("Sets how much gold the player has")
                        .arg(BuggerArgument("gold").help("The amount of gold to set"))
                        .process(function (_options) {
                            ARI.set_gold(real(_options.gold))
                        })
                )
                .subcommand(
                    BuggerCommand("set_skill_level")
                        .arg(BuggerArgument("skill").values(get_all_keys(Skill.LEN, skill_to_string)))
                        .arg(BuggerArgument("level"))
                        .process(function (args) {
                            ARI.skill_xp[string_to_skill(args.skill)] = skill_level_cost(string_to_skill(args.skill), real(args.level));
                        })
                )
                .subcommand(
                    BuggerCommand("set_renown")
                        .help("Sets how much renown the player has")
                        .arg(BuggerArgument("renown").help("The amount of renown to set"))
                        .process(function (_options) {
                            ARI.set_renown(real(_options.renown));
                            var level = renown_to_level(ARI.renown);
                            BUGGER.cli.echo("Ari now has {} renown and is level {}, rank '{Local}'", ARI.renown, level, renown_level_to_rank(level).name);
                        })
                )
                .subcommand(
                    BuggerCommand("renown_status")
                        .help("Shows the current stats for Ari's renown")
                        .process(function() {
                            var level = renown_to_level(ARI.renown);
                            var rank = renown_level_to_rank(level);
                            var output = List(
                                format("Rank: {Local}", rank.name),
                                format("Level: {}", level),
                                format("Renown: {}", ARI.renown),
                                format("Renown Until Next Level: {}", renown_level_total_cost(level + 1) - ARI.renown),
                            );

                            BUGGER.cli.post(output.join("\n"));
                        })
                )
                .subcommand(
                    BuggerCommand("set_essence")
                        .help("Sets how much essence the player has")
                        .arg(BuggerArgument("essence").help("The amount of essence to give"))
                        .process(function (_options) {
                            ARI.set_essence(real(_options.essence));
                        })
                )
                .subcommand(
                    BuggerCommand("set_mana")
                        .help("Sets how many spell slots the player has")
                        .arg(BuggerArgument("count").help("The number of slots to set"))
                        .process(function (_options) {
                            if real(_options.count) > ARI.mana_max {
                                ARI.mana_max = real(_options.count);
                            }
                            ARI.set_mana(real(_options.count))
                        })
                )
                .subcommand(
                    BuggerCommand("full")
                        .help("Fill player health and stamina")
                        .process(function () {
                            ARI.set_stamina(ARI.get_max_stamina());
                            ARI.set_health(ARI.get_max_health());
                            BUGGER.cli.post("Player has full health and stamina!");
                        })
                )
                .subcommand(
                    BuggerCommand("set_health")
                        .help("Sets Ari's HP.")
                        .arg(BuggerArgument("hp").help("The hp to set to."))
                        .process(function(args) {
                            ARI.set_health(real(args.hp));
                        })
                )
                .subcommand(
                    BuggerCommand("acquire_perk")
                    .help("Acquire a perk")
                    .arg(BuggerArgument("perk").help("Perk to set to").values(get_all_keys(Perk.LEN, perk_to_string)))
                    .process(function(args) {
                        ARI.acquire_perk(string_to_perk(args.perk));
                    })
                )
                .subcommand(
                    BuggerCommand("toggle_perk")
                    .help("Toggle a perk on or off")
                    .arg(BuggerArgument("perk").help("Perk to toggle").values(get_all_keys(Perk.LEN, perk_to_string)))
                    .process(function(args) {
                        ARI.perks_active[string_to_perk(args.perk)] = !ARI.perks_active[string_to_perk(args.perk)];
                    })
                )
                .subcommand(
                    BuggerCommand("set_stamina")
                        .help("Sets Ari's Stamina.")
                        .arg(BuggerArgument("stamina").help("The stamina to set to."))
                        .process(function(args) {
                            ARI.set_stamina(real(args.stamina));
                        })
                )
                .subcommand(
                    BuggerCommand("mark_items_as_acquired")
                        .process(function(_opts) {
                            ARI.items_acquired = array_create(ItemId.LEN, true);
                        })
                )
                .subcommand(
                    BuggerCommand("set_inventory_size")
                        .help("sets inventory size -- YOU MUST USE 10, 20, OR 30")
                        .arg(BuggerArgument("size").help("da size"))
                        .process(function (args) {
                            ARI.inventory.resize(real(args.size));
                        })
                )
        )
        .add_command(
            BuggerCommand("add_item")
                .help("adds an item to player inventory")
                .arg(BuggerArgument("item").help("The name of the item to add").values(get_all_keys(ItemId.LEN, item_id_to_string)))
                .arg(BuggerArgument("count").help("The number of items to add").optional(1))
                .arg(BuggerArgument("extra_data").optional(undefined))
                .arg(BuggerArgument("extra_extra_data").optional(undefined))
                .process(function (args) {
                    var item = new LiveItem(string_to_item_id(args.item));

                    switch item.item_id {
                        case ItemId.Cosmetic:
                            item.cosmetic = args.extra_data;
                            break;
                        case ItemId.Purse:
                            item.gold_to_gain = real(args.extra_data);
                            break;
                        case ItemId.AnimalCosmetic:
                            item.animal_cosmetic = {
                                animal: string_to_animal_kind(args.extra_data),
                                cosmetic: args.extra_extra_data,
                            }
                            break;
                        case ItemId.PetCosmetic:
                            item.pet_cosmetic_set_name = args.extra_data;
                            break;
                        case ItemId.UnidentifiedArtifact:
                        case ItemId.CraftingScroll:
                        case ItemId.RecipeScroll:
                            item.inner_item = string_to_item_id(args.extra_data);
                            break;
                        default:
                            if args.extra_data != undefined {
                                item.infusion = string_to_infusion(args.extra_data);
                            }
                            break;

                    }

                    var count = real(args.count);
                    ARI.give_item(item, count);
                })
        )
        .add_command(
            BuggerCommand("add_wild")
                .help("adds an item to player inventory in a wild manner")
                .arg(BuggerArgument("item").help("The name of the item to add").values(get_all_keys(ItemId.LEN, item_id_to_string)))
                .arg(BuggerArgument("count").help("The number of items to add").optional(1))
                .process(function (args) {
                    for (var i = 0; i < ItemId.LEN; i++) {
                        var id_as_str = item_id_to_string(i);
                        if string_pos(args.item, id_as_str) != 0 {
                            var item = new LiveItem(i);
                            var count = real(args.count);
                            ARI.give_item(item, count, true, false);
                        }
                    }
                })
        )
        .add_command(
            BuggerCommand("add_set_items")
                .help("adds items to the player's inventory based on a museum set")
                .arg(BuggerArgument("wing").help("The name of the wing").values(get_all_keys(MuseumWing.LEN, museum_wing_to_string)))
                .arg(BuggerArgument("set").help("The name of the set"))
                .process(function (args) {
                    var items = MUSEUM_DATA.data[string_to_museum_wing(args.wing)].sets.get(args.set).items;
                    for (var i = 0; i < array_length(items); i++) {
                        ARI.give_item(items[i], 1, true, false);
                    }
                })
        )
        .add_command(
            BuggerCommand("test_bug")
                .process(function() {
                    var successions = 0;
                    var data = {};
                    var amount = 1000;

                    repeat(amount) {
                        var success = spawn_bug(irandom(GRID.dims.x - 1), irandom(GRID.dims.y - 1));
                        if success != undefined && instance_exists(success) {
                            if data[$ item_id_to_string(success.item_id)] == undefined {
                                data[$ item_id_to_string(success.item_id)] = 0;
                            }
                            data[$ item_id_to_string(success.item_id)] += 1;
                            successions++;
                        }
                    }

                    trace("Generic attempt success rate {}%", successions/amount*100);
                    var names = struct_get_names(data);
                    for (var i = 0; i < array_length(names); i++) {
                        trace("Percentage of bug {}: {}%. (spawned {}/{} total).", names[i], data[$ names[i]]/successions*100, data[$ names[i]], successions);
                    }
                })
        )
        .add_command(
            BuggerCommand("ts_proceed")
                .process(function() {
                    global.__can_proceed = true;
                    BUGGER.cli.hide();
                    BUGGER.cli.cli_input.set_takes_input(false);
                })
        )
        .add_command(
            BuggerCommand("unit_test")
                .help("Runs the unit tests.")
                .author("gabe")
                .process(function() {
                    var result = run_unit_tests();
                    if result.succeeded {
                        BUGGER.cli.post("All tests passed.")
                    } else {
                        BUGGER.cli.post(fmt(
                            "{} tests did not pass ({}). Check the output for more information.",
                            result.error_count,
                            result.failed_test_names.join(", "),
                        ));
                    }
                })
        )
        .add_command(
            BuggerCommand("mist")
                .help("Commands to assist with mist, our cutscene system")
                .author("Gabe")
                .subcommand(BuggerCommand("run")
                    .arg(BuggerArgument("scene_name")
                        .help("The name of the scene file (no file extension) to play")
                        .values(CUTSCENES.keys())
                    )
                    .process(function(_options) {
                        MIST.run_scene(_options.scene_name);
                    })
                )
                .subcommand(BuggerCommand("skip_to")
                    .arg(BuggerArgument("checkpoint"))
                    .arg(BuggerArgument("prompt_index")
                        .help("The option every prompt answers itself with while skipping. Defaults to 0 -- pass 1 to take the romantic split of a heart event.")
                        .optional(0)
                    )
                    .process(function(o) {
                        MIST.runtime.begin_simulation(o.checkpoint, real(o.prompt_index));
                    }))
        )
        .add_command(
            BuggerCommand("bug")
                .help("make insects in the game be in the game!")
                .author("g-money")
                .subcommand(BuggerCommand("spawn")
                    .help("Spawn a bug by name")
                    .arg(BuggerArgument("bug_name").values(array_map(BUGS.keys(), function(stringy) { return item_id_to_string(real(stringy)); } )))
                    .process(function(args) {
                        var inst = instance_create_depth(mouse_x(), mouse_y(), 0, obj_bug);
                        inst.setup(string_to_item_id(args.bug_name));
                    })
                )
                .subcommand(BuggerCommand("monte_carlo")
                    .arg(BuggerArgument("json").help("if true, will print in JSON").optional(false))
                    .process(function(args) {
                        var print_json = bool(args.json);

                        var o = {};
                        var total = 0;
                        var rarity_counts = {};

                        repeat 5000 {
                            instance_destroy(obj_bug);
                            spawn_bugs_on_room_start();

                            with obj_bug {
                                var name = format("{ItemId} ({})", obj_bug.item_id, BUGS.get(obj_bug.item_id).rarity);
                                if o[$ name] == undefined {
                                    o[$ name] = 0;
                                }
                                o[$ name] += 1;

                                //
                                var name = BUGS.get(obj_bug.item_id).rarity;
                                if rarity_counts[$ name] == undefined {
                                    rarity_counts[$ name] = 0;
                                }
                                rarity_counts[$ name] += 1;

                                total += 1;
                            }
                        }
                        var keys = struct_get_names(o);

                        //
                        var o3 = [];
                        for (var i = 0; i < array_length(keys); i++) {
                            array_push(o3, [keys[i], o[$ keys[i]]]);
                        }

                        array_sort(o3, function(elem1, elem2) {
                            return elem2[1] - elem1[1];
                        });

                        var o2 = {};
                        for (var i = 0; i < array_length(keys); i++) {
                            var data_pair = o3[i];
                            var key = data_pair[0];
                            var value = data_pair[1];

                            o2[$ key] = format("{}%", (value / total) * 100.0);

                            if print_json == false {
                                BUGGER.cli.echo("{}. {} {}, {}", i + 1, key, value, o2[$ key]);
                            }
                        }

                        if !print_json {
                            BUGGER.cli.echo("-------");
                        }

                        var rarity2 = {};
                        var keys = struct_get_names(rarity_counts);
                        for (var i = 0; i < array_length(keys); i++) {
                            var key = keys[i];
                            var value = rarity_counts[$ key];

                            rarity2[$ key] = format("{}%", (value / total) * 100.0);

                            if print_json == false {
                                BUGGER.cli.echo("{}. {} {}, {}", i + 1, key, value, rarity2[$ key]);
                            }
                        }

                        if print_json {
                            BUGGER.cli.echo("{json}", { raw: o, percent: o2, rarity_counts: rarity2 });
                        }
                    })
                )
                .subcommand(BuggerCommand("dungeon_monte_carlo")
                    .arg(BuggerArgument("start_floor"))
                    .process(function(args) {
                        var c = new_chain();

                        global.o = {
                            sad: 0,
                        };
                        global.total = 0;
                        global.rarity_counts = {};

                        //
                        var start_floor = real(args.start_floor);
                        start_floor = (start_floor div 20) * 20 + 1;

                        BUGGER.cli.echo("Starting monte carlo simulation on floor {}..={}...this might take awhile...", start_floor, start_floor + 18);

                        c.append(LinkId.Timer, 2);
                        c.append(LinkId.Function, function(start_floor) {
                            enter_dungeon(start_floor);
                        }, [start_floor]);

                        repeat 1000 {
                            c.append(LinkId.Function, function(start_floor) {
                                with obj_bug {
                                    var name = format("{ItemId} ({})", obj_bug.item_id, BUGS.get(obj_bug.item_id).rarity);
                                    if global.o[$ name] == undefined {
                                        global.o[$ name] = 0;
                                    }
                                    global.o[$ name] += 1;

                                    //
                                    var name = BUGS.get(obj_bug.item_id).rarity;
                                    if global.rarity_counts[$ name] == undefined {
                                        global.rarity_counts[$ name] = 0;
                                    }
                                    global.rarity_counts[$ name] += 1;

                                    global.total += 1;
                                }
                                if instance_number(obj_bug) == 0 {
                                    global.o.sad += 1;
                                    global.total += 1;
                                }

                                if DUNGEON_FLOOR >= (start_floor + 18) {
                                    enter_dungeon(start_floor, DUNGEON_FLOOR_COUNT, true);
                                } else {
                                    DUNGEON_RUNNER.proceed("cheater", true);
                                }
                            }, [start_floor]);
                            c.append(LinkId.Timer, 1);
                        }

                        c.append(LinkId.Function, function() {
                            var o = global.o;
                            var total = global.total;
                            var rarity_counts = global.rarity_counts;

                            var keys = struct_get_names(o);

                            //
                            var o3 = [];
                            for (var i = 0; i < array_length(keys); i++) {
                                array_push(o3, [keys[i], o[$ keys[i]]]);
                            }

                            array_sort(o3, function(elem1, elem2) {
                                return elem2[1] - elem1[1];
                            });

                            var o2 = {};
                            for (var i = 0; i < array_length(keys); i++) {
                                var data_pair = o3[i];
                                var key = data_pair[0];
                                var value = data_pair[1];

                                o2[$ key] = format("{}%", (value / total) * 100.0);

                                BUGGER.cli.echo("{}. {} {}, {}", i + 1, key, value, o2[$ key]);
                            }

                            BUGGER.cli.echo("-------");

                            var rarity2 = {};
                            var keys = struct_get_names(rarity_counts);
                            for (var i = 0; i < array_length(keys); i++) {
                                var key = keys[i];
                                var value = rarity_counts[$ key];

                                rarity2[$ key] = format("{}%", (value / total) * 100.0);
                                BUGGER.cli.echo("{}. {} {}, {}", i + 1, key, value, rarity2[$ key]);
                            }

                            //
                            SCREEN_FADER.snap_in();
                        });
                    })
                )
        )
        .add_command(
            BuggerCommand("anchor")
                .help("utilities 4 anchor")
                .author("g-money")
                .subcommand(BuggerCommand("toggle_text_zones")
                    .process(function() {
                        for (var i = 0; i < ds_list_size(ANCHOR.node_registrar); i++) {
                            var node = ANCHOR.node_registrar[| i];
                            if node.get_enabled() && node.type == NodeId.Text {
                                var old = node.blackboard.try_take("zone");
                                if old != undefined {
                                    ANCHOR.free_node(old);
                                } else {
                                    node.show_text_zone();
                                }
                            }
                        }
                    })
                )
                .subcommand(BuggerCommand("toggle_positional_previews")
                    .help("Toggles a preview box for all positional nodes")
                    .process(function() {
                        for (var i = 0; i < ds_list_size(ANCHOR.node_registrar); i++) {
                            var node = ANCHOR.node_registrar[| i];
                            if node.get_enabled() && node.type == NodeId.Positional {
                                var old = node.blackboard.try_take("preview");
                                if old != undefined {
                                    ANCHOR.free_node(old);
                                } else {
                                    static ITER = 0;
                                    static COLORS = [
                                        make_color_rgb(20, 20, 20),
                                        make_color_rgb(30, 120, 255),
                                        make_color_rgb(255, 0, 200),
                                        make_color_rgb(0, 180, 60),
                                        make_color_rgb(150, 140, 0),
                                        make_color_rgb(255, 130, 0),
                                        make_color_rgb(140, 0, 200),
                                        make_color_rgb(220, 0, 0),
                                        make_color_rgb(180, 180, 180),
                                        make_color_rgb(0, 190, 190),
                                        make_color_rgb(0, 90, 90),
                                        make_color_rgb(255, 220, 0),
                                    ];
                                    node.preview(COLORS[ITER]);
                                    ITER = wrap(ITER + 1, array_length(COLORS));
                                }
                            }
                        }
                    })
                )
                .subcommand(BuggerCommand("menu_report")
                    .process(function() {
                        BUGGER.cli.echo(
                            ANCHOR.open_menus.map_to(
                                function(v) {
                                    return menu_to_string(v.type);
                                })
                                .join(", ")
                        );
                    })
                )
                .subcommand(BuggerCommand("hide")
                    .process(function() {
                        BUGGER.hide_ui = !BUGGER.hide_ui;
                    })
                )
                .subcommand(BuggerCommand("detect_lost_nodes")
                    .process(function() {
                        var nodes = ANCHOR.detect_lost_nodes();
                        var header = format("{}/{} scanned nodes were lost!", nodes.count(), ANCHOR.node_count);
                        var summary = nodes
                            .map_to(function(node) {
                                return node.display();
                            })
                            .join("\n");
                        trace("{}\n\n## Lost Nodes ##\n\n{}", header, summary);
                    })
                )
                .subcommand(BuggerCommand("time")
                    .arg(BuggerArgument("hour"))
                    .arg(BuggerArgument("minute"))
                    .process(function(args) {
                        var menu = ANCHOR.get_menu(Menu.Title);
                        if menu != undefined {
                            menu.manual_menu_time = hours(args.hour) + minutes(args.minute);
                        }
                    })
                )
                .subcommand(BuggerCommand("timelapse")
                    .process(function() {
                        new_chain().append(LinkId.Ease, new Ease(EaseId.Linear, hours(6), hours(26), 300), function(_, a) {
                            var menu = ANCHOR.get_menu(Menu.Title);
                            if menu != undefined {
                                menu.manual_menu_time = a;
                            }
                        });

                    })
                )
                .subcommand(BuggerCommand("show")
                    .process(function() {
                        BUGGER.hide_ui = false;
                    })
                )
                .subcommand(BuggerCommand("node_report")
                    .process(function() {
                        var menus = Map();
                        for (var i = 0; i < ANCHOR.node_count; i++) {
                            var node = ANCHOR.node_registrar[| i];
                            var menu = "none";
                            if node.source_menu != undefined {
                                menu = menu_to_string(node.source_menu.type);
                            }

                            var num = menus.get_or_insert(menu, 0);
                            menus.set(menu, num + 1);
                        }

                        var breakdown = "";
                        var keys = menus.keys();
                        for (var i = 0; i < array_length(keys); i++) {
                            breakdown += format("{}: {}\n", keys[i], menus.get(keys[i]));
                        }

                        BUGGER.cli.echo(format(
                            "-------- NODE REPORT --------\n\n{}\n\n-----------------------------",
                            breakdown
                        ));
                    })
                )
        )
        .add_command(
            BuggerCommand("show_room_transitions")
                .help("shows room transitions visibly")
                .author("jack")
                .process(function() {
                    with obj_roomtransition {
                        visible = !visible;

                        if self.visible {
                            depth = -100000;
                        }
                    }
                })
        )
        .add_command(
            BuggerCommand("hammer")
                .help("hammers the room transition over and over")
                .author("jack")
                .process(function() {
                    function append_to_chain(c, l) {
                        l += 1;
                        if l >= LocationId.LEN {
                            l = 0;
                        }

                        if keyboard_check(vk_escape) == false {
                            c.append(LinkId.Function, function(l) {
                                if matches(
                                    l,
                                    LocationId.Aldaria,
                                    LocationId.SmallCoop,
                                    LocationId.SmallBarn,
                                    LocationId.MediumCoop,
                                    LocationId.MediumBarn,
                                    LocationId.LargeCoop,
                                    LocationId.LargeBarn,
                                    LocationId.Dungeon
                                ) {
                                    return;
                                }
                                if is_dungeon_room(location_id_to_gm_room(l)) {
                                    return;
                                }

                                trace("going from: {LocationId} -> {LocationId} @ {time}", gm_room_to_location_id(room()), l, CLOCK.time)
                                goto_location_id(l, true);
                            }, [l])
                            .append(LinkId.Timer, 5)
                            .append(LinkId.Function, append_to_chain, [c, l]);
                        }
                    };

                    append_to_chain(new_chain(), -1);
                })
        )
        .add_command(
            BuggerCommand("audio_pop")
                .process(function() {
                    global.SUSPECTS = [
                        "SoundEffects/Ari/Footsteps/StoneFeetRun",
                        "SoundEffects/Ari/Footsteps/WoodFeetRun",
                        "SoundEffects/NPCs/Vocal/TextBlipDell",
                        "SoundEffects/NPCs/Vocal/TextBlipEiland",
                    ];

                    global.RUN = function() {
                        for (var i = 0; i < array_length(global.SUSPECTS); i++) {
                            var path = global.SUSPECTS[i];
                            TANGO.play(path, obj_ari.x, obj_ari.y);
                        }
                        new_chain()
                            .append(LinkId.Timer, 1)
                            .append(LinkId.Function, global.RUN)
                    }
                    global.RUN();
                })
        )
        .add_command(
            BuggerCommand("smack")
            .process(function() {
                obj_ari.fsm.change_state(PlayerState.Hurt);
            })
        )
        .add_command(
            BuggerCommand("bird")
                .process(function() {
                    //
                    var nearest = find_nearest_bird_landing_position(mouse_x(), mouse_y());
                    if nearest != undefined {
                        BUGGER.cli.echo("Made a bird at {}x{}, flying to {}x{}", mouse_x(), mouse_y(), nearest.x, nearest.y);
                        var b = instance_create_depth(mouse_x(), mouse_y(), 0, obj_bird, { target: nearest });
                        nearest.occupied = b;
                    } else {
                        BUGGER.cli.echo("Couldn't make a bird! No available landing positions");
                    }
                })
        )
        .add_command(
            BuggerCommand("create_stuffed_save")
            .process(function() {
                ARI.name = format("Stuffed Save {SemVer}", GAME_VERSION);
                global.STUFF_POSITIONS = List();
                global.RUG_POSITIONS = List();
                var grid = GRIDS[LocationId.Aldaria];
                for (var i = 0; i < grid.dims.y; i++) {
                    for (var j = 0; j < grid.dims.x; j++) {
                        global.STUFF_POSITIONS.push(Vec2(j, i));
                        global.RUG_POSITIONS.push(Vec2(j, i));
                    }
                }

                static HANDLE_SPAWN = function(object_id, extra_data) {
                    trace("{ObjectId}", object_id);
                    var list = NODE_PROTOTYPES[object_id][$ "rug"]
                        ? global.RUG_POSITIONS
                        : global.STUFF_POSITIONS;

                    while !list.is_empty() {
                        var pos = list.remove(0);
                        var node = GRIDS[LocationId.Aldaria].write_node(
                            pos.x,
                            pos.y,
                            object_id,
                            extra_data,
                        );
                        if node != undefined {
                            return node;
                        }
                    }
                    trace("failure.")
                    return undefined;
                }

                static HANDLE_ITEM = function(item, node) {
                    node.inventory.add(item.clone());
                    GRIDS[LocationId.Aldaria].lost_items.push({
                        x: 0,
                        y: 0,
                        items: ListFromArray([item]),
                    });
                }

                var all_items = List();
                for (var i = 0; i < ItemId.LEN; i++) {
                    switch i {
                        case ItemId.RecipeScroll:
                            for (var j = 0; j < ItemId.LEN; j++) {
                                var item = new LiveItem(ItemId.RecipeScroll);
                                var proto = ITEM_PROTOTYPES[j];
                                if proto.recipe != undefined && proto.stars != undefined {
                                    item.inner_item = j;
                                    all_items.push(item);
                                }
                            }
                            break;
                        case ItemId.CraftingScroll:
                            for (var j = 0; j < ItemId.LEN; j++) {
                                var proto = ITEM_PROTOTYPES[j];
                                if proto.recipe != undefined && proto.tags.contains("furniture") {
                                    var item = new LiveItem(ItemId.CraftingScroll);
                                    item.inner_item = j;
                                    all_items.push(item);
                                }
                            }
                            break;
                        case ItemId.Cosmetic:
                            var all_cosmetics = PLAYER_ANIMATION_DATABASE.player_assets.keys();
                            for (var j = 0; j < array_length(all_cosmetics); j++) {
                                var item = new LiveItem(ItemId.Cosmetic);
                                item.cosmetic = all_cosmetics[j];
                                all_items.push(item);
                            }
                            break;
                        case ItemId.AnimalCosmetic:
                            for (var j = 0; j < AnimalKind.LEN; j++) {
                                var animal = ANIMAL_PROTOTYPES[j];
                                var all_cosmetics = animal.cosmetics.keys();
                                for (var k = 0; k < array_length(all_cosmetics); k++) {
                                    var item = new LiveItem(ItemId.AnimalCosmetic);
                                    item.animal_cosmetic = {
                                        animal: j,
                                        cosmetic: all_cosmetics[k],
                                    };
                                    all_items.push(item);
                                }
                            }
                            break;
                        case ItemId.PetCosmetic:
                            var keys = PET_PROTOTYPE.cosmetic_sets.keys();
                            for (var j = 0; j < array_length(keys); j++) {
                                var item = new LiveItem(ItemId.PetCosmetic);
                                item.pet_cosmetic_set_name = keys[j];
                                all_items.push(item);
                            }
                            break;
                        default:
                            all_items.push(new LiveItem(i));
                            break;
                    }
                };

                for (var i = 0; i < Infusion.LEN; i++) {
                    var infusion = INFUSIONS.get(i);
                    var tags = ListFromArray(infusion.supported_tags);
                    for (var j = 0; j < ItemId.LEN; j++) {
                        var proto = ITEM_PROTOTYPES[j];
                        if proto.tags.contains_any_value_from(tags) {
                            var item = new LiveItem(j);
                            item.infusion = i;
                            all_items.push(item);
                            break;
                        }
                    }
                }

                var all_objects = ListFromArray(array_create_ext(ObjectId.LEN, function(i) {
                    return NODE_PROTOTYPES[i];
                }));

                var failures = List();
                for (var i = 0; i < ObjectCategory.LEN; i++) {
                    trace("Stuffing {ObjectCategory}...", i);
                    var remaining = undefined;
                    switch i {
                        case ObjectCategory.Building:
                        case ObjectCategory.DigSite:
                        case ObjectCategory.Grass:
                            break;
                        case ObjectCategory.Furniture:
                            remaining = all_objects
                                .clone()
                                .retain(function(proto, HANDLE_SPAWN, HANDLE_ITEM, all_items) {
                                    if object_id_to_object_category(proto.object_id) == ObjectCategory.Furniture {
                                        if proto.rug {
                                            return HANDLE_SPAWN(proto.object_id) == undefined;
                                        } else if proto[$ "blueprint_id"] == undefined
                                            && !proto.fence
                                            && !proto.is_date_photo
                                            && !proto.house_stairs
                                            && proto.object_id != ObjectId.StableCraftingTable
                                            && proto.object_id != ObjectId.OcarinaSpriteStatue
                                            && proto.object_id != ObjectId.OcarinaSpriteStatueBase
                                            && proto.object_id != ObjectId.AutoFeeder
                                            && proto.object_id != ObjectId.AutoFeederPlatform
                                            && proto.object_id != ObjectId.FarmBridge
                                            && proto.object_id != ObjectId.GemstoneBridgeV1
                                            && proto.object_id != ObjectId.GemstoneBridgeV2
                                            && proto.object_id != ObjectId.GemstoneBridgeV3
                                            && proto.object_id != ObjectId.WaterBlocker
                                        {
                                            var node = HANDLE_SPAWN(proto.object_id);
                                            if node == undefined {
                                                return true;
                                            }
                                            while node[$ "inventory"] != undefined && !all_items.is_empty() {
                                                var item = all_items.last();
                                                if !node.inventory.can_add(item) {
                                                    break;
                                                }
                                                HANDLE_ITEM(all_items.pop(), node);
                                            }
                                        }
                                    }
                                    return false;
                                }, HANDLE_SPAWN, HANDLE_ITEM, all_items);
                            break;
                        case ObjectCategory.Crop:
                        case ObjectCategory.Tree:
                            remaining = all_objects
                                .clone()
                                .retain(function(proto, category, HANDLE_SPAWN) {
                                    if object_id_to_object_category(proto.object_id) == category {
                                        for (var stage = 0; stage <= proto.day_to_stage.max(); stage++) {

                                            var reset = false;
                                            if proto[$ "seasons"] != undefined && !proto.seasons[CALENDAR.season()] {
                                                proto.seasons[CALENDAR.season()] = true;
                                            }
                                            var node = HANDLE_SPAWN(proto.object_id);
                                            if reset {
                                                proto.seasons[CALENDAR.season()] = false;
                                            }

                                            if node == undefined {
                                                return true;
                                            }

                                            var day = proto.day_to_stage.find(function(v, stage) {
                                                return v == stage;
                                            }, stage);

                                            node.day_count = day;
                                            node.stage = stage;
                                        }
                                    }
                                    return false;
                                }, i, HANDLE_SPAWN)
                            break;
                        default:
                            remaining = all_objects
                                .clone()
                                .retain(function(proto, category, HANDLE_SPAWN) {
                                    if object_id_to_object_category(proto.object_id) == category {
                                        var reset = false;
                                        if proto[$ "seasons"] != undefined && !proto.seasons[CALENDAR.season()] {
                                            proto.seasons[CALENDAR.season()] = true;
                                        }
                                        var node = HANDLE_SPAWN(proto.object_id);
                                        if reset {
                                            proto.seasons[CALENDAR.season()] = false;
                                        }
                                        return node == undefined;
                                    }
                                    return false;
                                }, i, HANDLE_SPAWN)
                            break;
                    }

                    if remaining != undefined {
                        failures.copy_from(remaining);
                    }
                }

                //
                trace("Writing remaining items to chests...");
                while !all_items.is_empty() {
                    var node = HANDLE_SPAWN(ObjectId.BasicWoodChestDark);
                    if node == undefined {
                        break;
                    }
                    assert_neq(node, undefined, "Failed to write a chest to store items!");
                    while !all_items.is_empty() && node.inventory.can_add(all_items.last()) {
                        HANDLE_ITEM(all_items.pop(), node);
                    }
                }

                assert(
                    failures.is_empty(),
                    "Failed to write the following objects:\n{}",
                    failures
                        .map(function(v) {
                            return object_id_to_string(v.object_id);
                        })
                        .join("\n")
                );

                assert(
                    all_items.is_empty(),
                    "Failed to place {} items in storage!",
                    all_items.count(),
                );

                trace("Finished stuffing Aldaria!");

                QUEST_LOG.completed.clear();
                var keys = QUESTS.keys();
                for (var i = 0; i < array_length(keys); i++) {
                    QUEST_LOG.start(keys[i]);
                }

                var keys = LETTERS.keys();
                ARI.inbox.contents = List();
                for (var i = 0; i < array_length(keys); i++) {
                    ARI.inbox.contents.push({
                        name: keys[i],
                        items_taken: false,
                        read: false,
                    });
                }

                ARI.renown = 0;
                ARI.set_renown(renown_level_total_cost(100));

                for (var i = 0; i < StatusEffectId.LEN; i++) {
                    if matches(i, StatusEffectId.Venomous, StatusEffectId.Frozen) {
                        continue;
                    }

                    ARI.status_effects.register(
                        i,
                        1,
                        CALENDAR.unified_time(),
                        CALENDAR.unified_time() + hours(1),
                    );
                }

                for (var i = 0; i < AnimalKind.LEN; i++) {
                    var animal = ANIMAL_PROTOTYPES[i];
                    var keys = animal.variants.keys();
                    for (var j = 0; j < array_length(keys); j++) {
                        DAYCARE.push(new PlayerAnimal(i, keys[j], choose(Sex.Male, Sex.Female)));
                    }
                }

                MIST.scene_history = HashSetFromArray(CUTSCENES.keys());

                //
                LOCATIONS[LocationId.Aldaria].serializable = true;
                ARI.save_position = player_wake_position();
                save_game(
                    format("{}/saves/game-{}-{}.sav", CONFIG_DIRECTORY, GAME_VERSION.minor, GAME_VERSION.patch),
                );
                LOCATIONS[LocationId.Aldaria].serializable = false;
            })
        )
        .add_command(
            BuggerCommand("sarah")
                .help("runs a function")
                .author("jack")
                .process(function() {
                    ARI.unlock_recipe(ItemId.BlackberryJam, false);
                    ARI.unlock_recipe(ItemId.BlueberryJam, false);
                    ARI.unlock_recipe(ItemId.Bread, false);
                    ARI.unlock_recipe(ItemId.Butter, false);
                    ARI.unlock_recipe(ItemId.Cheese, false);
                    ARI.unlock_recipe(ItemId.CannedSardines, false);
                    ARI.unlock_recipe(ItemId.CrunchyChickpeas, false);
                    ARI.unlock_recipe(ItemId.DeviledEggs, false);
                    ARI.unlock_recipe(ItemId.DriedSquid, false);
                    ARI.unlock_recipe(ItemId.HardBoiledEgg, false);
                    ARI.unlock_recipe(ItemId.BeetSalad, false);
                    ARI.unlock_recipe(ItemId.CabbageSlaw, false);
                    ARI.unlock_recipe(ItemId.CucumberSalad, false);
                    ARI.unlock_recipe(ItemId.BraisedCarrots, false);
                    ARI.unlock_recipe(ItemId.ButteredPeas, false);
                    ARI.unlock_recipe(ItemId.GrilledCorn, false);
                    ARI.unlock_recipe(ItemId.PumpkinStew, false);
                    ARI.unlock_recipe(ItemId.SmokedTroutSoup, false);
                    ARI.unlock_recipe(ItemId.TomatoSoup, false);
                    ARI.unlock_recipe(ItemId.VegetableSoup, false);
                    ARI.unlock_recipe(ItemId.FishStew, false);
                    ARI.unlock_recipe(ItemId.MinersMushroomStew, false);
                    ARI.unlock_recipe(ItemId.MackerelSashimi, false);
                    ARI.unlock_recipe(ItemId.RedSnapperSushi, false);
                    ARI.unlock_recipe(ItemId.Riceball, false);
                    ARI.unlock_recipe(ItemId.BerriesAndCream, false);
                    ARI.unlock_recipe(ItemId.CherryCobbler, false);
                    ARI.unlock_recipe(ItemId.CherryTart, false);
                    ARI.unlock_recipe(ItemId.CaldosianChocolateCake, false);
                    ARI.unlock_recipe(ItemId.AppleJuice, false);
                    ARI.unlock_recipe(ItemId.CoconutMilk, false);
                    ARI.unlock_recipe(ItemId.CranberryJuice, false);
                    ARI.unlock_recipe(ItemId.GrapeJuice, false);
                    ARI.unlock_recipe(ItemId.GreenTea, false);
                    ARI.unlock_recipe(ItemId.HotCocoa, false);
                })
        )
        .add_command(
            BuggerCommand("full_start")
                .help("runs a function")
                .author("jack")
                .process(function() {
                    full_start_farm_setup(GRIDS[LocationId.Farm]);
                })
        )
        .add_command(
            BuggerCommand("unlock_all_cosmetics")
                .process(function() {
                    ARI.cosmetic_unlocks = HashSetFromArray(PLAYER_ANIMATION_DATABASE.player_assets.keys());
                    ARI.seen_cosmetics = HashSetFromArray(PLAYER_ANIMATION_DATABASE.player_assets.keys());
                    for (var i = 0; i < AnimalKind.LEN; i++) {
                        var animal = ANIMAL_PROTOTYPES[i];
                        var unlocks = HashSetFromArray(animal.cosmetics.keys());
                        ARI.animal_cosmetic_unlocks[i] = unlocks;
                    }
                    ARI.pet_cosmetic_sets_unlocked = PET_PROTOTYPE.cosmetic_sets.keys();
                })
        )
        .add_command(
            BuggerCommand("weather")
                .author("gabe")
                .subcommand(BuggerCommand("set")
                    .arg(BuggerArgument("type").values(get_all_keys(Weather.LEN, weather_to_string)))
                    .process(function (opts) {
                        WEATHER.set_weather(string_to_weather(opts.type));
                    })
                )
                .subcommand(BuggerCommand("forecast")
                    .process(function() {
                        for (var i = 0; i < 28; i++) {
                            trace("{}. {Weather}", i + 1, WEATHER.forecast[i]);
                        }
                    })
                )
        )
        .add_command(
            BuggerCommand("story_enabled")
                .author("gabe")
                .process(function() {
                    STORY_ENABLED = true;
                })
        )
        .add_command(
            BuggerCommand("quest")
                .subcommand(BuggerCommand("start")
                    .help("Starts a quest if it's inactive")
                    .arg(BuggerArgument("quest").values(QUESTS.keys()))
                    .process(function(args) {
                        if QUEST_LOG.start(args.quest) {
                            BUGGER.cli.post("Quest has been started.");
                        }   else    {
                            BUGGER.cli.post("Couldn't start the specified quest.");
                        }
                    })
                )
                .subcommand(BuggerCommand("progress")
                    .help("Progresses an active quest")
                    .arg(BuggerArgument("quest").values(QUESTS.keys()))
                    .process(function(args) {
                        var quest_data = QUEST_LOG.active.get(args.quest);
                        if quest_data == undefined {
                            BUGGER.cli.post("Could not find an active quest with that name!");
                        }
                        var output = quest_data.progress();
                        if output == ProgressOutput.Complete {
                            quest_data.handle_progress_output(output);
                        } else {
                            BUGGER.cli.post(format("Quest has been progressed ({}/{}).", quest_data.current_stage, quest_data.quest.tasks.count()));
                        }
                    })
                )
                .subcommand(BuggerCommand("complete")
                    .help("Completes an active quest")
                    .arg(BuggerArgument("quest").values(QUESTS.keys()))
                    .process(function(args) {
                        if QUEST_LOG.complete(args.quest) {
                            BUGGER.cli.post("Quest has been completed.");
                        }   else    {
                            BUGGER.cli.post("Couldn't complete the specified quest.");
                        }
                    })
                )
        )
}

//
function get_all_keys(len, func) {
    var a = [];
    for (var i = 0; i < len; i++) {
        array_push(a, func(i));
    }
    return a;
}

function get_all_destination_keys() {
    var values = List();
    values.transfer(ListFromArray(get_all_keys(NpcId.LEN, npc_id_to_string)));
    values.transfer(ListFromArray(get_all_keys(LocationId.LEN, location_id_to_string)));
    values.transfer(ListFromArray(trellis_points_all()));
    return values.to_array();
}

function get_all_mines_room_names() {
    var room_ids = asset_get_ids(asset_room);

    var output = [];
    for (var i = 0; i < array_length(room_ids); i++) {
        var rm = room_ids[i];
        if is_dungeon_room(rm) {
            var stripped = string_replace(asset_to_string(rm), "rm_mines_", "");

            array_push(output, stripped);
        }
    }
    return output;
}

function get_all_gm_font_names() {
    var font_ids = asset_get_ids(asset_font);
    var a = [];
    for (var i = 0; i < array_length(font_ids); i++) {
        array_push(a, asset_to_string(font_ids[i]));
    }
    return a;
}

function get_all_gm_obj_names() {
    return array_map(asset_get_ids(asset_object), object_get_name);
}

function get_all_furniture_tile_sets() {
    return ["basic_v1", "basic_v2", "cabin_v1", "cabin_v2", "cabin_v3", "cottage_v1", "cottage_v2"];
}
