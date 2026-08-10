#macro QUEST_LOG global.__quest_log
global.__quest_log = undefined;

function QuestLog() constructor {
    self.active = Map();
    self.completed = HashSet();
    self.completion_timestamps = Map();

    //
    self.blackboard = Map();

    //
    function start(quest_name, target_stage=0) {
        var quest = QUESTS.get_unwrap(quest_name);

        //
        T2R.write("quest_last_started_at_time", CLOCK.time);
        T2R.write(format("quest_{}_in_progress", quest_name), true);
        T2R.write(format("quest_{}_complete", quest_name), false);

        var active_quest = new ActiveQuest(quest, quest_name, target_stage);

        for (var i = 0; i <= target_stage; i++) {
            active_quest.initialize_requirements_on_task(i);
        }

        self.active.insert(quest_name, active_quest);

        return true;
    }

    //
    function complete(quest_name) {
        var finished_quest = self.active.get(quest_name);
        if finished_quest == undefined || finished_quest.current_stage < finished_quest.quest.tasks.count() {
            return undefined;
        }

        T2R.write(format("quest_{}_in_progress", quest_name), false);
        T2R.write(format("quest_{}_complete", quest_name), true);

        //
        self.active.remove(quest_name);
        self.completed.insert(quest_name);
        self.completion_timestamps.insert(quest_name, CALENDAR.time);
        REQUEST_BOARD_READ_ENTRIES.remove(quest_name); //

        //
        var quest_gives_renown = finished_quest.quest.reward_list.any(function(reward) {
            return reward.type == QuestRewardType.Renown;
        });
        if quest_gives_renown {
            ARI.pending_renown_entries.push(RenownEntry.Quest(quest_name));
        }

        refresh_achievements([Requirement.CompletedQuest, Requirement.CompletedQuestsInCategory]);

        return finished_quest;
    }
}

