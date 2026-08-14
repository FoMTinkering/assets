object_create(
    "par_ladder",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_main_dungeon_prototype_instance_door_ladder_down,
        state: LadderState.Spawned,
        create: function() {
            event_inherit(ObjectEvent.Create, par_interactable);

            self.xstart = self.x;
            self.ystart = self.y;

            self.allowed_in_fire_spell = true;
            self.want_to_spawn_collision = false;

            //
            function dungeon_init() {
                self.x += 8;
                if self.object_index == obj_dungeon_ladder_up {
                    self.y += 8;
                }

                self.shadow_caster = SHADOW_GRID.caster_create(x, y);
                shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(sprite_index));

                self.set_state(self.state ?? LadderState.Spawned);
            }

            //
            function try_open() {
                switch self.state {
                    case LadderState.TrapdoorClosed:
                        self.set_state(LadderState.TrapdoorOpening);
                        break;
                    case LadderState.Unspawned:
                        self.set_state(LadderState.Spawned);
                        create_animation_effect(x, y, depth - 1, spr_fence_create_poof_strip5);
                        break;
                    default: break;
                }
            }

            //
            function set_state(state) {
                self.state = state;

                //
                //
                var biome = is_dungeon_room(room()) ? DUNGEON_BIOME : DungeonBiome.Upper;
                if self.state == LadderState.Spawned {
                    self.want_to_spawn_collision = true;
                } else {
                    var ox = self.xstart div 8;
                    var oy = self.ystart div 8;
                    remove_collision_on_node_region(GRID, ox, oy, ox + 1, oy + 1);
                }

                //
                self.image_speed = 0;
                depth = get_instance_depth(y);
                if self.state == LadderState.Unspawned {
                    self.sprite_index = spr_nothing;
                } else if object_index == obj_dungeon_ladder_up {
                    switch biome {
                        case DungeonBiome.Upper:
                            self.sprite_index = spr_dungeon_mines_biome_1_ladder_up_spring;
                            break;
                        case DungeonBiome.TideCaverns:
                            self.sprite_index = spr_dungeon_mines_biome_2_ladder_up_spring;
                            break;
                        case DungeonBiome.DeepEarth:
                            self.sprite_index = spr_dungeon_mines_biome_3_ladder_up_spring;
                            break;
                        case DungeonBiome.LavaCaves:
                            self.sprite_index = spr_dungeon_mines_biome_4_ladder_up_spring;
                            break;
                        case DungeonBiome.Ruins:
                            self.sprite_index = spr_dungeon_mines_biome_5_ladder_up_spring;
                            break;
                        default: impossible("Unexpected DungeonBiome: {}", biome);
                    }
                } else {
                    switch self.state {
                        case LadderState.Spawned:
                        case LadderState.TrapdoorOpening:
                            switch biome {
                                case DungeonBiome.Upper:
                                    self.sprite_index = spr_dungeon_mines_biome_1_trapdoor_swing;
                                    break;
                                case DungeonBiome.TideCaverns:
                                    self.sprite_index = spr_dungeon_mines_biome_2_trapdoor_swing;
                                    break;
                                case DungeonBiome.DeepEarth:
                                    self.sprite_index = spr_dungeon_mines_biome_3_trapdoor_swing;
                                    break;
                                case DungeonBiome.LavaCaves:
                                    self.sprite_index = spr_dungeon_mines_biome_4_trapdoor_swing;
                                    break;
                                case DungeonBiome.Ruins:
                                    self.sprite_index = spr_dungeon_mines_biome_5_trapdoor_swing;
                                    break;
                                default: impossible("Unexpected DungeonBiome: {}", biome);
                            }
                            break;
                        case LadderState.TrapdoorClosed:
                            self.depth = get_floor_depth();
                            switch biome {
                                case DungeonBiome.Upper:
                                    self.sprite_index = spr_dungeon_mines_biome_1_trapdoor_closed;
                                    break;
                                case DungeonBiome.TideCaverns:
                                    self.sprite_index = spr_dungeon_mines_biome_2_trapdoor_closed;
                                    break;
                                case DungeonBiome.DeepEarth:
                                    self.sprite_index = spr_dungeon_mines_biome_3_trapdoor_closed;
                                    break;
                                case DungeonBiome.LavaCaves:
                                    self.sprite_index = spr_dungeon_mines_biome_4_trapdoor_closed;
                                    break;
                                case DungeonBiome.Ruins:
                                    self.sprite_index = spr_dungeon_mines_biome_5_trapdoor_closed;
                                    break;
                                default: impossible("Unexpected DungeonBiome: {}", biome);
                            }
                            break;
                    }

                    self.image_index = self.state == LadderState.Spawned ? sprite_get_number(self.sprite_index) - 1 : 0;
                    self.image_speed = self.state == LadderState.TrapdoorOpening ? 1 : 0;
                }

                shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));
            }

            self.highlighter = new Highlighter();

            //
            var can_interact = function() {
                return
                    !TAXI.is_traveling()
                    && (self.state == LadderState.Spawned|| self.state == LadderState.TrapdoorOpening)
                    && ARI.held_animal_id == undefined //
            }

            if object_index == obj_dungeon_ladder_up {
                mask_index = spr_mask_ladder_up;
                self.register_interaction(
                    InputId.Interact,
                    "misc_local/ascend",
                    function() {
                        var popup = popup_creator("misc_local/return_to_surface", "misc_local/confirm_leave_dungeon")
                        popup.create_button("misc_local/no");
                        popup.create_button("misc_local/yes", function() {
                            TANGO.play("SoundEffects/Entrances/LadderDescend");
                            var pos = trellis_point("mines_entry/dungeon entry");
                            goto_location_id(LocationId.MinesEntry).set_exact_position(pos.x, pos.y);
                            DUNGEON_RUNNER.exit_mines_stats_condition = "ascended";

                            obj_ari.fsm.change_state(PlayerState.Dummy);
                        });
                        popup.spawn();
                    },
                    can_interact,
                );
            } else {
                mask_index = spr_mask_ladder_down;
                self.register_interaction(
                    InputId.Interact,
                    "misc_local/descend",
                    function() {
                        TANGO.play("SoundEffects/Entrances/LadderDescend");
                        if room() == rm_mines_entry {
                            enter_dungeon();
                        } else {
                            DUNGEON_RUNNER.proceed("descended");
                        }
                        obj_ari.fsm.change_state(PlayerState.Dummy);
                    },
                    can_interact,
                );
            }
        },
        animation_end: function() {
            if self.state == LadderState.TrapdoorOpening {
                self.set_state(LadderState.Spawned);
            }
        },
    }
);
