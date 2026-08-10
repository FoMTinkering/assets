object_create(
    "obj_seal_altar",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_water_seal_altar_spring,
        item_id: "id not set",
        sin_wave_offset: 0,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.item_id = string_to_item_id(self.item_id);
            self.icon_sprite = ITEM_PROTOTYPES[self.item_id].icon_sprite;
            light = undefined;
            self.sin_offset = 0;
            self.run_sin = true;
            self.seal_id = room() == rm_seridias_chamber ? Seal.Final : obj_seal_tablet.seal_id;
            self.icon_override = self.seal_id == Seal.Void;
            self.icon_x_offset = 5;

            if self.seal_id != Seal.Void {
                SHADOW_WAIT_LIST.push({
                    x,
                    y,
                    sprite: SHADOW_DICTIONARY.get(self.sprite_index),
                });
            }

            switch self.seal_id {
                case Seal.Water:
                    self.sprite_index = spr_water_seal_altar_spring;
                    break;
                case Seal.Earth:
                    self.sprite_index = spr_earth_seal_altar_spring;
                    break;
                case Seal.Fire:
                    self.sprite_index = spr_fire_seal_altar_spring;
                    break;
                case Seal.Ruins:
                    self.sprite_index = spr_ruins_seal_altar_spring;
                    break;
                case Seal.Void:
                    self.sprite_index = spr_void_seal_volumetric_light_medium;
                    self.icon_x_offset = 0;
                    break;
                case Seal.Final:
                    self.sprite_index = spr_seridias_chamber_altar_spring;
                    break;
                default: impossible("Unexpected Seal: {Seal}", self.seal_id);
            }

            if self.seal_id != Seal.Final {
                self.register_interaction(
                    InputId.Interact,
                    "misc_local/inspect",
                    function() {
                        //
                        obj_ari.face_dir(point_direction(obj_ari.x, obj_ari.y, self.x, self.y));
                        obj_ari.set_idle_simple();

                        var q = QUEST_LOG.active.get(obj_seal_tablet.quest);

                        if q != undefined && (q.current_stage > 0 || self.seal_id == Seal.Void) {
                            var convo;
                            switch self.item_id {
                                case ItemId.LanternMoth:
                                    convo = GpTriggeredConversation.InspectLanternMothClaw;
                                    break;
                                case ItemId.StoneLoach:
                                    convo = GpTriggeredConversation.InspectStoneLoachClaw;
                                    break;
                                case ItemId.UpperMinesMushroom:
                                    convo = GpTriggeredConversation.InspectUpperMinesMushroomClaw;
                                    break;
                                case ItemId.OreRuby:
                                    convo = GpTriggeredConversation.InspectRubyClaw;
                                    break;
                                case ItemId.CoralMantis:
                                    convo = GpTriggeredConversation.InspectCoralMantisClaw;
                                    break;
                                case ItemId.Archerfish:
                                    convo = GpTriggeredConversation.InspectArcherfishClaw;
                                    break;
                                case ItemId.CaveKelp:
                                    convo = GpTriggeredConversation.InspectCaveKelpClaw;
                                    break;
                                case ItemId.OreSapphire:
                                    convo = GpTriggeredConversation.InspectSapphireClaw;
                                    break;
                                case ItemId.Shardfin:
                                    convo = GpTriggeredConversation.InspectShardfinClaw;
                                    break;
                                case ItemId.CrystalBerries:
                                    convo = GpTriggeredConversation.InspectCrystalBerryClaw;
                                    break;
                                case ItemId.Crystal:
                                    convo = GpTriggeredConversation.InspectCrystalClaw;
                                    break;
                                case ItemId.DeepEarthworm:
                                    convo = GpTriggeredConversation.InspectDeepEarthwormClaw;
                                    break;
                                case ItemId.FacetedRockGem:
                                    convo = GpTriggeredConversation.InspectFacetedRockGemClaw;
                                    break;
                                case ItemId.Rockroot:
                                    convo = GpTriggeredConversation.InspectRockrootClaw;
                                    break;
                                case ItemId.OreEmerald:
                                    convo = GpTriggeredConversation.InspectEmeraldClaw;
                                    break;
                                case ItemId.SealingScroll:
                                    convo = GpTriggeredConversation.InspectSealingScrollClaw;
                                    break;
                                case ItemId.VoidStone:
                                    convo = GpTriggeredConversation.InspectVoidStoneClaw;
                                    break;
                                case ItemId.VoidPowder:
                                    convo = GpTriggeredConversation.InspectVoidPowderClaw;
                                    break;
                                case ItemId.VoidHerb:
                                    convo = GpTriggeredConversation. InspectVoidHerbClaw;
                                    break;
                                case ItemId.VoidPearl:
                                    convo = GpTriggeredConversation. InspectVoidPearlClaw;
                                    break;
                                case ItemId.BreathOfFire:
                                    convo = GpTriggeredConversation.InspectBreathOfFireClaw;
                                    break;
                                case ItemId.SmokeMoth:
                                    convo = GpTriggeredConversation.InspectSmokeMothClaw;
                                    break;
                                case ItemId.FiresailFish:
                                    convo = GpTriggeredConversation.InspectFiresailFishClaw;
                                    break;
                                case ItemId.Obsidian:
                                    convo = GpTriggeredConversation.InspectObsidianClaw;
                                    break;
                                case ItemId.DragonForgedFang:
                                    convo = GpTriggeredConversation.InspectDragonForgedFangClaw;
                                    break;
                                case ItemId.DragonForgedHorn:
                                    convo = GpTriggeredConversation.InspectDragonForgedHornClaw;
                                    break;
                                case ItemId.DragonForgedCore:
                                    convo = GpTriggeredConversation.InspectDragonForgedCoreClaw;
                                    break;
                                case ItemId.DragonForgedPowder:
                                    convo = GpTriggeredConversation.InspectDragonForgedPowderClaw;
                                    break;
                                default: impossible("Unexpected ItemId: {ItemId}", self.item_id);
                            }
                            play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[convo]);
                        } else {
                            play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectClaw]);
                        }
                    },
                    function() {
                        return obj_seal_tablet.quest != undefined && !QUEST_LOG.completed.contains(obj_seal_tablet.quest);
                    }
                );
            }

            depth = get_instance_depth(y);
        },
        step: function() {
            self.sin_offset = self.run_sin
                ? -sin(self.sin_wave_offset * pi + TICK * pi / 120)
                : 0;

            if self.seal_id != Seal.Void && SEAL_INVENTORIES[self.seal_id].item_id_quantity(self.item_id) != 0 {
                if self.light == undefined {
                    self.light = instance_create_depth(
                        self.x + 5,
                        self.y - 21 + self.sin_offset,
                        self.depth,
                        par_light,
                    );
                    self.light.tiered_light = Light.Xs;
                    self.light.sprite_index = LIGHTS[Light.Xs][0];
                } else {
                    self.light.y = self.y - 21 + self.sin_offset;
                }
            }
        },
        draw: function() {
            draw_self();

            if self.item_id == ItemId.SealingScroll && requirements_pass(Requirement.BrokeFireSeal) {
                return;
            }

            if self.seal_id == Seal.Ruins && !MIST.scene_history.contains("break_ruins_seal_pt_3") && !self.icon_override {
                return;
            }

            if self.icon_sprite != undefined && (self.icon_override || SEAL_INVENTORIES[self.seal_id].item_id_quantity(self.item_id) != 0) {
                draw_sprite(self.icon_sprite, 0, x + self.icon_x_offset, y - 21 + self.sin_offset);
            }
        },
        draw_end: function() {
            //
        },
        animation_end: function() {
            if self.sprite_index == spr_ruins_seal_altar_cutscene_spring_start {
                self.sprite_index = spr_ruins_seal_altar_cutscene_spring_loop;
            }
            if self.sprite_index == spr_ruins_seal_altar_cutscene_spring_end {
                self.sprite_index = spr_ruins_seal_altar_spring;
            }
        },
    }
);
