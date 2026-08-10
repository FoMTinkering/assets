#macro WATER_FLOW_SPEED 0.05

#macro FISH global.__fish
global.__fish = undefined;

//
#macro FISH_DISTRIBUTIONS global.__fish_distributions
global.__fish_distributions = undefined;

//
#macro DIVESPOT_DISTRIBUTION global.__divespot_distribution
global.__divespot_distribution = undefined;

#macro FISH_CHEST global.__fish_chest
global.__fish_chest = undefined;

#macro FISH_SHOULD_DRAW_NAME global.__fish_should_draw_name
FISH_SHOULD_DRAW_NAME = false;

#macro FISH_CONDITION_DATA global.__fish_condition_data
FISH_CONDITION_DATA = {
    water_type: WaterType.Ocean,
    size: FishSize.Small,
    all_any_size: false,
    bait: undefined,
};

enum FishSpawn {
    Fish,
    School,
    Divespot,
    LEN
}

enum FishRetrieval {
    EMPTY = 0,
    FISHES = 1,
    MINES = 1 << 1,
    DIVESPOTS = 1 << 2,
    FISH_TRAP = 1 << 3,
}

enum FishChestItemKind {
    Item,
    Recipe,
    Cosmetic
}

//
function create_fish_prototypes() {
    var fish_prototypes = array_create(ItemId.LEN, undefined);

    var fish_data = fiddle_get("fish");
    var fish_default = fish_data[$ "default"];
    var default_keys = struct_get_names(fish_default);

    for (var i = 0; i < FishId.LEN; i++) {
        var fish = fish_data[$ fish_id_to_string(i)];
        var conditions = new SpawnConditions();
        var prototype = {
            id: i,
            secondary_item: undefined,
        };

        //
        for (var j = 0; j < array_length(default_keys); j++) {
            var key = default_keys[j];
            var value = fish[$ key] ?? fish_default[$ key];
            switch key {
                case "recipe":
                    if is_string(value) {
                        assert_eq(prototype.secondary_item, undefined, "two things tried to assign a secondary_item to a fish prototype!");
                        prototype.secondary_item = string_to_item_id(value);
                        conditions.require(Condition.Invert(Condition.HasRecipeUnlocked(prototype.secondary_item)));
                    }
                    break;

                case "retrieval":
                    prototype.retrieval = FishRetrieval.EMPTY;

                    value = ensure_array(value);
                    for (var k = 0; k < array_length(value); k++) {
                        switch value[k] {
                            case "fishing":
                                prototype.retrieval = set_flag(prototype.retrieval, FishRetrieval.FISHES);
                                break;
                            case "mines":
                                prototype.retrieval = set_flag(prototype.retrieval, FishRetrieval.MINES);
                                break;
                            case "divespot":
                                prototype.retrieval = set_flag(prototype.retrieval, FishRetrieval.DIVESPOTS);
                                break;
                            case "fish_trap":
                                prototype.retrieval = set_flag(prototype.retrieval, FishRetrieval.FISH_TRAP);
                                break;
                            default: crash("unexpected fish retrieval value: {}", value[k]);
                        }
                    }
                    break;
                case "item":
                    if value == "<..>" {
                        value = fish_id_to_string(i);
                    }
                    prototype.item = string_to_item_id(value);
                    break;
                case "seasons":
                    if value == false {
                        break;
                    }
                    var condition = Condition.Or();
                    for (var k = 0; k < array_length(value); k++) {
                        array_push(condition.conditions, Condition.CurrentSeason(string_to_season(value[k])));
                    }
                    conditions.require(condition);
                    break;
                case "rarity":
                    var rarity_value = fiddle_get(format("fishing/votes/{}", value));
                    conditions.add(rarity_value, Condition.None);
                    prototype.rarity = value;
                    prototype.rarity_value = rarity_value;
                    break;
                case "locations":
                    if value == false {
                        break;
                    }
                    var condition = Condition.Or();
                    for (var k = 0; k < array_length(value); k++) {
                        array_push(condition.conditions, Condition.CurrentLocation(string_to_location_id(value[k])));
                    }
                    conditions.require(condition);
                    break;
                case "hours":
                    if value == false {
                        break;
                    }
                    conditions.require(Condition.TimeBetween(hours(value[0]), hours(value[1])));
                    break;
                case "weather":
                    if value == false {
                        break;
                    }
                    var condition = Condition.Or();
                    for (var k = 0; k < array_length(value); k++) {
                        array_push(condition.conditions, Condition.CurrentWeather(string_to_weather(value[k])));
                    }
                    conditions.require(condition);
                    break;
                case "water_type":
                    value = is_array(value) ? value : [value];
                    prototype.water_type = apply_func(value, string_to_water_type);
                    break;
                case "size":
                    prototype.size = string_to_fish_size(value);
                    break;
                case "perk_artifact":
                    if is_string(value) {
                        assert_eq(prototype.secondary_item, undefined, "two things tried to assign a secondary_item to a fish prototype!");
                        conditions.require(Condition.HasPerk(string_to_perk(value)));
                        prototype.secondary_item = string_to_item_id(fish_id_to_string(i));
                    }
                    break;
                case "has_perk":
                    if is_string(value) {
                        conditions.require(Condition.HasPerk(string_to_perk(value)));
                    }
                    break;
                default:
                    prototype[$ key] = value;
                    break;
            }
        }

        //
        assert_neq(prototype.item, undefined, "{FishId} does not have an item defined!");
        if prototype.item == ItemId.RecipeScroll || prototype.item == ItemId.UnidentifiedArtifact {
            assert_neq(prototype.secondary_item, undefined, "{FishId} needs an inner item!", prototype.id);
        }

        //
        if prototype.legendary {
            conditions.require(Condition.LegendaryNotCaught(string_to_season(fish.seasons[0])));
        }

        //
        conditions.require(Condition.FishIsValid(prototype.id));

        //
        prototype.conditions = conditions;

        fish_prototypes[prototype.id] = prototype;
    }

    return fish_prototypes;
}

