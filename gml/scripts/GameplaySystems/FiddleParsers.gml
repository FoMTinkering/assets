#macro ATE_SOUP global.__ate_soup
global.__ate_soup = false;

#macro WORLD_FOUNTAINS global.__world_fountains
WORLD_FOUNTAINS = undefined;

#macro USED_WISHING_WELL global.__used_wishing_well
global.__used_wishing_well = false;

#macro BANNED_BARKS global.__banned_barks
global.__banned_barks = List();

#macro MALE_ANIMAL_NAMES global.__male_animal_names
MALE_ANIMAL_NAMES = undefined;

#macro FEMALE_ANIMAL_NAMES global.__female_animal_names
FEMALE_ANIMAL_NAMES = undefined;

#macro MALE_CHILD_NAMES global.__male_child_names
MALE_CHILD_NAMES = undefined;

#macro FEMALE_CHILD_NAMES global.__female_child_names
FEMALE_CHILD_NAMES = undefined;

#macro GAMEPLAY_CONVERSATIONS global.__gameplay_conversations
GAMEPLAY_CONVERSATIONS = undefined;

#macro FOOTSTEPS global.__footsteps
FOOTSTEPS = undefined;

#macro SEAL_INVENTORIES global.__seal_inventories
SEAL_INVENTORIES = undefined;

#macro ANIMAL_HEART_POINTS global.__animal_heart_points
ANIMAL_HEART_POINTS = undefined;

#macro ANIMAL_XP global.__animal_xp
ANIMAL_XP = undefined;

#macro TILE_CURSORS global.__tile_cursors
TILE_CURSORS = undefined;

#macro TUTORIALS global.__tutorials
TUTORIALS = undefined;

#macro BIRD_CATALOGUE global.__bird_catalogue
BIRD_CATALOGUE = undefined;

#macro ILLEGAL_WINTER_SPRITES global.__illegal_winter_sprites
ILLEGAL_WINTER_SPRITES = undefined;

#macro FLAVOR_TEXT global.__flavor_text
FLAVOR_TEXT = undefined;

#macro RUMBLE_DATABSE global.__rumble_database
RUMBLE_DATABSE = undefined;

#macro EXTERIOR_LIGHTS global.__exterior_lights
EXTERIOR_LIGHTS = undefined;

#macro INTERIOR_LIGHTS global.__interior_lights
INTERIOR_LIGHTS = undefined;

#macro LIGHTS global.__lights
LIGHTS = undefined;

#macro LIGHT_SIZES global.__light_sizes
LIGHT_SIZES = undefined;


#macro OUTLINE_DICTIONARY global.__outline_dictionary
global.__outline_dictionary = undefined;

#macro ANCIENT_INSPIRATION global.__ancient_inspiration
global.__ancient_inspiration = undefined;

#macro EARTHLY_ESSENCE global.__earthly_essence
global.__earthly_essence = undefined;

#macro EARTHLY_ESSENCE_ALTERNATIVE global.__earthly_essence_alternative
global.__earthly_essence_alternative = undefined;

#macro MIST_SIGHT global.__mist_sight
global.__mist_sight = undefined;

#macro MIST_SIGHT_ACTIVE_INDEX global.__mist_sight_active_index
global.__mist_sight_active_index = undefined;

#macro ESSENCE_CHARGE global.__essence_charge
ESSENCE_CHARGE = undefined;

#macro EXPANSION_COST global.__expansion_cost
EXPANSION_COST = undefined;

#macro CONTENT_REGISTRY global.__content_registry
CONTENT_REGISTRY = undefined;

#macro TEXT_STYLES global.__text_styles
TEXT_STYLES = undefined;

#macro HAYDEN_PUMPKINS global.__hayden_pumpkins
HAYDEN_PUMPKINS = undefined;

#macro WINDOW_BACKING_TIMES global.__window_backing_timing
WINDOW_BACKING_TIMES = undefined;

