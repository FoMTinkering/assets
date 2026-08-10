//
//
//
//
function slash_node(grid, x_pos, y_pos, parent_obj) {
    var inst_index = grid.try_node_index_for_cell(x_pos, y_pos);
    if inst_index == undefined {
        return false;
    }

    switch object_id_to_object_category(grid.node_object_id[inst_index]) {
        case ObjectCategory.Grass:
            var node = grid.node_parent[inst_index];
            create_grass_debris(node.renderer);
            set_rumble_additive(RumbleKind.ToolWeak, 3);

            if chance_percent(fiddle_get("misc/bugs/in_grass_chance")) {
                spawn_bug(node.renderer.x div 8, node.renderer.y div 8, BugSpawnType.Grass);
            }

            var bundle = node.prototype.drop_bundle.choose_drop();

            try_gather_item_spawn(GatherDropChance.SlashGrass, node.renderer.x, node.renderer.y);

            if bundle.is_empty() == false {
                drop_item(bundle.to_array(), node.renderer.x, node.renderer.y);

                if ARI.perk_value(Perk.FeedingFrenzy) {
                    GAME_STATS.perks[$ perk_to_string(Perk.FeedingFrenzy)] += 1;
                    item_from_critical_poof(
                        node.renderer.x,
                        node.renderer.y,
                        bundle.to_array(),
                    );
                }
            }

            TANGO.play("SoundEffects/Objects/SmallBushDestroy", node.renderer.x, node.renderer.y);
            //
            erase_object_node(grid, inst_index);
            return true;
        case ObjectCategory.Breakable:
            var node = grid.node_parent[inst_index];
            create_breakable_debris(node.renderer);

            node.hitpoints -= 1;
            traumatize(node.renderer, 1);

            set_rumble_additive(RumbleKind.ToolWeak, 3);

            if node.hitpoints <= 0 {
                var bundle;
                if node.prototype.dungeon_only {
                    var bonus = 1;
                    if ARI.perk_active(Perk.UndergroundInspiration)
                        && (grid.node_object_id[inst_index] == ObjectId.CoralLarge
                        || grid.node_object_id[inst_index] == ObjectId.CoralSmall
                        || grid.node_object_id[inst_index] == ObjectId.CrystalLarge
                        || grid.node_object_id[inst_index] == ObjectId.CrystalSmall) {
                        bonus = 2;
                        GAME_STATS.perks[$ perk_to_string(Perk.UndergroundInspiration)] += 1;
                    }
                    bundle = node.prototype.drop_bundle[DUNGEON_BIOME].choose_drop(bonus);
                } else {
                    bundle = node.prototype.drop_bundle[CALENDAR.season()].choose_drop();
                }

                var arr = bundle.to_array();

                if GS_MINES_RUN != undefined {
                    for (var i = 0, c = array_length(arr); i < c; i++) {
                        var item = arr[i];
                        array_push(GS_MINES_FLOOR.debris_items_released, item_id_to_string(item.item_id));
                    }
                    if ARI.perk_active(Perk.MaterialWorld) {
                        for (var i = 0, c = array_length(arr); i < c; i++) {
                            var item = arr[i];
                            array_push(GS_MINES_FLOOR.debris_items_released, item_id_to_string(item.item_id));
                        }
                        if array_length(arr) != 0 {
                            item_from_critical_poof(node.renderer.x, node.renderer.y, arr);
                        }
                    }

                    if chance_percent(ARI.perk_value(Perk.VoidValue))
                        && (node.object_id == ObjectId.VoiditeSmall || node.object_id == ObjectId.VoiditeLarge)
                    {
                        item_from_critical_poof(node.renderer.x, node.renderer.y, arr);
                        for (var i = 0, c = array_length(arr); i < c; i++) {
                            var item = arr[i];
                            array_push(GS_MINES_FLOOR.debris_items_released, item_id_to_string(item.item_id));
                        }
                    }
                }

                try_gather_item_spawn(GatherDropChance.SlashBreakable, node.renderer.x, node.renderer.y);

                drop_item(arr, node.renderer.x, node.renderer.y);
                TANGO.play(node.prototype.destruction_sfx, node.renderer.x, node.renderer.y);
                erase_object_node(grid, inst_index);
            }

            if node.prototype.chest != undefined
                && node.is_locked == false
                && node.is_open == false
                && (parent_obj == obj_ari || parent_obj == obj_fire_breath)
            {
                breakable_open_chest(node);
            }

            return true;
        case ObjectCategory.Crop:
            if ARI.perk_active(Perk.SickleSword) {
                interact(grid.node_parent[inst_index]);
                GAME_STATS.perks[$ perk_to_string(Perk.SickleSword)] += 1;
            }
        break;
        default: return false;
    }
}
