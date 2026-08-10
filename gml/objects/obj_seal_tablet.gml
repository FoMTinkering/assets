object_create(
    "obj_seal_tablet",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_water_seal_tablet_spring,
        seal_id: Seal.Water,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.inventory = Inventory(4);
            var fiddle = fiddle_get(format("seals/{Seal}", self.seal_id));
            self.sprite_index = string_to_asset(fiddle.tablet_sprite);
            self.quest = CONTENT_REGISTRY.validate_quest(fiddle.quest);
            self.stage = fiddle.stage;
            if fiddle[$ "cutscene"] != undefined {
                self.cutscene = CONTENT_REGISTRY.validate_cutscene(fiddle.cutscene);
            } else {
                self.cutscene = undefined;
            }

            if self.seal_id == Seal.Final {
                var quest = QUEST_LOG.active.get("the_dragonsworn_tablet");
                if (quest != undefined && quest.current_stage >= 2) || QUEST_LOG.completed.contains("the_dragonsworn_tablet") {
                    self.sprite_index = spr_seridias_chamber_tablet_unlocked;
                }
            }

            function my_recipe() {
                var quest = QUESTS.get(self.quest);
                var recipe = {};
                for (var i = 0; i < quest.tasks.count(); i++) {
                    var req = quest.tasks.get(i).requirements[Requirement.SuppliedItems];
                    if req == undefined {
                        continue;
                    }
                    if array_length(req) > 0 {
                        for (var j = 0; j < ItemId.LEN; j++) {
                            if req[0].items[j] != 0 {
                                recipe[$ j] = req[0].items[j];
                            }
                        }
                    }
                }
                return recipe;
            }

            function quest_at_donation_stage() {
                var quest = QUEST_LOG.active.get(self.quest);
                return quest != undefined && quest.current_stage == self.stage;
            }

            function can_be_completed(include_menu_inventory=false) {
                var recipe = self.my_recipe();
                var count = SEAL_INVENTORIES[self.seal_id].slots.sum_with(function(v) {
                    return v.count;
                });

                if include_menu_inventory {
                    count += self.inventory.slots.sum_with(function(v) {
                        return v.count;
                    });
                }

                var total_sum = 0;
                var names = struct_get_names(recipe);
                for (var i = 0; i < array_length(names); i++) {
                    total_sum += recipe[$ names[i]];
                }

                return count == total_sum;
            }

            function complete_donation(menu) {
                var recipe = self.my_recipe();
                var items = self.inventory.drain();
                for (var i = 0; i < items.count(); i++) {
                    var item = items.get(i);
                    if SEAL_INVENTORIES[self.seal_id].item_id_quantity(item.item_id) < recipe[$ item.item_id] {
                        SEAL_INVENTORIES[self.seal_id].add(item);
                    } else {
                        drop_item(item, obj_ari.x, obj_ari.y);
                    }
                }

                if self.can_be_completed() {
                    if self.cutscene != undefined {
                        MIST.request_scene(self.cutscene);
                        MIST.arbitrary_quest_to_progress = QUEST_LOG.active.get(self.quest);
                    } else {
                        assert(self.seal_id == Seal.Priestess);
                        QUEST_LOG.active.get(self.quest).progress();
                        drop_item(ItemId.SeedMagicKey, obj_ari.x, obj_ari.y);
                    }
                }
                menu.close();
            }

            function interact_callback() {
                var recipe = self.my_recipe();

                var menu = ANCHOR.spawn_menu(Menu.Storage)
                    .set_inventories(self.inventory, ARI.inventory)
                    .with_right_banner()
                    .with_recipe(recipe, SEAL_INVENTORIES[self.seal_id])
                    .with_alt_stack_behavior()
                    .build();

                menu.left_menu.pilot.request_newline();

                menu.left_menu.canvas.add_y(-14);

                menu.button = ANCHOR.nine_slice(menu.left_box)
                    .set_sprites_from_key("spr_ui_button")
                    .set_size(68, 18)
                    .set_align(Align.Center, Align.Middle)
                    .set_y(11)
                    .add_text_label("misc_local/offer", COMMON_LUT, CommonLutIndex.Dark)
                    .set_tap_sound("SoundEffects/UI/UIExtraPositiveClick")
                    .add_to_pilot(menu.left_menu.pilot)
                    .set_think_callback(function(menu) {
                        //
                        if !instance_exists(self) {
                            return;
                        }
                        menu.button.set_unlocked(!self.inventory.is_empty());
                    }, [menu])
                    .set_tap_callback(function(menu) {
                        if self.cutscene == "dragon_tablet_pt_4" && self.can_be_completed(true) {
                            var popup = popup_creator("misc_local/turn_in_items", "misc_local/final_seal_confirmation");
                            popup.create_button("misc_local/not_yet");
                            popup.create_button("misc_local/yes", function(menu) {
                                self.complete_donation(menu);
                            }, [menu]);
                            popup.spawn();
                            return;
                        }

                        self.complete_donation(menu);
                    }, [menu])

                menu.button.text_label
                    .set_align(Align.Center, Align.Middle)
                    .set_x(4)

                menu.icon = ANCHOR.sprite(menu.button)
                    .set_sprites_from_key("spr_ui_dungeon_offer_button_icon")
                    .set_key_sprite_target(menu.button)
                    .set_align(Align.LeftIn, Align.Middle)
                    .set_x(6)

                menu.on_close = method(menu, function() {
                    var items = self.left_menu.inventory.drain();
                    for (var i = 0; i < items.count(); i++) {
                        drop_item(items.get(i), obj_ari.x, obj_ari.y);
                    }
                });
            }

            function spawn_void_ari() {
                var tp = trellis_point("ruins_seal/rs3_void_ari_entrance");
                instance_create_depth(tp.x, tp.y, self.depth, obj_void_ari);
            }

            if self.seal_id == Seal.Ruins && self.quest_at_donation_stage() {
                self.spawn_void_ari();
            }

            self.sound_controller = undefined;
            if self.seal_id == Seal.Void {
                self.sound_controller = new SoundInstanceController(
                    TANGO.play("SoundEffects/Environment/SeridiaCauldronLoop", self.x, self.y)
                );
            }

            self.register_interaction(
                InputId.Interact,
                "misc_local/interact",
                self.interact_callback,
                function() {
                    if self.seal_id == Seal.Ruins {
                        return false;
                    }
                    return self.quest_at_donation_stage();
                }
            );

            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    //
                    obj_ari.face_dir(point_direction(obj_ari.x, obj_ari.y, self.x, self.y));
                    obj_ari.set_idle_simple();

                    switch self.seal_id {
                        case Seal.Water:
                            play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectWaterTablet]);
                            break;
                        case Seal.Earth:
                            play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectEarthTablet]);
                            break;
                        case Seal.Fire:
                            play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectFireTablet]);
                            break;
                        case Seal.Priestess:
                            play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.PqTablet]);
                            var quest = QUEST_LOG.active.get(self.quest);
                            if quest != undefined {
                                quest.progress();
                            }
                            break;
                        case Seal.Final:
                            var quest = QUEST_LOG.active.get("the_dragonsworn_tablet");
                            if quest != undefined {
                                if quest.current_stage == 0 {
                                    MIST.request_scene("dragon_tablet_pt_2");
                                } else if quest.current_stage == 2 {
                                    quest.progress();
                                    QUEST_LOG.complete("the_dragonsworn_tablet");
                                    QUEST_LOG.start("breaking_the_final_seal");
                                    play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectDragonswornTablet], function() {
                                        await_popup(ARI.unlock_recipe, [ItemId.DragonForgedFang]);
                                        await_popup(ARI.unlock_recipe, [ItemId.DragonForgedHorn]);
                                        await_popup(ARI.unlock_recipe, [ItemId.DragonForgedCore]);
                                        await_popup(ARI.unlock_recipe, [ItemId.DragonForgedPowder]);
                                    });
                                }
                            }
                            break;
                        default: impossible("Unexpected Seal: {Seal}", self.seal_id);
                    }
                },
                function() {
                    switch self.seal_id {
                        case Seal.Priestess: return !T2R.read("read_pq_tablet");
                        case Seal.Void: return false;
                        case Seal.Ruins: return false;
                        case Seal.Final:
                            var quest = QUEST_LOG.active.get("the_dragonsworn_tablet");
                            return quest != undefined && matches(quest.current_stage, 0, 2);
                        default: return !QUEST_LOG.active.contains_key(self.quest) && !QUEST_LOG.completed.contains(self.quest);
                    }
                }
            );

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            if self.seal_id == Seal.Final {
                var fiddle_data = fiddle_get("interaction/final_tablet_offset");
            } else {
                var fiddle_data = fiddle_get("interaction/water_tablet_offset");
            }

            self.bounce_x_offset = fiddle_data[0];
            self.bounce_y_offset = fiddle_data[1];
            depth = get_instance_depth(y);
        },
        step: function() {

        },
        draw_end: function() {
            self.bouncer.status = InteractBounceStatus.Distant;

            if game_paused() || !self.has_potential_interactions() || !QUEST_LOG.active.contains_key(self.quest) {
                return;
            }

            if self.seal_id == Seal.Priestess && !T2R.read("read_pq_tablet") {
                return;
            }

            self.bouncer.alpha = BARK_MIN_ALPHA;

            var is_being_selected = self.bouncer.update();

            if is_being_selected {
                draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_donate, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
            } else {
                draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_donate_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
            }
        },
        animation_end: function() {
            if self.sprite_index == spr_ruins_seal_tablet_cutscene_spring_start {
                self.sprite_index = spr_ruins_seal_tablet_cutscene_spring_loop;
            }
            if self.sprite_index == spr_ruins_seal_tablet_cutscene_spring_end {
                self.sprite_index = spr_ruins_seal_tablet_spring;
            }
        },
        cleanup: function() {
            if self.sound_controller != undefined {
                self.sound_controller.force_stop();
            }
        },
    }
);
