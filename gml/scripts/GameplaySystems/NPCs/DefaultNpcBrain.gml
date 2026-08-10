function DefaultNpcBrain() {
    var brain = NewTreeBuilder();
    return brain.build(
        Selector(
            //
            Run(function(bb) {
                var me = bb.get("me");
                var output = T2R.schedule_execute(me.id, CALENDAR.unified_time());
                if output == undefined {
                    if T2R.schedule_current_action_has_arrived(me.id) {
                        return Status.Err;
                    }

                    //
                    //
                    var new_destination = T2R.schedule_current_destination(me.id);
                    output = {
                        type: undefined,
                        point: new_destination,
                    };
                }

                if output.type == T2OutputId.ScheduleState {
                    for (var k = 0, c = array_length(output.actions); k < c; k++) {
                        process_t2_action(output.actions[k], me.id);
                    }
                }

                start_schedule_pathfind(bb, trellis_point_location_position(output.point));
                return Status.Err;
            }),

            //
            ServeBarSubTree(),
            ServeTableSubTree(),
            OrderSubTree(Activity.OrderFood),
            OrderSubTree(Activity.OrderDrink),

            //
            Invert(PathfindingSubTree()),

            //
            //
            //
        ),
    );
}

function MistNpcBrain() {
    var brain = NewTreeBuilder();
    return brain.build(
        Selector(
            //
            ServeBarSubTree(),
            ServeTableSubTree(),
            OrderSubTree(Activity.OrderFood),
            OrderSubTree(Activity.OrderDrink),

            //
            Invert(PathfindingSubTree()),
        ),
    );
}

function CameoBrain() {
    var brain = NewTreeBuilder();
    return brain.build(
        Selector(
            Invert(PathfindingSubTree()),
        ),
    );
}


function start_schedule_pathfind(bb, next_location) {
    var me = bb.get("me");
    var instance = bb.get("instance");
    bb.clear();
    bb.insert("me", me);
    bb.insert("instance", instance);

    bb.set("next_location", next_location);
    bb.set("on_arrived_at_next_location", function(bb) {
        var me = bb.get("me");
        var actions = T2R.schedule_arrived_at_destination(me.id, CALENDAR.unified_time());
        if actions != undefined {
            for (var i = 0, c = array_length(actions); i < c; i++) {
                process_t2_action(actions[i], me.id);
            }
        }
        me.brain_dead = true;
    });
}
