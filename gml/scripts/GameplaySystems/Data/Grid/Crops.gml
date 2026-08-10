//
enum CropFlag {
    //
    EMPTY,

    //
    MANAGED = 1,

    //
    FORAGEABLE = 1 << 1,

    //
    NO_HARVEST = 1 << 2,

    //
    SPAWN_GROWN = 1 << 3,
}

//
function create_crop_prototype(object_id, fiddle_obj) {
    var o = {
        object_id: object_id,
        seasons: deserialize_array_bool(wrap_in_array(fiddle_obj.seasons), string_to_season, Season.LEN),
        sprites: array_map(fiddle_obj.sprites ?? [], string_to_asset),
        size: fiddle_deserialize_vec2(fiddle_obj.size),
        harvest: fiddle_obj.harvest,
        day_to_stage: fiddle_obj.day_to_stage,
        harvest_time_enabled: fiddle_obj.harvest_time_enabled,
        post_harvest_day_to_stage: undefined,
        interact_size: fiddle_obj.interact_size,
        sound_on_collide: fiddle_obj.sound_on_collide,
        count: fiddle_obj.count,
        offset: fiddle_deserialize_vec2(fiddle_obj.offset),
        sways: fiddle_obj.sways,
        stage_zero_is_seed: fiddle_obj.stage_zero_is_seed,
        mound_sprite: string_to_asset(fiddle_obj.mound_sprite),
        winter_mound_sprite: string_to_asset(fiddle_obj.winter_mound_sprite),
        managed_regrow_sprite: string_to_asset(fiddle_obj.managed_regrow_sprite),
        managed_regrow_days: fiddle_obj.managed_regrow_days,
        currency: fiddle_obj.currency,
        mound_sprite_is_floor: fiddle_obj.mound_sprite_is_floor,
        faux_crop: opt_and_then(fiddle_obj[$ "faux_crop"], string_to_item_id),
        animated_sprite: fiddle_obj.animated_sprite,
        is_plant: fiddle_obj.is_plant
    };

    //
    if o.harvest == "<..>" {
        o.harvest = object_id_to_string(object_id);
    }

    if fiddle_obj.animated_sprite == false {
        o.animated_sprite = undefined;
    } else {
        o.animated_sprite = string_to_asset(fiddle_obj.animated_sprite);
    }
    o.harvest = string_to_item_id(o.harvest);

    if o.day_to_stage != undefined {
        o.day_to_stage = ListFromArray(array_clone(o.day_to_stage));

        //
        var stage_number = 0;
        for (var i = 0; i < o.day_to_stage.count(); i++) {
            var this_stage = o.day_to_stage.get(i);
            if this_stage > stage_number {
                assert_eq(this_stage - stage_number, 1, "{ObjectId} jumps a stage in its day_to_stage", object_id)
                stage_number = this_stage;
            }
        }

        assert_eq(
            stage_number,
            array_length(o.sprites) - 1,
            "{ObjectId} doesn't have enough day_to_stage (or too many sprites)",
            object_id
        );
    };

    if array_length(o.sprites) == 1 {
        o.stage_zero_is_seed = false;
    }

    //
    //
    if fiddle_obj.regrow_days != 0 {
        assert(fiddle_obj.regrow_days > 0, "negative regrowth?? Are you trying to break the game!");
        var final_stage = o.day_to_stage.last();
        var stage_to_stick = final_stage - 1;

        var post_harvest_day_to_stage = ListFromArray(array_create(fiddle_obj.regrow_days + 1, stage_to_stick));
        post_harvest_day_to_stage.set(fiddle_obj.regrow_days, final_stage);

        o.post_harvest_day_to_stage = post_harvest_day_to_stage;
    }

    return o;
}

