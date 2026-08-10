#macro ACTIVITIES global.__activities
global.__activities = undefined;

#macro ROUTINES global.__routines
global.__routines = undefined;

enum ActivityKind {
    TrellisPoint,
    CustomProgramming,
    GridObject,
    Wander,
    LEN,
}

enum ActivityState {
    Inactive,
    Active,
    Traveling,
    LEN,
}

function load_activities() {
    var toml_data = MapWrap(clone_value(fiddle_get("activities")));
    var default_value = toml_data.take("default");
    var keys = toml_data.keys();
    var collection = Map();
    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];
        var prototype = patch_object(toml_data.get(key), clone_value(default_value));
        apply_func(prototype, function(e) {
            return e == "<n/a>" ? undefined : e;
        });
        prototype.id = string_to_activity(key);
        prototype.kind = string_to_activity_kind(prototype.kind);
        prototype.required_vendor = opt_and_then(prototype.required_vendor, string_to_npc_id);
        prototype.animations = ListFromArray(
            is_array(prototype.animations)
            ? prototype.animations
            : [prototype.animations]
        );
        prototype.object_ids = [];
        if prototype[$ "object_tag"] != undefined {
            for (var j = 0; j < ObjectId.LEN; j++) {
                var activities = NODE_PROTOTYPES[j][$ "activities"];
                if activities == undefined {
                    continue;
                }
                for (var k = 0; k < array_length(activities); k++) {
                    var activity = activities[k];
                    if activity != undefined && activity.tag == prototype.object_tag {
                        array_push(prototype.object_ids, j);
                    }
                }
            }
        }
        assert(
            prototype.kind == ActivityKind.CustomProgramming || !prototype.animations.is_empty(),
            "Activity '{}' has no animations!",
            key,
        );
        collection.set(prototype.id, prototype);
    }
    return collection;
}

function load_routines() {
    var toml_data = MapWrap(clone_value(fiddle_get("routines")));
    var default_value = toml_data.take("default");
    var keys = toml_data.keys();
    var collection = Map();
    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];
        var prototype = patch_object(toml_data.get(key), clone_value(default_value));
        prototype.activities = apply_func(prototype.activities, string_to_activity);
        prototype.overrides = apply_func(prototype.overrides, string_to_activity);
        prototype.id = string_to_routine(key);
        collection.set(prototype.id, prototype);
    }
    return collection;
}

