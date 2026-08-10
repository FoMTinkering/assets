#macro MAX_TREE_STAGE 4

function create_tree_prototype(object_id, fiddle_obj) {
    static PER_STAGE = function(fiddle_obj, f) {
        var o = array_create(MAX_TREE_STAGE + 1, undefined);

        for (var i = 0; i < MAX_TREE_STAGE + 1; i++) {
            var k = format("stage{}", i + 1);
            o[i] = f(fiddle_obj[$ k], i);
        }

        return o;
    };

    return {
        object_id: object_id,
        day_to_stage: opt_and_then(fiddle_obj[$ "day_to_stage"], function(v) { return ListFromArray(array_clone(v)) }),
        max_hitpoints: opt_and_then(fiddle_obj[$ "max_hitpoints"], function(v) { return ListFromArray(array_clone(v)) }),
        wood_items: ListFromArray(PER_STAGE(fiddle_obj.wood_items, create_fiddle_drops)),
        offsets: PER_STAGE(fiddle_obj.offsets, fiddle_deserialize_vec2),
        sprites: PER_STAGE(fiddle_obj.sprites, function(season_array) {
            return fiddle_deserialize_season(season_array, function(variant_array) {
                return array_map(variant_array, string_to_asset)
            })
        }),
        bird_landing_pos: PER_STAGE(fiddle_obj.bird_landing_pos, function(value) {
            if is_array(value) {
                return fiddle_deserialize_vec2(value);
            } else {
                return undefined;
            }
        }),
        destruct_sprites: fiddle_deserialize_season(fiddle_obj.destruct_sprites, function(variant_array) {
            return array_map(variant_array, string_to_asset)
        }),
        stump_id: opt_and_then(fiddle_obj.stump_id, string_to_object_id),
        interact_mask: opt_and_then(fiddle_obj[$ "interact_mask"], string_to_asset),
        cull_mask: opt_and_then(fiddle_obj[$ "cull_mask"], string_to_asset),
        minimum_quality: string_to_quality_id(fiddle_obj.minimum_quality),
        spawns_bugs: fiddle_obj.spawns_bugs,
        shake_item: opt_and_then(fiddle_obj[$ "shake_item"], string_to_item_id),
        currency: fiddle_obj.currency,
        shake_range_x: fiddle_deserialize_vec2(fiddle_obj.shake_range_x),
        shake_range_y: fiddle_deserialize_vec2(fiddle_obj.shake_range_y),
        fruit_data: opt_and_then(fiddle_obj[$ "fruit_data"], function(fruit_data) {
            return {
                harvest: string_to_item_id(fruit_data.harvest),
                positions: array_map(fruit_data.positions, fiddle_deserialize_vec2),
                regrow_days: fruit_data.regrow_days,
                seasons: HashSetFromArray(array_map(fruit_data.seasons, string_to_season)),
            }
        }),
        burn_iframes: fiddle_obj.burn_iframes,
        transparency_boxes: PER_STAGE(fiddle_obj.transparency_boxes, function(value) {
            return opt_and_then(value, parse_transparency_boxes) ?? [];
        }),
    };
}

function write_tree_to_location(grid, top_left_x, top_left_y, tree_proto) {
    //
    if local_pos_is_valid(grid, top_left_x, top_left_y, Vec2(6, 6)) == false {
        return undefined;
    }

    //
    for (var xx = 0; xx < 6; xx++) {
        for (var yy = 0; yy < 6; yy++) {
            if matches(xx, 0, 1, 4, 5) && matches(yy, 0, 1, 4, 5) {
                continue;
            }
            var ni = grid.node_index_for_cell(top_left_x + xx, top_left_y + yy);

            if can_write_object_on_node(grid, ni, TerrainKind.Ground) == false {
                return undefined;
            }
        }
    }

    var node = create_parent_object_node(tree_proto, top_left_x, top_left_y, Vec2(6, 6));

    //
    for (var xx = 0; xx < 6; xx++) {
        for (var yy = 0; yy < 6; yy++) {
            if matches(xx, 0, 1, 4, 5) && matches(yy, 0, 1, 4, 5) {
                continue;
            }
            var this_cell_node = grid.node_index_for_cell(top_left_x + xx, top_left_y + yy);
            write_object_inst_node(grid, this_cell_node, node);

            if matches(xx, 2, 3) && matches(yy, 2, 3) {
                set_collision_on_node(grid, top_left_x + xx, top_left_y + yy, true);
            }
        }
    }

    //
    node.stage = 0;
    node.day_count = 0;
    node.hitpoints = node.prototype.max_hitpoints.get(node.stage);
    node.fruiting_days = 0;
    node.has_fruit = false;

    //
    node.variant_idx = irandom_range(0, 99) / 100.0;

    return node;
}

