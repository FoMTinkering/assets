object_create(
    "obj_pq_dragon_forge",
    object_reserve("par_crafting_table"),
    {
        sprite_index: spr_priestess_quarters_anvil_main,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.fiddle_name = "interaction/forge_offset";
            self.large_icon = spr_ui_bark_icon_crafting;
            self.small_icon = spr_ui_bark_icon_crafting_small;

            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    play_conversation_from_path(NpcId.Adeline, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.PqDragonForgeNotReady]);
                },
                function() {
                    var quest = QUEST_LOG.active.get("find_the_magic_key");
                    return quest != undefined && quest.current_stage == 0;
                }
            )

            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    play_conversation_from_path(NpcId.Adeline, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.PqDragonForgeReady]);
                },
                function() {
                    var quest = QUEST_LOG.active.get("find_the_magic_key");
                    return quest != undefined && quest.current_stage == 1;
                }
            )

            self.register_interaction(
                InputId.Interact,
                "misc_local/use",
                function() {
                    var point = trellis_point("priestess_quarters/ari_blacksmithing");
                    spawn_crafting_menu(
                        DRAGON_FORGING_UI_DATA,
                        point.x,
                        point.y,
                    );
                },
                function() {
                    var quest = QUEST_LOG.active.get("find_the_magic_key");
                    return quest == undefined || quest.current_stage >= 2;
                },
            );


            self.receiver = create_receiver(x, y, sprite_index, id, {
                target: CombatTarget.Enemy
            });

            self.receiver.image_xscale = image_xscale;
            self.receiver.image_yscale = image_yscale;

            function burn() {
                instance_destroy(self.receiver);
                MIST.run_scene("unlock_pq_ne");
            }

            function can_use() {
                var quest = QUEST_LOG.active.get("find_the_magic_key");
                return quest == undefined || quest.current_stage >= 2;
            }

            self.depth = get_instance_depth(self.y);
        },
        step: function() {
            var quest = QUEST_LOG.active.get("find_the_magic_key");
            if instance_exists(self.receiver) && quest != undefined && quest.current_stage == 1 {
                self.receiver.try_take_damage();
            }
        },
        draw: function() {
            event_inherit(ObjectEvent.Draw);
            draw_sprite(self.sprite_index, self.image_index, self.x, self.y);
        },
    }
);