#macro SHADOWS_OVERSIZED global.__shadows_oversized
SHADOWS_OVERSIZED = undefined;

#macro TRANSPARENT_ASSETS global.__transparent_assets
TRANSPARENT_ASSETS = undefined;

#macro SECRET_NARROWS global.__secret_narrows
SECRET_NARROWS = 0;

#macro SECRET_BEACH global.__secret_beach
SECRET_BEACH = 0;

#macro SECRET_TOWER global.__secret_tower
SECRET_TOWER = 0;

#macro LOST_AND_FOUND global.__lost_and_found
LOST_AND_FOUND = undefined;

#macro FISH_TRAP_RARITY global.__fish_trap_rarity
FISH_TRAP_RARITY = undefined;

#macro FISH_TRAP_TIMESTAMP global.fish_trap_timestamp
FISH_TRAP_TIMESTAMP = undefined;

#macro ROOMMATE_TIMES global.__roommate_times
ROOMMATE_TIMES = undefined;

#macro SONGS global.__songs
SONGS = undefined;

#macro BELL_SOUNDS global.__bell_sounds
BELL_SOUNDS = undefined;

//
//
//
function create_fiddle_parsers() {
    //
    BANNED_BARKS = ListFromArray(fiddle_get("misc/npc_behavior/barks_random_invalid"));
    for (var i = 0, c = BANNED_BARKS.count(); i < c; i++) {
        BANNED_BARKS.set(i, string_to_bark_id(BANNED_BARKS.get(i)));
    }

    MALE_ANIMAL_NAMES = ListFromArray(fiddle_get("ranching/misc/default_male_names"));
    FEMALE_ANIMAL_NAMES = ListFromArray(fiddle_get("ranching/misc/default_female_names"));

    MALE_CHILD_NAMES = ListFromArray(fiddle_get("misc/default_male_child_names"));
    FEMALE_CHILD_NAMES = ListFromArray(fiddle_get("misc/default_female_child_names"));

    GAMEPLAY_CONVERSATIONS = find_gameplay_conversations();
    FOOTSTEPS = parse_footsteps(fiddle_get("footsteps"));
    ANIMAL_HEART_POINTS = parse_animal_heart_points();
    ANIMAL_XP = fiddle_get("ranching/misc/xp");

    TILE_CURSORS = parse_tile_cursors();

    TUTORIALS = parse_tutorials();
    BIRD_CATALOGUE = parse_bird_catalogue();

    ILLEGAL_WINTER_SPRITES = array_map(fiddle_get("misc/illegal_winter_sprites"), string_to_asset);

    FLAVOR_TEXT = parse_flavor_text();
    RUMBLE_DATABSE = parse_rumble_database();
    EXTERIOR_LIGHTS = parse_exterior_lights();
    INTERIOR_LIGHTS = parse_interior_lights();
    var light_parse = parse_lights();
    LIGHTS = light_parse[0];
    LIGHT_SIZES = light_parse[1];
    ANCIENT_INSPIRATION = ancient_inspiration_load();
    MIST_SIGHT = mist_sight_load();
    EARTHLY_ESSENCE = earthly_essence_load();
    EARTHLY_ESSENCE_ALTERNATIVE = earthly_essence_alternative_load();
    EXPANSION_COST = farm_expansion_cost();
    HAYDEN_PUMPKINS = haydens_pumpkins();
    WINDOW_BACKING_TIMES = window_backing_times();
    SHADOWS_OVERSIZED = parse_oversized_shadows();
    TRANSPARENT_ASSETS = parse_transparent_assets(fiddle_get("transparent_assets"));
    ROOMMATE_TIMES = load_roommate_times();
}

