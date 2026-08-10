object_create(
    "obj_beach_secret_build_mod_obj",
    undefined,
    {
        sprite_index: spr_beach_cave_door_spring_top,
        create: function() {
            self.interaction_trigger = undefined;
            self.trigger = undefined;
            self.red_blend_strength = 0;
            self.timer = 0;
            self.begin_destruction = false;
            self.depth = room_data_layer_depth(rm_beach, "Level_0_WallsNatural");

            self.cave_entrance = try_get_seasonal_sprite_alt(spr_beach_cave_door_spring) ?? spr_beach_cave_door_spring;
            var shadow_caster = SHADOW_GRID.caster_create(self.x, self.y);
            shadow_caster_set_sprite(shadow_caster, SHADOW_DICTIONARY.get(self.cave_entrance));

            if !world_mod_enabled(WorldMod.BeachSecret) {
                self.sprite_index = try_get_seasonal_sprite_alt(self.sprite_index) ?? sprite_index;

                var bbox_dims = shape_get_dimensions(spr_narrows_cave_entrance_spring_top);
                self.trigger = instance_create_layer(
                    x + 10,
                    y,
                    "Instances",
                    obj_fire_trigger,
                    {
                        image_xscale: bbox_dims[0],
                        image_yscale: bbox_dims[1],
                        cutscene: "beach_secret",
                        can_burn: function() {
                            return instance_exists(obj_ari)
                                && obj_ari.fsm.current_state_id() == PlayerState.Default;
                        },
                    }
                );

                self.interaction_trigger = instance_create_layer(
                    self.x,
                    self.y,
                    "Meta",
                    par_interactable,
                    {
                        //
                        mask_index: spr_narrows_cave_entrance_spring_top
                    }
                );
                with self.interaction_trigger {
                    self.register_interaction(
                        InputId.Interact,
                        "misc_local/inspect",
                        function() {
                            //
                            obj_ari.face_dir(point_direction(obj_ari.x, obj_ari.y, self.x, self.y));

                            obj_ari.set_idle_simple();
                            var conversation = GpTriggeredConversation.CannotOpenSecret;
                            if ARI.spells_learned[Spell.FireBreath] {
                                conversation = GpTriggeredConversation.CanOpenSecret;
                            }
                            play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[conversation]);
                        }
                    );
                }
            }
        },
        step: function() {
            var was_making_noise = !world_mod_enabled(WorldMod.BeachSecret)
                && self.red_blend_strength > 0.9;

            if self.begin_destruction {
                self.red_blend_strength = sin(self.timer * pi * FRAME_TIME - 1.5707) * 0.5 + 0.5;

                self.timer += 1;
                if self.timer >= 180 {
                    self.begin_destruction = false;
                    self.red_blend_strength = 1;
                }
            }

            if !world_mod_enabled(WorldMod.BeachSecret)
                && self.red_blend_strength > 0.9
            {
                CAMERA.max_offset.x = 20;
                CAMERA.add_trauma(0.2 + (self.timer div 60) * 0.1, 0.4);

                if was_making_noise == false {
                    if self.timer >= 120 {
                        TANGO.play("SoundEffects/SpecialEvents/CaveDoorDestruction");
                    } else {
                        TANGO.play("SoundEffects/SpecialEvents/ScreenShake");
                    }
                }
            }
        },
        draw: function() {
            draw_sprite(self.cave_entrance, 0, x, y);

            if !world_mod_enabled(WorldMod.BeachSecret) {
                draw_self();

                draw_sprite_ext(
                    self.sprite_index,
                    0,
                    x,
                    y,
                    1,
                    1,
                    0,
                    make_color_rgb(255, 40, 5),
                    self.red_blend_strength,
                );
            }
        },
        destroy: function() {
            if self.interaction_trigger != undefined {
                instance_destroy(self.interaction_trigger);
            }

            if self.trigger != undefined {
                instance_destroy(self.trigger);
            }
        },
    }
);
