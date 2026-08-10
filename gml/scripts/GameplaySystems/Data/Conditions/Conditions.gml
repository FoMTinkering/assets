enum ConditionId {
    None,
    TimeBetween,
    HasItemInInventory,
    CurrentLocation,
    CurrentDungeonBiome,
    CurrentWeather,
    CurrentSeason,
    InDungeon,
    HasRecipeUnlocked,
    Invert,
    And,
    Or,
    TileFlagAtCell,
    TerrainKindAtCell,
    GroundKindAtCell,
    NoCollisionAtCell,
    FishIsValid,
    BugIsValid,
    HasPerk,
    LegendaryNotCaught,
    PursuitIsActive,
    Sand,
    BugTag,

    NoCosmetic,
    NoRecipe,
    LEN
}

function ConditionFactory() constructor {
    static None = {
        type: ConditionId.None
    }
    static Invert = function(condition) {
        return {
            type: ConditionId.Invert,
            condition: condition,
        }
    }
    static And = function() {
        assert(argument_count >= 2, "Must have at least two conditions for an 'And' condition!");
        var conditions = array_create(argument_count);
        for(var i = 0; i < argument_count; i++) {
            conditions[i] = argument[i];
        }
        return {
            type: ConditionId.And,
            conditions: conditions
        }
    }
    static Or = function() {
        var conditions = array_create(argument_count);
        for(var i = 0; i < argument_count; i++) {
            conditions[i] = argument[i];
        }
        return {
            type: ConditionId.Or,
            conditions: conditions
        }
    }
    static TimeBetween = function(minimum, maximum) {
        return {
            type: ConditionId.TimeBetween,
            minimum: minimum,
            maximum: maximum,
        }
    }
    static HasItemInInventory = function(item, count) {
        return {
            type: ConditionId.HasItemInInventory,
            item: item,
            count: count,
        }
    }
    static CurrentLocation = function(location) {
        return {
            type: ConditionId.CurrentLocation,
            location: location,
        }
    }
    static CurrentDungeonBiome = function(biome) {
        return {
            type: ConditionId.CurrentDungeonBiome,
            biome: biome,
        }
    }
    static InDungeon = {
        type: ConditionId.InDungeon
    }
    static CurrentWeather = function(weather) {
        return {
            type: ConditionId.CurrentWeather,
            weather: weather,
        }
    }
    static CurrentSeason = function(season) {
        return {
            type: ConditionId.CurrentSeason,
            season: season,
        }
    }
    static HasRecipeUnlocked = function(recipe_id) {
        return {
            type: ConditionId.HasRecipeUnlocked,
            recipe_id,
        }
    }
    static TileFlagAtCell = function(tile_flag) {
        return {
            type: ConditionId.TileFlagAtCell,
            tile_flag: tile_flag,
        }
    }
    static TerrainKindAtCell = function(terrain_id) {
        return {
            type: ConditionId.TerrainKindAtCell,
            terrain_id: terrain_id,
        }
    }
    static GroundKindAtCell = function(terrain_id) {
        return {
            type: ConditionId.GroundKindAtCell,
            terrain_id: terrain_id,
        }
    }
    static NoCollisionAtCell = {
        type: ConditionId.NoCollisionAtCell,
    }
    static FishIsValid = function(fish_id) {
        return {
            type: ConditionId.FishIsValid,
            fish_id,
        }
    }

    static BugIsValid = function(bug_id) {
        return {
            type: ConditionId.BugIsValid,
            bug_id,
        }
    }

    static HasPerk = function(perk) {
        return {
            type: ConditionId.HasPerk,
            perk: perk
        }
    }

    static LegendaryNotCaught = function(season) {
        return {
            type: ConditionId.LegendaryNotCaught,
            season,
        }
    }

    static PursuitIsActive = {
        type: ConditionId.PursuitIsActive,
    }

    static NoCosmetic = function(cosmetic) {
        return {
            cosmetic,
            type: ConditionId.NoCosmetic,
        }
    }

    static NoRecipe = function(recipe) {
        return {
            recipe,
            type: ConditionId.NoRecipe,
        }
    }

    static Sand = {
        type: ConditionId.Sand,
    }

    static BugTag = function(bug_tag) {
        return {
            bug_tag,
            type: ConditionId.BugTag,
        }
    }
}