//
//
function ContentRegistry() constructor {
    self.quests = array_concat(
        struct_get_names(fiddle_get("quests/story_quests")),
        struct_get_names(fiddle_get("quests/crown_quests")),
        struct_get_names(fiddle_get("quests/tali_challenges")),
        struct_get_names(fiddle_get("quests/stillwell_challenges")),
        struct_get_names(fiddle_get("quests/heart_quests")),
        struct_get_names(fiddle_get("quests/fetch_quests")),
    );
    self.cutscenes = struct_get_names(fiddle_get("cutscenes"));
    self.letters = struct_get_names(fiddle_get("letters"));

    array_delete(self.cutscenes, array_index(self.cutscenes, "default"), 1);
    array_delete(self.letters, array_index(self.letters, "default"), 1);

    function validate_quest(quest) {
        if DEBUG_ASSERTIONS {
            return array_contains(self.quests, quest) ? quest : undefined;
        } else {
            assert(array_contains(self.quests, quest), "Quest does not exist: '{}'", quest);
            return quest;
        }
    }

    function validate_cutscene(scene) {
        assert(array_contains(self.cutscenes, scene), "Cutscene does not exist: '{}'", scene);
        return scene;
    }

    function validate_letter(letter) {
        assert(array_contains(self.letters, letter), "Letter does not exist: '{}'", letter);
        return letter;
    }
}

function farm_expansion_cost() {
    var upgrade_data = fiddle_get("misc/farm_data/expansion_cost");
    var list = List();

    for (var i = 0, ic = array_length(upgrade_data.items); i < ic; i++) {
        var item = upgrade_data.items[i];

        list.push({
            count: item.count,
            item_id: string_to_item_id(item.item_id)
        });
    }

    return {
        items: list,
        gold: upgrade_data.gold,
        preview: string_to_asset(upgrade_data.preview)
    }
}

function soup_of_the_day() {
    var day = CALENDAR.day_type();
    return local_get(fiddle_get("misc/inn/soup_kinds")[day]);
}

function random_animal_name(sex) {
    var list = sex == Sex.Female ? FEMALE_ANIMAL_NAMES : MALE_ANIMAL_NAMES;
    return list.choose_random();
}

function random_child_name(sex) {
    var list = sex == Sex.Female ? FEMALE_CHILD_NAMES : MALE_CHILD_NAMES;
    return list.choose_random();
}

function tile_cursor_sprite_bundle() {
    if CALENDAR.season() == Season.Winter && LOCATIONS[CURRENT_LOCATION_ID].outdoor {
        return TILE_CURSORS.winter;
    } else {
        return TILE_CURSORS.normal;
    }
}

function haydens_pumpkins() {
    var fiddle_data = fiddle_get("misc/pumpkin_patch_options");
    var list = List();
    for (var i = 0, c = array_length(fiddle_data); i < c; i++) {
        var data = fiddle_data[i];
        for (var j = 0, jc = data.count; j < jc; j++) {
            list.push(string_to_item_id(data.item));
        }
    }
    return list;
}

function parse_footsteps(f_step) {
    var a = array_create(FootstepKind.LEN, undefined);
    for (var i = 0; i < FootstepKind.LEN; i++) {
        var f = f_step[$ footstep_kind_to_string(i)];
        a[i] = {
            walk_sound: f.walk_sound,
            run_sound: f.run_sound,

            mount_walk_sound: f.mount_walk_sound,
            mount_run_sound_front: f.mount_run_sound_front,
            mount_run_sound_back: f.mount_run_sound_back,

            particle_sprites: opt_and_then(f[$ "particle_sprites"], function(f_v) {
                return {
                    horizontal: string_to_asset(f_v.horizontal),
                    vertical: string_to_asset(f_v.vertical),
                }
            }),
            winter_particle_sprites: opt_and_then(f[$ "winter_particle_sprites"], function(f_v) {
                return {
                    horizontal: string_to_asset(f_v.horizontal),
                    vertical: string_to_asset(f_v.vertical),
                }
            }),
        };

        if DEBUG_ASSERTIONS {
            audio_asset_assert_exists(a[i].walk_sound);
            audio_asset_assert_exists(a[i].run_sound);
            audio_asset_assert_exists(a[i].mount_walk_sound);
            audio_asset_assert_exists(a[i].mount_run_sound_front);
            audio_asset_assert_exists(a[i].mount_run_sound_back);
        }
    }

    return a;
}

