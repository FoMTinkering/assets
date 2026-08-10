//
//
function clone_value(value) {
    if is_array(value) {
        var new_array = array_create(array_length(value));

        var length = array_length(new_array);

        for (var i = 0; i < length; i++) {
            new_array[i] = clone_value(value[i]);
        }

        return new_array;
    }

    if is_struct(value) {
        var new_struct = {};

        var names = struct_get_names(value);
        for (var i = 0, c = array_length(names); i < c; i++) {
            var name = names[i];

            new_struct[$ name] = clone_value(value[$ name]);
        }

        return new_struct;
    }

    //
    return value;
}

//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
function patch_object(patch_obj, target_obj) {
    var keys = struct_get_names(patch_obj);
    for (var i = 0, c = array_length(keys); i < c; i++) {
        var patch_value_name = keys[i];

        var patch_value = patch_obj[$ patch_value_name];

        if patch_value != undefined {
            target_obj[$ patch_value_name] = patch_value;
        }
    }

    return target_obj;
}

//
function ensure_array(v) {
    if is_array(v) {
        return v;
    } else {
        return [v];
    }
}

//
function apply_defaults(obj, defaults) {
    var keys = struct_get_names(defaults);
    for (var i = 0, c = array_length(keys); i < c; i++) {
        var key = keys[i];
        if is_nullish(obj[$ key]) {
            obj[$ key] = defaults[$ key];
        }
    }
    return obj;
}

//
//
//
//
//
function apply_func(value, func) {
    if is_array(value) {
        for (var i = 0, c = array_length(value); i < c; i++) {
            value[i] = func(value[i]);
        }

        return value;
    }

    if is_struct(value) {
        var names = struct_get_names(value);
        for (var i = 0, c = array_length(names); i < c; i++) {
            var name = names[i];

            value[$ name] = func(value[$ name]);
        }

        return value;
    }

    //
    return func(value);
}

//
function filter_toml_nulls(value) {
    if value == "<n/a>" {
        return undefined;
    } else if is_array(value) {
        for (var i = 0; i < array_length(value); i++) {
            value[i] = filter_toml_nulls(value[i]);
        }
    } else if is_struct(value) {
        var names = struct_get_names(value);
        for (var i = 0, c = array_length(names); i < c; i++) {
            var name = names[i];
            value[$ name] = filter_toml_nulls(value[$ name]);
        }
    }

    return value;
}

//
//
function foreach_field(struct, func) {
    var names = struct_get_names(struct);
    for (var i = 0, c = array_length(names); i < c; i++) {
        var value = struct[$ names[i]];
        var new_value = func(value, names[i]);
        struct[$ names[i]] = new_value;
    }
}

//
function struct_take(struct, name) {
    var value = struct[$ name];
    assert_neq(value, undefined, "Value for '{}' was undefined in {}", name, struct);
    struct_remove(struct, name);
    return value;
}

//
function array_to_vec2(array) {
    return Vec2(array[0], array[1]);
}

//
function try_array_to_vec2(value) {
    return is_array(value) && array_length(value) == 2
        ? array_to_vec2(value)
        : undefined;
}

//
function array_has(a, v) {
    for (var i = 0, c = array_length(a); i < c; i++) {
        if a[i] == v {
            return true;
        }
    }
    return false;
}

//
//
//
//
//
function array_index(my_array, test_value, len_to_check) {
    var output = array_get_index(my_array, test_value, 0, len_to_check ?? array_length(my_array));
    if output == -1 {
        return undefined;
    } else {
        return output;
    }
}

//
//
function try_index_array(a, i) {
    if i < 0 || i >= array_length(a) {
        return undefined;
    }

    return a[i];
}

//
function array_clone(input_array, length_to_clone = undefined) {
    var l = length_to_clone ?? array_length(input_array);
    var new_array = array_create(l, -1);
    array_copy(new_array, 0, input_array, 0, l);

    return new_array;
}


//
//
//
//
//
//
//
//
function array_map_mut(arr, f_to_u, count = undefined) {
    var l = count ?? array_length(arr);

    for (var i = 0; i < l; i++) {
        arr[i] = f_to_u(arr[i]);
    }
}

function object_has_flag(obj, flag_name) {
    return obj[$ flag_name] == true;
}

//
function array_to_string(array, delim, amount=undefined) {
    amount = amount == undefined ? array_length(array) : amount;
    var o = "";
    for (var i = 0; i < amount; i++) {
        o += array[i];
        if i != amount - 1 {
            o += delim;
        }
    }
    return o;
}