function ActiveQuest(quest, quest_name, current_stage=0) constructor {
    //
    self.quest = quest;
    self.quest_name = quest_name;
    self.blackboard = Map();
    self.current_stage = current_stage;

    //
    //
    //
    function progress() {
        var task = self.quest.tasks.get(self.current_stage);

        //
        grant_quest_rewards(task.reward_list);

        for (var i = 0; i < Requirement.LEN; i++) {
            var requirement = task.requirements[i];
            if requirement == undefined {
                continue;
            }

            switch i {
                case Requirement.HasItem:
                    for (var j = 0; j < array_length(requirement); j++) {
                        var this_item = requirement[j];
                        ARI.inventory.remove(this_item[0], this_item[1]);
                    }
                    break;
                case Requirement.HasGold:
                    array_push(GAME_STATS.purchases, {
                        type: "quest_turn_in",
                        cost: requirement,
                        day: total_days(),
                    });
                    ARI.modify_gold(-requirement);
                    break;
                case Requirement.SuppliedItems:
                    for (var j = 0; j < array_length(requirement); j++) {
                        var this_req = requirement[j];

                        if this_req.type == SupplyType.Chest {
                            var point = trellis_point_location_position(this_req.point);
                            var grid = GRIDS[point.location_id];
                            var ni = grid.node_index_for_cell(point.pos.x div 8, point.pos.y div 8);
                            var chest = grid.node_parent[ni].inventory;

                            for (var i = 0; i < ItemId.LEN; i++) {
                                var count = this_req.items[i];
                                if count == 0 {
                                    continue;
                                }
                                chest.remove(i, count)
                            }

                            erase_object_node(grid, ni);
                        }
                    }
                    break;
                case Requirement.Custom:
                    if requirement[$ "submit_animal"] != undefined {
                        for (var j = 0; j < AnimalSize.LEN; j++) {
                            var idx = ARI.quest_artifacts.try_take(format("festival_selected_{AnimalSize}_animal", j));
                            var animal = opt_and_then(idx, function(idx) {
                                return find_animal(idx, true);
                            });
                            var animal_score = 0;
                            var tier = 0;
                            var placeable = undefined;
                            var cosmetic = undefined;
                            if animal != undefined {
                                animal_score = animal_festival_score(animal.tier(), points_to_animal_heart_level(animal.heart_points));
                                tier = score_to_tier_reward_index(QUESTS.get("the_animal_festival").reward_list.first(), animal_score);
                                animal.festival_tier = max(animal.festival_tier ?? 0, tier);

                                var all_prizes = fiddle_get(format("misc/{AnimalSize}_animal_festival_rewards", j));
                                var our_prizes = all_prizes[tier];
                                if our_prizes[$ "placeable"] != undefined {
                                    placeable = { item: format(our_prizes.placeable, animal.kind) };
                                }
                                if our_prizes[$ "cosmetic"] != undefined {
                                    cosmetic = {
                                        animal: animal_kind_to_string(animal.kind),
                                        animal_cosmetic: format(our_prizes.cosmetic, animal.kind)
                                    };
                                    if ari_has_animal_cosmetic_anywhere(animal.kind, cosmetic.animal_cosmetic) {
                                        cosmetic = undefined;
                                    }
                                }
                            }
                            T2R.write(format("{AnimalSize}_animal_place", j), tier);
                            ARI.quest_artifacts.insert(format("festival_{AnimalSize}_placeable", j), placeable);
                            ARI.quest_artifacts.insert(format("festival_{AnimalSize}_cosmetic", j), cosmetic);
                            ARI.quest_artifacts.insert(
                                format("festival_{AnimalSize}_animal_score", j),
                                { last_tier: tier },
                            );
                        }
                    } else if requirement[$ "gather"] != undefined {
                        var item = string_to_item_id(requirement.gather.item);
                        var player_score = total_item_count(item);
                        remove_item_from_world(item);

                        //
                        var tier = undefined;
                        for (var j = 0; j < self.quest.reward_list.count(); j++) {
                            var reward = self.quest.reward_list.get(j);
                            if reward.type == QuestRewardType.Tiers {
                                tier = score_to_tier_reward_index(reward, player_score, ARI);
                                break;
                            }
                        }
                        assert_neq(tier, undefined, "Failed to find a tier reward for {}", self.quest_name);

                        var artifact = ARI.ensure_quest_artifact(requirement.gather.artifact_key);
                        artifact.last_tier = tier;
                        artifact.last_score = player_score;
                        artifact.max_score = max(artifact.max_score, player_score);
                    }
                    break;
                default: break;
            }
        }

        self.current_stage += 1;

        if self.current_stage >= self.quest.tasks.count() {
            return ProgressOutput.Complete;
        }

        self.initialize_requirements_on_task(self.current_stage);

        return ProgressOutput.NextStage;
    }

    //
    //
    //
    function handle_progress_output(output) {
        if output == ProgressOutput.Complete {
            QUEST_LOG.complete(self.quest_name);

            if self.quest.reward_list.is_empty() {
                var raw = format("{Local}:\n{Local}", "misc_local/quest_completed", self.quest.name);
                create_notification(ANCHOR.wrap_for_local(raw));
            } else {
                await_popup(create_quest_complete_popup, [self]);
            }

            if self.quest.post_complete_tutorial != undefined {
                await_popup(spawn_tutorial, [self.quest.post_complete_tutorial]);
            }
        }
    }

    //
    //
    //
    //
    function initialize_requirements_on_task(task_index) {
        var task = self.quest.tasks.get(task_index);

        for (var i = 0; i < Requirement.LEN; i++) {
            var requirement = task.requirements[i];
            if requirement == undefined {
                continue;
            }

            switch i {
                case Requirement.SuppliedItems:
                    for (var j = 0; j < array_length(requirement); j++) {
                        var this_req = requirement[j];
                        if this_req.type != SupplyType.Chest {
                            continue;
                        }

                        var point = trellis_point_location_position(this_req.point);

                        var output = GRIDS[point.location_id].write_node(point.pos.x div 8, point.pos.y div 8, ObjectId.TurnInBox);

                        //
                        //
                        //
                        if output == undefined {
                            var ni = GRIDS[point.location_id].node_index_for_cell(point.pos.x div 8, point.pos.y div 8);
                            assert_eq(GRIDS[point.location_id].node_object_id[ni], ObjectId.TurnInBox);
                            assert_eq(GRIDS[point.location_id].node_parent[ni].quest_id, self.quest_name);
                        } else {
                            output.quest_id = self.quest_name;
                        }
                    }
                    break;
                case Requirement.ShippedTag:
                    for (var j = 0; j < array_length(requirement); j++) {
                        self.blackboard.insert(
                            format("{}_needed", requirement[j][0]),
                            ARI.times_item_tag_sold(requirement[j][0]) + requirement[j][1],
                        );
                    }
                    break;
                case Requirement.ShippedItem:
                    for (var j = 0; j < array_length(requirement); j++) {
                        self.blackboard.insert(
                            format("{ItemId}_needed", requirement[j][0]),
                            ARI.items_sold[requirement[j][0]] + requirement[j][1],
                        );
                    }
                    break;
                case Requirement.DefeatedMonster:
                    for (var j = 0; j < array_length(requirement); j++) {
                        self.blackboard.insert(
                            format("{MonsterCategory}_needed", requirement[j][0]),
                            ARI.monsters_killed(requirement[j][0]) + requirement[j][1],
                        );
                    }
                    break;
            }
        }
    }
}