//
function parse_animal_heart_points() {
    return {
        base_value: fiddle_get("ranching/misc/heart_points/feed"),
        cooked_star_bonuses: fiddle_get("ranching/misc/heart_points/cooked_star_bonuses"),
        feed: array_create_ext(AnimalFeedTier.LEN, function(aft) {
            return fiddle_get(
                format("ranching/misc/heart_points/{AnimalFeedTier}_feed_bonus", aft)
            );
        }),
        crop_tree: fiddle_get("ranching/misc/heart_points/crop_bonus")
    }
}
function create_seal_inventories() {
    return array_create_ext(Seal.LEN, function() {
        return Inventory(4);
    });
}

function parse_flavor_text() {
    var raw_data = fiddle_get("flavor_text");
    var spr_names = struct_get_names(raw_data);
    var output = Map();

    for (var i = 0; i < array_length(spr_names); i++) {
        var spr_name = spr_names[i];
        //
        string_to_asset(spr_name);

        var flavor_text_data = raw_data[$ spr_name];

        var full_name = format("Conversations/flavor_text/{}", flavor_text_data.flavor_text);
        var checker = T2R.fuzzy_search_conversation(NpcId.Caldarus, full_name, ConversationKind.GameplayTriggered);
        assert_eq(checker, full_name);

        var glyph_action = "misc_local/inspect";
        if flavor_text_data[$ "glyph_action"] != undefined {
            glyph_action = format("misc_local/{}", flavor_text_data.glyph_action);
            assert(local_has(glyph_action), "`misc_local/{}` does not exist!", flavor_text_data.glyph_action);
        }

        var alternative = opt_and_then(flavor_text_data[$ "alternative"], function(v) {
            var full_name = format("Conversations/flavor_text/{}", v.flavor_text);
            var checker = T2R.fuzzy_search_conversation(NpcId.Caldarus, full_name, ConversationKind.GameplayTriggered);
            assert_eq(checker, full_name);

            return {
                flavor_text: full_name,
                requirements: parse_requirements(v.requirements),
            };
        });

        output.insert(spr_name, {
            flavor_text: full_name,
            highlight: flavor_text_data[$ "highlight"] == true,
            glyph_action,
            override_mask: opt_and_then(flavor_text_data[$ "override_mask"], string_to_asset),
            alternative,
        });
    }

    return output;
}

#macro INFUSIONS global.__infusions
INFUSIONS = undefined;

function load_infusions() {
    var f_infusions = fiddle_get("infusions");
    var keys = struct_get_names(f_infusions);
    var output = Map();
    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];
        var infusion = clone_value(f_infusions[$ key]);
        infusion.required_perk = opt_and_then(infusion[$ "required_perk"], string_to_perk);
        infusion.craftable = infusion[$ "craftable"] ?? true;
        infusion.sub_icon = string_to_asset(infusion.sub_icon);
        infusion.tooltip_icon = string_to_asset(infusion.tooltip_icon);
        output.insert(string_to_infusion(key), infusion);
    }

    return output;
}

function parse_tile_cursors() {
    var raw = fiddle_get("tile_cursor");

    return {
        normal: {
            tool: [
                string_to_asset(raw.normal.tool.invalid),
                string_to_asset(raw.normal.tool.valid),
            ],
            furniture: [
                string_to_asset(raw.normal.furniture.invalid),
                string_to_asset(raw.normal.furniture.valid),
            ],
        },
        winter: {
            tool: [
                string_to_asset(raw.winter.tool.invalid),
                string_to_asset(raw.winter.tool.valid),
            ],
            furniture: [
                string_to_asset(raw.winter.furniture.invalid),
                string_to_asset(raw.winter.furniture.valid),
            ],
        },
    }
}

