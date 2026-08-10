global.__dungeon_runner = undefined;
#macro DUNGEON_RUNNER global.__dungeon_runner
#macro DUNGEON_BIOME global.__dungeon_runner.current_level().biome
#macro DUNGEON_IMPL global.__dungeon_runner.current_level().impl
#macro DUNGEON_FLOOR global.__dungeon_runner.current_floor
#macro DUNGEON_FLOOR_COUNT fiddle_get("dungeons/misc/max_floors")
#macro MAX_DUNGEON_FLOOR (DUNGEON_FLOOR_COUNT - 1)

#macro DUNGEON global.__dungeon
global.__dungeon = undefined;

#macro DUNGEON_TREASURE global.__dungeon_treasure
DUNGEON_TREASURE = undefined;

function load_dungeon() {
    var data = fiddle_get("dungeons/dungeons");
    var biomes = array_map(data.biomes, function(biome) {
        var votes = [];
        for (var k = 0; k < DungeonSpawn.LEN; k++) {
            var these_votes = new SpawnDistribution();
            array_push(votes, these_votes);
            var spawn_key = dungeon_spawn_to_string(k);
            var vote_data = biome.votes[$ spawn_key];
            if vote_data == undefined {
                continue;
            }

            for (var h = 0; h < array_length(vote_data); h++) {
                var conditions = new SpawnConditions();
                var vote = vote_data[h];
                var element = undefined;
                switch k {
                    case DungeonSpawn.Enemy:
                    case DungeonSpawn.EnemyImplEnemy:
                    case DungeonSpawn.MiniBossEnemy:
                    case DungeonSpawn.MiniBossEnemyImplEnemy:
                        element = string_to_monster_id(vote.object);
                        break;
                    case DungeonSpawn.Bug:
                        element = string_to_item_id(vote.object);
                        conditions.require(Condition.BugIsValid(element)); //
                        break;
                    case DungeonSpawn.Fish:
                        element = string_to_fish_id(vote.object);
                        conditions.require(Condition.FishIsValid(element)); //
                        break;
                    case DungeonSpawn.VoidPearl:
                        element = string_to_fish_id(vote.object);
                        break;
                    default:
                        element = string_to_object_id(vote.object);
                        if element == ObjectId.TreasureChestWood {
                            conditions.require(Condition.Invert(Condition.HasPerk(Perk.FantasticFinds)));
                        }
                        break;
                }
                conditions.add(vote[$ "votes"] ?? 1, Condition.None);
                these_votes.add_candidate(element, conditions);
            }
        }
        var furniture_checked = {};
        var recipes = [];

        for (var i = 0, c = array_length(biome.furniture); i < c; i++) {
            var item_id = string_to_item_id(biome.furniture[i]);
            if ITEM_PROTOTYPES[item_id][$ "recipe_key"] != undefined && furniture_checked[$ ITEM_PROTOTYPES[item_id][$ "recipe_key"]] == undefined {
                array_push(recipes, item_id);
                furniture_checked[$ ITEM_PROTOTYPES[item_id][$ "recipe_key"]] = true;
            } else if ITEM_PROTOTYPES[item_id][$ "recipe_key"] == undefined {
                array_push(recipes, item_id);
            }
        }

        return {
            name: biome.name,
            asset_insert: biome.asset_insert,
            votes: votes,
            music: biome.music,
            floor: biome.floor,
            artifact_set: biome.artifact_set,
            ore: string_to_item_id(biome.ore),
            gem: string_to_item_id(biome.gem),
            combat_xp_gain: biome.combat_xp_gain,
            cosmetics: array_map(biome.cosmetics, validate_cosmetic),
            armor: array_map(biome.armor, string_to_item_id),
            dungeon_delicacies: array_map(biome.dungeon_delicacies, string_to_item_id),
            shrine: {
                inputs: array_map(biome.shrine.inputs, function(item_desc) {
                    return {
                        item_id: string_to_item_id(item_desc.item_id),
                        amount: item_desc.amount,
                    }
                }),
                outputs: struct_to_array(biome.shrine.outputs, Shrine.LEN, string_to_shrine),
            },
            taste_maker: array_map(biome.taste_maker, string_to_item_id),
            furniture: array_map(biome.furniture, string_to_item_id),
            recipes: recipes,
            ladder_chance_range: biome.ladder_chance_range,
            object_element_points: biome.object_element_points,
            monster_element_points: biome.monster_element_points,
        };
    });

    //
    var f_ranges = fiddle_get("dungeons/level_ranges");
    var f_range_keys = struct_get_names(f_ranges);

    var level_ranges = [];
    for (var i = 0, c = DUNGEON_FLOOR_COUNT; i < c; i++) {
        var this_floor = [];
        for (var j = 0; j < array_length(f_range_keys); j++) {
            var rm = string_to_asset(f_range_keys[j]);
            var range = f_ranges[$ f_range_keys[j]];
            if is_between_inclusive(i + 1, range[0], range[1]) {
                array_push(this_floor, rm);
            }
        }
        array_push(level_ranges, this_floor);
    }

    var overrides = fiddle_get("dungeons/level_overrides");
    var override_keys = struct_get_names(overrides);
    for (var i = 0; i < array_length(override_keys); i++) {
        var rm = string_to_asset(override_keys[i]);
        var flr = overrides[$ override_keys[i]];
        level_ranges[flr - 1] = [rm];
    }

    //
    var f_decorations = fiddle_get("dungeons/decorations");
    var decorations = array_create(DungeonDecor.LEN, undefined);
    var sprite_to_decorations = Map();

    var base = f_decorations[$ "default"];

    for (var i = 0; i < DungeonDecor.LEN; i++) {
        var decoration = f_decorations[$ dungeon_decor_to_string(i)];

        //
        var sprites = array_create(array_length(decoration.sprites), undefined);
        for (var j = 0; j < array_length(decoration.sprites); j++) {
            sprites[j] = string_to_asset(decoration.sprites[j]);
            sprite_to_decorations.set(sprites[j], {
                decoration_id: i,
                spr_index: j,
            });
        }

        var size = fiddle_deserialize_vec2(decoration[$ "size"] ?? base.size);
        var collision_grid = parse_collision_strings(
            size,
            decoration[$ "collision_grid"] ?? base.collision_grid,
            undefined
        );

        decorations[i] = {
            sprites,
            offset: fiddle_deserialize_vec2(
                decoration[$ "offset"] ?? base.offset
            ),
            collision_offset: fiddle_deserialize_vec2(
                decoration[$ "collision_offset"] ?? base.collision_offset
            ),
            size,
            collision_grid,
            on_floor: decoration[$ "on_floor"] ?? base.on_floor,
            depth_offset: decoration[$ "depth_offset"] ?? base.depth_offset,
            top_sprites: opt_and_then(decoration[$ "top_sprites"], function(a) {
                return array_map(a, string_to_asset);
            }),
            light: opt_and_then(decoration[$ "light"], string_to_light),
            light_offset: fiddle_deserialize_vec2(decoration[$ "light_offset"] ?? base.light_offset),
            sound: opt_and_then(decoration[$ "sound"], audio_asset_assert_exists),
            sound_emitter_size: fiddle_deserialize_vec2(
                decoration[$ "sound_emitter_size"] ?? base.sound_emitter_size
            ),
            dark_light: opt_and_then(decoration[$ "dark_light"], function(data) {
                return {
                    sprite: string_to_asset(data.sprite),
                    light: string_to_light(data.light),
                }
            })
        };
    }

    return {
        biomes,
        level_ranges,
        decorations,
        sprite_to_decorations,
    }
}

