object_create(
    "obj_unfinished_content",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_prop_sign_spring_farm_fence_border_south,
        horizontal: false,
        create: function() {
            event_inherit(ObjectEvent.Create);

            if horizontal {
                sprite_index = spr_prop_sign_spring_farm_fence_border_east;
            }

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            self.register_interaction(
                InputId.Interact,
                "misc_local/use",
                function() {
                    play_conversation_from_path(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.UnfinishedContent]);
                },
            );
            depth = get_instance_depth(y);
        },
    }
);