//
function ActivityHandler(npc) constructor {
    self.npc = npc;
    self.state = ActivityState.Inactive;
    self.request = undefined;
    self.routine = undefined;
    self.activity = undefined;
    self.start_time = undefined;
    self.end_time = undefined;
    self.target_location = undefined;
    self.target_node = undefined;
    self.target_activity_index = undefined;
    self.failure_cache = [];

    //
    function run(time) {
        time = time == undefined ? CLOCK.time : time;

        //
        var instance = self.npc.brain.blackboard.get("instance");
        if instance != undefined && instance.kissing {
            return;
        }

        //
        if self.state == ActivityState.Traveling {
            var request_pending = self.npc.brain.blackboard.contains_key("next_location");
            var in_pathfind = self.npc.itinerary != undefined;
            if !request_pending && !in_pathfind {
                self.begin_activity();
            }
        }

        //
        if self.state == ActivityState.Active && time >= self.end_time {
            self.clear_activity();
        }

        //
        if self.request == undefined && self.state == ActivityState.Inactive {
            var new_activity = self.try_get_activity();
            if new_activity != undefined {
                self.request_activity(new_activity);
            }
        }

        //
        if self.request != undefined {
            var activity = ACTIVITIES.get(self.request);
            self.request = undefined;

            //
            if !self.npc_fulfills_activity(activity.id) {
                //
                array_push(self.failure_cache, activity.id);
            } else {
                //
                //
                if array_is_empty(activity.trellis_points)
                    && array_is_empty(activity.object_ids)
                    && activity.kind != ActivityKind.Wander
                {
                    self.activity = activity;
                    self.begin_activity();
                } else {
                    //
                    self.select_activity_destination(activity);
                    if self.target_location != undefined {
                        self.activity = activity;
                        self.start_time = time;

                        //
                        if self.target_node != undefined
                            && (self.npc.location_position.location_id != CURRENT_LOCATION_ID || IN_NPC_TIME_JUMP)
                        {
                            self.npc.location_position = self.target_location;
                            self.begin_activity();
                        } else {
                            //
                            self.state = ActivityState.Traveling;
                            self.npc.brain.blackboard.set("next_location", self.target_location);
                        }
                    } else {
                        array_push(self.failure_cache, activity.id);
                    }
                }
            }
        }

        if self.state == ActivityState.Inactive
            && self.routine != undefined
            && array_is_superset_of(self.failure_cache, self.routine.activities)
        {
            if self.routine.wander_on_failure {
                self.request_activity(Activity.Wander);
            } else {
                self.reset();
            }
        }
    }

    //
    function clear_activity() {
        if self.state == ActivityState.Traveling {
            self.npc.brain.blackboard.remove("next_location");
        }
        self.state = ActivityState.Inactive;
        self.npc.set_animation(self.npc.is_seated() ? "sit" : "idle");
        T2R.write(format("{NpcId}_activity", self.npc.id), undefined);
        T2R.write(format("{NpcId}_activity_object", self.npc.id), undefined);
        self.activity = undefined;
        self.target_location = undefined;
        self.target_node = undefined;
        self.target_activity_index = undefined;
        self.end_time = undefined;
        self.failure_cache = [];
    }

    //
    function reset() {
        self.clear_activity();
        self.routine = undefined;
        T2R.write(format("{NpcId}_routine", self.npc.id), undefined);
        self.request = undefined;
        self.failure_cache = [];
    }

    //
    function set_routine(routine) {
        self.routine = ROUTINES.get(routine);
        T2R.write(format("{NpcId}_routine", self.npc.id), routine_to_string(self.routine.id));
    }

    //
    function request_activity(request) {
        self.request = request;
    }

    //
    //
    function needs_brain() {
        return
            (self.activity != undefined && self.activity.kind == ActivityKind.CustomProgramming)
            || self.state == ActivityState.Traveling;
    }

    //
    function begin_activity(time) {
        time = time == undefined ? CLOCK.time : time;

        //
        var required_cardinal = undefined;
        if self.target_node != undefined {
            var this = self.target_node.prototype.activities[self.target_activity_index];
            required_cardinal = this.direction ?? self.target_node.cardinal_index;
            self.npc.set_cardinality(required_cardinal);
            T2R.write(format("{NpcId}_activity_object", self.npc.id), object_id_to_string(self.target_node.object_id));
        }

        if !self.activity.animations.is_empty() {
            var choice = undefined;
            var valid_options = 0;
            for (var i = 0; i < self.activity.animations.count(); i++) {
                var animation = self.activity.animations.get(i);
                if self.npc.can_perform_animation(animation, required_cardinal) {
                    valid_options += 1;
                    if irandom_range(1, valid_options) == 1 {
                        choice = animation;
                    }
                }
            }

            choice = choice ?? "idle";

            assert_defined(choice, "Failed to find any valid animation for a greenlit activity!");

            self.npc.set_animation(choice);
        }

        T2R.write(format("{NpcId}_activity", self.npc.id), activity_to_string(self.activity.id));

        //
        //
        var range = self.activity.duration_range ?? [I32_MAX, I32_MAX];
        self.end_time = time + minutes(irandom_range(range[0], range[1]));
        self.state = ActivityState.Active;

        //
        self.npc.brain_dead = !self.needs_brain();
    }

    //
    function try_get_activity() {
        if self.routine == undefined {
            return undefined;
        }

        var choice = undefined;
        var valid_options = 0;
        for (var i = 0; i < array_length(self.routine.activities); i++) {
            var activity = self.routine.activities[i];
            if array_has(self.failure_cache, activity) {
                continue;
            }
            if self.npc_fulfills_activity(activity) {
                valid_options += 1;
                if irandom_range(1, valid_options) == 1 {
                    choice = activity;
                }
            } else {
                array_push(self.failure_cache, activity);
            }
        }

        return choice;
    }

    //
    //
    function select_activity_destination(activity) {
        switch activity.kind {
            case ActivityKind.TrellisPoint:
                var choice = undefined;
                var valid_options = 0;

                //
                for (var i = 0; i < array_length(activity.trellis_points); i++) {
                    var point = trellis_point_location_position(activity.trellis_points[i]);
                    var location_id_matches = point.location_id == self.npc.location_position.location_id;
                    var other_npc_occupying = find_npc_at_or_approaching(point, self.npc.id);
                    if location_id_matches && other_npc_occupying == undefined {
                        valid_options += 1;
                        if irandom_range(1, valid_options) == 1 {
                            choice = point;
                        }
                    }
                }

                if valid_options <= 1 {
                    if choice == undefined {
                        return false;
                    } else {
                        self.target_location = choice;
                        return true
                    }
                }

                var choice = undefined;
                var valid_options = 0;

                //
                for (var i = 0; i < array_length(activity.trellis_points); i++) {
                    var point = trellis_point_location_position(activity.trellis_points[i]);
                    var location_id_matches = point.location_id == self.npc.location_position.location_id;
                    var other_npc_occupying = find_npc_at_or_approaching(point, self.npc.id);
                    if location_id_matches
                        && other_npc_occupying == undefined
                        && self.npc.location_position.eq(point) == false
                    {
                        valid_options += 1;
                        if irandom_range(1, valid_options) == 1 {
                            choice = point;
                        }
                    }
                }

                self.target_location = choice;
                return true;

            case ActivityKind.GridObject:
                static SEARCH_GRID = function(activity, nodes, location_id) {
                    static MAX_ATTEMPTS = 100;
                    var choice = undefined;
                    var valid_options = 0;

                    var attempts = 0;
                    repeat min(MAX_ATTEMPTS, nodes.count() * nodes.count()) {
                        attempts += 1;

                        var i = irandom(nodes.count() - 1);
                        var node = nodes.get(i);
                        if !array_has(activity.object_ids, node.object_id) {
                            continue;
                        }

                        //
                        for (var j = 0; j < array_length(node.prototype.activities); j++) {
                            var this = node.prototype.activities[j];
                            if this.tag == activity.object_tag {
                                var dir = this.direction ?? node.cardinal_index
                                var destination = new LocationPosition(
                                    location_id,
                                    activity_position_for_node(node, dir, j),
                                );

                                //
                                if self.npc.location_position.eq(destination) {
                                    continue;
                                }

                                if node.child_grid != undefined {
                                    var has_children = false;
                                    for (var xx = 0; xx < node.child_grid.dims.x; xx++) {
                                        for (var yy = 0; yy < node.child_grid.dims.y; yy++) {
                                            var cell = node.child_grid.node_index_for_cell(xx, yy);
                                            if node.child_grid.node_object_id[cell] != undefined {
                                                has_children = true;
                                                break;
                                            }
                                        }
                                    }
                                    if has_children {
                                        continue;
                                    }
                                }

                                if location_id == CURRENT_LOCATION_ID {
                                    var test_path = PATHFINDING.calculate_local_path(
                                        self.npc.location_position.pos.x,
                                        self.npc.location_position.pos.y,
                                        destination.pos.x,
                                        destination.pos.y,
                                        true,
                                    );

                                    if test_path == undefined {
                                        continue;
                                    }
                                }

                                valid_options += 1;
                                if irandom_range(1, valid_options) == 1 {
                                    choice = {
                                        target_node: node,
                                        target_activity_index: j,
                                        target_location: destination,
                                    };
                                }
                            }
                        }

                        if choice != undefined {
                            break;
                        }
                    }

                    return choice;
                }

                var selection = undefined;

                //
                var location_target = self.npc.brain.blackboard.try_take("forced_location");
                if self.npc.location_position.location_id == CURRENT_LOCATION_ID || location_target != undefined  {
                    location_target ??= CURRENT_LOCATION_ID;
                    var grid_target = GRIDS[location_target];
                    selection = SEARCH_GRID(activity, grid_target.activity_nodes, location_target);
                } else {
                    var needle_lid = self.npc.at_farm()
                        ? npc.location_position.location_id
                        : LocationId.PlayerHome;

                    //
                    //
                    var npcs_grid = GRIDS[needle_lid];
                    selection = SEARCH_GRID(activity, npcs_grid.activity_nodes, needle_lid);
                    var valid_options = 1;
                    var neighbors = PLAYER_LOCATION_NEIGHBORS[npcs_grid.location_id];
                    for (var i = 0; i < array_length(neighbors); i++) {
                        var lid = neighbors[i];
                        if lid == CURRENT_LOCATION_ID {
                            continue;
                        }

                        if lid == LocationId.Farm && (!is_between(CLOCK.time, hours(8), hours(11)) || WEATHER.is_inclement()) {
                            continue;
                        }

                        if is_home_location(lid) && !home_location_is_unlocked(lid) {
                            continue;
                        }

                        if get_house_corresponding_room(npcs_grid.location_id) == lid {
                            var found_stairs = false;
                            for (var j = 0; j < npcs_grid.node_len; j++) {
                                var oid = npcs_grid.node_object_id[j];
                                if oid != undefined && NODE_PROTOTYPES[oid].house_stairs != undefined {
                                    found_stairs = true;
                                    break;
                                }
                            }

                            if !found_stairs {
                                continue;
                            }
                        }


                        var potential = SEARCH_GRID(activity, GRIDS[lid].activity_nodes, lid);
                        if potential == undefined {
                            continue;
                        }

                        valid_options += 1;
                        if irandom_range(1, valid_options) {
                            selection = potential;
                        }
                    }
                }

                if selection != undefined {
                    self.target_node = selection.target_node;
                    self.target_location = selection.target_location;
                    self.target_activity_index = selection.target_activity_index;
                    return true;
                }
                return false;
            case ActivityKind.Wander:
                static MAX_ATTEMPTS = 50;
                var grid = GRIDS[self.npc.location_position.location_id];
                var winner = undefined;
                var winner = player_home_random_position(self.npc.location_position.location_id);

                //
                //
                //
                if winner != undefined {
                    if self.npc.location_position.location_id == CURRENT_LOCATION_ID {
                        var test_path = PATHFINDING.calculate_local_path(
                            self.npc.location_position.pos.x,
                            self.npc.location_position.pos.y,
                            winner.x,
                            winner.y,
                        );

                        if test_path == undefined {
                            return false;
                        }
                    }
                    self.target_location = LocationPosition(grid.location_id, winner);
                }
                return false;
            default: impossible("Unexpected ActivityKind: {ActivityKind}", activity.kind);
        }
    }

    //
    //
    function npc_fulfills_activity(activity) {
        var data = ACTIVITIES.get(activity);
        var is_custom = data.kind == ActivityKind.CustomProgramming;
        var animation_valid = is_custom || data.animations.any(function(e) {
            return self.npc.can_perform_animation(e, undefined, true);
        });
        var vendor_req_passed = true;
        if data.required_vendor != undefined {
            vendor_req_passed = SATURDAY_MARKET.stalls[data.required_vendor];
        }
        return animation_valid && vendor_req_passed;
    }
}

//
function ActivityCanOverride(activity) {
    return new __ActivityCanOverride(activity);
}
function __ActivityCanOverride(activity) : __Leaf() constructor {
    self.activity = activity;
    self.run = function(bb) {
        var routine = bb.get("me").activity_handler.routine;
        if routine != undefined {
            return array_has(routine.overrides, self.activity)
                ? Status.Ok
                : Status.Err;
        }
        return Status.Err;
    }
}
