function OrderSubTree(activity) {
    var activity_data = ACTIVITIES.get(activity);
    var followup = string_to_activity(activity_data.followup_activity);
    return Selector(
        //
        Sequence(
            Invert(Equal("ordered", true)),
            Set("activity_to_check", activity),
            Run(function(bb) {
                var activity = bb.get("me").activity_handler.activity;
                if activity != undefined {
                    return activity.id == bb.take("activity_to_check")
                        ? Status.Ok
                        : Status.Err;
                } else {
                    return Status.Err;
                }
            }),
            FindOrderLocation("order_location"),
            Run(function() {
                //
                //
                for (var i = 0; i < NpcId.LEN; i++) {
                    var npc = NPCS[i];
                    var routine = npc.activity_handler.routine;
                    if
                        routine != undefined
                        && (
                            array_has(routine.overrides, Activity.ServeTable)
                            || array_has(routine.overrides, Activity.ServeBar)
                        )
                    {
                        npc.brain_dead = false; //
                    }
                }
                return Status.Ok;
            }),
            Set(activity_data.request_key, true),
            Ensure(PlayBark(activity_data.request_bark, BarkType.Speech)),
            Set("ordered", true),
        ),

        //
        Sequence(
            Equal(activity_data.request_key, true),
            TakeFlag("service_received"),
            Ensure(PlayBark("cute_face", BarkType.Speech)),
            RemoveVariable("ordered"),
            Set("activity_request", followup),
            Run(function(bb) {
                bb.get("me").activity_handler.request_activity(bb.take("activity_request"));
                return Status.Ok;
            }),
        ),
    )
}

function FindOrderLocation(save_name) {
    return new __FindOrderLocation(save_name);
}
function __FindOrderLocation(save_name) : __Leaf() constructor {
    self.save_name = save_name;
    self.run = function(bb) {
        var order_location = undefined;
        var pos = bb.get("me").location_position;
        var trellis_point = trellis_point_by_location_position(pos);
        if trellis_point != undefined {
            order_location = self.name_to_order_location(trellis_point.name);
        }
        if order_location != undefined {
            bb.set(self.save_name, order_location);
            return Status.Ok;
        }
        return Status.Err;
    }

    self.name_to_order_location = function(tp_name) {
        if string_pos("north table", tp_name) != 0 {
            return InnOrderLocation.NorthTable;
        } else if string_pos("south table", tp_name) != 0 {
            return InnOrderLocation.SouthTable;
        } else {
            switch tp_name {
                case "inn/top bar seat": return InnOrderLocation.BarTop;
                case "inn/top-middle bar seat": return InnOrderLocation.BarMiddle;
                case "inn/bottom-middle bar seat":
                case "inn/bottom bar seat":
                    return InnOrderLocation.BarBottom;
                default: return undefined;
            }
        }
    }
}