//
function array_is_superset_of(a, b) {
    for (var i = 0; i < array_length(b); i++) {
        if array_has(a, b[i]) == false {
            return false;
        }
    }
    return true;
}

//
//
//
function opt_and_then(value, func) {
    if is_nullish(value) {
        return undefined;
    }

    return func(value);
}

//
//
function wrap_in_array(value) {
    return is_array(value) ? value : [value];
}

//
//
//
//
//
function string_width_font(str, font) {
    font = is_nullish(font) ? ANCHOR.get_text_font() : font;
    draw_set_font(font);
    return string_width(str);
}

//
function instance_at_animation_end(inst) {
    if sign(inst.image_speed) == 1 {
        return inst.image_index + inst.image_speed >= sprite_get_number(inst.sprite_index);
    } else {
        return inst.image_index + inst.image_speed <= 0;
    }
}

//
//
function int_to_hex_string(integer, min_chars=1) {
    static INT_TO_HEX_CHAR = function(integer) {
        switch integer {
            case 10: return "A";
            case 11: return "B";
            case 12: return "C";
            case 13: return "D";
            case 14: return "E";
            case 15: return "F";
            default: return string(integer);
        }
    }

    var str = "";
    while true {
        var quotient = integer div 16;
        var remainder = integer mod 16;
        str = INT_TO_HEX_CHAR(remainder) + str;
        if quotient >= 16 {
            integer = quotient;
        } else {
            if quotient != 0 {
                str = INT_TO_HEX_CHAR(quotient) + str;
            }
            break;
        }
    }

    while string_length(str) < min_chars {
        str = "0" + str;
    }

    return str;
}

//
function array_to_struct(array, functor) {
    var output = {};
    for (var i = 0; i < array_length(array); i++) {
        output[$ functor(i)] = array[i]
    }

    return output;
}

//
function struct_to_array(struct, len, functor) {
    var output = array_create(len, undefined);
    var keys = struct_get_names(struct);
    for (var i = 0; i < array_length(keys); i++) {
        output[functor(keys[i])] = struct[$ keys[i]];
    }

    return output;
}

//
function apply_struct_to_array(input, struct, functor, value_modifier=undefined) {
    var keys = struct_get_names(struct);
    var new_value;
    for (var i = 0; i < array_length(keys); i++) {
        new_value = struct[$ keys[i]];
        if value_modifier != undefined {
            new_value = value_modifier(new_value);
        }
        var num = functor(keys[i]);
        if is_numeric(num) {
            input[num] = new_value;
        } else if DEBUG_ASSERTIONS {
            crash("unexpected input in functor...{} -> {}", i, num);
        }
    }
}

function instance_destroy_safe(input_id) {
    if input_id != undefined && instance_exists(input_id) {
        instance_destroy(input_id);
        return true;
    }

    return false;
}

//
function test_hex_conversion() {
    assert_eq(int_to_hex_string(0), "0");
    assert_eq(int_to_hex_string(1), "1");
    assert_eq(int_to_hex_string(1, 5), "00001");
    assert_eq(int_to_hex_string(49), "31");
    assert_eq(int_to_hex_string(444), "1BC");
    assert_eq(int_to_hex_string(920582), "E0C06");
}

//
function ranges_overlap(a1, a2, b1, b2) {
    return !(b2 <= a1 || a2 <= b1);
}

function is_nullish(foo) {
    return foo == undefined || foo == pointer_null;
}

function try_get_seasonal_sprite_alt(sprite) {
    var spr_name = string_replace(
        asset_to_string(sprite),
        "spring",
        season_to_string(CALENDAR.season())
    );
    var seasonal_spr = try_string_to_asset(spr_name);

    //
    if seasonal_spr == undefined && CALENDAR.season() == Season.Fall {
        spr_name = string_replace(
            asset_to_string(sprite),
            "spring",
            "autumn"
        );
        seasonal_spr = try_string_to_asset(spr_name);
    }

    return seasonal_spr;
}

