//
function array_bool(len) {
    return array_create(len, false);
}

//
//
//
//
function serialize_array_bool(a_bool, num_to_string) {
    var o = List();

    for (var i = 0; i < array_length(a_bool); i++) {
        if a_bool[i] {
            o.push(num_to_string(i));
        }
    }

    return o.to_array();
}

//
//
//
function deserialize_array_bool(string_array, string_to_num, len) {
    var target = array_bool(len);

    for (var i = 0; i < array_length(string_array); i++) {
        var num = string_to_num(string_array[i]);
        if is_numeric(num) {
            target[num] = true;
        } else if DEBUG_ASSERTIONS {
            crash("unexpected input in functor...{}/{} -> {}", i, string_array[i], num);
        }
    }

    return target;
}

//
//
//
//
//
//
function array_to_bool_map(key_array, len) {
    var o = array_create(len, false);

    for (i = 0; i < array_length(key_array); i++) {
        o[key_array[i]] = true;
    }

    return o;
}
