function ServeTableSubTree() {
    return Sequence(
        //
        ActivityCanOverride(Activity.ServeTable),

        //
        FindServiceLocation("order_data", Activity.ServeTable),
        SetWith("table_position", function(bb) {
            return bb.get("order_data").location_position.clone();
        }),
        StartActivityOverride(Activity.ServeTable),
        Copy("table_position", "next_location"),
        PathfindingSubTree(),

        //
        Ensure(PlayBark("question_mark", BarkType.Speech)),
        SetAnimation("write"),
        Wait(300),

        //
        Set("next_location", trellis_point_location_position("inn/kitchen shelf")),
        PathfindingSubTree(),
        SetAnimation("action", "idle"),
        Wait(60),

        //
        Copy("table_position", "next_location"),
        PathfindingSubTree(),

        //
        SetAnimation("idle"),
        Wait(30),

        //
        Run(function(bb) {
            var my_order_location = bb.get("order_data").order_location;
            for (var i = 0; i < NpcId.LEN; i++) {
                var npc = NPCS[i];
                var at_this_table = npc.brain.blackboard.get("order_location") == my_order_location;
                if at_this_table {
                    npc.brain.blackboard.set("service_received", true);
                    npc.brain.blackboard.remove("order_location");
                }
            }
            return Status.Ok;
        }),

        //
        RemoveVariable("order_data"),
        RemoveVariable("table_position"),
        Wait(120),
        EndActivityOverride(),
    );
}

function ServeBarSubTree() {
    return Sequence(
        //
        ActivityCanOverride(Activity.ServeBar),

        //
        FindServiceLocation("order_data", Activity.ServeBar),

        //
        StartActivityOverride(Activity.ServeBar),
        SetWith("next_location", function(bb) {
            return bb.get("order_data").location_position;
        }),
        PathfindingSubTree(),

        //
        SetAnimation("idle"),
        Run(function(bb) {
            var order_data = bb.get("order_data");
            var npc = NPCS[order_data.npc];
            npc.brain.blackboard.set("service_received", true);
            npc.brain.blackboard.remove("order_location");
            return Status.Ok;
        }),

        //
        RemoveVariable("order_data"),
        Wait(120),
        EndActivityOverride(),
    )
}

//
//
function FindServiceLocation(save_name, activity_id) {
    return new __FindServiceLocation(save_name, activity_id);
}
function __FindServiceLocation(save_name, activity_id) : __Leaf() constructor {
    self.activity_id = activity_id;
    self.save_name = save_name;
    self.run = function(bb) {
        for (var i = 0; i < NpcId.LEN; i++) {
            //
            var npc = NPCS[i];
            var order_location = npc.brain.blackboard.get("order_location");

            //
            if order_location == undefined {
                continue;
            }

            //
            var trellis_point_name = inn_order_location_to_trellis_point_name(order_location);

            //
            var activity = ACTIVITIES.get(self.activity_id);
            if !array_has(activity.service_positions, trellis_point_name) {
                continue;
            }

            //
            var already_being_served = false;
            for (var k = 0; k < NpcId.LEN; k++) {
                var npc = NPCS[k];

                var data = npc.brain.blackboard.get(self.save_name);
                if data != undefined && data.order_location == order_location {
                    already_being_served = true;
                    break;
                }
            }
            if already_being_served {
                continue;
            }

            //
            bb.set(self.save_name, {
                order_location: order_location,
                location_position: trellis_point_location_position(trellis_point_name),
                npc: i,
            });
            return Status.Ok;
        }
        return Status.Err;
    }
}

//
function StartActivityOverride(activity_id) {
    return new __StartActivityOverride(activity_id);
}
function __StartActivityOverride(activity_id) : __Leaf() constructor {
    self.activity_id = activity_id;
    self.run = function(bb) {
        var me = bb.get("me");
        me.activity_handler.clear_activity();
        me.activity_handler.activity = ACTIVITIES.get(self.activity_id);
        me.activity_handler.begin_activity();
        return Status.Ok;
    }
}

//
function EndActivityOverride() {
    return new __EndActivityOverride();
}
function __EndActivityOverride() : __Leaf() constructor {
    self.run = function(bb) {
        var me = bb.get("me");
        me.activity_handler.clear_activity();
        return Status.Ok;
    }
}

function inn_order_location_to_trellis_point_name(loc) {
    switch loc {
        case InnOrderLocation.NorthTable: return "inn/north table service";
        case InnOrderLocation.SouthTable: return "inn/south table service";
        case InnOrderLocation.BarTop: return "inn/bartender 1";
        case InnOrderLocation.BarMiddle: return "inn/bartender 2";
        case InnOrderLocation.BarBottom: return "inn/bartender 3";
        default: impossible("Unexpected InnOrderLocation: {InnOrderLocation}", loc);
    }
}

enum InnOrderLocation {
    NorthTable,
    SouthTable,
    BarTop,
    BarMiddle,
    BarBottom,
    LEN,
}
