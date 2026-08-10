enum UseItemSuccess {
    //
    None,
    //
    Remove,
    //
    //
    RemoveLater,
}

//
//
//
function use_item(item, target_pos) {
    if !is_struct(item) {
        item = new LiveItem(item);
    }
    obj_ari.fsm.blackboard.set("target_pos", target_pos);
    obj_ari.fsm.blackboard.set("execute_instantly", false);
    if item.auto_use == false {
        obj_ari.fsm.blackboard.set("live_item", item);
    }

    var ni = GRID.try_node_index_for_cell(target_pos.x, target_pos.y);

    switch item.prototype.use {
        case ItemUse.IdentifyItem:
        case ItemUse.OpenChest:
        case ItemUse.Consume:
        case ItemUse.ApplyOil:
        case ItemUse.LearnRecipe:
        case ItemUse.UnlockCosmetic:
        case ItemUse.UnlockAnimalCosmetic:
        case ItemUse.UnlockPetCosmetic:
        case ItemUse.UnlockPetSkin:
        case ItemUse.UnlockDate:
        case ItemUse.UnlockSong:
        case ItemUse.GainGold:
        case ItemUse.CrackEssenceStone:
        case ItemUse.CrackEgg:
        case ItemUse.UnpackBundle:
            obj_ari.fsm.change_state(PlayerState.HoldToUse);
            return UseItemSuccess.RemoveLater;
        case ItemUse.ExpandInventory:
            if item.prototype.new_inventory_size == ARI.inventory.size() + 10 {
                obj_ari.fsm.change_state(PlayerState.HoldToUse);
                return UseItemSuccess.RemoveLater;
            } else {
                return undefined;
            };
            break;
        case ItemUse.GainGoldInstant:
            ARI.modify_gold(item.gold_to_gain);
            array_push(GAME_STATS.income, {
                type: "mob_coin",
                amount: item.gold_to_gain,
                day: total_days(),
            });
            return UseItemSuccess.None;
        case ItemUse.Bomb:
            //
            return UseItemSuccess.None;
        case ItemUse.Flooring:
        case ItemUse.Wallpaper:
            if !is_home_location(CURRENT_LOCATION_ID) {
                break;
            }
            obj_ari.fsm.change_state(PlayerState.HoldToUse);
            return UseItemSuccess.RemoveLater;
        case ItemUse.PlaceTile:
            if GRID.item_effects_node_at_cell(target_pos.x, target_pos.y, item.prototype) == false {
                break;
            }

            GRID.node_terrain_variant[ni] = item.prototype.tile_placement.index;
            write_terrain_tile_to_tilemap(GRID, target_pos.x, target_pos.y);

            TANGO.play("SoundEffects/UI/UIRotateBuilding");

            //
            obj_tile_cursor.select();
            if obj_ari.using_mouse {
                obj_ari.face_cell(target_pos.x, target_pos.y);
            }

            return UseItemSuccess.Remove;
        case ItemUse.PlaceObject:
            //
            if ni == undefined
                || (array_contains(NODE_PROTOTYPES[item.prototype.object].placeable_locations, CURRENT_LOCATION_ID) == false
                    && (NODE_PROTOTYPES[item.prototype.object].house_stairs == undefined
                        || array_contains(NODE_PROTOTYPES[NODE_PROTOTYPES[item.prototype.object].house_stairs.paired_object].placeable_locations, CURRENT_LOCATION_ID) == false)
                    )
            {
                break;
            }

            var success = false;
            switch object_id_to_object_category(item.prototype.object) {
                case ObjectCategory.Furniture:
                    //
                    var off = center_offset_furniture(item.prototype.object, obj_ari.cardinal_placement);
                    success = GRID.write_node(
                        target_pos.x + off.x,
                        target_pos.y + off.y,
                        item.prototype.object,
                        obj_ari.cardinal_placement
                    );

                    if success {
                        var old = GAME_STATS.furniture_placed[$ object_id_to_string(item.prototype.object)] ?? 0;
                        GAME_STATS.furniture_placed[$ object_id_to_string(item.prototype.object)] = old + 1;
                    }
                    break;
                default: crash("Unexpected Object Category used!");
            }
            if success {
                TANGO.play("SoundEffects/UI/UIPlaceBuilding");
                set_rumble(RumbleKind.FurniturePlace);

                //
                success.infusion = try_infusion_to_string(item.infusion);

                success.date_photo = item.date_photo;
                return UseItemSuccess.Remove;
            }
            break;
        case ItemUse.Blueprint:
            //
            if CURRENT_LOCATION_ID != LocationId.Farm || ni == undefined {
                break;
            }

            var success = write_blueprint_to_location(GRID, (target_pos.x div 2) * 2, (target_pos.y div 2) * 2, item.prototype.blueprint.blueprint, item_id_to_string(item.prototype.item_id));

            if success {
                TANGO.play("SoundEffects/UI/UIPlaceBuilding");
                set_rumble(RumbleKind.FurniturePlace);
                return UseItemSuccess.Remove;
            }
            break;
        case ItemUse.UseTool:
        case ItemUse.Attack:
        case ItemUse.PlantSeed:
        case ItemUse.PlantGrass:
        case ItemUse.PlantSapling:
            //
            if ARI.get_stamina() <= 0
                && item.prototype.use != ItemUse.Attack //
                && item.prototype.stamina_cost < 0  //
            {
                obj_ari.fsm.change_state(PlayerState.AnimateAndThen);
                obj_ari.fsm.blackboard.set("animation", AnimationName.Tired);
                obj_ari.fsm.blackboard.set("on_start_action", function() {
                    TANGO.play("SoundEffects/Ari/Yawn", obj_ari.x, obj_ari.y);
                });
                return false;
            }

            var player_state = obj_ari.fsm.current_state();
            if item.prototype.tool_type == ToolType.FishingRod {
                //
                obj_ari.face_dir(cardinal_to_angle(obj_ari.cardinal));
                player_state.dir = obj_ari.dir;

                //
                //
                target_pos.set_val(
                    (obj_ari.x div OBJECT_CELL_SIZE) + lengthdir_x(2, obj_ari.dir),
                    (obj_ari.y div OBJECT_CELL_SIZE) + lengthdir_y(2, obj_ari.dir),
                );

                obj_ari.cell_select = target_pos.clone();

                //
                obj_ari.fsm.blackboard.set("target_pos", target_pos);
            }

            if item.prototype.use != ItemUse.Attack
                && !(item.prototype.use == ItemUse.UseTool && item.prototype.tool_type == ToolType.FishingRod)
            {
                obj_tile_cursor.select();

                if obj_ari.using_mouse {
                    obj_ari.face_cell(target_pos.x, target_pos.y);
                }
            }

            obj_ari.fsm.change_state(PlayerState.Tool);
            switch item.prototype.use {
                case ItemUse.Attack:
                    obj_ari.fsm.change_state(PlayerState.Sword);
                    obj_ari.fsm.blackboard.set("sword", item);
                    return UseItemSuccess.None;
                case ItemUse.PlantSeed:
                    obj_ari.fsm.blackboard.set("animation_name", AnimationName.Sow);
                    return UseItemSuccess.RemoveLater;
                case ItemUse.PlantSapling:
                case ItemUse.PlantGrass:
                    obj_ari.fsm.blackboard.set("animation_name", AnimationName.Action);
                    return UseItemSuccess.RemoveLater;
                case ItemUse.UseTool:
                    switch item.prototype.tool_type {
                        case ToolType.FishingRod:
                            obj_ari.fsm.change_state(PlayerState.Fishing);
                            break;
                        case ToolType.Hoe:
                            var anim = item.prototype.quality == QualityId.Tier1 ? AnimationName.Till : AnimationName.ChargeHoe;
                            obj_ari.fsm.blackboard.set("animation_name", anim);
                            break;
                        case ToolType.Axe:
                            obj_ari.fsm.blackboard.set("animation_name", AnimationName.Axe);
                            break;
                        case ToolType.PickAxe:
                            obj_ari.fsm.blackboard.set("animation_name", AnimationName.Axe);
                            obj_ari.fsm.blackboard.set("is_pick_axe", true);
                            break;
                        case ToolType.Net:
                            obj_ari.fsm.blackboard.set("animation_name", AnimationName.Net);
                            break;
                        case ToolType.Shovel:
                            obj_ari.fsm.blackboard.set("animation_name", AnimationName.Shovel);
                            break;

                        case ToolType.WateringCan:
                            obj_ari.fsm.blackboard.set("animation_name", AnimationName.Water);
                            break;
                        default: impossible("Unexpected ToolType: {}", item.tool_type);
                    }
                    return UseItemSuccess.None;
                default: impossible("Unexpected ItemUse: {}", item.use);
            }
            break;
        case ItemUse.Bait:
            var pos = obj_ari.cell_select.clone();

            if GRID.item_effects_node_at_cell(pos.x, pos.y, item.prototype) == false
                || GRID.item_effects_node_at_cell(pos.x + 1, pos.y, item.prototype) == false
                || GRID.item_effects_node_at_cell(pos.x, pos.y + 1, item.prototype) == false
                || GRID.item_effects_node_at_cell(pos.x + 1, pos.y + 1, item.prototype) == false
            {
                break;
            }

            if item.prototype.attract.bug {
                BUG_CONDITION_DATA.spawn_type = undefined;
                BUG_CONDITION_DATA.bait = item.prototype;
                var distribution = DUNGEON_RUNNER != undefined
                    ? DUNGEON.biomes[DUNGEON_BIOME].votes[DungeonSpawn.Bug]
                    : BUG_DISTRIBUTION;
                var bug_id = distribution.get_candidate_votes_at_cell(GRID, pos.x, pos.y).get_candidate();
                reset_bug_condition_data();

                if bug_id == undefined {
                    create_notification("misc_local/no_bug");
                    break;
                }

                TANGO.play("SoundEffects/Tools/SeedUseSuccess", obj_ari.x, obj_ari.y);
                obj_ari.fsm.blackboard.set("only_south", false);
                obj_ari.fsm.blackboard.set("animation", AnimationName.Sow);
                obj_ari.fsm.blackboard.set("hold_animation_forever", false);
                obj_ari.fsm.change_state(PlayerState.AnimateAndThen);
                new_world_chain()
                    .append(LinkId.Timer, 15)
                    .append(LinkId.Function, function(sprinkle, spawn, bug_id) {
                        var ae = create_animation_effect(spawn.x + 8, spawn.y + 8, obj_ari.depth, spr_fx_critical_swing_poof);
                        create_animation_effect(spawn.x, spawn.y - 10, obj_ari.depth, sprinkle);
                        ae.spawn = spawn;
                        ae.bug_id = bug_id;
                        ae.image_idx = sprite_get_number(spr_fx_critical_swing_poof) - 1;
                        ae.image_idx_func = method(ae, function() {
                            TANGO.play("SoundEffects/Animals/BugSpawn", spawn.x, spawn.y);
                            var inst = spawn_bug_object(spawn.x, spawn.y, bug_id, false);
                            if inst != undefined {
                                inst.x += 8;
                                inst.y += 8;
                                inst.image_alpha = 0;
                            } else {
                                error("Failed to spawn bug from pheremones");
                            }
                        });
                    }, [item.prototype.attract.sprinkle, Vec2(pos.x * 8, pos.y * 8), bug_id]);

                return UseItemSuccess.Remove;
            } else {
                obj_ari.fsm.blackboard.set("bait", true);
                obj_ari.fsm.blackboard.set("bait_prototype", item.prototype);
                obj_ari.fsm.change_state(PlayerState.Fishing);
                return UseItemSuccess.RemoveLater;
            }

            break;
        default: impossible("unexpected item_use = {}", item.prototype.use);
    }

    return undefined;
}

//
function use_item_fast(item, target_pos) {
    if !is_struct(item) {
        item = new LiveItem(item);
    }

    if target_pos == undefined {
        target_pos = Vec2();
    }

    var success = use_item(item, target_pos);
    if success == UseItemSuccess.RemoveLater {
        obj_ari.fsm.blackboard.insert("execute_instantly", true);
    }

    obj_ari.fsm.blackboard.remove("remove_item_at");
    return success;
}
