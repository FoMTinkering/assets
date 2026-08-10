enum PathfindingAgentKind {
    Npc,
    Player,
    Animal,

    LEN
}

enum MoveAlongPathResponse {
    Ok,
    Err,
}

//
//
enum PathfindingPathErrKind {
    Npc = PathfindingAgentKind.Npc,
    Player = PathfindingAgentKind.Player,
    Animal = PathfindingAgentKind.Animal,

    NewCollision,
}

//
function PathfindingAgent(meddler) constructor {
    //
    self.meddler = meddler;
    self.itinerary = undefined;
    self.err_response = undefined;
    self.ok_response = undefined;
    self.conversion_rate = 1.0;
    self.should_reserve_squares = true;

    //
    function set_path(itinerary, simulated_distance_traveled) {
        //
        self.itinerary = itinerary;
        var itinerary_item = itinerary.items.get(itinerary.cursor);

        //
        var map_percent = simulated_distance_traveled / max(1, itinerary_item.distance);
        var count = itinerary_item.local_path.count();
        var tiles_to_remove = min(count - 2, round(count * map_percent));

        repeat tiles_to_remove {
            itinerary_item.local_path.pop();
        }

        var starting_position = itinerary_item.local_path.last();
        assert_neq(starting_position, undefined, "Starting position was undefined!");

        //
        self.conversion_rate = itinerary_item.distance / itinerary_item.local_path_distance;

        return starting_position;
    }

    //
    function todo_list() {
        return self.itinerary.items.get(self.itinerary.cursor).local_path;
    }

    //
    function raise_error(err) {
        assert_neq(self.error_handler, undefined, "This path was blocked, and no error handler was provided.");
        return self.error_handler(err);
    }

    //
    function move_along_path() {
        var todo_list = self.todo_list();
        self.ok_response = todo_list.last();

        //
        var err = self.path_check_error();
        if err != undefined {
            self.err_response = err;
            return MoveAlongPathResponse.Err;
        }

        return MoveAlongPathResponse.Ok;
    }

    //
    //
    //
    //
    //
    function onto_next_point() {
        var todo_list = self.todo_list();
        var pos = todo_list.pop();
        if self.should_reserve_squares {
            self.reserve_new_square(pos);
        }

        if todo_list.is_empty() {
            //
            return true;
        }

        return false;
    }

    //
    //
    function path_check_error() {
        //
        if self.meddler == undefined {
            return undefined;
        }

        var todo_list = self.todo_list();

        var lookahead = fiddle_get("misc/npc_behavior/pathfinding_lookahead");
        for (var i = 0; i < lookahead; i++) {
            var idx = todo_list.count() - i - 1;
            if idx < 0 {
                break;
            }
            var tile_to_do = todo_list.get(idx);

            var square_owner_kind = self.meddler.can_move_to_square(tile_to_do.x div 8, tile_to_do.y div 8);

            if square_owner_kind != undefined {
                return square_owner_kind;
            }
        }

        return undefined;
    }

    //
    function squares_to_check() {
        var todo_list = self.todo_list();

        var lookahead = fiddle_get("misc/npc_behavior/pathfinding_lookahead");
        var out = array_create(lookahead, undefined);

        for (var i = 0; i < lookahead; i++) {
            var idx = todo_list.count() - i - 1;
            if idx < 0 {
                break;
            }
            var tile_to_do = todo_list.get(idx);

            out[i] = tile_to_do;
        }

        return out;
    }

    //
    function reserve_new_square(position) {
        if self.meddler != undefined {
            self.meddler.release_reservations();
            self.meddler.reserve_new_square(position.x div 8, position.y div 8);
        }
    }

    //
    function clear_all_reservations() {
        if self.meddler != undefined {
            self.meddler.release_reservations();
        }
    }
}
