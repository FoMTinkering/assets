#macro MAX_SKILL_LEVEL 60

//
function skill_level_cost(skill, level) {
    var total = 0;
    for (var i = 0; i <= level; i++) {
        total += skill_level_individual_cost(skill, i);
    }
    return total;
}

//
function skill_level_individual_cost(skill, level) {
    if level <= 1 {
        return 0;
    }

    switch skill {
        case Skill.Cooking:
            var modifier = level <= 2 ? 0 : 1;
            return ((level + modifier) div 2) * 3;

        case Skill.Ranching:
            static THRESH = 15;

            var cost = 0;
            if level > THRESH {
                cost += (level - THRESH) * 6;
                level = THRESH;
            }

            cost += (level - 1) * 3;

            return cost;

        case Skill.Mining:
            static MINING_GAINS = [
                { min_level: 1, xp: 0 },
                { min_level: 2, xp: 200 },
                { min_level: 3, xp: 280 },
                { min_level: 11, xp: 340 },
                { min_level: 16, xp: 400 },
            ];
            static MINING_COUNT = array_length(MINING_GAINS);

            var cost = 0;
            for (var i = 0; i < MINING_COUNT; i++) {
                var gain = MINING_GAINS[i];
                if level >= gain.min_level {
                    cost = gain.xp;
                } else {
                    break;
                }
            }
            return cost;

        case Skill.Combat:
            static COMBAT_GAINS = [
                { min_level: 1, xp: 0 },
                { min_level: 2, xp: 18 },
                { min_level: 3, xp: 30 },
                { min_level: 4, xp: 40 },
                { min_level: 10, xp: 50 },
                { min_level: 16, xp: 60 },
            ];
            static COMBAT_COUNT = array_length(COMBAT_GAINS);

            var cost = 0;
            for (var i = 0; i < COMBAT_COUNT; i++) {
                var gain = COMBAT_GAINS[i];
                if level >= gain.min_level {
                    cost = gain.xp;
                } else {
                    break;
                }
            }
            return cost;
        case Skill.Woodcrafting:
            switch level {
                case 2:
                case 3:
                case 4:
                    return 3;
                case 5:
                    return 4;
                case 6:
                case 7:
                case 8:
                case 9:
                case 10:
                    return 5;
                default:
                    var normalized = level - 6;
                    var units = floor(normalized / 5);
                    return 6 + (units * 3)
            }
        case Skill.Blacksmithing:
            if level < 5 {
                return 3;
            } else if level == 5 {
                return 4;
            } else {
                var normalized = level - 6;
                var units = normalized div 5;
                return 6 + (units * 3);
            }
        case Skill.Fishing:
            if level < 10 {
                return (level - 1) * 20;
            } else {
                return 180 + (2 * (level - 10));
            }
        case Skill.Farming:
            switch level {
                case 0: return 0;
                case 1: return 0;
                case 2: return 72;
                default: return 60 + ((level - 3) * 10)
            }
        case Skill.Archaeology:
            switch level {
                case 0: return 0;
                case 1: return 0;
                case 2: return 6;
                case 3: return 9;
                case 4: return 12;
                case 5: return 15;
                case 6: return 18;
                default:
                    static BASE_COST = 21;
                    if level <= 15 {
                        return BASE_COST;
                    } else {
                        return BASE_COST + (3 * ((level - 1) div 15));
                    }
            }
        default:
            //
            return ((level - 1) * 60) - 30;
            break;
    }
}

//
function skill_xp_to_level(skill, xp) {
    var level = 0;
    var measure_xp = 0;
    while true {
        measure_xp += skill_level_individual_cost(skill, level);

        if measure_xp > xp {
            return level - 1;
        }

        level += 1;
    }
}

//
#macro MAX_SKILL_LEVEL_COSTS global.__max_skill_level_costs
MAX_SKILL_LEVEL_COSTS = array_create(Skill.LEN, undefined);
for (var i = 0; i < Skill.LEN; i++) {
    MAX_SKILL_LEVEL_COSTS[i] = skill_level_cost(i, MAX_SKILL_LEVEL);
}

