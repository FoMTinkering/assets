#macro POST_PROCESS_DATABASE global.__post_process_database
global.__post_process_database = undefined;

function setup_post_process_database() {
    var o = {};

    var f = fiddle_get_directory("post_process");
    var names = struct_get_names(f);
    for (var i = 0, c = array_length(names); i < c; i++) {
        var name = names[i];

        o[$ name] = parse_post_process_obj(f[$ name]);
    }

    return o;
}

function parse_post_process_obj(fiddle_obj) {
    var output = {
        init: undefined,
        frames: List(),
        min_multiply_level: undefined,
        multiply_by_light_count: undefined,
    };

    var keys = struct_get_names(fiddle_obj);
    for (var i = 0, c = array_length(keys); i < c; i++) {
        var key_name = keys[i];
        var fiddle_sub_obj = fiddle_obj[$ key_name];

        var frame = {
            shading: undefined,
            light: undefined,
            shadow: undefined,
        };

        if key_name == "init" {
            assert_eq(output.init, undefined, "cannot set `init` twice!");

            frame.shading = {
                vivid: {
                    kind: CurveType.Constant,
                    value: array_map(fiddle_sub_obj.shading.vivid, function(v) { return v / 255 }),
                    stop_time: undefined,
                    start_time: hours(6),
                },
                multiply: {
                    kind: CurveType.Constant,
                    value: array_map(fiddle_sub_obj.shading.multiply, function(v) { return v / 255 }),
                    stop_time: undefined,
                    start_time: hours(6),
                },
                levels: {
                    kind: CurveType.Constant,
                    value: [
                        fiddle_sub_obj.shading.levels.black / 255,
                        fiddle_sub_obj.shading.levels.grey / 255,
                        fiddle_sub_obj.shading.levels.white / 255
                    ],
                    stop_time: undefined,
                    start_time: hours(6),
                },
            };

            frame.light = {
                kind: CurveType.Constant,
                value: array_clone(fiddle_sub_obj.light),
                stop_time: undefined,
                start_time: hours(6),
            };
            assert_eq(array_length(frame.light.value), 4, "light must have 4 entries, it had {}", array_length(frame.light.value));

            frame.shadow = {
                kind: CurveType.Constant,
                value: array_map(fiddle_sub_obj.shadow, function(v) { return v / 255 }),
                stop_time: undefined,
                start_time: hours(6),
            };

            output.init = frame;
        } else if key_name == "min_multiply_level" {
            output.min_multiply_level = real(fiddle_sub_obj) / 255;
            continue;
        } else if key_name == "multiply_by_light_count" {
            output.multiply_by_light_count = real(fiddle_sub_obj);
            continue;
        } else {
            var name_as_time = parse_time(key_name);
            assert_neq(name_as_time, undefined, "{String} could not be parsed into a tag!", key_name);

            frame.time = name_as_time;

            var shading_fiddle = fiddle_sub_obj[$ "shading"];
            if shading_fiddle != undefined {
                //
                var shading = {
                    vivid: parse_post_process_key_frame_entry(shading_fiddle.vivid, name_as_time),
                    multiply: parse_post_process_key_frame_entry(shading_fiddle.multiply, name_as_time),
                    levels: parse_post_process_key_frame_entry(shading_fiddle.levels, name_as_time),
                };

                apply_func(shading.vivid.value, function(v) { return v / 255 });
                apply_func(shading.multiply.value, function(v) { return v / 255 });
                shading.levels.value = [shading.levels.value.black / 255, shading.levels.value.grey / 255, shading.levels.value.white / 255];

                frame.shading = shading;
            }

            var light_fiddle = fiddle_sub_obj[$ "light"];
            if light_fiddle != undefined {
                frame.light = parse_post_process_key_frame_entry(light_fiddle, name_as_time);
                assert_eq(array_length(frame.light.value), 4, "light must have 4 entries");
            }

            var shadow_fiddle = fiddle_sub_obj[$ "shadow"];
            if shadow_fiddle != undefined {
                frame.shadow = parse_post_process_key_frame_entry(shadow_fiddle, name_as_time);
                apply_func(frame.shadow.value, function(v) { return v / 255 });
            }

            output.frames.push(frame);
        }
    }

    assert_neq(output.min_multiply_level, undefined, "no min_multiply_level found!");
    assert_neq(output.multiply_by_light_count, undefined, "no multiply_by_light_count found!");

    //
    output.frames.sort_with(function(lhs, rhs) {
        return lhs.time - rhs.time;
    });

    //
    for (var i = 0, c = output.frames.count(); i < c; i++) {
        var frame = output.frames.get(i);

        var target_time = hours(26);

        if frame.shading != undefined {
            for (var k = i + 1; k < c; k++) {
                var other_frame = output.frames.get(k);
                if other_frame.shading != undefined {
                    target_time = other_frame.time;
                    break;
                }
            }

            frame.shading.multiply.stop_time = target_time;
            frame.shading.vivid.stop_time = target_time;
            frame.shading.levels.stop_time = target_time;
        }

        if frame.shadow != undefined && frame.shadow.stop_time == undefined {
            target_time = hours(26);
            for (var k = i + 1; k < c; k++) {
                var other_frame = output.frames.get(k);
                if other_frame.shadow != undefined {
                    target_time = other_frame.time;
                    break;
                }
            }
            frame.shadow.stop_time = target_time;
        }

        if frame.light != undefined && frame.light.stop_time == undefined {
            target_time = hours(26);
            for (var k = i + 1; k < c; k++) {
                var other_frame = output.frames.get(k);
                if other_frame.light != undefined {
                    target_time = other_frame.time;
                    break;
                }
            }
            frame.light.stop_time = target_time;
        }
    }

    //
    var init_end_time = hours(26);
    var first = output.frames.first();
    if first != undefined {
        init_end_time = first.time;
    }

    output.init.shading.vivid.stop_time = init_end_time;
    output.init.shading.multiply.stop_time = init_end_time;
    output.init.shading.levels.stop_time = init_end_time;
    output.init.light.stop_time = init_end_time;
    output.init.shadow.stop_time = init_end_time;

    return output;
}

function parse_post_process_key_frame_entry(fiddle_obj, start_time) {
    var kind = string_to_curve_type(fiddle_obj.kind);
    var value = clone_value(fiddle_obj.value);

    var stop_time = undefined;

    if kind == CurveType.Linear {
        var override_stop_time = fiddle_obj[$ "stop_time"];
        if override_stop_time != undefined {
            override_stop_time = parse_time(override_stop_time);
            assert_neq(override_stop_time, undefined, "override stop time {} was not correct", fiddle_obj[$ "stop_time"]);
        }
        stop_time = override_stop_time;
    }

    return {
        kind: kind,
        value: value,
        stop_time: stop_time,
        start_time: start_time,
    };
}

//
//
//
//
//
//
//
//
function parse_time(input) {
    var date_array = string_split(input, ":");
    if array_length(date_array) != 2 {
        return undefined;
    }

    var hour = date_array[0];
    var minute = date_array[1];

    var pm = string_pos("pm", minute);
    var hour_mod = 0;

    if pm == 3 {
        minute = string_copy(minute, 1, 2);
        hour_mod = hours(12);

        //
        if hour == "12" {
            hour = "0";
        }
    } else if pm != 0 {
        //
        return undefined;
    }

    var am = string_pos("am", minute);
    if am != 0 && am != 3 {
        return undefined;
    }
    if am == 3 {
        minute = string_copy(minute, 1, 2);
    }

    return hours(real(hour)) + hour_mod + minutes(minute);
}
