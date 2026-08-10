#macro SHADOW_DICTIONARY global.__shadow_dictionary
global.__shadow_dictionary = undefined;

//
function ShadowDictionary() {
    var map = generate_sprite_remap_dictionary("animation/shadow_manifest.json");

    return {
        //
        map: map,

        //
        get: function(sprite_key) {
            var shadow = self.map[$ sprite_key];

            if shadow == undefined {
                return spr_nothing;
            } else {
                return shadow;
            }
        },

        //
        //
        try_get: function(sprite_key) {
            return self.map[$ sprite_key];
        },
    }
}

//
function generate_sprite_remap_dictionary(fpath) {
    var map = {};

    //
    var struct = read_json_file(fpath);

    //
    var json_object_names = struct_get_names(struct);

    //
    for (var o = 0, c = array_length(json_object_names); o < c; o++) {
        var name = json_object_names[o];
        var idx = try_string_to_asset(name);
        var value = try_string_to_asset(struct[$ name]);

        if !DEBUG_ASSERTIONS {
            if idx == undefined {
                error("Sprite `{}` did not exist. ignoring...", name);
                continue;
            }
            if value == undefined {
                error("Sprite `{}` did not exist. ignoring...", struct[$ name]);
                continue;
            }
        } else if idx == undefined || value == undefined {
            crash("either sprite `{}` or sprite `{}` did not exist!", name, struct[$ name]);
        }

        map[$ idx] = value;
    }

    return map;
}
