#macro BUGS global.__bugs
global.__bugs = undefined;

#macro BUG_DISTRIBUTION global.__bug_distribution
global.__bug_distribution = undefined;

#macro BUG_CONDITION_DATA global.__bug_condition_data

function load_bugs() {
    var collection = {
        bugs: Map(),
        distribution: new SpawnDistribution(),
    }
    var bugs = fiddle_get("bugs");
    var bug_names = struct_get_names(bugs);
    var bug_default = bugs[$ "default"];
    var default_keys = struct_get_names(bug_default);

    var perk_pollinator_data = fiddle_get(format("perks/{Perk}", Perk.PerfectPollinators));

    for (var i = 0; i < array_length(bug_names); i++) {
        var bug_key = bug_names[i];
        if bug_key == "default" {
            continue;
        }
        var item_id = string_to_item_id(bug_key);
        var bug = bugs[$ bug_key];
        var conditions = new SpawnConditions();
        conditions.require(Condition.BugIsValid(item_id));
        var prototype = {};

        //
        for (var j = 0; j < array_length(default_keys); j++) {
            var key = default_keys[j];
            var value = bug[$ key] ?? bug_default[$ key];
            switch key {
                case "type":
                    prototype.type = string_to_bug_movement_type(bug[$ key] ?? bug_default[$ key]);
                    break;
                case "idle_sprite":
                    if value == "<..>" {
                        value = fmt("spr_insect_{}_entity_idle", string_replace_all(bug_key, "_", ""));
                    }
                    prototype.idle_sprite = string_to_asset(value);
                    break;
                case "move_sprite":
                    if value == "<..>" {
                        value = fmt("spr_insect_{}_entity_move", string_replace_all(bug_key, "_", ""));
                    }
                    prototype.move_sprite = string_to_asset(value);
                    break;
                case "spawn":
                    prototype.spawn = [];
                    if is_array(value) {
                        prototype.spawn = array_map(value, string_to_bug_spawn_type);
                    } else {
                        prototype.spawn = [string_to_bug_spawn_type(value)];
                    }

                    break;
                case "seasons":
                    var condition = Condition.Or();
                    for (var k = 0; k < array_length(value); k++) {
                        array_push(condition.conditions, Condition.CurrentSeason(string_to_season(value[k])));
                    }
                    conditions.require(condition);
                    break;
                case "hours":
                    conditions.require(Condition.TimeBetween(hours(value[0]), hours(value[1])));
                    break;
                case "weather":
                    var condition = Condition.Or();
                    for (var k = 0; k < array_length(value); k++) {
                        array_push(condition.conditions, Condition.CurrentWeather(string_to_weather(value[k])));
                    }
                    conditions.require(condition);
                    break;
                case "rarity":
                    var rarity = fiddle_get(format("bug_rates/{}", value));
                    if value == "rare" {
                        conditions.add(perk_pollinator_data.vote_change[0], Condition.HasPerk(Perk.PerfectPollinators));
                    } else if value == "very_rare" {
                        conditions.add(perk_pollinator_data.vote_change[1], Condition.HasPerk(Perk.PerfectPollinators));
                    }
                    conditions.add(rarity);
                    prototype.rarity = value;
                    prototype.rarity_value = rarity;
                    break;
                case "tag":
                    conditions.require(Condition.BugTag(parse_bug_tag(value)));
                    break;
                case "can_spawn_on_water":
                    prototype.can_spawn_on_water = value;
                    break;
                case "dungeon_biome":
                    var req;
                    if value != -1 {
                        req = Condition.CurrentDungeonBiome(string_to_dungeon_biome(value));
                    } else {
                        req = Condition.Invert(Condition.InDungeon);
                    }
                    conditions.require(req);
                    break;
                case "attraction":
                    prototype.attraction = string_to_bug_attraction(value);
                    break;
                default:
                    prototype[$ key] = value;
                    break;
            }
        }

        //
        if matches(prototype.type, BugMovementType.Fly, BugMovementType.FlyWave) {
            //
            prototype.acceptable_terrain = undefined;
        } else if prototype.can_spawn_on_water {
            prototype.acceptable_terrain = TerrainKind.Water;
        } else {
            prototype.acceptable_terrain = TerrainKind.Ground;
        }

        collection.distribution.add_candidate(item_id, conditions);
        collection.bugs.set(item_id, prototype);
    }
    return collection;
}

function reset_bug_condition_data() {
    BUG_CONDITION_DATA = {
        spawn_type: undefined,
        bait: undefined,
    };
}

reset_bug_condition_data();
