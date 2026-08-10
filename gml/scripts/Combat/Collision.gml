//
enum MovementCollisionDirection {
    NONE,
    HORIZONTAL = 1 << 0,
    VERTICAL = 1 << 1,
}

//
//
//
//
function setup_move_and_collide(slippery=0.1) {
    self.check_collision = function(xx, yy) {
        var ni = GRID.try_node_index_for_room_position(xx, yy);

        return ni == undefined || GRID.node_collideable[ni];
    }

    //
    self.move = Vec2();
    self.slip_move = Vec2();
    self.slippery_coefficient = slippery;
}

//
//
//
function movement_and_collide() {
    var ret = MovementCollisionDirection.NONE;

    var x_frac = frac(x);
    var y_frac = frac(y);

    var movement_x = self.move.x;
    var movement_y = self.move.y;

    //
    //
    if movement_x != 0.0 {
        //
        var signum = sign(movement_x);
        var pt = x_frac + ((signum > 0.0) ? bbox_right : bbox_left);
        //
        //
        if self.check_collision(pt + movement_x, bbox_top) || self.check_collision(pt + movement_x, bbox_bottom) {
            ret = set_flag(ret, MovementCollisionDirection.HORIZONTAL);
            var amt = abs(movement_x);
            repeat amt {
                pt = x_frac + ((signum > 0.0) ? bbox_right : bbox_left);
                if self.check_collision(pt + signum, bbox_top) || self.check_collision(pt + signum, bbox_bottom) {
                    //
                    break;
                }
                x += signum;
            }
            //
        } else {
            x += movement_x;
        }
    }

    //
    if movement_y != 0.0 {
        //
        //
        var signum = sign(movement_y);
        var pt = y_frac + ((signum > 0.0) ? bbox_bottom : bbox_top);
        if self.check_collision(bbox_left + x_frac, pt + movement_y) || self.check_collision(bbox_right + x_frac, pt + movement_y) {
            ret = set_flag(ret, MovementCollisionDirection.VERTICAL);
            var amt = abs(movement_y);
            movement_y = 0;
            repeat amt {
                pt = y_frac + ((signum > 0.0) ? bbox_bottom : bbox_top);
                if self.check_collision(bbox_left + x_frac, pt + signum) || self.check_collision(bbox_right + x_frac, pt + signum) {
                    break;
                }
                y += signum;
                //
            }
            //
        } else {
            y += movement_y;
        }
    }

    //
    self.move.x = 0;
    self.move.y = 0;

    return ret;
}

function setup_friction() {
    //
    friction_coefficient = 0.1;
}

function apply_friction() {
    self.move.x = lerp(self.move.x, 0.0, self.friction_coefficient);
    self.move.y = lerp(self.move.y, 0.0, self.friction_coefficient);
}

function apply_slippery_vertical(movement_y) {
    //
    if abs(movement_y) < self.slippery_coefficient {
        if sign(movement_y) == -1.0 && !self.check_collision(x, bbox_top - OBJECT_CELL_SIZE) {
            movement_y -= self.slippery_coefficient;
        } else if sign(movement_y) == 1.0 && !self.check_collision(x, bbox_bottom + OBJECT_CELL_SIZE) {
            movement_y += self.slippery_coefficient;
        }
    }
    return movement_y;
}

function apply_slippery_horizontal(movement_x) {
    //
    if abs(movement_x) < slippery_coefficient {
        if sign(movement_x) == -1.0 && !self.check_collision(bbox_left - OBJECT_CELL_SIZE, y) {
            movement_x -= slippery_coefficient;
        } else if sign(movement_x) == 1.0 && !self.check_collision(bbox_right + OBJECT_CELL_SIZE, y) {
            movement_x += slippery_coefficient;
        }
    }
    return movement_x;
}

function setup_push() {
    self.allow_shoving = true;
    self.shove_factor = 1;
}

function push_and_shove(obj, radius, force) {
    static LIST = ds_list_create();

    ds_list_clear(LIST);
    var count = collision_circle_list(self.x, self.y, radius, obj, LIST);
    for (var i = 0; i < count; i++) {
        var inst = LIST[| i];
        if inst == self {
            continue;
        }
        var me_to_them = point_direction(self.x, self.y, inst.x, inst.y);
        var them_to_me = point_direction(inst.x, inst.y, self.x, self.y);
        if self.allow_shoving {
            self.move.x += lengthdir_x(force, them_to_me) * inst.shove_factor;
            self.move.y += lengthdir_y(force, them_to_me) * inst.shove_factor;
        }
        if inst.allow_shoving {
            inst.move.x += lengthdir_x(force, me_to_them) * self.shove_factor;
            inst.move.y += lengthdir_y(force, me_to_them) * self.shove_factor;
        }
    }
}

function push_from(obj, radius, force) {
    var count = instance_number(obj);
    for (var i = 0; i < count; i++) {
        var inst = instance_find(obj, i);
        if collision_circle(self.x, self.y, radius, inst) {
            var them_to_me = point_direction(inst.x, inst.y, self.x, self.y);
            if self.allow_shoving {
                self.move.x += lengthdir_x(force, them_to_me);
                self.move.y += lengthdir_y(force, them_to_me);
            }
        }
    }
}
