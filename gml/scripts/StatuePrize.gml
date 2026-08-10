#macro CHICKEN_STATUE_REWARDS global.__chicken_statue_rewards
CHICKEN_STATUE_REWARDS = undefined;

#macro WISHING_WELL_REWARDS global.__wishing_well_rewards
WISHING_WELL_REWARDS = undefined;

#macro STATUE_CTX global.__statue_ctx
STATUE_CTX = undefined;

//
#macro OFFERING_ITEM_NAME global.__offering_item_name
OFFERING_ITEM_NAME = undefined;

//
#macro OFFERING_ITEM_COUNT global.__offering_item_count
OFFERING_ITEM_COUNT = undefined;

enum PrizeRarity {
    Legendary,
    Rare,
    Common,
    LEN,
}

function parse_statue_rewards(fiddle_root) {
    var output = array_create(PrizeRarity.LEN, undefined);

    for (var rarity = 0; rarity < PrizeRarity.LEN; rarity++) {
        var f_rewards_data = fiddle_get(format("{}/{PrizeRarity}", fiddle_root, rarity));

        static PARSE = function(v) {
            return {
                reward: parse_reward(v),
                requirements: parse_requirements(v[$ "requirements"] ?? {}),
            };
        }

        output[rarity] = {
            chance: f_rewards_data.chance,
            small: array_map(f_rewards_data.small_roll, PARSE),
            large: array_map(f_rewards_data.large_roll, PARSE),
        };
    }

    assert_eq(output[PrizeRarity.Common].chance, 1.0, "common rewards_data must have a chance of 1.0!");
    assert(array_length(output[PrizeRarity.Common].large) > 0, "common large rewards_data must have some valid rewards in it!");
    assert(array_length(output[PrizeRarity.Common].small) > 0, "common small rewards_data must have some valid rewards in it!");

    //
    var found_item_or_purse = false;
    for (var i = 0; i < array_length(output[PrizeRarity.Common].large); i++) {
        var item = output[PrizeRarity.Common].large[i].reward;

        if item.type == RewardType.Item || item.type == RewardType.Purse {
            found_item_or_purse = true;
            break;
        }
    }
    assert(found_item_or_purse, "we need the common large rewards_data to have at least one item or a purse in it");

    //
    var found_item_or_purse = false;
    for (var i = 0; i < array_length(output[PrizeRarity.Common].small); i++) {
        var item = output[PrizeRarity.Common].small[i].reward;

        if item.type == RewardType.Item || item.type == RewardType.Purse {
            found_item_or_purse = true;
            break;
        }
    }
    assert(found_item_or_purse, "we need the common small rewards_data to have at least one item or a purse in it");

    return output;
}

//
//
function poll_statue_reward(statue_rewards, small_roll) {
    var roll = random(1);
    for (var prize_rarity = 0; prize_rarity < PrizeRarity.LEN; prize_rarity++) {
        var rewards_data = statue_rewards[prize_rarity];

        if roll <= rewards_data.chance {
            var pool = small_roll ? rewards_data.small : rewards_data.large;
            //
            if array_length(pool) == 0 {
                continue;
            }
            //
            for (var attempts = 0; attempts < 100; attempts++) {
                var candidate = pool[irandom(array_length(pool) - 1)];
                var valid = false;

                switch candidate.reward.type {
                    case RewardType.Item:
                    case RewardType.Purse:
                        valid = true;
                        break;
                    case RewardType.Cosmetic:
                        valid = !ari_has_cosmetic_anywhere(candidate.reward.cosmetic);
                        break;
                    case RewardType.AnimalCosmetic:
                        valid = !ari_has_animal_cosmetic_anywhere(candidate.reward.animal, candidate.reward.animal_cosmetic);
                        break;
                    case RewardType.PetCosmetic:
                        valid = PET.unlocked() && !ari_has_pet_cosmetic_anywhere(candidate.reward.pet_cosmetic);
                        break;
                    case RewardType.RecipeScroll:
                    case RewardType.CraftingScroll:
                        valid = !ari_has_recipe_anywhere(candidate.reward.item);
                        break;
                    default: impossible("Unexpected RewardType: {}", candidate.reward.type);
                }

                if valid && requirements_pass(candidate.requirements) {
                    return candidate.reward;
                }
            }
        }
    }

    crash("we always return a reward in the common pool above, which will always have a reward");
};