function create_tree_renderer(node) {
    var sprite_variants = node.prototype.sprites[node.stage][LOCATIONS[CURRENT_LOCATION_ID].ignore_seasons ? 0 : CALENDAR.season()];
    var sprite = sprite_variants[floor(array_length(sprite_variants) * node.variant_idx)];

    var offset = node.prototype.offsets[node.stage];

    node.renderer = create_node_renderer(
        (node.top_left_x * 8) + offset.x,
        (node.top_left_y * 8) + offset.y,
        node,
        sprite,
    );

    //
    node.renderer.burn_iframes = node.prototype.burn_iframes;

    for (var i = 0; i < array_length(node.prototype.transparency_boxes[node.stage]); i++) {
        var transparency_box = node.prototype.transparency_boxes[node.stage][i];
        //
        //
        //
        instance_create_depth(
            node.top_left_x * 8 + transparency_box.offset.x,
            node.top_left_y * 8 + transparency_box.offset.y,
            0,
            obj_transparency_detector,
            {
                image_xscale: transparency_box.size.x,
                image_yscale: transparency_box.size.y,
                renderer: node.renderer,
            }
        );
    }

    tree_setup_renderer_by_stage(node);
}

//
function tree_setup_renderer_by_stage(node) {
    node.renderer.mask_index = node.prototype.cull_mask;
    var bird_landing_pos = node.prototype.bird_landing_pos[node.stage];
    if bird_landing_pos != undefined
        && (node.renderer.linked_object == undefined || instance_exists(node.renderer.linked_object) == false)
    {
        node.renderer.linked_object = instance_create_depth(
            node.renderer.x + bird_landing_pos.x,
            node.renderer.y,
            0,
            obj_bird_landing_position,
            {
                image_yscale: bird_landing_pos.y
            }
        );
    }

    var rotational_trauma_range = node.stage > 2 ? 4 : 6;
    node.renderer.rotational_trauma_range = rotational_trauma_range;

    //
    if node.stage >= 2 {
        var stump_proto = NODE_PROTOTYPES[node.prototype.stump_id];
        var spr_array = (CALENDAR.season() == Season.Winter) ? stump_proto.winter_sprites : stump_proto.sprites;
        var stump_sprite = spr_array[floor(array_length(spr_array) * node.variant_idx)];
        node.renderer.set_secondary_sprite(stump_sprite);
    } else {
        node.renderer.set_secondary_sprite(undefined);
    }

    if node.has_fruit {
        var fruit_sprite = ITEM_PROTOTYPES[node.prototype.fruit_data.harvest].icon_sprite;
        node.renderer.fruit_sprite = fruit_sprite;
        node.renderer.fruit_sprite_positions = node.prototype.fruit_data.positions;
    }

    if can_interact(node) {
        node.renderer.interact("misc_local/shake", node.prototype.interact_mask);
    }

    node.renderer.has_bug = chance_percent(fiddle_get("misc/bugs/in_tree_chance"))
        && node.prototype.spawns_bugs;
    node.renderer.has_shake_item = chance_percent(fiddle_get("misc/shake_item_in_tree_chance"))
        && node.prototype.shake_item != undefined;
}

