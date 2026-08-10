//
enum DirectionAngle {
    Right = 0,
    Up = 90,
    Left = 180,
    Down = 270
}

//
enum Cardinal {
    East,
    North,
    West,
    South,
    LEN
}

function cardinal_to_mat2(_cardinal) {
    static MAT2_EAST    = [1, 0, 0, 1];
    static MAT2_NORTH   = [0, -1, 1, 0];
    static MAT2_WEST    = [-1, 0, 0, -1];
    static MAT2_SOUTH   = [0, 1, -1, 0];

    switch floor(_cardinal) {
        case Cardinal.East:     return MAT2_EAST;
        case Cardinal.North:    return MAT2_NORTH;
        case Cardinal.West:     return MAT2_WEST;
        case Cardinal.South:    return MAT2_SOUTH;
        default:    impossible("Input ({}) is outside cardinal range (0..{})", _cardinal, Cardinal.LEN-1);
    }
}

function cardinal_to_inverse_mat2(_cardinal) {
    static MAT2_EAST    = [1, 0, 0, 1];
    static MAT2_NORTH   = [0, 1, -1, 0];
    static MAT2_WEST    = [-1, 0, 0, -1];
    static MAT2_SOUTH   = [0, -1, 1, 0];

    switch _cardinal {
        case Cardinal.East:     return MAT2_EAST;
        case Cardinal.North:    return MAT2_NORTH;
        case Cardinal.West:     return MAT2_WEST;
        case Cardinal.South:    return MAT2_SOUTH;
        default: impossible("unexpected cardinal {}", _cardinal);
    }
}

function angle_to_cardinal(_dir) {
    return ((_dir + 45) div 90) mod 4;
}

function cardinal_to_angle(card) {
    return card * 90;
}

function cardinal_to_radian(card) {
    return degtorad(card * 90);
}

function cardinal_to_inverse(card) {
    return (card + 2) % 4;
}

function cardinal_is_vertical(card) {
    return card == Cardinal.North || card == Cardinal.South;
}

function cardinal_is_horizontal(card) {
    return card == Cardinal.West || card == Cardinal.East;
}

function tile_get_cardinal_rotation(_tile) {
    var rot = tile_get_rotate(_tile) ? tile_rotate : 0;
    var flip = tile_get_flip(_tile) ? tile_flip : 0;
    var mirror = tile_get_mirror(_tile) ? tile_mirror : 0;
    var flag = rot | flip | mirror;
    switch(flag) {
        case tile_rotate | tile_mirror:
        case tile_rotate | tile_mirror | tile_flip:
            return 0;
        case tile_mirror:
        case tile_mirror | tile_flip:
            return 1;
        case tile_rotate:
        case tile_rotate | tile_flip:
            return 2;
        case 0:
        case tile_flip:
            return 3;
    }
}

//
function cardinal_struct_to_array(obj) {
    var o = [];
    for (var i = 0; i < Cardinal.LEN; i++) {
        o[i] = obj[$ cardinal_to_string(i)];
    }
    return o;
}

//
enum Vertical {
    North,
    South,
}