function parse_tutorials() {
    var f = fiddle_get("ui/tutorials");
    var a = array_create(Tutorial.LEN, undefined);
    for (var i = 0; i < Tutorial.LEN; i++) {
        var tut = clone_value(f[$ tutorial_to_string(i)]);
        for (var j = 0; j < array_length(tut.steps); j++) {
            tut.steps[j].sprite = string_to_asset(tut.steps[j].sprite);
        }
        a[i] = tut;
    }
    return a;
}

function parse_bird_catalogue() {
    var f = fiddle_get("birds");
    var f_default_birds = f[$ "default"];

    var output = array_create(Bird.LEN, undefined);

    for (var i = 0; i < Bird.LEN; i++) {
        var obj = clone_value(f_default_birds);
        patch_object(f[$ bird_to_string(i)], obj);

        //
        var sprite_names = struct_get_names(obj.sprites);
        for (var k = 0; k < array_length(sprite_names); k++) {
            var spr = obj.sprites[$ sprite_names[k]];

            var spr_lookup;
            if is_struct(spr) {
                spr_lookup = struct_to_array(spr, Cardinal.LEN, string_to_cardinal);
                spr_lookup[Cardinal.West] = spr_lookup[Cardinal.East];
                spr_lookup = array_map(spr_lookup, string_to_asset);
            } else {
                spr_lookup = array_create(Cardinal.LEN, string_to_asset(spr));
            }

            obj.sprites[$ sprite_names[k]] = spr_lookup;
        }

        obj.idle_time = fiddle_deserialize_vec2(obj.idle_time);
        obj.look_number = fiddle_deserialize_vec2(obj.look_number);
        obj.sleep_number = fiddle_deserialize_vec2(obj.sleep_number);
        obj.votes = struct_to_array(obj.votes, BirdAction.LEN, string_to_bird_action);

        output[i] = obj;
    }

    return output;
}

function parse_exterior_lights() {
    var f = fiddle_get("exterior_lights");
    var output = Map();

    var keys = struct_get_names(f);
    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];

        //
        string_to_asset(key);

        var value = string_to_asset(f[$ key]);

        output.insert(key, value);
    }

    return output;
}


function parse_interior_lights() {
    var f = fiddle_get("interior_lights");
    var output = Map();

    var keys = struct_get_names(f);
    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];

        //
        string_to_asset(key);
        var data = f[$ key];

        output.insert(key, {
            offset: fiddle_deserialize_vec2(data.offset),
            light: string_to_light(data.light),
        });
    }

    return output;
}


function parse_lights() {
    var f = fiddle_get("lights");

    var output = array_create(Light.LEN, undefined);
    var sizes = array_create(Light.LEN, undefined);

    for (var i = 0; i < Light.LEN; i++) {
        var light_data = f[$ light_to_string(i)];

        output[i] = array_map(light_data.sprites, string_to_asset);
        sizes[i] = light_data.size;
    }

    return [output, sizes];
}

function ancient_inspiration_load() {
    var data = fiddle_get("misc").ancient_inspiration_table;
    return array_map(data, string_to_item_id);
}

function mist_sight_load() {
    return array_map(fiddle_get("misc").mist_sight_table, function(item) {
        var item_id = string_to_item_id(item.item_id);
        if item[$ "inner_data"] == undefined {
            assert(item_id != ItemId.UnidentifiedArtifact && item_id != ItemId.RecipeScroll && item_id != ItemId.Cosmetic, "An item id {ItemId} was supplied without inner data despite needing it!");
            return {
                item_id
            }
        } else {
            return {
                item_id,
                inner_data: item_id == ItemId.UnidentifiedArtifact || item_id == ItemId.RecipeScroll ? string_to_item_id(item.inner_data) : item.inner_data
            }
        }
    });
}

function earthly_essence_load() {
    var arr = array_create(Season.LEN, undefined);
    var data = fiddle_get("misc/earthly_essence");
    var names = struct_get_names(data);
    for (var i = 0, c = array_length(names); i < c; i++) {
        var season = names[i];
        arr[string_to_season(season)] = array_map(data[$ season], function(item) {
            var item_id = string_to_item_id(item.item_id);
            return {
                item_id,
                inner_data: item_id == ItemId.RecipeScroll ? string_to_item_id(item.inner_data) : item.inner_data
            };
        })
    }
    return arr;
}

