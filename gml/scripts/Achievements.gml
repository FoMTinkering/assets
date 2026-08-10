#macro ACHIEVEMENTS global.__achievements
ACHIEVEMENTS = undefined;

#macro ACHIEVEMENT_CACHE global.__achievement_cache
ACHIEVEMENT_CACHE = array_create(Achievement.LEN, false);

#macro ACHIEVEMENTS_USING_REQUIREMENT global.__achievements_using_requirement
ACHIEVEMENTS_USING_REQUIREMENT = undefined;

#macro CHECK_ACHIEVEMENTS global.__check_achievements
CHECK_ACHIEVEMENTS = true;

//
//
//
//
//
//
#macro VALID_ACHIEVEMENT_FILTERS global.__valid_achievement_filters
VALID_ACHIEVEMENT_FILTERS = array_create_ext(Requirement.LEN, function(i) {
    switch i {
        //
        case Requirement.CompletedQuest:
        case Requirement.CompletedQuestsInCategory:

        //
        case Requirement.CompletedAlmanac:

        //
        case Requirement.ReachedHeartLevel:

        //
        case Requirement.CompletedMuseum:
        case Requirement.CompletedMuseumSet:
        case Requirement.CompletedMuseumSetWithin:

        //
        case Requirement.SeenCutscene:
        case Requirement.HasSpouse:
        case Requirement.HasBestFriend:
        case Requirement.HasPartner:
        case Requirement.IsDating:

        //
        case Requirement.EarnedGold:

        //
        case Requirement.WorldFactIs:

        //
        case Requirement.ReachedEssence:

        //
        case Requirement.ReachedRenownLevel:

        //
        case Requirement.HasHomeUpgrade:
        case Requirement.HasUpperFloor:

        //
        case Requirement.HasAnimalOfRank:
        case Requirement.HasAnyAnimal:

        //
        case Requirement.HasAtLeastOneTierFivePerkPerCategory:

        //
        case Requirement.ReachedSkillLevel:

        //
        case Requirement.AllNpcGiftsDiscovered:
        case Requirement.GoodGiftsGiven:

        //
        case Requirement.HasChildAtAge:
            return true;
        default: return false;
    }
});



function parse_achievements() {
    var data = fiddle_get("achievements");
    var arr = array_create(Achievement.LEN, undefined);

    for (var i = 0; i < Achievement.LEN; i++) {
        arr[i] = parse_requirements(data[$ achievement_to_string(i)].requirements);

        if DEBUG_ASSERTIONS {
            var used = requirements_used_within(arr[i]);
            for (var j = 0; j < array_length(used); j++) {
                assert(
                    VALID_ACHIEVEMENT_FILTERS[used[j]],
                    "{Requirement} is not set up as a valid achievement filter!",
                    used[j],
                );
            }
        }
    }

    return arr;
}

function gather_achievement_requirement_usage() {
    var out = array_create_ext(Requirement.LEN, function() {
        return []
    });
    for (var i = 0; i < Requirement.LEN; i++) {
        if VALID_ACHIEVEMENT_FILTERS[i] {
            var collection = out[i];

            for (var j = 0; j < Achievement.LEN; j++) {
                var ach = ACHIEVEMENTS[j];
                if array_has(requirements_used_within(ach), i) {
                    array_push(collection, j);
                }
            }
        }
    }

    return out;
}

function refresh_achievements(filter) {
    static GATHER_ALL = function() {
        var out = [];
        for (var i = 0; i < Requirement.LEN; i++) {
            if VALID_ACHIEVEMENT_FILTERS[i] {
                array_push(out, i);
            }
        }
        return out;
    }
    static ALL = GATHER_ALL();

    filter ??= ALL;

    //
    //
    if !CHECK_ACHIEVEMENTS {
        return;
    }

    var seen = array_bool(Achievement.LEN);
    for (var i = 0, c = array_length(filter); i < c; i++) {
        if DEBUG_ASSERTIONS && !VALID_ACHIEVEMENT_FILTERS[filter[i]] {
            crash("{Requirement} is not set up as a valid achievement filter!", filter[i]);
        }

        var achs = ACHIEVEMENTS_USING_REQUIREMENT[filter[i]];
        for (var j = 0, jc = array_length(achs); j < jc; j++) {
            var ach = achs[j];
            if seen[ach] {
                continue;
            }

            seen[ach] = true

            if ACHIEVEMENT_CACHE[ach] {
                continue;
            }

            if requirements_pass(ACHIEVEMENTS[ach]) {
                steam_unlock_achievement(achievement_to_string(ach));
                ACHIEVEMENT_CACHE[ach] = true;
                trace("Achievement Unlocked: {Achievement}", ach);
            }
        }
    }
}
