//
function can_pick_node(grid, ni, item_quality) {
    if grid.node_object_id[ni] == undefined {
        //
        if grid.node_rug_id[ni] != undefined {
            return true;
        }

        return false;
    }

    switch object_id_to_object_category(grid.node_object_id[ni]) {
        case ObjectCategory.Rock:
            return item_quality >= grid.node_parent[ni].prototype.minimum_quality;
        case ObjectCategory.DigSite:
            //
            return grid.node_object_id[ni] == ObjectId.DigSite;
        case ObjectCategory.Furniture:
            var node_parent = grid.node_parent[ni];
            if array_contains(NODE_PROTOTYPES[grid.node_object_id[ni]].placeable_locations, CURRENT_LOCATION_ID) == false {
                return false;
            }

            //
            if node_parent.prototype.check_pick {
                with node_parent.renderer {
                    if overlap_instance(x, y, [obj_ari, par_animal]) {
                        return false;
                    }
                }
            }

            if node_parent.destructable == false {
                if node_parent.child_grid == undefined {
                    return false;
                } else {
                    //
                    //
                    var target_list = List();
                    furniture_collect_children_with_depth(node_parent.child_grid, target_list, 1);

                    for (var i = 0; i < target_list.count(); i++) {
                        var data = target_list.get(i);
                        var node = data[0];

                        if node.prototype.destructable {
                            return true;
                        }
                    }

                    return false;
                }
            }

            if node_parent.prototype.animal_toy != undefined
                && animals_using_toy(node_parent) > 0
            {
                return false;
            }

            if node_parent.object_id == ObjectId.BabyCradle {
                //
                for (var i = 0; i < array_length(ARI.children); i++) {
                    if ARI.children[i].location == ChildLocation.InCradle {
                        return false;
                    }
                }
            }

            return true;
        default:
            return false;
    }
}

enum PickResult {
    Nothing,
    Rock,
    DigSite,
    Furniture
}

