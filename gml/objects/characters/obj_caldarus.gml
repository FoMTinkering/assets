object_create(
    "obj_caldarus",
    object_reserve("par_NPC"),
    {
        sprite_index: spr_npc_mask,
        create: function() {
            event_inherit(ObjectEvent.Create);

            //
            self.register_interaction(
                InputId.Interact,
                "misc_local/talk",
                function() {
                    NPCS[NpcId.Caldarus].talk_flag = false;
                    self.talk(GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.CaldarusAsleep]);
                },
                function() {
                    return self.can_talk() && caldarus_is_sleeping() && ari_can_talk();
                }
            );
        },
    }
);