//
function write_crop_to_location(grid, xx, yy, proto, ctx=CropFlag.EMPTY) {
    //
    if grid.location_id == LocationId.Farm && proto.seasons[CALENDAR.season()] == false {
        return undefined;
    }

    var node = attempt_to_write_object_node(grid, xx, yy, proto.size, proto, false, true);
    if node == undefined {
        return undefined;
    }

    //
    node.ctx = ctx;

    if has_flag(node.ctx, CropFlag.SPAWN_GROWN) {
        node.day_count = node.prototype.day_to_stage.count() - 1;
    } else {
        node.day_count = 0;
    }

    if has_flag(node.ctx, CropFlag.MANAGED) {
        node.managed_timer = undefined;
    }
    node.regrow_cycle = false;
    node.stage = node.prototype.day_to_stage.get(node.day_count);

    return node;
}

//
function create_crop_renderer(node) {
    var spr;

    if has_flag(node.ctx, CropFlag.MANAGED) && node.managed_timer != undefined {
        spr = node.prototype.managed_regrow_sprite;
    } else {
        var stage = clamp(node.stage, 0, array_length(node.prototype.sprites) - 1);
        spr = node.prototype.sprites[stage];
    }

    node.renderer = create_node_renderer(
        (node.top_left_x * 8) + node.prototype.offset.x,
        (node.top_left_y * 8) + node.prototype.offset.y,
        node,
        spr,
    );

    var is_seed = node.prototype.stage_zero_is_seed && node.stage == 0;

    //
    node.renderer.sway_on_impact = !is_seed && node.prototype.sways;

    //
    if is_seed {
        node.renderer.depth = get_floor_depth();
    }

    if node.prototype.harvest != undefined {
        node.renderer.interact("misc_local/harvest");
    }
    node.renderer.interactable_mode = InteractableMode.Circle;
    node.renderer.circle_size = node.prototype.interact_size;

    if has_flag(node.ctx, CropFlag.MANAGED)
        && has_flag(node.ctx, CropFlag.NO_HARVEST) == false
    {
        var mound_sprite;
        if CALENDAR.season() == Season.Winter {
            mound_sprite = node.prototype.winter_mound_sprite;
        } else {
            mound_sprite = node.prototype.mound_sprite;
        }

        if node.prototype.mound_sprite_is_floor {
            var spr_renderer = create_sprite_renderer(node.renderer.x, node.renderer.y, 0, mound_sprite);
            spr_renderer.depth = get_floor_depth();
            node.renderer.targets_to_destroy = List(spr_renderer);
        } else {
            node.renderer.secondary_sprite = mound_sprite;
        }

        //
        if node.prototype.mound_sprite_is_floor && node.managed_timer != undefined {
            node.renderer.depth = get_floor_depth();
        }
    }

    if CURRENT_LOCATION_ID == LocationId.Farm && node_is_animal_food(node) {
        node.renderer.linked_object = instance_create_layer(node.renderer.x, node.renderer.y, "Instances", obj_animal_food_marker, {
            paired_renderer: node.renderer
        });
    }
}

//
function crop_node_new_day(grid, node) {
    //
    if grid.location_id == LocationId.Farm && node.prototype.seasons[CALENDAR.season()] == false {
        return false;
    }

    node.day_count += 1;

    if has_flag(node.ctx, CropFlag.MANAGED) && node.managed_timer != undefined {
        node.managed_timer -= 1;
        if node.managed_timer <= 0 {
            node.managed_timer = undefined;
        }
    }

    var day_to_stage;
    if node.regrow_cycle {
        if is_nullish(node.prototype.post_harvest_day_to_stage) {
            error("somehow, we're regrow_cycle, but no post_harvest? in: {ObjectId}", node.prototype.object_id);
            day_to_stage = node.prototype.day_to_stage;
        } else {
            day_to_stage = node.prototype.post_harvest_day_to_stage;
        }
    } else {
        day_to_stage = node.prototype.day_to_stage;
    }

    if ARI.perk_active(Perk.HarvestTime)
        && node.prototype.harvest_time_enabled
        && node.regrow_cycle == false
        && node.day_count == (day_to_stage.count() - 2)
    {
        node.day_count += 1;
    }

    var next_stage = day_to_stage.try_get(node.day_count);
    if next_stage != undefined && node.stage != next_stage {
        node.stage = next_stage;
        var spr = node.prototype.sprites[node.stage];
        if node.renderer != undefined && instance_exists(node.renderer) {
            node.renderer.set_sprite(spr);
        }
    } else {
        //
    }

    return true;
}