global.condition_factory = new ConditionFactory();
#macro Condition global.condition_factory

//
function test_condition(grid, condition, cell_x, cell_y) {
    switch condition.type {
        case ConditionId.None:
            return true;

        case ConditionId.HasPerk:
            return ARI.perk_active(condition.perk)

        case ConditionId.LegendaryNotCaught:
            return ARI.legendary_fish_caught[condition.season] == false;

        case ConditionId.TimeBetween:
            var time = CLOCK.time;
            return time >= condition.minimum && time <= condition.maximum;

        case ConditionId.HasItemInInventory:
            return ARI.inventory.item_id_quantity(condition.item) >= condition.count;

        case ConditionId.CurrentLocation:
            return grid.location_id == condition.location;

        case ConditionId.CurrentDungeonBiome:
            return (DUNGEON_RUNNER != undefined ? DUNGEON_BIOME : undefined) == condition.biome;

        case ConditionId.InDungeon: return DUNGEON_RUNNER != undefined;

        case ConditionId.CurrentWeather:
            return WEATHER.weather == condition.weather;

        case ConditionId.CurrentSeason:
            return CALENDAR.season() == condition.season;

        case ConditionId.HasRecipeUnlocked:
            return ari_has_recipe_anywhere(condition.recipe_id);

        case ConditionId.Invert:
            return !test_condition(grid, condition.condition, cell_x, cell_y);

        case ConditionId.And:
            for(var i = 0, c = array_length(condition.conditions); i < c; i++) {
                if(!test_condition(grid, condition.conditions[i], cell_x, cell_y)) {
                    return false;
                }
            }
            return true;

        case ConditionId.Or:
            for(var i = 0, c = array_length(condition.conditions); i < c; i++) {
                if(test_condition(grid, condition.conditions[i], cell_x, cell_y)) {
                    return true;
                }
            }
            return false;

        case ConditionId.TileFlagAtCell:
            return grid.tile_flag_satisfies(
                cell_x,
                cell_y,
                condition.tile_flag
            );

        case ConditionId.TerrainKindAtCell:
            return grid.node_terrain_kind[grid.node_index_for_cell(cell_x, cell_y)] == condition.terrain_id;

        case ConditionId.GroundKindAtCell:
            var ni = grid.node_index_for_cell(cell_x, cell_y);
            if grid.node_terrain_kind[ni] == TerrainKind.Ground {
                return grid.node_terrain_ground_kind[ni] == condition.terrain_id;
            } else {
                return false;
            }

        case ConditionId.NoCollisionAtCell:
            var ni = grid.try_node_index_for_cell(cell_x, cell_y);
            return ni != undefined && grid.node_collideable[ni] == false;

        case ConditionId.FishIsValid:
            var fish = FISH[condition.fish_id];

            //
            //
            if FISH_CONDITION_DATA.bait != undefined
                && (fish.rarity_value >= FISH_CONDITION_DATA.bait.attract.min_rarity
                || fish.rarity_value < FISH_CONDITION_DATA.bait.attract.max_rarity)
            {
                return false;
            }

            //
            if is_dungeon_room(room()) {
                return true;
            }

            var water_check = false;
            for (var i = 0; i < array_length(fish.water_type); i++) {
                if fish.water_type[i] == FISH_CONDITION_DATA.water_type {
                    water_check = true;
                }
            }
            if water_check == false {
                return false;
            }

            //
            if fish.bait_only && FISH_CONDITION_DATA.bait == undefined {
                return false;
            }

            return FISH_CONDITION_DATA.all_any_size
                || (fish.any_size && FISH_CONDITION_DATA.size != FishSize.Giant)
                || fish.size == FISH_CONDITION_DATA.size;

        case ConditionId.BugIsValid:
            var bug = BUGS.get(condition.bug_id);

            if BUG_CONDITION_DATA.bait != undefined {
                if bug.can_spawn_on_water {
                    return false;
                }
                if bug.rarity_value >= BUG_CONDITION_DATA.bait.attract.min_rarity
                    || bug.rarity_value < BUG_CONDITION_DATA.bait.attract.max_rarity {
                    return false;
                }
            //
            } else if bug.pheromones_only {
                return false;
            }

            return BUG_CONDITION_DATA.spawn_type == undefined || array_contains(bug.spawn, BUG_CONDITION_DATA.spawn_type);

        case ConditionId.PursuitIsActive:
            return ARI.active_pursuit;

        case ConditionId.NoCosmetic:
            return ari_has_cosmetic_anywhere(condition.cosmetic) == false;

        case ConditionId.NoRecipe:
            return ari_has_recipe_anywhere(condition.recipe) == false;

        case ConditionId.Sand:
            //
            return grid.location_id == LocationId.Beach && grid.node_footstep_kind[grid.node_index_for_cell(cell_x, cell_y)] == FootstepKind.Sand;

        case ConditionId.BugTag:
            return intersects_flag(LOCATIONS[grid.location_id].bug_tag, condition.bug_tag);

        default: impossible("Condition {} test unimplemented!", condition.type);
    }
}