//
//
//
//
//
//
//
function pick_node(grid, x_pos, y_pos, item, modifier, effect_override, doppel, is_burn=false) {
    var is_rug_pick = false;
    var inst_index = undefined;
    var object_id = undefined;
    var breaker = false;

    //
    //
    var register_dungeon_stats = is_dungeon_room(room())
        && ARI.end_of_day_status == undefined
        && GS_MINES_RUN != undefined
        && GS_MINES_FLOOR != undefined;

    for (var xx = 0; xx < 2; xx++) {
        if breaker {
            break;
        }

        for (var yy = 0; yy < 2; yy++) {
            var found = grid.try_node_index_for_cell(x_pos + xx, y_pos + yy);
            if found != undefined && (grid.node_object_id[found] != undefined || grid.node_rug_id[found] != undefined) {
                inst_index = found;
                breaker = true;

                //
                if grid.node_object_id[found] == undefined && grid.node_rug_id[found] != undefined {
                    is_rug_pick = true;
                    object_id = grid.node_rug_id[found];
                } else {
                    object_id = grid.node_object_id[inst_index];
                }
                break;
            }
        }
    }
    var damage = item.damage + modifier;
    var pick_sfx = fiddle_get("tool_fx/pick");

    //
    switch object_id_to_object_category(object_id) {
        case ObjectCategory.Rock:
            var node = grid.node_parent[inst_index];
            var is_large = node.prototype.size.x > 2 || node.prototype.size.y > 2;

            var status = ToolStatus.None;

            if item.quality == QualityId.LEN - 1 || (item.quality + modifier) >= node.prototype.minimum_quality {
                node.hitpoints -= min(damage, node.hitpoints);
                status = node.hitpoints <= 0 ? ToolStatus.Dead : ToolStatus.Damage;
            }

            switch (status) {
                case ToolStatus.None:
                    doppel.play_bad(pick_sfx.inadequate.sfx, node.renderer.x, node.renderer.y);
                    //
                    CAMERA.add_trauma(pick_sfx.inadequate.cam_trauma);
                    traumatize(node.renderer, pick_sfx.inadequate.node_trauma);
                    set_rumble(RumbleKind.ToolInvalid);

                    return PickResult.Nothing;
                case ToolStatus.Damage:
                    doppel.play_good(is_large ? pick_sfx.damaged.large_sfx : pick_sfx.damaged.sfx, node.renderer.x, node.renderer.y);
                    //
                    CAMERA.add_trauma(pick_sfx.damaged.cam_trauma);
                    set_rumble(RumbleKind.ToolWeak);
                    traumatize(node.renderer, pick_sfx.damaged.node_trauma);
                    return PickResult.Rock;

                case ToolStatus.Dead:
                    doppel.play_good(effect_override ?? (is_large ? pick_sfx.destroyed.large_sfx : pick_sfx.destroyed.sfx), node.renderer.x, node.renderer.y);
                    CAMERA.add_trauma(pick_sfx.destroyed.cam_trauma);
                    set_rumble(RumbleKind.ToolStrong);

                    var xx = node.renderer.x;
                    var yy = node.renderer.y;

                    //
                    create_rock_debris(node.renderer, node);

                    //
                    erase_object_node(grid, inst_index);

                    //
                    //
                    if MIST.is_running() {
                        return PickResult.Rock;
                    }

                    var bundle = node.prototype.drop_bundle.choose_drop();

                    if chance_percent(ARI.perk_value(Perk.IronHound)) && object_id == ObjectId.NodeIron {
                        item_from_critical_poof(xx, yy, ItemId.OreIron);
                        GAME_STATS.perks[$ perk_to_string(Perk.IronHound)] += 1;
                    }

                    if chance_percent(ARI.perk_value(Perk.TrueBlue)) && object_id == ObjectId.NodeSapphire {
                        item_from_critical_poof(xx, yy, ItemId.OreSapphire);
                        GAME_STATS.perks[$ perk_to_string(Perk.TrueBlue)] += 1;
                    }

                    if chance_percent(ARI.perk_value(Perk.SilverSeeker)) && object_id == ObjectId.NodeSilver {
                        item_from_critical_poof(xx, yy, ItemId.OreSilver);
                        GAME_STATS.perks[$ perk_to_string(Perk.SilverSeeker)] += 1;
                    }

                    if chance_percent(ARI.perk_value(Perk.GoodAsGold)) && object_id == ObjectId.NodeGold {
                        item_from_critical_poof(xx, yy, ItemId.OreGold);
                        GAME_STATS.perks[$ perk_to_string(Perk.GoodAsGold)] += 1;
                    }

                    if chance_percent(ARI.perk_value(Perk.MistrilMastery)) && object_id == ObjectId.NodeMistril {
                        item_from_critical_poof(xx, yy, ItemId.OreMistril);
                        GAME_STATS.perks[$ perk_to_string(Perk.MistrilMastery)] += 1;
                    }

                    ARI.gain_xp(Skill.Mining, node.prototype.mining_xp_gain);

                    //
                    if chance_percent(fiddle_get("misc/bugs/low_spawn")) {
                        var output = spawn_bug(xx div 8, yy div 8, BugSpawnType.Rock);
                        trace("Spawning a bug...success: {bool}", output != undefined);

                        if register_dungeon_stats && output != undefined {
                            array_push(GS_MINES_FLOOR.pickaxe_spawned_bugs, item_id_to_string(output.item_id));
                        }
                    }
                    if register_dungeon_stats {
                        array_push(GS_MINES_FLOOR.rocks_broken, object_id_to_string(object_id));
                    }

                    //
                    var bundle_array = bundle.to_array();
                    drop_item(bundle.to_array(), xx, yy);

                    if chance_percent(ARI.perk_value(Perk.Masonry)){
                        item_from_critical_poof(xx, yy, ItemId.OreStone);
                        GAME_STATS.perks[$ perk_to_string(Perk.Masonry)] += 1;
                    }

                    if register_dungeon_stats {
                        for (var i = 0, c = array_length(bundle_array); i < c; i++) {
                            array_push(GS_MINES_FLOOR.rock_drops, item_id_to_string(bundle_array[i].item_id));
                        }
                    }

                    //
                    if is_dungeon_room(room()) && chance_percent(ARI.perk_value(Perk.OreRiginal)) {
                        item_from_critical_poof(
                            xx,
                            yy,
                            DUNGEON.biomes[DUNGEON_BIOME].ore,
                        );
                    }

                    //
                    var skill_chance = ARI.perk_value(Perk.EarthBreaker);

                    if ARI.perk_active(Perk.EarthBreakerTwo) {
                        skill_chance = ARI.perk_value(Perk.EarthBreakerTwo);
                    }

                    if is_dungeon_room(room()) && effect_override == undefined && chance_percent(skill_chance) {
                        var fake_cardinal = wrap(obj_ari.cardinal - 1, Cardinal.LEN);
                        switch fake_cardinal {
                            case Cardinal.North:
                                y_pos += 2;
                                break;
                            case Cardinal.South:
                                y_pos -= 2;
                                break;
                            case Cardinal.West:
                                x_pos += 2;
                                break;
                            case Cardinal.East:
                                x_pos -= 2;
                                break;
                        }
                        var list = range_pattern_to_targets(x_pos, y_pos, RangePattern.OneByThree, fake_cardinal);
                        var stagger = choose(1, 0);

                        //
                        var can_trigger = false;
                        for (var i = 0, c = list.count(); i < c; i++) {
                            var pos = list.get(i);
                            if i == 1 {
                                continue;
                            }
                            var other_node = grid.try_node_index_for_cell(pos.x, pos.y);
                            if other_node == undefined {
                                continue;
                            }

                            if can_pick_node(grid, other_node, item.quality) {
                                can_trigger = true;
                                break;
                            }
                        }

                        if can_trigger {
                            doppel.play_good("SoundEffects/Ari/EarthbreakerRumble");

                            for (var i = 0, c = list.count(); i < c; i++) {
                                var pos = list.get(i);
                                if i == 1 {
                                    continue;
                                }

                                var other_node = grid.try_node_index_for_cell(pos.x, pos.y);
                                if other_node == undefined {
                                    continue;
                                }
                                if
                                    object_id_to_object_category(grid.node_object_id[other_node]) == ObjectCategory.Rock
                                    && can_pick_node(grid, other_node, item.quality)
                                {
                                    traumatize(grid.node_parent[other_node].renderer, 1);

                                    new_chain()
                                        .append(LinkId.Timer, 9 + stagger * 3)
                                        .append(LinkId.Function, function(grid, pos, item, doppel) {
                                            var other_node = grid.try_node_index_for_cell(pos.x, pos.y);
                                            if other_node == undefined
                                                || object_id_to_object_category(grid.node_object_id[other_node]) != ObjectCategory.Rock
                                            {
                                                return;
                                            }

                                            var critical_vfx = create_animation_effect(
                                                grid.node_parent[other_node].renderer.x,
                                                grid.node_parent[other_node].renderer.y + 5,
                                                get_floor_depth(),
                                                spr_fx_critical_swing_poof
                                            );
                                            TANGO.play("SoundEffects/Inventory/StaminaPreSpawnPoof", grid.node_parent[other_node].renderer.x, grid.node_parent[other_node].renderer.y);
                                            critical_vfx.image_idx = 2;
                                            critical_vfx.node_pos = pos;
                                            critical_vfx.node_grid = grid;
                                            critical_vfx.node_item = item;
                                            critical_vfx.doppel = doppel;
                                            critical_vfx.image_idx_func = method(critical_vfx, function() {
                                                var other_node = self.node_grid.try_node_index_for_cell(self.node_pos.x, self.node_pos.y);
                                                if other_node == undefined
                                                    || object_id_to_object_category(self.node_grid.node_object_id[other_node]) != ObjectCategory.Rock
                                                {
                                                    return;
                                                }

                                                if can_pick_node(self.node_grid, other_node, QualityId.Tier6) {
                                                    pick_node(self.node_grid, self.node_pos.x, self.node_pos.y, self.node_item, I32_MAX, "SoundEffects/Objects/EarthbreakerRockBreak", self.doppel);
                                                }
                                            });

                                        }, [grid, pos, item, doppel]);

                                    stagger = !stagger;
                                }
                            }
                        }
                    }

                    if is_dungeon_room(room()) && chance_percent(ARI.perk_value(Perk.Stoneturner)) {
                        item_from_critical_poof(x_pos * 8, y_pos * 8, ARCHAEOLOGY.choose_random_artifact());
                        GAME_STATS.perks[$ perk_to_string(Perk.Stoneturner)] += 1;
                    }

                    //
                    try_gather_item_spawn(GatherDropChance.RockBreak, xx, yy);

                    //
                    return PickResult.Rock;
                break;

                default: impossible("unknown status {}", status);
            }

        case ObjectCategory.DigSite:
            if grid.node_object_id[inst_index] == ObjectId.DigSiteDestroyed {
                set_rumble(RumbleKind.ToolInvalid);
                return PickResult.Nothing;
            }
            var success = dig_site_attempt_dig(x_pos, y_pos, ARCHAEOLOGY.choose_random_artifact());
            if success {
                set_rumble(RumbleKind.ToolStrong);
                doppel.play_good(pick_sfx.destroyed.sfx);
                return PickResult.DigSite;
            }
            return PickResult.Nothing;
        //
        case ObjectCategory.Tree:
            //
            if (x_pos != (grid.node_parent[inst_index].top_left_x + 2)
                && x_pos != (grid.node_parent[inst_index].top_left_x + 3))
                || (y_pos != (grid.node_parent[inst_index].top_left_y + 2)
                && y_pos != (grid.node_parent[inst_index].top_left_y + 3))
            {
                return PickResult.Nothing;
            }

            var node = grid.node_parent[inst_index];
            doppel.play_bad(pick_sfx.wrong.sfx, node.renderer.x, node.renderer.y);
            CAMERA.add_trauma(pick_sfx.wrong.cam_trauma);
            var node_trauma = pick_sfx.wrong.node_trauma;

            //
            if node.stage <= 2 {
                node_trauma += 0.1;
            }
            traumatize(node.renderer, node_trauma);
            set_rumble(RumbleKind.ToolInvalid);

            return PickResult.Nothing;

        case ObjectCategory.Furniture:
            var node = is_rug_pick ? grid.node_rug_parent[inst_index] : grid.node_parent[inst_index];

            var target_list = undefined;
            var cannot_destroy = node.destructable == false;

            //
            //
            //
            if is_rug_pick == false {
                target_list = List();
                if node.child_grid != undefined {
                    furniture_collect_children_with_depth(node.child_grid, target_list, 1);
                }

                if cannot_destroy {
                    //
                    //
                    //
                    //
                    //
                    for (var i = 0; i < target_list.count(); i++) {
                        if target_list.get(i)[0].prototype.destructable {
                            cannot_destroy = false;
                            break;
                        }
                    }
                }
            }

            //
            if node.prototype.check_pick {
                with node.renderer {
                    if overlap_instance(x, y, [obj_ari, par_animal]) {
                        return false;
                    }
                }
            }

            if node.object_id == ObjectId.BabyCradle {
                //
                for (var i = 0; i < array_length(ARI.children); i++) {
                    if ARI.children[i].location == ChildLocation.InCradle {
                        cannot_destroy = true;
                    }
                }
            }

            //
            if cannot_destroy
                || array_contains(node.prototype.placeable_locations, CURRENT_LOCATION_ID) == false
                || (node.prototype.animal_toy != undefined && animals_using_toy(node) > 0)
            {
                doppel.play_bad(pick_sfx.inadequate.sfx, node.renderer.x, node.renderer.y);
                CAMERA.add_trauma(pick_sfx.inadequate.cam_trauma);
                traumatize(node.renderer, pick_sfx.inadequate.node_trauma);
                set_rumble(RumbleKind.ToolInvalid);
                return PickResult.Nothing;
            }

            doppel.play_good(pick_sfx.furniture.sfx);
            set_rumble(RumbleKind.FurnitureRemove);
            CAMERA.add_trauma(pick_sfx.furniture.cam_trauma);

            //
            //
            //
            if is_rug_pick {
                drop_item_from_object(node.object_id, node.renderer.x, node.renderer.y, try_string_to_infusion(node.infusion));
                erase_rug_node(grid, inst_index);
            } else {
                //
                target_list.push([node, 0, grid]);
                var original_node = node;

                target_list.sort_with(function(lhs, rhs) {
                    return sign(rhs[1] - lhs[1]);
                });

                var max_sort = undefined;
                for (var i = 0; i < target_list.count(); i++) {
                    var data = target_list.get(i);
                    var node = data[0];
                    if max_sort == undefined {
                        max_sort = data[1];
                    } else if max_sort > data[1] {
                        break;
                    }

                    //
                    if is_burn && node.prototype.interaction_chest != undefined {
                        return PickResult.Nothing;
                    }

                    //
                    create_animation_effect(
                        node.renderer.x,
                        node.renderer.y,
                        -1000,
                        spr_fx_poof1_dirt_once
                    );

                    //
                    var item_proto = find_item_prototype(node.object_id);
                    if item_proto == undefined && node.prototype.house_stairs != undefined {
                        item_proto = find_item_prototype(node.prototype.house_stairs.paired_object);
                    }

                    if item_proto != undefined {
                        var live_item = new LiveItem(item_proto.item_id);
                        if live_item.infusion == undefined {
                            live_item.infusion = try_string_to_infusion(node.infusion);
                        }
                        if node.prototype.is_date_photo {
                            live_item.date_photo = node.date_photo;
                        }

                        drop_item_to_ground(original_node.renderer.x, original_node.renderer.y + 1, node.renderer.y - original_node.renderer.y)
                            .setup(List(live_item));
                    }

                    if node.prototype.essence_machine != undefined && node.essence_supply > 0 {
                        drop_item(essence_get_change(node), node.renderer.x, node.renderer.y);
                    }

                    if node.prototype.factory != undefined && node.inventory.total_items() > 0 {
                        drop_item(node.inventory.drain().to_array(), node.renderer.x, node.renderer.y);
                    }

                    //
                    if node.prototype.object_id == ObjectId.TesseraeTree
                        && can_interact(node)
                    {
                        interact(node);
                    }

                    //
                    erase_object_node_by_parent(data[2], node);
                }
            }
            return PickResult.Furniture;
            break;
        case ObjectCategory.Grass:
        case undefined:
            set_rumble(RumbleKind.ToolInvalid);
            return PickResult.Nothing;

        default:
            doppel.play_bad(
                pick_sfx.wrong.sfx,
                x_pos * 8,
                y_pos * 8,
            );
            //
            CAMERA.add_trauma(pick_sfx.wrong.cam_trauma);
            traumatize(grid.node_parent[inst_index].renderer, pick_sfx.wrong.node_trauma);
            set_rumble(RumbleKind.ToolInvalid);
            return PickResult.Nothing;
    }
}

