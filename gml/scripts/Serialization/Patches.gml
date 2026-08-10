function apply_save_patches(current_version, goal_version, loader) {
    var saver = new RustSaver(loader.save_path, loader.vault_id);

    if current_version.major != 1 {
        patch_early_access_saves(current_version, goal_version, loader, saver);
    }

    //
    while current_version.minor != goal_version.minor {
        switch current_version.minor {
            default:
                //
                break;
        }
    }

    //
    while current_version.patch != goal_version.patch {
        switch current_version.patch {
            default:
                current_version.patch += 1;
                break;
        }
    }

    //
    current_version.pre = goal_version.pre;

    var game_stats = loader.load_file("game_stats");
    patch_game_stats(game_stats);
    saver.save_file("game_stats", game_stats);

    var player = loader.load_file("player");
    patch_default_content(player);
    saver.save_file("player", player);

    return saver;
}

//
function patch_early_access_saves(current_version, goal_version, loader, saver) {
    while current_version.major != 1 {
        switch current_version.minor {
            //
            case 0:
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9:
            case 10:
                return undefined;
            case 11:
                //
                while current_version.patch != 8 {
                    switch current_version.patch {
                        case 3:
                            var quests = loader.load_file("quests");
                            var gamedata = loader.load_file("gamedata");
                            if array_contains(quests.completed_quests, "repair_the_beach_bridge") {
                                gamedata.building_modifier_status.beach_bridge = "fixed";
                            }

                            //
                            //
                            var farm_objects = loader.load_file("farm");
                            for (var i = 0; i < array_length(farm_objects.object_list); i++) {
                                var obj = farm_objects.object_list[i];
                                var obj_id = string_to_object_id(obj.object_id);

                                if object_id_to_object_category(obj_id) != ObjectCategory.Building {
                                    continue;
                                }

                                var fetuses = obj.stable.incubating_fetuses;
                                var animals = obj.stable.animals;

                                for (var fetus_idx = array_length(fetuses) - 1; fetus_idx >= 0; fetus_idx--) {
                                    var fetus = fetuses[fetus_idx];

                                    var mother_index = undefined;
                                    var father_index = undefined;

                                    for (var anim = 0; anim < array_length(animals); anim++) {
                                        var animal = animals[anim];
                                        if animal == undefined {
                                            continue;
                                        }

                                        if animal.idx == fetus.female_parent {
                                            mother_index = anim;
                                            animal.checked_valid = true;
                                        } else if animal.idx == fetus.male_parent {
                                            father_index = anim;
                                            animal.checked_valid = true;
                                        }
                                    }

                                    var fetus_found_valid;

                                    if mother_index != undefined && father_index != undefined {
                                        fetus_found_valid = true;
                                    } else if mother_index != undefined || father_index != undefined {
                                        fetus_found_valid = false;

                                        if mother_index != undefined {
                                            animals[mother_index].is_incubating = false;
                                        } else if father_index != undefined {
                                            animals[father_index].is_incubating = false;
                                        }
                                    } else {
                                        fetus_found_valid = false;
                                    }

                                    if fetus_found_valid == false {
                                        array_delete(fetuses, fetus_idx, 1);
                                    }
                                }

                                //
                                //
                                for (var anim = array_length(animals) - 1; anim >= 0; anim--) {
                                    var animal = animals[anim];
                                    if animal == undefined {
                                        continue;
                                    }

                                    if animal.is_incubating && animal[$ "checked_valid"] != true {
                                        animal.is_incubating = false;
                                    }

                                    if animal[$ "checked_valid"] != undefined {
                                        struct_remove(animal, "checked_valid");
                                    }
                                }

                                saver.save_file("farm", farm_objects);
                            }

                            //
                            for (var i = 0; i < array_length(gamedata.daycare); i++) {
                                var animal = gamedata.daycare[i];
                                animal.is_incubating = false;
                            }

                            saver.save_file("gamedata", gamedata);

                            current_version.patch += 1;
                            break;

                        case 4:
                            var player = loader.load_file("player");

                            //
                            //
                            if array_contains(player.recipe_unlocks, "crop_sign_rice") {
                                array_push(player.recipe_unlocks, item_id_to_string(ItemId.CropSignOrange));
                            }
                            if array_contains(player.recipe_unlocks, "crop_sign_beet") {
                                array_push(player.recipe_unlocks, item_id_to_string(ItemId.CropSignPomegranate));
                            }

                            saver.save_file("player", player);

                            current_version.patch += 1;
                            break;

                        case 5:
                            //
                            replace_item_reference("large_mob_coin", loader, saver);
                            replace_item_reference("medium_mob_coin", loader, saver);
                            replace_item_reference("mob_coin", loader, saver);

                            //
                            var player = loader.load_file("player");
                            var header = loader.load_file("header");
                            for (var i = 0; i < array_length(player.presets); i++) {
                                zero_eleven_six_hair_patch(player.presets[i]);
                            }
                            zero_eleven_six_hair_patch(header.preset);

                            saver.save_file("player", player);
                            saver.save_file("header", header);
                            current_version.patch += 1;
                            break;

                        case 7:
                            //
                            var floor_data = {};
                            var wall_data = {};
                            var player = loader.load_file("player");
                            var gamedata = loader.load_file("gamedata");
                            for (var i = 0; i < LocationId.LEN; i++) {
                                if is_home_location(i) {
                                    floor_data[$ location_id_to_string(i)] = {
                                        flooring: "default_v1",
                                        infusion: undefined
                                    }

                                    wall_data[$ location_id_to_string(i)] = {
                                        wallpaper: "default_v1",
                                        door_mold_sprite: "spr_carpenter_house_f2_doorway2_spring",
                                        infusion: undefined
                                    }

                                    if i != LocationId.PlayerHome {
                                        var room_dimensions = room_dimensions(location_id_to_gm_room(i));
                                        var size_x = room_dimensions[0] div 8;
                                        var size_y = room_dimensions[1] div 8;

                                        var grid = {
                                            location_id: location_id_to_string(i),
                                            size_x,
                                            size_y,
                                            inventories: [],
                                            object_list: [],
                                            dyn_index: -1,

                                        }
                                        saver.save_file(location_id_to_string(i), grid);
                                    }
                                }
                            }

                            floor_data[$ location_id_to_string(LocationId.PlayerHome)] = {
                                flooring: player.flooring,
                                infusion: undefined
                            };
                            player.floorings = floor_data;

                            wall_data[$ location_id_to_string(LocationId.PlayerHome)] = {
                                wallpaper: player.wallpaper,
                                door_mold_sprite: "spr_carpenter_house_f2_doorway2_spring",
                                infusion: player.wallpaper_infusion
                            };
                            player.wallpapers = wall_data;

                            if player.size_upgrade {
                                player.size_upgrade = home_upgrade_to_string(HomeUpgrade.Large);
                            } else {
                                player.size_upgrade = home_upgrade_to_string(HomeUpgrade.Small);
                            }

                            //
                            player.home_location = location_id_to_string(LocationId.PlayerHome);

                            //
                            //
                            player.quest_artifacts = {};
                            var old_results = player.festival_results.spring;
                            if array_length(old_results) > 0 {
                                var max_got = 0;
                                for (var i = 0; i < array_length(old_results); i++) {
                                    max_got = max(max_got, old_results[i]);
                                }

                                //
                                var reward = QUESTS.get("the_spring_festival").reward_list.first();
                                var tier = score_to_tier_reward_index(reward, max_got);
                                player.quest_artifacts.spring_festival = {
                                    last_tier: tier,
                                    last_score: max_got,
                                    max_score: max_got,
                                };
                            }

                            replace_object_reference(loader, saver, "breath_of_spring");
                            replace_object_reference(loader, saver, "red_toadstool");

                            if renown_to_level(player.stats.renown) >= 50 {
                                player.crown_cooldown = 0; //
                            } else {
                                player.crown_cooldown = undefined; //
                            }

                            player.has_seen_treasure_level_today = false;
                            player.has_seen_ritual_level_today = false;
                            player.stats.perks_active = array_to_struct(array_create(Perk.LEN, true), perk_to_string);

                            var game_stats = loader.load_file("game_stats");
                            game_stats.animals = [];
                            game_stats.animal_eats = [];
                            game_stats.animal_production = [];
                            game_stats.animal_bead_drops = [];
                            game_stats.animal_eod_statuses = [];
                            game_stats.home_upgrades = [];

                            saver.save_file("player", player);
                            saver.save_file("gamedata", gamedata);
                            saver.save_file("game_stats", game_stats);

                            current_version.patch += 1;
                            break;
                        default:
                            //
                            current_version.patch += 1;
                            break;
                    }
                }

                //
                current_version.minor += 1;
                current_version.patch = 0;
                break;
            case 12:
                while current_version.patch != 5 {
                    switch current_version.patch {
                        case 0:
                            var quest_file = loader.load_file("quests");
                            for (var i = 0; i < array_length(quest_file.active_quests); i++) {
                                var quest = quest_file.active_quests[i];
                                if quest.quest_name == "replenishing_mistrias_food_reserves_1"
                                    && quest.blackboard[$ "count_needed"] != undefined
                                {
                                    quest.blackboard.crop_needed = quest.blackboard.count_needed;
                                }
                            }
                            saver.save_file("quests", quest_file);

                            current_version.patch = 1;
                            break;
                        case 2:
                            var player = loader.load_file("player");
                            if array_contains(player.recipe_unlocks, "star_cushion_yellow") {
                                array_push(player.recipe_unlocks, "star_cushion_blue");
                            }

                            saver.save_file("player", player);
                            current_version.patch = 3;
                            break;
                        case 3:
                            var player = loader.load_file("player");
                            if player.quest_artifacts[$ "spring_festival"] != undefined {
                                var reward = QUESTS.get("the_spring_festival").reward_list.first();
                                var max_score = player.quest_artifacts.spring_festival.max_score;
                                var tier = score_to_tier_reward_index(reward, max_score);
                                if tier >= 3 {
                                    array_push(player.cosmetic_unlocks, "head_special_flower_crown");
                                }
                            }

                            var quests = loader.load_file("quests");

                            saver.save_file("player", player);
                            current_version.patch = 4;
                            break;
                        default:
                            //
                            current_version.patch += 1;
                            break;
                    }
                }

                //
                var player_data = loader.load_file("player");
                var game_data = loader.load_file("gamedata");
                var npcs = loader.load_file("npcs");

                player_data.stats.ancient_inspiration_time = undefined;
                player_data.has_gossiped_today = false;
                player_data.pet_cosmetic_sets_unlocked = [];

                //
                replace_perk_reference(player_data, "treemendous");

                replace_letter_reference(player_data.inbox, "post_repair_the_inn");

                game_data.farm_expanded = false;
                game_data.pending_day_time_speed_change = undefined;
                game_data.day_time_speed = day_time_speed_to_string(DayTimeSpeed.Standard);
                game_data.active_mist_sights = [];

                var pos = array_index(game_data.scene_history, "fire_seal");
                if pos != undefined {
                    array_delete(game_data.scene_history, pos, 1);
                }

                //
                for (var i = 0, c = array_length(game_data.scene_history); i < c; i++) {
                    var cutscene_data = CUTSCENES.get(game_data.scene_history[i]);
                    if cutscene_data == undefined {
                        continue;
                    }
                    for (var j = 0, jc = array_length(cutscene_data.heart_level_changes); j < jc; j++) {
                        var command = cutscene_data.heart_level_changes[j];
                        var npc = npcs[$ npc_id_to_string(command.npc_id)];
                        var heart_points = npc_heart_level_to_points(command.heart_level)
                        if npc.heart_points < heart_points {
                            npc.heart_points = heart_points;
                        }
                    }
                }

                var keys = struct_get_names(npcs);
                for (var i = 0; i < array_length(keys); i++) {
                    var npc = npcs[$ keys[i]];
                    npc.known_gift_preferences = clone_value(npc.gifts_given);
                }

                //
                var temp_calendar = new Calendar();
                temp_calendar.time = int64(real(game_data.date));
                var animal_festival = FESTIVALS[FestivalId.Animal].prototype;
                var animal_festival_time = seasons(animal_festival.date.season)
                    + days(animal_festival.date.day - 1)
                    + years(get_years(temp_calendar.time));
                if temp_calendar.date_is(animal_festival_time) {
                    game_data.cancel_festivals = true;
                }

                //
                if array_contains(player_data.recipe_unlocks, "crop_sign_cabbage") {
                    array_push(player_data.recipe_unlocks, item_id_to_string(ItemId.CropSignTempleFlower));
                }

                //
                if array_contains(player_data.recipe_unlocks, "dragon_altar_earth") {
                    array_push(player_data.recipe_unlocks, item_id_to_string(ItemId.DragonAltarRuins));
                }

                //
                var farm_objects = loader.load_file("farm");
                array_push(farm_objects.object_list, {
                    top_left_y: 26.0,
                    old_terrain: undefined,
                    object_id: "water_blocker",
                    infusion: undefined,
                    destructable: false,
                    top_left_x: 169.0,
                    cardinal_index: 3.0
                });
                array_push(farm_objects.object_list, {
                    top_left_y: 25.0,
                    old_terrain: undefined,
                    object_id: "water_blocker",
                    infusion: undefined,
                    destructable: false,
                    top_left_x: 173.0,
                    cardinal_index: 3.0
                });
                array_push(farm_objects.object_list, {
                    top_left_y: 26.0,
                    old_terrain: undefined,
                    object_id: "water_blocker",
                    infusion: undefined,
                    destructable: false,
                    top_left_x: 175.0,
                    cardinal_index: 3.0
                });

                saver.save_file("farm", farm_objects);
                saver.save_file("player", player_data);
                saver.save_file("npcs", npcs);
                saver.save_file("gamedata", game_data);
                saver.save_file("deep_woods", {});
                saver.save_file("beach_secret", {});
                saver.save_file("narrows_secret", {});
                saver.save_file("mines_entry", {});
                saver.save_file("ruins_seal", {});

                //
                current_version.minor += 1;
                current_version.patch = 0;
                break;

            //
            case 13:
                while current_version.patch != 5 {
                    switch current_version.patch {
                        case 0:
                            //
                            var game_data = loader.load_file("gamedata");
                            for (var i = 0; i < game_data.dynamic_grid_count; i++) {
                                var dyn_name = create_dynamic_grid_file_name(i);
                                var grid_file = loader.has_file(dyn_name)
                                    ? loader.load_file(dyn_name)
                                    : undefined;
                                if grid_file == undefined {
                                    continue;
                                }
                                var location_id = string_to_location_id(grid_file.location_id);
                                switch location_id {
                                    case LocationId.LargeBarn:
                                    case LocationId.LargeCoop:
                                        //
                                        var had_ocarina_sprite_statue_base = array_any(grid_file.object_list, function(value) {
                                            return value.object_id == "ocarina_sprite_statue_base";
                                        });
                                        if had_ocarina_sprite_statue_base == false {
                                            array_push(grid_file.object_list, {
                                                top_left_x: 22.0,
                                                top_left_y: 11.0,
                                                sub_grid_blob: {
                                                    location_id: grid_file.location_id,
                                                    dyn_index: -1.0,
                                                    size_y: 2.0,
                                                    size_x: 2.0,
                                                    inventories: [],
                                                    object_list: []
                                                },
                                                destructable: false,
                                                infusion: undefined,
                                                object_id: "ocarina_sprite_statue_base",
                                                cardinal_index: 3.0,
                                                old_terrain: undefined
                                            });
                                            saver.save_file(dyn_name, grid_file);
                                        }
                                        break;
                                    default:
                                        continue;
                                }
                            }

                            current_version.patch = 1;
                            break;
                        case 1:
                            //
                            replace_item_reference("pet_cosmetic", loader, saver);

                            var player = loader.load_file("player");
                            if array_contains(player.recipe_unlocks, "lava_caves_obsidian_fence_blue")
                                || array_contains(player.recipe_unlocks, "lava_caves_obsidian_fence_purple")
                            {
                                array_push(player.recipe_unlocks, "lava_caves_obsidian_fence_blue");
                                array_push(player.recipe_unlocks, "lava_caves_obsidian_fence_purple");
                            }

                            saver.save_file("player", player);
                            current_version.patch = 2;
                            break;

                        case 2:
                            replace_item_reference("perfect_gift", loader, saver);

                            var player = loader.load_file("player");
                            var gamedata = loader.load_file("gamedata");
                            var town_string = location_id_to_string(LocationId.Town);

                            //
                            //
                            //
                            var recipes_created = array_bool(ItemId.LEN);

                            if gamedata.lost_items[$ town_string] == undefined {
                                gamedata.lost_items[$ town_string] = [];
                            }

                            if renown_to_level(player.stats.renown) >= 70 {
                                //
                                var cap = clamp(renown_to_level(player.stats.renown), 0, 90);
                                for (var i = 70; i < cap; i++) {
                                    var reward = RENOWN.rewards.get(i);
                                    var main_item;

                                    if reward[$ "item"] != undefined {
                                        main_item = new LiveItem(reward.item);
                                    } else if reward[$ "cosmetic"] != undefined {
                                        main_item = new LiveItem(ItemId.Cosmetic);
                                        main_item.cosmetic = reward.cosmetic;
                                    } else {
                                        continue;
                                    }

                                    var recipe = undefined;
                                    if main_item.prototype.tags.contains("furniture")
                                        && !array_contains(player.recipe_unlocks, item_id_to_string(main_item.item_id))
                                        && recipes_created[main_item.item_id] == false
                                    {
                                        recipes_created[main_item.item_id] = true;
                                        recipe = new LiveItem(ItemId.CraftingScroll, main_item.item_id);
                                    }

                                    var items_to_insert = [main_item, recipe];
                                    for (var item_idx = 0; item_idx < array_length(items_to_insert); item_idx++) {
                                        var item = items_to_insert[item_idx];
                                        if item == undefined {
                                            continue;
                                        }
                                        item = item.serialize();

                                        var inserted = false;
                                        for (var j = 0; j < array_length(player.renown_reward_inventory); j++) {
                                            var slot = player.renown_reward_inventory[j];
                                            if array_length(slot.members) == 0 {
                                                array_push(slot.members, item);
                                                inserted = true;
                                                break;
                                            }
                                        }

                                        if !inserted {
                                            array_push(gamedata.lost_items[$ town_string], {
                                                x: 1346,
                                                y: 1712,
                                                items: [item]
                                            });
                                        }
                                    }
                                }
                            }

                            if array_contains(player.recipe_unlocks, "cottage_bed_ash") {
                                array_push(player.recipe_unlocks, "cottage_potted_flowers_ash");
                                array_push(player.recipe_unlocks, "cottage_potted_flowers_oak");
                                array_push(player.recipe_unlocks, "cottage_fridge_ash");
                                array_push(player.recipe_unlocks, "cottage_fridge_oak");
                            }
                            player.morning_recipe_unlocks = clone_value(player.recipe_unlocks);
                            player.recipes_created = clone_value(player.recipe_unlocks);

                            saver.save_file("player", player);
                            saver.save_file("gamedata", gamedata);
                            current_version.patch += 1;
                            break;
                        default:
                            //
                            current_version.patch += 1;
                            break;
                    }
                }

                replace_item_reference("perfect_gift", loader, saver);
                //
                saver.save_file("player_home_upper_central", {});
                saver.save_file("player_home_upper_west", {});
                saver.save_file("player_home_upper_east", {});

                var gamedata = loader.load_file("gamedata");
                gamedata.props.player_home_upper_central = [];
                gamedata.props.player_home_upper_west = [];
                gamedata.props.player_home_upper_east = [];

                var player = loader.load_file("player");
                player.floorings.player_home_upper_central = {
                    infusion: undefined,
                    flooring: "default_v1"
                };
                player.floorings.player_home_upper_west = {
                    infusion: undefined,
                    flooring: "default_v1"
                };
                player.floorings.player_home_upper_east = {
                    infusion: undefined,
                    flooring: "default_v1"
                };

                //
                player.wallpapers.player_home_upper_central = {
                    infusion: undefined,
                    door_mold_sprite: "spr_carpenter_house_f2_doorway2_spring",
                    wallpaper: "default_v1"
                };
                player.wallpapers.player_home_upper_west = {
                    infusion: undefined,
                    door_mold_sprite: "spr_carpenter_house_f2_doorway2_spring",
                    wallpaper: "default_v1"
                };
                player.wallpapers.player_home_upper_east = {
                    infusion: undefined,
                    door_mold_sprite: "spr_carpenter_house_f2_doorway2_spring",
                    wallpaper: "default_v1"
                };

                saver.save_file("dragonsworn_glade", {});

                var quests = loader.load_file("quests");
                replace_quest_reference(quests, gamedata.t2_world_facts, "a_gem_exchange");
                replace_quest_reference(quests, gamedata.t2_world_facts, "pharmacy_restock");

                var time = int64(real(gamedata.date));
                var fall_eight = seasons(Season.Fall) + days(7) + years(get_years(time));
                var fall_ten = seasons(Season.Fall) + days(9) + years(get_years(time));
                if time >= fall_eight && time < fall_ten {
                    array_push(player.inbox, {
                        path: "harvest_festival_patch_case",
                        read: false,
                        items_taken: false,
                    });

                    array_push(quests.active_quests, {
                        quest_name: "the_harvest_festival",
                        task_id: 0,
                        blackboard: {},
                    });
                } else if time == fall_ten {
                    gamedata.cancel_festivals = true;
                }

                player.pronouns = default_pronouns();
                player.pronouns.eng = struct_take(player, "pronoun_choice");
                player.date_history = [];
                player.date_unlocks = [];
                player.upper_floor = false;

                //
                player.has_left_house_today = true;

                gamedata.active_mist_sight = undefined;
                replace_letter_reference(player.inbox, "post_stone_refinery");
                saver.save_file("gamedata", gamedata);
                saver.save_file("player", player);
                saver.save_file("quests", quests);
                saver.save_file("date_photos", { photos: [] });

                current_version.minor += 1;
                current_version.patch = 0;
                break;

            case 14:
                //
                while current_version.patch != 5 {
                    switch current_version.patch {
                        case 0:
                            var player = loader.load_file("player");
                            var npcs = loader.load_file("npcs");
                            var gamedata = loader.load_file("gamedata");
                            for (var i = 0; i < array_length(player.stats.status_effects); i++) {
                                var effect = player.stats.status_effects[i];
                                if !is_nullish(effect) {
                                    effect.stacks = effect[$ "stacks"] ?? 1;
                                }
                            }

                            if array_contains(gamedata.scene_history, "eiland_eight_hearts")
                                && is_nullish(gamedata.t2_world_facts[$ "eiland_status"])
                            {
                                //
                                gamedata.t2_world_facts.eiland_status = "best_friend";

                                if array_contains(gamedata.scene_history, "adeline_eight_hearts") {
                                    //
                                    var should_be_romantic = gamedata.t2_world_facts[$ "adeline_status"] == "romantic"; //

                                    //
                                    //
                                    for (var i = 0; i < array_length(player.date_history); i++) {
                                        if player.date_history[i].npc == "adeline" {
                                            should_be_romantic = true;
                                            break;
                                        }
                                    }

                                    //
                                    static ADELINE_LINES = [
                                        "Conversations/Bank/Adeline/Banked Lines/relationship_basement/adeline_romantic_basement_1",
                                        "Conversations/Bank/Adeline/Banked Lines/relationship_basement/adeline_romantic_basement_2",
                                        "Conversations/Bank/Adeline/Banked Lines/relationship_basement/adeline_romantic_basement_3",
                                        "Conversations/Bank/Adeline/Banked Lines/relationship_basement/adeline_romantic_basement_4",
                                        "Conversations/Bank/Adeline/Banked Lines/relationship_basement/adeline_romantic_basement_5",
                                        "Conversations/Bank/Adeline/Banked Lines/relationship_basement/adeline_romantic_basement_6",
                                        "Conversations/Bank/Adeline/Banked Lines/relationship_basement/adeline_romantic_basement_7",
                                        "Conversations/Bank/Adeline/Banked Lines/relationship_basement/adeline_romantic_basement_8",
                                        "Conversations/Bank/Adeline/Relationship Lines/Relationship/post_8h_lines_romantic/adeline_post_8h_romantic_0",
                                        "Conversations/Bank/Adeline/Relationship Lines/Relationship/post_8h_lines_romantic/adeline_post_8h_romantic_1",
                                        "Conversations/Bank/Adeline/Relationship Lines/Relationship/post_8h_lines_romantic/adeline_post_8h_romantic_2",
                                        "Conversations/Bank/Adeline/Relationship Lines/Relationship/post_8h_lines_romantic/adeline_post_8h_romantic_3",
                                        "Conversations/Bank/Adeline/Relationship Lines/Relationship/post_8h_lines_romantic/adeline_post_8h_romantic_4",
                                        "Conversations/Bank/Adeline/Relationship Lines/Relationship/post_8h_lines_romantic/adeline_post_8h_romantic_5",
                                        "Conversations/Bank/Adeline/Relationship Lines/Relationship/post_8h_lines_romantic/adeline_post_8h_romantic_7",
                                        "Conversations/Bank/Adeline/Relationship Lines/Relationship/post_8h_lines_romantic/adeline_post_8h_romantic_8",
                                        "Conversations/Bank/Adeline/Relationship Lines/Relationship/post_8h_lines_romantic/adeline_post_8h_romantic_9",
                                        "Conversations/Bank/Adeline/Relationship Lines/Relationship/post_8h_lines_romantic/adeline_post_8h_romantic_10",
                                        "Conversations/Bank/Adeline/Relationship Lines/Relationship/post_8h_lines_romantic/adeline_post_8h_romantic_11",
                                        "Conversations/Bank/Adeline/Relationship Lines/Relationship/post_8h_lines_romantic/adeline_post_8h_romantic_question_0",
                                        "Conversations/Bank/Adeline/Relationship Lines/Relationship/post_8h_lines_romantic/adeline_post_8h_romantic_question_1",
                                        "Conversations/Bank/Adeline/Relationship Lines/Relationship/post_8h_lines_romantic/adeline_post_8h_romantic_question_2",
                                        "Cutscenes/Heart Events/Adeline/adeline_eight_hearts/adeline_eight_hearts_follow_up_elsie_romantic",
                                    ];
                                    for (var i = 0; i < array_length(ADELINE_LINES); i++) {
                                        if gamedata.t2_world_facts[$ ADELINE_LINES[i]] == 1 {
                                            should_be_romantic = true;
                                            break;
                                        }
                                    }

                                    if should_be_romantic {
                                        //
                                        gamedata.t2_world_facts.adeline_status = "romantic";
                                    }
                                } else {
                                    //
                                    gamedata.t2_world_facts.adeline_status = undefined;
                                }
                            }

                            saver.save_file("npcs", npcs);
                            saver.save_file("gamedata", gamedata);
                            saver.save_file("player", player);
                            current_version.patch += 1;
                            break;

                        case 1:
                            var player = loader.load_file("player");
                            var quests = loader.load_file("quests");
                            var gamedata = loader.load_file("gamedata");
                            var npcs = loader.load_file("npcs");

                            //
                            for (var i = 0; i < array_length(player.inbox); i++) {
                                var letter = player.inbox[i];
                                var proto = LETTERS.get(letter.path);
                                if !proto.items.is_empty() && letter.read && !letter.items_taken {
                                    letter.items_taken = true;
                                    for (var j = 0; j < proto.items.count(); j++) {
                                        var item = proto.items.get(j);
                                        if item[$ "recipe"] != undefined {
                                            var proto_live_item = new LiveItem(ItemId.RecipeScroll, item.recipe);
                                            var count = 1;
                                        } else {
                                            var proto_live_item = new LiveItem(item.item);
                                            var count = item.count;
                                        }
                                        var packed_array = array_create(count, undefined);
                                        for (var k = 0; k < count; k++) {
                                            packed_array[k] = proto_live_item.serialize();
                                        }
                                        if gamedata.lost_items[$ "farm"] == undefined {
                                            gamedata.lost_items.farm = [];
                                        }
                                        array_push(gamedata.lost_items.farm, {
                                            x: 890,
                                            y: 304,
                                            items: packed_array,
                                        });
                                    }
                                }
                            }

                            if array_contains(player.recipe_unlocks, "crop_sign_cabbage") && array_contains(player.recipe_unlocks, "crop_sign_mystery_bag") == false {
                                array_push(player.recipe_unlocks, "crop_sign_mystery_bag");
                            }

                            //
                            replace_quest_reference(quests, gamedata.t2_world_facts, "the_saturday_market_committee_election");
                            replace_quest_reference(quests, gamedata.t2_world_facts, "sweet_memories");
                            replace_quest_reference(quests, gamedata.t2_world_facts, "josephines_strays");
                            replace_quest_reference(quests, gamedata.t2_world_facts, "a_new_blend");
                            replace_quest_reference(quests, gamedata.t2_world_facts, "a_mysterious_treasure");
                            replace_quest_reference(quests, gamedata.t2_world_facts, "happy_anniversary");
                            replace_quest_reference(quests, gamedata.t2_world_facts, "olrics_super_normal_dilemma");
                            replace_quest_reference(quests, gamedata.t2_world_facts, "a_fine_discovery");
                            replace_quest_reference(quests, gamedata.t2_world_facts, "the_big_one");
                            replace_quest_reference(quests, gamedata.t2_world_facts, "a_heartfelt_apology");
                            replace_quest_reference(quests, gamedata.t2_world_facts, "dark_omens");

                            npcs.caldarus.outfit = string_replace(npcs.caldarus.outfit, "human_", "");

                            //
                            for (var npc_id = 0; npc_id < NpcId.LEN; npc_id++) {
                                var key = format("{}_birthday", npc_id);
                                gamedata.t2_world_facts[$ key] = T2R.read(key);
                            }

                            saver.save_file("player", player);
                            saver.save_file("quests", quests);
                            saver.save_file("gamedata", gamedata);
                            saver.save_file("npcs", npcs);

                            current_version.patch += 1;
                            break;

                        case 4:
                            replace_object_reference(loader, saver, "witch_queen_bed", "witch_queen_bed_v1");
                            replace_object_reference(loader, saver, "witch_queen_double_bed", "witch_queen_double_bed_v1");
                            replace_object_reference(loader, saver, "witch_queen_cauldron", "witch_queen_cauldron_v1");
                            replace_object_reference(loader, saver, "witch_queen_chair", "witch_queen_chair_v1");
                            replace_object_reference(loader, saver, "witch_queen_dressing_table", "witch_queen_dressing_table_v1");
                            replace_object_reference(loader, saver, "witch_queen_moon_lamp", "witch_queen_moon_lamp_v1");
                            replace_object_reference(loader, saver, "witch_queen_nightstand", "witch_queen_nightstand_v1");
                            replace_object_reference(loader, saver, "witch_queen_pillar", "witch_queen_pillar_v1");
                            replace_object_reference(loader, saver, "witch_queen_rug", "witch_queen_rug_v1");
                            replace_object_reference(loader, saver, "witch_queen_table", "witch_queen_table_v1");
                            replace_object_reference(loader, saver, "witch_queen_throne", "witch_queen_throne_v1");

                            replace_item_reference("witch_queen_bed", loader, saver, "witch_queen_bed_v1");
                            replace_item_reference("witch_queen_double_bed", loader, saver, "witch_queen_double_bed_v1");
                            replace_item_reference("witch_queen_cauldron", loader, saver, "witch_queen_cauldron_v1");
                            replace_item_reference("witch_queen_chair", loader, saver, "witch_queen_chair_v1");
                            replace_item_reference("witch_queen_dressing_table", loader, saver, "witch_queen_dressing_table_v1");
                            replace_item_reference("witch_queen_moon_lamp", loader, saver, "witch_queen_moon_lamp_v1");
                            replace_item_reference("witch_queen_nightstand", loader, saver, "witch_queen_nightstand_v1");
                            replace_item_reference("witch_queen_pillar", loader, saver, "witch_queen_pillar_v1");
                            replace_item_reference("witch_queen_rug", loader, saver, "witch_queen_rug_v1");
                            replace_item_reference("witch_queen_table", loader, saver, "witch_queen_table_v1");
                            replace_item_reference("witch_queen_throne", loader, saver, "witch_queen_throne_v1");
                            replace_item_reference("witch_queen_flooring", loader, saver, "witch_queen_flooring_v1");
                            replace_item_reference("witch_queen_wallpaper", loader, saver, "witch_queen_wallpaper_v1");
                            current_version.patch += 1;
                            break;

                        default:
                            //
                            current_version.patch += 1;
                            break;
                    }
                }

                //
                saver.save_file("priestess_quarters", {});
                saver.save_file("void_seal", {});
                var player = loader.load_file("player");
                player.lost_and_found = Inventory(54).serialize();
                player.pet_skin_unlocks = [];
                saver.save_file("player", player);
                var game_data = loader.load_file("gamedata");
                game_data.seals.priestess = Inventory(4).serialize();
                game_data.seals.void = Inventory(4).serialize();
                game_data.seals.ruins = Inventory(4).serialize();
                game_data.seals.final = Inventory(4).serialize();

                for (var i = 0; i < game_data.dynamic_grid_count; i++) {
                    var dyn_name = create_dynamic_grid_file_name(i);
                    var grid_file = loader.has_file(dyn_name)
                        ? loader.load_file(dyn_name)
                        : undefined;
                    if grid_file == undefined {
                        continue;
                    }
                    var location_id = string_to_location_id(grid_file.location_id);
                    if matches(location_id, LocationId.LargeBarn, LocationId.LargeCoop) {
                        for (var j = 0; j < array_length(grid_file.object_list); j++) {
                            var obj = grid_file.object_list[j];
                            if obj.object_id == "stable_storage_chest" {
                                obj.top_left_x = 34.0;
                                break;
                            }
                        }
                    }

                    if matches(location_id, LocationId.LargeBarn, LocationId.LargeCoop) {
                        array_push(grid_file.object_list, {
                            top_left_x: 38.0,
                            top_left_y: location_id == LocationId.LargeBarn ? 38.0 : 34.0,
                            sub_grid_blob: {
                                location_id: grid_file.location_id,
                                dyn_index: -1.0,
                                size_y: 2.0,
                                size_x: 2.0,
                                inventories: [],
                                object_list: []
                            },
                            destructable: false,
                            infusion: undefined,
                            object_id: "auto_feeder_platform",
                            cardinal_index: 3.0,
                            old_terrain: undefined
                        });
                        saver.save_file(dyn_name, grid_file);
                    }
                }

                saver.save_file("gamedata", game_data);

                current_version.minor += 1;
                current_version.patch = 0;
                break;

            case 15:
                //
                while current_version.patch < 4 {
                    switch current_version.patch {
                        case 1:
                            var player = loader.load_file("player");
                            player.has_seen_arena_level_today = false;
                            saver.save_file("player", player);

                            //
                            replace_item_reference("large_mob_coin", loader, saver);
                            replace_item_reference("medium_mob_coin", loader, saver);
                            replace_item_reference("mob_coin", loader, saver);
                            replace_item_reference("tree_coin", loader, saver);
                            current_version.patch += 1;
                            break;
                        default:
                            //
                            current_version.patch += 1;
                            break;
                    }
                }

                //
                var gamedata = loader.load_file("gamedata");
                for (var i = 0; i < NpcId.LEN; i++) {
                    var status = gamedata.t2_world_facts[$ format("{NpcId}_status", i)];
                    if status == "romantic" {
                        status = "dating";
                        gamedata.t2_world_facts[$ format("{NpcId}_status", i)] = status;
                    }
                    gamedata.t2_world_facts[$ format("{NpcId}_is_best_friend", i)] = status == "best_friend";
                    gamedata.t2_world_facts[$ format("{NpcId}_is_dating", i)] = status == "dating";
                    gamedata.t2_world_facts[$ format("{NpcId}_is_spouse", i)] = false;
                    gamedata.t2_world_facts[$ format("{NpcId}_is_fiance", i)] = false;
                    gamedata.t2_world_facts[$ format("{NpcId}_is_partner", i)] = status == "dating";
                }
                saver.save_file("gamedata", gamedata);

                current_version.minor += 1;
                current_version.patch = 0;
                break;
            case 16:
                while current_version.patch < 4 {
                    switch current_version.patch {
                        case 0:
                        case 1:
                            //
                            var player = loader.load_file("player");
                            replace_perk_reference(player, "playtime_one");
                            saver.save_file("player", player);
                            current_version.patch += 1;
                            break;
                        default:
                            //
                            current_version.patch += 1;
                            break;
                    }
                }

                replace_item_reference("rock_clod_garden_purple", loader, saver);

                var player = loader.load_file("player");
                var game_stats = loader.load_file("game_stats");
                var gamedata = loader.load_file("gamedata");
                var npcs = loader.load_file("npcs");

                //
                //
                //
                var eng = player.pronouns.eng;
                player.pronouns = default_pronouns();
                player.pronouns.eng = eng;

                //
                game_stats.gross_essence = player.stats.essence;
                var toml_data = fiddle_get_directory("ui/skill_menu");
                var keys = struct_get_names(toml_data);
                var a = 0;
                for (var i = 0; i < array_length(keys); i++) {
                    var prototype = toml_data[keys[i]];
                    for (var j = 0; j < 5; j++) {
                        var tier = prototype[$ fmt("tier_{}", j + 1)];
                        if tier == undefined {
                            continue;
                        }
                        for (var k = 0; k < array_length(tier); k++) {
                            var entry = tier[k];
                            if entry["perk"] != undefined && array_contains(player.perks, entry.perk) {
                                game_stats.gross_essence += entry["essence"] ?? 0;
                            }
                        }
                    }
                }

                //
                static YEAR_ONE_PER_SEASON = 25000;
                static YEAR_TWO_PER_SEASON = 70000;
                static YEAR_PLUS_PER_SEASON = 200000;
                var time = int64(real(gamedata.date));
                var season_count = time / seasons(1);
                var year_one_earnings = min(4, season_count) * YEAR_ONE_PER_SEASON;
                var year_two_earnings = max(0, season_count - 4) * YEAR_ONE_PER_SEASON;
                var additional_earnings = max(0, season_count - 8) * YEAR_PLUS_PER_SEASON;
                var gold = round(year_one_earnings + year_two_earnings + additional_earnings);
                array_push(
                    game_stats.income,
                    {
                        type: "ea_compensation",
                        amount: gold,
                        day: 0,
                    }
                );

                //
                //
                //
                var keys = struct_get_names(npcs);
                game_stats.gifts_given = [];
                for (var i = 0; i < array_length(keys); i++) {
                    var npc_data = npcs[keys[i]];
                    var prototype = NPC_PROTOTYPES[string_to_npc_id(keys[i])];
                    var gave_any_liked = false;
                    var gave_any_loved = false;
                    for (var j = 0; j < array_length(npc_data.known_gift_preferences); j++) {
                        var pref = string_to_item_id(npc_data.known_gift_preferences[j]);
                        var liked = prototype.loved_gifts.contains(pref);
                        var loved = prototype.liked_gifts.contains(pref);
                        gave_any_liked |= liked;
                        gave_any_loved |= loved;
                        if liked || loved {
                            repeat 2 {
                                array_push(game_stats.gifts_given, {
                                    npc: keys[i],
                                    gift: npc_data.known_gift_preferences[j],
                                    desire: liked ? "liked" : "loved",
                                    day: 0,
                                });
                            }
                        }
                    }

                    //
                    var four_hearts = fiddle_get("misc/npc_heart_point_table")[3];
                    if npc_data.heart_points >= four_hearts && gave_any_liked && gave_any_loved {
                        gamedata.t2_world_facts[format("gave_{}_good_birthday_gift", keys[i])] = true;
                    }
                }

                //
                //
                //
                //
                for (var i = 0; i < array_length(game_stats.bedtimes); i++) {
                    var bedtime = game_stats.bedtimes[i];
                    if string_pos("1:5", bedtime) != 0 && string_pos("am", bedtime) != undefined {
                        gamedata.t2_world_facts["slept_last_minute"] = true;
                        break;
                    }
                }

                //
                gamedata.t2_world_facts.has_ever_fainted = gamedata.t2_world_facts["cutscene_seen_dying"] == true;

                saver.save_file("player", player);
                saver.save_file("game_stats", game_stats);
                saver.save_file("gamedata", gamedata);
                saver.save_file("npcs", npcs);

                current_version.major = 1;
                current_version.minor = 0;
                current_version.patch = 0;
                break;

            default: impossible("unhandled minor version in saves: {} of {SemVer}", current_version.minor, current_version);
        }
    }
}

