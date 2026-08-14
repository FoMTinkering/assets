//
//
function can_interact(node) {
    switch object_id_to_object_category(node.object_id) {
        case ObjectCategory.Crop:
            if has_flag(node.ctx, CropFlag.NO_HARVEST)
                || (has_flag(node.ctx, CropFlag.MANAGED) && node.managed_timer != undefined)
            {
                return false;
            }

            var day_to_stage;
            //
            //
            if node.prototype.post_harvest_day_to_stage != undefined && node.regrow_cycle {
                day_to_stage = node.prototype.post_harvest_day_to_stage;
            } else {
                day_to_stage = node.prototype.day_to_stage;
            }
            return node.stage == day_to_stage.last();

        case ObjectCategory.Bush:
            return node.prototype.harvest != undefined
                && node.day_count >= node.prototype.regrow_days;

        case ObjectCategory.Furniture:
            switch node.object_id {
                case ObjectId.FarmHouseCalendar:
                case ObjectId.StableCraftingTable:
                case ObjectId.WaterSealDoor:
                case ObjectId.EarthSealDoor:
                case ObjectId.FireSealDoor:
                case ObjectId.RuinsSealDoor:
                case ObjectId.BigBell:
                case ObjectId.AutoFeeder:
                case ObjectId.BabyCradle:
                case ObjectId.JunipersProtectionScroll:
                    return true;
                case ObjectId.CaldarusDragonswornStatue:
                case ObjectId.EspressoMachine:
                    return !ARI.used_object_today[node.object_id];
                case ObjectId.Mailbox:
                    return ARI.inbox.contents.count() > 0;
                case ObjectId.TesseraeTree:
                    return node.day_count >= 3;
                case ObjectId.SeedMaker:
                    return ARI.held_item() != undefined
                        && item_to_seed(ARI.held_item().item_id) != undefined;
                default:
                    if node.prototype.interact_menu != undefined {
                        return ARI.held_animal_id == undefined && obj_ari.is_mounted() == false;
                    }

                    if node.prototype.restoration != undefined {
                        return !ARI.used_object_today[node.object_id];
                    }

                    return node.prototype.interaction_turn_on != undefined
                        || node.prototype.interaction_chest != undefined
                        || node.prototype.factory != undefined
                        || node.prototype.forecaster != undefined
                        || node.prototype.is_journal
                        || node.prototype.is_crystal_resonator
                        || node.prototype.is_date_photo
                        || (
                            node.prototype.essence_machine != undefined
                                && node.essence_supply <= 0
                                && ARI.held_item() != undefined
                                && ARI.held_item().prototype.essence_charge != undefined
                            )
                        || (node.prototype.animal_toy != undefined && animals_using_toy(node) > 0)
                        || (node.prototype.bed_kind != undefined && requirements_pass(Requirement.Sleep))
                        || (node.prototype.house_stairs != undefined);
            }

        case ObjectCategory.Tree:
            return node.stage > 1;

        case ObjectCategory.Breakable:
            return node.prototype.chest != undefined
                && node.is_locked == false
                && node.is_open == false;

        default: return false;
    }
}

