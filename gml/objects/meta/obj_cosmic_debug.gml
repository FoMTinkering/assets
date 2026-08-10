var cosmic_debug_obj = object_create(
    "obj_cosmic_debug",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            assert(DEBUG_TOOLS);
            depth = -14000;
            draw_interact_boxes = false;
            draw_transparency_detectors = false;
            lighting_debug = false;
            light_state = 0;
            light_value = 0;

            vivid = [80, 70, 255, 25];
            multiply = [37, 0, 114, 114];
            levels = [0, 0.91, 240 / 255.0];
            lights = [1.0, 0.9, 0.75, 0.55];

            show_collisions = false;
            show_static_collisions = false;
            show_objects = false;
            show_rugs = false;
            show_activity_positions = false;
            names = false;
            describe = false;
            show_terrain = false;
            show_watered = false;
            show_room_name = false;
            show_lava = false;
            show_objects_sub_layer = false;
            obj_transform = false;
            obj_depth_transform = false;
            show_footsteps = false;
            show_cbs = false;
            show_building_points = false;

            show_food_markers = false;

            show_pathfind = false;
            show_pathfind_collision = false;
            show_pathfind_paths = false;

            tile_selection = false;
            new_tile_indicator = false;

            show_camera_range = false;
            show_cull_range = false;
            show_object_cull_ranges = false;

            show_shadow_chunks = false;
            show_activated_shadow_chunks = false;

            draw_jump_target = false;

            hitbox = false;
            hurtbox = false;
            aggro_box = false;
            enemy_state = false;
            enemy_patience = false;
            enemy_transform = false;
            enemy_target = false;
            enemy_collision = false;
            show_grow_back_sections = false;

            transforms = false;
            trigger_crash = undefined;

            bird_landing_positions = false;

            bug_net = false;

            bomb_radius = false;

            function action_per_node_in_view(f) {
                for (var yy = CAMERA.top() div 8; yy < CAMERA.bottom() div 8; yy++) {
                    for (var xx = CAMERA.left() div 8; xx < CAMERA.right() div 8; xx++) {
                        var ni = GRID.try_node_index_for_cell(xx, yy);
                        if ni == undefined || GRID.node_object_id[ni] == undefined {
                            continue;
                        }

                        f(GRID.node_parent[ni], xx, yy);
                    }
                }
            }

            function draw_box(x1, y1, x2, y2, color, alpha) {
                //
                draw_sprite_ext(spr_pixel, 0, x1, y1, x2 - x1, 1, 0, color, alpha);
                draw_sprite_ext(spr_pixel, 0, x1, y2, x2 - x1, 1, 0, color, alpha);

                //
                draw_sprite_ext(spr_pixel, 0, x1, y1, 1, y2 - y1, 0, color, alpha);
                draw_sprite_ext(spr_pixel, 0, x2, y1, 1, y2 - y1, 0, color, alpha);
            }

            function draw_rectangle_color(x1, y1, x2, y2, c, alpha) {
                draw_sprite_stretched_ext(spr_pixel, 0, x1, y1, x2 - x1, x2 - x1, c, alpha ?? 1.0);
            }
        },
        draw: function() {
            gpu_reset_extra();
            if draw_interact_boxes {
                var npc_nudge_amt = fiddle_get("interaction/npcs/nudge_distance");

                for (var i = 0; i < INTERACTABLES.count(); i++) {
                    var interactable = INTERACTABLES.get(i);
                    if interactable == undefined || instance_exists(interactable) == false {
                        continue;
                    }

                    with interactable {
                        if self.has_potential_interactions() == false {
                            continue;
                        }
                        var c = c_red;
                        switch self.interactable_mode {
                            case InteractableMode.Circle:
                                var xx = x;
                                var yy = y;

                                if self.offset_with_cardinal {
                                    switch self.animator.cardinality {
                                        case Cardinal.East:
                                            xx += npc_nudge_amt;
                                            break;
                                        case Cardinal.West:
                                            xx -= npc_nudge_amt;
                                            break;
                                        case Cardinal.South:
                                            yy += npc_nudge_amt;
                                            break;
                                        case Cardinal.North:
                                            yy -= npc_nudge_amt;
                                            break;
                                    }
                                }
                                draw_circle(xx - self.circle_size, yy - self.circle_size, xx + self.circle_size, yy + self.circle_size, c, 0.5, false);
                                break;
                            case InteractableMode.Bbox:
                                if self.override_mask != undefined {
                                    self.temp_stash = self.mask_index;
                                    self.mask_index = self.override_mask;
                                }

                                other.draw_rectangle_color(bbox_left, bbox_top, bbox_right, bbox_bottom, c, 0.2);

                                if self.override_mask != undefined {
                                    self.mask_index = self.temp_stash;
                                    self.temp_stash = undefined;
                                }
                                break;
                            case InteractableMode.Box:
                                var xx = self.interaction_center.x;
                                var yy = self.interaction_center.y;

                                other.draw_rectangle_color(
                                    xx - self.interaction_half_size.x,
                                    yy - self.interaction_half_size.y,
                                    xx + self.interaction_half_size.x,
                                    yy + self.interaction_half_size.y,
                                    c,
                                    0.2
                                );
                                break;
                        }
                    }
                }

                var ari_x = obj_ari.x;
                var ari_y = obj_ari.y;

                var f = fiddle_get("interaction");
                //
                switch obj_ari.cardinal {
                    case Cardinal.East:
                        ari_x += f.nudge_distance;
                        break;
                    case Cardinal.West:
                        ari_x -= f.nudge_distance;
                        break;
                    case Cardinal.South:
                        ari_y += f.nudge_distance;
                        break;
                    case Cardinal.North:
                        ari_y -= f.nudge_distance;
                        break;
                    default: impossible("unexpected cardinal {}", obj_ari.cardinal);
                }

                draw_rectangle_color(
                    ari_x - f.max_radius,
                    ari_y - f.max_radius,
                    ari_x + f.max_radius,
                    ari_y + f.max_radius,
                    c_white,
                    0.2
                );

                draw_circle(ari_x - f.max_radius, ari_y - f.max_radius, ari_x + f.max_radius, ari_y + f.max_radius, c_yellow, 0.5);

                with par_interactable {
                    var c;
                    if self.has_potential_interactions() {
                        c = c_red;
                    } else {
                        c = c_black;
                    }

                    switch self.interactable_mode {
                        case InteractableMode.Circle:
                            var xx = x;
                            var yy = y;

                            if self.offset_with_cardinal {
                                switch self.animator.cardinality {
                                    case Cardinal.East:
                                        xx += npc_nudge_amt;
                                        break;
                                    case Cardinal.West:
                                        xx -= npc_nudge_amt;
                                        break;
                                    case Cardinal.South:
                                        yy += npc_nudge_amt;
                                        break;
                                    case Cardinal.North:
                                        yy -= npc_nudge_amt;
                                        break;
                                }
                            }
                            //
                            break;
                        case InteractableMode.Bbox:
                            if self.override_mask != undefined {
                                self.temp_stash = self.mask_index;
                                self.mask_index = self.override_mask;
                            }

                            other.draw_rectangle_color(bbox_left, bbox_top, bbox_right, bbox_bottom, c, 1.0);

                            if self.override_mask != undefined {
                                self.mask_index = self.temp_stash;
                                self.temp_stash = undefined;
                            }
                            break;
                        case InteractableMode.Box:
                            var xx = self.interaction_center.x;
                            var yy = self.interaction_center.y;

                            other.draw_rectangle_color(
                                xx - self.interaction_half_size.x,
                                yy - self.interaction_half_size.y,
                                xx + self.interaction_half_size.x,
                                yy + self.interaction_half_size.y,
                                c,
                                1.0
                            );
                            break;
                    }
                }

                draw_circle(ari_x - f.max_radius, ari_y - f.max_radius, ari_x + f.max_radius, ari_y + f.max_radius, c_yellow, 0.5, true);
            }

            if draw_transparency_detectors {
                var c = c_red;

                with obj_transparency_detector {
                    if overlap_instance_any(self.x, self.y, obj_ari) {
                        c = c_yellow;
                    } else {
                        c = c_red;
                    }

                    other.draw_rectangle_color(bbox_left, bbox_top, bbox_right, bbox_bottom, c, 1.0);
                }

                draw_rectangle_color(obj_ari.bbox_left, obj_ari.bbox_top, obj_ari.bbox_right, obj_ari.bbox_bottom, c, 0.5);
            }

            if self.bug_net && instance_exists(obj_ari) {
                var item = ARI.held_item();
                if item != undefined && item.prototype.tool_type == ToolType.Net {
                    var as_angles = cardinal_to_angle(obj_ari.cardinal);
                    var r = item.prototype.catch_size;
                    var cx = obj_ari.x + lengthdir_x(20, as_angles) - 1
                    var cy = obj_ari.y + lengthdir_y(20 * .7, as_angles) - 6;
                    draw_set_alpha(0.25);
                    draw_rectangle_color(cx - r, cy - r, cx + r, cy + r, c_red, c_red, c_red, c_red, false);
                    draw_set_alpha(1);
                }
            }

            if draw_jump_target && instance_exists(obj_ari) {
                var distance;
                if obj_ari.is_swimming() {
                    distance = HUMAN_WATER_JUMP;
                } else {
                    distance = ARI.run_toggle ? HUMAN_RUN_JUMP_DISTANCE : HUMAN_WALK_JUMP_DISTANCE
                };

                var helper = Vec2(
                    INPUT.check_value(InputId.Right) - INPUT.check_value(InputId.Left),
                    INPUT.check_value(InputId.Down) - INPUT.check_value(InputId.Up),
                );
                helper.normalized();
                helper.set_scale(distance);

                draw_sprite_ext(spr_pixel, 0, obj_ari.x + helper.x, obj_ari.y + helper.y, 1, 1, 0,c_fuchsia, 1.0);
            }

            if tile_selection {
                var base_xx = (obj_ari.x div 16) * 16;
                var base_yy = (obj_ari.y div 16) * 16;

                for (var i = 0; i < 2; i++) {
                    draw_set_alpha(i == 0 ? 0.2 : 1.0);

                    var lower_range_x = 0;
                    var red_x = obj_ari.x % 16;
                    var red_y = obj_ari.y % 16;

                    for (var xx = 0; xx < 3; xx++) {
                        var x_multiplier = xx == 1 ? 2 : 1;
                        var size_x = 4 * x_multiplier;
                        var top_range_x = lower_range_x + size_x;

                        var in_this_x = (red_x >= lower_range_x) && (red_x < top_range_x);

                        var lower_range_y = 0;

                        for (var yy = 0; yy < 3; yy++) {
                            var y_multiplier = yy == 1 ? 2 : 1;
                            var size_y = 4 * y_multiplier;
                            var top_range_y = lower_range_y + size_y;

                            var in_this_y = (red_y >= lower_range_y) && (red_y < top_range_y);

                            var c = in_this_x && in_this_y ? c_green : c_white;
                            draw_rectangle_color(
                                base_xx + lower_range_x,
                                base_yy + lower_range_y,
                                base_xx + top_range_x,
                                base_yy + top_range_y,
                                c,
                                c,
                                c,
                                c,
                                i == 1
                            );

                            lower_range_y += size_y;
                        }

                        lower_range_x += size_x;
                    }
                }

                draw_set_alpha(1.0);
                draw_circle_color(
                    obj_ari.x,
                    obj_ari.y,
                    1,
                    c_yellow,
                    c_yellow,
                    false
                );
            }

            //
            if show_collisions {
                for (var yy = CAMERA.top() div 8; yy < CAMERA.bottom() div 8; yy++) {
                    if yy < 0 || yy >= GRID.dims.y {
                        continue;
                    }
                    for (var xx = CAMERA.left() div 8; xx < CAMERA.right() div 8; xx++) {
                        if xx < 0 || xx >= GRID.dims.x || yy < 0 || yy >= GRID.dims.y {
                            continue;
                        }
                        var ni = GRID.node_index_for_cell(xx, yy);
                        var c = undefined;

                        if GRID.node_collideable[ni] {
                            if GRID.node_can_jump_over[ni] {
                                c = c_orange;
                            } else {
                                c = c_red;
                            }
                        }

                        if c != undefined {
                            draw_sprite_ext(spr_square, 0, xx * 8, yy * 8, 8, 8, 0, c, 0.5);
                        }
                    }
                }

                draw_sprite_ext(spr_square, 0, (obj_ari.x div 8) * 8, (obj_ari.y div 8) * 8, 8, 8, 0, c_white, 0.5);
            }

            if show_static_collisions {
                for (var yy = CAMERA.top() div 8; yy < CAMERA.bottom() div 8; yy++) {
                    if yy < 0 || yy >= GRID.dims.y {
                        continue;
                    }
                    for (var xx = CAMERA.left() div 8; xx < CAMERA.right() div 8; xx++) {
                        if xx < 0 || xx >= GRID.dims.x || yy < 0 || yy >= GRID.dims.y {
                            continue;
                        }
                        var ni = GRID.try_node_index_for_cell(xx, yy);
                        var c = undefined;
                        if ni == undefined {
                            continue;
                        }

                        switch GRID.node_is_room_editor_collision[ni] {
                            case RoomEditorCollision.None:
                                break;
                            case RoomEditorCollision.Active:
                                c = "A";
                                break;
                            case RoomEditorCollision.Inactive:
                                c = "-";
                                break;
                            default:
                                c = "?";
                                break;
                        }

                        if c != undefined {
                            draw_set_font(ANCHOR.get_text_font());
                            draw_set_halign(HorizontalOffset.Middle);
                            draw_set_valign(VerticalOffset.Middle);
                            draw_text(xx * 8 + 4, yy * 8 + 4, c);
                        }
                    }
                }

                draw_sprite_ext(spr_square, 0, (obj_ari.x div 8) * 8, (obj_ari.y div 8) * 8, 8, 8, 0, c_white, 0.5);
            }

            if show_objects {
                action_per_node_in_view(function(_, xx, yy) {
                    draw_sprite_ext(spr_square, 0, xx * 8, yy * 8, 8, 8, 0, c_fuchsia, 0.5);
                })
            }


            if show_rugs {
                for (var yy = CAMERA.top() div 8; yy < CAMERA.bottom() div 8; yy++) {
                    for (var xx = CAMERA.left() div 8; xx < CAMERA.right() div 8; xx++) {
                        var ni = GRID.try_node_index_for_cell(xx, yy);
                        if ni == undefined || GRID.node_rug_id[ni] == undefined {
                            continue;
                        }

                        draw_sprite_ext(spr_square, 0, xx * 8, yy * 8, 8, 8, 0, c_red, 0.5);
                    }
                }
            }

            if show_objects_sub_layer {
                var tag = irandom(I32_MAX);

                for (var yy = CAMERA.top() div 8; yy < CAMERA.bottom() div 8; yy++) {
                    if yy < 0 || yy >= GRID.dims.y {
                        continue;
                }
                    for (var xx = CAMERA.left() div 8; xx < CAMERA.right() div 8; xx++) {
                        if xx < 0 || xx >= GRID.dims.x || yy < 0 || yy >= GRID.dims.y {
                            continue;
                        }
                        var ni = GRID.node_index_for_cell(xx, yy);

                        if object_id_to_object_category(GRID.node_object_id[ni]) == ObjectCategory.Furniture
                            && GRID.node_parent[ni].child_grid != undefined
                            && GRID.node_parent[ni].last_update != tag
                        {
                            for (var xxx = 0; xxx < GRID.node_parent[ni].child_grid.dims.x; xxx++) {
                                for (var yyy = 0; yyy < GRID.node_parent[ni].child_grid.dims.y; yyy++) {
                                    var inner_cell = GRID.node_parent[ni].child_grid.node_index_for_cell(xxx, yyy);
                                    if GRID.node_parent[ni].child_grid.node_flags[inner_cell] == 0 {
                                        continue;
                                    }

                                    var c = c_fuchsia;
                                    if GRID.node_parent[ni].child_grid.node_object_id[inner_cell] == undefined {
                                        c = c_gray;
                                    }

                                    var offset = GRID.node_parent[ni].prototype.cardinal_data[GRID.node_parent[ni].cardinal_index].child_grid_offset;
                                    draw_sprite_ext(spr_square, 0, (xx + xxx) * 8 + offset.x, (yy + yyy) * 8 + offset.y, 8, 8, 0, c, 0.5);
                                }
                            }

                            GRID.node_parent[ni].last_update = tag;
                        }
                    }
                }
            }

            //
            if show_terrain {
                for (var yy = CAMERA.top() div 8; yy < CAMERA.bottom() div 8; yy++) {
                    if yy < 0 || yy >= GRID.dims.y {
                        continue;
                    }

                    for (var xx = CAMERA.left() div 8; xx < CAMERA.right() div 8; xx++) {
                        if xx < 0 || xx >= GRID.dims.x {
                            continue;
                        }

                        var ni = GRID.node_index_for_cell(xx, yy);
                        var c = undefined;

                        switch GRID.node_terrain_kind[ni] {
                            case TerrainKind.Water:
                                c = c_blue;
                                break;

                            case TerrainKind.Lava:
                                c = c_orange;
                                break;

                            case TerrainKind.Ground:
                                switch GRID.node_terrain_ground_kind[ni] {
                                    case GroundKind.Grass:
                                        c = c_green;
                                        break;
                                    case GroundKind.Dirt:
                                        c = c_red;
                                        break;

                                    case GroundKind.Soil:
                                        c = c_fuchsia;
                                        break;

                                    case GroundKind.RiverBank:
                                        c = c_yellow;
                                }
                                break;
                        }

                        if c != undefined {
                            draw_sprite_ext(spr_square, 0, xx * 8, yy * 8, 8, 8, 0, c, 0.5);
                        }
                    }

                    draw_sprite_ext(spr_square, 0, (obj_ari.x div 8) * 8, (obj_ari.y div 8) * 8, 8, 8, 0, c_white, 0.5)
                }
            }

            //
            if show_footsteps {
                for (var yy = CAMERA.top() div 8; yy < CAMERA.bottom() div 8; yy++) {
                    if yy % 2 != 0 {
                        continue;
                    }

                    for (var xx = CAMERA.left() div 8; xx < CAMERA.right() div 8; xx++) {
                        if xx % 2 != 0 {
                            continue;
                        }

                        var ni = GRID.try_node_index_for_cell(xx, yy);
                        if ni == undefined {
                            continue;
                        }

                        if GRID.node_footstep_kind[ni] == 0 {
                            continue;
                        }

                        draw_tile(tile_footsteps, GRID.node_footstep_kind[ni], 0, xx * 8, yy * 8);
                    }
                }
            }

            //
            if show_lava {
                for (var yy = CAMERA.top() div 8; yy < CAMERA.bottom() div 8; yy++) {
                    if yy < 0 || yy >= GRID.dims.y {
                        continue;
                    }

                    for (var xx = CAMERA.left() div 8; xx < CAMERA.right() div 8; xx++) {
                        if xx < 0 || xx >= GRID.dims.x {
                            continue;
                        }

                        var ni = GRID.node_index_for_cell(xx, yy);
                        var c = undefined;

                        switch GRID.node_terrain_kind[ni] {
                            case TerrainKind.Water:
                                break;

                            case TerrainKind.Lava:
                                c = c_orange;
                                break;

                            case TerrainKind.Ground:
                                break;
                        }

                        if c != undefined {
                            draw_sprite_ext(spr_square, 0, xx * 8, yy * 8, 8, 8, 0, c, 0.5);
                        }
                    }

                    draw_sprite_ext(spr_square, 0, (obj_ari.x div 8) * 8, (obj_ari.y div 8) * 8, 8, 8, 0, c_white, 0.5)
                }
            }

            //
            if show_watered {
                for (var yy = CAMERA.top() div 8; yy < CAMERA.bottom() div 8; yy++) {
                    if yy < 0 || yy >= GRID.dims.y {
                        continue;
                    }
                    for (var xx = CAMERA.left() div 8; xx < CAMERA.right() div 8; xx++) {
                        if xx < 0 || xx >= GRID.dims.x || yy < 0 || yy >= GRID.dims.y {
                            continue;
                        }

                        var ni = GRID.node_index_for_cell(xx, yy);
                        var c = undefined;

                        if GRID.node_terrain_kind[ni] == TerrainKind.Ground && GRID.node_terrain_is_watered[ni] {
                            c = c_blue;
                        }

                        if c != undefined {
                            draw_sprite_ext(spr_square, 0, xx * 8, yy * 8, 8, 8, 0, c, 0.5);
                        }
                    }
                }
            }

            if show_pathfind {
                for (var yy = CAMERA.top() div 8; yy < CAMERA.bottom() div 8; yy++) {
                    if yy < 0 || yy >= GRID.dims.y {
                        continue;
                    }

                    for (var xx = CAMERA.left() div 8; xx < CAMERA.right() div 8; xx++) {
                        if xx < 0 || xx >= GRID.dims.x {
                            continue;
                        }

                        var c = undefined;
                        var o = 0.5;

                        var cost = PATHFINDING.get_local_position_cost(xx, yy);

                        switch cost {
                            case 1:
                                c = c_fuchsia;
                                break;
                            case 3:
                                c = c_yellow;
                                break;
                            case 5:
                                c = c_white;
                                o = 0;
                                break;
                            default:
                                c = c_teal;
                                break;
                        }

                        if c != undefined {
                            draw_sprite_ext(spr_square, 0, xx * 8, yy * 8, 8, 8, 0, c, o);
                        }
                    }
                }
            }

            if show_pathfind_collision {
                for (var yy = CAMERA.top() div 8; yy < CAMERA.bottom() div 8; yy++) {
                    if yy < 0 || yy >= GRID.dims.y {
                        continue;
                    }

                    for (var xx = CAMERA.left() div 8; xx < CAMERA.right() div 8; xx++) {
                        if xx < 0 || xx >= GRID.dims.x {
                            continue;
                        }

                        if PATHFINDING.get_local_position_is_taken(xx, yy) {
                            draw_sprite_ext(spr_square, 0, xx * 8, yy * 8, 8, 8, 0, c_red, 0.5);
                        }
                    }
                }
            }

            if show_pathfind_paths {
                with (par_NPC) {
                    if self.fsm.current_state_id() == NpcState.Pathfinding {
                        var todo_list = self.pathfinding_agent.todo_list();

                        for (var i = 0, c = todo_list.count(); i < c; i++) {
                            var target = todo_list.get(i);

                            draw_sprite_ext(spr_square, 0, target.x, target.y, 8, 8, 0, c_white, 0.5);
                        }

                        var blocked_squares = self.pathfinding_agent.squares_to_check();

                        for (var i = 0, c = array_length(blocked_squares); i < c; i++) {
                            var square = blocked_squares[i];
                            if square == undefined {
                                break;
                            }
                            draw_sprite_ext(spr_square, 0, square.x, square.y, 8, 8, 0, c_yellow, 0.5);
                        }
                    }
                }

                with obj_pet {
                    if self.fsm.current_state_id() == PetState.Pathfinding {
                        var todo_list = self.pathfinding_agent.todo_list();

                        for (var i = 0, c = todo_list.count(); i < c; i++) {
                            var target = todo_list.get(i);

                            draw_sprite_ext(spr_square, 0, target.x, target.y, 8, 8, 0, c_white, 0.5);
                        }

                        var blocked_squares = self.pathfinding_agent.squares_to_check();

                        for (var i = 0, c = array_length(blocked_squares); i < c; i++) {
                            var square = blocked_squares[i];
                            if square == undefined {
                                break;
                            }
                            draw_sprite_ext(spr_square, 0, square.x, square.y, 8, 8, 0, c_yellow, 0.5);
                        }
                    }
                }

                with obj_monster_rock_stack {
                    if self.fsm.current_state_id() == RockStackState.Walk && self.fsm.current_state().path != undefined {
                        var points = self.fsm.current_state().path.output_list;

                        for (var i = 0, c = points.count(); i < c; i++) {
                            var target = points.get(i);
                            var col = i == c - 1 ? c_yellow : c_white;
                            draw_sprite_ext(spr_square, 0, target.x, target.y, 8, 8, 0, col, 0.5);
                        }
                    }
                }

                with obj_monster_statue {
                    if self.fsm.current_state_id() == StatueState.Chase && self.fsm.current_state().path != undefined {
                        var points = self.fsm.current_state().path.output_list;

                        for (var i = 0, c = points.count(); i < c; i++) {
                            var target = points.get(i);
                            var col = i == c - 1 ? c_yellow : c_white;
                            draw_sprite_ext(spr_square, 0, target.x, target.y, 8, 8, 0, col, 0.5);
                        }
                    }
                }

                with obj_player_animal {
                    if self.fsm.current_state_id() == AnimalState.Pathfinding {
                        var todo_list = self.pathfinding_agent.todo_list();

                        for (var i = 0, c = todo_list.count(); i < c; i++) {
                            var target = todo_list.get(i);

                            draw_sprite_ext(spr_square, 0, target.x, target.y, 8, 8, 0, c_white, 0.5);
                        }

                        var blocked_squares = self.pathfinding_agent.squares_to_check();

                        for (var i = 0, c = array_length(blocked_squares); i < c; i++) {
                            var square = blocked_squares[i];
                            if square == undefined {
                                break;
                            }
                            draw_sprite_ext(spr_square, 0, square.x, square.y, 8, 8, 0, c_yellow, 0.5);
                        }
                    }
                }

                if obj_ari.fsm.current_state_id() == PlayerState.Pathfind {
                    var todo_list = obj_ari.fsm.current_state().pathfinding_agent.todo_list();

                    for (var i = 0, c = todo_list.count(); i < c; i++) {
                        var target = todo_list.get(i);

                        draw_sprite_ext(spr_square, 0, target.x, target.y, 8, 8, 0, c_white, 0.5);
                    }

                    var blocked_squares = obj_ari.fsm.current_state().pathfinding_agent.squares_to_check();

                    for (var i = 0, c = array_length(blocked_squares); i < c; i++) {
                        var square = blocked_squares[i];
                        if square == undefined {
                            break;
                        }
                        draw_sprite_ext(spr_square, 0, square.x, square.y, 8, 8, 0, c_yellow, 0.5);
                    }
                }

                //
                PATHFINDING.reservations.for_each(function(square) {
                    square = real(square);
                    var xx = square mod GRID.dims.x;
                    var yy = square div GRID.dims.x;

                    draw_sprite_ext(spr_square, 0, xx * 8, yy * 8, 8, 8, 0, c_red, 0.5);
                });
            }

            if names {
                var ni = GRID.try_node_index_for_cell(mouse_x() div 8, mouse_y() div 8);
                draw_set_font(ANCHOR.get_text_font());
                if ni != undefined && GRID.node_object_id[ni] != undefined {
                    draw_text(mouse_x(), mouse_y(), object_id_to_string(GRID.node_object_id[ni]));
                    trace("Hoving over: `{ObjectId}`", GRID.node_object_id[ni]);
                }
            }

            if describe {
                var ni = GRID.try_node_index_for_cell(mouse_x() div 8, mouse_y() div 8);
                if ni == undefined {
                    trace("Hover ({}x{} / {}x{}): OUT OF GRID", mouse_x() div 8, mouse_y() div 8, mouse_x(), mouse_y());
                } else {
                    switch object_id_to_object_category(GRID.node_object_id[ni]) {
                        case ObjectCategory.Crop:
                            trace("Hover ({}x{} / {}x{}): {ObjectId}, Collision: {bool}, F: {}", mouse_x() div 8, mouse_y() div 8, mouse_x(), mouse_y(), GRID.node_object_id[ni], GRID.node_collideable[ni], GRID.node_flags[ni]);
                            var obj = GRID.node_parent[ni];

                            trace("..ctx = {}, stage = {}, override_sprite_active = {}", obj.ctx, obj.stage, obj.override_sprite != undefined);
                            trace("..managed = {}, forageable = {}, no_harvest = {}, spawn_grown = {}", has_flag(obj.ctx, CropFlag.MANAGED), has_flag(obj.ctx, CropFlag.FORAGEABLE), has_flag(obj.ctx, CropFlag.NO_HARVEST), has_flag(obj.ctx, CropFlag.SPAWN_GROWN));
                            break;
                        case ObjectCategory.Bush:
                            trace("Hover ({}x{} / {}x{}): {ObjectId}, Collision: {bool}, F: {}", mouse_x() div 8, mouse_y() div 8, mouse_x(), mouse_y(), GRID.node_object_id[ni], GRID.node_collideable[ni], GRID.node_flags[ni]);
                            trace("..day_count = {}, can_interact = {}", GRID.node_parent[ni].day_count, can_interact(GRID.node_parent[ni]));
                            break;
                        default:
                            trace("Hover ({}x{} / {}x{}): Collision: {bool}, F: {}", mouse_x() div 8, mouse_y() div 8, mouse_x(), mouse_y(), GRID.node_collideable[ni], GRID.node_flags[ni]);
                            break;
                    }
                }
            }

            if obj_transform {
                with obj_node_renderer {
                    draw_sprite_ext(spr_pixel, 0, self.x, self.y, 2, 2, 0, c_fuchsia, 1.0)
                }

                with obj_ari {
                    draw_sprite_ext(spr_pixel, 0, self.x, self.y, 2, 2, 0, c_fuchsia, 1.0)
                }
            }

            if obj_depth_transform {
                with obj_node_renderer {
                    draw_sprite_ext(spr_pixel, 0, self.x, self.y - (self.depth + self.y), 1, 1, 0, c_aqua, 1.0)
                    if id[$ "node"] != undefined && self.node[$ "child_grid"] != undefined {
                        draw_sprite_ext(spr_pixel, 0, self.node.top_left_x * 8, (self.node.top_left_y + self.node.write_size_y) * 8, 1, 1, 0, c_black, 1.0)
                    }
                }

                with obj_ari {
                    draw_sprite_ext(spr_pixel, 0, self.x, self.y - (self.depth + self.y), 1, 1, 0, c_aqua, 1.0)
                }
            }

            if show_room_name {
                draw_set_font(ANCHOR.get_text_font());
                draw_text(CAMERA.internal_cam_pos.x + 200, CAMERA.internal_cam_pos.y + 40, asset_to_string(room()));
            }

            if self.show_object_cull_ranges {
                var all_instances = instance_get_all();
                for (var j = 0; j < array_length(all_instances); j++) {
                    with all_instances[j] {
                        other.draw_box(bbox_left, bbox_top, bbox_right, bbox_bottom, c_yellow, 0.25);
                    }
                }
            }

            if self.show_cull_range {
                var region = CAMERA.get_cull_region();
                self.draw_box(region[0], region[1], region[0] + region[2], region[1] + region[3], c_fuchsia, 1.0);
            }

            if self.show_camera_range {
                self.draw_box(
                    CAMERA.cam_pos.x + CAMERA.cull_offset_x,
                    CAMERA.cam_pos.y + CAMERA.cull_offset_y,
                    CAMERA.cam_pos.x + CAMERA.cull_offset_x + CAMERA.cull_width,
                    CAMERA.cam_pos.y + CAMERA.cull_offset_y + CAMERA.cull_height,
                    c_white,
                    1.0,
                );
            }

            /*
            if self.show_shadow_chunks {
                var yy_max = room_height() div SHADOW_GRID_CELL_SIZE_DEFAULT;
                var xx_max = room_width() div SHADOW_GRID_CELL_SIZE_DEFAULT;

                for (var yy = 0; yy < yy_max; yy++) {
                    for (var xx = 0; xx < xx_max; xx++) {
                        self.draw_box(
                            xx * SHADOW_GRID_CELL_SIZE_DEFAULT,
                            yy * SHADOW_GRID_CELL_SIZE_DEFAULT,
                            (xx + 1) * SHADOW_GRID_CELL_SIZE_DEFAULT,
                            (yy + 1) * SHADOW_GRID_CELL_SIZE_DEFAULT,
                            c_gray,
                            1.0,
                        );
                    }
                }
            }

            if self.show_activated_shadow_chunks {
                var region = CAMERA.get_cull_region();
                var xx_max = 1 + (region[0] + region[2]) div SHADOW_GRID_CELL_SIZE_DEFAULT;
                var yy_max = 1 + (region[1] + region[3]) div SHADOW_GRID_CELL_SIZE_DEFAULT;

                for (var xx = region[0] div SHADOW_GRID_CELL_SIZE_DEFAULT; xx < xx_max; xx++) {
                    for (var yy = region[1] div SHADOW_GRID_CELL_SIZE_DEFAULT; yy < yy_max; yy++) {
                        self.draw_box(
                            xx * SHADOW_GRID_CELL_SIZE_DEFAULT,
                            yy * SHADOW_GRID_CELL_SIZE_DEFAULT,
                            (xx + 1) * SHADOW_GRID_CELL_SIZE_DEFAULT,
                            (yy + 1) * SHADOW_GRID_CELL_SIZE_DEFAULT,
                            c_yellow,
                            1.0,
                        );
                    }
                }
            }
            */


            if hitbox {
                var _left;
                var _right;
                var _up;
                var _down;

                with obj_damage_tarball {
                    //
                    switch self.collision_mode {
                        case TarballCollision.BuiltIn:
                            _left = bbox_left;
                            _right = bbox_right;
                            _up = bbox_top;
                            _down = bbox_bottom;
                            break;

                        case TarballCollision.RectInRect:
                            _left = x;
                            _right = x + dimensions.x;
                            _up = y;
                            _down = y + dimensions.y;
                            break;

                        case TarballCollision.Circle:
                            _left = x;
                            _right = x + dimensions.x;
                            _up = y;
                            _down = y + dimensions.y;
                            break;
                    }

                    if self.collision_mode == TarballCollision.Circle {
                        //
                    } else {
                        other.draw_rectangle_color(_left, _up, _right, _down, c_fuchsia, 0.5);
                    }

                    if self.in_air {
                        draw_sprite(spr_combat_in_air, 0, x, y);
                    }
                }
            }

            if hurtbox {
                with obj_damage_receiver {
                    other.draw_rectangle_color(
                        self.bbox_left,
                        self.bbox_top,
                        self.bbox_right,
                        self.bbox_bottom,
                        c_yellow,
                        0.5
                    );

                    if self.in_air {
                        draw_sprite(spr_combat_in_air, 0, x, y);
                    }
                }
            }

            if enemy_state || enemy_patience {
                draw_set_font(ANCHOR.get_text_font());
                draw_set_halign(HorizontalOffset.Middle);

                with par_monster {
                    var str = "";
                    if other.enemy_state {
                        str = format("{}State: {} ", str, self.debug_state());
                    }
                    if other.enemy_patience {
                        str = format("{}({})", str, self.patience.value);
                    }

                    draw_text(x, y + z + 6, str);
                }
            }

            if enemy_transform {
                with par_monster {
                    draw_sprite_ext(spr_pixel, 0, self.x, self.y, 1, 1, 0, c_fuchsia, 0.75);
                    draw_sprite_ext(spr_pixel, 0, self.x, -self.depth, 1, 1, 0, c_aqua, 1.0)
                }
            }

            if enemy_collision {
                with par_monster {
                    var id_r = real(self.id);
                    var c = make_color_rgb(id_r % 255, (id_r + 180) % 255, (id_r + 90) % 255);
                    other.draw_rectangle_color(bbox_left, bbox_top, bbox_right, bbox_bottom, c, 0.2);
                }
            }

            if show_cbs {
                with par_NPC {
                    other.draw_rectangle_color(bbox_left, bbox_top, bbox_right, bbox_bottom, c_red, 0.4);
                }
                with par_animal {
                    other.draw_rectangle_color(bbox_left, bbox_top, bbox_right, bbox_bottom, c_yellow, 0.4);
                }
                draw_rectangle_color(obj_ari.bbox_left, obj_ari.bbox_top, obj_ari.bbox_right, obj_ari.bbox_bottom, c_white, 0.4);
            }

            if show_building_points && CURRENT_LOCATION_ID == LocationId.Farm {
                var buildings = get_buildings();

                for (var i = 0; i < buildings.count(); i++) {
                    var building = buildings.get(i);
                    if building.stable != undefined {
                        draw_sprite_ext(spr_pixel, 0, building_send_animal_in_x(building), building_send_animal_in_y(building), 1, 1, 0, c_fuchsia, 0.9);
                        draw_sprite_ext(spr_pixel, 0, building_send_animal_out_x(building), building_send_animal_out_y(building), 1, 1, 0, c_white, 0.9);
                    }
                }
            }

            if transforms {
                var all_instances = instance_get_all();
                for (var j = 0; j < array_length(all_instances); j++) {
                    with all_instances[j] {
                        draw_sprite_ext(spr_pixel, 0, self.x, self.y, 1, 1, 0, c_fuchsia, 0.75);
                    }
                }
            }

            if show_food_markers {
                with obj_animal_food_marker {
                    draw_sprite_ext(spr_pixel, 0, self.x, self.y, 1, 1, 0, c_fuchsia, 0.75);
                }
            }

            if self.bird_landing_positions {
                with obj_bird_landing_position {
                    draw_sprite_ext(spr_pixel, 0, self.x, self.y, self.image_xscale, -self.image_yscale, 0, c_fuchsia, 0.75);
                }
            }

            if show_grow_back_sections && CURRENT_LOCATION_ID == LocationId.Farm {
                var bx_left = ((CAMERA.left() div 8) div GROW_BACK.cell_size) * GROW_BACK.cell_size;
                var bx_top = ((CAMERA.top() div 8) div GROW_BACK.cell_size) * GROW_BACK.cell_size;

                for (var x_size = 0; x_size < (CAMERA.view_width div GROW_BACK.cell_size); x_size++) {
                    for (var y_size = 0; y_size < (CAMERA.view_height div GROW_BACK.cell_size); y_size++) {
                        draw_set_alpha(1.0);
                        draw_rectangle_color(
                            (bx_left + GROW_BACK.cell_size * y_size) * 8,
                            (bx_top + GROW_BACK.cell_size * x_size) * 8,
                            (bx_left + GROW_BACK.cell_size * (y_size + 1)) * 8,
                            (bx_top + GROW_BACK.cell_size * (x_size + 1)) * 8,
                            c_white,
                            c_white,
                            c_white,
                            c_white,
                            true
                        );
                    }
                }

                var region_x = (mouse_x() div 128) * 128;
                var region_y = (mouse_y() div 128) * 128;

                var n = GRID.try_node_index_for_room_position(region_x, region_y);
                if n != undefined {
                    draw_set_font(ANCHOR.get_text_font());
                    draw_text(mouse_x(), mouse_y(), format("\n{} colliders, {} grass\n{} colliders timer, {} grass timer", GRID.node_colliders_count[? n], GRID.node_grass_count[? n], GRID.node_spawn_colliders_timer[? n], GRID.node_spawn_grass_timer[? n]));
                }
            }

            if bomb_radius {
                draw_set_alpha(0.2);
                with obj_monster_barrel {
                    draw_circle_color(x, y, config.aggro_radius, c_red, c_red, false);
                    draw_circle_color(x, y, config.inner_aggro_radius, c_red, c_red, false);
                }
                draw_set_alpha(1);
            }

            if trigger_crash != undefined {
                crash(trigger_crash);
            }

            gpu_reset_extra();

            if show_activity_positions {
                with obj_node_renderer {
                    if self.node.prototype.activities != undefined {
                        static COLORS = [c_fuchsia, c_blue, c_orange, c_green, c_red, c_yellow];
                        for (var i = 0; i < array_length(self.node.prototype.activities); i++) {
                            var positions = self.node.prototype.activities[i].positions;
                            var pos = position_for_furniture_renderer(node);
                            for (var j = 0; j < array_length(positions); j++) {
                                var off = positions[j];
                                var vec = undefined;
                                static CARDS = [Cardinal.South, Cardinal.West, Cardinal.North, Cardinal.East];
                                for (var k = 0; k < array_length(CARDS); k++) {
                                    var dir = CARDS[k];
                                    dir = dir == Cardinal.West ? Cardinal.East : dir;
                                    var vec = off[dir].add(pos);
                                    draw_sprite_ext(spr_pixel, 0, vec.x, vec.y, 1, 1, 0, COLORS[i], 1.0);
                                }
                            }
                        }
                    }
                }
            }
        },
    }
);

object_persists_on_room_change(cosmic_debug_obj);
