enum ShovelResult {
    EMPTY = 0,
    SHOW_POOF = 1,
    GIVE_ESSENCE = 1 << 1,
    GAIN_DIG_SITE_EXPERIENCE = 1 << 2,
}

//
function can_shovel_node(x_pos, y_pos) {
    var this_node = GRID.try_node_index_for_cell((x_pos div 2) * 2, (y_pos div 2) * 2);
    if this_node != undefined && GRID.node_object_id[this_node] == ObjectId.DigSite {
        return true;
    }

    if LOCATIONS[CURRENT_LOCATION_ID].farm == false {
        return false;
    }

    for (var xx = x_pos; xx < x_pos + 2; xx++) {
        for (var yy = y_pos; yy < y_pos + 2; yy++) {
            var this_node = GRID.node_index_for_cell(xx,yy);
            if has_flag(GRID.node_flags[this_node], TileFlag.Placeable) == false
                || GRID.node_terrain_kind[this_node] != TerrainKind.Ground
                || GRID.node_terrain_ground_kind[this_node] == GroundKind.RiverBank
            {
                return false;
            }


            if CURRENT_LOCATION_ID != LocationId.Farm
                && object_id_to_object_category(GRID.node_object_id[this_node]) != ObjectCategory.Crop
            {
                return false;
            }

            //
            //
            if GRID.node_object_id[this_node] == ObjectId.MagicKey
                && GRID.node_parent[this_node].stage > 0
                && GRID.node_parent[this_node].stage < 3
            {
                return false;
            }
        }
    }

    return true;
}

//
function shovel_node(grid, x_pos, y_pos, doppel) {
    var inst_index = grid.node_index_for_cell(x_pos, y_pos);

    if can_shovel_node(x_pos, y_pos) == false  {
        if grid.node_object_id[inst_index] != undefined && grid.node_object_id[inst_index] {
            //
            doppel.play_bad(
                "SoundEffects/Tools/WrongToolUse",
                x_pos * 8,
                y_pos * 8
            );
        }
        set_rumble(RumbleKind.ToolInvalid);
        return ShovelResult.EMPTY;
    }
    var shovel_sfx = fiddle_get("tool_fx/shovel");
    set_rumble(RumbleKind.ToolStrong);

    switch object_id_to_object_category(grid.node_object_id[inst_index]) {
        case ObjectCategory.DigSite:
            var success = dig_site_attempt_dig(x_pos, y_pos, ARCHAEOLOGY.choose_random_artifact());
            if success {
                doppel.play_good(shovel_sfx.dig_digsite_sfx);
                return ShovelResult.SHOW_POOF | ShovelResult.GIVE_ESSENCE | ShovelResult.GAIN_DIG_SITE_EXPERIENCE;
            } else {
                return ShovelResult.EMPTY;
            }
            break;
        case ObjectCategory.Crop:
            //
            doppel.play_good(shovel_sfx.dig_digsite_sfx);
            var node = grid.node_parent[inst_index];

            var day_to_stage;
            //
            //
            if node.prototype.post_harvest_day_to_stage != undefined && node.regrow_cycle {
                day_to_stage = node.prototype.post_harvest_day_to_stage;
            } else {
                day_to_stage = node.prototype.day_to_stage;
            }

            if node.stage == day_to_stage.last() {
                interact(node);

                //
                var inst_index = grid.node_index_for_cell(x_pos, y_pos);
                if grid.node_object_id[inst_index] != undefined {
                    erase_object_node(GRID, inst_index);
                }

            } else if node.stage == 0 && node.prototype.stage_zero_is_seed {
                for (var i = 0; i < ItemId.LEN; i++) {
                    if ITEM_PROTOTYPES[i].use == ItemUse.PlantSeed
                        && ITEM_PROTOTYPES[i].crop_object == node.prototype.object_id
                    {
                        drop_item(i, node.renderer.x, node.renderer.y);
                        break;
                    }
                }
                erase_object_node(GRID, inst_index);
            } else {
                erase_object_node(GRID, inst_index);
            }

            return ShovelResult.SHOW_POOF;
    }

    var new_ground_kind;

    switch grid.node_terrain_ground_kind[inst_index] {
        case GroundKind.Grass:
            new_ground_kind = GroundKind.Dirt;
            break;
        case GroundKind.Dirt:
            new_ground_kind = GroundKind.Grass;
            break;
        case GroundKind.Soil:
            new_ground_kind = GroundKind.Grass;
            break;
        case GroundKind.RiverBank:
            impossible("can't get here because of `can_shovel_node`");
    }
    grid.write_ground(x_pos, y_pos, new_ground_kind);

    switch new_ground_kind {
        case GroundKind.Grass:
            doppel.play_good(shovel_sfx.fill_sfx);
            break;
        case GroundKind.Dirt:
            doppel.play_good(shovel_sfx.dig_sfx);
            break;
    }

    return ShovelResult.SHOW_POOF | ShovelResult.GIVE_ESSENCE;
}