function tree_node_new_day(grid, node) {
    //
    if node[$ "restrict_tree_growth"] == TICK {
        return;
    }
    node.day_count += 1;

    var next_stage = node.prototype.day_to_stage.try_get(node.day_count);
    if (next_stage != undefined && node.stage != next_stage) {
        node.stage = next_stage;

        if node.stage == MAX_TREE_STAGE
            && node.prototype.fruit_data != undefined
            //
            && (
                node.prototype.fruit_data.seasons.contains(CALENDAR.season())
                    || LOCATIONS[grid.location_id].ignore_seasons
            )
        {
            node.has_fruit = true;
            node.fruiting_days = 0;
        }
    }

    //
    if node.stage > 3 {
        //
        set_collision_on_node_region(grid, node.top_left_x + 2, node.top_left_y + 2, node.top_left_x + 3, node.top_left_y + 3);

        //
        var x_pos = max(node.top_left_x - 2, 0);
        var y_pos = min(node.top_left_y  + 2, grid.dims.y - 1);

        if x_pos >= 0 {
            for (var xx = x_pos; xx < x_pos + 2; xx++) {
                for (var yy = y_pos; yy < y_pos + 2; yy++) {
                    grid.node_restrict_tree_growth[? grid.node_index_for_cell(xx, yy)] = TICK;
                }
            }
        }

        //
        x_pos += 8;

        for (var xx = x_pos; xx < x_pos + 2; xx++) {
            for (var yy = y_pos; yy < y_pos + 2; yy++) {
                var other_node = grid.try_node_index_for_cell(xx, yy);
                if other_node != undefined {
                    grid.node_restrict_tree_growth[? other_node] = TICK;
                }
            }
        }
    }

    //
    if node.prototype.fruit_data != undefined
        && node.stage == MAX_TREE_STAGE
        && node.has_fruit == false
        && (
            node.prototype.fruit_data.seasons.contains(CALENDAR.season())
                || LOCATIONS[grid.location_id].ignore_seasons
        )
    {
        node.fruiting_days++;

        if node.fruiting_days >= node.prototype.fruit_data.regrow_days {
            node.has_fruit = true;
            node.fruiting_days = 0;
        }
    }

    //
    node.hitpoints = node.prototype.max_hitpoints.get(node.stage);

    //
    for (var xx = 2; xx < 4; xx++) {
        for (var yy = 2; yy < 4; yy++) {
            set_collision_on_node(grid, node.top_left_x + xx, node.top_left_y + yy, node.stage == 0);
        }
    }
}

//
//
function tree_node_initialize_at_stage(grid, node, stage) {
    var min_age = undefined;
    var max_age = undefined;

    //
    //
    for (var i = 0, c = node.prototype.day_to_stage.count(); i < c; i++) {
        var this_stage = node.prototype.day_to_stage.get(i);
        if min_age == undefined {
            if stage == this_stage {
                min_age = i;
            }
        } else {
            if stage != this_stage {
                break;
            }

            max_age = i;
        }
    }

    //
    node.day_count = irandom_range(min_age, max_age) - 1;
    tree_node_new_day(grid, node);
}

function create_tree_debris(node) {
    create_tree_debris_raw(node.prototype, node.variant_idx, node.stage, node.renderer.x, node.renderer.y, node.renderer.depth);
}

function create_tree_debris_raw(node_prototype, variant_idx, stage, xx, yy, depth) {
    static LEAF_DEBRIS = new ParticleFloatingBundle();

    //
    //
    var sprite_variants = node_prototype.sprites[stage][CALENDAR.season()];
    var idx = floor(array_length(sprite_variants) * variant_idx);

    var destruct_sprite_variants = node_prototype.destruct_sprites[CALENDAR.season()];
    var sprite = destruct_sprite_variants[min(array_length(destruct_sprite_variants) - 1, idx)];

    var amt = stage + 1;

    var number = irandom_range(ceil(0.5 * amt), amt);
    repeat number {
        create_debris(
            xx + random_range(-24, 24),
            yy - 24 + random_range(-8, 8),
            depth - 1,
            sprite,
            LEAF_DEBRIS,
        );
    }
}

