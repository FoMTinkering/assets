function Vec4(_x1, _y1, _x2, _y2) {
    _x1 = _x1 == undefined ? 0 : _x1;
    _y1 = _y1 == undefined ? 0 : _y1;
    _x2 = _x2 == undefined ? 0 : _x2;
    _y2 = _y2 == undefined ? 0 : _y2;
    return new __Vec4(_x1, _y1, _x2, _y2);
}

function Vec4Zero() {
    return new __Vec4(0, 0, 0, 0);
}

function __Vec4(_x1, _y1, _x2, _y2) constructor {
    x1 = _x1;
    y1 = _y1;

    x2 = _x2;
    y2 = _y2;

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
    static as_vec2 = function() {
        return Vec2(x1, y1);
    }

    //
    //
    static as_vec2_front = as_vec2;

    //
    static left = function() {
        return self.x1;
    }

    static top = function() {
        return self.y1;
    }

    static right = function() {
        return self.x2;
    }

    static bottom = function() {
        return self.y2;
    }

    static center = function() {
        return Vec2(
            self.x1 + (self.x2 - self.x1) / 2,
            self.y1 + (self.y2 - self.y1) / 2,
        );
    }

    //
    static r = function() {
        return self.x1;
    }

    static g = function() {
        return self.y1;
    }

    static b = function() {
        return self.x2;
    }

    static a = function() {
        return self.y2;
    }

    static toString = function() {
        return format(
            "({}x{}, {}x{})",
            self.x1,
            self.y1,
            self.x2,
            self.y2,
        );
    }
}