function apply_settings_patches(current_version, goal_version, settings) {
    trace("Transforming settings from {SemVer} -> {SemVer}", current_version, goal_version);
    var old_current_version = clone_value(current_version);

    //
    while current_version.major != 1 {
        patch_early_access_settings(current_version, goal_version, settings);
    }

    //
    while current_version.minor != goal_version.minor {
        switch current_version.minor {
            default: break;
        }
        current_version.minor += 1;
        current_version.patch = 0;
    }

    //
    while current_version.patch != goal_version.patch {
        switch current_version.patch {
            default: break;
        }

        current_version.patch += 1;
    }

    trace("Transforming settings from version: {SemVer} to {SemVer}", old_current_version, current_version);

    return settings;
}

function patch_early_access_settings(current_version, goal_version, settings) {
    //
    while current_version.major != 1 {
        switch current_version.minor {
            case 0:
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9:
            case 10:
                settings = MapWrap(get_default_settings());
                break;
            case 11:
                var found_left_stick = false;
                var keys = struct_get_names(settings.inner.bindings);
                for (var i = 0; i < array_length(keys); i++) {
                    var key = keys[i];
                    //
                    if key == "last_toolbar_tab" {
                        continue;
                    }
                    var bindings_array = settings.inner.bindings[$ keys[i]];

                    for (var k = 0; k < array_length(bindings_array); k++) {
                        var binding = bindings_array[k];
                        if binding == gp_stickl {
                            found_left_stick = true;
                            break;
                        }
                    }

                    if found_left_stick {
                        break;
                    }
                }

                if found_left_stick {
                    settings.inner.bindings[$ "ride"] = [vk_equals, -1, -1, -1];
                } else {
                    var toolbar_bindings = settings.inner.bindings[$ "last_toolbar_tab"];
                    if toolbar_bindings[2] == gp_stickl {
                        toolbar_bindings[2] = -1;
                    }
                    if toolbar_bindings[3] == gp_stickl {
                        toolbar_bindings[3] = -1;
                    }

                    settings.inner.bindings[$ "ride"] = [vk_equals, -1, gp_stickl, -1];
                }
                break;
            case 12:
            case 13:
            case 14:
            case 15:
                break;
            case 16:
                //
                //
                current_version.major = 1;
                current_version.minor = 0;
                current_version.patch = 0;
                return;

            default: impossible("unhandled minor version in settings: {} of {SemVer}", current_version.minor, current_version);
        }

        current_version.minor += 1;
        current_version.patch = 0;
    }

    //
    while current_version.patch != goal_version.patch {
        switch current_version.patch {
            default:
                //
                current_version.patch += 1;
                break;
        }
    }

}

