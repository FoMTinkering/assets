//
#macro GP_PER_AXIS_CHECK 0.6

//
#macro GP_DEAD_ZONE_UI (GP_PER_AXIS_CHECK * GP_PER_AXIS_CHECK)

//
#macro GP_DEAD_ZONE (GP_DEAD_ZONE_UI * GP_DEAD_ZONE_UI)

#macro GAMEPADS_COUNT 8

#macro GAMEPADS_LAST_FRAME global.__gamepads_connected
global.__gamepads_connected = [];

enum InputType {
    Kbm,
    Gamepad,
    LEN,
}

enum InputId {
    LeftMouse,
    Up,
    Down,
    Left,
    Right,
    Jump,
    Interact,
    SecondaryInteract,
    PickUpOne,
    OpenJournal,
    MenuBack,
    UseToolCharged,
    UseToolRepeated,
    CastPinnedSpell,
    Throw,
    Walk,
    Ride,
    OpenMapMenu,
    MenuTabRight,
    MenuTabLeft,
    NextPreset,
    LastPreset,
    ToolbarIncUp,
    ToolbarIncDown,
    RotateRight,
    RotateLeft,
    FurnitureUp,
    FurnitureDown,
    FurnitureLeft,
    FurnitureRight,
    NextToolbarTab,
    LastToolbarTab,
    SelectToolbarOne,
    SelectToolbarTwo,
    SelectToolbarThree,
    SelectToolbarFour,
    SelectToolbarFive,
    SelectToolbarSix,
    SelectToolbarSeven,
    SelectToolbarEight,
    SelectToolbarNine,
    SelectToolbarZero,
    ConfirmTextInput,
    ResetControls,
    LEN
}

enum BindingType {
    Keyboard,
    Mouse,
    GamepadButton,
    GamepadAxis,
    LEN,
}

function binding_type_to_input_type(bt) {
    switch bt {
        case BindingType.Keyboard:
        case BindingType.Mouse:
            return InputType.Kbm;
        case BindingType.GamepadButton:
            return InputType.Gamepad;
        case BindingType.GamepadAxis:
            return InputType.Gamepad;

        default: impossible("unexpected binding type: {}", bt);
    }
}

enum DigitalStatus {
    //
    //
    Off,

    //
    Pressed = 1 << 0,

    //
    Released = 1 << 1,

    //
    On = 1 << 2,

    //
    Muted = 1 << 3,
}

enum InputStatus {
    Off,
    Pressed,
    Down,
    Released,
    LEN,
}

//
#macro mb_wheel_up 12345 //
#macro mb_wheel_down 54321 //

#macro KEYBOARD_INPUTS global.__KEYBOARD_INPUTS
//
KEYBOARD_INPUTS = [
    ord("A"),
    ord("B"),
    ord("C"),
    ord("D"),
    ord("E"),
    ord("F"),
    ord("G"),
    ord("H"),
    ord("I"),
    ord("J"),
    ord("K"),
    ord("L"),
    ord("M"),
    ord("N"),
    ord("O"),
    ord("P"),
    ord("Q"),
    ord("R"),
    ord("S"),
    ord("T"),
    ord("U"),
    ord("V"),
    ord("W"),
    ord("X"),
    ord("Y"),
    ord("Z"),
    vk_semicolon,
    vk_grave,
    vk_plus,
    vk_minus,
    vk_equals,
    vk_square_bracket_right,
    vk_square_bracket_left,
    vk_slash,
    vk_slash, //
    vk_delete,
    vk_end,
    vk_pagedown,
    vk_pageup,
    vk_insert,
    vk_space,
    vk_tab,
    vk_backspace,
    vk_caps_lock,
    vk_shift,
    vk_control,
    vk_enter,
    vk_up,
    vk_down,
    vk_left,
    vk_right,
    vk_f1,
    vk_f2,
    vk_f3,
    vk_f4,
    vk_f5,
    vk_f6,
    vk_f7,
    vk_f8,
    vk_f9,
    vk_f10,
    vk_f11,
    vk_f12,
    vk_home,
    vk_escape,
    vk_comma,
    vk_period,
    ord("0"),
    ord("1"),
    ord("2"),
    ord("3"),
    ord("4"),
    ord("5"),
    ord("6"),
    ord("7"),
    ord("8"),
    ord("9"),
    vk_period,
];

#macro MOUSE_BUTTONS global.__mouse_buttons
//
//
//
MOUSE_BUTTONS = [mb_left, mb_right, mb_middle, mb_wheel_up, mb_wheel_down];