#macro XpValue global.__xp_values
function initialize_xp_values() {
    global.__xp_values = {
        break_dig_spot: fiddle_get("misc/xp_values/break_dig_spot"),
        identify_artifact: fiddle_get("misc/xp_values/identify_artifact"),
        catch_small_fish: fiddle_get("misc/xp_values/catch_small_fish"),
        catch_medium_fish:  fiddle_get("misc/xp_values/catch_medium_fish"),
        catch_large_fish: fiddle_get("misc/xp_values/catch_large_fish"),
        catch_giant_fish: fiddle_get("misc/xp_values/catch_giant_fish"),
        harvest_dive_spot: fiddle_get("misc/xp_values/harvest_dive_spot"),
        plant_seed: fiddle_get("misc/xp_values/plant_seed"),
        harvest_crop: fiddle_get("misc/xp_values/harvest_crop"),
        till_dirt: fiddle_get("misc/xp_values/till_dirt"),
        water_dirt: fiddle_get("misc/xp_values/water_dirt"),
    };
}

function fish_size_to_xp_value(fish_size) {
    switch fish_size {
        case FishSize.Small: return XpValue.catch_small_fish;
        case FishSize.Medium: return XpValue.catch_medium_fish;
        case FishSize.Large: return XpValue.catch_large_fish;
        case FishSize.Giant: return XpValue.catch_giant_fish;
        default: impossible("Unexpected FishSize: {}", fish_size);
    }
}


//
//
function test_skill_xp_paralleled() {
    for (var i = 0; i < Skill.LEN; i++) {
        for (var j = 1; j <= MAX_SKILL_LEVEL; j++) {
            var cost = skill_level_cost(i, j);
            assert_eq(
                j,
                skill_xp_to_level(i, cost),
                "{Skill} not parallel: expected {} but got {}!",
                i,
                j,
                skill_xp_to_level(i, cost),
            )
        }
    }
}

//
//
function test_cooking_xp_functions() {
    assert_eq(skill_level_individual_cost(Skill.Cooking, 1), 0);
    assert_eq(skill_level_individual_cost(Skill.Cooking, 2), 3);
    assert_eq(skill_level_individual_cost(Skill.Cooking, 3), 6);
    assert_eq(skill_level_individual_cost(Skill.Cooking, 4), 6);
    assert_eq(skill_level_individual_cost(Skill.Cooking, 5), 9);
    assert_eq(skill_level_individual_cost(Skill.Cooking, 6), 9);
    assert_eq(skill_level_individual_cost(Skill.Cooking, 7), 12);
    assert_eq(skill_level_individual_cost(Skill.Cooking, 8), 12);
    assert_eq(skill_level_individual_cost(Skill.Cooking, 9), 15);
    assert_eq(skill_level_individual_cost(Skill.Cooking, 10), 15);
    assert_eq(skill_level_individual_cost(Skill.Cooking, 11), 18);
    assert_eq(skill_level_individual_cost(Skill.Cooking, 12), 18);
    assert_eq(skill_level_individual_cost(Skill.Cooking, 13), 21);
    assert_eq(skill_level_individual_cost(Skill.Cooking, 14), 21);
    assert_eq(skill_level_individual_cost(Skill.Cooking, 15), 24);
}

//
//
function test_ranching_xp_functions() {
    assert_eq(skill_level_individual_cost(Skill.Ranching, 1), 0);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 2), 3);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 3), 6);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 4), 9);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 5), 12);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 6), 15);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 7), 18);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 8), 21);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 9), 24);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 10), 27);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 11), 30);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 12), 33);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 13), 36);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 14), 39);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 15), 42);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 16), 48);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 17), 54);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 18), 60);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 19), 66);
    assert_eq(skill_level_individual_cost(Skill.Ranching, 20), 72);
}

