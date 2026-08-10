object_create(
    "obj_horse_statue",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_narrows_horse_statue_spring_off,
        create: function() {
            //
            event_inherit(ObjectEvent.Create);

            if !requirements_pass(Requirement.RepairedHorseStatue) {
                instance_destroy();
                return;
            }

            var shadow_caster = SHADOW_GRID.caster_create(x, y);
            shadow_caster_set_sprite(shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));

            self.mask_index = self.sprite_index;
            self.image_speed = 0;

            self.register_interaction(
                InputId.Interact,
                "misc_local/use_shrine",
                function() {
                    ANCHOR.spawn_menu(Menu.DragonShrine, ShrineMenuVariant.Horse);
                },
                function() {
                    return ARI.mount != undefined;
                }
            );

            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    var convo = GpTriggeredConversation.HorseStatueInspect;
                    var callback = function(driver) {
                        if driver.prompt_index_selected == 0 {
                            TANGO.play("SoundEffects/Objects/UseChickenStatue");

                            ARI.modify_essence(-100);

                            self.sprite_index = spr_narrows_horse_statue_spring_on;
                            self.image_speed = 1;

                            MIST.request_scene("reveal_mistmare");

                            ARI.mount = create_default_mount("mistmare");

                            //
                            if BINDINGS.get_primary_binding(InputId.Ride) == undefined {
                                new_chain()
                                    .append(LinkId.Await, function() {
                                        return !MIST.is_running();
                                    })
                                    .append(LinkId.Function, function() {
                                        var pop = popup_creator("misc_local/missing_input", "misc_local/missing_mount_input_description");
                                        pop.create_button("misc_local/close");
                                        pop.spawn();
                                    })
                            }
                        }

                    };

                    var driver = play_conversation_from_path(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[convo], callback);

                    if ARI.get_essence() < 100 {
                        driver.textbox.prompt_one.blackboard.insert("stay_locked", true);
                    }
                },
                function() {
                    return ARI.mount == undefined;
                }
            );

            depth = get_instance_depth(y);

            var grid = GRIDS[LocationId.Narrows];
            for (var xx = 38; xx <= 43; xx++) {
                for (var yy = 97; yy <= 101; yy++) {
                    erase_object_node(grid, grid.node_index_for_cell(xx, yy));
                }
            }
        },
        animation_end: function() {
            self.sprite_index = spr_narrows_horse_statue_spring_off;
            self.image_speed = 0;
        },
    }
);