#macro GAMEPAD_BUTTONS global.__GAMEPAD_BUTTONS
//
GAMEPAD_BUTTONS = [
    gp_select,
    gp_start,
    gp_stickl,
    gp_stickr,
    gp_padu,
    gp_padd,
    gp_padl,
    gp_padr,
    gp_face4,
    gp_face3,
    gp_face2,
    gp_face1,
    gp_shoulderlb,
    gp_shoulderrb,
    gp_shoulderl,
    gp_shoulderr,
    gp_paddler,
    gp_paddlel,
    gp_paddlerb,
    gp_paddlelb,
];

#macro GAMEPAD_AXIS global.__gamepad_axis
GAMEPAD_AXIS = [
    -gp_axislv,
    gp_axislv,
    -gp_axislh,
    gp_axislh,
    -gp_axisrv,
    gp_axisrv,
    -gp_axisrh,
    gp_axisrh,
]

//
//
//
//
//
//
//
#macro INPUT_UNLISTED global.__input_unlisted
INPUT_UNLISTED = array_create_ext(InputId.LEN, function(i) {
    return matches(
        i,
        InputId.LeftMouse,
        InputId.ConfirmTextInput,
        InputId.ResetControls,
    );
})

//
//
#macro INPUT_REQUIRED global.__input_required
INPUT_REQUIRED = array_create_ext(InputId.LEN, function(i) {
    return matches(
        i,
        InputId.Up,
        InputId.Down,
        InputId.Left,
        InputId.Right,
        InputId.MenuBack,
        InputId.OpenJournal,
        InputId.ResetControls,
        InputId.Interact,
    )
})

enum InputCategory {
    General,
    InWorld,
}

function input_id_to_input_category(input_id) {
    switch input_id {
        case InputId.Up:
        case InputId.Down:
        case InputId.Left:
        case InputId.Right:
        case InputId.Interact:
        case InputId.LeftMouse:
        case InputId.MenuTabRight:
        case InputId.MenuTabLeft:
        case InputId.SelectToolbarOne:
        case InputId.SelectToolbarTwo:
        case InputId.SelectToolbarThree:
        case InputId.SelectToolbarFour:
        case InputId.SelectToolbarFive:
        case InputId.SelectToolbarSix:
        case InputId.SelectToolbarSeven:
        case InputId.SelectToolbarEight:
        case InputId.SelectToolbarNine:
        case InputId.SelectToolbarZero:
        case InputId.MenuBack:
        case InputId.SecondaryInteract:
        case InputId.PickUpOne:
        case InputId.ConfirmTextInput:
        case InputId.ResetControls:
            return InputCategory.General;
        case InputId.OpenJournal:
        case InputId.Walk:
        case InputId.Jump:
        case InputId.UseToolCharged:
        case InputId.UseToolRepeated:
        case InputId.Throw:
        case InputId.ToolbarIncUp:
        case InputId.ToolbarIncDown:
        case InputId.OpenMapMenu:
        case InputId.NextPreset:
        case InputId.LastPreset:
        case InputId.RotateRight:
        case InputId.RotateLeft:
        case InputId.FurnitureUp:
        case InputId.FurnitureDown:
        case InputId.FurnitureLeft:
        case InputId.FurnitureRight:
        case InputId.CastPinnedSpell:
        case InputId.NextToolbarTab:
        case InputId.LastToolbarTab:
        case InputId.Ride:
            return InputCategory.InWorld;
        default: impossible("Unexpected InputId: {InputId}", input_id);
    }
}

function input_forbidden_on_gamepad(input_id) {
    return matches(input_id, InputId.Walk);
}

//
function kb_input_to_index(keycode) {
    var index = array_index(KEYBOARD_INPUTS, keycode);
    assert_neq(index, undefined, "{keycode} is not a valid keyboard keycode!", keycode);
    return index + 1;
}

//
function mouse_input_to_index(keycode) {
    var index = array_index(MOUSE_BUTTONS, keycode);
    assert_neq(index, undefined, "{keycode} is not a valid mouse keycode!", keycode);
    return index + 1;
}

//
function gp_input_to_index(keycode) {
    var index = array_index(GAMEPAD_BUTTONS, keycode);
    assert_neq(index, undefined, "{keycode} is not a valid gamepad keycode!", keycode);
    return index + 1;
}