//
function clone_condition(condition) {
    switch condition.type {
        case ConditionId.None:
            return Condition.None;

        case ConditionId.HasPerk:
            return Condition.HasPerk(condition.perk);

        case ConditionId.TimeBetween:
            return Condition.TimeBetween(condition.minimum, condition.maximum);

        case ConditionId.HasItemInInventory:
            return Condition.HasItemInInventory(condition.item, condition.count);

        case ConditionId.CurrentLocation:
            return Condition.CurrentLocation(condition.location);

        case ConditionId.CurrentDungeonBiome:
            return Condition.CurrentDungeonBiome(condition.biome);

        case ConditionId.InDungeon:
            return Condition.InDungeon;

        case ConditionId.CurrentWeather:
            return Condition.CurrentWeather(condition.weather);

        case ConditionId.CurrentSeason:
            return Condition.CurrentSeason(condition.season);

        case ConditionId.HasRecipeUnlocked:
            return Condition.HasRecipeUnlocked(condition.recipe_id);

        case ConditionId.Invert:
            return Condition.Invert(clone_condition(condition.condition));

        case ConditionId.And:
            return {
                type: ConditionId.And,
                conditions: array_map(condition.conditions, clone_condition)
            }

        case ConditionId.Or:
            return {
                type: ConditionId.Or,
                conditions: array_map(condition.conditions, clone_condition)
            }
        case ConditionId.TileFlagAtCell:
            return Condition.TileFlagAtCell(condition.tile_flag);

        case ConditionId.TerrainKindAtCell:
            return Condition.TileFlagAtCell(condition.terrain_kind);

        case ConditionId.GroundKindAtCell:
            return Condition.GroundKindAtCell(condition.terrain_id);

        case ConditionId.NoCollisionAtCell:
            return Condition.NoCollisionAtCell;

        case ConditionId.FishIsValid:
            return Condition.FishIsValid(condition.fish_id);
        case ConditionId.BugIsValid:
            return Condition.BugIsValid(condition.bug_id);
        case ConditionId.PursuitIsActive:
            return Condition.PursuitIsActive;

        case ConditionId.LegendaryNotCaught:
            return Condition.LegendaryNotCaught(condition.season);

        case ConditionId.Sand:
            return Condition.Sand;

        case ConditionId.BugTag:
            return Condition.BugTag(condition.bug_tag);

        default: impossible("Condition {} test unimplemented!", condition.type);
    }
}

//
function condition_clone() {
    assert_eq(
        json_stringify(Condition.HasItemInInventory(ItemId.Apple)),
        json_stringify(clone_condition(Condition.HasItemInInventory(ItemId.Apple))),
    );

    assert_eq(
        json_stringify(Condition.FishIsValid(ItemId.Trout)),
        json_stringify(clone_condition(Condition.FishIsValid(ItemId.Trout))),
    );
}