function patch_save(loader) {
    var info = loader.load_file("info");

    //
    if info.version[$ "pre"] == undefined {
        info.version.pre = undefined;
    }

    var save_is_valid = versions_match(GAME_VERSION, info.version) || TEST_SUITE;
    if save_is_valid {
        return true;
    }

    if version_is_ahead(info.version, GAME_VERSION) {
        return false;
    }

    try {
        trace("Updating save `{}` from `{SemVer}` to `{SemVer}`", loader.save_path, info.version, GAME_VERSION);
        var saver = apply_save_patches(info.version, GAME_VERSION, loader);
        if saver != undefined {
            return saver.save_to_disk(info);
        } else {
            return false;
        }
    } catch(e) {
        if DEBUG_ASSERTIONS {
            crash("failed to patch a save file! {}", e);
        } else {
            error("failed to patch a save file! {}", e);
        }
        return false;
    }
}

//
//
function replace_letter_reference(player_inbox, old_key, new_key) {
    var found = false;
    for (var i = array_length(player_inbox) - 1; i >= 0; i--) {
        var letter = player_inbox[i];
        if letter.path == old_key {
            if new_key == undefined {
                array_delete(player_inbox, i, 1);
            } else {
                letter.path = new_key;
            }
            found = true;
        }
    }
    return found;
}

