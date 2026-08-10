#macro PET_PROTOTYPE global.__pet_prototype
PET_PROTOTYPE = undefined;

function load_pet_prototype() {
    var pets = fiddle_get("pets");

    var ui_order = fiddle_get("ui/misc/pet_variant_order");

    var animations = Map();
    var animation_keys = struct_get_names(pets.animations);
    for (var i = 0; i < array_length(animation_keys); i++) {
        var animation_name = animation_keys[i];
        if animation_name == "default" {
            continue;
        }

        var animation_data = pets.animations[$ animation_name];
        animation_data.duration = animation_data.duration == "<n/a>" ? undefined : fiddle_deserialize_vec2(animation_data.duration);
        animation_data.time_range = animation_data.time_range == "<n/a>" ? undefined :  array_to_vec2(apply_func(animation_data.time_range, hours));
        animation_data.valid_for = undefined;

        if animation_data[$ "white_list"] == undefined {
            animation_data.white_list = array_create_ext(PetKind.LEN, identity);
        } else {
            animation_data.white_list = array_map(animation_data.white_list, string_to_pet_kind);
        }

        animations.insert(animation_name, animation_data);
    }

    //
    var variants = Map();
    var variant_keys = struct_get_names(pets.variants);
    for (var i = 0; i < array_length(variant_keys); i++) {
        var variant_name = variant_keys[i];

        assert(array_has(ui_order, variant_name), "{} needs to be added to ui/misc/pet_variant_order!", variant_name);

        var variant = pets.variants[$ variant_name];
        var pet_kind = string_to_pet_kind(variant.pet_kind);

        var variant_data = {
            sprites: parse_pet_sprites(
                variant.sprite_template,
                animations,
                pet_kind,
                false,
            ),
            pet_kind,
            ui_icon: string_to_asset(variant.ui_icon),
            map_icon: string_to_asset(variant.map_icon),
            name: variant.name,
            unlock_key: variant[$ "unlock_key"],
            preview_direction: string_to_cardinal(variant.preview_direction),
        };
        assert_neq(variant_data.sprites, undefined, "Pet variant `{}` does not have any sprites!", variant_name);
        if variant.lut == "<n/a>" {
            variant_data.lut = undefined;
        } else {
            variant_data.lut = string_to_asset(variant.lut);
            variant_data.lut_index = variant.lut_index;
        }

        variants.insert(variant_name, variant_data);
    }

    //
    var cosmetic_sets = Map();
    var cosmetic_set_keys = struct_get_names(pets.cosmetic_sets);
    for (var i = 0; i < array_length(cosmetic_set_keys); i++) {
        var cosmetic_set_key = cosmetic_set_keys[i];
        var cosmetic_set = pets.cosmetic_sets[$ cosmetic_set_key];

        cosmetic_sets.insert(cosmetic_set_key, {
            ui_icon: string_to_asset(cosmetic_set.ui_icon),
            name: cosmetic_set.name,
            cosmetics_to_unlock: [],
        });
    }

    var cosmetics = Map();
    var cosmetic_keys = struct_get_names(pets.cosmetics);
    for (var i = 0; i < array_length(cosmetic_keys); i++) {
        var cosmetic_key = cosmetic_keys[i];
        var cosmetic = pets.cosmetics[$ cosmetic_key];
        var pet_kind = string_to_pet_kind(cosmetic.pet_kind);

        var cosmetic_data = {
            sprites: parse_pet_sprites(
                cosmetic.sprite_template,
                animations,
                pet_kind,
                true,
            ),
            pet_kind,
            cosmetic_set: cosmetic.cosmetic_set,
        };

        //
        var set = cosmetic_sets.get_unwrap(cosmetic.cosmetic_set);
        array_push(set.cosmetics_to_unlock, cosmetic_key);

        cosmetics.insert(cosmetic_key, cosmetic_data);
    }

    //
    var job_setup_data = array_create(PetJob.LEN, undefined);
    for (var i = 0; i < PetJob.LEN; i++) {
        if i == PetJob.None {
            continue;
        }

        var f_job_data = pets.jobs[$ pet_job_to_string(i)];
        job_setup_data[i] = {
            location_id: string_to_location_id(f_job_data.location_id),
            pet_position: fiddle_deserialize_vec2(f_job_data.pet_position),
            props: array_map(f_job_data.props, function(f_prop_data) {
                return {
                    sprite: string_to_asset(f_prop_data.sprite),
                    position: fiddle_deserialize_vec2(f_prop_data.position),
                }
            }),
            reward: f_job_data.reward == "custom" ? undefined : string_to_item_id(f_job_data.reward),
            reward_table: f_job_data.reward_table,
            conversation_name: string_to_gp_triggered_conversation(f_job_data.conversation_name),
            icon: string_to_asset(f_job_data.icon),
        }
    }

    //
    if DEBUG_ASSERTIONS {
        var keys = cosmetic_sets.keys();
        for (var i = 0; i < array_length(keys); i++) {
            assert(array_length(cosmetic_sets.get(keys[i]).cosmetics_to_unlock) > 0, "set {} has no cosmetics associated with it!", keys[i]);
        }
    }

    //
    //
    assert_eq(array_length(ui_order), array_length(variants.keys()));

    return {
        pet_cosmetic_sub_icon: string_to_asset(pets.pet_cosmetic_sub_icon),
        variants,
        cosmetics,
        cosmetic_sets,
        animations,
        celebration_animation: pets.celebration_animation,
        bark_offsets: array_map(cardinal_struct_to_array(pets.bark_offsets), array_to_vec2),
        job_setup_data,
    };
}

//
//
function parse_pet_sprites(variant_template, animal_animations, check_key, can_be_empty) {
    var map = Map();

    var animation_keys = animal_animations.keys();
    for (var h = 0; h < array_length(animation_keys); h++) {
        var animation_key = animation_keys[h];
        var animation = animal_animations.get(animation_key);

        //
        if array_contains(animation.white_list, check_key) == false {
            continue;
        }

        //
        var base = string_replace(variant_template, "{ANIMATION_KEY}", animation_key);

        //
        //
        //
        //
        //
        var north = try_string_to_asset(format("{}_north", base));
        var south = try_string_to_asset(format("{}_south", base));
        var east = try_string_to_asset(format("{}_east", base));

        //
        if DEBUG_ASSERTIONS && can_be_empty == false {
            assert_neq(
                (east ?? south) ?? north,
                undefined,
                "No sprites could be found under {}!",
                base,
            );
        }


        //
        map.set(animation_key, [
            east,
            north,
            east,
            south,
        ]);
    }

    return map;
}