//
//
function test_combat_xp_functions() {
    assert_eq(skill_level_cost(Skill.Combat, 1), 0);
    assert_eq(skill_level_cost(Skill.Combat, 2), 18);
    assert_eq(skill_level_cost(Skill.Combat, 3), 48);
    assert_eq(skill_level_cost(Skill.Combat, 4), 88);
    assert_eq(skill_level_cost(Skill.Combat, 5), 128);
    assert_eq(skill_level_cost(Skill.Combat, 6), 168);
    assert_eq(skill_level_cost(Skill.Combat, 7), 208);
    assert_eq(skill_level_cost(Skill.Combat, 8), 248);
    assert_eq(skill_level_cost(Skill.Combat, 9), 288);
    assert_eq(skill_level_cost(Skill.Combat, 10), 338);
    assert_eq(skill_level_cost(Skill.Combat, 11), 388);
    assert_eq(skill_level_cost(Skill.Combat, 12), 438);
    assert_eq(skill_level_cost(Skill.Combat, 13), 488);
    assert_eq(skill_level_cost(Skill.Combat, 14), 538);
    assert_eq(skill_level_cost(Skill.Combat, 15), 588);
    assert_eq(skill_level_cost(Skill.Combat, 16), 648);
    assert_eq(skill_level_cost(Skill.Combat, 17), 708);
    assert_eq(skill_level_cost(Skill.Combat, 18), 768);
    assert_eq(skill_level_cost(Skill.Combat, 19), 828);
    assert_eq(skill_level_cost(Skill.Combat, 20), 888);
    assert_eq(skill_level_cost(Skill.Combat, 21), 948);
    assert_eq(skill_level_cost(Skill.Combat, 22), 1008);
    assert_eq(skill_level_cost(Skill.Combat, 23), 1068);
    assert_eq(skill_level_cost(Skill.Combat, 24), 1128);
    assert_eq(skill_level_cost(Skill.Combat, 25), 1188);
    assert_eq(skill_level_cost(Skill.Combat, 26), 1248);
    assert_eq(skill_level_cost(Skill.Combat, 27), 1308);
    assert_eq(skill_level_cost(Skill.Combat, 28), 1368);
    assert_eq(skill_level_cost(Skill.Combat, 29), 1428);
    assert_eq(skill_level_cost(Skill.Combat, 30), 1488);
    assert_eq(skill_level_cost(Skill.Combat, 31), 1548);
    assert_eq(skill_level_cost(Skill.Combat, 32), 1608);
    assert_eq(skill_level_cost(Skill.Combat, 33), 1668);
    assert_eq(skill_level_cost(Skill.Combat, 34), 1728);
    assert_eq(skill_level_cost(Skill.Combat, 35), 1788);
    assert_eq(skill_level_cost(Skill.Combat, 36), 1848);
    assert_eq(skill_level_cost(Skill.Combat, 37), 1908);
    assert_eq(skill_level_cost(Skill.Combat, 38), 1968);
    assert_eq(skill_level_cost(Skill.Combat, 39), 2028);
    assert_eq(skill_level_cost(Skill.Combat, 40), 2088);
    assert_eq(skill_level_cost(Skill.Combat, 41), 2148);
    assert_eq(skill_level_cost(Skill.Combat, 42), 2208);
    assert_eq(skill_level_cost(Skill.Combat, 43), 2268);
    assert_eq(skill_level_cost(Skill.Combat, 44), 2328);
    assert_eq(skill_level_cost(Skill.Combat, 45), 2388);
    assert_eq(skill_level_cost(Skill.Combat, 46), 2448);
    assert_eq(skill_level_cost(Skill.Combat, 47), 2508);
    assert_eq(skill_level_cost(Skill.Combat, 48), 2568);
    assert_eq(skill_level_cost(Skill.Combat, 49), 2628);
    assert_eq(skill_level_cost(Skill.Combat, 50), 2688);
}

//
//
function test_mining_xp_functions() {
    assert_eq(skill_level_cost(Skill.Mining, 2), 200);
    assert_eq(skill_level_cost(Skill.Mining, 3), 480);
    assert_eq(skill_level_cost(Skill.Mining, 4), 760);
    assert_eq(skill_level_cost(Skill.Mining, 5), 1040);
    assert_eq(skill_level_cost(Skill.Mining, 6), 1320);
    assert_eq(skill_level_cost(Skill.Mining, 7), 1600);
    assert_eq(skill_level_cost(Skill.Mining, 8), 1880);
    assert_eq(skill_level_cost(Skill.Mining, 9), 2160);
    assert_eq(skill_level_cost(Skill.Mining, 10), 2440);
    assert_eq(skill_level_cost(Skill.Mining, 11), 2780);
    assert_eq(skill_level_cost(Skill.Mining, 12), 3120);
    assert_eq(skill_level_cost(Skill.Mining, 13), 3460);
    assert_eq(skill_level_cost(Skill.Mining, 14), 3800);
    assert_eq(skill_level_cost(Skill.Mining, 15), 4140);
    assert_eq(skill_level_cost(Skill.Mining, 16), 4540);
    assert_eq(skill_level_cost(Skill.Mining, 17), 4940);
    assert_eq(skill_level_cost(Skill.Mining, 18), 5340);
    assert_eq(skill_level_cost(Skill.Mining, 19), 5740);
    assert_eq(skill_level_cost(Skill.Mining, 20), 6140);
    assert_eq(skill_level_cost(Skill.Mining, 21), 6540);
    assert_eq(skill_level_cost(Skill.Mining, 22), 6940);
    assert_eq(skill_level_cost(Skill.Mining, 23), 7340);
    assert_eq(skill_level_cost(Skill.Mining, 24), 7740);
    assert_eq(skill_level_cost(Skill.Mining, 25), 8140);
    assert_eq(skill_level_cost(Skill.Mining, 26), 8540);
    assert_eq(skill_level_cost(Skill.Mining, 27), 8940);
    assert_eq(skill_level_cost(Skill.Mining, 28), 9340);
    assert_eq(skill_level_cost(Skill.Mining, 29), 9740);
}