//
//
function replace_quest_reference(quest_log, t2_world_facts, old_key, new_key) {
    var removal = {
        completion_timestamp: undefined,
        completed: false,
        active: undefined,
        read_on_board: false,
        manually_unlocked: false,
    }

    //
    var keys = struct_get_names(quest_log.completion_timestamps);
    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];
        if key == old_key {
            removal.completion_timestamp = quest_log.completion_timestamps[$ old_key];
            struct_remove(quest_log.completion_timestamps, old_key);
        }
    }

    //
    for (var i = array_length(quest_log.completed_quests) - 1; i >= 0; i--) {
        var quest_name = quest_log.completed_quests[i];
        if quest_name == old_key {
            array_delete(quest_log.completed_quests, i, 1);
            removal.completed = true;
        }
    }

    //
    for (var i = array_length(quest_log.manual_quest_unlocks) - 1; i >= 0; i--) {
        var quest_name = quest_log.manual_quest_unlocks[i];
        if quest_name == old_key {
            array_delete(quest_log.manual_quest_unlocks, i, 1);
            removal.manually_unlocked = true;
        }
    }

    //
    for (var i = array_length(quest_log.request_board_read_entries) - 1; i >= 0; i--) {
        var quest_name = quest_log.request_board_read_entries[i];
        if quest_name == old_key {
            array_delete(quest_log.request_board_read_entries, i, 1);
            removal.read_on_board = true;
        }
    }

    //
    for (var i = array_length(quest_log.active_quests) - 1; i >= 0; i--) {
        var quest_blob = quest_log.active_quests[i];
        if quest_blob.quest_name == old_key {
            removal.active = quest_blob;
            array_delete(quest_log.active_quests, i, 1);
        }
    }

    //
    var old_names = [
        format("quest_{}_complete", old_key),
        format("quest_{}_in_progress", old_key),
    ];
    var new_names = [
        format("quest_{}_complete", new_key),
        format("quest_{}_in_progress", new_key),
    ]
    var wf_keys = struct_get_names(t2_world_facts);
    for (var i = 0; i < array_length(wf_keys); i++) {
        var key = wf_keys[i];
        for (var j = 0; j < array_length(old_names); j++) {
            if key == old_names[j] {
                var old_value = t2_world_facts[$ key];
                struct_remove(t2_world_facts, key);
                if new_key != undefined {
                    t2_world_facts[$ new_names[j]] = old_value;
                }
            }
        }
    }

    //
    if new_key != undefined {
        if removal.completion_timestamp != undefined {
            quest_log.completion_timestamps[$ new_key] = removal.completion_timestamp;
        }
        if removal.completed {
            array_push(quest_log.completed_quests, new_key);
        }
        if removal.active != undefined {
            removal.active.quest_name = new_key;
            array_push(quest_log.active_quests, removal.active);
        }
        if removal.read_on_board {
            array_push(quest_log.request_board_read_entries, new_key);
        }
        if removal.manually_unlocked {
            array_push(quest_log.manual_quest_unlocks, new_key);
        }
    }

    return removal;
}

