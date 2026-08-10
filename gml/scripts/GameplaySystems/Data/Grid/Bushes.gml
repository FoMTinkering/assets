//
enum OffSeason {
    Regress,
    Destroy,
}

//
function create_bush_prototype(object_id, fiddle_obj) {
    var o = {
        object_id: object_id,
        regrow_days: fiddle_obj.regrow_days,
        harvest: try_string_to_item_id(fiddle_obj.harvest),
        size: fiddle_deserialize_vec2(fiddle_obj.size),
        offset: fiddle_deserialize_vec2(fiddle_obj.offset),
        interact_size: fiddle_obj.interact_size,
        sound_on_collide: fiddle_obj.sound_on_collide,
        count: fiddle_obj.count,
        target_terrain: string_to_terrain_kind(fiddle_obj.target_terrain),
        water_bases: opt_and_then(fiddle_obj[$ "water_bases"], function(v) {
            return array_map(v, string_to_asset);
        }),
        off_season: string_to_off_season(fiddle_obj.off_season),
        sway: fiddle_obj.sway,

        sprites: array_create(Season.LEN, undefined),
        seasons: deserialize_array_bool(wrap_in_array(fiddle_obj.seasons), string_to_season, Season.LEN),
        collision_grid: undefined,
    };

    //
    if is_struct(fiddle_obj.sprites) {
        for (var i = 0; i < Season.LEN; i++) {
            o.sprites[i] = array_map(wrap_in_array(fiddle_obj.sprites[$ season_to_string(i)]), string_to_asset);
        }
    } else {
        var season_sprites = array_map(wrap_in_array(fiddle_obj.sprites), string_to_asset);

        for (var i = 0; i < Season.LEN; i++) {
            o.sprites[i] = array_clone(season_sprites);
        }
    }

    //
    var f_col_grid = fiddle_obj.collides;
    o.collision_grid = ds_grid_create(o.size.x, o.size.y);
    if f_col_grid == undefined || f_col_grid == 0 {
        ds_grid_set_region(o.collision_grid, 0, 0, o.size.x - 1, o.size.y - 1, 0);
    } else if is_string(f_col_grid) {
        ds_grid_set_region(o.collision_grid, 0, 0, o.size.x - 1, o.size.y - 1, real(string_char_at(f_col_grid, 1)));
    } else {
        assert_eq(array_length(f_col_grid), o.size.y, "collision_grid height mismatch ({} != {}) for {ObjectId}", array_length(f_col_grid), o.size.y, o.object_id);
        for (var j = 0; j < o.size.y; j ++) {
            var str_seq = f_col_grid[j];
            assert_eq(string_length(str_seq), o.size.x, "collision_grid width mismatch ({} != {}) for {ObjectId}", string_length(str_seq), o.size.x, o.object_id);
            for (var i = 0; i < o.size.x; i ++) {
                o.collision_grid[# i, j] = real(string_char_at(str_seq, i + 1));
            }
        }
    }

    return o;
}

//
function write_bush_to_location(grid, xx, yy, proto) {
    //
    var is_valid = proto.seasons[CALENDAR.season()];
    if is_valid == false && proto.off_season == OffSeason.Destroy {
        return undefined;
    }

    if local_pos_is_valid(grid, xx, yy, proto.size) == false {
        return undefined;
    }
    var node = create_parent_object_node(proto, xx, yy, proto.size);

    for (var i = 0; i < proto.size.x; i++) {
        for (var j = 0; j < proto.size.y; j++) {
            var this_cell_node = grid.node_index_for_cell(xx + i, yy + j);
            write_object_inst_node(grid, this_cell_node, node);

            var col_flag = proto.collision_grid[# i, j];
            if col_flag != 0 {
                set_collision_on_node(grid, xx + i, yy + j, col_flag);
            }
        }
    }

    //
    if is_valid {
        if proto.object_id == ObjectId.WildBerryBush {
            node.day_count = irandom_range(0, proto.regrow_days + 1);
        } else {
            node.day_count = proto.regrow_days + 1;
        }
    } else {
        node.day_count = 0;
    }

    return node;
}

//
function create_bush_renderer(node) {
    var sprite_array = node.prototype.sprites[CALENDAR.season()];
    var stage = min(node.day_count >= node.prototype.regrow_days, array_length(sprite_array) - 1);

    var spr = sprite_array[stage];
    node.renderer = create_node_renderer(
        (node.top_left_x * 8) + node.prototype.offset.x,
        (node.top_left_y * 8) + node.prototype.offset.y,
        node,
        spr,
    );

    node.renderer.sway_on_impact = node.prototype.sway;

    node.renderer.interact("misc_local/harvest");
    node.renderer.interactable_mode = InteractableMode.Circle;
    node.renderer.circle_size = node.prototype.interact_size;

    //
    if node.prototype.target_terrain == TerrainKind.Water {
        node.renderer.water_base_renderer = instance_create_depth(
            (node.top_left_x * 8) + node.prototype.offset.x,
            (node.top_left_y * 8) + node.prototype.offset.y,
            0,
            obj_sprite_renderer,
            {
                sprite_index: node.prototype.water_bases[stage],
            }
        );
        node.renderer.water_base_renderer.depth = get_water_depth() - 1;
        node.renderer.water_base_renderer.image_speed = 1;
    }
}

//
function bush_node_new_day(node) {
    if node.prototype.seasons[CALENDAR.season()] == false {
        return false;
    }

    node.day_count += 1;

    if node.renderer != undefined && instance_exists(node.renderer) {
        var sprite_array = node.prototype.sprites[CALENDAR.season()];
        var stage = min(node.day_count >= node.prototype.regrow_days, array_length(sprite_array) - 1);
        node.renderer.set_sprite(sprite_array[stage]);
    }

    return true;
}

//
function level_up_bush(node) {
    //
    if node.day_count < node.prototype.regrow_days {
        node.day_count = node.prototype.regrow_days;
    }

    //
    if instance_exists(node.renderer) {
        //
        create_animation_effect(node.renderer.x, node.renderer.y, node.renderer.depth - 4, spr_part_sparkle_item_icon);

        var spr = node.prototype.sprites[CALENDAR.season()][1];
        node.renderer.set_sprite(spr);

        if node.prototype.target_terrain == TerrainKind.Water {
            node.renderer.water_base_renderer.sprite_index = node.prototype.water_bases[1];
        }

        node.renderer.highlight_interactable = true;
        node.renderer.highlighter.request_highlight_mode = true;
        node.renderer.highlighter.override_strength = 0.45;
        node.renderer.highlighter.override_strength_decrease = 0.01;

        //
        sway_renderer(node.renderer, Cardinal.East);
    }
}
