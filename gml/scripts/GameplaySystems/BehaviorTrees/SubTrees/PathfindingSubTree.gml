//
//
function PathfindingSubTree() {
    return Selector(
        //
        Invert(IsDefined("next_location")),

        //
        Run(function(bb) {
            var next_location = bb.get("next_location");
            var me = bb.get("me");

            if next_location.eq_floored(me.location_position) {
                me.complete_pathfind();

                bb.remove("next_location");

                return Status.Ok;
            } else if me.activity_handler.routine != undefined {
                T2R.write(format("{NpcId}_zone", me.id), format("personal/{NpcId}", me.id));
            }
            return Status.Err;
        }),
        //
        Sequence(
            //
            Run(function(bb) {
                var npc = bb.get("instance");
                var me = bb.get("me");
                var faded = false;
                me.itinerary = PATHFINDING.calculate_map_path(me.location_position, bb.take("next_location"));

                //
                //
                if me.itinerary.items.get(0).start_location.location_id != me.location_position.location_id {
                    warn("{NpcId} is jumping from {} to {}", me.id, me.location_position, me.itinerary.items.get(0).start_location);

                    //
                    me.location_position = me.itinerary.items.get(0).start_location.clone();
                    me.simulated_distance_traveled = 0;

                    var npc = bb.get("instance");

                    //
                    //
                    if npc != undefined
                        && instance_exists(npc)
                        && me.itinerary.items.get(0).start_location.location_id != CURRENT_LOCATION_ID
                    {
                        warn("{NpcId} was trapped and will teleport!", me.id);
                        var err = npc.pathfinding_agent.move_along_path();
                        fade_value(npc, "image_alpha", npc.image_alpha, 0, 60);
                        new_world_chain(npc, CURRENT_LOCATION_ID)
                            .append(LinkId.Timer, 59)
                            .append(LinkId.Function, function(npc) {
                                instance_destroy(npc);
                            }, [npc]);

                        faded = true;
                    }
                }

                //
                if npc != undefined && instance_exists(npc) && npc.fsm.current_state_id() == NpcState.Pathfinding && faded == false {
                    me.simulated_distance_traveled = 0;
                    npc.fsm.change_state(NpcState.Pathfinding);
                }
                return Status.Ok;
            }),

            RepeatUntilSuccess(
                Selector(
                    //
                    //
                    Sequence(
                        InRoom(),
                        TakeFlag("pathfind_complete"),
                        Run(function(bb) {
                            var me = bb.get("me");
                            me.complete_pathfind();

                            return Status.Ok;
                        }),
                    ),

                    //
                    Sequence(
                        Invert(InRoom()),
                        Run(function(bb) {
                            var me = bb.get("me");
                            var itinerary = me.itinerary;
                            //
                            if itinerary == undefined || itinerary.items.is_empty() {
                                error("we lost our path somehow? This seems incredibly unlikely for us to actually get here...")
                                return Status.Ok;
                            }
                            var itinerary_item = itinerary.items.get(itinerary.cursor);
                            me.simulated_distance_traveled += OUT_OF_ROOM_BRAIN_FREQUENCY * HUMAN_WALK_SPEED;
                            if me.simulated_distance_traveled >= itinerary_item.distance {
                                me.simulated_distance_traveled = 0;
                                if itinerary.on_last_item() {
                                    //
                                    me.location_position = itinerary
                                        .current_item()
                                        .target_location
                                        .clone();

                                    me.complete_pathfind();
                                    return Status.Ok;
                                } else {
                                    me.location_position = itinerary.advance_path();
                                    return Status.Err;
                                }
                            }
                            return Status.Err;
                        }),
                    ),

                    //
                    //
                    Run(function(bb) {
                        var me = bb.get("me");
                        if T2R.schedule_will_execute(me.id, CLOCK.time) {
                            return Status.Ok;
                        } else {
                            return Status.Err;
                        }
                    })
                )
            )
        )
    )
}
