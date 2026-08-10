#macro PATHFINDING global.__pathfinding
global.__pathfinding = undefined;

//
function Pathfinding() constructor {
    reservations = Map();

    //
    function initialize_local_grid() {
        //
        hyperpath_init_local_pathfinding(GRID.dims.x, GRID.dims.y);

        //
        for (var i = 0; i < GRID.dims.x; i++) {
            for (var j = 0; j < GRID.dims.y; j++) {
                var ni = GRID.node_index_for_cell(i, j);

                var is_taken = false;
                if GRID.node_collideable[ni] {
                    is_taken = true;
                }
                if GRID.node_pathfinding_sitting[ni] {
                    is_taken = false;
                }

                self.set_local_position_is_taken(i, j, is_taken);

                var value = GRID.node_pathfinding_cost[ni];
                if value != undefined  && value != 0 {
                    self.set_local_position_cost(i, j, value);
                }
            }
        }

        //
        hyperpath_surround_taken_tiles_with_bad_tiles(10);
    }

    //
    function enable_simple_pathfinding() {
        //
        for (var i = 0; i < GRID.dims.x; i++) {
            for (var j = 0; j < GRID.dims.y; j++) {
                var ni = GRID.node_index_for_cell(i, j);
                var value = GRID.node_pathfinding_cost[ni];
                if value != undefined  && value != 0 {
                    self.set_local_position_cost(i, j, 1);
                }
            }
        }

        hyperpath_surround_taken_tiles_with_bad_tiles(10);
    }

    //
    function calculate_local_path(start_x, start_y, dest_x, dest_y, quiet=false) {
        var output_list = List();
        self.last_error = undefined;

        //
        var output = hyperpath_calculate_local_path(start_x, start_y, dest_x, dest_y);

        if is_array(output) {
            var distance = output[0];

            //
            for (var i = 1; i < array_length(output); i+=2) {
                output_list.push(Vec2(output[i], output[i + 1]));
            }

            //
            //
            //
            if array_length(output) == 1 {
                output_list.push(Vec2(dest_x, dest_y));
            }

            //
            //
            var last = output_list.last();
            if last.x != dest_x || last.y != dest_y {
                output_list.push(Vec2(dest_x, dest_y));
            }

            //
            output_list.set_reverse();

            return {
                output_list,
                distance,
            }
        } else {
            if quiet == false {
                warn(
                    "Failed to calculate a path: {PathfindErr}. \nPosition: {}x{} to {}x{}\nTiles: {}x{} -> {}x{}\nIs Taken: Target: {}",
                    output,
                    start_x,
                    start_y,
                    dest_x,
                    dest_y,
                    start_x div 8,
                    start_y div 8,
                    dest_x div 8,
                    dest_y div 8,
                    self.get_local_position_is_taken(dest_x div 8, dest_y div 8),
                );
            }
            self.last_error = output;
        }
    }

    function calculate_map_path(start_location, end_location) {
        //
        var output;
        try {
            output = hyperpath_calculate_map_path(
                location_id_to_string(start_location.location_id),
                location_id_to_string(end_location.location_id),
                start_location.pos.x,
                start_location.pos.y,
                end_location.pos.x,
                end_location.pos.y
            );
        } catch(e) {
            error(
                "from {LocationId}::{}x{} -> {LocationId}::{}x{}",
                start_location.location_id,
                start_location.pos.x,
                start_location.pos.y,
                end_location.location_id,
                end_location.pos.x,
                end_location.pos.y,
            );

            crash(e);
        }

        //
        var sub_paths = List();

        if array_length(output.paths) == 0 {
            sub_paths.push(new ItineraryItem(start_location, end_location, 0));
        } else {
            for (var i = 0; i < array_length(output.paths); i++) {
                var path = output.paths[i];
                var loc = string_to_location_id(path.location);
                var start_loc_pos = new LocationPosition(
                    loc,
                    Vec2(path.start[0], path.start[1])
                );
                var end_loc_pos = new LocationPosition(
                    loc,
                    Vec2(path.destination[0], path.destination[1])
                );
                sub_paths.push(new ItineraryItem(start_loc_pos, end_loc_pos, path.distance));
            }
        }

        return new Itinerary(sub_paths);
    }

    //
    function set_local_position_is_taken(xx, yy, is_taken) {
        hyperpath_set_local_position_is_taken(
            xx,
            yy,
            is_taken,
        );
    }

    //
    function get_local_position_is_taken(xx, yy) {
        return hyperpath_local_position_is_taken(xx, yy);
    }

    //
    function set_local_position_cost(xx, yy, cost) {
        hyperpath_set_local_position_cost(
            xx,
            yy,
            cost,
        );
    }

    //
    function get_local_position_cost(xx, yy) {
        return hyperpath_local_position_cost(xx, yy);
    }

    function reserve(sqr_idx, meddler) {
        self.reservations.set(sqr_idx, meddler);
    }

    function reservation(square) {
        return self.reservations.get(square);
    }

    function release_reservation(sqr_idx, meddler) {
        var current = self.reservations.get(sqr_idx);
        if current == undefined || current.id == meddler.id {
            self.reservations.remove(sqr_idx);
            return true;
        } else {
            return false;
        }
    }

    //
    function on_room_start() {
        self.initialize_local_grid();
        self.reservations.clear();
    }
}

//
function Itinerary(items) constructor {
    self.items = items;
    self.cursor = 0;

    //
    //
    function advance_path() {
        if self.on_last_item() {
            return self.items.get(self.cursor).target_location.clone();
        } else {
            self.cursor++;
            return self.items.get(self.cursor).start_location.clone();
        }
    }

    //
    function current_item() {
        return self.items.get(self.cursor);
    }

    //
    function on_last_item() {
        return self.cursor + 1 == self.items.count();
    }
}

//
//
function ItineraryItem(start_location, target_location, distance, local_path=undefined) constructor {
    self.start_location = start_location;
    self.target_location = target_location;
    self.distance = distance;
    self.local_path = local_path;
    self.local_path_distance = 0;
}
