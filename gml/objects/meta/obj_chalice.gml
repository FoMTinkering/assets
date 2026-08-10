object_create(
    "obj_chalice",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_narrows_mines_entry_teleportation_chalice,
        create: function() {
            event_inherit(ObjectEvent.Create);

            depth = get_instance_depth(y);
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

                                self.sprite_index = spr_narrows_mines_entry_teleportation_chalice_glow;
                                self.image_index = 0;
                            }
                        });
                    } else {
                        play_conversation_from_path(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.CaldarusTeleportFail]);
                    }
                },
                function() {
                    return !TAXI.is_traveling();
                }
            );
        },
    }
);
