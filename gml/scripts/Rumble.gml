#macro RUMBLE global.__rumble
RUMBLE = undefined;

function parse_rumble_database() {
    var o = array_create(RumbleKind.LEN, undefined);
    var f_o = fiddle_get("rumbles");

    for (var i = 0; i < RumbleKind.LEN; i++) {
        var rumble_data = f_o[$ rumble_kind_to_string(i)];
        o[i] = {
            max_length: rumble_data.length,
            strength: rumble_data[$ "strength"] ?? 1,
        }
    }

    return o;
}

//
function set_rumble(rumble_kind) {
    var rumble_data = RUMBLE_DATABSE[rumble_kind];
    RUMBLE = {
        timer: 0,
        max_length: rumble_data.max_length,
        left_max: rumble_data.strength,
        right_max: rumble_data.strength,
    };
}

//
function set_rumble_additive(rumble_kind, max_multiplier) {
    if RUMBLE == undefined {
        set_rumble(rumble_kind);
    } else {
        var rumble_data = RUMBLE_DATABSE[rumble_kind];
        RUMBLE.max_length += rumble_data.max_length;
        RUMBLE.left_max = min(rumble_data.strength + RUMBLE.left_max, rumble_data.strength * max_multiplier);
        RUMBLE.right_max = min(rumble_data.strength + RUMBLE.right_max, rumble_data.strength * max_multiplier);

        RUMBLE = {
            timer: 0,
            max_length: rumble_data.max_length,
            left_max: rumble_data.strength,
            right_max: rumble_data.strength,
        };
    }
}
