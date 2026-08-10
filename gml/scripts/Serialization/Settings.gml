#macro SETTINGS_PATH (CONFIG_DIRECTORY + "/settings.json")
#macro NEW_SETTINGS_PATH (CONFIG_DIRECTORY + "/settings.new.json")
#macro OLD_SETTINGS_PATH (CONFIG_DIRECTORY + "/settings.old.json")
#macro SETTINGS global.__settings
global.__settings = undefined;

function load_settings(ignore_patch=false) {
    var settings = get_default_settings();

    if TEST_SUITE {
        trace("Running TEST_SUITE -- Using default settings with `pause_on_unfocus=false`");
        settings.pause_on_unfocus = false;
        settings.open_fscreen = false;
        settings.window_x = 1280;
        settings.window_y = 720;
        settings.global_volume = 0;
        settings.vsync = 0;
        var language = environment_get_variable("TEST_SUITE_LANGUAGE");
        settings.language = language == undefined ? "eng" : language;

        return MapWrap(settings);
    }

    var data = undefined;
    if file_exists(SETTINGS_PATH) {
        data = try_read_json_file(SETTINGS_PATH);
    }

    if data != undefined {
        settings = MapWrap(patch_object(data.settings, settings));

        if data.version[$ "pre"] == undefined {
            data.version.pre = undefined;
        }
        if ignore_patch == false && version_is_ahead(GAME_VERSION, data.version) {
            settings = apply_settings_patches(data.version, GAME_VERSION, settings);
            save_settings(settings);
        }
    } else {
        settings = MapWrap(settings);
    }

    return settings;
}

function get_default_settings() {
    return {
        bindings: default_input_id_bindings(),
        language: local_language(),
        sfx_volume: 1,
        msc_volume: 1,
        amb_volume: 1,
        global_volume: 1,
        fscreen_expansion: 0,
        fscreen_expansion: 0,
		open_fscreen: OPEN_FULLSCREEN,
		window_x: OPEN_FULLSCREEN ? 1920 : 1280,
		window_y: OPEN_FULLSCREEN ? 1080 : 720,
        window_expansion: 0,
        one_stick_mode: false,
        gp_cam_move: 1,
        screenshake: true,
        screen_flash: true,
        vsync: 1,
        show_tile_cursor: true,
        twenty_four_hour_clock: false,
        show_hud_numbers: false,
        pause_on_unfocus: true,
        pause_audio_on_unfocus: true,
        borderless_fullscreen: true,
        button_glyph_preference: steam_on_deck() ? "xbox" : "nintendo",
        menu_bounce: true,
        rumble: true,
        sound_footsteps: true,
        sound_vocal_text: true,
        sound_eating_drinking: true,
        sound_animals: true,
        weather_strength: "default",
        touch_screen: false,
        send_analytics: true,
        can_burn_fruit_trees: true,
        oversleep_penalty: true,
        low_spec_mode: false,
        high_res_in_cutscenes: true,
        asymptote: true,
        scrolling_backgrounds: true,
        native_cursor: true,
        snap_frame_rate: false,
        frame_rate_cap: false,
        gamma_slider: 0.5,
        saturation_slider: 0.5,
    };
}

function default_input_id_bindings(platform_override) {
    var bindings = {};

    for (var i = 0; i < InputId.LEN; i++) {
        bindings[$ input_id_to_string(i)] = default_bindings_for_input_id(i, platform_override);
    }

    return bindings;
}

#macro gp_south gp_face1
#macro gp_east gp_face2
#macro gp_north gp_face4
#macro gp_west gp_face3

