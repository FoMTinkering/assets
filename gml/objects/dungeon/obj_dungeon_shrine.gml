object_create(
    "obj_dungeon_shrine",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_dungeon_mines_offering_spring_on,
        create: function() {
            function dungeon_init() {
                object_event(object("par_interactable"), ObjectEvent.Create)();
                depth = get_instance_depth(y);
                self.can_use = true;

                //
                self.mask_index = self.sprite_index;

                self.shrine_type = irandom(Shrine.LEN - 1);

                var biome = DUNGEON.biomes[current_dungeon_biome() ?? DungeonBiome.Upper];
                var input = biome.shrine.inputs[irandom(array_length(biome.shrine.inputs) - 1)];
                self.item_id = input.item_id;
                self.quantity = input.amount;

                self.x += 8;
                self.y += 8;

                //
                var ox = self.x div 8;
                var oy = (self.y div 8) + 1;
                set_collision_on_node_region(GRID, ox - 2, oy - 2, ox + 1, oy, false);

                //
                self.shadow_caster = SHADOW_GRID.caster_create(x, y);
                shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));

                //
                var fiddle_data = fiddle_get("interaction/dungeon_shrine_offset");
                self.offset_x = fiddle_data[0];
                self.offset_y = fiddle_data[1];

                switch self.shrine_type {
                    case Shrine.Health:
                        self.small_icon = spr_ui_bark_icon_health_small;
                        self.big_icon = spr_ui_bark_icon_health;
                        break;
                    case Shrine.Stamina:
                        self.small_icon = spr_ui_bark_icon_stamina_small;
                        self.big_icon = spr_ui_bark_icon_stamina;
                        break;
                    case Shrine.Essence:
                        self.small_icon = spr_ui_bark_icon_essence_small;
                        self.big_icon = spr_ui_bark_icon_essence;
                        break;
                }

                self.register_interaction(
                    InputId.Interact,
                    "misc_local/give_offering",
                    function() {
                        OFFERING_ITEM_NAME = local_get(ITEM_PROTOTYPES[self.item_id].name_key);
                        OFFERING_ITEM_COUNT = string(self.quantity);

                        var driver = play_conversation_from_path(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.OfferingInteraction], function(driver) {
                            if driver.prompt_index_selected == 0 {
                                TANGO.play("SoundEffects/Objects/UseChickenStatue");
                                self.sprite_index = spr_dungeon_mines_offering_spring_shine;
                                ARI.inventory.remove(self.item_id, self.quantity);
                                self.can_use = false;
                            }
                        });

                        if ARI.inventory.item_id_quantity(self.item_id) < self.quantity {
                            driver.textbox.prompt_one.blackboard.insert("stay_locked", true);
                        }
                    },
                    function() {
                        return self.can_use;
                    }
                );
            }
        },
        draw: function() {
            if self.can_use {
                if self.highlighter.update(x, y) {
                    gpu_set_extra(UberShaderKind.Overlay);
                    draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, 0, self.highlighter.color, self.highlighter.strength);
                    gpu_reset_extra();
                } else {
                    draw_self();
                }
            } else {
                draw_self();
            }
        },
        draw_end: function() {
            //
            if has_flag(PAUSE_STATUS, PauseStatus.CUTSCENE) || has_flag(PAUSE_STATUS, PauseStatus.MENU)  {
                return;
            }

            //
            if self.can_use == false {
                return;
            }

            self.bouncer.status = InteractBounceStatus.Distant;
            self.bouncer.alpha = BARK_MIN_ALPHA;

            var is_being_selected = self.bouncer.update();

            if is_being_selected {
                draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(self.big_icon, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            } else {
                draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(self.small_icon, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            }
        },
        animation_end: function() {
            if self.sprite_index != spr_dungeon_mines_offering_spring_shine {
                return;
            }

            self.sprite_index = spr_dungeon_mines_offering_spring_on;

            var biome = DUNGEON.biomes[current_dungeon_biome() ?? DungeonBiome.Upper];
            var amount = biome.shrine.outputs[self.shrine_type];
            var type;
            switch self.shrine_type {
                case Shrine.Health:
                    type = MorselType.Health;
                    break;
                case Shrine.Stamina:
                    type = MorselType.Stamina;
                    break;
                case Shrine.Essence:
                    type = MorselType.Essence;
                    //
                    amount *= 10;
                    break;
                default: impossible("Unexpected Shrine: {}", self.shrine_type);
            }

            if ARI.perk_active(Perk.ShrineSavant) {
                var time = CALENDAR.unified_time();
                ARI.status_effects.register(
                    StatusEffectId.ShrineBoon,
                    undefined,
                    time,
                    time + minutes(fiddle_get("perks/shrine_savant/duration_minutes")),
                );
                GAME_STATS.perks[$ perk_to_string(Perk.ShrineSavant)] += 1;
            }

            create_morsels(self.x, self.y + 8, 32, type, amount, self.depth);
        },
    }
);
