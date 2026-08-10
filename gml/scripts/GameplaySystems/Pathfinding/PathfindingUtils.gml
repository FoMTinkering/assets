//
function pathfinding_util_get_itinerary() {
    //
    var diff = self.owner.me.location_position.pos.sub(self.owner);
    var sqrd_magnitude = diff.sqrd_magnitude();

    if sqrd_magnitude > 2 {
        error(
            "{NpcId} Database mismatch\nInstance was at: {}\nData was at: {}",
            self.owner.npc_id,
            Vec2(self.owner.x, self.owner.y),
            self.owner.me.location_position,
        );

        if DEBUG_ASSERTIONS {
            crash("Database mismatch for {NpcId}", self.owner.npc_id);
        }
    }

    assert_eq(
        self.owner.me.location_position.location_id,
        CURRENT_LOCATION_ID,
        "Location database mismatch for {NpcId}. Database: {}",
        self.owner.debug_name,
        self.owner.me.location_position,
    )

    //
    return self.owner.me.itinerary;
}

//
function pathfinding_util_create_local_path(itinerary, owner, recreate_path=true, snap_pos=true) {
    //
    var itinerary_item = itinerary.items.get(itinerary.cursor);
    //
    if itinerary_item.local_path == undefined || recreate_path {
        var new_path_data = PATHFINDING.calculate_local_path(
            itinerary_item.start_location.pos.x,
            itinerary_item.start_location.pos.y,
            itinerary_item.target_location.pos.x,
            itinerary_item.target_location.pos.y,
        );
        if new_path_data == undefined {
            return PATHFINDING.last_error;
        }
        itinerary_item.local_path = new_path_data.output_list;
        itinerary_item.local_path_distance = new_path_data.distance;
    }

    //
    var snap_to_position = owner.pathfinding_agent.set_path(
        itinerary,
        owner.me.simulated_distance_traveled,
    );

    if snap_pos {
        //
        owner.x = snap_to_position.x;
        owner.y = snap_to_position.y;

        //
        owner.me.location_position.pos.x = snap_to_position.x;
        owner.me.location_position.pos.y = snap_to_position.y;
    }
}

function pathfinding_util_move_along_path(pos, move_accel, move_spd, agent, owner) {
    var next_pos = agent.ok_response;
    //
    var distance_vec2 = next_pos.sub(pos);

    //
    var min_dist = move_accel.sqrd_magnitude();
    var dist_to_pt = distance_vec2.sqrd_magnitude();

    var arrived = dist_to_pt <= min_dist;
    if arrived {
        if owner != undefined {
            owner.me.simulated_distance_traveled += sqrt(dist_to_pt) * agent.conversion_rate;
        }

        //
        pos.x = next_pos.x;
        pos.y = next_pos.y;
        return agent.onto_next_point();
    } else {
        //
        var dir = point_direction(0, 0, distance_vec2.x, distance_vec2.y);
        var x_dist = lengthdir_x(move_accel.x, dir);
        var y_dist = lengthdir_y(move_accel.y, dir);

        //
        //
        move_spd.x = min(abs(distance_vec2.x), abs(x_dist)) * sign(distance_vec2.x);
        move_spd.y = min(abs(distance_vec2.y), abs(y_dist)) * sign(distance_vec2.y);

        //
        if owner != undefined {
            owner.me.simulated_distance_traveled += sqrt(move_spd.x * move_spd.x + move_spd.y * move_spd.y) * agent.conversion_rate;
        }

        return false;
    }
}

function pathfinding_util_end_step() {
    self.owner.update_position();
    self.owner.me.location_position.pos.x = self.owner.x;
    self.owner.me.location_position.pos.y = self.owner.y;
}
