#macro BARK_PROTOTYPES global.__barks
global.__barks = undefined;

#macro BARK_OPENING_INFO global.__bark_opening_info
global.__bark_opening_info = undefined;

#macro BARK_CLOSING_INFO global.__bark_closing_info
global.__bark_closing_info = undefined;

#macro BARK_TIMER 80

function load_bark_prototypes() {
    var toml_data = MapWrap(clone_value(fiddle_get("barks")));
    var default_value = toml_data.take("default");
    var keys = toml_data.keys();
    var collection = array_create(BarkId.LEN, undefined);

    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];
        var prototype = patch_object(toml_data.get(key), clone_value(default_value));
        apply_func(prototype, function(e) {
            return e == "<n/a>" ? undefined : e;
        });
        prototype.icon = string_to_asset(prototype.icon ?? fmt("spr_ui_bark_icon_{}", key));
        prototype.id = string_to_bark_id(key);
        prototype.frames = array_map(sprite_get_info(prototype.icon).frame_info, function(value) {
            //
            //
            //
            //
            //
            //
            //
            //
            //
            return value.duration * 1.5;
        });

        if DEBUG_ASSERTIONS {
            var v = 0;
            for (var k = 0; k < array_length(prototype.frames); k++) {
                v += prototype.frames[k];
            }
            assert(v < BARK_TIMER, "{BarkId} is too long! It's {}s, but it must be shorter than {}s", prototype.id, v, BARK_TIMER);
        }

        collection[prototype.id] = prototype;
    }

    return collection;
}

function load_bark_opening_info() {
    return [
        array_map(sprite_get_info(spr_ui_bark_bubble_think_opening).frame_info, function(value) {
            return value.duration * 1.5;
        }),
        array_map(sprite_get_info(spr_ui_bark_bubble_speak_opening).frame_info, function(value) {
            return value.duration * 1.5;
        }),
    ];

}

function load_bark_closing_info() {
    return [
        array_map(sprite_get_info(spr_ui_bark_bubble_think_closing).frame_info, function(value) {
            return value.duration * 1.5;
        }),
        array_map(sprite_get_info(spr_ui_bark_bubble_speak_closing).frame_info, function(value) {
            return value.duration * 1.5;
        }),
    ];
}

enum BarkState {
    In,
    Sit,
    Out,
}

enum BarkType {
    Thought,
    Speech,
}
