global.__animals = undefined;
#macro ANIMAL_PROTOTYPES global.__animals

//
function load_animals() {
    //
    var output = array_create(AnimalKind.LEN, undefined);
    var default_animal = fiddle_get("ranching/animals/default");
    apply_func(default_animal, function(field) {
        return Map(field);
    });
    var default_animation = Map(default_animal.animations.take("default"));
    var default_variant = Map(default_animal.variants.take("default"));
    var default_cosmetic = Map(default_animal.cosmetics.take("default"));

    //
    for (var i = 0; i < AnimalKind.LEN; i++) {
        var animal_key = animal_kind_to_string(i);
        var animal = fiddle_get(format("ranching/animals/{}", animal_key));

        //
        //
        //
        animal.core = default_animal.core.apply_on(animal.core);
        filter_toml_nulls(animal.core);
        animal.core.size = string_to_animal_size(animal.core.size);
        animal.core.cosmetic_sub_icon = string_to_asset(animal.core.cosmetic_sub_icon);
        animal.core.requirements = parse_requirements(animal.core.requirements);

        //
        animal.celebration_data = default_animal.celebration_data.apply_on(animal[$ "celebration_data"] ?? {});

        //
        default_animal.production.apply_on(animal.production.female);
        animal.production.female.normal_product = string_to_item_id(animal.production.female.normal_product);
        animal.production.female.golden_product = string_to_item_id(animal.production.female.golden_product);
        default_animal.production.apply_on(animal.production.male);
        animal.production.male.normal_product = string_to_item_id(animal.production.male.normal_product);
        animal.production.male.golden_product = string_to_item_id(animal.production.male.golden_product);

        //
        default_animal.animations.apply_on(animal.animations);
        animal.animations = Map(animal.animations);
        var animation_keys = animal.animations.keys();
        for (var j = 0; j < array_length(animation_keys); j++) {
            var animation_key = animation_keys[j];
            var animation = default_animation.apply_on(animal.animations.get(animation_key));
            filter_toml_nulls(animation);
            animation.valid_for = is_array(animation.valid_for)
                ? animation.valid_for
                : [animation.valid_for];
            animation.time_range = array_to_vec2(
                apply_func(animation.time_range, hours),
            );
            if animation.duration != undefined {
                animation.duration = array_to_vec2(
                    is_array(animation.duration)
                    ? animation.duration
                    : [animation.duration]
                );
            }
        }

        //
        //
        //
        //
        animal.variants = Map(animal.variants);
        var our_default_variant = Map(default_variant.apply_on(animal.variants.take("default")));

        //
        var variant_keys = animal.variants.keys();
        for (var j = 0; j < array_length(variant_keys); j++) {
            var variant_key = variant_keys[j];
            var variant = animal.variants.get(variant_key);
            our_default_variant.apply_on(variant);
            variant.key = variant_key;
            variant.born_in = deserialize_array_bool(wrap_in_array(variant.born_in), string_to_season, Season.LEN);

            //
            var default_lut = struct_take(variant, "lut");
            var default_lut_index = struct_take(variant, "lut_index");

            static TYPE_KEYS = ["male", "female", "baby"];
            for (var k = 0; k < array_length(TYPE_KEYS); k++) {
                var type_key = TYPE_KEYS[k];
                var entry = variant[$ type_key];
                apply_defaults(entry, our_default_variant.get(type_key));
                filter_toml_nulls(entry);
                var key = struct_take(entry, "key");
                var top_key = entry[$ "top_key"];
                if is_nullish(entry[$ "lut"]) {
                    entry.lut = default_lut;
                }
                if is_nullish(entry[$ "lut_index"]) {
                    entry.lut_index = default_lut_index;
                }
                if entry.lut != "<n/a>" {
                    entry.lut = string_to_asset(entry.lut);
                } else {
                    entry.lut = undefined;
                }

                var ui_icon = entry[$ "ui_key"] ?? key;
                entry.ui_icon = string_to_asset(format(
                    "spr_ui_icon_animal_{}_{}",
                    animal_key,
                    ui_icon,
                ));

                //
                entry.sprites = parse_animal_sprites(animal_key, key, top_key, animation_keys, animal.animations, type_key);
            }
        }

        //
        //
        //
        animal.cosmetics = Map(animal[$ "cosmetics"] ?? {});
        var our_default_cosmetic = Map(default_cosmetic.apply_on(animal.cosmetics.try_take("default", {})));
        var cosmetic_keys = animal.cosmetics.keys();
        for (var j = 0; j < array_length(cosmetic_keys); j++) {
            var cosmetic_key = cosmetic_keys[j];
            var cosmetic = animal.cosmetics.get(cosmetic_key);
            our_default_cosmetic.apply_on(cosmetic);
            cosmetic.key = cosmetic_key;

            cosmetic.ui_icon = string_to_asset(format(
                "spr_ui_item_{}_cosmetic_{}",
                animal_key,
                cosmetic_key,
            ));

            static SEXES = ["male", "female"];
            for (var k = 0; k < array_length(SEXES); k++) {
                var type_key = SEXES[k];
                var entry = cosmetic[$ type_key];
                apply_defaults(entry, our_default_cosmetic.get(type_key));
                filter_toml_nulls(entry);

                var base_key = format("cosmetic_{}", cosmetic_key);
                var key = entry[$ "key"];
                if key != undefined {
                    base_key = format("{}_{}", base_key, key);
                }

                var top_key = entry[$ "top_key"];
                if top_key != undefined {
                    top_key = format("cosmetic_{}_{}", cosmetic_key, top_key);
                }

                //
                var sprites = parse_animal_sprites(animal_key, base_key, top_key, animation_keys, animal.animations, type_key);
                assert_neq(sprites, undefined, "Cosmetic '{}' for '{AnimalKind}' failed to load anything!", cosmetic_key, i);
                entry.sprites = sprites;
            }
        }

        //
        animal.behavior = default_animal.behavior.apply_on(animal[$ "behavior"] ?? {});
        animal.breeding = default_animal.breeding.apply_on(animal[$ "breeding"] ?? {});
        animal.eating = default_animal.eating.apply_on(animal[$ "eating"] ?? {});
        animal.mounting = default_animal.mounting.apply_on(animal[$ "mounting"] ?? {});
        animal.petting = default_animal.petting.apply_on(animal[$ "petting"] ?? {});
        animal.pricing = default_animal.pricing.apply_on(animal[$ "pricing"] ?? {});
        animal.sounds = default_animal.sounds.apply_on(animal[$ "sounds"] ?? {});

        //
        animal.breeding.treat = string_to_item_id(animal.breeding.treat);
        animal.breeding.sparkle_offset = fiddle_deserialize_vec2(animal.breeding.sparkle_offset);
        animal.eating.kind = string_to_feed_kind(animal.eating.kind);
        animal.eating.offset = fiddle_deserialize_vec2(animal.eating.offset);
        animal.eating.baby_offset = fiddle_deserialize_vec2(animal.eating.baby_offset);
        animal.eating.shake_frames = fiddle_deserialize_vec2(animal.eating.shake_frames);

        animal.petting.kind = string_to_petting_kind(animal.petting.kind);
        animal.petting.held_offset = array_to_vec2(animal.petting.held_offset);

        //
        animal.bark_offsets.adult = array_map(
            cardinal_struct_to_array(animal.bark_offsets.adult),
            array_to_vec2,
        );
        animal.bark_offsets.baby = array_map(
            cardinal_struct_to_array(animal.bark_offsets.baby),
            array_to_vec2,
        );

        //
        animal = filter_toml_nulls(animal);


        //
        var sound_events = struct_get_names(animal.sounds);
        for (var j = 0; j < array_length(sound_events); j++) {
            var sound_variants = animal.sounds[$ sound_events[j]];

            for (var k = 0; k < array_length(sound_variants); k++) {
                var sound_variant = sound_variants[k];

                var sound_keys = struct_get_names(sound_variant);
                for (var l = 0; l < array_length(sound_keys); l++) {
                    var sound_key = sound_keys[l];
                    var tango_str_name = sound_variant[$ sound_key];

                    //
                    if sound_key == "ambient" && tango_str_name == undefined {
                        continue;
                    }

                    audio_asset_assert_exists(tango_str_name);
                }
            }
        }

        //
        output[i] = animal;
    }

    return output;
}

