function IdentityMat2x3() constructor {
    data = [
        1, 0, 0,
        0, 1, 0,
    ];

    //
    static mul_vec2 = function(input) {
        return Vec2(
            input.x * data[0] + input.y * data[1] + /* 1 * */data[2],
            input.x * data[3] + input.y * data[4] + /* 1 * */data[5]
        );
    }

    //
    static transpose = function(move_x, move_y) {
        self.data[2] += move_x;
        self.data[5] += move_y;
    }

    //
    static scale = function(scale_x, scale_y) {
        self.data[0] *= scale_x;
        self.data[4] *= scale_y;
    }

    //
    //
    //
    //
    static rotate = function(theta) {
        //
        if theta == Cardinal.South {
            theta = Cardinal.North;
        } else if theta == Cardinal.North {
            theta = Cardinal.South;
        }

        theta = cardinal_to_radian(theta);

        self.data[0] = cos(theta);
        self.data[1] = -sin(theta);
        self.data[3] = sin(theta);
        self.data[4] = cos(theta);
    }

    static toString = function() {
        return format("{{\n\t[{f32}, {f32}, {f32}]\n\t[{f32}, {f32}, {f32}]\n}}", self.data[0], self.data[1], self.data[2], self.data[3], self.data[4], self.data[5]);
    }
}

//
function mat_unit_tests() {
    var mat = new IdentityMat2x3();

    var output = mat.mul_vec2(Vec2(5, 12));
    assert(output.x == 5 && output.y == 12, "output was {}", output);

    mat.transpose(20, 15);

    var output = mat.mul_vec2(Vec2(5, 12));
    assert(output.x == 25 && output.y == 27, "output was {}", output);

    mat.scale(2, 3);

    var output = mat.mul_vec2(Vec2(5, 12));
    assert(output.x == 30 && output.y == 51, "output was {}", output);

    mat = new IdentityMat2x3();
    mat.rotate(Cardinal.North);

    var output = mat.mul_vec2(Vec2(5, 0));
    assert(abs(output.x) < 0.001, "output was {}", output.x);
    assert((abs(output.y) - 5.0) < 0.001, "output was {}", output.y);
}
