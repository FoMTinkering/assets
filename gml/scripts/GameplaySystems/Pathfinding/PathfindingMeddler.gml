function PathfindingMeddler(agent_kind, owner) constructor {
    static ID_GENERATOR = 0;

    self.size = agent_kind == PathfindingAgentKind.Player ? 1 : 0;
    self.held_squares = array_create(self.size * 8 + 1, undefined);
    self.last_pos = Vec2(-1, -1);
    self.agent_kind = agent_kind;
    self.owner = owner;

    self.id = ID_GENERATOR;
    ID_GENERATOR += 1;

    function release_reservations() {
        for (var i = 0, c = array_length(self.held_squares); i < c; i++) {
            var square = self.held_squares[i];

            if square != undefined {
                PATHFINDING.release_reservation(square, self);
            }
        }
    }

    function can_move_to_square(xx, yy) {
        for (var x_mod = -self.size; x_mod <= self.size; x_mod++) {
            for (var y_mod = -self.size; y_mod <= self.size; y_mod++) {
                var ni = GRID.try_node_index_for_cell(xx + x_mod, yy + y_mod);

                var current_reservation_meddler = PATHFINDING.reservation(ni);
                if current_reservation_meddler != undefined && current_reservation_meddler.id != self.id {
                    //
                    return current_reservation_meddler.agent_kind;
                }

                if self.agent_kind == PathfindingAgentKind.Animal
                    && ni != undefined
                    && GRID.node_collideable[ni]
                {
                    return PathfindingPathErrKind.NewCollision;
                }
            }
        }

        return undefined;
    }

    function reserve_new_square(xx, yy) {
        var idx = 0;

        for (var x_mod = -self.size; x_mod <= self.size; x_mod++) {
            for (var y_mod = -self.size; y_mod <= self.size; y_mod++) {
                self.held_squares[idx] = (xx + x_mod) + (yy + y_mod) * GRID.dims.x;
                idx += 1;
            }
        }

        //
        for (var i = 0, c = array_length(self.held_squares); i < c; i++) {
            PATHFINDING.reserve(self.held_squares[i], self);
        }
    }

    //
    function update(xx, yy) {
        xx = xx div 8;
        yy = yy div 8;

        if self.last_pos.x == xx && self.last_pos.y == yy {
            return;
        }

        self.last_pos.x = xx;
        self.last_pos.y = yy;

        self.release_reservations();
        self.reserve_new_square(xx, yy);
    }
}
