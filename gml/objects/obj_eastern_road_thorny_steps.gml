object_create(
    "obj_eastern_road_thorny_steps",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            self.begin_destruction = false;
            self.timer = 0;
            self.depth = get_floor_depth() - 1;
            self.overlay_strength = 0;
            self.red_blend_strength = 0;
            self.red_blend_color = make_color_rgb(255, 40, 5)
            self.stairs_sprite = try_get_seasonal_sprite_alt(spr_easternroad_stairs_vines_spring) ?? spr_easternroad_stairs_vines_spring;

            self.collision_area = Vec4(128, 0, 140, 27);

            function update_collisions(on=true) {
                var grid = GRIDS[LocationId.EasternRoad];
                for (var i = self.collision_area.x1; i < self.collision_area.x2; i++) {
                    for (var j = self.collision_area.y1; j < self.collision_area.y2; j++) {
                        var ni = grid.node_index_for_cell(i, j);
                        var cache = grid.node_is_room_editor_collision[ni];
                        grid.node_is_room_editor_collision[ni] = RoomEditorCollision.None;
                        if on {
                            set_collision_on_node(grid, i, j);
                        } else {
                            remove_collision_on_node(grid, i, j);
                        }
                        grid.node_is_room_editor_collision[ni] = cache;
                    }
                }
            }

            if !world_mod_enabled(WorldMod.ThornyStairs) {
                self.update_collisions(true);
                self.trigger = instance_create_layer(
                    1016,
                    160,
                    "Instances",
                    obj_fire_trigger,
                    {
                        image_xscale: 114,
                        image_yscale: 60,
                        cutscene: "destroy_vines_eastern_road",
                        can_burn: function() { return true },
                    }
                );

                self.interaction_trigger = instance_create_layer(
                    self.x,
                    self.y,
                    "Meta",
                    par_interactable,
                    {
                        mask_index: spr_easternroad_stairs_vines_mask_spring
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
                            var conversation = GpTriggeredConversation.CannotPassVines;
                            if ARI.spells_learned[Spell.FireBreath] {
                                conversation = GpTriggeredConversation.VinesCanBeBurned;
                            }
                            play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[conversation]);
                        }
                    );
                }
            } else {
                self.update_collisions(false);
            }
        },
        step: function() {
            var was_making_noise = !world_mod_enabled(WorldMod.ThornyStairs)
                && self.red_blend_strength > 0.9;

            if self.begin_destruction {
                self.red_blend_strength = sin(self.timer * pi * FRAME_TIME - 1.5707) * 0.5 + 0.5;

                self.timer += 1;
                if self.timer >= 300 {
                    self.begin_destruction = false;
                    self.red_blend_strength = 1;
                }
            }

            if !world_mod_enabled(WorldMod.ThornyStairs)
                && self.red_blend_strength > 0.9
            {
                CAMERA.max_offset.x = 20;
                CAMERA.add_trauma(0.2 + (self.timer div 60) * 0.1, 0.4);

                if was_making_noise == false {
                    if self.timer >= 240 {
                        TANGO.play("SoundEffects/SpecialEvents/VinesDestruction");
                    } else {
                        TANGO.play("SoundEffects/SpecialEvents/ScreenShake");
                    }
                }
            }
        },
        draw: function() {
            with obj_assetobject {
                if self.sprite_index == spr_easternroad_stairs_broken_spring {
                    other.depth = self.depth - 1;
                    other.x = self.x;
                    other.y = self.y;
                }
            }

            if !world_mod_enabled(WorldMod.ThornyStairs) {
                gpu_set_extra(UberShaderKind.OverlayCorrect);
                draw_sprite_ext(
                    self.stairs_sprite,
                    0,
                    self.x,
                    self.y,
                    1,
                    1,
                    0,
                    self.red_blend_color,
                    self.red_blend_strength,
                );
                gpu_reset_extra();

                //
                draw_sprite_ext(
                    spr_easternroad_stairs_vines_mask_spring,
                    0,
                    self.x,
                    self.y,
                    1,
                    1,
                    0,
                    self.red_blend_color,
                    self.red_blend_strength * 0.5,
                );
            }
        },
        destroy: function() {

        },
    }
);
