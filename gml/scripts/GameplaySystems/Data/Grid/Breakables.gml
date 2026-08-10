function create_breakable_prototype(object_id, fiddle_obj) {
    static LEAF_PILE_DEBRIS = new ParticleGrassExplosionBundle()
        .set_instances_range(20, 24)
        .set_offset(0, 5)
        .set_spawn_rectangle(-8, 8, 2, 15);
    static BRANCH_DEBRIS = new ParticleBundle();
    static BUSH_DEBRIS = new ParticleGrassBundle()
        .set_instances_range(6, 8);
    static CORAL_DEBRIS = new ParticleGrassBundle()
        .set_instances_range(6, 8);

    var o = {
        object_id: object_id,
        max_hits: fiddle_obj.hits,
        size: fiddle_deserialize_vec2(fiddle_obj.size),
        offset: fiddle_deserialize_vec2(fiddle_obj.offset),
        collideable: fiddle_obj.collideable,
        dungeon_only: fiddle_obj.dungeon_only,
        minimum_quality: string_to_quality_id(fiddle_obj.minimum_quality),
        drop_bundle: undefined,
        debris: undefined,
        ladder_candidate: fiddle_obj.ladder_candidate,
        sound_on_collide: fiddle_obj.sound_on_collide == false ? undefined : fiddle_obj.sound_on_collide,
        interact_mask: opt_and_then(fiddle_obj[$ "interact_mask"], string_to_asset),
        destruction_sfx: opt_and_then(fiddle_obj[$ "destruction_sfx"], audio_asset_assert_exists),
        chest: opt_and_then(fiddle_obj[$ "chest"], function(chest) {
            return {
                open_sprite : string_to_asset(chest[$ "open_sprite"]),
                opening_sprite : string_to_asset(chest[$ "opening_sprite"]),
                closed_sprite : string_to_asset(chest[$ "closed_sprite"]),
                ore_count: chest[$ "ore_count"] ?? 0,
                gem_chance: chest[$ "gem_chance"] ?? 0,
                mana_chance: chest[$ "mana_chance"] ?? 0,
                extras_chance: chest.extras_chance,
                essence_stone: try_string_to_item_id(chest[$ "essence_stone"]),
            }
            //
            return data;
        })
    };

    switch fiddle_obj.debris_emitter {
        case "branch":
            o.debris = BRANCH_DEBRIS;
            break;
        case "bush":
            o.debris = BUSH_DEBRIS;
            break;
        case "leaf_pile":
            o.debris = LEAF_PILE_DEBRIS;
            break;
        case "coral":
            o.debris = CORAL_DEBRIS;
            break;
        case 0:
            //
            break;
        default: impossible("unexpected debris name {}", fiddle_obj.debris_emitter);
    }

    if o.dungeon_only || object_id == ObjectId.TreasureChestSecret {
        o.on_destruction_particles = fiddle_deserialize_biome(fiddle_obj[$ "on_destruction_particles"], function(sprite_array) { return array_map(sprite_array, string_to_asset)});
        o.sprites = fiddle_deserialize_biome(fiddle_obj[$ "sprites"], function(sprite_array) { return array_map(sprite_array, string_to_asset)});
        o.drop_bundle = fiddle_deserialize_biome(fiddle_obj[$ "drops"], create_fiddle_drops);
    } else {
        o.on_destruction_particles = fiddle_deserialize_season(fiddle_obj[$ "on_destruction_particles"], function(sprite_array) { return array_map(sprite_array, string_to_asset)});
        o.sprites = fiddle_deserialize_season(fiddle_obj[$ "sprites"], function(sprite_array) { return array_map(sprite_array, string_to_asset)});
        o.drop_bundle = fiddle_deserialize_season(fiddle_obj[$ "drops"], create_fiddle_drops);
    }

    return o;
}

function write_breakable_to_location(grid, xx, yy, proto) {
    var node = attempt_to_write_object_node(grid, xx, yy, proto.size, proto, proto.collideable);
    if (node == undefined) {
        return undefined;
    }

    //
    node.hitpoints = node.prototype.max_hits;
    node.is_locked = false;
    node.variant_idx = irandom_range(0, 99) / 100.0;
    node.ladder_candidate = node.prototype.ladder_candidate;

    if node.prototype.chest != undefined {
        node.is_open = false;

        if node.prototype.dungeon_only == false {
            node.items = undefined;
        }
    }

    return node;
}

