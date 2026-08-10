object_create(
    "obj_seridias_house_statue",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_seridias_house_dragon_statue,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.register_interaction(
                InputId.Interact,
                "misc_local/teleport",
                function() {
                    if ARI.get_essence() >= 10  {
                        play_conversation_from_path(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.CaldarusTeleportFarm], function(driver) {
                            if driver.prompt_index_selected == 0 {
                                TANGO.play("SoundEffects/Inventory/SpendEssence");
                                ARI.modify_essence(-10);
                                var point = trellis_point("farm/teleport_target");
                                ari_teleport_to_room(LocationId.Farm, point.x, point.y);
                            }
                        });
                    } else {
                        play_conversation_from_path(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.CaldarusTeleportFail]);
                    }
                },
                function() {
                    return npc_is_unlocked(NpcId.Caldarus) && !TAXI.is_traveling();
                }
            );

            self.depth = get_instance_depth(self.y);

            self.name = "seridias_house_statue";
            self.big_icon = spr_ui_bark_icon_essence;
            self.small_icon = spr_ui_bark_icon_essence_small;
        },
    }
);
