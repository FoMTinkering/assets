#macro NODE_PROTOTYPES global.__node_prototypes
NODE_PROTOTYPES = undefined;

//
enum ObjectCategory {
    Breakable,
    Building,
    Bush,
    Crop,
    DigSite,
    Furniture,
    Grass,
    Rock,
    Stump,
    Tree,

    LEN
}

function create_node_prototypes() {
    static GET_NODE_PROTOTYPE_CTOR = function(category_id) {
        switch category_id {
            case ObjectCategory.DigSite:
                return create_dig_site_prototype;
            case ObjectCategory.Tree:
                return create_tree_prototype;
            case ObjectCategory.Rock:
                return create_rock_prototype;
            case ObjectCategory.Breakable:
                return create_breakable_prototype;
            case ObjectCategory.Stump:
                return create_stump_prototype;
            case ObjectCategory.Crop:
                return create_crop_prototype;
            case ObjectCategory.Grass:
                return create_grass_prototype;
            case ObjectCategory.Building:
                return create_building_prototype;
            case ObjectCategory.Furniture:
                return create_furniture_prototype;
            case ObjectCategory.Bush:
                return create_bush_prototype;
            default: impossible("unexpected ObjectCategory {}", category_id);
        }
    }

    static APPLY_FIELDS_ONTO_STRUCT = function(patch_obj, original_obj) {
        var keys = struct_get_names(patch_obj);
        for (var i = 0, c = array_length(keys); i < c; i++) {
            var patch_value_name = keys[i];

            var patch_value = patch_obj[$ patch_value_name];

            if patch_value != undefined {
                original_obj[$ patch_value_name] = patch_value;
            }
        }
        return original_obj;
    }

    static HAS_NO_DEFAULT = function(category_id) {
        return matches(category_id, ObjectCategory.Building, ObjectCategory.DigSite);
    }

    var prototypes = array_create(ObjectId.LEN, undefined);

    for (var category_id = 0; category_id < ObjectCategory.LEN; category_id++) {
        var category_name = object_category_to_string(category_id);
        var category = fiddle_get(format("object_prototypes/{}", category_name));
        var category_keys = struct_get_names(category);
        var ctor = GET_NODE_PROTOTYPE_CTOR(category_id);

        //
        var default_object = category[$ "default"];

        //
        assert(default_object != undefined || HAS_NO_DEFAULT(category_id), "you must have a `[default]` key defined for category {ObjectCategory}", category_id);

        //
        for (var j = 0, c_j = array_length(category_keys); j < c_j; j++) {
            var object_name = category_keys[j];
            if object_name == "default" {
                continue;
            }
            var object_id = string_to_object_id(object_name);
            var patch_obj = category[$ object_name];

            var object;
            if HAS_NO_DEFAULT(category_id) == false {
                object = clone_value(default_object);
                patch_object(patch_obj, object);
            } else {
                object = patch_obj;
            }

            prototypes[object_id] = ctor(object_id, object);
            prototypes[object_id].category_id = category_id;
        }
    }

    //
    //
    for (var i = 0; i < array_length(prototypes); i++) {
        var proto = prototypes[i];
        assert_neq(prototypes[i], undefined, "{ObjectId} was not defined!", i);
        //
        if proto.category_id != ObjectCategory.Furniture {
            continue;
        }
        if proto.house_stairs != undefined {
            assert_eq(
                i,
                prototypes[proto.house_stairs.paired_object].house_stairs.paired_object,
                "{ObjectId} was paired with {ObjectId}, but {ObjectId} was paired with {ObjectId}",
                i,
                proto.house_stairs.paired_object,
                proto.house_stairs.paired_object,
                prototypes[proto.house_stairs.paired_object].house_stairs.paired_object,
            );
        }
    }

    return prototypes;
}

//
function object_id_to_object_category(obj_id) {
    //
    if obj_id == undefined {
        return undefined;
    }

    return NODE_PROTOTYPES[obj_id].category_id;
}


function fiddle_deserialize_vec2(vec2_obj) {
    if vec2_obj == undefined {
        return undefined;
    }

    return array_to_vec2(vec2_obj);
}

function fiddle_deserialize_season(season_object, func) {
    if season_object == undefined {
        return undefined;
    }

    var spring_sprite = func(season_object.spring);
    var variants = [
        spring_sprite,
        spring_sprite,
        spring_sprite,
        spring_sprite,
    ];

    if season_object[$ "summer"] != undefined {
        variants[Season.Summer] = func(season_object.summer);
    }

    if season_object[$ "fall"] != undefined {
        variants[Season.Fall] = func(season_object.fall);
    }

    if season_object[$ "winter"] != undefined {
        variants[Season.Winter] = func(season_object.winter);
    }

    return variants
}

function fiddle_deserialize_biome(season_object, func) {
    if season_object == undefined {
        return undefined;
    }
    var spring_sprite = func(season_object.biome_1);
    var variants = [
        spring_sprite,
        spring_sprite,
        spring_sprite,
        spring_sprite,
        spring_sprite,
    ];

    if season_object[$ "biome_2"] != undefined {
        variants[1] = func(season_object.biome_2);
    }

    if season_object[$ "biome_3"] != undefined {
        variants[2] = func(season_object.biome_3);
    }

    if season_object[$ "biome_4"] != undefined {
        variants[3] = func(season_object.biome_4);
    }

    if season_object[$ "biome_5"] != undefined {
        variants[4] = func(season_object.biome_5);
    }

    return variants
}

function parse_transparency_boxes(input) {
    return array_map(input, function(v) {
        return {
            offset: fiddle_deserialize_vec2(v.offset),
            size: fiddle_deserialize_vec2(v.size),
        }
    });
}