function earthly_essence_alternative_load() {
    var arr = [];
    var data = fiddle_get("misc/earthly_essence_alternative");
    for (var i = 0, c = array_length(data); i < c; i++) {
        var sub_data = data[i];
        var item_id = string_to_item_id(sub_data.item_id);
        var payload = {
            item_id
        }

        if item_id == ItemId.Purse {
            payload.gold = sub_data.gold;
        }

        array_push(arr, payload);
    }
    return arr;
}

function load_text_styles() {
    var output = {};
    var f = fiddle_get("ui/text_styles");
    var keys = struct_get_names(f);
    var languages = local_get_all_languages();
    for (var i = 0; i < array_length(keys); i++) {
        var k = keys[i];
        var v = f[$ k];
        var this_pack = {};
        for (var j = 0; j < array_length(languages); j++) {
            var language = languages[j];
            var entry = v[$ language];
            if entry == undefined {
                entry = f.standard[$ language];
            }
            this_pack[$ language] = string_to_asset(entry);
        }

        output[$ k] = this_pack;
    }

    for (var i = 0; i < array_length(languages); i++) {
        assert_neq(output.standard[$ languages[i]], undefined, "All languages must declare themselves into the standard text_style!");
    }

    return output;
}

function load_songs() {
    var output = {};
    var f = fiddle_get("songs");
    var keys = struct_get_names(f);
    for (var i = 0 ; i < array_length(keys); i++) {
        var key = keys[i];
        output[key] = f[key];
        output[key].icon = string_to_asset(output[key].icon);
    }
    return output;
}

function load_bell_sounds() {
    var output = {};
    var f = fiddle_get("bell_sounds");
    var keys = struct_get_names(f);
    for (var i = 0 ; i < array_length(keys); i++) {
        var key = keys[i];
        output[key] = f[key];
        output[key].icon = string_to_asset(output[key].icon);
    }
    return output;
}

function find_gameplay_conversations() {
    var o = array_create(GpTriggeredConversation.LEN, undefined);

    for (var i = 0; i < GpTriggeredConversation.LEN; i++) {
        //
        o[i] = T2R.exact_gameplay_conversation(gp_triggered_conversation_to_string(i));

        if o[i] == undefined {
            crash("Failed to find the gp convo: {GpTriggeredConversation}", i);
        }
    }

    return o;
}

function window_backing_times() {
    var window_backing_map = fiddle_get("misc/window_backing");
    var keys = struct_get_names(window_backing_map);
    var output = array_create(array_length(keys), undefined);

    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];
        var name_as_time = parse_time(key);
        assert_neq(name_as_time, undefined, "{String} could not be parsed into a tag!", key);

        output[i] = [real(name_as_time), window_backing_map[$ key]];
    }

    array_sort(output, function(elem0, elem1) {
        return elem0[0] - elem1[0];
    });

    return output;
}

function dingy_ids() {
    var out = [];
    for (var i = 0; i < ItemId.LEN; i++) {
        var proto = ITEM_PROTOTYPES[i];
        if proto.tags.contains("dingy_set") {
            array_push(out, i);
        }
    }
    return out;
}

function parse_oversized_shadows() {
    return array_map(fiddle_get("shadows/oversized"), string_to_asset);
}

function parse_transparent_assets(input) {
    var output = Map();
    var keys = struct_get_names(input);
    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];
        output.insert(key, parse_transparency_boxes(input[$ key]));
    }

    return output;
}

function load_roommate_times() {
    var times = fiddle_get("spouse/times");
    apply_func(times, function(v) {
        return hours(v.hour) + minutes(v.minute);
    });
    return times;
}