//
function gp_axis_input_to_index(keycode) {
    var index = array_index(GAMEPAD_AXIS, keycode);
    assert_neq(index, undefined, "{keycode} is not a valid gamepad axis keycode!", keycode);
    return index;
}

//
//
function number_to_input(i) {
    switch i {
        case 0: return InputId.SelectToolbarZero;
        case 1: return InputId.SelectToolbarOne;
        case 2: return InputId.SelectToolbarTwo;
        case 3: return InputId.SelectToolbarThree;
        case 4: return InputId.SelectToolbarFour;
        case 5: return InputId.SelectToolbarFive;
        case 6: return InputId.SelectToolbarSix;
        case 7: return InputId.SelectToolbarSeven;
        case 8: return InputId.SelectToolbarEight;
        case 9: return InputId.SelectToolbarNine;
        default: impossible();
    }
}

//
function keycode_to_binding_type(keycode) {
    if array_contains(MOUSE_BUTTONS, keycode) {
        return BindingType.Mouse;
    } else if array_contains(KEYBOARD_INPUTS, keycode) {
        return BindingType.Keyboard;
    } else if array_contains(GAMEPAD_BUTTONS, keycode) {
        return BindingType.GamepadButton;
    } else if array_contains(GAMEPAD_AXIS, keycode) {
        return BindingType.GamepadAxis;
    }
    impossible("Failed to find an BindingType for {}", keycode);
}

function big_keyboard_keys_sprite() {
    switch local_language() {
        case "spa": return spr_ui_generic_keyboard_keys_es;
        case "fra": return spr_ui_generic_keyboard_keys_fr;
        default: return spr_ui_generic_keyboard_keys;
    }
}

function small_keyboard_keys_sprite() {
    switch local_language() {
        case "spa": return spr_ui_generic_keyboard_keys_small_es;
        case "fra": return spr_ui_generic_keyboard_keys_small_fr;
        default: return spr_ui_generic_keyboard_keys_small;
    }
}

//
function get_display_for_input_id(input_id) {
    var slot = ON_GAMEPAD || ON_CONSOLE ? 2 : 0;
    var binding = BINDINGS.get_binding(input_id, slot);
    return binding != undefined
        ? get_display_for_keycode(binding.keycode)
        : {
            big_sprite: big_keyboard_keys_sprite(),
            small_sprite: small_keyboard_keys_sprite(),
            index: 0,
        };
}

//
function get_display_for_keycode(keycode) {
    var input_type = keycode_to_binding_type(keycode);
    var big_sprite = undefined;
    var small_sprite = undefined;
    var index = undefined;
    switch input_type {
        case BindingType.Keyboard:
            big_sprite = big_keyboard_keys_sprite();
            small_sprite = small_keyboard_keys_sprite();
            index = kb_input_to_index(keycode);
            break;
        case BindingType.Mouse:
            big_sprite = spr_ui_generic_mouse_keys;
            small_sprite = spr_ui_generic_mouse_keys_small;
            index = mouse_input_to_index(keycode);
            break;
        case BindingType.GamepadButton:
            switch SETTINGS.get("button_glyph_preference") {
                case "xbox":
                    big_sprite = spr_ui_generic_xbox_buttons;
                    small_sprite = spr_ui_generic_xbox_small_buttons;
                    break;
                case "nintendo":
                    big_sprite = spr_ui_generic_switch_big_buttons;
                    small_sprite = spr_ui_generic_switch_small_buttons;
                    break;
                case "play_station":
                    big_sprite = spr_ui_generic_playstation_buttons;
                    small_sprite = spr_ui_generic_playstation_small_buttons;
                    break;
                default: impossible("Unexpected button glyphs: {}", SETTINGS.get("button_glyph_preference"));
            }
            index = gp_input_to_index(keycode);
            break;
        case BindingType.GamepadAxis:
            switch SETTINGS.get("button_glyph_preference") {
                case "xbox":
                    big_sprite = spr_ui_generic_xbox_analog;
                    small_sprite = spr_ui_generic_xbox_small_analog;
                    break;
                case "nintendo":
                    big_sprite = spr_ui_generic_switch_big_analog;
                    small_sprite = spr_ui_generic_switch_small_analog;
                    break;
                case "play_station":
                    big_sprite = spr_ui_generic_playstation_analog;
                    small_sprite = spr_ui_generic_playstation_small_analog;
                    break;
                default: impossible("Unexpected button glyphs: {}", SETTINGS.get("button_glyph_preference"));
            }
            index = gp_axis_input_to_index(keycode);
            break;

        default: impossible("Unexpected BindingType: {BindingType}", input_type);
    }
    return {
        big_sprite,
        small_sprite,
        index,
    };
}

