#macro REQUIREMENT_ALIASES global.__requirement_aliases
REQUIREMENT_ALIASES = undefined;

function load_requirement_aliases() {
    static DATA = fiddle_get("requirements");
    var aliases = array_create(Requirement.LEN, undefined);
    for (var i = 0; i < Requirement.LEN; i++) {
        var data = DATA[$ requirement_to_string(i)];
        if struct_names_count(data) != 0 {
            aliases[i] = parse_requirements(data);
        }
    }
    return aliases;
}

function parse_requirements(entry) {
    static PARSE = function(requirement, this_entry) {
        static MAP_SINGLE_FIELD = function(v, key_functor, value_functor) {
            var names = struct_get_names(v);
            if array_length(names) != 1 {
                crash(
                    "Cannot place more than one field in a single entry: {}.\nHint: Use an array instead: [ {{ a = 1 }}, {{ b = 1 }}, etc ]",
                    v,
                );
            }
            var key = names[0];
            var value = v[$ key];
            return [
                key_functor != undefined ? key_functor(key) : key,
                value_functor != undefined ? value_functor(value) : value,
            ];
        }

        switch requirement {
            case Requirement.Or: return array_map(this_entry, parse_requirements);
            case Requirement.Invert:
                var sub_requirements = parse_requirements(this_entry);
                var found_sub_req = false;
                for (var req_id = 0; req_id < Requirement.LEN; req_id++) {
                    var sub_req = sub_requirements[req_id];
                    if sub_req == undefined || (requirement_field_is_array(req_id) && array_is_empty(sub_req)) {
                        continue;
                    }

                    assert(!found_sub_req, "Invert requirement had more than one sub_requirement. If you need more than one sub_requirement, use an `or`!");
                    found_sub_req = true;
                }

                return sub_requirements;
            case Requirement.HasPerk: return string_to_perk(this_entry);
            case Requirement.SeenCutscene:
            case Requirement.SceneIsPlaying:
                return CONTENT_REGISTRY.validate_cutscene(this_entry);
            case Requirement.CompletedQuest:
                var days_after = is_struct(this_entry) ? this_entry.days_after : 0;
                var quest = is_struct(this_entry) ? this_entry.quest : this_entry;
                CONTENT_REGISTRY.validate_quest(quest);
                return [quest, days_after];
            case Requirement.CompletedQuestsInCategory: return string_to_quest_category(this_entry);
            case Requirement.QuestIsActive: return CONTENT_REGISTRY.validate_quest(this_entry);
            case Requirement.ReachedSkillLevel: return MAP_SINGLE_FIELD(this_entry, string_to_skill);
            case Requirement.ReachedHeartLevel: return MAP_SINGLE_FIELD(this_entry, string_to_npc_id);
            case Requirement.IsDayType: return string_to_day(this_entry);
            case Requirement.IsSeason: return string_to_season(this_entry);
            case Requirement.InTimeRange:
                if DEBUG_ASSERTIONS {
                    assert(is_between_inclusive(this_entry[0], 0, 26), "Cannot have a time value at {}", this_entry[0]);
                    assert(is_between_inclusive(this_entry[1], 0, 26), "Cannot have a time value at {}", this_entry[0]);
                    assert(this_entry[1] >= this_entry[0], "Second time value cannot be greater than first one!");
                }
                return this_entry;
            case Requirement.InDateRange: return [parse_requirement_date(this_entry[0]), parse_requirement_date(this_entry[1])];
            case Requirement.MetNpc: return string_to_npc_id(this_entry);
            case Requirement.ShippedItem: return is_struct(this_entry)
                ? MAP_SINGLE_FIELD(this_entry, string_to_item_id)
                : [string_to_item_id(this_entry), 1];
            case Requirement.ShippedTag: return is_struct(this_entry)
                ? MAP_SINGLE_FIELD(this_entry)
                : [this_entry, 1];
            case Requirement.HasItem: return is_struct(this_entry)
                ? MAP_SINGLE_FIELD(this_entry, string_to_item_id)
                : [string_to_item_id(this_entry), 1];
            case Requirement.DefeatedMonster: return is_struct(this_entry)
                ? MAP_SINGLE_FIELD(this_entry, string_to_monster_id)
                : [string_to_monster_id(this_entry), 1];
            case Requirement.DonatedItem: return string_to_item_id(this_entry);
            case Requirement.UnlockedAnimal: return string_to_animal_kind(this_entry);
            case Requirement.ReceivedLetter: return CONTENT_REGISTRY.validate_letter(this_entry);
            case Requirement.AcquiredItem: return string_to_item_id(this_entry);
            case Requirement.SuppliedItems:
                var items = array_create(ItemId.LEN, 0);
                var keys = struct_get_names(this_entry.items);
                for (var i = 0; i < array_length(keys); i++) {
                    var item_id = string_to_item_id(keys[i]);
                    var count = this_entry.items[$ keys[i]];
                    items[item_id] = count;
                }
                if this_entry[$ "point"] != undefined {
                    trellis_point(this_entry.point); //
                    return {
                        type: SupplyType.Chest,
                        point: this_entry.point,
                        items,
                    }
                } else {
                    return {
                        type: SupplyType.Seal,
                        seal: string_to_seal(this_entry.seal),
                        items,
                    }
                }
            case Requirement.ReachedDate: return parse_requirement_date(this_entry);
            case Requirement.QuestIsAtStage: return this_entry;
            case Requirement.ReachedMinesLevel:
                if DEBUG_ASSERTIONS {
                    assert(is_between_inclusive(this_entry, 0, 99), "{} is an invalid mines level!", this_entry);
                }
                return this_entry;
            case Requirement.ReachedRenownLevel:
                if DEBUG_ASSERTIONS {
                    assert(is_between_inclusive(this_entry, 0, 100), "{} is an invalid renown level!", this_entry);
                }
                return this_entry;
            case Requirement.HasHomeUpgrade: return string_to_home_upgrade(this_entry);
            case Requirement.EarnedGold:
            case Requirement.HasGold:
            case Requirement.ReachedItemsCooked:
            case Requirement.ReachedItemsWoodcrafted:
            case Requirement.ReachedItemsSmithed:
            case Requirement.ReachedBugsCaught:
            case Requirement.ReachedFishCaught:
            case Requirement.ReachedCropsHarvested:
            case Requirement.ReachedEnemiesDefeated:
            case Requirement.AcquiredAnimals:
            case Requirement.HasAnimalOfRank:
            case Requirement.GoodGiftsGiven:
            case Requirement.ReachedEssence:
                if DEBUG_ASSERTIONS {
                    assert(is_real(this_entry), "Can only use a real for {Requirement}!", requirement);
                }
                return this_entry;
            case Requirement.WorldFactIs: return MAP_SINGLE_FIELD(this_entry, undefined, function(v) {
                return v == "undefined" ? undefined : v;
            });
            case Requirement.IsDating: return string_to_npc_id(this_entry);
            case Requirement.IsSpouse: return string_to_npc_id(this_entry);
            case Requirement.IsPartner: return string_to_npc_id(this_entry);
            case Requirement.IsBestFriend: return string_to_npc_id(this_entry);
            case Requirement.CompletedMuseumSetWithin: return string_to_museum_wing(this_entry);
            case Requirement.CompletedMuseumSet: return [string_to_museum_wing(this_entry.wing), this_entry.set];
            case Requirement.EndOfDayStatus: return string_to_end_of_day_status(this_entry);
            case Requirement.AllNpcGiftsDiscovered: return string_to_npc_id(this_entry);
            case Requirement.HasChildAtAge: return this_entry;
            case Requirement.Custom: return this_entry;
            default:
                if DEBUG_ASSERTIONS {
                    assert(this_entry == true, "Can only use `true` with {Requirement}!", requirement);
                }
                return this_entry;
        }
    }

    if DEBUG_ASSERTIONS {
        static VALID_KEYS = array_create_ext(Requirement.LEN, requirement_to_string);
        var invalid_field = find_invalid_field(entry, VALID_KEYS);
        if invalid_field != undefined {
            crash("Invalid Requirement field: {}", invalid_field);
        }
    }

    //
    //
    var requirement = array_create(Requirement.LEN, undefined);

    for (var i = 0; i < Requirement.LEN; i++) {
        var field_name = requirement_to_string(i);
        var their_field = entry[$ field_name];

        if their_field == undefined {
            continue;
        }

        if requirement_field_is_array(i) {
            if !is_array(their_field) {
                their_field = [their_field];
            }

            if !array_is_empty(their_field) {
                requirement[i] = [];
            }

            for (var j = 0; j < array_length(their_field); j++) {
                array_push(requirement[i], PARSE(i, their_field[j]));
            }
        } else {
            requirement[i] = PARSE(i, their_field);
        }
    }

    return requirement;
}