//
//
//
function parse_animal_sprites(animal_key, key, top_key, animation_keys, animal_animations, type_key) {
    static GET_SPRITES = function(animal_key, layer_key, animation_key, map) {
        //
        //
        //
        var base = format("spr_animal_{}_{}_{}", animal_key, layer_key, animation_key);

        //
        //
        //
        //
        //
        var north = try_string_to_asset(format("{}_north", base));
        var south = try_string_to_asset(format("{}_south", base));
        var east = try_string_to_asset(format("{}_east", base));

        //
        var any_sprite = (east ?? south) ?? north;
        assert(
            any_sprite != undefined || layer_key != "base",
            undefined,
            "No sprites could be found under {}!",
            base,
        );

        //
        map.set(animation_key, [
            east,
            north,
            east,
            south,
        ]);

        return any_sprite != undefined;
    }

    var any_sprite_found = false;
    var sprites = {
        base: Map(),
        top: Map(),
    };

    for (var h = 0; h < array_length(animation_keys); h++) {
        var animation_key = animation_keys[h];
        var animation = animal_animations.get(animation_key);
        if type_key == undefined || array_has(animation.valid_for, type_key) {
            any_sprite_found |= GET_SPRITES(animal_key, key, animation_key, sprites.base);
            if top_key != undefined {
                any_sprite_found |= GET_SPRITES(animal_key, top_key, animation_key, sprites.top);
            }
        }
    }

    if any_sprite_found {
        return sprites;
    } else {
        return undefined;
    }
}
