enum Benchmark {
    PanOnBusyFarm,
    LoadBusyFarm,
}

//
function run_bench(benchmark) {
    switch benchmark {
        case Benchmark.PanOnBusyFarm:
            var chain = new_chain();
            if CURRENT_LOCATION_ID != LocationId.Farm {
                __ts_travel_to(LocationId.Farm, chain);
            }
            chain.append(LinkId.Timer, 3);

            chain.append(LinkId.Function, function() {
                CLOCK.time_stopped = true;
                for (var i = 0; i < NpcId.LEN; i++) {
                    NPC_WHITELIST[i] = false;
                }

                instance_destroy(obj_bug);
                instance_destroy(obj_bird);
                instance_destroy(obj_fishy);
            });

            repeat 10 {
                chain.append(LinkId.Function, function() {
                    CAMERA.follow_point_instant(160, 448);
                    CAMERA.pan(1312, 448, 300, EaseId.Linear);
                })
                .append(LinkId.Timer, 300);
            }

            chain.append(LinkId.Function, function() {
            })
            .append(LinkId.Function, function() {
                CLOCK.time_stopped = false;
                for (var i = 0; i < NpcId.LEN; i++) {
                    NPC_WHITELIST[i] = true;
                }

                CAMERA.follow_instance(obj_ari);
            });
            break;
        case Benchmark.LoadBusyFarm:
            CLOCK.time_stopped = true;
            for (var i = 0; i < NpcId.LEN; i++) {
                NPC_WHITELIST[i] = false;
            }
            var chain = new_chain();

            //

            repeat 25 {
                __ts_travel_to(LocationId.Farm, chain);
                chain.append(LinkId.Timer, 10);
                __ts_travel_to(LocationId.PlayerHome, chain);
                chain.append(LinkId.Timer, 10);
            }

            chain.append(LinkId.Function, function() {
            })
            .append(LinkId.Function, function() {
                CLOCK.time_stopped = false;
                for (var i = 0; i < NpcId.LEN; i++) {
                    NPC_WHITELIST[i] = true;
                }

                CAMERA.follow_instance(obj_ari);
            });
            break;
    }
}
