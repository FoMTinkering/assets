//
function can_hoe_node(grid, ni) {
    return CURRENT_LOCATION_ID == LocationId.Farm
        && grid.node_terrain_kind[ni] == TerrainKind.Ground
        && (grid.node_terrain_ground_kind[ni] == GroundKind.Dirt || grid.node_terrain_ground_kind[ni] == GroundKind.Soil)
        && object_id_to_object_category(grid.node_object_id[ni]) != ObjectCategory.Crop
}

//
function hoe_node(grid, x_pos, y_pos, doppel) {
    var inst_index = grid.node_index_for_cell(x_pos, y_pos);

    if can_hoe_node(grid, inst_index) == false {
        set_rumble(RumbleKind.ToolInvalid);
        return false;
    }

    set_rumble(RumbleKind.ToolStrong);

    var target;
    var hoe_sfx = fiddle_get("tool_fx/hoe");
    switch grid.node_terrain_ground_kind[inst_index] {
        case GroundKind.Grass:
        case GroundKind.RiverBank:
            impossible("we can't get here because we check `can_hoe_node` first.");
        case GroundKind.Soil:
            target = GroundKind.Dirt;
            break;
        case GroundKind.Dirt:
            target = GroundKind.Soil;
            break;
        default: impossible("unexpected ground_kind = {}", grid.node_terrain_ground_kind[inst_index]);
    }
    grid.write_ground(x_pos, y_pos, target);

    if chance_percent(ARI.perk_value(Perk.HeavyDuty)) {
        item_from_critical_poof(x_pos * 8, y_pos * 8, choose(ItemId.OreStone, ItemId.BasicWood));
        GAME_STATS.perks[$ perk_to_string(Perk.HeavyDuty)] += 1;
    }

    //
    if WEATHER.is_inclement() {
        water_node(grid, x_pos, y_pos);
    }

    switch target {
        case GroundKind.Soil:
            doppel.play_good(hoe_sfx.till_sfx);
            break;
        case GroundKind.Dirt:
            doppel.play_good(hoe_sfx.untill_sfx);
            break;
    }

    return true;
}
