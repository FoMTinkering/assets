object_create(
    "obj_pq_nw_shelf",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_priestess_quarters_library_shelf_1_main,
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
                    play_conversation_from_path(NpcId.Adeline, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.PqNwShelf]);
                    var quest = QUEST_LOG.active.get("find_the_magic_key");
                    if quest != undefined && quest.current_stage == 0 {
                        quest.progress();
                    }
                }
            )

            self.depth = get_instance_depth(self.y);
        },
    }
);