//
function dungeon_impl_to_layer_name(impl) {
    return "impl_" + dungeon_impl_to_string(impl);
}

//
function dungeon_level_contains_elevator(index) {
    return (index + 1) % fiddle_get("dungeons/misc/elevator_frequency") == 0;
}

//
//
function current_dungeon_biome() {
    switch CURRENT_LOCATION_ID {
        case LocationId.Dungeon: return DUNGEON_BIOME;
        case LocationId.WaterSeal: return DungeonBiome.Upper;
        case LocationId.EarthSeal: return DungeonBiome.TideCaverns;
        case LocationId.FireSeal: return DungeonBiome.DeepEarth;
        case LocationId.RuinsSeal: return DungeonBiome.LavaCaves;
        default: return undefined;
    }
}

function floor_to_dungeon_biome(flr) {
    var visual_index = flr + 1;
    var biome = undefined;
    for (var i = 0; i < array_length(DUNGEON.biomes); i++) {
        var this_biome = DUNGEON.biomes[i];
        if this_biome.floor <= visual_index  {
            biome = i;
        }
    }
    return biome;
}



//
enum DungeonBiome {
    Upper,
    TideCaverns,
    DeepEarth,
    LavaCaves,
    Ruins,
    LEN
}

//
enum DungeonSpawn {
    SmallRock,
    LargeRock,
    OreRock,
    SeamRock,
    Chest,
    Junk,
    Enemy,
    EnemyImplEnemy,
    Forageable,
    Bug,
    Fish,
    Artifact,
    Breakable,
    WaterForageable,
    VoidRock,
    VoidHerb,
    VoidPearl,
    MiniBossEnemy,
    MiniBossEnemyImplEnemy,
    LEN
}

//
enum ProtoTile {
    Void,
    Ground,
    Wall,
    GroundBright,
    GroundDark,
    GroundRuins,
    Water,
    Lava,
    JumpableVoid,
    DarkWater,
    DarkLava,
}

//
enum InteractState {
    Deactivated,
    Transition,
    Activated,
}