//
function gamepad_check_any() {
    for (var gp_index = 0; gp_index < GAMEPADS_COUNT; gp_index++) {
        if gamepad_is_connected(gp_index) == false {
            continue;
        }

        var final_index = gp_padr; //
        for (var i = gp_face1; i <= final_index; i++) {
            if gamepad_button_check(gp_index, i) {
                return true;
            }
        }

        var final_index = gp_axisrv;
        for (var i = gp_axislh; i <= final_index; i++) {
            if abs(gamepad_axis_value(gp_index, i)) {
                return true;
            }
        }
    }

    return false;
}

//
function place_object_input_id() {
    if ON_GAMEPAD {
        return InputId.Interact;
    } else {
        return BINDINGS.get_primary_binding(InputId.UseToolCharged) == undefined
            ? InputId.UseToolRepeated
            : InputId.UseToolCharged;
    }
}

#macro GAMEPAD_LOST_POPUP global.__gamepad_lost_popup
GAMEPAD_LOST_POPUP = undefined;

function keycode_to_string(keycode) {
    switch keycode {
        case ord("A"): return "a";
        case ord("B"): return "b";
        case ord("C"): return "c";
        case ord("D"): return "d";
        case ord("E"): return "e";
        case ord("F"): return "f";
        case ord("G"): return "g";
        case ord("H"): return "h";
        case ord("I"): return "i";
        case ord("J"): return "j";
        case ord("K"): return "k";
        case ord("L"): return "l";
        case ord("M"): return "m";
        case ord("N"): return "n";
        case ord("O"): return "o";
        case ord("P"): return "p";
        case ord("Q"): return "q";
        case ord("R"): return "r";
        case ord("S"): return "s";
        case ord("T"): return "t";
        case ord("U"): return "u";
        case ord("V"): return "v";
        case ord("W"): return "w";
        case ord("X"): return "x";
        case ord("Y"): return "y";
        case ord("Z"): return "z";
        case vk_semicolon: return ";";
        case vk_grave: return "`";
        case vk_plus: return "+";
        case vk_minus: return "-";
        case vk_equals: return "=";
        case vk_square_bracket_right: return "]";
        case vk_square_bracket_left: return "[";
        case vk_slash: return "/";
        case vk_delete: return "delete";
        case vk_end: return "end";
        case vk_pagedown: return "page_down";
        case vk_pageup: return "page_up";
        case vk_insert: return "insert";
        case vk_space: return "space";
        case vk_tab: return "tab";
        case vk_backspace: return "backspace";
        case vk_caps_lock: return "caps_lock";
        case vk_shift: return "shift";
        case vk_control: return "control";
        case vk_enter: return "enter";
        case vk_up: return "arrow_up";
        case vk_down: return "arrow_down";
        case vk_left: return "arrow_left";
        case vk_right: return "arrow_right";
        case vk_f1: return "f1";
        case vk_f2: return "f2";
        case vk_f3: return "f3";
        case vk_f4: return "f4";
        case vk_f5: return "f5";
        case vk_f6: return "f6";
        case vk_f7: return "f7";
        case vk_f8: return "f8";
        case vk_f9: return "f9";
        case vk_f10: return "f10";
        case vk_f11: return "f11";
        case vk_f12: return "f12";
        case vk_home: return "home";
        case vk_escape: return "escape";
        case vk_comma: return ",";
        case vk_period: return ".";
        case ord("0"): return "0";
        case ord("1"): return "1";
        case ord("2"): return "2";
        case ord("3"): return "3";
        case ord("4"): return "4";
        case ord("5"): return "5";
        case ord("6"): return "6";
        case ord("7"): return "7";
        case ord("8"): return "8";
        case ord("9"): return "9";
        case mb_left: return "mb_left";
        case mb_right: return "mb_right";
        case mb_middle: return "mb_middle";
        case mb_wheel_up: return "mb_wheel_up";
        case mb_wheel_down: return "mb_wheel_down";
        case gp_select: return "select";
        case gp_start: return "start";
        case gp_stickl: return "left_stick";
        case gp_stickr: return "right_stick";
        case gp_padu: return "pad_up";
        case gp_padd: return "pad_down";
        case gp_padl: return "pad_left";
        case gp_padr: return "pad_right";
        case gp_north: return "north_face";
        case gp_west: return "west_face";
        case gp_east: return "east_face";
        case gp_south: return "south_face";
        case gp_shoulderlb: return "left_trigger";
        case gp_shoulderrb: return "right_trigger";
        case gp_shoulderl: return "left_bumper";
        case gp_shoulderr: return "right_bumper";
        case gp_paddler: return "paddle_one";
        case gp_paddlel: return "paddle_two";
        case gp_paddlerb: return "paddle_three";
        case gp_paddlelb: return "paddle_four";
        case -gp_axislv: return "left_stick_up";
        case gp_axislv: return "left_stick_down";
        case -gp_axislh: return "left_stick_left";
        case gp_axislh: return "left_stick_right";
        case -gp_axisrv: return "right_stick_up";
        case gp_axisrv: return "right_stick_down";
        case -gp_axisrh: return "right_stick_left";
        case gp_axisrh: return "right_stick_right";
        default: impossible("Unexpected keycode: {}", keycode);
    }
}