//
function create_breakable_renderer(node) {
    var spr_array;

    if node.prototype.dungeon_only {
        spr_array = node.prototype.sprites[current_dungeon_biome() ?? DungeonBiome.Upper];
    } else {
        spr_array = node.prototype.sprites[CALENDAR.season()];
    }

    var spr = spr_array[floor(array_length(spr_array) * node.variant_idx)];

    node.renderer = create_node_renderer(
        (node.top_left_x * 8) + node.prototype.offset.x,
        (node.top_left_y * 8) + node.prototype.offset.y,
        node,
        spr,
    );

    if node.prototype.chest != undefined {
        if node.is_open {
            node.renderer.set_sprite(node.prototype.chest.open_sprite);
            node.renderer.image_speed = 0;
        } else {
            node.renderer.set_sprite(node.prototype.chest.closed_sprite);
            node.renderer.mask_index = node.prototype.interact_mask;

            if node.prototype.dungeon_only {
                node.renderer.interact("misc_local/input_interact", node.prototype.interact_mask);
                node.renderer.give_animation_end_callback(function() {
                    if self.sprite_index == self.node.prototype.chest.opening_sprite
                        && self.node.is_locked == false
                    {
                        self.node.is_open = true;
                        self.set_sprite(self.node.prototype.chest.open_sprite);
                        self.image_speed = 0;

                        var drop_chain = new_chain()
                            .append(LinkId.Timer, 40);

                        //
                        var biome_ore = DUNGEON.biomes[current_dungeon_biome() ?? DungeonBiome.Upper].ore;
                        var ore_count = irandom_range(node.prototype.chest.ore_count[0], node.prototype.chest.ore_count[1]);
                        for (var i = 0; i < ore_count; i++) {
                            if is_dungeon_room(room()) {
                                array_push(GS_MINES_FLOOR.chest_items_released, item_id_to_string(biome_ore));
                            }

                            drop_chain
                                .append(LinkId.Function, drop_item, [biome_ore, node.renderer.x, node.renderer.y, -4])
                                .append(LinkId.Timer, 10);
                        }

                        var biome = DUNGEON.biomes[current_dungeon_biome() ?? DungeonBiome.Upper];

                        //
                        if chance_percent(node.prototype.chest.extras_chance) {
                            var item_id = undefined;
                            repeat array_length(biome.cosmetics) {
                                var maybe = biome.cosmetics[irandom_range(0, array_length(biome.cosmetics) - 1)];
                                if ari_has_cosmetic_anywhere(maybe) == false {
                                    item_id = maybe;
                                    break;
                                }
                            }
                            if item_id != undefined {
                                var li = new LiveItem(ItemId.Cosmetic);
                                li.cosmetic = item_id;
                                drop_chain
                                    .append(LinkId.Function, drop_item, [li, node.renderer.x, node.renderer.y, -4])
                                    .append(LinkId.Timer, 30);
                            }
                        }

                        //
                        var data = get_treasure_from_distribution(node.top_left_x, node.top_left_y);
                        if data != undefined {
                            if data[1] {
                                drop_chain
                                    .append(LinkId.Function, item_from_critical_poof, [node.renderer.x, node.renderer.y + 4, data[0]])
                                    .append(LinkId.Timer, 30);
                            } else {
                                if data[0].item_id == ItemId.RecipeScroll || data[0].item_id == ItemId.CraftingScroll {
                                    ARI.recipes_created[data[0].inner_item] = true;
                                }
                                drop_chain
                                    .append(LinkId.Function, drop_item, [data[0], node.renderer.x, node.renderer.y, -4])
                                    .append(LinkId.Timer, 10);
                            }
                        }

                        //
                        if ARI.perk_active(Perk.TasteMaker) && chance_percent(node.prototype.chest.extras_chance)  {
                            var item_id = undefined;
                            repeat array_length(biome.taste_maker) {
                                var maybe = biome.taste_maker[irandom_range(0, array_length(biome.taste_maker) - 1)];
                                if ari_has_recipe_anywhere(maybe) == false {
                                    item_id = maybe;
                                    break;
                                }
                            }
                            if item_id != undefined {
                                drop_chain
                                    .append(LinkId.Function, item_from_critical_poof, [node.renderer.x, node.renderer.y + 4, new LiveItem(ItemId.RecipeScroll, item_id)])
                                    .append(LinkId.Timer, 30);
                            }
                        }

                        //
                        if ARI.perk_active(Perk.Reclaimer) && chance_percent(node.prototype.chest.extras_chance) {
                            var item_id = undefined;
                            repeat array_length(biome.furniture) {
                                var maybe = biome.furniture[irandom_range(0, array_length(biome.furniture) - 1)];
                                if ari_has_recipe_anywhere(maybe) == false {
                                    item_id = maybe;
                                    break;
                                }
                            }
                            if item_id != undefined {
                                drop_chain
                                    .append(LinkId.Function, item_from_critical_poof, [node.renderer.x, node.renderer.y + 4, new LiveItem(ItemId.CraftingScroll, item_id)])
                                    .append(LinkId.Timer, 30);
                            }
                        }

                        //
                        if chance_percent(node.prototype.chest.mana_chance) {
                            drop_chain
                                .append(LinkId.Timer, 10)
                                .append(LinkId.Function, drop_item, [ItemId.ManaPotion, node.renderer.x, node.renderer.y, -4])
                        }
                        //
                        if node.prototype.chest.essence_stone != undefined && chance_percent(fiddle_get("misc/global_essence_crystal_chance")) {
                            drop_chain
                                .append(LinkId.Timer, 10)
                                .append(LinkId.Function, drop_item, [node.prototype.chest.essence_stone, node.renderer.x, node.renderer.y, -4])
                        }

                        if chance_percent(fiddle_get("misc/rough_gemstone_chance") * 100)
                            && array_contains(ARI.date_unlocks, true)
                            && !ARI.date_unlocks[Date.GemCutting]
                            && !any_item_matches(ItemId.RoughGemstone)
                        {
                            drop_chain
                                .append(LinkId.Timer, 10)
                                .append(LinkId.Function, drop_item, [ItemId.RoughGemstone, node.renderer.x, node.renderer.y, -4])
                        }
                    }
                });
            } else {
                //
            }
        }
    }

    if node.object_id == ObjectId.WiltedPlant {
        node.renderer.sway_on_impact = true;
    }
}

