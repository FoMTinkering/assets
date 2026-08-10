//
//
//
function Pilot() constructor {
    self.map = [[]];
    self.newline_requested = false;
    self.position = Vec2Zero();
    self.placement_cursor = Vec2Zero();
    self.pilot_neighbors = [undefined, undefined, undefined, undefined];
    self.tap_on_hover_flag = false;
    self.overflow_behaviors = [
        PilotOverflowBehavior.Freeze,
        PilotOverflowBehavior.Freeze,
        PilotOverflowBehavior.Freeze,
        PilotOverflowBehavior.Freeze,
    ];

    //
    function reset() {
        for (var i = 0; i < array_length(self.map); i++) {
            for (var j = 0; j < array_length(self.map[i]); j++) {
                var node = self.map[i][j];
                if node != undefined {
                    node.pilot = undefined;
                }
            }
        }
        self.map = [[]];
        self.goto_default();
        self.placement_cursor = Vec2Zero();
        self.newline_requested = false;
    }

    function is_empty() {
        return array_length(self.map) == 1 && array_length(self.map[0]) == 0;
    }

    function has_any_eligible_nodes() {
        for (var i = 0; i < array_length(self.map); i++) {
            var row = self.map[i];
            for (var j = 0; j < array_length(row); j++) {
                var node = row[j];
                if node != undefined && node.is_unlocked() {
                    return true;
                }
            }
        }
        return false;
    }

    //
    function add(node) {
        if self.newline_requested {
            self.placement_cursor.y += 1;
            self.placement_cursor.x = 0;
            array_push(self.map, []);
            self.newline_requested = false;
        }
        array_push(self.map[self.placement_cursor.y], node);
        self.placement_cursor.x += 1;
        return self;
    }

    //
    //
    //
    function add_empty() {
        self.add(undefined);
        return self;
    }

    //
    //
    //
    //
    function request_newline() {
        self.newline_requested = true;
        return self;
    }

    //
    function return_to_row(row) {
        assert(row < array_length(self.map), "Tried to return to row {}, but there are only {} rows!");
        self.placement_cursor.y = row;
    }

    //
    function get() {
        if !self.position_is_valid(self.position.x, self.position.y) {
            return undefined;
        }
        return self.map[self.position.y][self.position.x];
    }

    //
    function get_position() {
        return self.position.clone();
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
    function position_for_approach(source_node, source_position, card) {
        //
        if !self.has_any_eligible_nodes() {
            return undefined;
        }

        //
        var node_position = ANCHOR.get_screen_position(source_node);

        //
        var best_delta = Vec2(I32_MAX, I32_MAX);
        var selected_position = clone_value(source_position);
        for (var yy = 0; yy < array_length(self.map); yy++) {
            for (var xx = 0; xx < array_length(self.map[yy]); xx++) {
                if !self.position_is_valid(xx, yy) {
                    continue;
                }

                //
                //
                var node = self.map[yy][xx];
                var this_node_position = ANCHOR.get_screen_position(node);
                var delta = Vec2(
                    abs(node_position.x - this_node_position.x),
                    abs(node_position.y - this_node_position.y),
                );

                //
                if delta.x < best_delta.x {
                    best_delta.x = delta.x;
                    selected_position.x = xx;
                }

                //
                if delta.y < best_delta.y {
                    best_delta.y = delta.y;
                    selected_position.y = yy;
                }
            }
        }

        //
        var xx = selected_position.x;
        var yy = selected_position.y;
        yy = clamp(yy, 0, array_length(self.map) - 1);
        xx = clamp(xx, 0, array_length(self.map[yy]) - 1);

        //
        switch card {
            case Cardinal.East:
                xx = 0;
                break;
            case Cardinal.West:
                xx = array_length(self.map[yy]) - 1;
                break;
            case Cardinal.North:
                yy = array_length(self.map) - 1;
                break;
            case Cardinal.South:
                yy = 0;
                break;
        }

        //
        //
        //
        //
        var original_xx = xx;
        var original_yy = yy;
        var move_horizontally = matches(card, Cardinal.East, Cardinal.West);
        var move_vertically = !move_horizontally;
        var move_y = move_horizontally ? 0 : -1;
        var move_x = move_vertically ? 0 : -1;
        while !self.position_is_valid(xx, yy) {
            yy = wrap(yy + move_y, array_length(self.map));
            xx = wrap(xx + move_x, array_length(self.map[yy]));

            //
            //
            if move_horizontally && xx == original_xx {
                var sig = card == Cardinal.North ? -1 : 1;
                yy = wrap(yy + sig, array_length(self.map));
            }

            //
            if move_vertically && yy == original_yy {
                var sig = card == Cardinal.West ? -1 : 1;
                xx = wrap(xx + sig, array_length(self.map));
            }

        }

        return Vec2(xx, yy);
    }

    //
    function set_position(xx, yy) {
        assert(self.position_is_valid(xx, yy), "Tried to set the pilot to an invalid position: {}x{}", xx, yy);
        self.position.x = xx;
        self.position.y = yy;
    }

    //
    function try_force_select(node) {
        for (var i = 0; i < array_length(self.map); i++) {
            for (var j = 0; j < array_length(self.map[i]); j++) {
                if self.map[i][j] == node {
                    self.position.x = j;
                    self.position.y = i;
                    if !node.is_hovered() {
                        ANCHOR.hover_node(node);
                    }
                    return true;
                }
            }
        }
        return false;
    }

    //
    function select_at_index_clamped(row) {
        self.force_select(self.map[clamp(row, 0, array_length(self.map) - 1)][0]);
    }

    //
    function force_select(node) {
        assert(self.try_force_select(node), "Node '{AnchorNode}' did not appear in the pilot!", node);
    }

    //
    //
    function set_neighbor(pilot, dir) {
        self.overflow_behaviors[dir] = PilotOverflowBehavior.SwapPilot;
        self.pilot_neighbors[dir] = pilot;
        return self;
    }

    //
    //
    function allow_vertical_wrapping() {
        self.overflow_behaviors[Cardinal.North] = PilotOverflowBehavior.Wrap;
        self.overflow_behaviors[Cardinal.South] = PilotOverflowBehavior.Wrap;
        return self;
    }

    //
    //
    function allow_horizontal_wrapping() {
        self.overflow_behaviors[Cardinal.East] = PilotOverflowBehavior.Wrap;
        self.overflow_behaviors[Cardinal.West] = PilotOverflowBehavior.Wrap;
        return self;
    }

    //
    function tap_on_hover(boo=true) {
        self.tap_on_hover_flag = boo;
        return self;
    }

    //
    //
    //
    //
    function position_is_valid(xx, yy) {
        if xx < 0 || yy < 0 || array_length(self.map) <= yy || array_length(self.map[yy]) <= xx {
            return false;
        }
        var node = self.map[yy][xx];
        if node == undefined {
            return false;
        }
        return node.safe_unlocked; //
    }

    //
    //
    function goto_default() {
        self.position.x = 0;
        self.position.y = 0;
    }

    //
    //
    function find_first_acceptable_node(xx, yy, dir) {
        if !self.has_any_eligible_nodes() {
            return PilotMovementReturn.Freeze;
        }
        while true {
            switch dir {
                case Cardinal.West:
                    var should_wrap = xx - 1 < 0;
                    var wrap_pos_x = array_length(self.map[yy]) - 1;
                    var wrap_pos_y = yy;
                    var move_pos_x = xx - 1;
                    var move_pos_y = yy;
                    break;
                case Cardinal.East:
                    var should_wrap = xx + 1 >= array_length(self.map[yy]);
                    var wrap_pos_x = 0;
                    var wrap_pos_y = yy;
                    var move_pos_x = xx + 1;
                    var move_pos_y = yy;
                    break;
                case Cardinal.North:
                    var should_wrap = yy - 1 < 0;
                    var wrap_pos_x = xx;
                    var wrap_pos_y = array_length(self.map) - 1;
                    var move_pos_x = xx;
                    var move_pos_y = yy - 1;
                    break;
                case Cardinal.South:
                    var should_wrap = yy + 1 >= array_length(self.map);
                    var wrap_pos_x = xx;
                    var wrap_pos_y = 0;
                    var move_pos_x = xx;
                    var move_pos_y = yy + 1;
                    break;
            }
            if should_wrap {
                switch self.overflow_behaviors[dir] {
                    case PilotOverflowBehavior.Freeze: return PilotMovementReturn.Freeze;
                    case PilotOverflowBehavior.Wrap:
                        if wrap_pos_x == xx && wrap_pos_y == yy {
                            return PilotMovementReturn.Freeze;
                        }

                        //
                        if self.position_is_valid(wrap_pos_x, wrap_pos_y) {
                            return PilotMovementReturn.Movement(wrap_pos_x, wrap_pos_y);
                        }

                        //
                        return self.find_first_acceptable_node(wrap_pos_x, wrap_pos_y, dir);
                    case PilotOverflowBehavior.SwapPilot:
                        //
                        var target_pilot = self.pilot_neighbors[dir];
                        if target_pilot.has_any_eligible_nodes() {
                            var position = target_pilot.position_for_approach(self.get(), self.position, dir);
                            return PilotMovementReturn.SwapPilot(target_pilot, position.x, position.y);
                        } else {
                            return PilotMovementReturn.Freeze;
                        }
                    default: impossible("Unexpected {PilotOverflowBehavior}", self.overflow_behaviors[dir]);
                }
            } else {
                move_pos_y = clamp(move_pos_y, 0, array_length(self.map) - 1);
                move_pos_x = clamp(move_pos_x, 0, array_length(self.map[move_pos_y]) - 1);
                if self.position_is_valid(move_pos_x, move_pos_y) {
                    return PilotMovementReturn.Movement(move_pos_x, move_pos_y);
                } else {
                    //
                    //
                    //
                    //
                    if dir == Cardinal.North || dir == Cardinal.South {
                        //
                        var maybe_x = clamp(move_pos_x - 1, 0, array_length(self.map[move_pos_y]) - 1);
                        if self.position_is_valid(maybe_x, move_pos_y) {
                            return PilotMovementReturn.Movement(maybe_x, move_pos_y);
                        }

                        //
                        var maybe_x = clamp(move_pos_x + 1, 0, array_length(self.map[move_pos_y]) - 1);
                        if self.position_is_valid(maybe_x, move_pos_y) {
                            return PilotMovementReturn.Movement(maybe_x, move_pos_y);
                        }

                    }
                    //
                    xx = move_pos_x;
                    yy = move_pos_y;
                }
            }
        }
    }
}

enum PilotOverflowBehavior {
    Freeze,
    Wrap,
    SwapPilot,
}

enum PilotMovementReturnType {
    Movement,
    SwapPilot,
    Freeze,
}

function PilotMovementReturnFactory() constructor {
    static Movement = function(xx, yy) {
        return {
            type: PilotMovementReturnType.Movement,
            xx: xx,
            yy: yy,
        }
    }
    static SwapPilot = function(pilot, xx, yy) {
        return {
            type: PilotMovementReturnType.SwapPilot,
            pilot: pilot,
            x: xx,
            y: yy,
        }
    }
    static Freeze = {
        type: PilotMovementReturnType.Freeze,
    }
}

global.__pilot_movement_return_factory = new PilotMovementReturnFactory();
#macro PilotMovementReturn global.__pilot_movement_return_factory