//
enum GpTriggeredConversation {
    JuniperBathhouseOffer,
    JuniperBathhouseCannotAfford,
    JuniperBathhouseFarewell,
    DozyBathhouseOffer,
    DozyBathhouseCannotAfford,
    DozyBathhouseFarewell,
    JuniperBathhouseFreeOne,
    JuniperBathhouseFreeTwo,
    JuniperBathhouseFreeThree,
    JuniperBathhouseFreeFour,
    JuniperBathhouseFreeFive,
    DozyBathhouseFreeOne,
    DozyBathhouseFreeTwo,
    DozyBathhouseFreeThree,
    DozyBathhouseFreeFour,
    DozyBathhouseFreeFive,
    InnSoup,
    PerpetualSoup,
    PerpetualSoupNoItem,
    MinesFloorTen,
    UnfinishedContent,
    InspectCaldarusStatue,
    InspectSeridiaStatue,
    InspectWaterTablet,
    InspectClaw,
    InspectLanternMothClaw,
    InspectRubyClaw,
    InspectUpperMinesMushroomClaw,
    InspectStoneLoachClaw,
    InspectWaterSeal,
    InspectCoralMantisClaw,
    InspectSapphireClaw,
    InspectCaveKelpClaw,
    InspectArcherfishClaw,
    InspectEarthTablet,
    InspectCrystalClaw,
    InspectShardfinClaw,
    InspectCrystalBerryClaw,
    InspectDeepEarthwormClaw,
    InspectFireTablet,
    InspectEarthSeal,
    InspectFireSeal,
    InspectFacetedRockGemClaw,
    InspectRockrootClaw,
    InspectEmeraldClaw,
    InspectSealingScrollClaw,
    InspectRuinsSeal,
    WeatherSunny,
    WeatherRainy,
    WeatherStormy,
    WeatherCherryBlossoms,
    WeatherFallingLeaves,
    WeatherSnowy,
    WeatherBlizzard,
    AnimalTreatInitial,
    AnimalTreatSecond,
    AnimalTreatAlreadyIncubating,
    AnimalTreatAlreadyTaken,
    AnimalTreatAlreadyTakenByOther,
    AnimalTreatBaby,
    AnimalTreatNoRoom,
    AnimalTreatNoIncubatorSpace,
    AnimalTreatBelowTwoHearts,
    IncubationLong,
    IncubationShort,
    ChickenStatueNoCurrency,
    ChickenStatueHasCurrency,
    ChickenStatueEgg,
    OfferingInteraction,

    ShootingStarNotYet,
    ShootingStarDone,
    ShootingStarAdelineSuperAccept,
    ShootingStarAdelineBasicAccept,
    ShootingStarAdelineDecline,
    ShootingStarAdelineFriendDecline,
    ShootingStarBalorSuperAccept,
    ShootingStarBalorBasicAccept,
    ShootingStarBalorDecline,
    ShootingStarBalorFriendDecline,
    ShootingStarCaldarusSuperAccept,
    ShootingStarCaldarusBasicAccept,
    ShootingStarCaldarusFriendDecline,
    ShootingStarCelineSuperAccept,
    ShootingStarCelineBasicAccept,
    ShootingStarCelineDecline,
    ShootingStarCelineFriendDecline,
    ShootingStarEilandSuperAccept,
    ShootingStarEilandBasicAccept,
    ShootingStarEilandDecline,
    ShootingStarEilandFriendDecline,
    ShootingStarHaydenSuperAccept,
    ShootingStarHaydenBasicAccept,
    ShootingStarHaydenDecline,
    ShootingStarHaydenFriendDecline,
    ShootingStarJuniperSuperAccept,
    ShootingStarJuniperBasicAccept,
    ShootingStarJuniperDecline,
    ShootingStarJuniperFriendDecline,
    ShootingStarMarchSuperAccept,
    ShootingStarMarchBasicAccept,
    ShootingStarMarchDecline,
    ShootingStarMarchFriendDecline,
    ShootingStarReinaSuperAccept,
    ShootingStarReinaBasicAccept,
    ShootingStarReinaDecline,
    ShootingStarReinaFriendDecline,
    ShootingStarRyisSuperAccept,
    ShootingStarRyisBasicAccept,
    ShootingStarRyisDecline,
    ShootingStarRyisFriendDecline,
    ShootingStarSeridiaBasicAccept,
    ShootingStarSeridiaSuperAccept,
    ShootingStarSeridiaFriendDecline,
    ShootingStarValenSuperAccept,
    ShootingStarValenBasicAccept,
    ShootingStarValenDecline,
    ShootingStarValenFriendDecline,

