object_create(
    "obj_tile_cursor",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            state = TileCursorState.Hidden;
            show_tile_cursor = false;
            sprite_index = spr_blank_pixel;
            target_alpha = 0;
            last_valid_selection = Vec2();
            extra_shadow_casters = List();
            extra_casters_to_draw = 0;
            self.depth = get_floor_depth();

            draw_bottom_lines = false;
            furniture_renderer = instance_create_depth(obj_ari.x, obj_ari.y, obj_ari.depth, obj_furniture_previewer);
            furniture_renderer.sprite_index = spr_furniture_basic_bed_v1_spring;

            //
            bottom_line_renderer = instance_create_depth(obj_ari.x, obj_ari.y, obj_ari.depth, obj_tile_furniture_lines);
            bottom_line_renderer.line_alpha = 0.4
            top_line_renderer = instance_create_depth(obj_ari.x, obj_ari.y, obj_ari.depth, obj_tile_furniture_lines);

            is_charging = false;
            selected_tiles = List();
            simple_draw = false;
            complex_size_x = 0;
            complex_size_y = 0;

            shadow_override = undefined;

            fade_speed = fiddle_get("tile_cursor/fade_speed");

            splotch_shadows_to_draw = List();
            tree_shadows_to_draw = List();

            //
            //
            //
            function select() {
                self.state = TileCursorState.Selected;
                self.last_valid_selection.x = obj_ari.cell_select.x;
                self.last_valid_selection.y = obj_ari.cell_select.y;

                self.set_sprite(self.show_tile_cursor);

                self.target_alpha = 1.0;
                self.show_tile_cursor = false;
            }

            function set_sprite(valid) {
                //
                //
                if valid {
                    var item = ARI.held_item();
                    if item != undefined && item.prototype.use == ItemUse.UseTool && item.prototype.tool_type != ToolType.PickAxe {
                        self.sprite_index = tile_cursor_sprite_bundle().tool[valid];
                        self.simple_draw = true;
                        return;
                    }
                }

                var ni = GRID.node_index_for_cell(self.last_valid_selection.x, self.last_valid_selection.y);
                if GRID.node_object_id[ni] == undefined
                    && GRID.node_rug_id[ni] == undefined
                    && self.last_valid_selection.x % 2 == 0
                    && self.last_valid_selection.y % 2 == 0
                {
                    for (var xx = 0; xx < 2; xx++) {
                        var all_break = false;
                        for (var yy = 0; yy < 2; yy++) {
                            ni = GRID.node_index_for_cell(self.last_valid_selection.x + xx, self.last_valid_selection.y + yy);
                            if GRID.node_object_id[ni] != undefined || GRID.node_rug_id[ni] != undefined {
                                all_break = true;
                                break;
                            }
                        }
                        if all_break {
                            break;
                        }
                    }
                }

                var item = ARI.held_item();
                if item != undefined && item.prototype.use == ItemUse.PlantSapling {
                    self.simple_draw = false;
                } else if GRID.node_object_id[ni] == undefined {
                    //
                    if GRID.node_rug_id[ni] != undefined {
                        self.simple_draw = false;
                        self.complex_size_x = GRID.node_rug_parent[ni].write_size_x + 1;
                        self.complex_size_y = GRID.node_rug_parent[ni].write_size_y + 1;
                        self.sprite_index = tile_cursor_sprite_bundle().furniture[valid];
                        self.last_valid_selection.x = GRID.node_rug_parent[ni].top_left_x;
                        self.last_valid_selection.y = GRID.node_rug_parent[ni].top_left_y;
                    } else {
                        self.sprite_index = tile_cursor_sprite_bundle().tool[valid];
                        self.simple_draw = true;
                    }
                } else {
                    self.complex_draw(valid, GRID.node_parent[ni].top_left_x, GRID.node_parent[ni].top_left_y, GRID.node_parent[ni].write_size_x + 1, GRID.node_parent[ni].write_size_y + 1);
                    if object_id_to_object_category(GRID.node_object_id[ni]) == ObjectCategory.Tree {
                        self.last_valid_selection.x = GRID.node_parent[ni].top_left_x + 2;
                        self.last_valid_selection.y = GRID.node_parent[ni].top_left_y + 2;
                        self.complex_size_x -= 4;
                        self.complex_size_y -= 4;
                    }
                }
            }

            //
            function complex_draw(valid, xx, yy, width, height) {
                self.simple_draw = false;
                self.complex_size_x = width;
                self.complex_size_y = height;

                self.last_valid_selection.x = xx;
                self.last_valid_selection.y = yy;

                self.sprite_index = tile_cursor_sprite_bundle().furniture[valid];
            }

            function clear_charging_shadows() {
                //
                for(var i = 0, c = self.selected_tiles.count(); i < c; i++) {
                    var tile = self.selected_tiles.get(i);
                    SHADOW_GRID.caster_remove(tile.shadow);
                }
                self.selected_tiles.clear();
            }

            function add_charging_shadow(vec, item_prototype) {
                var shadow = SHADOW_GRID.caster_create(vec.x * 8, vec.y * 8);
                shadow_caster_set_sprite(shadow, SHADOW_DICTIONARY.get(tile_cursor_sprite_bundle().tool[false]));
                shadow_caster_set_alpha(shadow, 1.0);

                self.selected_tiles.push({
                    shadow: shadow,
                    pos: vec.clone(),
                    valid: GRID.item_effects_node_at_cell(vec.x, vec.y, item_prototype),
                });
            }

            function draw_parts_of_tile_indicator(size_x, size_y, spr, alpha, off_x=-4, off_y=-4) {
                for (var xx = 0; xx < size_x; xx++) {
                    //
                    var part_x;
                    if xx == 0 {
                        part_x = 0;
                    } else if xx == (size_x - 1) {
                        part_x = 2;
                    } else {
                        part_x = 1;
                    }

                    for (var yy = 0; yy < size_y; yy++) {
                        var part_y;
                        if yy == 0 {
                            part_y = 0;
                        } else if yy == (size_y - 1) {
                            part_y = 2;
                        } else {
                            part_y = 1;
                        }

                        draw_sprite_part(
                            spr,
                            0,
                            12 + part_x * 8,
                            12 + part_y * 8,
                            8,
                            8,
                            (self.last_valid_selection.x + xx) * 8 + off_x,
                            (self.last_valid_selection.y + yy) * 8 + off_y,
                            self.image_blend,
                            alpha
                        );
                    }
                }
            }

            function shadow_draw(shadow_alpha) {
                if self.selected_tiles.count() > 1
                    || self.is_charging
                    || game_paused()
                {
                    return;
                }

                //
                //
                for (var i = 0, c = self.splotch_shadows_to_draw.count(); i < c; i++) {
                    var splotcher = self.splotch_shadows_to_draw.get(i);

                    draw_sprite_part(
                        spr_cursor_placement_splotch_shadow,
                        0,
                        splotcher.part_x,
                        splotcher.part_y,
                        8,
                        9,
                        splotcher.x_pos,
                        splotcher.y_pos,
                        c_black,
                        shadow_alpha,
                    );
                }
                self.splotch_shadows_to_draw.clear();

                for (var i = 0, c = self.tree_shadows_to_draw.count(); i < c; i++) {
                    var tree_data = self.tree_shadows_to_draw.get(i);

                    draw_sprite_ext(
                        spr_cursor_placement_tree_splotch_shadow,
                        0,
                        tree_data.x_pos,
                        tree_data.y_pos,
                        1,
                        1,
                        0,
                        c_black,
                        shadow_alpha,
                    );
                }
                self.tree_shadows_to_draw.clear();

                if self.shadow_override != undefined {
                    self.draw_parts_of_tile_indicator(
                        self.shadow_override.size_x,
                        self.shadow_override.size_y,
                        self.shadow_override.sprite,
                        shadow_alpha,
                        self.shadow_override.off_x,
                        self.shadow_override.off_y,
                    );
                    return;
                }

                //
                if self.image_alpha <= 0.25 {
                    return;
                }

                if self.simple_draw {
                    draw_sprite_ext(
                        SHADOW_DICTIONARY.get(self.sprite_index),
                        0,
                        self.last_valid_selection.x * 8,
                        self.last_valid_selection.y * 8,
                        1,
                        1,
                        0,
                        self.image_blend,
                        shadow_alpha,
                    );
                } else {
                    self.draw_parts_of_tile_indicator(
                        self.complex_size_x,
                        self.complex_size_y,
                        SHADOW_DICTIONARY.get(self.sprite_index),
                        shadow_alpha,
                    );
                }
            }

            function show_tree_splotches(blocker_node, tag) {
                if blocker_node != undefined
                    && GRID.node_object_id[blocker_node] != undefined
                    && GRID.node_parent[blocker_node].last_update != tag
                {
                    GRID.node_parent[blocker_node].last_update = tag;
                    //
                    var cat = object_id_to_object_category(GRID.node_object_id[blocker_node]);

                    switch cat {
                        case ObjectCategory.Tree:
                            draw_sprite_ext(
                                spr_cursor_placement_tree_splotch_indicator,
                                0,
                                GRID.node_top_left_x[blocker_node] * 8,
                                GRID.node_top_left_y[blocker_node] * 8,
                                1,
                                1,
                                0,
                                c_white,
                                0.6
                            );
                            self.tree_shadows_to_draw.push({
                                x_pos: GRID.node_top_left_x[blocker_node] * 8,
                                y_pos: GRID.node_top_left_y[blocker_node] * 8,
                            });
                            break;
                        case ObjectCategory.Building:
                        case ObjectCategory.Furniture:
                            //
                            if GRID.node_object_id[blocker_node] == ObjectId.Mailbox {
                                return;
                            }

                            for (var xx = 0; xx < GRID.node_parent[blocker_node].write_size_x; xx++) {
                                for (var yy = 0; yy < GRID.node_parent[blocker_node].write_size_y; yy++) {
                                    var x_align;
                                    if xx == 0 {
                                        x_align = QuickAlign.Low;
                                    } else if xx == (GRID.node_parent[blocker_node].write_size_x - 1) {
                                        x_align = QuickAlign.High;
                                    } else {
                                        x_align = QuickAlign.Middle;
                                    }
                                    var y_align;
                                    if yy == 0 {
                                        y_align = QuickAlign.Low;
                                    } else if yy == (GRID.node_parent[blocker_node].write_size_y - 1) {
                                        y_align = QuickAlign.High;
                                    } else {
                                        y_align = QuickAlign.Middle;
                                    }

                                    var y_off = cat == ObjectCategory.Furniture ? 2 : 0;

                                    draw_splotch_shared(
                                        (GRID.node_top_left_x[blocker_node] + xx) * 8,
                                        (GRID.node_top_left_y[blocker_node] + yy) * 8 + y_off,
                                        x_align,
                                        y_align,
                                    )
                                }
                            }
                            break;
                    }
                }
            }

            function show_no_furniture_splotches(x_pos, y_pos) {
                var no_furniture = overlap_point(x_pos, y_pos, obj_no_furniture);
                if no_furniture != undefined && no_furniture.tick != TICK {
                    no_furniture.tick = TICK;

                    for (var xx = 0; xx < (no_furniture.image_xscale div 8); xx++) {
                        for (var yy = 0; yy < (no_furniture.image_yscale div 8); yy++) {
                            var x_align;
                            if xx == 0 {
                                x_align = QuickAlign.Low;
                            } else if xx == ((no_furniture.image_xscale div 8) - 1) {
                                x_align = QuickAlign.High;
                            } else {
                                x_align = QuickAlign.Middle;
                            }
                            var y_align;
                            if yy == 0 {
                                y_align = QuickAlign.Low;
                            } else if yy == ((no_furniture.image_yscale div 8) - 1) {
                                y_align = QuickAlign.High;
                            } else {
                                y_align = QuickAlign.Middle;
                            }

                            draw_splotch_shared(
                                no_furniture.x + (xx * 8),
                                no_furniture.y + (yy * 8),
                                x_align,
                                y_align,
                            )
                        }
                    }
                }
            }

            function draw_splotch_shared(x_pos, y_pos, x_align, y_align) {
                draw_sprite_part(
                    spr_cursor_placement_splotch_indicator,
                    0,
                    12 + x_align * 8,
                    12 + y_align * 8,
                    8,
                    8,
                    x_pos,
                    y_pos,
                    c_white,
                    0.6,
                );

                if y_align == QuickAlign.High {
                    self.splotch_shadows_to_draw.push({
                        part_x: 12 + x_align * 8,
                        part_y: 12 + y_align * 8,
                        x_pos,
                        y_pos,
                    });
                }
            }
        },
        step_end: function() {
            //
            if game_paused() || ARI.fire_breath_time > 0 {
                return;
            }

            switch self.state {
                case TileCursorState.Hidden:
                    if self.show_tile_cursor {
                        self.state = TileCursorState.Idle;
                    }

                    break;
                case TileCursorState.Idle:
                    if self.show_tile_cursor == false {
                        self.state = TileCursorState.Hidden;
                    }
                    break;
                case TileCursorState.Selected:
                    //
                    if target_alpha == 1.0 && self.image_alpha >= 1.0 {
                        if self.show_tile_cursor {
                            self.state = TileCursorState.Idle;
                        } else {
                            target_alpha = 0;
                        }
                    }
                    if target_alpha == 0 && self.image_alpha <= 0 {
                        self.state = TileCursorState.Hidden;
                    }
                    break;
            }
            //
            var target;
            switch self.state {
                case TileCursorState.Hidden:
                    target = 0.0;
                    break;
                case TileCursorState.Idle:
                    target = 0.65;
                    self.last_valid_selection = obj_ari.cell_select.clone();
                    self.set_sprite(true);
                    break;
                case TileCursorState.Selected:
                    target = self.target_alpha;
                    break;
                default: impossible("unexpected state: {}", self.state);
            }

            self.image_alpha = approach(self.image_alpha, target, self.fade_speed);
            self.show_tile_cursor = false;

            if self.selected_tiles.count() > 1 || self.is_charging {
                //
                for (var i = 0; i < self.selected_tiles.count(); i++) {
                    var tile_select = self.selected_tiles.get(i);

                    //
                    //
                    if self.image_alpha > 0.1 {
                        shadow_caster_set_alpha(tile_select.shadow, image_alpha * 0.2 + 0.8);
                    } else {
                        shadow_caster_set_alpha(tile_select.shadow, 0.0);
                    }
                }
            }

            //
            //
            var item = ARI.held_item();
            if ARI.end_of_day_status != undefined
                || instance_exists(obj_ari) == false
                || obj_ari.should_show_item_usage_ux() == false
            {
                item = undefined;
            }

            self.extra_casters_to_draw = 0;
            self.depth = get_floor_depth() - 1;

            //
            self.shadow_override = undefined;

            if item == undefined {
                return;
            }

            switch item.prototype.use {
                case ItemUse.PlaceObject:
                    var furniture_draw_data = create_test_placement_furniture_draw_info(
                        obj_ari.cell_select.x,
                        obj_ari.cell_select.y,
                        item.prototype.object,
                        obj_ari.cardinal_placement,
                        self.furniture_renderer
                    );

                    //
                    if self.furniture_renderer.z != 0 && furniture_draw_data.y_off <= -16 {
                        self.bottom_line_renderer.depth = get_floor_depth();
                        self.bottom_line_renderer.valid = furniture_draw_data.is_valid;
                        self.bottom_line_renderer.cursor_data = furniture_draw_data.cursor_data;
                        self.bottom_line_renderer.x = furniture_draw_data.x_off;
                    }

                    if furniture_draw_data.y_off <= -16 || furniture_draw_data.y_off == 0 {
                        //
                        var tile_spr_to_draw = tile_cursor_sprite_bundle().furniture[furniture_draw_data.is_valid];
                        self.extra_casters_to_draw = furniture_draw_data.cursor_data.count();
                        for (var i = 0; i < self.extra_casters_to_draw; i++) {
                            var cursor_data = furniture_draw_data.cursor_data.get(i);
                            var my_caster;

                            if self.extra_shadow_casters.count() <= i {
                                var new_caster = create_shadow_caster(cursor_data.pos_x + furniture_draw_data.x_off, cursor_data.pos_y);
                                self.extra_shadow_casters.push(new_caster);
                                my_caster = new_caster;
                            } else {
                                my_caster = self.extra_shadow_casters.get(i);
                            }

                            my_caster[ShadowCasterField.SpriteIndex] = SHADOW_DICTIONARY.get(tile_spr_to_draw);
                            my_caster[ShadowCasterField.WorldX] = cursor_data.pos_x + furniture_draw_data.x_off;
                            my_caster[ShadowCasterField.WorldY] = cursor_data.pos_y;

                            //
                            my_caster[ShadowCasterField.ImageXScale] = cursor_data.part_x;
                            my_caster[ShadowCasterField.ImageYScale] = cursor_data.part_y;
                        }

                        //
                        if furniture_draw_data.render_arrow != undefined {
                            var render_points = furniture_arrow_offset(
                                furniture_draw_data.render_arrow,
                                furniture_draw_data.top_left_x,
                                furniture_draw_data.top_left_y,
                                furniture_draw_data.bot_right_x,
                                furniture_draw_data.bot_right_y,
                            );

                            var my_caster;
                            if self.extra_shadow_casters.count() <= self.extra_casters_to_draw {
                                var new_caster = create_shadow_caster(render_points[1], render_points[2]);
                                self.extra_shadow_casters.push(new_caster);
                                my_caster = new_caster;
                            } else {
                                my_caster = self.extra_shadow_casters.get(self.extra_casters_to_draw);
                            }

                            my_caster[ShadowCasterField.SpriteIndex] = SHADOW_DICTIONARY.get(render_points[0]);
                            my_caster[ShadowCasterField.ImageIndex] = 0;
                            my_caster[ShadowCasterField.WorldX] = render_points[1];
                            my_caster[ShadowCasterField.WorldY] = render_points[2];

                            //
                            my_caster[ShadowCasterField.ImageXScale] = 0;
                            my_caster[ShadowCasterField.ImageYScale] = 0;

                            //
                            self.extra_casters_to_draw += 1;
                        }
                    }

                    self.top_line_renderer.valid = furniture_draw_data.is_valid;
                    self.top_line_renderer.cursor_data = furniture_draw_data.cursor_data;
                    self.top_line_renderer.splotch_data = furniture_draw_data.splotch_data;
                    self.top_line_renderer.x = furniture_draw_data.x_off;
                    self.top_line_renderer.y = furniture_draw_data.y_off;

                    self.top_line_renderer.render_arrow = furniture_draw_data.render_arrow;
                    self.top_line_renderer.top_left_x = furniture_draw_data.top_left_x;
                    self.top_line_renderer.top_left_y = furniture_draw_data.top_left_y;
                    self.top_line_renderer.bot_right_x = furniture_draw_data.bot_right_x;
                    self.top_line_renderer.bot_right_y = furniture_draw_data.bot_right_y;

                    //
                    if self.furniture_renderer.on_floor {
                        self.furniture_renderer.depth = get_floor_depth() - 1;
                        self.top_line_renderer.depth = get_floor_depth() - 1;
                    } else {
                        self.furniture_renderer.depth = get_instance_depth(self.furniture_renderer.y, self.furniture_renderer.z) - 1;
                        self.top_line_renderer.depth = self.furniture_renderer.depth + 1;
                    }
                    break;
                case ItemUse.Blueprint:
                    if obj_ari.should_show_item_usage_ux() == false {
                        return;
                    }
                    self.last_valid_selection.x = (obj_ari.cell_select.x div 2) * 2;
                    self.last_valid_selection.y = (obj_ari.cell_select.y div 2) * 2;

                    var proto = BLUEPRINT_PROTOTYPES[item.prototype.blueprint.blueprint];
                    var building_proto = NODE_PROTOTYPES[proto.building_on_finish];

                    self.furniture_renderer.x = self.last_valid_selection.x * 8 + building_proto.offset.x;
                    self.furniture_renderer.y = self.last_valid_selection.y * 8 + building_proto.offset.y;
                    self.furniture_renderer.on_floor = false;
                    self.furniture_renderer.image_xscale = 1.0;
                    self.furniture_renderer.image_index = 0;
                    self.furniture_renderer.sprite_index = item.prototype.blueprint.preview_sprite;
                    self.furniture_renderer.z = 0;
                    self.furniture_renderer.depth = get_instance_depth(self.furniture_renderer.y, self.furniture_renderer.z) - 1;
                    self.furniture_renderer.is_success = CURRENT_LOCATION_ID == LocationId.Farm
                        && can_write_blueprint(
                            GRID,
                            self.last_valid_selection.x,
                            self.last_valid_selection.y,
                            proto
                        );
                    break;
                case ItemUse.PlantSapling:
                    if obj_ari.should_show_item_usage_ux() == false {
                        return;
                    }
                    self.last_valid_selection.x = (obj_ari.cell_select.x div 2) * 2;
                    self.last_valid_selection.y = (obj_ari.cell_select.y div 2) * 2;

                    var proto = NODE_PROTOTYPES[item.prototype.sapling];

                    self.furniture_renderer.x = self.last_valid_selection.x * 8 + 24;
                    self.furniture_renderer.y = self.last_valid_selection.y * 8 + 28;
                    self.furniture_renderer.on_floor = false;
                    self.furniture_renderer.image_xscale = 1.0;
                    self.furniture_renderer.image_index = 0;
                    self.furniture_renderer.sprite_index = proto.sprites[0][CALENDAR.season()][0];
                    self.furniture_renderer.z = 0;
                    self.furniture_renderer.depth = get_instance_depth(self.furniture_renderer.y, self.furniture_renderer.z) - 1;
                    self.furniture_renderer.is_success = can_plant_sapling(GRID, self.last_valid_selection.x, self.last_valid_selection.y, item.prototype.sapling);
                    break;
            }
        },
        draw: function() {
            //
            if game_paused() {
                return;
            }

            //
            var item = ARI.held_item();
            if ARI.end_of_day_status != undefined || instance_exists(obj_ari) == false || ARI.fire_breath_time > 0
            {
                item = undefined;
            }

            if item != undefined {
                switch item.prototype.use {
                    case ItemUse.PlaceObject:
                        if obj_ari.should_show_item_usage_ux() == false {
                            return;
                        }
                        //
                        if self.top_line_renderer.valid == false && self.top_line_renderer.splotch_data != undefined {
                            var t = irandom(I32_MAX);
                            for (var i = 0; i < self.top_line_renderer.splotch_data.count(); i++) {
                                var cursor = self.top_line_renderer.splotch_data.get(i);
                                if NODE_PROTOTYPES[item.prototype.object].rug == false {
                                    self.show_tree_splotches(
                                        GRID.try_node_index_for_room_position(cursor.x, cursor.y),
                                        t
                                    );
                                }
                                self.show_no_furniture_splotches(cursor.x, cursor.y);
                            }
                        }

                        //
                        if object_id_to_object_category(item.prototype.object) == ObjectCategory.Furniture
                            && NODE_PROTOTYPES[item.prototype.object].sprinkler != undefined
                        {
                            var old_x = self.last_valid_selection.x;
                            var old_y = self.last_valid_selection.y;
                            self.last_valid_selection.x = obj_ari.cell_select.x - (NODE_PROTOTYPES[item.prototype.object].sprinkler * 2 + 1);
                            self.last_valid_selection.y = obj_ari.cell_select.y - (NODE_PROTOTYPES[item.prototype.object].sprinkler * 2 + 1);
                            self.draw_parts_of_tile_indicator(NODE_PROTOTYPES[item.prototype.object].sprinkler * 4 + 3, NODE_PROTOTYPES[item.prototype.object].sprinkler * 4 + 3, TILE_CURSORS.winter.furniture[true], 0.65);
                            self.last_valid_selection.x = old_x;
                            self.last_valid_selection.y = old_y;
                        }

                        return;
                    case ItemUse.Blueprint:
                        if obj_ari.should_show_item_usage_ux() == false {
                            return;
                        }
                        var proto = BLUEPRINT_PROTOTYPES[item.prototype.blueprint.blueprint];

                        //
                        var valid = CURRENT_LOCATION_ID == LocationId.Farm && can_write_blueprint(GRID, self.last_valid_selection.x, self.last_valid_selection.y, proto);

                        var spr = tile_cursor_sprite_bundle().furniture[valid];
                        self.shadow_override = {
                            size_x: proto.size.x + 1,
                            size_y: proto.size.y + 1,
                            off_x: -4,
                            off_y: -4,
                            sprite: SHADOW_DICTIONARY.get(spr)
                        };
                        self.draw_parts_of_tile_indicator(proto.size.x + 1, proto.size.y + 1, spr, 1.0);

                        if valid == false {
                            var t = irandom(I32_MAX);
                            for (var xx = 0; xx < proto.size.x / 2; xx++) {
                                for (var yy = 0; yy < proto.size.y / 2; yy++) {
                                    self.show_tree_splotches(
                                        GRID.try_node_index_for_cell(
                                            self.last_valid_selection.x + xx * 2,
                                            self.last_valid_selection.y + yy * 2,
                                        ),
                                        t
                                    );
                                    self.show_no_furniture_splotches(
                                        self.last_valid_selection.x + xx * 2,
                                        self.last_valid_selection.y + yy * 2,
                                    );
                                }
                            }
                        }
                        return;
                    case ItemUse.PlantSapling:
                        if obj_ari.should_show_item_usage_ux() == false {
                            return;
                        }
                        var valid = can_plant_sapling(GRID, self.last_valid_selection.x, self.last_valid_selection.y, item.prototype.sapling);

                        var spr = tile_cursor_sprite_bundle().furniture[valid];
                        self.shadow_override = {
                            size_x: 6,
                            size_y: 6,
                            off_x: 0,
                            off_y: 0,
                            sprite: SHADOW_DICTIONARY.get(spr),
                        };
                        self.draw_parts_of_tile_indicator(6, 6, spr, 1.0, 0, 0);

                        if valid == false {
                            var t = irandom(I32_MAX);
                            for (var xx = 0; xx < 3; xx++) {
                                for (var yy = 0; yy < 3; yy++) {
                                    self.show_tree_splotches(
                                        GRID.try_node_index_for_cell(
                                            self.last_valid_selection.x + xx * 2,
                                            self.last_valid_selection.y + yy * 2,
                                        ),
                                        t
                                    );
                                    self.show_no_furniture_splotches(
                                        self.last_valid_selection.x + xx * 2,
                                        self.last_valid_selection.y + yy * 2,
                                    );
                                }
                            }
                        }
                        return;
                    case ItemUse.PlaceTile:
                        if obj_ari.should_show_item_usage_ux() == false {
                            return;
                        }
                        //
                        self.last_valid_selection.x = (obj_ari.cell_select.x div 2) * 2;
                        self.last_valid_selection.y = (obj_ari.cell_select.y div 2) * 2;

                        var valid = GRID.item_effects_node_at_cell(self.last_valid_selection.x, self.last_valid_selection.y, item.prototype);
                        var spr = tile_cursor_sprite_bundle().furniture[valid];
                        self.shadow_override = {
                            size_x: 3,
                            size_y: 3,
                            off_x: -4,
                            off_y: -4,
                            sprite: SHADOW_DICTIONARY.get(spr)
                        };
                        self.draw_parts_of_tile_indicator(3, 3, spr, 1.0);

                        if valid {
                            var tset = get_seasonal_tileset(tile_main_exteriors_spring, CALENDAR.season());
                            draw_tile(tset, item.prototype.tile_placement.index, 0, self.last_valid_selection.x * 8, self.last_valid_selection.y * 8);
                        }
                        return;
                }
            }

            //
            if self.selected_tiles.count() <= 1 && self.is_charging == false {
                if self.simple_draw {
                    draw_sprite_ext(sprite_index, 0, self.last_valid_selection.x * 8, self.last_valid_selection.y * 8, 1, 1, 0, image_blend, image_alpha);
                } else {
                    self.draw_parts_of_tile_indicator(self.complex_size_x, self.complex_size_y, self.sprite_index, self.image_alpha);
                }
                return;
            }

            //
            if item == undefined {
                return;
            }

            //
            for (var i = 0; i < self.selected_tiles.count(); i++) {
                var tile_select = self.selected_tiles.get(i);

                var col = c_white;

                if tile_select.valid {
                    gpu_set_blendmode_ext(bm_src_alpha, bm_one);
                    col = make_color_rgb(2, 43, 0);
                } else {
                    //
                    gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);
                    col = make_color_rgb(253, 33, 74);
                }

                draw_sprite_ext(spr_pixel, 0, tile_select.pos.x * 8, tile_select.pos.y * 8, 16, 16, 0, col, image_alpha * 0.6);
            }
            gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);

            //
            for (var i = 0; i < self.selected_tiles.count(); i++) {
                var tile_select = self.selected_tiles.get(i);

                if tile_select.valid == false {
                    draw_sprite_ext(tile_cursor_sprite_bundle().tool[false], 0, tile_select.pos.x * 8, tile_select.pos.y * 8, 1, 1, 0, image_blend, image_alpha);
                }
            }

            //
            for (var i = 0; i < self.selected_tiles.count(); i++) {
                var tile_select = self.selected_tiles.get(i);

                if tile_select.valid {
                    draw_sprite_ext(tile_cursor_sprite_bundle().tool[true], 0, tile_select.pos.x * 8, tile_select.pos.y * 8, 1, 1, 0, image_blend, image_alpha);
                }
            }
        },
        cleanup: function() {

        },
    }
);