function furniture_collect_children_with_depth(g, list, child_depth) {
    //
    var node_tick = irandom(I32_MAX);

    for (var xx = 0; xx < g.dims.x; xx++) {
        for (var yy = 0; yy < g.dims.y; yy++) {
            var sub_grid_index = g.node_index_for_cell(xx,yy);
            if g.node_object_id[sub_grid_index] == undefined || g.node_parent[sub_grid_index].last_update == node_tick {
                continue;
            }

            if g.node_parent[sub_grid_index].child_grid != undefined {
                furniture_collect_children_with_depth(g.node_parent[sub_grid_index].child_grid, list, child_depth + 1);
            }

            list.push([g.node_parent[sub_grid_index], child_depth, g]);
            g.node_parent[sub_grid_index].last_update = node_tick;
        }
    }
}

function drop_item_from_object(object_id, xx, yy, infusion) {
    var old_item = find_item_prototype(object_id);
    if old_item != undefined {
        var inst = instance_create_layer(xx, yy, "Instances", obj_item);
        inst.move_z = true;
        var item = new LiveItem(old_item.item_id);
        if item.infusion == undefined {
            item.infusion = infusion;
        }
        inst.setup(List(item));
    }
}

function find_item_prototype(object) {
    for(var i = 0, j = array_length(ITEM_PROTOTYPES); i < j; i ++) {
        item_obj = ITEM_PROTOTYPES[i].object;
        if item_obj == object {
            return ITEM_PROTOTYPES[i];
        }
    }
    return undefined;
}

//
function essence_get_change(node) {
    var items = [];
    var essence = node.essence_supply;
    for (var i = 0, c = array_length(ESSENCE_STONES); i < c; i++) {
        var stone = ITEM_PROTOTYPES[ESSENCE_STONES[i]];
        for (var j = 0, jc = essence div stone.essence_charge; j < jc; j++) {
            essence -= stone.essence_charge;
            array_push(items, new LiveItem(ESSENCE_STONES[i]))
        }
    }

    return items;
}
