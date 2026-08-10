//
function create_dig_site_prototype(object_id, fiddle_obj) {
    return {
        object_id: object_id,
        sprite_id: string_to_asset(fiddle_obj.sprite),
        offset: fiddle_deserialize_vec2(fiddle_obj[$ "offset"]),
    }
}

//
function write_dig_site_to_location(grid, xx, yy, proto, artifact_override) {
    var node = attempt_to_write_object_node(grid, xx, yy, Vec2(2,2), proto, false);
    if (node == undefined) {
        return undefined;
    }
    node.artifact_override = artifact_override;
    node.day_count = 0;

    return node;
}

function create_dig_site_renderer(node) {
    var sprite_idx = node.prototype.sprite_id;

    node.renderer = create_node_renderer(
        (node.top_left_x * 8) + node.prototype.offset.x,
        (node.top_left_y * 8) + node.prototype.offset.y,
        node,
        sprite_idx,
    );
    node.renderer.depth += 64;
}

function dig_site_attempt_dig(xx, yy, item_to_find) {
    var ni = GRID.node_index_for_cell(xx, yy);
    if GRID.node_object_id[ni] != ObjectId.DigSite {
        return false;
    }

    if GRID.node_parent[ni].artifact_override != undefined {
        item_to_find = GRID.node_parent[ni].artifact_override;
    }

    item_to_find = is_struct(item_to_find) ? item_to_find : new LiveItem(item_to_find);

    if item_to_find.prototype.tags.contains("archaeology") {
        if ARI.items_acquired[item_to_find.item_id] == false {
            //
            item_to_find = new LiveItem(ItemId.UnidentifiedArtifact, item_to_find.item_id);
        }
    } else if item_to_find.item_id == ItemId.Sod || item_to_find.item_id == ItemId.Peat || item_to_find.item_id == ItemId.Clay {
        if ARI.perk_active(Perk.Pursuit) {
            ARI.active_pursuit = true;
        }

        if chance_percent(ARI.perk_value(Perk.Unpeatable)) {
            GAME_STATS.perks[$ perk_to_string(Perk.Unpeatable)] += 1;
            item_from_critical_poof(
                xx * 8 + 8,
                yy * 8 + 8,
                item_to_find
            );
        }
    }

    array_push(GAME_STATS.digs, {
        item_id: item_to_find.pretty_print(),
        day: total_days(),
    });

    if GS_MINES_RUN != undefined {
        array_push(GS_MINES_FLOOR.artifacts, item_to_find.pretty_print());
        if chance_percent(ARI.perk_value(Perk.NaturalBeauty) + ARI.perk_value(Perk.NaturalBeautyTwo)) {
            var furniture_options = [];
            var recipes = DUNGEON.biomes[current_dungeon_biome() ?? DungeonBiome.Upper].recipes
            for (var i = 0, c = array_length(recipes); i < c; i++) {
                if !ari_has_recipe_anywhere(recipes[i]) {
                    array_push(furniture_options, recipes[i]);
                }
            }

            if array_length(furniture_options) != 0 {
                item_to_find= new LiveItem(ItemId.CraftingScroll, furniture_options[irandom(array_length(furniture_options) - 1)]);
            }
        }
    }

    drop_item(item_to_find, xx * 8, yy * 8);
    try_gather_item_spawn(GatherDropChance.DigSite, xx * 8, yy * 8);
    erase_object_node(GRID, ni);
    GRID.write_node(xx, yy, ObjectId.DigSiteDestroyed);

    if chance_percent(fiddle_get("misc/dollhouse_bench_chance") * 100)
        && array_contains(ARI.date_unlocks, true)
        && CURRENT_LOCATION_ID == LocationId.EasternRoad
        && !ARI.date_unlocks[Date.Park]
        && !any_item_matches(ItemId.DollhouseBench)
    {
        item_from_critical_poof(obj_ari.x, obj_ari.y, ItemId.DollhouseBench);
    }

    return true;
}