function fulfills_all_requirements(requirements, quest_blackboard) {
    for (var i = 0; i < Requirement.LEN; i++) {
        var requirement = requirements[i];
        if requirement == undefined {
            continue;
        }

        //
        switch i {
            case Requirement.ShippedTag:
                for (var j = 0; j < array_length(requirement); j++) {
                    var this_item = requirement[j];
                    if ARI.times_item_tag_sold(this_item[0]) < quest_blackboard.get(format("{}_needed", this_item[0])) {
                        return false;
                    }
                }
                break;
            case Requirement.ShippedItem:
                for (var j = 0; j < array_length(requirement); j++) {
                    var this_item = requirement[j];
                    if ARI.items_sold[this_item[0]] < quest_blackboard.get(format("{ItemId}_needed", this_item[0])) {
                        return false;
                    }
                }
                break;
            case Requirement.DefeatedMonster:
                for (var j = 0; j < array_length(requirement); j++) {
                    var this_cat = requirement[j];
                    if ARI.monsters_killed(this_cat[0]) < quest_blackboard.get(format("{MonsterCategory}_needed", this_cat[0])) {
                        return false;
                    }
                }
                break;
            case Requirement.Custom: break;
            default:
                if requirement_field_is_array(i) && array_is_empty(requirement) {
                    continue;
                }
                if !REQ_CHECK[i](requirement) {
                    return false;
                }
                break;
        }
    }
    return true;
}

//
//
//
function grant_quest_rewards(reward_list) {
    var output = List();

    for (var i = 0, c = reward_list.count(); i < c; i++) {
        var reward = reward_list.get(i);

        if reward.type == QuestRewardType.PlayerCosmetic {
            if !ari_has_cosmetic_anywhere(reward.cosmetic) {
                output.push(reward);
            }
        } else if reward.type != QuestRewardType.Tiers {
            output.push(reward);
        }

        switch reward.type {
            case QuestRewardType.Item:
                ARI.give_item(reward.item, reward.amount);
                break;
            case QuestRewardType.Gold:
                ARI.modify_gold(reward.amount);
                array_push(GAME_STATS.income, {
                    type: "quest_reward",
                    amount: reward.amount,
                    day: total_days(),
                });
                break;
            case QuestRewardType.Quest:
                QUEST_LOG.start(reward.quest_name);
                break;
            case QuestRewardType.RecipeScroll:
                var item = new LiveItem(ItemId.RecipeScroll, reward.item);
                ARI.give_item(item);
                break;
            case QuestRewardType.CraftingScroll:
                var item = new LiveItem(ItemId.CraftingScroll, reward.item);
                ARI.give_item(item);
                break;
            case QuestRewardType.Tiers:
                var artifact = ARI.ensure_quest_artifact(reward.artifact_key);
                var tier = artifact == undefined ? 0 : artifact.last_tier;
                for (var j = 0; j <= tier; j++) {
                    if tier == j || reward.cumulative {
                        var tier_rewards_given = grant_quest_rewards(reward.tiers[j].rewards);
                        output.copy_from(tier_rewards_given);
                    }
                }
                break;
            case QuestRewardType.AnimalCosmetic:
                var item = new LiveItem(ItemId.AnimalCosmetic);
                item.animal_cosmetic = {
                    animal: reward.animal,
                    cosmetic: reward.cosmetic,
                };
                ARI.give_item(item);
                break;
            case QuestRewardType.PlayerCosmetic:
                if !ari_has_cosmetic_anywhere(reward.cosmetic) {
                    var item = new LiveItem(ItemId.Cosmetic);
                    item.cosmetic = reward.cosmetic;
                    ARI.give_item(item);
                }
                break;
            case QuestRewardType.LookupKey:
                var value = ARI.quest_artifacts.get(reward.key);
                if value != undefined {
                    consume_reward(parse_reward(clone_value(value))).for_each(function(v) {
                        ARI.give_item(v);
                    });
                }
                break;
        }
    }

    return output;
}
