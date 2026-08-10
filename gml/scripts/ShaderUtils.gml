#macro STENCIL_VALUE global.__stencil_value
STENCIL_VALUE = 0;

enum UberShaderKind {
    Normal = 0,
    Flat = 1,
    Overlay = 2,
    OverlayCorrect = 3,
    WindowFill = 4,
    Animal = 5,
    PaletteSwap = 6,
    PlayerFinal = 7,
    Premultiply = 8,
    Light = 9,
    AnchorSprite = 10,
    AnchorText = 11,
    DayNight = 12,
    Sepia = 13,
    StarPunchOut = 14,
    Circle = 15,
    NoSrgb = 16,
    NormalPostPost = 17,
}

function gpu_reset_extra() {
    gpu_set_extra(UberShaderKind.Normal);
}

enum NodeDrawFlag {
    EMPTY = 0,
    PERFORMING_TRANSPARENCY = 1 << 0,
    PERFORMING_PREPASS = 1 << 1,
}

//
//
//
function blend_rgb32(lhs, rhs, amount) {
    var output = [0, 0, 0];

    for (var i = 0; i < 3; i++) {
        output[i] = lerp(lhs[i], rhs[i], amount);
    }

    return output;
}

//
//
//
function blend_rgba32(lhs, rhs, amount) {
    var output = [0, 0, 0, 0];

    for (var i = 0; i < 4; i++) {
        output[i] = lerp(lhs[i], rhs[i], amount);
    }

    return output;
}

function stencil_next() {
    return (STENCIL_VALUE + 1) % 256;
}

//
function stencil_increment() {
    var output = STENCIL_VALUE;
    STENCIL_VALUE += 1;

    if STENCIL_VALUE >= 256 {
        STENCIL_VALUE = 1;
        draw_clear_stencil(0);
    }

    return STENCIL_VALUE
}

//
//
//
//
function stencil_reserve_band(amount) {
    var output = STENCIL_VALUE;

    if (STENCIL_VALUE + amount) >= 255 {
        STENCIL_VALUE = 0;
        draw_clear_stencil(0);
    }

    //
    STENCIL_VALUE += amount;

    return STENCIL_VALUE
}