//
//
function find_nearest_bird_landing_position(xx, yy, ignore_counter=0) {
    static HELPER_LIST = List();
    HELPER_LIST.clear();

    var winner = undefined;
    var dist;

    repeat 100 {
        var nearest = instance_nearest(xx, yy, obj_bird_landing_position);

        if nearest == undefined {
            break;
        }

        if instance_exists(obj_ari) {
            dist = point_distance(self.x, self.y, obj_ari.x, obj_ari.y);
        } else {
            dist = infinity;
        }

        if nearest.occupied != undefined || ignore_counter > 0 || dist < 32 {
            nearest.original_x = nearest.x;
            nearest.original_y = nearest.y;

            nearest.x = infinity;
            nearest.y = infinity;

            HELPER_LIST.push(nearest);
            ignore_counter -= 1;
            continue;
        }

        //
        winner = nearest;
        break;
    }

    //
    for (var i = 0; i < HELPER_LIST.count(); i++) {
        var value = HELPER_LIST.get(i);
        value.x = value.original_x;
        value.y = value.original_y;

        value.original_x = undefined;
        value.original_y = undefined;
    }

    return winner;
}

function time_since_boot_str() {
    var time_micro = get_timer();
    var true_seconds = floor((time_micro / 1000) / 1000);
    var true_minutes = true_seconds div 60;
    var true_hours = true_minutes div 60;
    var seconds_display = true_seconds % 60;
    var minutes_display = true_minutes % 60;
    minutes_display = string_length(minutes_display) == 1 ? "0" + string(minutes_display) : minutes_display;
    seconds_display = string_length(seconds_display) == 1 ? "0" + string(seconds_display) : seconds_display;
    return fmt("{}:{}:{}", true_hours, minutes_display, seconds_display);
}

//
function struct_get_unwrap(blob, key) {
    gml_pragma("forceinline");

    var output = blob[$ key];
    assert_neq(output, undefined, "Struct did not contain a value for `{}`!", key);

    return output;
}

//
function identity(v) {
    return v;
}

//
function empty_function() {}

//
function find_invalid_field(obj, array) {
    var user_keys = struct_get_names(obj);
    for (var i = 0; i < array_length(user_keys); i++) {
        if !array_contains(array, user_keys[i]) {
            return user_keys[i];
        }
    }
    return undefined;
}

function item_to_tree(item_id) {
    for (var i = 0; i < ObjectId.LEN; i++) {
        var proto = NODE_PROTOTYPES[i];
        if proto[$ "fruit_data"] != undefined && proto.fruit_data.harvest == item_id {
            return i;
        }
    }
    return undefined;
}

function item_to_crop(item_id) {
    for (var i = 0; i < ObjectId.LEN; i++) {
        if i == ObjectId.MysteryBag {
            continue;
        }
        var proto = NODE_PROTOTYPES[i];
        if proto[$ "harvest"] == item_id {
            return i;
        }
    }
    return undefined;
}

function item_to_seed(item_id) {
    var crop_object = item_to_crop(item_id);

    if crop_object == undefined {
        return undefined;
    }

    for (var i = 0; i < ItemId.LEN; i++) {
        var item = ITEM_PROTOTYPES[i];
        if item.crop_object == crop_object {
            return i;
        }
    }

    return undefined;
}

//
//
function pretty_callstack() {
    var callstack = debug_get_callstack();
    var out = List();
    for (var i = 2; i < array_length(callstack); i++) {
        var stack = callstack[i];
        var pos = string_last_pos("/", stack);
        if pos == 0 {
            out.push(stack);
            continue;
        }

        var snip = string_copy(stack, pos + 1, string_length(stack) - pos);
        out.push(snip);
    }

    return out.reverse().join(" -> ");
}

//
function bell_sound_path() {
    var tag = undefined;
    if CURRENT_LOCATION_ID == LocationId.Town {
        tag = "";
    } else if is_dungeon_room(room()) || CURRENT_LOCATION_ID == LocationId.MinesEntry {
        tag = "FromMines";
    } else {
        tag = "2D";
    }

    var base = undefined;
    if world_mod_enabled(WorldMod.BellTowerBellBroken) {
        base = "SoundEffects/SpecialEvents/Alt8pmBells/8pmBellBroken"
    } else {
        base = BELL_SOUNDS[ARI.bell_sound].sound;
    }

    return format("{}{}", base, tag);
}

//
function test_ranges_overlap() {
    //
    assert(ranges_overlap(0, 2, 1, 3));
    assert(ranges_overlap(1, 3, 0, 2));

    //
    assert(ranges_overlap(0, 2, 1, 2));
    assert(ranges_overlap(1, 2, 0, 2));

    //
    assert(ranges_overlap(1, 2, 1, 2));

    //
    assert(ranges_overlap(0, 3, 1, 2));
    assert(ranges_overlap(1, 2, 0, 3));

    //
    assert(!ranges_overlap(0, 1, 2, 3));
    assert(!ranges_overlap(2, 3, 0, 1));
}
