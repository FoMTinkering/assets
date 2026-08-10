object_create(
    "obj_elsie",
    object_reserve("par_NPC"),
    {
        sprite_index: spr_npc_mask,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.register_interaction(
                InputId.SecondaryInteract,
                "misc_local/gossip",
                function() {
                    var gossip = get_gossip_selections();

                    //
                    obj_ari.face_dir(point_direction(obj_ari.x, obj_ari.y, self.x, self.y));
                    obj_ari.set_idle_simple();

                    if ARI.has_gossiped_today {
                        play_conversation_from_path(NpcId.Elsie, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.GossipCooldown]);
                    } else if array_length(gossip) == 0 {
                        //
                        play_conversation_from_path(NpcId.Elsie, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.NoGossip]);
                    } else {
                        static LINES = fiddle_get("misc/gossip_lines");
                        var line = string_to_gp_triggered_conversation(LINES[irandom(array_length(LINES) - 1)]);
                        play_conversation_from_path(
                            NpcId.Elsie,
                            GAMEPLAY_CONVERSATIONS[line],
                            function(_, gossip) {
                                var menu = ANCHOR.spawn_menu(Menu.Gossip);
                                menu.display_selections(gossip);
                            },
                            [gossip],
                        );
                    }

                },
                function() {
                    return QUEST_LOG.completed.contains("gossip_for_elsie")
                        && ari_can_talk();
                }
            );

        },
    }
);
