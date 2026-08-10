object_create(
    "obj_pq_sw_shelf",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_priestess_quarters_library_shelf_2_main,
        create: function() {
            event_inherit(ObjectEvent.Create);

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    play_conversation_from_path(NpcId.Adeline, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.PqSwShelf]);
                }
            )

            self.depth = get_instance_depth(self.y);
        },
    }
);