function create_fish_distributions() {
    var output = new SpawnDistribution();

    //
    var perfect_catch_f = fiddle_get("perks/perfect_catch");
    var perfect_catch = {};
    var vote_keys = struct_get_names(fiddle_get("fishing/votes"));
    for (var vote_name_idx = 0; vote_name_idx < array_length(vote_keys); vote_name_idx++) {
        var vote_name = vote_keys[vote_name_idx];
        var perfect_catch_override = perfect_catch_f[$ vote_name];

        if perfect_catch_override != undefined {
            perfect_catch[$ vote_name] = perfect_catch_override;
        }
    }

    for (var i = 0; i < FishId.LEN; i++) {
        var fish_proto = FISH[i];
        //
        if !has_flag(fish_proto.retrieval, FishRetrieval.FISHES) {
            continue;
        }

        var conditions = fish_proto.conditions.clone();

        if perfect_catch[$ fish_proto.rarity] != undefined {
            conditions.add(perfect_catch[$ fish_proto.rarity], Condition.HasPerk(Perk.PerfectCatch));
        }

        if fish_proto.rarity == "junk" {
            conditions.add(
                fiddle_get(format("perks/{Perk}", Perk.WeedlineWatcher)).value,
                Condition.HasPerk(Perk.WeedlineWatcher)
            );
            conditions.add(
                fiddle_get(format("perks/{Perk}", Perk.WeedlineWatcherTwo)).value,
                Condition.HasPerk(Perk.WeedlineWatcherTwo)
            );
        }

        if fish_proto.is_chest {
            var raw_votes = fiddle_get(format("fishing/votes/{}", fish_proto.rarity));
            var extra_votes = 0;
            var lookup = fiddle_get(format("perks/{Perk}", Perk.UnexpectedHaul));
            switch fish_proto.rarity {
                case "wood_chest":
                    extra_votes = raw_votes * lookup.wood_chest_multiplier;
                    conditions.require(Condition.Invert(Condition.HasPerk(Perk.TreasureTrove)));
                    break;
                case "copper_chest":
                    extra_votes = raw_votes * lookup.copper_chest_multiplier;
                    conditions.add(
                        ceil(raw_votes * .5),
                        Condition.HasPerk(Perk.TreasureTrove)
                    )
                    break;
                case "silver_chest":
                    extra_votes = raw_votes * lookup.silver_chest_multiplier;
                    conditions.add(
                        ceil(raw_votes * .5),
                        Condition.HasPerk(Perk.TreasureTrove)
                    )
                    break;
                case "gold_chest":
                    extra_votes = raw_votes * lookup.gold_chest_multiplier;
                    conditions.add(
                        ceil(raw_votes * .5),
                        Condition.HasPerk(Perk.TreasureTrove)
                    )
                    break;
                default: impossible("unexpected chest rarity: {}", fish_proto.rarity);
            }
            conditions.add(
                ceil(extra_votes),
                Condition.HasPerk(Perk.UnexpectedHaul)
            );
        }

        output.add_candidate(fish_proto.id, conditions);
    }

    return output;
}