function setup_tree_drop(node, item, offset) {
    var center_stump_x = (node.top_left_x + 3) * 8;
    var center_stump_y = (node.top_left_y + 4) * 8;
    var inst = instance_create_layer(node.renderer.x + offset.x, node.renderer.y + offset.y, "Instances", obj_item)

    var distance = random_range(15, 30);
    var dir = random_range(180, 360);
    inst.final_x = center_stump_x + lengthdir_x(distance, dir);
    inst.final_y = center_stump_y + lengthdir_y(distance, dir);
    inst.final_z = inst.z;

    inst.z += offset.y;
    inst.move_z = true;

    inst.ignore_this_renderer = node.renderer.id;
    inst.collision_checker = method(inst, function(grid, ni) {
        return ni != undefined
            && grid.node_collideable[ni]
            && (grid.node_object_id[ni] == undefined || grid.node_parent[ni].renderer.id != self.ignore_this_renderer);
    });


    item = new LiveItem(item);
    array_push(GAME_STATS.tree_harvests, {
        item: item.pretty_print(),
        day: total_days(),
    });

    inst.setup(List(item));
}

function tree_attempt_drop_fruit(node) {
    if node.has_fruit {
        var fruit_data = node.prototype.fruit_data;
        for (var i = 0, c = array_length(fruit_data.positions); i < c; i++) {
            var offset = fruit_data.positions[i];

            setup_tree_drop(node, fruit_data.harvest, offset);

        }
        TANGO.play("SoundEffects/Inventory/ItemDrop", node.renderer.x, node.renderer.y);

        node.renderer.fruit_sprite = undefined;
        node.fruiting_days = 0;
        node.has_fruit = false;

        try_gather_item_spawn(GatherDropChance.Harvest, node.renderer.x, node.renderer.y);

        return true;
    } else {
        return false;
    }
}

function tree_attempt_drop_shake_item(node) {
    if node.renderer.has_shake_item {
        setup_tree_drop(
            node,
            node.prototype.shake_item,
            Vec2(
                irandom_range(node.prototype.shake_range_x.x, node.prototype.shake_range_x.y), //
                irandom_range(node.prototype.shake_range_y.x, node.prototype.shake_range_y.y), //
            )
        );
        node.renderer.has_shake_item = false;
    }
}

//
function level_up_tree(node, ignore_season) {
    var max_stage = node.prototype.day_to_stage.last();
    if node.stage == max_stage {
        //
        if node.prototype.fruit_data != undefined
            && (ignore_season || node.prototype.fruit_data.seasons.contains(CALENDAR.season()))
            && node.has_fruit == false
        {
            node.has_fruit = true;
            node.fruiting_days = 0;
        }
    } else {
        node.day_count = node.prototype.day_to_stage.find_lazy(node.stage + 1);
        node.stage += 1;

        //
        tree_node_new_day(GRID, node);
    }

    //
    if instance_exists(node.renderer) {
        //
        if chance_percent(50) {
            create_animation_effect(node.renderer.x, node.renderer.y - 16, node.renderer.depth - 4, spr_part_sparkle_item_icon);
        }

        //
        var sprite_variants = node.prototype.sprites[node.stage][CALENDAR.season()];
        var sprite = sprite_variants[floor(array_length(sprite_variants) * node.variant_idx)];
        var offset = node.prototype.offsets[node.stage];
        node.renderer.set_sprite(sprite);
        node.renderer.x = node.top_left_x * 8 + offset.x;
        node.renderer.y = node.top_left_y * 8 + offset.y;
        if node.renderer.shadow_caster != undefined {
            shadow_caster_set_position(node.renderer.shadow_caster, node.renderer.x, node.renderer.y);
        }

        //
        if node.renderer.linked_object != undefined {
            instance_destroy(node.renderer.linked_object);
            node.renderer.linked_object = undefined;
        }

        tree_setup_renderer_by_stage(node);

        node.renderer.highlight_interactable = true;
        node.renderer.highlighter.request_highlight_mode = true;
        node.renderer.highlighter.override_strength = 0.45;
        node.renderer.highlighter.override_strength_decrease = 0.01;

        rot_traumatize(node.renderer, 0.8);
    }
}
