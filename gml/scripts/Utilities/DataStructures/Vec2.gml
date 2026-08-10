function Vec2(_x = 0, _y = 0) {
    return new __Vec2(_x, _y);
}

function Vec2Zero() {
    return new __Vec2(0, 0);
}

function Vec2Object(_obj) {
    return new __Vec2(_obj.x, _obj.y);
}

function __Vec2(_x, _y) constructor {
    x = _x;
    y = _y;

    //
    //
    static set_to_obj = function(_obj) {
        _obj.x = self.x;
        _obj.y = self.y;
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
    static set = function(_o) {
        self.x = _o.x;
        self.y = _o.y;
    }

    //
    static splat = function(value) {
        self.x = value;
        self.y = value;
    }

    //
    static clone = function() {
        return new __Vec2(self.x, self.y);
    }


    //
    //
    //
    //
    //
    //
    //
    //
    static eq = function(_o) {
        if (_o == undefined) {
            return false;
        }
        return _o.x == self.x && _o.y == self.y;
    }

    //
    //
    //
    //
    //
    //
    static eq_floored = function(_o) {
        if (_o == undefined) {
            return false;
        }
        return floor(_o.x) == floor(self.x) && floor(_o.y) == floor(self.y);
    }

    //
    //
    //
    //
    //
    //
    static scale = function(_scalar) {
        return Vec2(self.x * _scalar, self.y * _scalar);
    }

    //
    //
    //
    //
    //
    //
    static div_by = function(_scalar) {
        return Vec2(self.x div _scalar, self.y div _scalar);
    }

    //
    //
    //
    //
    //
    //
    //
    //
    static set_scale = function(_scalar) {
        self.x *= _scalar;
        self.y *= _scalar;
    }


    //
    //
    //
    //
    //
    //
    //
    static add = function(_o) {
        return new __Vec2(self.x + _o.x, self.y + _o.y);
    }

    //
    //
    //
    //
    //
    //
    //
    //
    static set_add = function(_o) {
        self.x += _o.x;
        self.y += _o.y;
    }

    //
    //
    //
    //
    //
    //
    //
    static sub = function(_o) {
        return new __Vec2(self.x - _o.x, self.y - _o.y);
    }

    //
    //
    //
    //
    //
    //
    //
    //
    static set_sub = function(_o) {
        self.x -= _o.x;
        self.y -= _o.y;
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
    static multip = function(_o) {
        return new __Vec2(self.x * _o.x, self.y * _o.y);
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
    static set_multip = function(_o) {
        self.x *= _o.x;
        self.y *= _o.y;
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
    static round_up = function() {
        return Vec2(ceil(self.x), ceil(self.y));
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
    static set_round_up = function() {
        self.x = ceil(self.x);
        self.y = ceil(self.y);
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
    static sqrd_magnitude = function() {
        return self.dot(self);
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
    static normalize = function(set_point=1.0) {
        var sqrd_magnitude_rcp = set_point / sqrt(self.sqrd_magnitude());
        return self.scale(sqrd_magnitude_rcp);
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
    static normalized = function(set_point=1.0) {
        var sqrd_magnitude_rcp = set_point / sqrt(self.sqrd_magnitude());
        self.set_scale(sqrd_magnitude_rcp);
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
    static dot = function(_o) {
        return self.x * _o.x + self.y * _o.y;
    }

    //
    static perpendicular = function() {
        return Vec2(self.y, -self.x);
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
    static cardinality_lossy = function() {
        if (self.x > 0) {
            return Cardinal.East;
        } else if (self.y > 0) {
            return Cardinal.South;
        } else if (self.x < 0) {
            return Cardinal.West;
        } else if (self.y < 0) {
            return Cardinal.North;
        } else {
            //
            return Cardinal.South;
        }
    }

    //
    //
    //
    static cardinality_heuristic = function() {
        switch sign(self.x) {
            case 0: switch sign(self.y) {
                case 0: return Cardinal.South;
                case 1: return Cardinal.South;
                case -1: return Cardinal.North;
            }
            case 1: return Cardinal.East;
            case -1: return Cardinal.West;
        }
    }

    //
    //
    //
    static to_dir = function() {
        return arctan2(self.y, self.x);
    }

    //
    //
    //
    static to_dir_degree = function() {
        return (360 - darctan2(self.y, self.x)) % 360;
    }

    //
    //
    //
    static to_cardinal = function() {
        return angle_to_cardinal(self.to_dir_degree());
    }

    //
    static rotate = function(rot_matrix) {
        return new __Vec2(self.x * rot_matrix[0] + self.y * rot_matrix[2], self.x * rot_matrix[1] + self.y * rot_matrix[3]);
    }
    //
    static set_rotate = function(rot_matrix) {
        var _newx = self.x * rot_matrix[0] + self.y * rot_matrix[2];
        var _newy = self.x * rot_matrix[1] + self.y * rot_matrix[3];
        self.x = _newx;
        self.y = _newy;
    }

    //
    static is_zero = function() {
        return self.x == 0 && self.y == 0;
    }

    //
    static set_zero = function() {
        self.x = 0;
        self.y = 0;
    }

    static set_val = function(_x, _y) {
        self.x = _x;
        self.y = _y;
    }

    static toString = function() {
        return "(" + string_format(self.x, 0, 2) + ", " + string_format(self.y, 0, 2) + ")";
    }
}
