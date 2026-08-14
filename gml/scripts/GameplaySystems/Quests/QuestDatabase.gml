#macro QUESTS global.__quest_db
global.__quest_db = undefined;

#macro QUEST_TAG_REGISTRATIONS global.__quest_tag_registrations
QUEST_TAG_REGISTRATIONS = undefined;

#macro CROWN_QUESTS global.__crown_quests
CROWN_QUESTS = undefined;

#macro TALI_CHALLENGES global.__tali_challenges
TALI_CHALLENGES = undefined;

#macro STILLWELL_CHALLENGES global.__stillwell_challenges
STILLWELL_CHALLENGES = undefined;

#macro QUESTS_BY_CATEGORY global.__quests_by_category
QUESTS_BY_CATEGORY = undefined;

//
function Quest() constructor {
    self.name = undefined;
    self.description = undefined;

    self.tasks = List();
    self.reward_list = List();
    self.post_complete_tutorial = undefined;
}

//
//
function QuestTask() constructor {
    self.description = undefined;

    self.requirements = array_create(Requirement.LEN, undefined);
    self.reward_list = List();
    self.query_targets = List();
}

function load_quests() {
    var quests = Map();

    quest_parse_file(quests, fiddle_get("quests/story_quests"), QuestCategory.Story);
    quest_parse_file(quests, fiddle_get("quests/crown_quests"), QuestCategory.Crown);
    quest_parse_file(quests, fiddle_get("quests/tali_challenges"), QuestCategory.TaliChallenge);
    quest_parse_file(quests, fiddle_get("quests/stillwell_challenges"), QuestCategory.StillwellChallenge);
    quest_parse_file(quests, fiddle_get("quests/heart_quests"), QuestCategory.Heart);
    quest_parse_file(quests, fiddle_get("quests/fetch_quests"), QuestCategory.Fetch);

    return quests;
}

//
//
function gather_quests_by_category() {
    var out = array_create_ext(QuestCategory.LEN, function() {
        return [];
    });
    var keys = QUESTS.keys();
    for (var i = 0; i < array_length(keys); i++) {
        var this_key = keys[i];
        var this_quest = QUESTS.get(this_key);
        array_push(out[this_quest.category], this_key);
    }

    return out;
}

function quest_parse_file(quests, f, category) {
    var quest_names = struct_get_names(f);

    for (var i = 0, c = array_length(quest_names); i < c; i++) {
        var quest_name = quest_names[i];
        var quest = parse_quest(f[$ quest_name]);
        quest.category = category;
        quest.test_target = QuestTestTarget.None;
        if category == QuestCategory.Story {
            assert_neq(f[quest_name]["test_target"], undefined, "Quest '{}' is missing a test target!", quest_name);
            quest.test_target = string_to_quest_test_target(f[quest_name].test_target);
        }
        quests.insert(quest_name, quest);
    }
}

function parse_quest(f_quest) {
    var quest = new Quest();

    if DEBUG_ASSERTIONS == false {
        f_quest[$ "name"] = f_quest[$ "name"] == undefined ? "misc_local/missing" : f_quest[$ "name"];
        f_quest[$ "description"] = f_quest[$ "description"] == undefined ? "misc_local/missing" : f_quest[$ "description"]
        f_quest[$ "npc_for_icon"] =  f_quest[$ "npc_for_icon"] == undefined ? "celine" : f_quest[$ "npc_for_icon"]
        f_quest[$ "stages"] = f_quest[$ "stages"] == undefined ? [] : f_quest[$ "stages"];
    }
    //
    quest.name = f_quest.name;
    quest.description = f_quest[$ "description"] ?? "";
    quest.post_complete_tutorial = opt_and_then(f_quest[$ "post_complete_tutorial"], string_to_tutorial);

    quest.npc_for_icon = string_to_npc_id(f_quest.npc_for_icon);

    //
    for (var i = 0, c = array_length(f_quest.stages); i < c; i ++) {
        var task = parse_task(quest, f_quest.stages[i]);
        quest.tasks.push(task);
    }

    //
    if f_quest[$ "rewards"] != undefined {
        parse_rewards(f_quest.rewards, quest.reward_list);
    }

    return quest;
}

function parse_task(quest, f_task) {
    var task = new QuestTask();
    task.description = f_task.objective_description;
    task.turn_in_description = f_task[$ "turn_in_description"] ?? "misc_local/turn_in_quest";
    task.turn_in_button_label = f_task[$ "turn_in_button_label"] ?? "misc_local/turn_in";

    //
    for (var i = 0, c = array_length(f_task.queries); i < c; i ++) {
        task.query_targets.push(parse_query(quest, f_task.queries[i]));
    }

    //
    if f_task[$ "requirements"] != undefined {
        task.requirements = parse_requirements(f_task.requirements);
    } else {
        task.requirements = array_create(Requirement.LEN, undefined);
    }

    if f_task[$ "rewards"] != undefined {
        parse_rewards(f_task.rewards, task.reward_list);
    }

    return task;
}

