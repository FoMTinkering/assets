function ds_grid_find_value_random(grid, value, padding) {
    var width = ds_grid_width(grid);
    var height = ds_grid_height(grid);
    var count = 0;
    var xx = 0;
    var yy = 0;
    while true {
        ++count;
        if count > 10000 {
            return undefined;
        }
        xx = irandom(width - 1);
        yy = irandom(height - 1);
        if padding == undefined {
            if grid[# xx, yy] == value {
                break;
            }
        } else {
            var out_break = true;
            var xbound = min(ds_grid_width(grid) - 1, xx + padding);
            var ybound = min(ds_grid_height(grid) - 1, yy + padding);
            for (var i = max(0, xx - padding); i <= xbound; i++) {
                for (var j = max(0, yy - padding); j <= ybound; j++) {
                    if grid[# i, j] != value {
                        out_break = false;
                        break;
                    }
                }
            }
            if out_break {
                break;
            }
        }
    }
    return Vec2(xx, yy);
}