function create_divespot_distributions() {
    var output = new SpawnDistribution();

    for (var i = 0; i < FishId.LEN; i++) {
        var fish = FISH[i];

        if !has_flag(fish.retrieval, FishRetrieval.DIVESPOTS) {
            continue;
        }
        var conditions = fish.conditions.clone();
        conditions.require(Condition.NoCollisionAtCell);

        var votes = fiddle_get(format("fishing/votes/{}", fish.rarity));
        if fish.is_chest {
            conditions.add(
                ceil(votes * (fiddle_get(fmt("perks/{Perk}", Perk.SunkenTreasure)).value / 100)),
                Condition.HasPerk(Perk.SunkenTreasure)
            );
        }
        output.add_candidate(fish.id, conditions);
    }

    return output;
}

function create_fish_chests() {
    var output = {};
    var chest_data = fiddle_get("fishing/chest_tables");
    var chest_names = struct_get_names(chest_data);
    for (var i = 0, c = array_length(chest_names); i < c; i++) {
        var chest_name = chest_names[i];
        var this_chest = chest_data[$ chest_name];
        output[$ chest_name] = {
            gold: this_chest.gold,
            items: array_map(this_chest.items, function(item_data) {
                return {
                    item: string_to_item_id(item_data.value),
                    chest_kind: string_to_fish_chest_item_kind(item_data.kind),
                    count: item_data[$ "count"] ?? 1,
                    cosmetic: item_data[$ "cosmetic"] ?? undefined
                }
            }),
        }
    }

    return output;
}

function setup_all_fish_spawners() {
    if LOCATIONS[CURRENT_LOCATION_ID].outdoor == false {
        return;
    }

    if instance_exists(obj_fish_spawner) {
        assert(layer_exists("Tiles_Fish_Size"), "An instance of obj_fish_spawner exists, but there is no tile layer Tiles_Fish_Size in this room.");
    }

    for (var i = 0; i < instance_number(obj_fish_spawner); i++) {
        var instance = instance_find(obj_fish_spawner, i);

        //
        var spawn_count = instance.spawn_count[FishSpawn.Fish];
        if spawn_count > 0 {
            for (var k = 0; k < spawn_count; k++) {
                spawn_fish(instance);
            }
        }

        var spawn_count = instance.spawn_count[FishSpawn.School];
        if spawn_count > 0 {
            for (var k = 0; k < spawn_count; k++) {
                spawn_fish_school(instance);
            }
        }

        //
        var spawn_count = instance.spawn_count[FishSpawn.Divespot];
        if spawn_count > 0 {
            for (var k = 0; k < spawn_count; k++) {
                spawn_divespot(instance);
            }
        }
    }
}

//
function spawn_fish(instance) {
    var fish_size = instance.fish_votes.get_candidate();
    if fish_size == undefined {
        return undefined;
    }
    var winner = populate_fish(FishSpawn.Fish, fish_size, instance.water_kind, instance.x, instance.y).get_candidate();
    if winner == undefined {
        error("spawner @ {}x{} wants to spawn a {FishSize} fish, but no fish was available.", instance.x, instance.y, fish_size);
        return undefined;
    }
    var position = instance.size_locations[fish_size].choose_random();
    if position == undefined {
        //
        position = instance.find_fallback_position();
    }
    var new_fish = instance_create_depth(position.x, position.y, 0, obj_fishy);
    new_fish.initialise(new Fish(winner));

    //
    if MIST.is_running() {
        new_fish.visible = false;
        instance_deactivate_object(new_fish);
    }

    return new_fish;
}

