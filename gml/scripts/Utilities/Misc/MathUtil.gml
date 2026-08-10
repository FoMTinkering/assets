enum Ordering {
    LessThan = -1,
    Equal = 0,
    GreaterThan = 1,
}

enum Signum {
    Positive,
    Negative,
    Zero
}

//
//
//
//
function cmp(lhs, rhs) {
    var output = lhs - rhs;

    switch (signum(output)) {
        case Signum.Negative:
            return Ordering.LessThan;
        case Signum.Positive:
            return Ordering.GreaterThan;
        case Signum.Zero:
            return Ordering.Equal;
    }
}

//
function signum(value) {
    switch (sign(value)) {
        case -1:
            return Signum.Negative;
        case 1:
            return Signum.Positive;
        default:
            return Signum.Zero;
    }
}

function degrees_to_radians(degrees) {
    return degrees * (pi / 180);
}

function is_between(_n, _min, _max) {
    return _n > _min && _n < _max;
}

function is_between_inclusive(_n, _min, _max) {
    return _n >= _min && _n <= _max;
}

//
//
//
//
//
function asymptotic_motion(current_pos, position_to_move_to, weight) {
    return (1 - weight) * current_pos + (weight * position_to_move_to);
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
function approach(val, target, maxMove) {
    return val > target ? max(val - maxMove, target) : min(val + maxMove, target);
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
function wrap(_val, _max, _min=0) {
    var _mod = (_val - _min) mod (_max - _min);
    return _mod + _max * (_mod < 0) + _min * !(_mod < 0);
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
function inverse_lerp(value, end, start) {
    var numerator = value - start;
    var denominator = end - start;

    return numerator / denominator;
}

function towards_signed_infinity(numb) {
    if sign(numb) == 1 {
        return ceil(numb);
    } else {
        return floor(numb);
    }
}

//
function gcd(a, b) {
    if b == 0 {
        return a;
    }

    return gcd(b, a % b);
}

//
function lcm(a, b, known_gcd) {
    if known_gcd == undefined {
        known_gcd = gcd(a, b);
    }
    return (a / known_gcd) * b;
}