//
//
function interact(node) {
    if can_interact(node) == false {
        return false;
    }

    ARI.used_object_today[node.object_id] = true;

    switch object_id_to_object_category(node.object_id) {
        case ObjectCategory.Crop:
            //
            var item = node.prototype.harvest;
            var yield = node.prototype.count;

            if node.ctx == CropFlag.EMPTY
                && node.object_id != ObjectId.MysteryBag
                && chance_percent(ARI.perk_value(Perk.LivingOffTheLand))
            {
                var legal_dishes = List();

                for (var i = 0; i < ItemId.LEN; i++) {
                    var prototype = ITEM_PROTOTYPES[i];

                    if prototype.recipe != undefined && prototype.edible {
                        var recipe = ITEM_PROTOTYPES[i].recipe;
                        for (var j = 0, k = recipe.components.count(); j < k; j++) {
                            var component = recipe.components.get(j);
                            if component.type == RecipeComponentType.Item && component.item_id == item {
                                legal_dishes.push(i);
                            }
                        }
                    }
                }

                if legal_dishes.count() != 0 {
                    item_from_critical_poof(node.renderer.x, node.renderer.y, legal_dishes.choose_random());
                }
            }

            if node.ctx == CropFlag.EMPTY
                && node.object_id != ObjectId.MysteryBag
                && chance_percent(ARI.perk_value(Perk.PrizeWinning))
            {
                var gold_amount = ITEM_PROTOTYPES[node.prototype.harvest].value.bin * fiddle_get("perks/prize_winning/percent");
                for (var i = 0; i < gold_amount; i++) {
                    var li = new LiveItem(ItemId.MobCoin);
                    li.auto_use = true;
                    li.gold_to_gain = 1;
                    item_from_critical_poof(node.renderer.x, node.renderer.y, li);
                }
            }

            if chance_percent(ARI.perk_value(Perk.EarthlyEssence))
                && node.ctx == CropFlag.EMPTY
                && node.prototype.is_plant //
            {
                item_from_critical_poof(node.renderer.x, node.renderer.y, new LiveItem(ItemId.SeedMysteryBag));
            }

            if ARI.perk_active(Perk.Ornamental) {
                var chance_to_check;
                if node.ctx == CropFlag.EMPTY || has_flag(node.ctx, CropFlag.MANAGED) {
                    chance_to_check = ARI.perk_value(Perk.Ornamental);
                } else {
                    //
                    chance_to_check = ARI.perk_value(Perk.Ornamental, "forageable_chance");
                }
                //
                if chance_percent(chance_to_check)
                    && node.prototype.faux_crop != undefined
                    && ARI.recipe_unlocks[node.prototype.faux_crop] == false
                {
                    var lv = new LiveItem(ItemId.CraftingScroll, node.prototype.faux_crop);
                    GAME_STATS.perks[$ perk_to_string(Perk.Ornamental)] += 1;
                    item_from_critical_poof(obj_ari.x, obj_ari.y, lv);
                }
            }

            set_rumble(RumbleKind.ToolStrong);
            if node.object_id == ObjectId.MysteryBag {
                var seasonal_array = EARTHLY_ESSENCE[CALENDAR.season()];
                var lv = undefined;

                repeat (array_length(seasonal_array) * 2) {
                    var item = seasonal_array[irandom_range(0, array_length(seasonal_array) - 1)];
                    if !ari_has_cosmetic_anywhere(item.inner_data) {
                        lv = new LiveItem(item.item_id);
                        lv.cosmetic = item.inner_data;
                        GAME_STATS.perks[$ perk_to_string(Perk.EarthlyEssence)] += 1;
                        break;
                    }
                }

                if lv == undefined {
                    //
                    var item = EARTHLY_ESSENCE_ALTERNATIVE[irandom_range(0, array_length(EARTHLY_ESSENCE_ALTERNATIVE) - 1)];
                    lv = new LiveItem(item.item_id);
                    if item.item_id == ItemId.Purse {
                        lv.gold_to_gain = item.gold;
                    }
                }

                drop_item(lv, node.renderer.x, node.renderer.y);
                erase_object_node_by_parent(GRID, node);
                return true;
            } else {
                drop_item(array_create(yield, item), node.renderer.x, node.renderer.y, true);
                try_gather_item_spawn(GatherDropChance.Harvest, node.renderer.x, node.renderer.y);
            }

            if node.object_id == ObjectId.MagicKey {
                var quest = QUEST_LOG.active.get("find_the_magic_key");
                if quest != undefined && quest.current_stage == 4 {
                    quest.progress();
                }
            }

            if has_flag(node.ctx, CropFlag.FORAGEABLE) {
                array_push(GAME_STATS.forageable_harvests, {
                    forageable: item_id_to_string(item),
                    day: total_days(),
                });
            }
            if GS_MINES_RUN != undefined {
                array_push(GS_MINES_FLOOR.forageables_harvested, item_id_to_string(item));
            }
            if node.ctx == CropFlag.EMPTY {
                ARI.gain_xp(Skill.Farming, XpValue.harvest_crop);
                array_push(GAME_STATS.crop_harvests, {
                    crop: item_id_to_string(item),
                    day: total_days(),
                });
            }

            process_crop_harvest(node, obj_ari.cardinal);
            return true;

        case ObjectCategory.Bush:
            //
            var item = node.prototype.harvest;
            var yield = node.prototype.count;
            set_rumble(RumbleKind.ToolStrong);
            drop_item(array_create(yield, item), node.renderer.x, node.renderer.y);
            node.day_count = 0;

            repeat yield {
                array_push(GAME_STATS.forageable_harvests, {
                    forageable: item_id_to_string(item),
                    day: total_days(),
                });
            }

            try_gather_item_spawn(GatherDropChance.Harvest, node.renderer.x, node.renderer.y);

            node.renderer.set_sprite(node.prototype.sprites[CALENDAR.season()][0]);
            sway_renderer(node.renderer, obj_ari.cardinal);

            //
            if node.prototype.target_terrain == TerrainKind.Water {
                node.renderer.water_base_renderer.sprite_index = node.prototype.water_bases[0];
            }
            return true;

        case ObjectCategory.Furniture:
            switch node.object_id {
                case ObjectId.BigBell:
                    var mcp = new MultipleChoicePopup("misc_local/big_bell");

                    mcp.option("misc_local/bell_out", function() {
                        with obj_farm_bell {
                            if self.chain == undefined {
                                self.bell_out(false);
                            }
                        }
                        node.renderer.sprite_index = node.prototype.ring_sprite;
                        node.renderer.image_index = 0;
                        TANGO.play("SoundEffects/Objects/BellBringOutside");
                    });

                    mcp.option("misc_local/bell_in", function() {
                        with obj_farm_bell {
                            if self.chain == undefined {
                                self.bell_in(false);
                            }
                        }
                        node.renderer.sprite_index = node.prototype.ring_sprite;
                        node.renderer.image_index = 0;
                        TANGO.play("SoundEffects/Objects/BellBringInside");
                    });

                    mcp.option("misc_local/close", function() {});
                break;
                case ObjectId.Mailbox:
                    ANCHOR.spawn_menu(Menu.Inbox);
                    obj_ari.set_idle_simple();
                    break;
                case ObjectId.BabyCradle:
                    //
                    //
                    if ARI.held_child() == undefined {
                        for (var i = 0; i < array_length(ARI.children); i++) {
                            var child = ARI.children[i];
                            if child.location == ChildLocation.InCradle {
                                child.set_location(ChildLocation.WithAri);
                            }
                        }
                    } else {
                        ARI.held_child().set_location(ChildLocation.InCradle);
                    }
                    break;
                case ObjectId.FarmHouseCalendar:
                    spawn_calendar_ui(CALENDAR.time)
                        .with_today(CALENDAR.time)
                        .build();
                    obj_ari.set_idle_simple();
                    break;

                case ObjectId.EspressoMachine:
                    var item = new LiveItem(ItemId.Espresso);
                    item.infusion = Infusion.Speedy;
                    use_item_fast(item);
                    break;
                case ObjectId.TesseraeTree:
                    node.day_count = 0;
                    repeat 10 {
                        var item = new LiveItem(ItemId.TreeCoin);
                        item.auto_use = true;
                        item.gold_to_gain = 10;
                        drop_item(item, node.renderer.x, node.renderer.y);
                    }
                    node.renderer.top_sheet_renderer.sprite_index = spr_object_tesserae_tree_main_stage1;
                    break;
                case ObjectId.WaterSealDoor:
                    obj_ari.set_idle_simple();
                    play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectWaterSeal]);
                    break;
                case ObjectId.EarthSealDoor:
                    obj_ari.set_idle_simple();
                    play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectEarthSeal]);
                    break;
                case ObjectId.FireSealDoor:
                    obj_ari.set_idle_simple();
                    play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectFireSeal]);
                    break;
                case ObjectId.RuinsSealDoor:
                    obj_ari.set_idle_simple();
                    play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectRuinsSeal]);
                    break;
                case ObjectId.StableCraftingTable:
                    var turn_in_box = stable_crafting_table_node_get_turn_in_box(node);
                    var turn_in_box_recipe = BLUEPRINT_PROTOTYPES[turn_in_box.blueprint_id].turn_in_box_recipe;

                    //
                    var bp_item_spawner = undefined;
                    var top_left_ni = GRID.node_index_for_cell(node.blueprint_top_left_x, node.blueprint_top_left_y);
                    if GRID.node_parent[top_left_ni] != undefined {
                        bp_item_spawner = try_string_to_item_id(GRID.node_parent[top_left_ni][$ "blueprint_spawner"]);
                    }

                    //
                    var wrapper = new MultipleChoicePopup(
                        format("object_prototypes/building/{ObjectId}/name", BLUEPRINT_PROTOTYPES[turn_in_box.blueprint_id].building_on_finish),
                        ITEM_PROTOTYPES[bp_item_spawner ?? ItemId.SmallCoopRedBlueprint].icon_sprite,
                    );

                    wrapper
                        .option("misc_local/build_building", function(turn_in_box, tl_x, tl_y, bl_id, wrapper) {
                            var bp_proto = BLUEPRINT_PROTOTYPES[turn_in_box.blueprint_id];

                            var popup = text_input_popup(
                                "misc_local/enter_new_name",
                                local_get(NODE_PROTOTYPES[bp_proto.building_on_finish].name),
                                BUILDING_NAME_MAX_WIDTH,
                                function(txt, turn_in_box, tl_x, tl_y, bl_id) {
                                    var bp_proto = BLUEPRINT_PROTOTYPES[turn_in_box.blueprint_id];
                                    //
                                    for (var xx = 0; xx < bp_proto.size.x; xx+=2) {
                                        for (var yy = 0; yy < bp_proto.size.y; yy+=2) {
                                            var ni = GRID.node_index_for_cell(tl_x + xx, tl_y + yy);

                                            if GRID.node_object_id[ni] != undefined {
                                                create_animation_effect(
                                                    GRID.node_parent[ni].renderer.x,
                                                    GRID.node_parent[ni].renderer.y,
                                                    -1000,
                                                    spr_fx_poof1_dirt_once
                                                );
                                            }
                                        }
                                    }
                                    set_rumble(RumbleKind.BuildingComplete);

                                    var turn_in_box_recipe = bp_proto.turn_in_box_recipe;
                                    inventory_drain_ingredients(turn_in_box_recipe, turn_in_box.inventory);

                                    var bp_item_spawner = string_to_item_id(GRID.node_parent[GRID.node_index_for_cell(tl_x, tl_y)].blueprint_spawner);
                                    remove_blueprint_from_location(GRID, tl_x, tl_y, bl_id);

                                    //
                                    if bp_proto.building_on_finish != undefined {
                                        var item_spawner = ITEM_PROTOTYPES[bp_item_spawner];

                                        //
                                        var output = GRIDS[LocationId.Farm].write_node(
                                            tl_x,
                                            tl_y,
                                            bp_proto.building_on_finish,
                                            item_spawner.blueprint.variant,
                                        );
                                        assert_neq(output, undefined, "we failed to build the building");
                                        TANGO.play("SoundEffects/UI/BuildBuilding", tl_x * 8, tl_y * 8);
                                        output.name = txt;

                                        global.__buildings = undefined;
                                    }
                                },
                                [turn_in_box, tl_x, tl_y, bl_id]
                            );

                            popup.background.in_now();
                            wrapper.popup.background.out_now();
                        }, [turn_in_box, node.blueprint_top_left_x, node.blueprint_top_left_y, node.blueprint_id, wrapper]);

                    wrapper.option("misc_local/remove_building", function(tl_x, tl_y, bl_id, bp_item_spawner) {
                            var bp_proto = BLUEPRINT_PROTOTYPES[bl_id];

                            //
                            for (var xx = 0; xx < bp_proto.size.x; xx+=2) {
                                for (var yy = 0; yy < bp_proto.size.y; yy+=2) {
                                    var ni = GRID.node_index_for_cell(tl_x + xx, tl_y + yy);

                                    if GRID.node_object_id[ni] != undefined {
                                        create_animation_effect(
                                            GRID.node_parent[ni].renderer.x,
                                            GRID.node_parent[ni].renderer.y,
                                            -1000,
                                            spr_fx_poof1_dirt_once
                                        );
                                    }
                                }
                            }

                            //
                            remove_blueprint_from_location(GRID, tl_x, tl_y, bl_id);
                            if bp_item_spawner != undefined {
                                drop_item(bp_item_spawner, (tl_x + bp_proto.size.x / 2) * 8, (tl_y + bp_proto.size.y / 2) * 8);
                            }
                        }, [node.blueprint_top_left_x, node.blueprint_top_left_y, node.blueprint_id, bp_item_spawner]);

                    wrapper.option("misc_local/close", function() {});
                    wrapper.popup.buttons.first().set_soft_locked(!inventory_satisfies_recipe(turn_in_box_recipe, turn_in_box.inventory) || bp_item_spawner == undefined);
                    break;
                case ObjectId.SeedMaker:
                    node.renderer.sprite_index = spr_object_seed_maker_main_bounce;
                    var item = ARI.inventory.slot(ARI.held_item_index).pop();
                    var seed = item_to_seed(item.item_id);
                    TANGO.play("SoundEffects/Objects/SeedMaker");
                    repeat irandom_range(1, 3) {
                        drop_item(seed, node.renderer.x, node.renderer.y);
                    }
                    break;
                case ObjectId.AutoFeeder:
                    obj_ari.set_idle_simple();

                    var menu = ANCHOR.spawn_menu(Menu.Storage, node)
                        .set_inventories(node.inventory, ARI.inventory)
                        .with_left_help_button()
                        .with_left_banner()
                        .with_right_banner()
                        .with_pull_button(false)

                    for (var i = 0; i < ItemId.LEN; i++) {
                        var proto = ITEM_PROTOTYPES[i];

                        if proto.use != ItemUse.Consume
                            && proto.animal_feed == undefined
                        {
                            menu.left.maximum_item_counts[i] = 0;
                        }
                    }

                    menu.build();

                    break;
                case ObjectId.JunipersProtectionScroll:
                    obj_ari.set_idle_simple();
                    play_conversation(
                        NpcId.Caldarus,
                        GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.JunipersProtectionScrollText],
                    );
                    break;
                case ObjectId.CaldarusDragonswornStatue:
                    obj_ari.set_idle_simple();
                    play_conversation(
                        NpcId.Caldarus,
                        GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.CaldarusDragonswornStatueText],
                        function(_, node) {
                            ARI.gain_essence(5 * ESSENCE_MORSEL_SMALL, node.renderer.x, node.renderer.y, 4, 0);
                        },
                        [node]
                    );
                    break;
                default:
                    if node.prototype.is_date_photo {
                        spawn_date_photo(node.date_photo);
                    }

                    if node.prototype.restoration != undefined {
                        play_conversation(
                            NpcId.Caldarus,
                            GAMEPLAY_CONVERSATIONS[node.prototype.restoration.convo],
                            function(_, node) {
                                obj_ari.set_idle_simple();

                                //
                                //
                                var chain = new_world_chain(node.renderer, CURRENT_LOCATION_ID)
                                TANGO.play("SoundEffects/Objects/UseSpouseGift", node.renderer.x, node.renderer.y);
                                repeat 4 {
                                    chain.append(LinkId.Function, function(node) {
                                        var inst = create_morsel(
                                            node.renderer.x + irandom_range(-4, 4),
                                            node.renderer.y + irandom_range(-4, 4),
                                            irandom_range(12, 32),
                                            MorselType.Health,
                                            irandom(MorselSize.LEN - 1),
                                            round(node.prototype.restoration.health / 4),
                                            node.renderer.y,
                                            false,
                                        );
                                        inst.z = -16;
                                    }, [node])
                                    chain.append(LinkId.Timer, 10);
                                    chain.append(LinkId.Function, function(node) {
                                        var inst = create_morsel(
                                            node.renderer.x + irandom_range(-4, 4),
                                            node.renderer.y + irandom_range(-4, 4),
                                            irandom_range(12, 32),
                                            MorselType.Stamina,
                                            irandom(MorselSize.LEN - 1),
                                            round(node.prototype.restoration.stamina / 4),
                                            node.renderer.y,
                                            false,
                                        );
                                        inst.z = -16;
                                    }, [node])
                                    chain.append(LinkId.Timer, 10);
                                }

                            },
                            [node]
                        );
                    }

                    if node.prototype.interact_menu != undefined {
                        var xx = node.renderer.x + node.prototype.interact_menu.ari_offset.x;
                        var yy = node.renderer.y + node.prototype.interact_menu.ari_offset.y;
                        var ui_data = undefined;
                        switch node.prototype.interact_menu.menu {
                            case "kitchen":
                                ui_data = COOKING_UI_DATA;
                                break;
                            case "woodcrafting":
                                ui_data = WOODCRAFTING_UI_DATA;
                                break;
                            case "forge":
                                ui_data = BLACKSMITHING_UI_DATA;
                                break;
                            case "mill":
                                ui_data = MILLING_UI_DATA;
                                break;
                        }

                        var menu = spawn_crafting_menu(ui_data, xx, yy, node.object_id);
                        menu.object_coordinates.x = node.renderer.x;
                        menu.object_coordinates.y = node.renderer.y;
                    }

                    //
                    if node.prototype.interaction_turn_on != undefined {
                        node.is_on = !node.is_on;

                        if node.is_on {
                            node.renderer.image_speed = 1;
                            node.renderer.image_index = 0;
                            node.renderer.set_sprite(node.prototype.cardinal_data[node.cardinal_index].on_sprite);

                            if node.prototype.interaction_turn_on.continual_on_sound != undefined {
                                node.renderer.sound_controller = new SoundInstanceController(TANGO.play(node.prototype.interaction_turn_on.continual_on_sound, node.renderer.x, node.renderer.y));
                            }

                            if node.prototype.interaction_turn_on.turn_on_sound != undefined {
                                TANGO.play(node.prototype.interaction_turn_on.turn_on_sound, node.renderer.x, node.renderer.y);
                            }

                            if node.prototype.interaction_turn_on.light != undefined {
                                node.renderer.light = instance_create_layer(
                                    node.renderer.x + node.prototype.interaction_turn_on.light_offset.x,
                                    node.renderer.y + node.prototype.interaction_turn_on.light_offset.y,
                                    "Lighting",
                                    par_light
                                );
                                node.renderer.light.tiered_light = node.prototype.interaction_turn_on.light;
                                node.renderer.light.sprite_index = LIGHTS[node.renderer.light.tiered_light][0];

                                //
                                Game.dark_room_light_count += 1;
                            }

                            if node.prototype.interaction_turn_on.interact_local != undefined {
                                replace_interaction_local(
                                    node.renderer,
                                    node.prototype.interaction_turn_on.interact_local,
                                    node.prototype.interaction_turn_on.interact_local_off
                                );
                            }
                        } else {
                            node.renderer.set_sprite(node.prototype.cardinal_data[node.cardinal_index].sprite);

                            if node.prototype.interaction_turn_on.turn_off_sound != undefined {
                                TANGO.play(node.prototype.interaction_turn_on.turn_off_sound, node.renderer.x, node.renderer.y);
                            }

                            if node.renderer.sound_controller != undefined {
                                //
                                node.renderer.sound_controller.force_stop();
                                node.renderer.sound_controller = undefined;
                            }

                            if node.renderer.light != undefined && instance_is_alive(node.renderer.light) {
                                instance_destroy(node.renderer.light);
                                node.renderer.light = undefined;
                            }

                            Game.dark_room_light_count = max(Game.dark_room_light_count - 1, 0);

                            if node.prototype.interaction_turn_on.pause_when_off {
                                node.renderer.image_speed = 0;
                                node.renderer.image_index = 0;
                            }

                            if node.prototype.interaction_turn_on.interact_local != undefined {
                                replace_interaction_local(
                                    node.renderer,
                                    node.prototype.interaction_turn_on.interact_local_off,
                                    node.prototype.interaction_turn_on.interact_local
                                );
                            }
                        }
                    }

                    if node.prototype.is_journal {
                        if is_home_location(CURRENT_LOCATION_ID) {
                            var popup = popup_creator("misc_local/save_game", "misc_local/save_your_progress");
                            popup.create_button("misc_local/no");
                            popup.create_button("misc_local/yes", function() {
                                var menu = ANCHOR.get_menu(Menu.GlyphGuide);
                                menu.canvas.disable();
                                CLOCK.time_stopped = false;
                                obj_ari.fsm.change_state(PlayerState.Dummy);
                                LOAD_SEQUENCE.start(
                                    "misc_local/saving",
                                    function() {
                                        ARI.save_position = new LocationPosition(
                                            CURRENT_LOCATION_ID,
                                            Vec2(obj_ari.x, obj_ari.y),
                                        );

                                        game_stats_increment(GAME_STATS, "manual_saves");
                                        save_game(exact_save_path(Game.unique_identifier, true, irandom(I32_MAX)));
                                        create_save_notification();

                                        //
                                        var menu = ANCHOR.get_menu(Menu.GlyphGuide);
                                        menu.canvas.enable();
                                        //
                                        //
                                        //
                                        CLOCK.time_stopped = false;
                                        obj_ari.fsm.change_state(PlayerState.Default);
                                        return true;
                                    },
                                    [],
                                    FADE_SPEED_TRANSITION,
                                );
                            });
                            popup.spawn();
                        } else {
                            var p = popup_creator("misc_local/cannot_save_outside_home", "misc_local/cannot_save_outside_home_data");
                            p.create_button("misc_local/close");
                            p.spawn();
                        }
                    }

                    if node.prototype.is_crystal_resonator {
                        song_selection_ui(function(song) {
                            if CURRENT_DYN_INDEX != undefined {
                                ARI.dyn_song_overrides[string(CURRENT_DYN_INDEX)] = song;
                            } else {
                                ARI.song_overrides[CURRENT_LOCATION_ID] = song;
                            }
                            MUSIC_PLAYER.refresh();
                        });
                    }

                    if node.prototype.bed_kind != undefined {
                        if is_home_location(CURRENT_LOCATION_ID) {
                            var popup = popup_creator("misc_local/bed", "misc_local/go_to_sleep");
                            popup.create_button("misc_local/cancel");
                            popup.create_button("misc_local/sleep", function(node) {
                                if TAXI.is_traveling() {
                                    return;
                                }

                                if CLOCK.time >= hours(25) + minutes(50) {
                                    T2R.write("slept_last_minute", true);
                                }

                                ARI.last_bed_used = {
                                    location_id: CURRENT_LOCATION_ID,
                                    ni: GRID.node_index_for_cell(node.top_left_x, node.top_left_y),
                                };

                                var spouse = undefined;
                                with par_NPC {
                                    if !self.me.is_spouse() {
                                        continue;
                                    }
                                    spouse = npc_id_to_string(self.npc_id);
                                    break;
                                }

                                MIST.blackboard.insert("spouse", spouse);
                                MIST.blackboard.insert("spouse_is_present", spouse != undefined);
                                MIST.request_scene("sleep");

                            }, [node]);
                            popup.spawn();
                        } else {
                            var p = popup_creator("misc_local/cannot_sleep_outside_home", "misc_local/cannot_sleep_outside_home_data");
                            p.create_button("misc_local/close");
                            p.spawn();
                        }
                    }

                    if node.prototype.interaction_chest != undefined {
                        obj_ari.set_idle_simple();

                        var menu = ANCHOR.spawn_menu(Menu.Storage, node)
                            .set_inventories(node.inventory, ARI.inventory)
                            .with_right_help_button()
                            .with_right_banner();

                        if object_id == ObjectId.TurnInBox {
                            menu.with_alt_stack_behavior();

                            //
                            var recipe_for_box = undefined;
                            if node[$ "building_box"] != undefined {
                                recipe_for_box = BLUEPRINT_PROTOTYPES[node.blueprint_id].turn_in_box_recipe;
                            } else {
                                var q = QUEST_LOG.active.get(node.quest_id);
                                var data = q.quest.tasks.get(q.current_stage).requirements[Requirement.SuppliedItems][0].items;

                                recipe_for_box = {};
                                for (var i = 0; i < array_length(data); i++) {
                                    if data[i] != 0 {
                                        recipe_for_box[$ i] = data[i];
                                    }
                                }
                            }

                            menu.with_recipe(recipe_for_box);
                        } else if !node.prototype.interaction_chest.shipping_bin {
                            menu.with_left_banner();
                        }

                        menu.with_chest_node(node);

                        node.renderer.sprite_index = node.prototype.interaction_chest.opening_sprite;
                        node.renderer.image_speed = 1;
                        node.renderer.image_index = 0.0;
                        TANGO.play(node.prototype.interaction_chest.open_sfx, self.x, self.y);
                        menu.build();
                    }

                    if node.prototype.forecaster != undefined {
                        var next_weather = weather_tomorrow();
                        var convo = undefined;
                        switch next_weather {
                            case Weather.Calm:
                                convo = GpTriggeredConversation.WeatherSunny;
                                break;
                            case Weather.Inclement:
                                convo = CALENDAR.season() == Season.Winter
                                    ? GpTriggeredConversation.WeatherSnowy
                                    : GpTriggeredConversation.WeatherRainy;
                                break;
                            case Weather.HeavyInclement:
                                convo = CALENDAR.season() == Season.Winter
                                    ? GpTriggeredConversation.WeatherBlizzard
                                    : GpTriggeredConversation.WeatherStormy;
                                break;
                            case Weather.Special:
                                if CALENDAR.season() == Season.Spring {
                                    convo = GpTriggeredConversation.WeatherCherryBlossoms;
                                } else {
                                    convo = GpTriggeredConversation.WeatherFallingLeaves;
                                }
                                break;
                            default: impossible("Unexpected Weather: {}", next_weather);
                        }

                        if convo != undefined {
                            play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[convo]);
                        }
                    }

                    if node.prototype.animal_toy != undefined {
                        //
                        with obj_player_animal {
                            if self.fsm.current_state_id() == AnimalState.UsingToy
                                && self.fsm.current_state().toy == node
                            {
                                //
                                self.y = node.renderer.y;
                                self.object_id_to_ignore = node.object_id;

                                self.fsm.change_state(AnimalState.Wander);
                                //
                            }
                        }

                        //
                        with obj_pet {
                            if self.fsm.current_state_id() == PetState.UsingToy
                                && self.fsm.current_state().toy == node {
                                //
                                self.y = node.renderer.y;
                                self.object_id_to_ignore = node.object_id;

                                self.fsm.change_state(PetState.Wander);
                            }
                        }

                        stop_animal_toy_sfx(node);

                        //
                        node.animal_count = 0;
                    }

                    if node.prototype.essence_machine != undefined
                        && node.essence_supply <= 0
                    {
                        var current_item = ARI.held_item();
                        if current_item != undefined
                            && current_item.prototype.essence_charge != undefined
                        {
                            ARI.inventory.slot(ARI.held_item_index).pop();

                            node.essence_supply = current_item.prototype.essence_charge;

                            node.renderer.essence_stone_sprite = current_item.prototype.icon_sprite;
                            node.renderer.essence_stone_offset_x = node.prototype.essence_machine.stone_offset.x;
                            node.renderer.essence_stone_offset_y = node.prototype.essence_machine.stone_offset.y;

                            if node.prototype.sprinkler != undefined {
                                SPRINKLER_TIMER = node.prototype.sprinkler * 60 + 1;
                            } else if node.prototype.object_id == ObjectId.OcarinaSpriteStatue {
                                activate_ocarina(node);
                            }

                            TANGO.play("SoundEffects/Objects/PlaceEssenceCrystal", node.renderer.x, node.renderer.y);
                        }
                    }

                    //
                    if node.prototype.house_stairs != undefined {
                        var corresponding_room = get_house_corresponding_room(CURRENT_LOCATION_ID);
                        if corresponding_room != undefined {
                            if node.prototype.house_stairs.pathfind_first != undefined {
                                var pos_to_pathfind_to = Vec2(node.top_left_x * 8 + node.prototype.house_stairs.pathfind_first.x, node.top_left_y * 8 + node.prototype.house_stairs.pathfind_first.y);
                                var path_data = PATHFINDING.calculate_local_path(
                                    obj_ari.x,
                                    obj_ari.y,
                                    pos_to_pathfind_to.x,
                                    pos_to_pathfind_to.y,
                                );
                                if path_data == undefined {
                                    obj_ari.x = pos_to_pathfind_to.x;
                                    obj_ari.y = pos_to_pathfind_to.y;
                                } else {
                                    var path = path_data.output_list;

                                    obj_ari.fsm.blackboard.set("itinerary", new Itinerary(List(new ItineraryItem(
                                        new LocationPosition(CURRENT_LOCATION_ID, Vec2(obj_ari.x, obj_ari.y)),
                                        new LocationPosition(CURRENT_LOCATION_ID, pos_to_pathfind_to),
                                        0,
                                        path
                                    ))));
                                    obj_ari.fsm.blackboard.set("move_accel", Vec2(0.6, 0.6));
                                    obj_ari.fsm.change_state(PlayerState.Pathfind);
                                }

                                //
                                ari_teleport_to_room(corresponding_room, pos_to_pathfind_to.x, pos_to_pathfind_to.y);
                                //
                                new_world_chain()
                                    .append(LinkId.Await, function() {
                                        return obj_ari.fsm.check_state_inclusive(PlayerState.Pathfind) == false;
                                    })
                                    .append(LinkId.Function, function(renderer, disappearance_animation) {
                                        if instance_exists(renderer) {
                                            renderer.stash_sprite = renderer.sprite_index;
                                            renderer.sprite_index = disappearance_animation;

                                            renderer.give_animation_end_callback(function() {
                                                self.sprite_index = self.stash_sprite;
                                                self.give_animation_end_callback(function() {});
                                            });
                                        }
                                        return obj_ari.fsm.check_state_inclusive(PlayerState.Pathfind) == false;
                                    }, [node.renderer, node.prototype.house_stairs.disappearance_animation[node.cardinal_index]]);
                                //
                                new_chain()
                                    .append(LinkId.Await, function(destination_location) {
                                        return CURRENT_LOCATION_ID == destination_location && instance_exists(obj_ari);
                                    }, [corresponding_room])
                                    .append(LinkId.Function, function(appearance_animation) {
                                        var ni = GRID.node_index_for_room_position(obj_ari.x, obj_ari.y);
                                        if ni != undefined {
                                            var node = GRID.node_parent[ni];
                                            if node.renderer != undefined && instance_exists(node.renderer) {
                                                node.renderer.stash_sprite = node.renderer.sprite_index;
                                                node.renderer.sprite_index = appearance_animation;

                                                node.renderer.give_animation_end_callback(function() {
                                                    self.sprite_index = self.stash_sprite;
                                                    self.give_animation_end_callback(function() {});
                                                });
                                            }
                                        }
                                    }, [node.prototype.house_stairs.appearance_animation[node.cardinal_index]])
                            } else {
                                var offset = node.prototype.house_stairs.drop_off_offset[node.cardinal_index];
                                TANGO.play("SoundEffects/Entrances/StairsTransition", node.top_left_x * 8, node.top_left_y * 8);

                                //
                                obj_ari.set_idle_simple();

                                goto_location_id(corresponding_room)
                                    .set_exact_position(
                                        node.top_left_x * 8 + offset.x,
                                        node.top_left_y * 8 + offset.y,
                                    );

                                //
                                obj_ari.fsm.change_state(PlayerState.Dummy);
                            }
                        }
                    }

                    if node.prototype.factory != undefined {
                        obj_ari.set_idle_simple();

                        factory_generate_storage_menu(node);
                    }
                    break;
            }
            break;

        case ObjectCategory.Tree:
            var center_stump_x = (node.top_left_x + 3) * 8;
            var center_stump_y = (node.top_left_y + 4) * 8;
            TANGO.play("SoundEffects/Objects/TreeLeafRustle", center_stump_x, center_stump_y);
            create_tree_debris(node);
            rot_traumatize(node.renderer, 0.6);

            //
            if node.renderer.has_bug {
                var output = spawn_bug(center_stump_x div 8, center_stump_y div 8, BugSpawnType.Canopy);
                if output != undefined {
                    trace("Spawning a bug...success: {bool}", output != undefined);
                    node.renderer.has_bug = false;
                }
            }

            //
            if tree_attempt_drop_fruit(node) {
                set_rumble(RumbleKind.ToolStrong);
            } else {
                set_rumble(RumbleKind.ToolWeak);
            }
            tree_attempt_drop_shake_item(node);

            //
            if node.renderer.linked_object != undefined
                && instance_exists(node.renderer.linked_object)
                && node.renderer.linked_object.occupied != undefined
            {
                node.renderer.linked_object.spook_bird = true;
            }
            return true;

        case ObjectCategory.Breakable:
            if node.prototype.chest != undefined && node.is_open == false {
                breakable_open_chest(node);
            }
            break;
        default:
            return false;
    }
}