function replace_object_reference(loader, saver, old_key, new_key) {
    static CHECK_GRID = function(grid_name, loader, saver, old_key, new_key) {
        var file = loader.load_file(grid_name);
        replace_object_reference_in_grid(file, old_key, new_key);
        saver.save_file(grid_name, file);
    }

    var dyn_grid_count = loader.load_file("gamedata").dynamic_grid_count;

    for (var i = 0; i < dyn_grid_count; i++) {
        var dyn_name = create_dynamic_grid_file_name(i);
        if loader.has_file(dyn_name) {
            CHECK_GRID(dyn_name, loader, saver, old_key, new_key);
        }
    }

    for (var i = 0; i < LocationId.LEN; i++) {
        var grid_name = location_id_to_string(i);
        if loader.has_file(grid_name) {
            CHECK_GRID(grid_name, loader, saver, old_key, new_key);
        }
    }
}

function replace_object_reference_in_grid(grid, old_key, new_key) {
    //
    if grid[$ "object_list"] == undefined {
        return;
    }

    for (var i = 0; i < array_length(grid.object_list); i++) {
        var object = grid.object_list[i];
        if object.object_id == old_key {
            if new_key == undefined {
                array_delete(grid.object_list, i, 1);
                i -= 1;
            } else {
                object.object_id = new_key;
            }
        }
        if object[$ "sub_grid_blob"] != undefined {
            replace_object_reference_in_grid(object.sub_grid_blob, old_key, new_key);
        }
    }
}