//
//
function test_blacksmithing_xp_functions() {
    assert_eq(skill_level_cost(Skill.Blacksmithing, 2), 3);
    assert_eq(skill_level_cost(Skill.Blacksmithing, 3), 6);
    assert_eq(skill_level_cost(Skill.Blacksmithing, 4), 9);
    assert_eq(skill_level_cost(Skill.Blacksmithing, 5), 13);
    assert_eq(skill_level_cost(Skill.Blacksmithing, 6), 19);
    assert_eq(skill_level_cost(Skill.Blacksmithing, 7), 25);
    assert_eq(skill_level_cost(Skill.Blacksmithing, 8), 31);
    assert_eq(skill_level_cost(Skill.Blacksmithing, 9), 37);
    assert_eq(skill_level_cost(Skill.Blacksmithing, 10), 43);
    assert_eq(skill_level_cost(Skill.Blacksmithing, 11), 52);
    assert_eq(skill_level_cost(Skill.Blacksmithing, 12), 61);
    assert_eq(skill_level_cost(Skill.Blacksmithing, 13), 70);
    assert_eq(skill_level_cost(Skill.Blacksmithing, 14), 79);
    assert_eq(skill_level_cost(Skill.Blacksmithing, 15), 88);
    assert_eq(skill_level_cost(Skill.Blacksmithing, 16), 100);
}

//
//
function test_woodcrafting_xp_functions() {
    assert_eq(skill_level_cost(Skill.Woodcrafting, 2), 3);
    assert_eq(skill_level_cost(Skill.Woodcrafting, 3), 6);
    assert_eq(skill_level_cost(Skill.Woodcrafting, 4), 9);
    assert_eq(skill_level_cost(Skill.Woodcrafting, 5), 13);
    assert_eq(skill_level_cost(Skill.Woodcrafting, 6), 18);
    assert_eq(skill_level_cost(Skill.Woodcrafting, 7), 23);
    assert_eq(skill_level_cost(Skill.Woodcrafting, 8), 28);
    assert_eq(skill_level_cost(Skill.Woodcrafting, 9), 33);
    assert_eq(skill_level_cost(Skill.Woodcrafting, 10), 38);
    assert_eq(skill_level_cost(Skill.Woodcrafting, 11), 47);
    assert_eq(skill_level_cost(Skill.Woodcrafting, 12), 56);
    assert_eq(skill_level_cost(Skill.Woodcrafting, 13), 65);
    assert_eq(skill_level_cost(Skill.Woodcrafting, 14), 74);
    assert_eq(skill_level_cost(Skill.Woodcrafting, 15), 83);
    assert_eq(skill_level_cost(Skill.Woodcrafting, 16), 95);
}

