//
function can_chop_node(grid, ni, item_struct, xx, yy) {
    if grid.node_object_id[ni] == undefined {
        return false;
    }

    switch grid.node_parent[ni].prototype.category_id {
        case ObjectCategory.Stump:
            //
            break;
        case ObjectCategory.Tree:
            //
            if (xx != (grid.node_parent[ni].top_left_x + 2)
                && xx != (grid.node_parent[ni].top_left_x + 3))
                || (yy != (grid.node_parent[ni].top_left_y + 2)
                && yy != (grid.node_parent[ni].top_left_y + 3))
            {
                return false;
            }
            break;
        default: return false;
    }

    return item_struct.quality >= grid.node_parent[ni].prototype.minimum_quality;
}

//
//
//
function chop_node(grid, x_pos, y_pos, item, modifier, doppel, is_burn=false) {
    var inst_index = grid.node_index_for_cell(x_pos, y_pos);
    var damage = item.damage + modifier;
    //
    var category = object_id_to_object_category(grid.node_object_id[inst_index]);

    var chop_fx = fiddle_get("tool_fx/chop");
    switch category {
        case ObjectCategory.Tree:
            //
            if (x_pos != (grid.node_parent[inst_index].top_left_x + 2)
                && x_pos != (grid.node_parent[inst_index].top_left_x + 3))
                || (y_pos != (grid.node_parent[inst_index].top_left_y + 2)
                && y_pos != (grid.node_parent[inst_index].top_left_y + 3))
            {
                return;
            }

            var node = grid.node_parent[inst_index];

            //
            if is_burn {
                if node.renderer.burn_iframes > 0 {
                    node.renderer.burn_iframes -= 1;
                    return false;
                } else {
                    node.renderer.burn_iframes = node.prototype.burn_iframes;
                }

                //
                if node.prototype.fruit_data != undefined && SETTINGS.get("can_burn_fruit_trees") == false {
                    return false;
                }
            }

            if (item.quality + modifier) < node.prototype.minimum_quality {
                doppel.play_bad(chop_fx.inadequate.sfx, grid.node_top_left_x[inst_index] * 8, grid.node_top_left_y[inst_index] * 8);
                CAMERA.add_trauma(chop_fx.inadequate.cam_trauma);
                traumatize(node.renderer, chop_fx.inadequate.node_trauma);
                set_rumble(RumbleKind.ToolInvalid);
                break;
            }

            node.hitpoints -= min(damage, node.hitpoints);

            //
            create_tree_debris(node);

            //
            if node.renderer.linked_object != undefined
                && instance_exists(node.renderer.linked_object)
                && node.renderer.linked_object.occupied != undefined
            {
                node.renderer.linked_object.spook_bird = true;
            }

            if node.hitpoints <= 0 {
                var entry = chop_fx.destroyed.tree[node.stage];
                doppel.play_good(entry.sfx, node.renderer.x, node.renderer.y);
                set_rumble(RumbleKind.ToolStrong);
                CAMERA.add_trauma(entry.cam_trauma);

                //
                if node.stage > 1 {
                    var inst = instance_create_depth(node.renderer.x, node.renderer.y, node.renderer.depth - 1, obj_falling_tree);
                    inst.sprite_index = node.renderer.sprite_index;
                    inst.prototype = node.prototype;
                    inst.variant_idx = node.variant_idx;
                    inst.stage = node.stage;
                    tree_attempt_drop_fruit(node);
                    tree_attempt_drop_shake_item(node);

                    var variant_idx = node.variant_idx;
                    //
                    erase_object_node(grid, inst_index);

                    //
                    var stump = grid.write_node(node.top_left_x + 2, node.top_left_y + 3, node.prototype.stump_id);
                    assert_neq(stump, undefined);
                    stump.variant_idx = variant_idx;

                    //
                    if is_burn {
                        stump.renderer.burn_iframes = stump.prototype.initial_burn_iframes;
                    }
                } else {
                    //
                    var bundle = node.prototype.wood_items.get(node.stage);
                    if bundle != undefined {
                        var wood = bundle.choose_drop().to_array();
                        drop_item(wood, node.renderer.x, node.renderer.y);
                        try_gather_item_spawn(GatherDropChance.AxeBreak, node.renderer.x, node.renderer.y);
                    }

                    //
                    create_tree_debris(node);

                    erase_object_node(grid, inst_index);
                }
            } else {
                var entry = chop_fx.damaged.tree[node.stage];
                doppel.play_good(entry.sfx, node.renderer.x, node.renderer.y);
                CAMERA.add_trauma(entry.cam_trauma);
                set_rumble(RumbleKind.ToolWeak);
                rot_traumatize(node.renderer, entry.node_trauma);
            }
            return true;

        case ObjectCategory.Stump:
            var node = grid.node_parent[inst_index];

            //
            if is_burn {
                if node.renderer.burn_iframes > 0 {
                    node.renderer.burn_iframes -= 1;
                    return false;
                } else {
                    node.renderer.burn_iframes = node.prototype.initial_burn_iframes;
                }
            }

            if (item.quality + modifier) < node.prototype.minimum_quality {
                doppel.play_good(chop_fx.inadequate.sfx, grid.node_top_left_x[inst_index] * 8, grid.node_top_left_y[inst_index] * 8);
                CAMERA.add_trauma(chop_fx.inadequate.cam_trauma);
                traumatize(node.renderer, chop_fx.inadequate.node_trauma);
                set_rumble(RumbleKind.ToolInvalid);
                break;
            }

            var is_large = node.prototype.size.x > 2 || node.prototype.size.y > 2;
            node.hitpoints -= min(damage, node.hitpoints);

            spawn_wood_debris(node.renderer.x, node.renderer.y, node.renderer.depth, is_large ? spr_part_farm_stump_small : spr_part_farm_stump_big);

            if node.hitpoints <= 0 {
                var tango_name;
                var bundle = node.prototype.drop_bundle.choose_drop();
                if node.object_id == ObjectId.Branch {
                    tango_name = chop_fx.destroyed.branch_sfx;
                    if chance_percent(ARI.perk_value(Perk.Lumberjack)) {
                        item_from_critical_poof(node.renderer.x, node.renderer.y, bundle.to_array());
                        GAME_STATS.perks[$ perk_to_string(Perk.Lumberjack)] += 1;
                    }
                } else {
                    if is_large {
                        tango_name = chop_fx.destroyed.large_stump_sfx;
                    } else {
                        tango_name = chop_fx.destroyed.stump_sfx;
                    }
                }
                set_rumble(RumbleKind.ToolStrong);
                doppel.play_good(tango_name, node.renderer.x, node.renderer.y);
                CAMERA.add_trauma(chop_fx.destroyed.cam_trauma);

                spawn_wood_debris(node.renderer.x, node.renderer.y, node.renderer.depth, is_large ? spr_part_farm_stump_small : spr_part_farm_stump_big);
                drop_item(bundle.to_array(), node.renderer.x, node.renderer.y);
                try_gather_item_spawn(GatherDropChance.AxeBreak, node.renderer.x, node.renderer.y);

                if ARI.perk_active(Perk.LumberjackTwo) {
                    item_from_critical_poof(node.renderer.x, node.renderer.y, bundle.to_array()[0]);
                    GAME_STATS.perks[$ perk_to_string(Perk.LumberjackTwo)] += 1;
                }
                erase_object_node(grid, inst_index);
            } else {
                var tango_name;
                var priority = undefined;
                if node.object_id == ObjectId.Branch {
                    tango_name = chop_fx.damaged.branch_sfx;
                } else if is_large {
                    tango_name = chop_fx.damaged.large_stump_sfx;
                } else {
                    tango_name = chop_fx.damaged.stump_sfx;
                }

                set_rumble(RumbleKind.ToolWeak);
                doppel.play_good(tango_name, priority, node.renderer.x, node.renderer.y);
                CAMERA.add_trauma(chop_fx.damaged.cam_trauma);
                traumatize(node.renderer, chop_fx.damaged.node_trauma);
            }
            return true;

        case ObjectCategory.Grass:
        case undefined:
            set_rumble(RumbleKind.ToolInvalid);
            return false;

        default:
            var node = grid.node_parent[inst_index];

            //
            doppel.play_bad(
                chop_fx.wrong.sfx,
                x_pos * 8,
                y_pos * 8
            );
            CAMERA.add_trauma(chop_fx.wrong.cam_trauma);
            traumatize(node.renderer, chop_fx.wrong.node_trauma);
            set_rumble(RumbleKind.ToolInvalid);
            return false;
    }

    return false;
}
