enum ProgressOutput {
    NextStage,
    Complete,
}

enum QuestState {
    Inactive,
    Active,
    Completed,
    LEN
}

enum QuestCategory {
    Story,
    Crown,
    TaliChallenge,
    StillwellChallenge,
    Heart,
    Fetch,
    LEN
}

enum QuestTestTarget {
    None,
    MainStory,
    DragonStory,
    Festivals,
    LEN
}

global.quest_reward_factory = new QuestRewardFactory();
#macro QuestReward global.quest_reward_factory

function QuestRewardFactory() constructor {
    static Item = function(_item, _amount) {
        return {
            type: QuestRewardType.Item,
            item: _item,
            amount: _amount
        }
    }
    static Gold = function(_amount) {
        return {
            type: QuestRewardType.Gold,
            amount: _amount
        }
    }
    static Quest = function(_quest_name) {
        return {
            type: QuestRewardType.Quest,
            quest_name: _quest_name
        }
    }
    static Renown = function(value) {
        return {
            type: QuestRewardType.Renown,
            value: value,
        }
    }
    static RecipeScroll = function(value) {
        return {
            type: QuestRewardType.RecipeScroll,
            item: value,
        }
    }
    static CraftingScroll = function(value) {
        return {
            type: QuestRewardType.CraftingScroll,
            item: value,
        }
    }
    static Tiers = function(tiers, artifact_key, cumulative) {
        return {
            type: QuestRewardType.Tiers,
            tiers,
            artifact_key,
            cumulative,
        }
    }
    static AnimalCosmetic = function(animal, cosmetic) {
        return {
            type: QuestRewardType.AnimalCosmetic,
            animal,
            cosmetic,
        }
    }
    static PlayerCosmetic = function(cosmetic) {
        return {
            type: QuestRewardType.PlayerCosmetic,
            cosmetic,
        }
    }
    static LookupKey = function(key) {
        return {
            type: QuestRewardType.LookupKey,
            key,
        }
    }
}

enum QuestRewardType {
    Item,
    Gold,
    Quest,
    Renown,
    RecipeScroll,
    CraftingScroll,
    Tiers,
    AnimalCosmetic,
    PlayerCosmetic,
    LookupKey,

    LEN
}

enum QuestQueryType {
    Npc,
    Cutscene,
    Manual,

    LEN
}

enum SupplyType {
    Chest,
    Seal,
    LEN,
}

//
function score_to_tier_reward_index(tier_reward, value, ari) {
    var result = 0;
    for (var i = 0; i < array_length(tier_reward.tiers); i++) {
        var tier = tier_reward.tiers[i];
        var required_score = tier.required_score;

        //
        if i == array_length(tier_reward.tiers) - 1 && ari != undefined {
            var artifact = ari.quest_artifacts.get(tier_reward.artifact_key);
            if artifact != undefined {
                required_score = max(required_score, artifact.max_score);
            }
        }

        if value >= required_score {
            result = i;
        } else {
            break;
        }
    }
    return result;
}

//
//
//
//
function try_gather_item_spawn(key, xx, yy, grid) {

    var any = false;
    var active_quests = QUEST_LOG.active.values();
    for (var i = 0; i < array_length(active_quests); i++) {
        var aq = active_quests[i];
        var task = aq.quest.tasks.get(aq.current_stage);
        var requirement = task.requirements[Requirement.Custom];
        if requirement != undefined && requirement[$ "gather"] != undefined {
            static DROP_CHANCES = fiddle_get("misc/gather_challenge_drop_chances");
            var passes = random(1) <= DROP_CHANCES[$ gather_drop_chance_to_string(key)];

            if passes {
                var item = string_to_item_id(requirement.gather.item);
                any = true;

                if grid == undefined {
                    var inst = create_animation_effect(xx, yy, -100000, spr_fx_breath_of_spring_poof);
                    inst.drop_bundle = item;
                    TANGO.play("SoundEffects/Inventory/StaminaPreSpawnPoof", xx, yy);
                    inst.image_idx = 4;
                    inst.image_idx_func = method(inst, function() {
                        drop_item(self.drop_bundle, self.x, self.y);
                    });
                } else {
                    grid.lost_items.push({
                        x: xx,
                        y: yy,
                        items: ListFromArray([new LiveItem(item)]),
                    });
                }
            }
        }
    }

    return any;
}

function available_tali_challenge() {
    var last_index = undefined;
    for (var i = array_length(TALI_CHALLENGES) - 1; i >= 0; i--) {
        var quest = TALI_CHALLENGES[i];
        if QUEST_LOG.active.contains_key(quest) {
            return undefined; //
        }
        if QUEST_LOG.completed.contains(quest) && QUEST_LOG.completion_timestamps.get(quest) < CALENDAR.time {
            last_index = i;
            break;
        }
    }

    //
    //
    var offer = undefined;
    if last_index == undefined {
        offer = TALI_CHALLENGES[0];
    } else if (last_index + 1) < array_length(TALI_CHALLENGES) {
        offer = TALI_CHALLENGES[last_index + 1];
    }

    //
    if offer != undefined
        && !QUEST_LOG.active.contains_key(offer)
        && !QUEST_LOG.completed.contains(offer)
    {
        return offer;
    } else {
        return undefined;
    }
}

function available_stillwell_challenge() {
    var last_index = undefined;
    for (var i = array_length(STILLWELL_CHALLENGES) - 1; i >= 0; i--) {
        var quest = STILLWELL_CHALLENGES[i];
        if QUEST_LOG.active.contains_key(quest) {
            return undefined; //
        }
        if QUEST_LOG.completed.contains(quest) && QUEST_LOG.completion_timestamps.get(quest) < CALENDAR.time {
            last_index = i;
            break;
        }
    }

    //
    //
    var offer = undefined;
    if last_index == undefined {
        offer = STILLWELL_CHALLENGES[0];
    } else if (last_index + 1) < array_length(STILLWELL_CHALLENGES) {
        offer = STILLWELL_CHALLENGES[last_index + 1];
    }

    //
    if offer != undefined
        && !QUEST_LOG.active.contains_key(offer)
        && !QUEST_LOG.completed.contains(offer)
    {
        return offer;
    } else {
        return undefined;
    }
}

enum GatherDropChance {
    Harvest,
    DigSite,
    RockBreak,
    AxeBreak,
    FishCaught,
    DiveSpot,
    BugCaught,
    AnimalProduction,
    SlashBreakable,
    SlashGrass,
    KillEnemy,
    LEN,
}