function string_to_keycode(keycode) {
    switch keycode {
        case "a": return ord("A");
        case "b": return ord("B");
        case "c": return ord("C");
        case "d": return ord("D");
        case "e": return ord("E");
        case "f": return ord("F");
        case "g": return ord("G");
        case "h": return ord("H");
        case "i": return ord("I");
        case "j": return ord("J");
        case "k": return ord("K");
        case "l": return ord("L");
        case "m": return ord("M");
        case "n": return ord("N");
        case "o": return ord("O");
        case "p": return ord("P");
        case "q": return ord("Q");
        case "r": return ord("R");
        case "s": return ord("S");
        case "t": return ord("T");
        case "u": return ord("U");
        case "v": return ord("V");
        case "w": return ord("W");
        case "x": return ord("X");
        case "y": return ord("Y");
        case "z": return ord("Z");
        case ";": return vk_semicolon;
        case "`": return vk_grave;
        case "+": return vk_plus;
        case "-": return vk_minus;
        case "=": return vk_equals;
        case "]": return vk_square_bracket_right;
        case "[": return vk_square_bracket_left;
        case "/": return vk_slash;
        case "delete": return vk_delete;
        case "end": return vk_end;
        case "page_down": return vk_pagedown;
        case "page_up": return vk_pageup;
        case "insert": return vk_insert;
        case "space": return vk_space;
        case "tab": return vk_tab;
        case "backspace": return vk_backspace;
        case "caps_lock": return vk_caps_lock;
        case "shift": return vk_shift;
        case "control": return vk_control;
        case "enter": return vk_enter;
        case "arrow_up": return vk_up;
        case "arrow_down": return vk_down;
        case "arrow_left": return vk_left;
        case "arrow_right": return vk_right;
        case "f1": return vk_f1;
        case "f2": return vk_f2;
        case "f3": return vk_f3;
        case "f4": return vk_f4;
        case "f5": return vk_f5;
        case "f6": return vk_f6;
        case "f7": return vk_f7;
        case "f8": return vk_f8;
        case "f9": return vk_f9;
        case "f10": return vk_f10;
        case "f11": return vk_f11;
        case "f12": return vk_f12;
        case "home": return vk_home;
        case "escape": return vk_escape;
        case ",": return vk_comma;
        case ".": return vk_period;
        case "0": return ord("0");
        case "1": return ord("1");
        case "2": return ord("2");
        case "3": return ord("3");
        case "4": return ord("4");
        case "5": return ord("5");
        case "6": return ord("6");
        case "7": return ord("7");
        case "8": return ord("8");
        case "9": return ord("9");
        case "mb_left": return mb_left;
        case "mb_right": return mb_right;
        case "mb_middle": return mb_middle;
        case "mb_wheel_up": return mb_wheel_up;
        case "mb_wheel_down": return mb_wheel_down;
        case "select": return gp_select;
        case "start": return gp_start;
        case "left_stick": return gp_stickl;
        case "right_stick": return gp_stickr;
        case "pad_up": return gp_padu;
        case "pad_down": return gp_padd;
        case "pad_left": return gp_padl;
        case "pad_right": return gp_padr;
        case "north_face": return gp_north;
        case "west_face": return gp_west;
        case "east_face": return gp_east;
        case "south_face": return gp_south;
        case "left_trigger": return gp_shoulderlb;
        case "right_trigger": return gp_shoulderrb;
        case "left_bumper": return gp_shoulderl;
        case "right_bumper": return gp_shoulderr;
        case "paddle_one": return gp_paddler;
        case "paddle_two": return gp_paddlel;
        case "paddle_three": return gp_paddlerb;
        case "paddle_four": return gp_paddlelb;
        case "left_stick_up": return -gp_axislv;
        case "left_stick_down": return gp_axislv;
        case "left_stick_left": return -gp_axislh;
        case "left_stick_right": return gp_axislh;
        case "right_stick_up": return -gp_axisrv;
        case "right_stick_down": return gp_axisrv;
        case "right_stick_left": return -gp_axisrh;
        case "right_stick_right": return gp_axisrh;
        default: impossible("Unexpected keycode: {}", keycode);
    }
}

