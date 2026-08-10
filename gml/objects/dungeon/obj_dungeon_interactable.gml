object_create(
    "obj_dungeon_interactable",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_main_dungeon_prototype_instance_special_lever,
        activated_sprite: string_to_asset("spr_dungeon_mines_biome_1_lever_spring_activated"),
        activates_ladder: true,
        deactivated_sprite: string_to_asset("spr_dungeon_mines_biome_1_lever_spring_deactivated"),
        interact_sound_effect: "SoundEffects/Objects/SwitchThrow",
        transition_sprite: string_to_asset("spr_dungeon_mines_biome_1_lever_spring_transition"),
        create: function() {
            event_inherit(ObjectEvent.Create);
            self.state = InteractState.Deactivated;

            function dungeon_init() {
                depth = get_instance_depth(y);
                self.state = InteractState.Deactivated;
                //
                var ox = self.x div 8;
                var oy = self.y div 8;
                set_collision_on_node_region(GRID, ox, oy, ox + 1, oy + 1, true);

                self.x += 8;
                self.y += 8;

                var biome = is_dungeon_room(room()) ? DUNGEON_BIOME : DungeonBiome.Upper;
                switch biome {
                    case DungeonBiome.Upper:
                        self.deactivated_sprite = spr_dungeon_mines_biome_1_lever_spring_deactivated;
                        self.activated_sprite = spr_dungeon_mines_biome_1_lever_spring_activated;
                        self.transition_sprite = spr_dungeon_mines_biome_1_lever_spring_transition;
                        break;
                    case DungeonBiome.TideCaverns:
                        self.deactivated_sprite = spr_dungeon_mines_biome_2_lever_spring_deactivated;
                        self.activated_sprite = spr_dungeon_mines_biome_2_lever_spring_activated;
                        self.transition_sprite = spr_dungeon_mines_biome_2_lever_spring_transition;
                        break;
                    case DungeonBiome.DeepEarth:
                        self.deactivated_sprite = spr_dungeon_mines_biome_3_lever_spring_deactivated;
                        self.activated_sprite = spr_dungeon_mines_biome_3_lever_spring_activated;
                        self.transition_sprite = spr_dungeon_mines_biome_3_lever_spring_transition;
                        break;
                    case DungeonBiome.LavaCaves:
                        self.deactivated_sprite = spr_dungeon_mines_biome_4_lever_spring_deactivated;
                        self.activated_sprite = spr_dungeon_mines_biome_4_lever_spring_activated;
                        self.transition_sprite = spr_dungeon_mines_biome_4_lever_spring_transition;
                        break;
                    case DungeonBiome.Ruins:
                        self.deactivated_sprite = spr_dungeon_mines_biome_5_lever_spring_deactivated;
                        self.activated_sprite = spr_dungeon_mines_biome_5_lever_spring_activated;
                        self.transition_sprite = spr_dungeon_mines_biome_5_lever_spring_transition;
                        break;
                }

                self.sprite_index = self.deactivated_sprite;

                self.shadow_caster = SHADOW_GRID.caster_create(x, y);
                shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));

                self.register_interaction(
                    InputId.Interact,
                    "misc_local/activate",
                    function() {
                        if self.interact_sound_effect != undefined {
                            TANGO.play(interact_sound_effect, x, y);
                        }

                        create_animation_effect(
                            x - 4,
                            y - 4,
                            self.depth - 100000,
                            spr_fx_poof1_dirt_once
                        );
                        CAMERA.add_trauma(0.3);

                        self.state = InteractState.Transition;
                        self.image_index = 0;
                        self.sprite_index = transition_sprite;
                        if self.activates_ladder {
                            with obj_dungeon_ladder_down {
                                self.try_open();
                            }
                        }
                    },
                    function() {
                        return state == InteractState.Deactivated;
                    },
                );
            }
        },
        animation_end: function() {
            switch(state) {
                case InteractState.Activated:
                    break;
                case InteractState.Transition:
                    state = InteractState.Activated;
                    sprite_index = activated_sprite;
                    shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));
                    create_animation_effect(
                        x + 4,
                        y - 4,
                        self.depth - 100000,
                        spr_fx_poof1_dirt_once
                    );
                    CAMERA.add_trauma(0.4);
                    break;
                case InteractState.Deactivated:
                    break;
            }
        },
    }
);
