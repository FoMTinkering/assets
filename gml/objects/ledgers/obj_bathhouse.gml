object_create(
    "obj_bathhouse",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_bathhouse_ledger_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.darkness_sprite = spr_bathhouse_ledger_darkness;
            self.name = "bathhouse";

            self.menu = Menu.Textbox;

            self.register_interaction(
                InputId.Interact,
                "misc_local/use",
                function() {
                    static GET_LINE_FOR_BATH = function(npc) {
                        //
                        var can_afford = ARI.free_baths > 0 || ARI.get_gold() >= ARI.get_bathhouse_cost();

                        switch npc {
                            case NpcId.Juniper:
                                if !can_afford {
                                    return GpTriggeredConversation.JuniperBathhouseCannotAfford;
                                } else {
                                    switch ARI.free_baths {
                                        case 5: return GpTriggeredConversation.JuniperBathhouseFreeOne;
                                        case 4: return GpTriggeredConversation.JuniperBathhouseFreeTwo;
                                        case 3: return GpTriggeredConversation.JuniperBathhouseFreeThree;
                                        case 2: return GpTriggeredConversation.JuniperBathhouseFreeFour;
                                        case 1: return GpTriggeredConversation.JuniperBathhouseFreeFive;
                                        default: return GpTriggeredConversation.JuniperBathhouseOffer;
                                    }
                                }
                            case NpcId.Dozy:
                                if !can_afford {
                                    return GpTriggeredConversation.DozyBathhouseCannotAfford;
                                } else {
                                    switch ARI.free_baths {
                                        case 5: return GpTriggeredConversation.DozyBathhouseFreeOne;
                                        case 4: return GpTriggeredConversation.DozyBathhouseFreeTwo;
                                        case 3: return GpTriggeredConversation.DozyBathhouseFreeThree;
                                        case 2: return GpTriggeredConversation.DozyBathhouseFreeFour;
                                        case 1: return GpTriggeredConversation.DozyBathhouseFreeFive;
                                        default: return GpTriggeredConversation.DozyBathhouseOffer;
                                    }
                                }
                        }
                    }

                    //
                    var till_location = trellis_point_location_position("bathhouse/front desk");
                    var juniper_location = NPCS[NpcId.Juniper].location_position;
                    var is_juniper = till_location.eq_floored(juniper_location);

                    var offer_convo = GET_LINE_FOR_BATH(is_juniper ? NpcId.Juniper : NpcId.Dozy);
                    var farewell_convo = is_juniper
                        ? GpTriggeredConversation.JuniperBathhouseFarewell
                        : GpTriggeredConversation.DozyBathhouseFarewell;

                    if is_juniper == false
                        && NPCS[NpcId.Dozy].location_position.location_id != LocationId.Bathhouse
                    {
                        offer_convo = GpTriggeredConversation.EmptyBathhouse;
                        farewell_convo = GpTriggeredConversation.EmptyBathhouseFarewell;
                    }

                    //
                    var callback = undefined;
                    var args = undefined;
                    var cost = ARI.free_baths > 0 ? 0 : ARI.get_bathhouse_cost();
                    if ARI.get_gold() >= cost {
                        callback = function(driver, cost, farewell_convo) {
                            //
                            if driver.prompt_index_selected == 0 {
                                ARI.times_bathhouse_used_today += 1;
                                array_push(GAME_STATS.purchases, {
                                    type: "bathhouse",
                                    cost: cost,
                                    day: total_days(),
                                });
                                ARI.modify_gold(-cost);
                                MIST.request_scene("bathhouse");
                                ARI.free_baths = max(0, ARI.free_baths - 1);
                                new_chain()
                                    .append(LinkId.Await, function() {
                                        return !MIST.running;
                                    })
                                    .append(LinkId.Function, function(farewell_convo) {
                                        game_stats_increment(GAME_STATS, "bathhouse_uses");
                                        obj_ari.face_dir(90);
                                        obj_ari.set_animation(AnimationName.Idle);

                                        play_conversation_from_path(NpcId.Adeline, GAMEPLAY_CONVERSATIONS[farewell_convo]);
                                    }, [farewell_convo])
                            }
                        };
                        args = [cost, farewell_convo];
                    }

                    obj_ari.face_dir(90);
                    obj_ari.set_animation(AnimationName.Idle);

                    //
                    play_conversation_from_path(NpcId.Adeline, GAMEPLAY_CONVERSATIONS[offer_convo], callback, args);
                },
            );
            depth = get_instance_depth(y);
        },
    }
);