//
function spawn_fish_school(instance) {
    var limit = irandom_range(2, 4);
    var list = List();

    if ARI.perk_active(Perk.FullClass) {
        limit += 1;
        GAME_STATS.perks[$ perk_to_string(Perk.FullClass)] += 1;
    }

    for (var lim = 0; lim < limit; lim++) {
        var fish_size = instance.fish_votes.get_candidate();
        if fish_size == undefined {
            break;
        }
        //
        if fish_size == FishSize.Giant {
            lim += 1;
        }
        var winner = populate_fish(FishSpawn.Fish, fish_size, instance.water_kind, instance.x, instance.y).get_candidate();
        if winner == undefined {
            error("spawner @ {}x{} wants to spawn a {FishSize} fish in a school, but no fish was available.", instance.x, instance.y, fish_size);
            continue;
        }
        list.push(new Fish(winner));
    }

    if list.is_empty() {
        error("we had no fish in our schools!");
        return undefined;
    }
    var position = instance.find_fallback_position();
    var new_school = instance_create_depth(position.x, position.y, 0, obj_fish_school);
    new_school.initialise(list);

    //
    if MIST.is_running() {
        new_school.visible = false;
        instance_deactivate_object(new_school);
    }

    return new_school;
}

//
function spawn_divespot(instance) {
    var position = instance.find_fallback_position();
    var winner = populate_fish(FishSpawn.Divespot, undefined, instance.water_kind, position.x, position.y).get_candidate();
    if winner == undefined {
        return undefined;
    }
    var new_divespot = instance_create_depth(position.x, position.y, 0, obj_divespot);
    if instance_exists(new_divespot) {
        new_divespot.initialise(new DiveSpot(winner));

        //
        if MIST.is_running() {
            new_divespot.visible = false;
            instance_deactivate_object(new_divespot);
        }
    }

    return new_divespot;
}

function Fish(fish_id) constructor {
    self.prototype = FISH[fish_id];
    if self.prototype.item == ItemId.UnidentifiedArtifact
        && ARI.items_acquired[self.prototype.secondary_item]
    {
        self.item = new LiveItem(self.prototype.secondary_item);
    } else {
        self.item = new LiveItem(self.prototype.item, self.prototype.secondary_item);
    }
    self.size = FISH[fish_id].size;

    static get_bite_time = function(_rod_quality) {
        assert_neq(_rod_quality, undefined, "Rod quality is undefined! Need to pass in player's rod.");
        var bite_times = fiddle_get("fishing/bite_times");
        var this_rod = bite_times[_rod_quality];
        var this_fish = this_rod[$ self.prototype.legendary ? "legendary" : fish_size_to_string(self.size)];
        return this_fish;
    }

    static get_celebration_data_essence_exp = function() {
        var essence = fiddle_get(format("fishing/essence_gains/{FishSize}_fish", self.prototype.size));
        var modifier_amt = fish_size_to_xp_value(self.prototype.size);

        return {
            essence,
            modifier_amt,
            stamina_modifier: -fiddle_get(format("fishing/stamina_costs/{FishSize}_fish", self.prototype.size)),
            item: self.item,
            is_fish: true,
            fish_prototype: self.prototype,
        }
    }
}

function DiveSpot(dive_fish) constructor {
    self.fish_prototype = FISH[dive_fish];

    if fish_prototype.item == ItemId.UnidentifiedArtifact
        && ARI.items_acquired[self.fish_prototype.secondary_item]
    {
        self.item = new LiveItem(self.fish_prototype.secondary_item);
    } else {
        self.item = new LiveItem(self.fish_prototype.item, self.fish_prototype.secondary_item);
    }

    static get_celebration_data = function() {
        return {
            item: self.item,
            is_fish: true,
            fish_prototype: self.fish_prototype,
        }
    }
}

//
//
//
//
//
function populate_fish(spawn_type, fish_size, water_type, xx, yy) {
    var distribution;
    switch spawn_type {
        case FishSpawn.Fish:
        case FishSpawn.School:
            distribution = FISH_DISTRIBUTIONS;
            break;

        case FishSpawn.Divespot:
            distribution = DIVESPOT_DISTRIBUTION;
            break;
        default: impossible("unexpected spawn type");
    }

    FISH_CONDITION_DATA.water_type = water_type;
    if fish_size == undefined {
        //
        FISH_CONDITION_DATA.size = FishSize.Small;
        FISH_CONDITION_DATA.all_any_size = true;
    } else {
        FISH_CONDITION_DATA.size = fish_size;
        FISH_CONDITION_DATA.all_any_size = false;
    }

    return distribution
        .get_candidate_votes_at_cell(GRID, xx div 8, yy div 8);
}