function default_bindings_for_input_id(input_id, platform_override) {
    var platform = os_type;
    if platform_override != undefined {
        platform = platform_override;
    }

    var east_override = platform == "switch" ? "south_face" : "east_face";
    var south_override = platform == "switch" ? "east_face" : "south_face";

    switch input_id {
        case InputId.Up: return ["w", "arrow_up", "pad_up", "left_stick_up"];
        case InputId.Down: return ["s", "arrow_down", "pad_down", "left_stick_down"];
        case InputId.Left: return ["a", "arrow_left", "pad_left", "left_stick_left"];
        case InputId.Right: return ["d", "arrow_right", "pad_right", "left_stick_right"];

        case InputId.Interact: return ["e", "mb_right", south_override, undefined];
        case InputId.OpenJournal: return ["escape", undefined, "start", undefined];
        case InputId.Walk: return ["control", undefined, undefined, undefined];
        case InputId.Jump: return ["space", undefined, east_override, undefined];
        case InputId.UseToolCharged: return ["mb_left", "t", "west_face", undefined];
        case InputId.UseToolRepeated: return [undefined, undefined, undefined, undefined];
        case InputId.Throw: return ["g", undefined, "right_trigger", undefined];
        case InputId.SecondaryInteract: return ["q", undefined, "north_face", undefined];
        case InputId.Ride: return ["+", undefined, "left_stick", undefined];
        case InputId.OpenMapMenu: return ["m", undefined, "select", undefined];
        case InputId.NextPreset: return [".", undefined, undefined, undefined];
        case InputId.LastPreset: return [",", undefined, undefined, undefined];
        case InputId.LeftMouse: return ["mb_left", undefined, undefined, undefined];
        case InputId.MenuBack: return ["escape", undefined, east_override, undefined];
        case InputId.PickUpOne: return ["mb_right", undefined, "west_face", undefined];
        case InputId.MenuTabLeft: return ["[", undefined, "left_bumper", undefined];
        case InputId.MenuTabRight: return ["]", undefined, "right_bumper", undefined];
        case InputId.ToolbarIncUp: return ["mb_wheel_down", undefined, "left_bumper", undefined];
        case InputId.ToolbarIncDown: return ["mb_wheel_up", undefined, "right_bumper", undefined];
        case InputId.SelectToolbarOne: return ["1", undefined, undefined, undefined];
        case InputId.SelectToolbarTwo: return ["2", undefined, undefined, undefined];
        case InputId.SelectToolbarThree: return ["3", undefined, undefined, undefined];
        case InputId.SelectToolbarFour: return ["4", undefined, undefined, undefined];
        case InputId.SelectToolbarFive: return ["5", undefined, undefined, undefined];
        case InputId.SelectToolbarSix: return ["6", undefined, undefined, undefined];
        case InputId.SelectToolbarSeven: return ["7", undefined, undefined, undefined];
        case InputId.SelectToolbarEight: return ["8", undefined, undefined, undefined];
        case InputId.SelectToolbarNine: return ["9", undefined, undefined, undefined];
        case InputId.SelectToolbarZero: return ["0", undefined, undefined, undefined];
        case InputId.RotateRight: return ["r", "mb_right", "north_face", undefined];
        case InputId.RotateLeft: return ["q", undefined, undefined, undefined];
        case InputId.FurnitureUp: return [undefined, undefined, "right_stick_up", undefined];
        case InputId.FurnitureDown: return [undefined, undefined, "right_stick_down", undefined];
        case InputId.FurnitureLeft: return [undefined, undefined, "right_stick_left", undefined];
        case InputId.FurnitureRight: return [undefined, undefined, "right_stick_right", undefined];
        case InputId.CastPinnedSpell: return ["c", undefined, "left_trigger", undefined];
        case InputId.NextToolbarTab: return ["tab", undefined, "right_stick", undefined];
        case InputId.LastToolbarTab: return [undefined, undefined, undefined, undefined];
        case InputId.ResetControls: return ["backspace", undefined, "start", undefined];
        case InputId.ConfirmTextInput: return ["enter", undefined, "start", undefined];
        default: impossible("unexpected input_id {InputId}", input_id);
    }
}

function save_settings(settings_override) {
    //
    if TEST_SUITE {
        return;
    }

    var output = {
        version: GAME_VERSION,
        settings: settings_override == undefined ? SETTINGS.inner : settings_override.inner,
    };

    if file_exists(OLD_SETTINGS_PATH) {
        file_delete(OLD_SETTINGS_PATH);
    }

    if file_exists(NEW_SETTINGS_PATH) {
        file_delete(NEW_SETTINGS_PATH);
    }

    if file_exists(SETTINGS_PATH) {
        file_rename(SETTINGS_PATH, OLD_SETTINGS_PATH);
    }

    save_json_file(NEW_SETTINGS_PATH, output);

    file_rename(NEW_SETTINGS_PATH, SETTINGS_PATH);
}

function saved_bindings_to_bindings(saved_bindings) {
    var bindings_manager = new Bindings();

    for (var i = 0; i < InputId.LEN; i++) {
        var new_bindings = bindings_manager.bindings[i];
        var binding = saved_bindings[$ input_id_to_string(i)];

        decode_binding(i, new_bindings, binding);
    }

    return bindings_manager;
}

function decode_binding(input_id, new_bindings, binding) {
    if binding == undefined {
        binding = default_bindings_for_input_id(input_id);
    }

    for (var j = 0; j < array_length(binding); j++) {
        var raw_keycode = binding[j];
        //
        if raw_keycode != undefined && raw_keycode != -1 {
            var keycode;
            if is_string(raw_keycode) {
                keycode = string_to_keycode(raw_keycode);
            } else {
                //
                var this_keycode = gm_keycode_to_string(raw_keycode);
                if this_keycode == undefined {
                    error("Failed to parse integer input: {}", raw_keycode);
                    decode_binding(input_id, new_bindings, undefined);
                    return;
                } else {
                    keycode = string_to_keycode(this_keycode);
                }
            }

            if keycode != undefined {
                new_bindings[j] = {
                    keycode,
                    type: keycode_to_binding_type(keycode),
                };
            }
        }
    }
}

enum Vsync {
    Adaptive = -1,
    Off = 0,
    On = 1,
}