function gm_keycode_to_string(gm_keycode) {
    switch gm_keycode {
        case 65: return "a";
        case 66: return "b";
        case 67: return "c";
        case 68: return "d";
        case 69: return "e";
        case 70: return "f";
        case 71: return "g";
        case 72: return "h";
        case 73: return "i";
        case 74: return "j";
        case 75: return "k";
        case 76: return "l";
        case 77: return "m";
        case 78: return "n";
        case 79: return "o";
        case 80: return "p";
        case 81: return "q";
        case 82: return "r";
        case 83: return "s";
        case 84: return "t";
        case 85: return "u";
        case 86: return "v";
        case 87: return "w";
        case 88: return "x";
        case 89: return "y";
        case 90: return "z";
        case 186: return ";";
        case 192: return "`";
        case 107: return "+";
        case 109: return "-";
        case 187: return "=";
        case 221: return "]";
        case 219: return "[";
        case 191: return "/";
        case 46: return "delete";
        case 35: return "end";
        case 34: return "page_down";
        case 33: return "page_up";
        case 45: return "insert";
        case 32: return "space";
        case 9: return "tab";
        case 8: return "backspace";
        case 20: return "caps_lock";
        case 16: return "shift";
        case 17: return "control";
        case 13: return "enter";
        case 38: return "arrow_up";
        case 40: return "arrow_down";
        case 37: return "arrow_left";
        case 39: return "arrow_right";
        case 112: return "f1";
        case 113: return "f2";
        case 114: return "f3";
        case 115: return "f4";
        case 116: return "f5";
        case 117: return "f6";
        case 118: return "f7";
        case 119: return "f8";
        case 120: return "f9";
        case 121: return "f10";
        case 122: return "f11";
        case 123: return "f12";
        case 36: return "home";
        case 27: return "escape";
        case 188: return ",";
        case 190: return ".";
        case 48: return "0";
        case 49: return "1";
        case 50: return "2";
        case 51: return "3";
        case 52: return "4";
        case 53: return "5";
        case 54: return "6";
        case 55: return "7";
        case 56: return "8";
        case 57: return "9";
        case 1: return "mb_left";
        case 2: return "mb_right";
        case 3: return "mb_middle";
        case 12345: return "mb_wheel_up";
        case 54321: return "mb_wheel_down";
        case 32777: return "select";
        case 32778: return "start";
        case 32779: return "left_stick";
        case 32780: return "right_stick";
        case 32781: return "pad_up";
        case 32782: return "pad_down";
        case 32783: return "pad_left";
        case 32784: return "pad_right";
        case 32772: return "north_face";
        case 32771: return "west_face";
        case 32770: return "east_face";
        case 32769: return "south_face";
        case 32775: return "left_trigger";
        case 32776: return "right_trigger";
        case 32773: return "left_bumper";
        case 32774: return "right_bumper";
        case 32804: return "paddle_one";
        case 32805: return "paddle_two";
        case 32806: return "paddle_three";
        case 32807: return "paddle_four";
        case -32786: return "left_stick_up";
        case 32786: return "left_stick_down";
        case -32785: return "left_stick_left";
        case 32785: return "left_stick_right";
        case -32788: return "right_stick_up";
        case 32788: return "right_stick_down";
        case -32787: return "right_stick_left";
        case 32787: return "right_stick_right";
        default: return undefined;
    }
}

//
function test_keycode_strings() {
    var list = List();
    list.transfer(ListFromArray(clone_value(MOUSE_BUTTONS)));
    list.transfer(ListFromArray(clone_value(KEYBOARD_INPUTS)));
    list.transfer(ListFromArray(clone_value(GAMEPAD_BUTTONS)));
    list.transfer(ListFromArray(clone_value(GAMEPAD_AXIS)));
    list.for_each(function(k) {
        keycode_to_string(k);
    })
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