//
//
function test_fishing_xp_functions() {
    assert_eq(skill_level_cost(Skill.Fishing, 2), 20);
    assert_eq(skill_level_cost(Skill.Fishing, 3), 60);
    assert_eq(skill_level_cost(Skill.Fishing, 4), 120);
    assert_eq(skill_level_cost(Skill.Fishing, 5), 200);
    assert_eq(skill_level_cost(Skill.Fishing, 6), 300);
    assert_eq(skill_level_cost(Skill.Fishing, 7), 420);
    assert_eq(skill_level_cost(Skill.Fishing, 8), 560);
    assert_eq(skill_level_cost(Skill.Fishing, 9), 720);
    assert_eq(skill_level_cost(Skill.Fishing, 10), 900);
    assert_eq(skill_level_cost(Skill.Fishing, 11), 1082);
    assert_eq(skill_level_cost(Skill.Fishing, 12), 1266);
    assert_eq(skill_level_cost(Skill.Fishing, 13), 1452);
    assert_eq(skill_level_cost(Skill.Fishing, 14), 1640);
    assert_eq(skill_level_cost(Skill.Fishing, 15), 1830);
    assert_eq(skill_level_cost(Skill.Fishing, 16), 2022);
    assert_eq(skill_level_cost(Skill.Fishing, 17), 2216);
    assert_eq(skill_level_cost(Skill.Fishing, 18), 2412);
    assert_eq(skill_level_cost(Skill.Fishing, 19), 2610);
    assert_eq(skill_level_cost(Skill.Fishing, 20), 2810);
}

//
//
function test_farming_xp_functions() {
    assert_eq(skill_level_cost(Skill.Farming, 2), 72);
    assert_eq(skill_level_cost(Skill.Farming, 3), 132);
    assert_eq(skill_level_cost(Skill.Farming, 4), 202);
    assert_eq(skill_level_cost(Skill.Farming, 5), 282);
    assert_eq(skill_level_cost(Skill.Farming, 6), 372);
    assert_eq(skill_level_cost(Skill.Farming, 7), 472);
    assert_eq(skill_level_cost(Skill.Farming, 8), 582);
    assert_eq(skill_level_cost(Skill.Farming, 9), 702);
    assert_eq(skill_level_cost(Skill.Farming, 10), 832);
    assert_eq(skill_level_cost(Skill.Farming, 11), 972);
    assert_eq(skill_level_cost(Skill.Farming, 12), 1122);
    assert_eq(skill_level_cost(Skill.Farming, 13), 1282);
    assert_eq(skill_level_cost(Skill.Farming, 14), 1452);
    assert_eq(skill_level_cost(Skill.Farming, 15), 1632);
    assert_eq(skill_level_cost(Skill.Farming, 16), 1822);
    assert_eq(skill_level_cost(Skill.Farming, 17), 2022);
    assert_eq(skill_level_cost(Skill.Farming, 18), 2232);
    assert_eq(skill_level_cost(Skill.Farming, 19), 2452);
    assert_eq(skill_level_cost(Skill.Farming, 20), 2682);
}

//
//
function test_archaeology_xp_functions() {
    assert_eq(skill_level_cost(Skill.Archaeology, 2), 6);
    assert_eq(skill_level_cost(Skill.Archaeology, 3), 15);
    assert_eq(skill_level_cost(Skill.Archaeology, 4), 27);
    assert_eq(skill_level_cost(Skill.Archaeology, 5), 42);
    assert_eq(skill_level_cost(Skill.Archaeology, 6), 60);
    assert_eq(skill_level_cost(Skill.Archaeology, 7), 81);
    assert_eq(skill_level_cost(Skill.Archaeology, 8), 102);
    assert_eq(skill_level_cost(Skill.Archaeology, 9), 123);
    assert_eq(skill_level_cost(Skill.Archaeology, 10), 144);
    assert_eq(skill_level_cost(Skill.Archaeology, 11), 165);
    assert_eq(skill_level_cost(Skill.Archaeology, 12), 186);
    assert_eq(skill_level_cost(Skill.Archaeology, 13), 207);
    assert_eq(skill_level_cost(Skill.Archaeology, 14), 228);
    assert_eq(skill_level_cost(Skill.Archaeology, 15), 249);
    assert_eq(skill_level_cost(Skill.Archaeology, 16), 273);

    assert_eq(skill_level_individual_cost(Skill.Archaeology, 29), 24);
    assert_eq(skill_level_individual_cost(Skill.Archaeology, 30), 24);
    assert_eq(skill_level_individual_cost(Skill.Archaeology, 31), 27);

    assert_eq(skill_level_individual_cost(Skill.Archaeology, 44), 27);
    assert_eq(skill_level_individual_cost(Skill.Archaeology, 45), 27);
    assert_eq(skill_level_individual_cost(Skill.Archaeology, 46), 30);
}