function create_breakable_debris(_renderer) {
    var node = _renderer.node;
    if node.prototype.debris == undefined {
        return;
    }

    var _rep = node.prototype.debris.get_instances();
    var insert = node.prototype.dungeon_only ? DUNGEON_BIOME : CALENDAR.season();

    var sprite_array = node.prototype.on_destruction_particles[insert];
    var spr = sprite_array[floor(array_length(sprite_array) * node.variant_idx)];

    repeat (_rep) {
        create_debris(
            _renderer.x,
            _renderer.y,
            _renderer.depth - 1,
            spr,
            node.prototype.debris,
        )
    }
}

function breakable_open_chest(node) {
    //
    node.renderer.sprite_index = node.prototype.chest.opening_sprite;
    node.renderer.image_speed = 1;

    TANGO.play("SoundEffects/Objects/TreasureChestOpen", node.renderer.x, node.renderer.y);
}

function create_treasure_distributions(biome) {
    var spawn_distribution_per_biome = new SpawnDistribution();

    //
    spawn_distribution_per_biome.add_candidate(
        biome.gem,
        new SpawnConditions().add(5),
    );

    //
    for (var i = 0; i < array_length(biome.dungeon_delicacies); i++) {
        spawn_distribution_per_biome.add_candidate(
            biome.dungeon_delicacies[i],
            new SpawnConditions().add(5)
                .require(Condition.HasPerk(Perk.DungeonDelicacies)),
        );
    }

    //
    for (var i = 0; i < array_length(biome.armor); i++) {
        spawn_distribution_per_biome.add_candidate(
            biome.armor[i],
            new SpawnConditions().add(5).require(Condition.HasPerk(Perk.WellArmed)),
        );
    }

    //
    for (var i = 0; i < array_length(biome.furniture); i++) {
        spawn_distribution_per_biome.add_candidate(
            biome.furniture[i],
            new SpawnConditions().add(5)
                .require(Condition.HasPerk(Perk.Reclaimer)),
        );

    }

    return spawn_distribution_per_biome;
}

function get_treasure_from_distribution(xx, yy) {
    var distro = DUNGEON_TREASURE[current_dungeon_biome() ?? DungeonBiome.Upper]
    var candidate = distro.get_candidate_votes_at_cell(GRID, xx, yy).get_candidate();

    var candidate_index = distro.spawnable_candidates.find(function(needle, value) {
        if is_array(value) {
            return is_array(needle.candidate_id) && needle.candidate_id[0] == value[0] && needle.candidate_id[1] == value[1];
        } else {
            return needle.candidate_id == value;
        }
    }, candidate);

    if candidate == undefined {
        return undefined;
    } else {
        assert_neq(candidate_index, undefined, "failed to find candidate_index");
        var candidate_data = distro.spawnable_candidates.get(candidate_index);

        var conditions = candidate_data.spawn_conditions.required_conditions;
        var is_perk = false;
        for (var i = 0; i < conditions.count(); i++) {
            var condition = conditions.get(i);
            if condition.condition.type == ConditionId.HasPerk {
                is_perk = true;
                break;
            }
        }

        var candidate_live_item;
        if is_array(candidate) {
            switch candidate[0] {
                case AnnoyingItem.Cosmetic:
                    candidate_live_item = new LiveItem(ItemId.Cosmetic);
                    candidate_live_item.cosmetic = candidate[1];
                    break;
                case AnnoyingItem.RecipeScroll:
                    candidate_live_item = new LiveItem(ItemId.RecipeScroll, candidate[1]);
                    break;
                case AnnoyingItem.CraftingScroll:
                    candidate_live_item = new LiveItem(ItemId.CraftingScroll, candidate[1]);
                    break;
                default: impossible("unexpected item_description: {}", candidate[0])
            }
        } else {
            candidate_live_item = new LiveItem(candidate);
        }

        return [candidate_live_item, is_perk];
    }
}