#macro REQ_CHECK global.__req_check
REQ_CHECK = undefined;

function create_req_check() {
    return array_create_ext(Requirement.LEN, function(i) {
        switch i {
            case Requirement.Or: return function(input) {
                var any = false;
                for (var i = 0; i < array_length(input); i++) {
                    if requirements_pass(input[i]) {
                        return true;
                    }
                }
                return false;
            }
            case Requirement.Invert: return function(input) {
                return !requirements_pass(input);
            }
            case Requirement.HasPerk: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if !ARI.perks[input[i]] {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.HasAtLeastOneTierFivePerkPerCategory: return function(input) {
                static tier_five_perks_by_category = get_tier_five_perks_by_category();
                for (var i = 0; i < array_length(tier_five_perks_by_category); i++) {
                    var perks = tier_five_perks_by_category[i];
                    var has_any = false;
                    for (var j = 0; j < array_length(perks); j++) {
                        if ARI.perks[perks[j]] {
                            has_any = true;
                            break;
                        }
                    }
                    if !has_any {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.SeenCutscene: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if !MIST.scene_history.contains(input[i]) {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.SceneIsPlaying: return function(input) {
                return MIST.is_running() && MIST.active_cutscene.id == input;
            }
            case Requirement.CompletedQuest: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    var this_entry = input[i];
                    if !QUEST_LOG.completed.contains(this_entry[0]) {
                        return false;
                    } else {
                        var completion_days = QUEST_LOG.completion_timestamps.get_or(this_entry[0], 0) div days(1);
                        var needed_days = completion_days + this_entry[1];
                        if CALENDAR.time div days(1) < needed_days {
                            return false;
                        }
                    }
                }
                return true;
            }
            case Requirement.CompletedQuestsInCategory: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    var this_entry = input[i];
                    var these_quests = QUESTS_BY_CATEGORY[this_entry];
                    for (var j = 0, c = array_length(these_quests); j < c; j++) {
                        if !QUEST_LOG.completed.contains(these_quests[j]) {
                            return false;
                        }
                    }

                }
                return true;
            }
            case Requirement.QuestIsActive: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if !QUEST_LOG.active.contains_key(input[i]) {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.QuestIsAtStage: return function(input) {
                for (var i = 0, ic = array_length(input); i < ic; i++) {
                    var quest = QUEST_LOG.active.get(input[i].quest);
                    if quest == undefined || quest.current_stage != input[i].stage {
                        return false;
                    }
                }

                return true;
            }
            case Requirement.ReachedSkillLevel: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    var entry = input[i];
                    if ARI.level(entry[0]) < entry[1] {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.ReachedHeartLevel: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    var entry = input[i];
                    if NPCS[entry[0]].heart_level() < entry[1] {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.IsDayType: return function(input) {
                return CALENDAR.day_type() == input;
            }
            case Requirement.IsSeason: return function(input) {
                var passes = true;
                for (var i = 0; i < array_length(input); i++) {
                    passes &= CALENDAR.season() == input[i];
                }
                return passes;
            }
            case Requirement.InTimeRange: return function(input) {
                return CLOCK.time >= hours(input[0]) && CLOCK.time <= hours(input[1]);
            }
            case Requirement.InDateRange: return function(input) {
                var year_one = input[0].year ?? CALENDAR.year();
                var time_one = seasons(input[0].season) + days(input[0].day) + years(year_one);
                var year_two = input[1].year ?? CALENDAR.year();
                var time_two = seasons(input[1].season) + days(input[1].day) + years(year_two);
                return CALENDAR.time >= time_one && CALENDAR.time <= time_two;
            }
            case Requirement.MetNpc: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if !NPCS[input[i]].has_met() {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.ShippedTag: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    var entry = input[i];
                    if ARI.times_item_tag_sold(entry[0]) < entry[1] {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.ShippedItem: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    var entry = input[i];
                    if ARI.items_sold[entry[0]] < entry[1] {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.DefeatedMonster: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if ARI.monsters_killed[input[i][0]] < input[i][1] {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.HasItem: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    var this_entry = input[i];
                    if this_entry[1] > ARI.inventory.item_id_quantity(this_entry[0]) {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.DonatedItem: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if !MUSEUM_PROGRESS[input[i]] {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.UnlockedAnimal: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if !animal_is_unlocked(input[i]) {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.HasAnimalOfRank: return function(input) {
                var animals = get_all_animals();

                for (var i = 0, ic = animals.count(); i < ic; i++) {
                    if array_contains(input, animals.get(i).tier()) {
                        return true;
                    }
                }

                return false;
            }
            case Requirement.AcquiredAnimals: return function(input) {
                if GAME_STATS["animals"] == undefined {
                    return false;
                }
                return array_length(GAME_STATS.animals) >= input;
            }
            case Requirement.ReceivedLetter: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if !ARI.inbox.contains(input[i]) {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.WorldFactIs: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if T2R.read(input[i][0]) != input[i][1] {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.AcquiredItem: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if !ARI.items_acquired[input[i]] {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.SuppliedItems: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    var this_req = input[i];
                    var inventory = undefined;
                    if this_req.type == SupplyType.Chest {
                        var point = trellis_point_location_position(this_req.point);
                        var grid = GRIDS[point.location_id];
                        var ni = grid.node_index_for_cell(point.pos.x div 8, point.pos.y div 8);
                        assert_eq(grid.node_object_id[ni], ObjectId.TurnInBox, "Chest at Trellis Point is not a turn in box");
                        inventory = grid.node_parent[ni].inventory;
                    } else {
                        inventory = SEAL_INVENTORIES[this_req.seal];
                    }

                    for (var j = 0; j < ItemId.LEN; j++) {
                        var count = this_req.items[j];
                        if count != 0 && inventory.item_id_quantity(j) < count {
                            return false;
                        }
                    }
                }
                return true;
            }
            case Requirement.HasGold: return function(input) {
                return ARI.get_gold() >= input;
            }
            case Requirement.ReachedDate: return function(input) {
                var year = input.year ?? CALENDAR.year();
                var time = seasons(input.season) + days(input.day) + years(year);
                if input.exact {
                    return CALENDAR.date_is(time);
                } else {
                    return CALENDAR.date_is_at_least(time);
                }
            }
            case Requirement.EndOfDayStatus: return function(input) {
                return ARI.end_of_day_status == input;
            }
            case Requirement.IsPlayerBirthday: return function() {
                return ARI.is_birthday();
            }
            case Requirement.IsDatingSomeone: return function() {
                return some_romantic_npc() != undefined;
            }
            case Requirement.IsDating: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if !NPCS[input[i]].is_dating() {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.IsSpouse: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if !NPCS[input[i]].is_spouse() {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.IsPartner: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if !NPCS[input[i]].is_partner() {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.IsBestFriend: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    if !NPCS[input[i]].is_best_friend() {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.HasSpouse: return function() {
                return ARI.has_spouse();
            }
            case Requirement.HasFiance: return function() {
                return ARI.has_fiance();
            }
            case Requirement.HasBestFriend: return function() {
                for (var i = 0; i < NpcId.LEN; i++) {
                    if NPCS[i].is_best_friend() {
                        return true;
                    }
                }
                return false;
            }
            case Requirement.HasPartner: return function() {
                for (var i = 0; i < NpcId.LEN; i++) {
                    if NPCS[i].is_partner() {
                        return true;
                    }
                }
                return false;
            }
            case Requirement.ReachedMinesLevel: return function(input) {
                return MAXIMUM_REACHED_DUNGEON_LEVEL + 1 >= input;
            }
            case Requirement.ReachedRenownLevel: return function(input) {
                var renown = ARI.renown;
                if ARI.end_of_day_status != undefined {
                    renown += ARI.pending_renown_entries.sum_with(function(e) {
                        return renown_entry_value(e);
                    });
                }
                return renown_to_level(renown) >= input;
            }
            case Requirement.EarnedGold: return function(input) {
                return game_stats_get_income_total() >= input;
            }
            case Requirement.EligibleForCrownRequest: return function() {
                return ARI.ready_for_crown_quest();
            }
            case Requirement.HasAnyAnimal: return function() {
                return !get_all_animals(true).is_empty();
            }
            case Requirement.IsFestivalDay: return function() {
                return todays_festival() != undefined;
            }
            case Requirement.HasHomeUpgrade: return function(input) {
                return DECOR.size_upgrade >= input;
            }
            case Requirement.HasUpperFloor: return function() {
                return DECOR.upper_floor;
            }
            case Requirement.HasLeftHouseToday: return function() {
                return ARI.has_left_house_today;
            }
            case Requirement.HasCoop: return function() {
                return get_buildings().any(function(v) {
                    return matches(v.object_id, ObjectId.SmallCoop, ObjectId.MediumCoop, ObjectId.LargeCoop);
                });
            }
            case Requirement.HasBarn: return function() {
                return get_buildings().any(function(v) {
                    return matches(v.object_id, ObjectId.SmallBarn, ObjectId.MediumBarn, ObjectId.LargeBarn);
                });
            }
            case Requirement.GoodGiftsGiven: return function(input) {
                for (var i = 0; i < NpcId.LEN; i++) {
                    if array_has(NPC_PROTOTYPES[i].tags, "townsfolk") {
                        T2R.write(format("gave_{NpcId}_good_birthday_gift", i), true);
                    }
                }
                return array_length(GAME_STATS.gifts_given) >= input;
            }
            case Requirement.ReachedItemsCooked: return function(input) {
                return array_length(GAME_STATS.items_cooked) >= input;
            }
            case Requirement.ReachedItemsWoodcrafted: return function(input) {
                return array_length(GAME_STATS.items_woodcrafted) >= input;
            }
            case Requirement.ReachedItemsSmithed: return function(input) {
                return array_length(GAME_STATS.items_forged) >= input;
            }
            case Requirement.ReachedBugsCaught: return function(input) {
                return array_length(GAME_STATS.bugs_caught) >= input;
            }
            case Requirement.ReachedFishCaught: return function(input) {
                return array_length(GAME_STATS.fish_caught) >= input;
            }
            case Requirement.ReachedCropsHarvested: return function(input) {
                return array_length(GAME_STATS.crop_harvests) >= input;
            }
            case Requirement.ReachedEnemiesDefeated: return function(input) {
                return GAME_STATS.enemies_killed >= input;
            }
            case Requirement.CompletedMuseumSetWithin: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    var wing = input[i];
                    var sets = MUSEUM_DATA.data[wing].sets.keys();
                    var any = false;
                    for (var j = 0; j < array_length(sets); j++) {
                        if museum_set_progress(wing, sets[j]) == museum_set_size(wing, sets[j]) {
                            any = true;
                            break;
                        }
                    }
                    if !any {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.CompletedMuseumSet: return function(input) {
                for (var i = 0; i < array_length(input); i++) {
                    var wing = input[i][0];
                    if museum_set_progress(wing, input[i][1]) != museum_set_size(wing, input[i][1]) {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.CompletedMuseum: return function(input) {
                for (var i = 0; i < ItemId.LEN; i++) {
                    if MUSEUM_DATA.museum_items[i] && !MUSEUM_PROGRESS[i] {
                        return false;
                    }
                }
                return true;
            }
            case Requirement.BabyIsDue: return function() {
                return ARI.pending_child != undefined && ARI.pending_child.due_date <= CALENDAR.time;
            }
            case Requirement.HasChild: return function() {
                return !array_is_empty(ARI.children);
            }
            case Requirement.ReachedEssence: return function(input) {
                return GAME_STATS.gross_essence >= input;
            }
            case Requirement.CompletedAlmanac: return function(arr) {
                return ARI.almanac_items_remaining.is_empty();
            }
            case Requirement.AllNpcGiftsDiscovered: return function(npc_ids) {
                for (var i = 0, ic = array_length(npc_ids); i < ic; i++) {
                    var npc = NPCS[npc_ids[i]]
                    for (var j = 0, jc = npc.prototype.loved_gifts.count(); j < jc; j++) {
                        if npc.gifts_given.contains(npc.prototype.loved_gifts.get(j)) == false {
                            return false;
                        }
                    }
                    for (var j = 0, jc = npc.prototype.liked_gifts.count(); j < jc; j++) {
                        if npc.gifts_given.contains(npc.prototype.liked_gifts.get(j)) == false {
                            return false;
                        }
                    }
                }
                return true;
            }
            case Requirement.HasChildAtAge: return function(age) {
                for (var i = 0; i < array_length(ARI.children); i++) {
                    if CALENDAR.year() - get_years(ARI.children[i].birthday) >= 1 {
                        return true;
                    }
                }
                return false;
            }
            case Requirement.Custom: return function() {
                assert_eq(input, undefined, "Custom requirements must be manually handled!");
                return true;
            }
            default:
                assert(requirement_is_alias(i), "REQ_CHECK not set up for {Requirement}", i);
                var bundle = { type: i };
                return method(bundle, function() {
                    if MIST.is_running() && MIST.requirement_overrides[self.type] {
                        return true;
                    }

                    return requirements_pass(REQUIREMENT_ALIASES[self.type]);
                });
        }
    });
}

function requirements_pass(req) {
    if is_int64(req) {
        if DEBUG_ASSERTIONS {
            assert(requirement_is_alias(req), "Expected an alias requirement here, not {Requirement}", req);
        }

        return REQ_CHECK[req]();
    }

    for (var i = 0; i < Requirement.LEN; i++) {
        var input = req[i];
        if input == undefined || (requirement_field_is_array(i) && array_is_empty(input)) {
            continue;
        }
        if !REQ_CHECK[i](input) {
            return false;
        }
    }
    return true;
}

function requirement_field_is_array(requirement) {
    switch requirement {
        case Requirement.ReachedDate:
        case Requirement.IsDayType:
        case Requirement.IsPlayerBirthday:
        case Requirement.IsDatingSomeone:
        case Requirement.ReachedMinesLevel:
        case Requirement.ReachedRenownLevel:
        case Requirement.EarnedGold:
        case Requirement.HasGold:
        case Requirement.EligibleForCrownRequest:
        case Requirement.HasAnyAnimal:
        case Requirement.InTimeRange:
        case Requirement.InDateRange:
        case Requirement.IsFestivalDay:
        case Requirement.HasLeftHouseToday:
        case Requirement.Custom:
        case Requirement.Invert:
        case Requirement.HasHomeUpgrade:
        case Requirement.HasUpperFloor:
        case Requirement.GoodGiftsGiven:
        case Requirement.ReachedItemsCooked:
        case Requirement.ReachedItemsSmithed:
        case Requirement.ReachedBugsCaught:
        case Requirement.ReachedFishCaught:
        case Requirement.ReachedEnemiesDefeated:
        case Requirement.ReachedCropsHarvested:
        case Requirement.Or:
        case Requirement.SceneIsPlaying:
        case Requirement.EndOfDayStatus:
        case Requirement.AcquiredAnimals:
        case Requirement.ReachedItemsWoodcrafted:
        case Requirement.ReachedEssence:
        case Requirement.BabyIsDue:
        case Requirement.HasChild:
            return false;
        default: return true;
    }
}

function requirement_is_alias(requirement) {
    return REQUIREMENT_ALIASES[requirement] != undefined;
}

function parse_requirement_date(input) {
    if is_string(input) {
        return {
            day: 0,
            season: string_to_season(input),
            year: undefined,
            exact: false,
        };
    }
    var year = opt_and_then(input[$ "year"], function(v) {
        return v - 1;
    });
    return {
        day: input.day - 1,
        season: string_to_season(input.season),
        year: year,
        exact: input[$ "exact"] ?? false,
    };
}

function requirements_used_within(entry, collection) {
    collection ??= [];

    for (var i = 0; i < Requirement.LEN; i++) {
        var this = entry[i];
        if this == undefined || (requirement_field_is_array(i) && array_is_empty(this)) {
            continue;
        }

        if requirement_is_alias(i) {
            requirements_used_within(REQUIREMENT_ALIASES[i], collection);
            continue;
        } else if i == Requirement.Or {
            for (var j = 0; j < array_length(this); j++) {
                requirements_used_within(this[j], collection);
            }
            continue;
        } else if i == Requirement.Invert {
            requirements_used_within(this, collection);
            continue;
        }

        if !array_has(collection, i) {
            array_push(collection, i);
        }
    }

    return collection;
}
