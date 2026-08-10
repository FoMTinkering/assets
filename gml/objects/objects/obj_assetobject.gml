object_create(
    "obj_assetobject",
    undefined,
    {
        sprite_index: undefined,
        depth_offset: 0.0,
        do_not_set_depth: false,
        ignore_dungeon_decor: false,
        on_floor: false,
        original_blend: 0.0,
        seasonal: true,
        z: 0.0,
        create: function() {
            self.light = undefined;
            self.emitter = undefined;
            self.reciever = undefined;
            var original_sprite_name = undefined;

            //
            if is_dungeon_room(room()) && !is_special_dungeon_room(room()) && self.ignore_dungeon_decor == false {
                var dungeon_decor_kind = DUNGEON.sprite_to_decorations.get(self.sprite_index);
                if dungeon_decor_kind == undefined {
                    error("`{GmSprite}` in an asset layer in the dungeon but not a known DungeonDecoration!", self.sprite_index);
                } else {
                    var dungeon_decor = DUNGEON.decorations[dungeon_decor_kind.decoration_id];

                    //
                    x += dungeon_decor.offset.x;
                    y += dungeon_decor.offset.y;
                    z += dungeon_decor.depth_offset;
                    self.on_floor = dungeon_decor.on_floor;

                    var base_x = x div 8 + dungeon_decor.collision_offset.x;
                    var base_y = y div 8 + dungeon_decor.collision_offset.y;

                    //
                    for (var i = 0; i < dungeon_decor.size.x; i++) {
                        for (var j = 0; j < dungeon_decor.size.y; j++) {
                            var col_flag = dungeon_decor.collision_grid[# i, j];
                            if col_flag != 0 {
                                set_collision_on_node(GRID, base_x + i, base_y + j, col_flag == 1);
                            }
                        }
                    }

                    if dungeon_decor.top_sprites != undefined {
                        create_animation_effect(x, y, -2000, dungeon_decor.top_sprites[dungeon_decor_kind.spr_index], true);
                    }

                    if dungeon_decor.light != undefined {
                        self.light = instance_create_depth(
                            self.x + dungeon_decor.light_offset.x,
                            self.y + dungeon_decor.light_offset.y,
                            -10000,
                            par_light
                        );
                        self.light.secondary = true;
                        self.light.depth_override = true;
                        self.light.tiered_light = dungeon_decor.light;
                        self.light.sprite_index = LIGHTS[dungeon_decor.light][0];
                        self.image_index = irandom(sprite_get_number(self.sprite_index));
                        self.light.image_index = image_index;
                        self.image_speed = 1;
                    } else {
                        self.light = undefined;
                    }

                    if dungeon_decor.sound != undefined {
                        self.emitter = instance_create_depth(x, y, 0, obj_sound_emitter, {
                            sound_asset: dungeon_decor.sound
                        });
                        self.emitter.apply_bbox(x, y, x + dungeon_decor.sound_emitter_size.x, y + dungeon_decor.sound_emitter_size.y);
                    } else {
                        self.emitter = undefined;
                    }

                    if dungeon_decor.dark_light != undefined {
                        var trigger = instance_create_depth(self.x, self.y, self.depth, obj_dark_light_trigger);
                        trigger.dad = self;
                        trigger.tiered_dark_light = dungeon_decor.dark_light.light;
                        trigger.dark_light = dungeon_decor.light;
                        trigger.dad_sprite = dungeon_decor.dark_light.sprite;
                        trigger.receiver = create_receiver(self.x, self.y, self.sprite_index, trigger, {
                            target: CombatTarget.Enemy
                        });
                    }
                }
            } else if self.seasonal {
                var alt_sprite = try_get_seasonal_sprite_alt(self.sprite_index);
                if alt_sprite != undefined {
                    original_sprite_name = asset_to_string(self.sprite_index);
                    self.sprite_index = alt_sprite;
                }
            }

            self.z += self.depth_offset;

            self.shadow_caster = SHADOW_GRID.caster_create(x, y);
            shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(sprite_index));
            self.from_room_service = false;

            if self.do_not_set_depth == false {
                depth = get_instance_depth(y, z);

                if self.on_floor {
                    //
                    self.depth = get_floor_depth();
                }
            }

            var spr_name = asset_to_string(self.sprite_index);
            self.flavor_information = FLAVOR_TEXT.get(spr_name);
            if self.flavor_information != undefined {
                object_event(object("par_interactable"), ObjectEvent.Create)();
                self.override_mask = self.flavor_information.override_mask;

                self.register_interaction(
                    InputId.Interact,
                    self.flavor_information.glyph_action,
                    function() {
                        obj_ari.set_idle_simple();
                        if self.flavor_information.alternative != undefined
                            && requirements_pass(self.flavor_information.alternative.requirements)
                        {
                            play_conversation(NpcId.Caldarus, self.flavor_information.alternative.flavor_text);
                        } else {
                            play_conversation(NpcId.Caldarus, self.flavor_information.flavor_text);
                        }
                    },
                    function() {
                        return true;
                    }
                );
            }

            var light_data = EXTERIOR_LIGHTS.get(spr_name);
            if light_data != undefined {
                self.visible = false;
                self.image_blend = make_color_rgb(232, 180, 134);
                self.image_alpha = 0.0;
                self.light = instance_create_depth(
                    x,
                    y,
                    depth,
                    obj_exterior_light,
                    {
                        sprite_index: light_data,
                    }
                );
                self.light.light_insert = self;

                if CLOCK.time >= LIGHT_TURN_ON_TIME || WEATHER.is_inclement() || MIST.blackboard.get("force_lights_on") == true {
                    self.light.time_offset = 0;
                    self.light.turn_on();
                }
            }

            //
            var light_data = INTERIOR_LIGHTS.get(spr_name);
            if light_data != undefined {
                self.light = instance_create_depth(
                    self.x + light_data.offset.x,
                    self.y + light_data.offset.y,
                    -10000,
                    par_light,
                );
                self.light.depth_override = true;
                self.light.tiered_light = light_data.light;
                self.light.sprite_index = LIGHTS[self.light.tiered_light][0];
            }

            var transparency_boxes = TRANSPARENT_ASSETS.get(spr_name) ?? TRANSPARENT_ASSETS.get(original_sprite_name);
            if transparency_boxes != undefined {
                for (var i = 0; i < array_length(transparency_boxes); i++) {
                    var transparency_box = transparency_boxes[i];
                    var inst = instance_create_depth(
                        self.x + transparency_box.offset.x,
                        self.y + transparency_box.offset.y,
                        0,
                        obj_transparency_detector,
                        {
                            image_xscale: transparency_box.size.x,
                            image_yscale: transparency_box.size.y,
                        }
                    );
                    inst.asset_object_target = self;
                }
            }
        },
        draw: function() {
            if self.flavor_information != undefined && self.flavor_information.highlight {
                object_event(object("par_interactable"), ObjectEvent.Draw)();
            } else {
                draw_self();
            }
        },
        destroy: function() {
            if self.light != undefined {
                instance_destroy(self.light);
            }

            if is_dungeon_room(room()) {
                if self.emitter != undefined {
                    instance_destroy(self.emitter);
                }
            }
        },
        cleanup: function() {
            SHADOW_GRID.caster_remove(self.shadow_caster);

            if is_dungeon_room(room()) {
                var dungeon_decor = DUNGEON.sprite_to_decorations.get(self.sprite_index);
                if dungeon_decor != undefined {
                    var dungeon_decor_kind = dungeon_decor.decoration_id;
                    if dungeon_decor_kind != undefined {
                        var dungeon_decor = DUNGEON.decorations[dungeon_decor_kind];

                        //
                        var base_x = x div 8 + dungeon_decor.collision_offset.x;
                        var base_y = y div 8 + dungeon_decor.collision_offset.y;

                        remove_collision_on_node_region(GRID, base_x, base_y, base_x + dungeon_decor.size.x - 1, base_y + dungeon_decor.size.y - 1);
                    }
                }
            }
        },
    }
);