function process_crop_harvest(node, harvester_cardinal) {
    var destroy = true;

    //
    //
    if has_flag(node.ctx, CropFlag.MANAGED) {
        destroy = false;
    }

    if node.prototype.post_harvest_day_to_stage != undefined {
        node.regrow_cycle = true;
        node.day_count = 0;
        node.stage = node.prototype.post_harvest_day_to_stage.get(node.day_count);
        destroy = false;
    }

    if has_flag(node.ctx, CropFlag.FORAGEABLE) {
        destroy = true;
    }

    if destroy {
        erase_object_node_by_parent(GRID, node);
    } else {
        var spr;

        if has_flag(node.ctx, CropFlag.MANAGED) {
            node.managed_timer = node.prototype.managed_regrow_days;
            spr = node.prototype.managed_regrow_sprite;

            if node.prototype.stage_zero_is_seed
                && chance_percent(ARI.perk_value(Perk.PreparedPicker))
            {
                for (var i = 0; i < ItemId.LEN; i++) {
                    if ITEM_PROTOTYPES[i].use == ItemUse.PlantSeed && ITEM_PROTOTYPES[i].crop_object == node.prototype.object_id {
                        item_from_critical_poof(node.renderer.x, node.renderer.y, i);
                        break;
                    }
                }
                GAME_STATS.perks[$ perk_to_string(Perk.PreparedPicker)] += 1;
            }

        } else {
            spr = node.prototype.sprites[node.stage];
        }

        node.renderer.set_sprite(spr);
        sway_renderer(node.renderer, harvester_cardinal);
    }

    return destroy;
}

//
function level_up_crop(node) {
    var day_to_stage;
    if node.regrow_cycle {
        if is_nullish(node.prototype.post_harvest_day_to_stage) {
            error("somehow, we're regrow_cycle, but no post_harvest? in: {ObjectId}", node.prototype.object_id);
            day_to_stage = node.prototype.day_to_stage;
        } else {
            day_to_stage = node.prototype.post_harvest_day_to_stage;
        }
    } else {
        day_to_stage = node.prototype.day_to_stage;
    }

    var output = 1;
    var max_stage = day_to_stage.last();
    if node.stage != max_stage {
        output = max_stage - node.stage;
        node.day_count = day_to_stage.find_lazy(node.stage + 1);
        node.stage += 1;

        if node.stage != max_stage {
            //
            new_chain()
                .append(LinkId.Timer, GROWTH_SPELL_DING_LENGTH)
                .append(LinkId.Function, level_up_crop, [node, false]);
        }

    }

    //
    if has_flag(node.ctx, CropFlag.MANAGED) {
        node.managed_timer = undefined;
    }

    //
    if instance_exists(node.renderer) {
        //
        if chance_percent(25) {
            create_animation_effect(node.renderer.x, node.renderer.y, node.renderer.depth - 4, spr_part_sparkle_item_icon);
        }

        //
        var spr = node.prototype.sprites[node.stage];
        node.renderer.set_sprite(spr);
        node.renderer.depth = get_instance_depth(node.renderer.y);

        node.renderer.highlight_interactable = true;
        node.renderer.highlighter.request_highlight_mode = true;
        node.renderer.highlighter.override_strength = 0.45;
        node.renderer.highlighter.override_strength_decrease = 0.01;

        //
        sway_renderer(node.renderer, Cardinal.East);
    }

    return output;
}