function parse_query(quest, f_query) {
    for (var i = 0; i < QuestQueryType.LEN; i++) {
        if f_query[$ quest_query_type_to_string(i)] == undefined {
            continue;
        }

        switch i {
            case QuestQueryType.Npc:
                assert_defined(f_query.npc_conversation, "Missing `query.npc_conversation' for '{}.stages[{}]'", quest.name, quest.tasks.count());
                var npc_name = string_to_npc_id(f_query.npc);

                //
                var output = T2R.exact_gameplay_conversation(f_query.npc_conversation);
                assert_defined(output, "conversation {} not found", f_query.npc_conversation);

                return {
                    npc_name: npc_name,
                    npc_conversation: output,
                    type: QuestQueryType.Npc,
                }
            case QuestQueryType.Cutscene:
                assert_defined(f_query[$ "location"], "Missing 'cutscene_room' for '{Local}.stages[{}]'", quest.name, quest.tasks.count());
                assert(CUTSCENES.contains_key(f_query.cutscene), "Cutscene `{}` does not exist", f_query.cutscene);

                return {
                    cutscene: f_query.cutscene,
                    cutscene_location: string_to_location_id(f_query.location),
                    cutscene_area: f_query[$ "area"] ?? [-infinity, -infinity, infinity, infinity],
                    type: QuestQueryType.Cutscene,
                }
            case QuestQueryType.Manual:
                return {
                    type: QuestQueryType.Manual
                }
            default: crash("unknown requirement: {}", f_requirement);
        }
    }
}

function parse_rewards(rewards, reward_list) {
    var og_size = reward_list.count();
    for (var i = 0, c = array_length(rewards); i < c; i ++) {
        var reward = rewards[i];

        for (var j = 0; j < QuestRewardType.LEN; j++) {
            if reward[$ quest_reward_type_to_string(j)] == undefined {
                continue;
            }

            switch j {
                case QuestRewardType.Item:
                    reward_list.push(QuestReward.Item(string_to_item_id(reward.item), reward[$ "count"] ?? 1));
                    break;
                case QuestRewardType.Gold:
                    reward_list.push(QuestReward.Gold(reward.gold));
                    break;
                case QuestRewardType.Quest:
                    reward_list.push(QuestReward.Quest(reward.quest));
                    break;
                case QuestRewardType.Renown:
                    reward_list.push(QuestReward.Renown(reward.renown));
                    break;
                case QuestRewardType.RecipeScroll:
                    var reward = QuestReward.RecipeScroll(string_to_item_id(reward.recipe_scroll));
                    reward_list.push(reward);
                    break;
                case QuestRewardType.CraftingScroll:
                    var reward = QuestReward.CraftingScroll(string_to_item_id(reward.crafting_scroll));
                    reward_list.push(reward);
                    break;
                case QuestRewardType.Tiers:
                    for (var k = 0; k < array_length(reward.tiers); k++) {
                        var tier = reward.tiers[k];
                        var list = List();
                        parse_rewards(tier.rewards, list);
                        tier.rewards = list;
                    }
                    var reward = QuestReward.Tiers(reward.tiers, reward.artifact_key, reward.cumulative);
                    reward_list.push(reward);
                    break;
                case QuestRewardType.AnimalCosmetic:
                    var animal = string_to_animal_kind(reward.animal);
                    assert(
                        ANIMAL_PROTOTYPES[animal].cosmetics.contains_key(reward.animal_cosmetic),
                        "Animal cosmetic '{}' does not exist",
                        reward.animal_cosmetic,
                    );
                    var reward = QuestReward.AnimalCosmetic(animal, reward.animal_cosmetic);
                    reward_list.push(reward);
                    break;
                case QuestRewardType.PlayerCosmetic:
                    validate_cosmetic(reward.player_cosmetic);
                    reward_list.push(QuestReward.PlayerCosmetic(reward.player_cosmetic));
                    break;
                case QuestRewardType.LookupKey:
                    reward_list.push(QuestReward.LookupKey(reward.lookup_key));
                    break;
            }
        }

    }

    assert_eq(array_length(rewards), reward_list.count() - og_size, "Failed to identify all rewards! {}", rewards);
}

function load_quest_tag_registrations() {
    var f = fiddle_get("quests/crown_registry/tag_registrations");
    var keys = struct_get_names(f);
    var registrations = Map();
    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];
        var value = f[$ key];
        registrations.insert(key, {
            text: value.text,
            item_for_icon: string_to_item_id(value.item_for_icon),
        });
    }

    return registrations;
}

function load_crown_quests() {
    var crown_requests = fiddle_get("quests/crown_registry/order");
    var output = array_create(array_length(crown_requests), undefined);
    for (var i = 0; i < array_length(crown_requests); i++) {
        var data = crown_requests[i];
        var quest = is_string(data) ? data : data.quest;
        var requirements = is_struct(data) ? opt_and_then(data[$ "requirements"], parse_requirements) : undefined;
        assert(QUESTS.contains_key(quest), "Crown quest does not exist: {}", quest);
        output[i] = {
            quest,
            requirements,
        };
    }
    return output;
}

function load_tali_challenges() {
    var challenges = fiddle_get("quests/tali_registry/order");
    for (var i = 0; i < array_length(challenges); i++) {
        var challenge = challenges[i];
        assert(QUESTS.contains_key(challenge), "Tali quest does not exist: {}", challenge);
    }
    return challenges;
}

function load_stillwell_challenges() {
    var challenges = fiddle_get("quests/stillwell_registry/order");
    for (var i = 0; i < array_length(challenges); i++) {
        var challenge = challenges[i];
        assert(QUESTS.contains_key(challenge), "Stillwell quest does not exist: {}", challenge);
    }
    return challenges;
}
