//
//
function find_free_position_spiral(xx, yy, is_valid, params, spiral_count=32) {
    //
    if is_valid(xx, yy, params) {
        //
        return Vec2(xx, yy);
    } else {
        //
        var cells_to_check = 0;
        for (var i = 0, next_loop = 8; i < spiral_count; i++) {
            cells_to_check += next_loop * i;
        }

        //
        var dir = 0, cells_travelled = 0, cells_to_travel = 0, turn_rep = 0;
        for (var i = 0; i < cells_to_check; i++) {
            //
            xx += lengthdir_x(1, dir);
            yy += lengthdir_y(1, dir);
            if is_valid(xx, yy, params) {
                //
                return Vec2(xx, yy);
            }

            //
            cells_travelled++;
            if cells_travelled > cells_to_travel {
                cells_travelled = 0;
                dir += 90;

                //
                //
                turn_rep++;
                if turn_rep == 2 {
                    turn_rep = 0;
                    cells_to_travel++;
                }
            }
        }
        return undefined;
    }
}


//
//
function check_cell_free(xx, yy) {
    var ni = GRID.node_index_for_cell(xx, yy);

    return GRID.node_object_id[ni] == undefined && GRID.node_collideable[ni] == false;
}