    HarvestAdelineBasicAccept,
    HarvestBalorBasicAccept,
    HarvestCaldarusBasicAccept,
    HarvestCaldarusBasicAcceptEog,
    HarvestCelineBasicAccept,
    HarvestEilandBasicAccept,
    HarvestHaydenBasicAccept,
    HarvestJuniperBasicAccept,
    HarvestMarchBasicAccept,
    HarvestMarchSuperAccept,
    HarvestReinaBasicAccept,
    HarvestRyisBasicAccept,
    HarvestSeridiaBasicAccept,
    HarvestValenBasicAccept,


    WishingWellInteraction,

    NothingFestivalPost,
    SaturdayMarketFestivalPost,
    SpringFestivalPost,
    ShootingStarPost,
    HarvestFestivalPost,
    AnimalFestivalPost,
    EasternRoadFountain,

    HorseStatueInspect,

    EssenceChargeRemainingPlural,
    EssenceChargeRemainingSingular,

    NoGossip,
    GossipCooldown,
    GossipOne,
    GossipTwo,
    GossipThree,
    GossipFour,
    GossipFive,
    GossipSix,
    GossipSeven,
    GossipEight,

    CaldarusTeleport,
    CaldarusTeleportFail,
    CaldarusTeleportFarm,

    PetJobWood,
    PetJobStone,
    PetJobForageables,

    CannotPassVines,
    VinesCanBeBurned,

    CannotOpenSecret,
    CanOpenSecret,

    CaldarusAwaitingAri,
    CaldarusAsleep,
    HarvestPie,
    PumpkinPatch,
    PumpkinPatchNoMoney,
    HarvestFestivalRejection,
    HarvestFestivalFriendRejection,

    PqScroll,
    PqDragonForgeNotReady,
    PqDragonForgeReady,
    PqNeShelf,
    PqNwShelf,
    PqSeShelf,
    PqSwShelf,
    PqTablet,

    CannotPlantKey,

    InspectVoidStoneClaw,
    InspectVoidPowderClaw,
    InspectVoidHerbClaw,
    InspectVoidPearlClaw,
    InspectBreathOfFireClaw,
    InspectSmokeMothClaw,
    InspectFiresailFishClaw,
    InspectObsidianClaw,
    InspectDragonForgedFangClaw,
    InspectDragonForgedHornClaw,
    InspectDragonForgedCoreClaw,
    InspectDragonForgedPowderClaw,

    InspectDragonswornTablet,

    FactoryDaysRemainingSingular,
    FactoryDaysRemainingPlural,
    FactoryItemInspect,

    InspectLostAndFound,
    InspectFishTrap,
    InspectBaitedFishTrap,
    InspectArtifactReplicator,
    InspectSeedMaker,

    EmptyBathhouse,
    EmptyBathhouseFarewell,

    AdelinesLifetimePlannerText,
    BalorsPolishedGemText,
    CaldarusDragonswornStatueText,
    CelinesRevivedFlowerText,
    EilandsLegacySteleText,
    HaydensCarvedNestText,
    JunipersProtectionScrollText,
    MarchsMistrianShieldText,
    ReinasCookbookManuscriptText,
    RyisHawthornTreeText,
    SeridiasDragonswornArmorText,
    ValensPanaceaJarText,

    TakeBaby,

    CaldarusProposalEdgeCase,

    ReplicaStatue,

    LEN,
}