function replace_perk_reference(player, old_key, new_key) {
    if player.stats[$ "perks_active"] == undefined {
        player.stats.perks_active = array_to_struct(array_create(Perk.LEN, true), perk_to_string);
    }

    var old_val = player.stats.perks_active[$ old_key];
    if new_key != undefined {
        player.stats.perks_active[$ new_key] = old_val;
    }
    struct_remove(player.stats.perks_active, old_key);

    var pos = array_index(player.perks, old_key);
    if pos != undefined {
        array_delete(player.perks, pos, 1);
    }
    if new_key != undefined {
        array_push(player.perks, new_key);
    }
}

function patch_default_content(player) {
    for (var i = 0; i < AnimalKind.LEN; i++) {
        var animal = ANIMAL_PROTOTYPES[i];
        var unlocks = player.animal_variant_unlocks[$ animal_kind_to_string(i)];
        var keys = animal.variants.keys();
        for (var j = 0; j < array_length(keys); j++) {
            if animal.variants.get(keys[j]).default_unlocked && !array_contains(unlocks, keys[j]) {
                array_push(unlocks, keys[j]);
            }
        }
    }

    for (var i = 0; i < ItemId.LEN; i++) {
        var recipe = ITEM_PROTOTYPES[i].recipe;
        var item = item_id_to_string(i);
        if recipe != undefined && recipe.is_default && !array_contains(player.recipe_unlocks, item) {
            array_push(player.recipe_unlocks, item);
        }
    }

    var default_cosmetics = default_cosmetic_unlocks().keys();
    for (var i = 0; i < array_length(default_cosmetics); i++) {
        if !array_contains(player.cosmetic_unlocks, default_cosmetics[i]) {
            array_push(player.cosmetic_unlocks, default_cosmetics[i]);
        }
    }
}

//
function zero_eleven_six_hair_patch(preset) {
    for (var i = 0; i < array_length(preset.assets); i++) {
        var asset = preset.assets[i];
        var database_asset = PLAYER_ANIMATION_DATABASE.player_assets.get(asset.name);
        if database_asset.ui_slot == ParUiSlot.Hair {
            if asset.lut_index > 30 {
                asset.lut_index += 10;
            } else if asset.lut_index > 25 {
                asset.lut_index += 5;
            }
        }
    }
}
