object_create(
    "obj_dragonshrine",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_farm_dragonstatue_broken_spring,
        visible: false,
        create: function() {
            event_inherit(ObjectEvent.Create);
            self.sprite_index = spr_farm_dragonstatue_broken_spring;
            self.visible = true;

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            //
            self.register_interaction(
                InputId.SecondaryInteract,
                "misc_local/use_shrine",
                function() {
                    ANCHOR.spawn_menu(Menu.DragonShrine, ShrineMenuVariant.Caldarus);
                },
                function() {
                    return requirements_pass(Requirement.UseDragonShrine) && !TAXI.is_traveling();
                },
            );

            //
            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    //
                    obj_ari.face_dir(point_direction(obj_ari.x, obj_ari.y, self.x, self.y));
                    obj_ari.set_idle_simple();
                    play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectCaldarusStatue]);
                },
                function() {
                    return requirements_pass(Requirement.RepairedDragonShrine)
                        && !requirements_pass(Requirement.UseDragonShrine)
                        && !requirements_pass(Requirement.SpeakToStatue);
                }
            );

            //
            self.register_interaction(
                InputId.Interact,
                "misc_local/talk",
                function() {
                    var next_conversation = T2R.request_conversation(NpcId.Caldarus);

                    //
                    obj_ari.face_dir(90);
                    obj_ari.set_idle_simple();
                    //
                    play_conversation(NpcId.Caldarus, next_conversation);
                },
                function() {
                    return requirements_pass(Requirement.SpeakToStatue)
                        && NPCS[NpcId.Caldarus].talk_flag
                        && !npc_is_unlocked(NpcId.Caldarus);
                },
            );

            //
            self.register_interaction(
                InputId.Interact,
                "misc_local/talk",
                function() {
                    obj_ari.face_dir(90);
                    obj_ari.set_idle_simple();
                    NPCS[NpcId.Caldarus].talk_flag = false;
                    play_conversation_from_path(
                        NpcId.Caldarus,
                        GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.CaldarusAwaitingAri],
                    );

                },
                function() {
                    return npc_is_unlocked(NpcId.Caldarus)
                        && NPCS[NpcId.Caldarus].talk_flag
                        && !MIST.scene_history.contains("caldarus_recovery");
                }
            )

            self.register_interaction(
                InputId.Interact,
                "misc_local/teleport",
                function() {
                    if ARI.get_essence() >= 10  {
                        var initial_outfit = NPCS[NpcId.Caldarus].wardrobe.outfit_name;
                        NPCS[NpcId.Caldarus].wardrobe.set_outfit("dragon_statue");
                        play_conversation_from_path(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.CaldarusTeleport], function(driver, initial_outfit) {
                            if driver.prompt_index_selected == 0 {
                                TANGO.play("SoundEffects/Inventory/SpendEssence");
                                ARI.modify_essence(-10);
                                var point = trellis_point("caldarus_house/teleport_target");
                                ari_teleport_to_room(LocationId.CaldarusHouse, point.x, point.y);
                            }
                            NPCS[NpcId.Caldarus].wardrobe.set_outfit(initial_outfit);
                        }, [initial_outfit]);
                    } else {
                        play_conversation_from_path(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.CaldarusTeleportFail]);
                    }
                },
                function() {
                    return npc_is_unlocked(NpcId.Caldarus)
                        && !TAXI.is_traveling()
                        && MIST.scene_history.contains("caldarus_recovery");
                }
            )

            depth = get_instance_depth(y);
            mask_index = spr_farm_dragonstatue_broken_spring;

            var fiddle_data = fiddle_get("interaction/dragon_shrine_offset");
            self.offset_x = fiddle_data[0];
            self.offset_y = fiddle_data[1];

        },
        step: function() {
            self.sprite_index = requirements_pass(Requirement.RepairedDragonShrine)
                ? spr_farm_dragonstatue_restored_spring
                : spr_farm_dragonstatue_broken_spring;
        },
        draw_end: function() {
            self.bouncer.status = InteractBounceStatus.Distant;

            //
            if has_flag(PAUSE_STATUS, PauseStatus.MENU)
                || has_flag(PAUSE_STATUS, PauseStatus.CUTSCENE)
            {
                return;
            }

            var has_talk_interaction = requirements_pass(Requirement.SpeakToStatue)
                && NPCS[NpcId.Caldarus].talk_flag
                && !npc_is_unlocked(NpcId.Caldarus);

            self.bouncer.alpha = approach(self.bouncer.alpha, BARK_MIN_ALPHA, BARK_FADE_SPEED);
            var is_being_selected = self.bouncer.update();

            
            if has_talk_interaction {
                if is_being_selected {
                    draw_sprite_ext(spr_ui_dialogue_speech_bubble_big, 0, x + offset_x, y + offset_y + 6 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                } else {
                    draw_sprite_ext(spr_ui_dialogue_speech_bubble_small, 0,  x + offset_x, y + offset_y + 6 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                }
            } else if requirements_pass(Requirement.UseDragonShrine) {
                if is_being_selected {
                    draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                    draw_sprite_ext(spr_ui_bark_icon_essence, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                } else {
                    draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                    draw_sprite_ext(spr_ui_bark_icon_essence_small, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                }
            }
        },
    }
);
