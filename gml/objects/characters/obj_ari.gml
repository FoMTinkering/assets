object_create(
    "obj_ari",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            mask_index = spr_character_mask;

            z = 0;
            depth = get_instance_depth(y);
            self.par = new PlayerAnimationRuntime();
            self.par.cardinal = Cardinal.South;
            build_obj_ari_par_from(ARI.animation_assets());
            FISHING.subscribe(self.id);
            var player_data = fiddle_get("player");

            self.par_offset = fiddle_deserialize_vec2(player_data.par.offset);
            self.default_par_offset = par_offset.clone();
            self.default_par_anim_spd = player_data.par.anim_speed;
            self.par_anim_spd = self.default_par_anim_spd;

            self.hurt_colors = array_map(player_data.hurt_colors, function(color_array) {
                return make_color_rgb(color_array[0], color_array[1], color_array[2]);
            });
            self.vfx_sprites = array_map(player_data.vfx_sprites, string_to_asset);
            self.hurt_state = undefined;
            self.iframes = 0;
            self.show_progress_bar = false;
            self.progress_bar_alpha = 0;
            self.progress_bar_color = c_white;
            self.progress_bar_width = 0;
            self.progress_bar_offset = fiddle_deserialize_vec2(player_data.progress_bar_normal_offset);

            self.furniture_rotate = Cardinal.South;
            self.furniture_place = Vec2(0, 0);

            self.move = Vec2(0, 0);
            self.dir = 0;
            self.lagged_dir = 0;
            self.cardinal = Cardinal.South;
            self.cardinal_placement = 0;

            //
            self.god_mode = false;
            self.wimp_mode = false;
            self.crit = false;

            self.ui_journal_request = false;
            self.ui_map_request = false;
            self.ui_spell_request = false;
            self.ui_mount_request = false;

            self.bark_emitter = new BarkEmitter(self, 0, -38);

            //
            self.item_detection_radius = player_data.item_detection_radius;
            self.cell_select = Vec2(0,0);
            self.using_mouse = false;

            //
            var f = fiddle_get("interaction");
            self.interact_nudge_distance = f.nudge_distance;
            self.interact_detection_radius = f.detection_radius;
            self.interact_max_radius = f.max_radius;
            self.no_clip = false;

            self.iframe_can_invisible = false;
            self.iframes_invisible = false;

            instance_create_depth(self.x, self.y, depth, obj_tile_cursor);

            //
            shadow_caster = SHADOW_GRID.caster_create(x, y);
            shadow_caster_set_sprite(shadow_caster, spr_npc_shadow);

            //
            self.collision_list = ds_list_create();
            self.jump_goal = Vec2(0, 0);
            self.jump_data = {
                spd: player_data.jump_data.speed,
                grv: player_data.jump_data.gravity,
                frames: player_data.jump_data.frames,
            }

            self.dust_particles = new ParticleDustBundle()
                .set_gravity_increase(0);

            //
            self.receiver = create_receiver(x, y, spr_mask_ari_hurtbox, undefined, {
                iframes: player_data.hurtbox.iframes,
                target: CombatTarget.Player,
            });

            self.buffered_input = undefined;
            self.buffered_tick = undefined;

            //
            self.meddler = new PathfindingMeddler(MIST.running ? PathfindingAgentKind.Npc : PathfindingAgentKind.Player, self);

            //
            self.fsm = undefined;

            self.fire_breath_effects = [];
            self.breathe_fire_in_other_states = false;
            self.dark_mines_light = undefined;

            //
            ARI.held_animal_last_frame = undefined;
            ARI.held_item_last_frame = undefined;
            self.can_set_depth_in_pause = true;
            self.asset_objects_last_frame = List();

            ds_list_clear(ARI.transparency_list);

            if ARI.held_item() != undefined {
                ARI.skip_pickup_animation = true;
            }

            function refresh_light() {
                var target = undefined;
                var count = ARI.armor.slots.sum_with(function(v) {
                    var item = v.item;
                    return item != undefined && item.prototype.tags.contains("glow_armor")
                        ? 1
                        : 0;
                });
                switch count {
                    case 0:
                        target = Light.CircleEightyEight;
                        break;
                    case 1:
                        target = Light.CircleHundred;
                        break;
                    case 2:
                        target = Light.CircleHundredTwelve;
                        break;
                    case 3:
                        target = Light.CircleHundredTwentyFour;
                        break;
                    case 4:
                        target = Light.CircleHundredThirtySix;
                        break;
                    default:
                        target = Light.CircleHundredFortyEight;
                        break;
                }

                if self.dark_mines_light != undefined {
                    instance_destroy(self.dark_mines_light);
                    self.dark_mines_light = undefined;
                }

                if in_dark_mines() && target != undefined {
                    self.dark_mines_light = instance_create_depth(x, y - 8, -10000, par_light);
                    self.dark_mines_light.tiered_light = target;
                    self.dark_mines_light.sprite_index = LIGHTS[target][0];
                }
            }

            //
            self.refresh_light();

            //
            function summon_held_animal() {
                var animal = find_animal(ARI.held_animal_id);
                if animal.instance == undefined {
                    if animal.is_pet {
                        spawn_pet();
                    } else {
                        spawn_animal(animal);
                    }
                }
                ARI.skip_pickup_animation = true;
            }

            function set_animation(animation_name, set_anim_override=SetAnimationOverride.DoNotOverride) {
                if set_anim_override == SetAnimationOverride.DoNotOverride
                    && (animation_name == self.par.base_animation() || self.par.has_modifier(animation_name))
                {
                    return false;
                }

                self.par.set_animation(animation_name);

                //
                if self.is_mounted() {
                    var target_mount_animation = undefined;
                    switch animation_name {
                        case AnimationName.Ride:
                            target_mount_animation = "idle";
                            break;
                        case AnimationName.RideWalk:
                            target_mount_animation = "walk";
                            break;
                        case AnimationName.RideRun:
                            target_mount_animation = "run";
                            break;
                        case AnimationName.RideJump:
                            target_mount_animation = "jump";
                            break;
                    }

                    if target_mount_animation != undefined && ARI.mount.animation != target_mount_animation {
                        var current_state = self.fsm.current_state();
                        current_state.new_animal_animation(target_mount_animation);
                    }
                }

                return true;
            }

            //
            function celebrate_loot(_celebration_data) {
                self.fsm.change_state(PlayerState.Celebrate);
                self.fsm.blackboard.set("celebration_data", _celebration_data);
            }

            //
            function check_for_menu_opens() {
                if game_paused() {
                    return false;
                }

                if self.ui_journal_request || INPUT.take_press(InputId.OpenJournal) {
                    self.ui_journal_request = false;
                    var menu = ANCHOR.spawn_menu(Menu.Journal);
                    menu.set_active_sub_menu(Menu.Player);
                    return true;
                }

                //
                if self.ui_map_request || INPUT.take_press(InputId.OpenMapMenu) {
                    self.ui_map_request = false;
                    var menu = ANCHOR.spawn_menu(Menu.Journal);
                    menu.set_active_sub_menu(Menu.Map);
                    return true;
                }
            }

            //
            function try_room_transition() {
                var trans = overlap_instance(x, y, obj_roomtransition);
                if trans != undefined && trans.ari_can_use && (self.is_mounted() == false || LOCATIONS[trans.destination_id].outdoor) {
                    trans.transition();
                    return trans;
                }
                return undefined;
            }
            function leave_room(_dir, _spd) {
                self.dir = _dir;

                self.face_dir(_dir);
                self.fsm.blackboard.set("spd", _spd);

                if self.is_mounted() {
                    self.fsm.blackboard.set("was_mounted", true);
                    self.fsm.blackboard.set("last_mounted_animation", self.par.base_animation());
                }

                self.fsm.change_state(PlayerState.Dummy);

                if self.is_mounted() == false && self.par.base_animation() != AnimationName.Run {
                    self.set_animation(AnimationName.Walk);
                }
            }

            //
            function face_dir(_dir) {
                self.dir = (round(_dir / 45) * 45) mod 360;

                var output_cardinal = Cardinal.South;

                switch(self.dir) {
                    case 315:
                    case 0:
                    case 45:
                        output_cardinal = Cardinal.East;
                        break;
                    case 90:
                        output_cardinal = Cardinal.North;
                        break;
                    case 135:
                    case 180:
                    case 225:
                        output_cardinal = Cardinal.West;
                        break;
                    case 270:
                        output_cardinal = Cardinal.South;
                        break;
                }

                self.set_cardinal(output_cardinal);
            }

            //
            //
            //
            function set_cardinal(cardinal) {
                if self.cardinal == cardinal {
                    return;
                }

                self.cardinal = cardinal;
                self.par.set_cardinal(self.cardinal);

                if self.is_mounted() {
                    ARI.mount.cardinality = cardinal;
                }
            }

            //
            function set_idle_simple() {
                if self.is_swimming() {
                    self.set_animation(AnimationName.SwimIdle);
                } else if self.is_mounted() {
                    self.set_animation(AnimationName.Ride);
                } else {
                    self.set_animation(AnimationName.Idle);
                }
            }

            function face_cell(_tile_cell_x, _tile_cell_y) {
                //
                //
                face_point(
                    (_tile_cell_x + 1) * 8,
                    (_tile_cell_y + 1) * 8,
                );
            }

            function face_point(_x, _y) {
                face_dir(point_direction(x, y, _x, _y));
            }

            //
            function player_collect_items() {
                var r = self.item_detection_radius;
                ds_list_clear(self.collision_list);
                var num = collision_rectangle_list(x - r, y - r, x + r, y + r, obj_item, self.collision_list);

                for(var i = 0; i < num; i++) {
                    var _item = self.collision_list[| i];
                    //
                    if _item.pickupable && _item.can_chase {
                        _item.chase_player();
                    }
                }
            }

            //
            function start_hurt_state() {
                //
                TANGO.play("SoundEffects/Ari/TakeDamage", x, y);
                self.hurt_state = 0;
                self.par.blend = {
                    src_mode: bm_src_alpha,
                    dest_mode: bm_one,
                    color: self.hurt_colors[self.hurt_state],
                    alpha: 1.0
                };
                create_animation_effect(
                    x + self.par_offset.x,
                    y + self.par_offset.y,
                    depth - 1,
                    self.vfx_sprites[self.cardinal]
                );

                self.save_iframes();
            }

            function save_iframes() {
                self.iframes = self.receiver.current_iframes;
                self.receiver.status = set_flag(self.receiver.status, ReceiverStatus.UntimedInvulnerable);
            }

            //
            function end_hurt_state() {
                self.restore_iframes();

                self.par.blend = undefined;
                self.hurt_state = undefined;

            }

            function restore_iframes() {
                ds_list_clear(self.receiver.damaged);
                self.receiver.status = remove_flag(self.receiver.status, ReceiverStatus.UntimedInvulnerable);
                self.receiver.current_iframes = self.iframes;
                self.iframes = 0;

                self.iframe_can_invisible = true;
            }

            //
            function can_mount() {
                return ARI.mount != undefined
                    && LOCATIONS[CURRENT_LOCATION_ID].outdoor
                    && !self.overlaps_mount_blocker();
            }

            function overlaps_mount_blocker() {
                return overlap_instance(self.x, self.y, obj_mount_blocker);
            }

            function collision_check(_vec2) {
                if _vec2.is_zero() || (DEBUG_TOOLS && self.no_clip) {
                    var ni = GRID.try_node_index_for_room_position(x, y);
                    if ni != undefined && GRID.node_object_id[ni] != undefined {
                        GRID.node_parent[ni].renderer.collide(false, self.cardinal);
                    }

                    return;
                }

                static SLIPPERY_COEFFICIENT = fiddle_get("misc/movement_speeds/slip_size");

                var collision_f = function(xx, yy) {
                    if self.overlapping_monster == false {
                        var o = overlap_point(xx, yy, par_monster);
                        if o != undefined && o.can_overlap_ari == false {
                            return true;
                        }
                    }
                    if self.overlapping_animal == false && overlap_point_any(xx, yy, par_animal) {
                        return true;
                    }
                    if self.overlapping_npc == false && overlap_point_any(xx, yy, par_NPC) {
                        return true;
                    }
                    //
                    if self.is_mounted() {
                        var trans = overlap_instance(xx, yy, obj_roomtransition);
                        if trans != undefined && trans.ari_can_use && LOCATIONS[trans.destination_id].outdoor == false {
                            return true;
                        }
                    }

                    var n = GRID.try_node_index_for_room_position(xx, yy);
                    return (n == undefined || GRID.node_collideable[n]);
                }

                var step_free = function(dx, dy, collision_f) {
                    if dy != 0 {
                        var leading_y = (dy > 0) ? self.bbox_bottom : self.bbox_top;

                        if collision_f(self.bbox_left + dx, leading_y + dy)
                            || collision_f(self.bbox_right + dx, leading_y + dy)
                        {
                            return false;
                        }
                    }
                    if dx != 0 {
                        var leading_x = (dx > 0) ? self.bbox_right : self.bbox_left;

                        if collision_f(leading_x + dx, self.bbox_top + dy)
                            || collision_f(leading_x + dx, self.bbox_bottom + dy)
                        {
                            return false;
                        }
                    }

                    return true;
                }

                //
                //
                var move_x = real(int64(_vec2.x)) + sign(_vec2.x);
                var move_y = real(int64(_vec2.y)) + sign(_vec2.y);

                var initial_move_x = move_x;
                var initial_move_y = move_y;

                var bbox_bounds = [
                    [bbox_left,  bbox_top,    -1, -1],
                    [bbox_left,  bbox_bottom, -1,  1],
                    [bbox_right, bbox_top,     1, -1],
                    [bbox_right, bbox_bottom,  1,  1],
                ];

                //
                var sign_move_x = sign(move_x);
                var sign_move_y = sign(move_y);
                var input_x = abs(round(move_x));
                var input_y = abs(round(move_y));

                self.overlapping_animal = overlap_instance_any(x, y, par_animal);
                self.overlapping_monster = overlap_instance_any(x, y, par_monster);
                self.overlapping_npc = overlap_instance_any(x, y, par_NPC);

                var slipped = false;
                if initial_move_y == 0 && move_x != 0 {
                    var leading_x = (move_x > 0) ? bbox_right : bbox_left;
                    var target_x = leading_x + move_x;

                    if collision_f(target_x, bbox_top) || collision_f(target_x, bbox_bottom) {
                        var slip_y = 0;

                        for (var d = 0; d <= SLIPPERY_COEFFICIENT; d++) {
                            if collision_f(target_x, bbox_bottom + d) == false {
                                slip_y = 1;
                                break;
                            }
                            if collision_f(target_x, bbox_top - d) == false {
                                slip_y = -1;
                                break;
                            }
                        }

                        if slip_y != 0 && step_free(0, slip_y, collision_f) {
                            move_y += slip_y;
                            move_x  = 0;
                            slipped = true;
                        }
                    }
                }

                if slipped == false && initial_move_x == 0 && move_y != 0 {
                    var leading_y = (move_y > 0) ? bbox_bottom : bbox_top;
                    var target_y = leading_y + move_y;

                    if collision_f(bbox_left, target_y) || collision_f(bbox_right, target_y) {
                        var slip_x = 0;

                        for (var d = 0; d <= SLIPPERY_COEFFICIENT; d++) {
                            if collision_f(bbox_right + d, target_y) == false {
                                slip_x = 1;
                                break;
                            }
                            if collision_f(bbox_left - d, target_y) == false {
                                slip_x = -1;
                                break;
                            }
                        }

                        if slip_x != 0 && step_free(slip_x, 0, collision_f) {
                            move_x += slip_x;
                            move_y  = 0;
                            slipped = true;
                        }
                    }
                }

                if slipped == false {
                    //
                    for (var i = 0; i < 4; i++) {
                        //
                        if bbox_bounds[i][2] != sign_move_x || move_x == 0 {
                            continue;
                        }

                        _xx = bbox_bounds[i][0];
                        _yy = bbox_bounds[i][1];

                        repeat input_x {
                            if collision_f(_xx + move_x, _yy) {
                                move_x -= sign_move_x;
                                if abs(move_x) < 1 {
                                    move_x = 0;
                                }
                                if move_x == 0 {
                                    break;
                                }
                            }
                        }
                    }

                    //
                    for (var i = 0; i < 4; i++) {
                        if bbox_bounds[i][3] != sign_move_y || move_y == 0 {
                            continue;
                        }

                        _xx = bbox_bounds[i][0];
                        _yy = bbox_bounds[i][1];

                        repeat input_y {
                            if collision_f(_xx + move_x, _yy + move_y) {
                                move_y -= sign_move_y;
                                if abs(move_y) < 1 {
                                    move_y = 0;
                                }
                                if move_y == 0 {
                                    break;
                                }
                            }
                        }
                    }
                }

                //
                var ni = GRID.node_index_for_room_position(x + move_x, y + move_y);
                if GRID.node_object_id[ni] != undefined {
                    GRID.node_parent[ni].renderer.collide(true, self.cardinal);
                }

                //
                if initial_move_x != move_x {
                    _vec2.x = move_x;
                }
                if initial_move_y != move_y {
                    _vec2.y = move_y;
                }
            }


            //
            function can_land_at_position(xx, yy) {
                //
                if overlap_instance_any(xx, yy, [par_monster, par_NPC, par_animal]) {
                    return false;
                }

                return self.check_bbox_at_point(xx, yy, function(xx, yy) {
                    var ni = GRID.try_node_index_for_room_position(xx, yy);
                    if ni == undefined {
                        return false;
                    }

                    //
                    if (ARI.held_animal_id != undefined || self.is_mounted()) && GRID.node_terrain_kind[ni] == TerrainKind.Water {
                        return false;
                    }

                    //
                    if self.is_mounted() {
                        var trans = overlap_instance(xx, yy, obj_roomtransition);
                        if trans != undefined && trans.ari_can_use && LOCATIONS[trans.destination_id].outdoor == false {
                            return false;
                        }
                    }

                    return !GRID.node_collideable[ni];
                });
            }

            //
            function check_bbox_at_point(xx, yy, f, param) {
                var old_xx = self.x;
                var old_yy = self.y;

                self.x = xx;
                self.y = yy;

                //
                var output = f(self.bbox_left, self.bbox_top, false, param)
                    && f(self.bbox_right, self.bbox_top, false, param)
                    && f(self.bbox_left, self.bbox_bottom, false, param)
                    && f(self.bbox_right, self.bbox_bottom, false, param);

                self.x = old_xx;
                self.y = old_yy;

                return output;
            }

            //
            function check_jump(input_x, input_y, jump_distance, ari_swims) {
                //
                if input_x == 0 && input_y == 0 {
                    self.jump_goal.x = x;
                    self.jump_goal.y = y;
                    return;
                }

                var helper = Vec2(input_x, input_y);
                helper.normalized();

                var dir = helper.to_dir_degree();
                if ari_swims {
                    dir = undefined;
                }

                var last_safe_distance = 0;
                for (var i = 1; i < jump_distance; i++) {
                    helper.normalized();
                    helper.set_scale(i);

                    if self.can_land_at_position(x + helper.x, y + helper.y) {
                        last_safe_distance = i;
                    }

                    var can_jump_over = self.check_bbox_at_point(x + helper.x, y + helper.y, function(xx, yy, _center, dir) {
                        //
                        if self.is_mounted() {
                            var trans = overlap_instance(xx, yy, obj_roomtransition);
                            if trans != undefined && trans.ari_can_use && LOCATIONS[trans.destination_id].outdoor == false {
                                return false;
                            }
                        }

                        var ni = GRID.try_node_index_for_room_position(xx, yy);
                        if ni == undefined {
                            return true;
                        }
                        if GRID.node_collideable[ni] {
                            if GRID.node_can_jump_over[ni] {
                                return true;
                            } else {
                                if GRID.node_force[ni] == undefined {
                                    return false;
                                } else if dir == undefined {
                                    return false;
                                } else {
                                    var level = tile_forces_to_level(GRID.node_force[ni]);
                                    var force = tile_forces_to_dir(GRID.node_force[ni]);
                                    return level == 0
                                        && abs(force - dir) <= 90;
                                }
                            }
                        } else {
                            return true;
                        }
                    }, dir);

                    if can_jump_over == false {
                        break;
                    }
                }

                if last_safe_distance == 0 {
                    self.jump_goal.x = x;
                    self.jump_goal.y = y;
                } else {
                    //
                    helper.normalized();
                    helper.set_scale(last_safe_distance);

                    self.jump_goal.x = floor(x + helper.x);
                    self.jump_goal.y = floor(y + helper.y);
                }
            }

            //
            function update_cell_select(held_item_prototype, hold_checks, relative_cell_select) {
                static PRESSED = array_create(InputId.LEN, false);
                static DIR_INPUTS = [InputId.FurnitureLeft, InputId.FurnitureRight, InputId.FurnitureUp, InputId.FurnitureDown];
                static HOLD_START = 8;
                static HOLD_PERIOD = 1.5;
                static QUEUE = List();

                var norm_x = 16 * (self.x div 16);
                var norm_y = 16 * (self.y div 16);

                var base_x = self.x % 16;
                var base_y = self.y % 16;

                QUEUE.clear();

                if self.using_mouse {
                    //
                    switch held_item_prototype.use {
                        case ItemUse.PlaceObject:
                            self.cell_select.x = mouse_x() div 8;
                            self.cell_select.y = mouse_y() div 8;

                            //
                            var proto = NODE_PROTOTYPES[held_item_prototype.object];
                            var rotation_matrix = furniture_calc_rot_to_rotation_matrix(
                                furniture_rotation_amount(self.cardinal_placement, proto),
                                proto
                            );
                            var size = furniture_size(rotation_matrix, proto);
                            //
                            self.cell_select.x = clamp(self.cell_select.x, max(CAMERA.left() div 8 + 1, 0) + (size.x div 2) + 1, min(CAMERA.right() div 8, GRID.dims.x - 1) - (size.x div 2));
                            self.cell_select.y = clamp(self.cell_select.y, max(CAMERA.top() div 8 + 1, 0) + (size.y div 2) + 1, min(CAMERA.bottom() div 8, GRID.dims.y - 1) - (size.y div 2));

                            if NODE_PROTOTYPES[held_item_prototype.object].on_twos_only {
                                self.cell_select.x = (self.cell_select.x div 2) * 2 + 1;
                                self.cell_select.y = (self.cell_select.y div 2) * 2 + 1;
                            }
                            break;
                        case ItemUse.PlaceTile:
                            self.cell_select.x = (mouse_x() div 16) * 2;
                            self.cell_select.y = (mouse_y() div 16) * 2;
                            break;
                        case ItemUse.PlantSapling:
                        case ItemUse.Blueprint:
                            var size_x;
                            var size_y;
                            if held_item_prototype.use == ItemUse.PlantSapling {
                                size_x = 2;
                                size_y = 2;
                            } else {
                                size_x = BLUEPRINT_PROTOTYPES[held_item_prototype.blueprint.blueprint].size.x div 2;
                                size_y = BLUEPRINT_PROTOTYPES[held_item_prototype.blueprint.blueprint].size.y div 2;
                            };

                            if size_x % 2 == 1 {
                                size_x -= 1;
                            }
                            if size_y % 2 == 1 {
                                size_y -= 1;
                            }

                            self.cell_select.x = ((mouse_x() div 16) * 2) - size_x;
                            self.cell_select.y = ((mouse_y() div 16) * 2) - size_y;

                            //
                            self.cell_select.x = clamp(self.cell_select.x, max(CAMERA.left() div 8 + 1, 0) + size_x, min(CAMERA.right() div 8, GRID.dims.x - 1) - (size_x * 2));
                            self.cell_select.y = clamp(self.cell_select.y, max(CAMERA.top() div 8 + 1, 0) + size_y, min(CAMERA.bottom() div 8, GRID.dims.y - 1) - (size_y * 2));
                            break;
                        default:
                            //
                            var bundle = {
                                mouse_xx: mouse_x() - 8,
                                mouse_yy: mouse_y() - 8,
                                norm_x: norm_x,
                                norm_y: norm_y,
                                dist_score: infinity,
                                coord: undefined
                            };
                            var check_tile_for_close = function(x_offset, y_offset, bundle) {
                                var this_coord = Vec2(bundle.norm_x + x_offset * 16, bundle.norm_y + y_offset * 16);
                                var x_comp = this_coord.x - bundle.mouse_xx;
                                var y_comp = this_coord.y - bundle.mouse_yy;
                                var distance = x_comp * x_comp + y_comp * y_comp;
                                if distance < bundle.dist_score {
                                    bundle.dist_score = distance;
                                    bundle.coord = this_coord;
                                }
                            }

                            for (var xx = -1; xx < 2; xx++) {
                                for (var yy = -1; yy < 2; yy++) {
                                    check_tile_for_close(xx, yy, bundle);
                                }
                            }

                            switch self.cardinal {
                                case Cardinal.West:
                                    if base_x < 8 {
                                        check_tile_for_close(-2, 0, bundle);

                                        if base_y < 8 {
                                            check_tile_for_close(-2, -1, bundle);
                                        } else {
                                            check_tile_for_close(-2, 1, bundle);
                                        }
                                    }
                                    break;
                                case Cardinal.East:
                                    if base_x >= 8 {
                                        check_tile_for_close(2, 0, bundle);

                                        if base_y < 8 {
                                            check_tile_for_close(2, -1, bundle);
                                        } else {
                                            check_tile_for_close(2, 1, bundle);
                                        }
                                    }
                                    break;
                                case Cardinal.North:
                                    if base_y < 8 {
                                        check_tile_for_close(0, -2, bundle);

                                        if base_x < 8 {
                                            check_tile_for_close(-1, -2, bundle);
                                        } else {
                                            check_tile_for_close(1, -2, bundle);
                                        }
                                    }
                                    break;
                                case Cardinal.South:
                                    if base_y >= 8 {
                                        check_tile_for_close(0, 2, bundle);

                                        if base_x < 8 {
                                            check_tile_for_close(-1, 2, bundle);
                                        } else {
                                            check_tile_for_close(1, 2, bundle);
                                        }
                                    }
                                    break;
                            }

                            bundle.coord.x = bundle.coord.x div 8;
                            bundle.coord.y = bundle.coord.y div 8;

                            self.cell_select = bundle.coord;
                    }

                    if held_item_prototype.tool_type == ToolType.Net {
                        obj_tile_cursor.show_tile_cursor = GRID.item_effects_node_at_cell(self.cell_select.x, self.cell_select.y, held_item_prototype);
                    } else if GRID.item_effects_node_at_cell(self.cell_select.x, self.cell_select.y, held_item_prototype)
                        || GRID.item_effects_node_at_cell(self.cell_select.x + 1, self.cell_select.y, held_item_prototype)
                        || GRID.item_effects_node_at_cell(self.cell_select.x, self.cell_select.y + 1, held_item_prototype)
                        || GRID.item_effects_node_at_cell(self.cell_select.x + 1, self.cell_select.y + 1, held_item_prototype)
                    {
                        obj_tile_cursor.show_tile_cursor = true;
                    }
                } else {
                    switch held_item_prototype.use {
                        case ItemUse.PlaceObject:
                            for (var i = 0; i < 4; i++) {
                                var pressed = false;
                                var input = DIR_INPUTS[i];
                                if INPUT.check(input) {
                                    var hold = hold_checks[input];
                                    if hold == undefined {
                                        pressed = true;
                                        hold_checks[input] = TICK;
                                    } else {
                                        var duration = TICK - hold;
                                        if duration > HOLD_START && (duration - HOLD_START) % HOLD_PERIOD == 0 {
                                            pressed = true;
                                        }
                                    }
                                } else {
                                    hold_checks[input] = undefined;
                                }
                                PRESSED[input] = pressed;
                            }

                            var new_coord_x = PRESSED[InputId.FurnitureRight] - PRESSED[InputId.FurnitureLeft];
                            var new_coord_y = PRESSED[InputId.FurnitureDown] - PRESSED[InputId.FurnitureUp];

                            var rotated_relative = relative_cell_select.rotate(cardinal_to_mat2(self.cardinal));
                            var candidate_x = (self.x div 8) + rotated_relative.x;
                            var candidate_y = (self.y div 8) + rotated_relative.y;

                            //
                            var proto = NODE_PROTOTYPES[held_item_prototype.object];
                            var rotation_matrix = furniture_calc_rot_to_rotation_matrix(
                                furniture_rotation_amount(self.cardinal_placement, proto),
                                proto
                            );
                            var region = furniture_size(rotation_matrix, proto);

                            var rot_data = furniture_mask_prep_vecdata(proto.size, rotation_matrix);

                            var not_in_collision = furniture_test_flag_mask(
                                rot_data,
                                GRID,
                                candidate_x - (region.x div 2),
                                candidate_y - (region.y div 2),
                                proto,
                                rotation_matrix,
                                true
                            );

                            if not_in_collision {
                                if furniture_test_flag_mask(
                                    rot_data,
                                    GRID,
                                    candidate_x + new_coord_x - (region.x div 2),
                                    candidate_y - (region.y div 2),
                                    proto,
                                    rotation_matrix,
                                    true
                                ) == false {
                                    new_coord_x = 0;
                                }

                                if furniture_test_flag_mask(
                                    rot_data,
                                    GRID,
                                    candidate_x + new_coord_x - (region.x div 2),
                                    candidate_y + new_coord_y - (region.y div 2),
                                    proto,
                                    rotation_matrix,
                                    true
                                ) == false {
                                    new_coord_y = 0;
                                }
                            }

                            if new_coord_x != 0 || new_coord_y != 0 {
                                var back_port_coord = Vec2(new_coord_x, new_coord_y);
                                back_port_coord.set_rotate(cardinal_to_inverse_mat2(self.cardinal));

                                relative_cell_select.x += back_port_coord.x;
                                relative_cell_select.y += back_port_coord.y;
                            }

                            self.cell_select.x = candidate_x + new_coord_x;
                            self.cell_select.y = candidate_y + new_coord_y;

                            if NODE_PROTOTYPES[held_item_prototype.object].on_twos_only {
                                self.cell_select.x = (self.cell_select.x div 2) * 2 + 1;
                                self.cell_select.y = (self.cell_select.y div 2) * 2 + 1;
                            }
                            break;

                        case ItemUse.PlantSapling:
                            self.cell_select.x = (obj_ari.x div 16) * 2;
                            self.cell_select.y = (obj_ari.y div 16) * 2;

                            switch self.cardinal {
                                case Cardinal.East:
                                    self.cell_select.x += 2;
                                    self.cell_select.y -= 1;
                                    break;
                                case Cardinal.West:
                                    self.cell_select.x -= 5;
                                    self.cell_select.y -= 1;
                                    break;
                                case Cardinal.North:
                                    self.cell_select.y -= 5;
                                    self.cell_select.x -= 1;
                                    break;
                                case Cardinal.South:
                                    self.cell_select.y += 2;
                                    self.cell_select.x -= 1;
                                    break;
                            }
                            break;
                        case ItemUse.Blueprint:
                            //
                            for (var i = 0; i < 4; i++) {
                                var pressed = false;
                                var input = DIR_INPUTS[i];
                                if INPUT.check(input) {
                                    var hold = hold_checks[input];
                                    if hold == undefined {
                                        pressed = true;
                                        hold_checks[input] = TICK;
                                    } else {
                                        var duration = TICK - hold;
                                        if duration > HOLD_START && (duration - HOLD_START) % HOLD_PERIOD == 0 {
                                            pressed = true;
                                        }
                                    }
                                } else {
                                    hold_checks[input] = undefined;
                                }
                                PRESSED[input] = pressed;
                            }

                            self.cell_select.x += 2 * (PRESSED[InputId.FurnitureRight] - PRESSED[InputId.FurnitureLeft]);
                            self.cell_select.y += 2 * (PRESSED[InputId.FurnitureDown] - PRESSED[InputId.FurnitureUp]);
                            break;
                        default:
                            var out_x = obj_ari.x div 16;
                            var out_y = obj_ari.y div 16;

                            obj_tile_cursor.show_tile_cursor = false;

                            var go_long = true;

                            if held_item_prototype.use == ItemUse.UseTool
                                && (held_item_prototype.tool_type == ToolType.Hoe
                                    || held_item_prototype.tool_type == ToolType.WateringCan
                                    || held_item_prototype.tool_type == ToolType.Shovel
                                )
                            {
                                go_long = false;
                            }

                            switch self.cardinal {
                                case Cardinal.East:
                                    QUEUE.push(Vec2(out_x + 1, out_y));
                                    QUEUE.push(Vec2(out_x, out_y));

                                    if go_long == false {
                                        break;
                                    }

                                    if base_x >= 8 {
                                        QUEUE.push(Vec2(out_x + 2, out_y));
                                    }

                                    if base_y < 8 {
                                        QUEUE.push(Vec2(out_x + 1, out_y - 1));
                                        if base_x >= 8 {
                                            QUEUE.push(Vec2(out_x + 2, out_y - 1));
                                        }
                                    } else {
                                        QUEUE.push(Vec2(out_x + 1, out_y + 1));
                                        if base_x >= 8 {
                                            QUEUE.push(Vec2(out_x + 2, out_y + 1));
                                        }
                                    }
                                    break;
                                case Cardinal.West:
                                    QUEUE.push(Vec2(out_x - 1, out_y));
                                    QUEUE.push(Vec2(out_x, out_y));

                                    if go_long == false {
                                        break;
                                    }

                                    if base_x < 8 {
                                        QUEUE.push(Vec2(out_x - 2, out_y));
                                    }

                                    if base_y < 8 {
                                        QUEUE.push(Vec2(out_x - 1, out_y - 1));
                                        if base_x < 8 {
                                            QUEUE.push(Vec2(out_x - 2, out_y - 1));
                                        }
                                    } else {
                                        QUEUE.push(Vec2(out_x - 1, out_y - 1));
                                        if base_x < 8 {
                                            QUEUE.push(Vec2(out_x - 2, out_y - 1));
                                        }
                                    }
                                    break;
                                case Cardinal.South:
                                    QUEUE.push(Vec2(out_x, out_y + 1));
                                    QUEUE.push(Vec2(out_x, out_y));

                                    if go_long == false {
                                        break;
                                    }

                                    if base_y >= 8 {
                                        QUEUE.push(Vec2(out_x, out_y + 2));
                                    }

                                    if base_x < 8 {
                                        QUEUE.push(Vec2(out_x - 1, out_y + 1));
                                        if base_y >= 8 {
                                            QUEUE.push(Vec2(out_x - 1, out_y + 2));
                                        }
                                    } else {
                                        QUEUE.push(Vec2(out_x + 1, out_y + 1));
                                        if base_y >= 8 {
                                            QUEUE.push(Vec2(out_x + 1, out_y + 2));
                                        }
                                    }
                                    break;
                                case Cardinal.North:
                                    QUEUE.push(Vec2(out_x, out_y - 1));
                                    QUEUE.push(Vec2(out_x, out_y));

                                    if go_long == false {
                                        break;
                                    }

                                    if base_y < 8 {
                                        QUEUE.push(Vec2(out_x, out_y - 2));
                                    }

                                    if base_x < 8 {
                                        QUEUE.push(Vec2(out_x - 1, out_y - 1));
                                        if base_y < 8 {
                                            QUEUE.push(Vec2(out_x - 1, out_y - 2));
                                        }
                                    } else {
                                        QUEUE.push(Vec2(out_x + 1, out_y - 1));
                                        if base_y < 8 {
                                            QUEUE.push(Vec2(out_x + 1, out_y - 2));
                                        }
                                    }
                                    break;
                            }

                            var did_it = false;
                            for (var i = 0; i < QUEUE.count(); i++) {
                                var coord = QUEUE.get(i);

                                //
                                coord.x *= 2;
                                coord.y *= 2;

                                if held_item_prototype.use == ItemUse.UseTool
                                    && held_item_prototype.tool_type == ToolType.Net
                                {
                                    if GRID.item_effects_node_at_cell(coord.x, coord.y, held_item_prototype) {
                                        self.cell_select = coord;
                                        obj_tile_cursor.show_tile_cursor = true;
                                        did_it = true;
                                        break;
                                    }
                                } else if GRID.item_effects_node_at_cell(coord.x, coord.y, held_item_prototype)
                                    || GRID.item_effects_node_at_cell(coord.x + 1, coord.y, held_item_prototype)
                                    || GRID.item_effects_node_at_cell(coord.x, coord.y + 1, held_item_prototype)
                                    || GRID.item_effects_node_at_cell(coord.x + 1, coord.y + 1, held_item_prototype)
                                {
                                    self.cell_select = coord;
                                    obj_tile_cursor.show_tile_cursor = true;

                                    did_it = true;
                                    break;
                                }
                            }

                            //
                            if did_it == false {
                                var coord = QUEUE.first();
                                self.cell_select = coord;
                            }
                            break;
                    }
                }

                //
                self.cell_select.x = clamp(self.cell_select.x, max(CAMERA.left() div 8 + 1, 0) + 2, min(CAMERA.right() div 8, GRID.dims.x - 1) - 2);
                self.cell_select.y = clamp(self.cell_select.y, max(CAMERA.top() div 8 + 1, 0) + 2, min(CAMERA.bottom() div 8, GRID.dims.y - 1) - 2);

                //
                if ANCHOR.mouse_interacting_with_any_node()
                    || held_item_prototype.use == ItemUse.Attack
                    || matches(held_item_prototype.tool_type, ToolType.Net, ToolType.FishingRod)
                 {
                    obj_tile_cursor.state = TileCursorState.Hidden;
                }
            }

            function change_preset(new_preset_index) {
                build_obj_ari_par_from(ARI.presets.get(new_preset_index));
                ARI.preset_index_selected = new_preset_index;
            }

            //
            function dive(water_obj, dive_behavior) {
                var f = fiddle_get("misc/diving");
                TANGO.play(f.sfx);
                var counter;

                switch dive_behavior {
                    case DiveBehavior.Divespot:
                        counter = f.whirlpool_counter;
                        break;
                    case DiveBehavior.Whirlpool:
                        counter = f.dungeon_counter;
                        break;
                }

                obj_ari.fsm.blackboard.set("dive_counter", counter);

                obj_ari.fsm.blackboard.set("underwater_behavior", dive_behavior);
                obj_ari.fsm.blackboard.set("water_object", water_obj);

                obj_ari.fsm.change_state(PlayerState.Diving);
            }

            //
            function quest_handle_queries() {
                if game_paused() || (TEST_SUITE && !STORY_EXECUTOR_RUNNING) {
                    return false;
                }

                var active_quest_names = QUEST_LOG.active.keys();
                for (var i = 0, c = array_length(active_quest_names); i < c; i++) {
                    var quest_data = QUEST_LOG.active.get(active_quest_names[i]);

                    var task = quest_data.quest.tasks.get(quest_data.current_stage);
                    var cutscene_query = task.query_targets.find(function(qt) {
                        return qt.type == QuestQueryType.Cutscene && qt.cutscene_location == CURRENT_LOCATION_ID;
                    });

                    if cutscene_query == undefined {
                        continue;
                    }

                    if ARI.end_of_day_status != undefined {
                        continue;
                    }

                    cutscene_query = task.query_targets.get(cutscene_query);

                    var inside_rect = point_in_rectangle(
                        x,
                        y,
                        cutscene_query.cutscene_area[0] * 8,
                        cutscene_query.cutscene_area[1] * 8,
                        cutscene_query.cutscene_area[2] * 8,
                        cutscene_query.cutscene_area[3] * 8,
                    );

                    //
                    if !(inside_rect && fulfills_all_requirements(task.requirements, quest_data.blackboard, QUEST_LOG.blackboard)) {
                        continue;
                    }

                    obj_ari.set_idle_simple();
                    MIST.request_scene(cutscene_query.cutscene);

                    MIST.arbitrary_quest_to_progress = quest_data;
                    return true;
                }
                return false;
            }

            //
            //
            //
            //
            function buffered_player_cmp_and_take(input) {
                if self.buffered_input == input && (TICK - self.buffered_tick < 30) {
                    self.buffered_input = undefined;
                    self.buffered_tick = undefined;
                    return true;
                } else {
                    return false;
                }
            }

            function is_in_normal_state() {
                var csid = self.fsm.current_state_id();

                return csid == PlayerState.Default
                    || csid == PlayerState.Swim
                    || csid == PlayerState.Dummy;
            }

            function is_swimming() {
                var csid = self.fsm.current_state_id();
                return csid == PlayerState.Swim
                    || csid == PlayerState.Diving
                    || csid == PlayerState.Underwater
                    || csid == PlayerState.Resurface
                    || csid == PlayerState.WhirlPool;
            }

            function is_mounted() {
                //
                if self.fsm == undefined {
                    return false;
                }
                var csid = self.fsm.current_state_id();
                return csid == PlayerState.MountDefault
                    || csid == PlayerState.MountJump;
            }

            function should_show_item_usage_ux() {
                switch self.fsm.current_state_id() {
                    case PlayerState.Jump: return self.fsm.last_state_id == PlayerState.Default;
                    case PlayerState.Default: return true;
                    default: return false;
                }
            }

            function can_use_item_in_state() {
                var csid = self.fsm.current_state_id();
                return csid != PlayerState.Swim
                    && csid != PlayerState.Diving
                    && csid != PlayerState.Underwater
                    && csid != PlayerState.Resurface
                    && csid != PlayerState.WhirlPool
                    && csid != PlayerState.AnimateAndThen
                    && csid != PlayerState.Dummy
                    && csid != PlayerState.MountDefault
                    && csid != PlayerState.MountJump;
            }

            function dust_particle_burst() {
                var rep = self.dust_particles.get_instances();
                repeat(rep) {
                    create_debris(
                        x + self.dust_particles.get_x_offset(),
                        y + self.dust_particles.get_y_offset(),
                        depth-1,
                        spr_part_rundirt,
                        self.dust_particles
                    );
                }
            }

            //
            function check_input(_input_id) {
                //
                if self.buffered_player_cmp_and_take(_input_id) {
                    return true;
                } else if INPUT.check(_input_id) {
                    return true;
                }

                return false;
            }

            //
            function check_pressed_input(_input_id) {
                //
                if self.buffered_player_cmp_and_take(_input_id) {
                    return true;
                } else if INPUT.take_press(_input_id) {
                    return true;
                }

                return false;
            }

            function should_faint() {
                if CLOCK.time < hours(26) || ARI.end_of_day_status != undefined || TAXI.is_traveling() {
                    return false;
                }

                self.par.blend = undefined;
                ARI.fire_breath_time = 0;

                ARI.end_of_day_status = ARI.has_protection_scroll
                    ? EndOfDayStatus.Protected
                    : EndOfDayStatus.Fainted;

                T2R.write("has_ever_fainted", true);
                refresh_achievements([Requirement.WorldFactIs]);

                self.depth = get_instance_depth(self.y);
                self.fsm.change_state(PlayerState.AnimateAndThen);

                self.fsm.blackboard.set("execute_always", true);

                if self.fsm.current_state_id() == PlayerState.Swim {
                    self.fsm.blackboard.set("animation", AnimationName.Blink);
                    self.fsm.blackboard.set("on_start_action", function() {
                        pass_out(true);
                        self.par_anim_spd = 0;
                    });
                } else {
                    self.fsm.blackboard.set("animation", AnimationName.Faint);
                    self.fsm.blackboard.set("on_start_action", function() {
                        pass_out(true);
                    });
                }

                self.fsm.blackboard.set("hold_animation_forever", true);

                return true;
            }

            function should_die() {
                if ARI.get_health() > 0 {
                    return false;
                }

                if ARI.status_effects.effects.get(StatusEffectId.Fairy) != undefined {
                    ARI.set_health(ARI.get_max_health() * 0.50);
                    if ARI.get_stamina() < ARI.get_max_stamina() * 0.50 {
                        ARI.set_stamina(ARI.get_max_stamina() * 0.50);
                    }
                    ARI.status_effects.cancel(StatusEffectId.Fairy);
                    return false;
                }

                game_stats_increment(GAME_STATS, "deaths");
                ARI.end_of_day_status = ARI.has_protection_scroll
                    ? EndOfDayStatus.Protected
                    : EndOfDayStatus.Died;

                self.fsm.change_state(PlayerState.AnimateAndThen);
                if is_swimming() {
                    self.fsm.blackboard.set("was_swimming", true);
                    self.fsm.blackboard.set("animation", AnimationName.HurtBlink);
                } else {
                    self.fsm.blackboard.set("animation", AnimationName.Faint);
                }
                self.fsm.blackboard.set("hold_animation_forever", true);
                self.fsm.blackboard.set("approach_z", true);
                self.fsm.blackboard.set("on_start_action", function() {
                    ARI.set_stamina(0);
                    TANGO.play("SoundEffects/Ari/Faint");

                    if self.fsm.blackboard.try_take("was_swimming", false) {
                        self.par_anim_spd = 0;
                    }

                    SCREEN_FADER.fade_out(FADE_SPEED_CUTSCENE, function() {
                        if ARI.has_protection_scroll {
                            pass_out();
                        } else {
                            MIST.run_scene("dying");
                        }
                    });
                });

                return true;
            }

            function initialize_for_cutscene() {
                self.par.unset_all_modifiers();
                self.par.remove_held_sprite();
                self.par.held_animal_render_callback = undefined;
                self.meddler.release_reservations();
                self.meddler = new PathfindingMeddler(PathfindingAgentKind.Npc, self);
                ARI.held_item_last_frame = undefined;
            }

            //
            function enter_action_animation(face_x, face_y) {
                self.fsm.change_state(PlayerState.AnimateAndThen);
                self.face_dir(point_direction(self.x, self.y, face_x, face_y));
                self.fsm.blackboard.set("animation", AnimationName.Action);
                self.fsm.blackboard.set("only_south", false);
                self.fsm.blackboard.set("unset_modifiers", true);
            }

            function change_mount_while_mounted() {
                if self.fsm.current_state_id() == PlayerState.MountDefault {
                    //
                    with self.fsm.current_state() {
                        mounted_par_offsets(self.in_idle_variant);
                        self.mount_cycle_override = undefined;
                        if ARI.mount.variant == "giant_chicken_white"
                            || ARI.mount.variant == "giant_chicken_gold"
                        {
                            self.mount_cycle_override = MountCycle.Back;
                        }
                    }
                }
            }

            function emit_fire() {
                var player_data = fiddle_get("player");
                var fire_body_alpha = (player_data.fire_effect_body_alpha_anchor
                    + sin(ARI.fire_breath_time * 2 * pi / player_data.fire_effect_body_time)
                        * player_data.fire_effect_body_alpha_range)
                    * ARI.fire_body_alpha;

                if ARI.fire_breath_time > 0 {
                    self.lagged_dir += min(abs(angle_difference(self.dir, self.lagged_dir)),5) * sign(angle_difference(self.dir, self.lagged_dir));
                    self.lagged_dir %= 360;

                    ARI.fire_body_alpha = approach(ARI.fire_body_alpha, 1, 0.05);
                    ARI.fire_breath_time -= !non_cutscene_pause();

                    if self.par.blend == undefined {
                        self.par.blend = {
                            src_mode: bm_src_alpha,
                            dest_mode: bm_one,
                            color: make_color_rgb(player_data.fire_effect_body[0], player_data.fire_effect_body[1], player_data.fire_effect_body[2]),
                            alpha: fire_body_alpha
                        };
                    }
                    self.par.blend.alpha = fire_body_alpha;

                    if (array_length(self.fire_breath_effects) - 1) < player_data.fire_effect_count
                        && (ARI.fire_breath_time % player_data.fire_effect_fire_rate) == 0
                    {
                        var offset = ARI.fire_breath_time % 2 == 0 ? -5 : 5;
                        var x_offset = lengthdir_x(player_data.fire_effect_offset, self.lagged_dir + offset);
                        var y_offset = lengthdir_y(player_data.fire_effect_offset, self.lagged_dir + offset) - 12;

                        var fire_breath_id = instance_create_layer(
                            self.x + x_offset,
                            self.y + y_offset,
                            "Instances",
                            obj_fire_breath,
                            {
                                move_x: lengthdir_x(player_data.fire_effect_speed, self.lagged_dir + offset),
                                move_y: lengthdir_y(player_data.fire_effect_speed, self.lagged_dir + offset),
                                 x_offset,
                                 y_offset,
                                fire_breath_damage: player_data.fire_breath_damage,
                                is_last_poof: ARI.fire_breath_time == player_data.fire_effect_fire_rate,
                                make_poof_sound: (ARI.fire_breath_time % (player_data.fire_effect_fire_rate * player_data.fire_effect_vfx_ratio)) == 0,
                                owner: obj_ari,
                            }
                        );
                        array_push(fire_breath_effects, fire_breath_id.id);
                    }
                } else if ARI.fire_body_alpha >= 0 {
                    ARI.fire_body_alpha -= 0.05;
                    if self.par.blend != undefined {
                        self.par.blend.alpha = fire_body_alpha;
                        if ARI.fire_body_alpha <= 0  {
                            self.par.blend = undefined;
                        }
                    }
                }
            }

            function current_tool_effect(is_critical) {
                if ARI.status_effects.get_effect_value(StatusEffectId.IceSword, 0) > 0 {
                    return ToolEffect.Ice;
                }
                if ARI.status_effects.get_effect_value(StatusEffectId.VenomSword, 0) > 0 {
                    return ToolEffect.Venom;
                }
                if ARI.status_effects.get_effect_value(StatusEffectId.FireSword, 0) > 0 {
                    return ToolEffect.Fire;
                }

                if is_critical    {
                    return ToolEffect.Critical;
                }

                return ToolEffect.None;
            }


            self.fsm = AriFsm().spawn(
                MIST.running ? PlayerState.Cutscene : PlayerState.Default,
                self,
                MapWrap({
                    loot: undefined,
                    harvest_item: undefined,
                    pool_sister: undefined,
                    dive_icon: undefined,
                    in_water: undefined,
                    mount_jump_recover: false,
                    move: Vec2(0,0),
                    dir: 0,
                    spd: 0,

                    skip_combo0: false,
                    skip_combo1: false,

                    //
                    itinerary: undefined,
                    error_on_path_state: undefined,
                    last_move: undefined,
                    end_state: undefined,
                    facing_dir: undefined,
                    move_accel: undefined,

                    //
                    watch_target: undefined,
                })
            );
        },
        step: function() {
            //
            if non_cutscene_pause() {
                if self.can_set_depth_in_pause {
                    depth = get_instance_depth(y);
                }
                return;
            }

            self.fsm.step();

            self.receiver.x = self.x;
            self.receiver.y = self.y - 1;

            if self.dark_mines_light != undefined {
                self.dark_mines_light.x = self.x;
                self.dark_mines_light.y = self.y - 8;
            }
        },
        step_begin: function() {
            if non_cutscene_pause() {
                return;
            }

            self.fsm.new_tick();
        },
        step_end: function() {
            if !non_cutscene_pause() {
                self.fsm.end_step();
                ARI.update();

                if self.hurt_state != undefined && par.new_frame {
                    self.hurt_state += 1;

                    if self.par.blend == undefined {
                        self.end_hurt_state();
                    }

                    if self.hurt_state != undefined && self.hurt_state < array_length(self.hurt_colors) {
                        self.par.blend.color = self.hurt_colors[self.hurt_state];
                    } else {
                        self.hurt_state = undefined;
                        self.end_hurt_state();
                    }
                }
            }

            var y_off = MIST.is_running()
                && MIST.blackboard.get("offset_shadows_while_seated")
                && self.par.base_animation() == AnimationName.Sit
                    ? -4
                    : 0;

            var ratio = DISPLAY.asset_resize();
            var draw_x = floor(x * ratio) / ratio;
            var draw_y = floor((y + y_off) * ratio) / ratio;

            shadow_caster_set_position(self.shadow_caster, draw_x, draw_y);

            if PAUSE_STATUS != PauseStatus.EMPTY || (ARI.end_of_day_status == EndOfDayStatus.Died && self.fsm.current_state_id() == PlayerState.AnimateAndThen) {
                return;
            }

            var item = ARI.held_item();
            if item != undefined
                && ARI.fire_breath_time <= 0
                && ARI.held_animal_id == undefined
                && self.can_use_item_in_state()
            {
                switch item.prototype.use {
                    case ItemUse.Consume:
                        GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/eat", GlyphGuidePriority.Low);
                        break;
                    case ItemUse.Bait:
                        if (LOCATIONS[CURRENT_LOCATION_ID].outdoor || is_dungeon_room(room()))
                            && self.should_show_item_usage_ux()
                            && GRID.item_effects_node_at_cell((self.cell_select.x div 2) * 2, (self.cell_select.y div 2) * 2, item.prototype)
                        {
                            var input_to_use = BINDINGS.get_primary_binding(InputId.UseToolCharged) == undefined
                                ? InputId.UseToolRepeated
                                : InputId.UseToolCharged;
                            GLYPH_GUIDE.set_input(input_to_use, "misc_local/use", GlyphGuidePriority.Low);
                        }
                        break;
                    case ItemUse.ApplyOil:
                    case ItemUse.CrackEssenceStone:
                        GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/use", GlyphGuidePriority.Low);
                        break;
                    case ItemUse.LearnRecipe:
                        GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/learn", GlyphGuidePriority.Low);
                        break;
                    case ItemUse.PlaceObject:
                        //
                        if self.should_show_item_usage_ux() == false {
                            break;
                        }
                        if obj_tile_cursor.top_line_renderer.valid {
                            GLYPH_GUIDE.set_input(place_object_input_id(), "misc_local/place_furniture", GlyphGuidePriority.Low);
                        }
                        if array_length(NODE_PROTOTYPES[item.prototype.object].cardinals) > 1 {
                            GLYPH_GUIDE.set_input(InputId.RotateRight, "misc_local/rotate", GlyphGuidePriority.Low);
                        }
                        break;
                    case ItemUse.Blueprint:
                        //
                        if self.should_show_item_usage_ux()
                            && CURRENT_LOCATION_ID == LocationId.Farm
                            && can_write_blueprint(GRID, (self.cell_select.x div 2) * 2, (self.cell_select.y div 2) * 2, BLUEPRINT_PROTOTYPES[item.prototype.blueprint.blueprint])
                        {
                            //
                            GLYPH_GUIDE.set_input(place_object_input_id(), "misc_local/place_building", GlyphGuidePriority.Low);
                        }
                        break;
                    case ItemUse.PlaceTile:
                        //
                        if self.should_show_item_usage_ux() == false {
                            break;
                        }
                        if CURRENT_LOCATION_ID == LocationId.Farm {
                            GLYPH_GUIDE.set_input(place_object_input_id(), "misc_local/place_tile", GlyphGuidePriority.Low);
                        }
                        break;
                    case ItemUse.Wallpaper:
                        if is_home_location(CURRENT_LOCATION_ID) {
                            GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/apply_wallpaper", GlyphGuidePriority.Low);
                        }
                        break;
                    case ItemUse.Flooring:
                        if is_home_location(CURRENT_LOCATION_ID) {
                            GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/apply_flooring", GlyphGuidePriority.Low);
                        }
                        break;
                    case ItemUse.IdentifyItem:
                        GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/identify", GlyphGuidePriority.Low);
                        break;
                    case ItemUse.OpenChest:
                        GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/open", GlyphGuidePriority.Low);
                        break;
                    case ItemUse.PlantSeed:
                    case ItemUse.PlantSapling:
                    case ItemUse.PlantGrass:
                        if self.should_show_item_usage_ux()
                            && GRID.item_effects_node_at_cell((self.cell_select.x div 2) * 2, (self.cell_select.y div 2) * 2, item.prototype)
                        {
                            var input_to_use = BINDINGS.get_primary_binding(InputId.UseToolCharged) == undefined
                                ? InputId.UseToolRepeated
                                : InputId.UseToolCharged;
                            GLYPH_GUIDE.set_input(input_to_use, "misc_local/plant", GlyphGuidePriority.Low);
                        }
                        break;
                    case ItemUse.GainGold:
                        GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/collect", GlyphGuidePriority.Low);
                        break;
                    case ItemUse.ExpandInventory:
                        if item.prototype.new_inventory_size == ARI.inventory.size() + 10 {
                            GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/expand_inventory", GlyphGuidePriority.Low);
                        }
                        break;
                    case ItemUse.UnlockCosmetic:
                    case ItemUse.UnlockAnimalCosmetic:
                    case ItemUse.UnlockPetCosmetic:
                        GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/unlock_cosmetic", GlyphGuidePriority.Low);
                        break;
                    case ItemUse.CrackEgg:
                        GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/open_egg", GlyphGuidePriority.Low);
                        break;
                    case ItemUse.UnlockPetSkin:
                        GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/unlock_pet_skin", GlyphGuidePriority.Low);
                        break;
                    case ItemUse.UnlockDate:
                        GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/unlock_date", GlyphGuidePriority.Low);
                        break;
                    case ItemUse.UnlockSong:
                        GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/unlock_song", GlyphGuidePriority.Low);
                        break;
                    case ItemUse.Bomb:
                        GLYPH_GUIDE.set_input(InputId.Throw, "misc_local/throw", GlyphGuidePriority.Low);
                        break;
                }
            }

            //
            var buffered_inputs = [InputId.UseToolCharged, InputId.UseToolRepeated, InputId.Interact, InputId.Jump];
            for (var i = 0; i < array_length(buffered_inputs); i++) {
                var input = buffered_inputs[i];
                if INPUT.pressed(input) {
                    self.buffered_input = input;
                    self.buffered_tick = TICK;
                    break;
                }
            }

            self.ui_journal_request = false;
            self.ui_map_request = false;
            self.ui_spell_request = false;

            var took_damage = false;
            var electrocute_kind = undefined;
            var damage_was_acid = false;

            while ARI.get_health() > 0 && CLOCK.time < hours(26) {
                //
                var next_dmg = self.receiver.try_take_damage();
                if next_dmg == undefined || self.god_mode || ARI.fire_breath_time > 0 {
                    break;
                }

                //
                if chance_percent(ARI.perk_value(Perk.GuardiansShieldTwo)) && ARI.invulnerable_hits == 0 {
                    ARI.invulnerable_hits += 1;
                }

                if ARI.invulnerable_hits <= 0 {
                    took_damage = true;
                    var defense = ARI.get_damage_mitigation();
                    var final_dmg = min(-1, defense - next_dmg.tarball.damage);
                    var damage_was_acid = has_flag(next_dmg.tarball.flags, CombatFlag.Acid);
                    var is_dead = ARI.modify_health(final_dmg, damage_was_acid == false);

                    if next_dmg.tarball.stats_entry != undefined {
                        next_dmg.tarball.stats_entry.damage_dealt += final_dmg;
                        next_dmg.tarball.stats_entry.damage_dealt_count += 1;
                    }

                    spawn_damage_numbers(
                        self,
                        fiddle_get("player").damage_number_offset,
                        abs(final_dmg),
                        DamageFlag.NONE,
                        make_color_rgb(255, 97, 97),
                    );
                    set_rumble(RumbleKind.Hurt);

                    if is_dead {
                        TANGO.play("SoundEffects/Ari/TakeDamage", self.x, self.y);
                        break;
                    }

                    if damage_was_acid {
                        TANGO.play("SoundEffects/Ari/TakeTinyDamage");
                        self.receiver.current_iframes = 20; //
                    } else if has_flag(next_dmg.tarball.flags, CombatFlag.Electric) {
                        electrocute_kind = next_dmg.tarball.electrocute_kind;
                    }
                } else {
                    ARI.invulnerable_hits -= 1;

                    if ARI.invulnerable_hits <= 0 {
                        ARI.status_effects.cancel(StatusEffectId.GuardiansShield);
                        create_animation_effect_on_object(self,spr_fx_guardian_shield, -1);
                        self.receiver.current_iframes = max(self.receiver.current_iframes + 5, 5);
                        TANGO.play("SoundEffects/Ari/ShieldBreakWithKnockback");

                        //
                        TarballBuilder(x, y, 48, 48, 0, CombatTarget.Enemy)
                            .set_offset(-24, -36)
                            .set_parent(self)
                            .set_knockback(11, 13, 96)
                            .set_circle()
                            .set_timer(2)
                            .set_heavy(true)
                            .gen();
                    }
                }
            }

            if took_damage && self.should_die() == false && damage_was_acid == false {
                switch self.fsm.current_state_id() {
                    case PlayerState.Jump:
                        self.start_hurt_state();
                        self.set_animation(AnimationName.Hurt);
                        self.par.set_base_hold_on_last_frame();
                        break;
                    case PlayerState.Swim:
                        //
                        TANGO.play("SoundEffects/Ari/TakeDamage", x, y);
                        self.fsm.blackboard.insert("blinky_eyes", true);
                        self.fsm.blackboard.insert("end_state", PlayerState.Swim);
                        self.fsm.change_state(PlayerState.Hurt);
                        break;
                    case PlayerState.Tool:
                        //
                        if array_length(self.fsm.current_state().bug) == 0 {
                            self.fsm.change_state(PlayerState.Hurt);
                        }
                        break;
                    default:
                        //
                        var it = self.fsm.blackboard.get("items_thrown");
                        if it != undefined {
                            throw_item(self, it);
                            self.fsm.blackboard.remove("items_thrown")
                        }
                        if electrocute_kind != undefined {
                            self.fsm.blackboard.insert("electrocute_kind", electrocute_kind);
                            self.fsm.change_state(PlayerState.Electrocute);
                        } else {
                            self.fsm.change_state(PlayerState.Hurt);
                        }
                        break;
                }
            }

            //
            var purple_color = self.hurt_colors[0];
            var touching_receiver = false;
            with self.receiver {
                touching_receiver = overlap_instance_any(self.x, self.y, obj_hot_patch);
            }
            if touching_receiver {
                var first_burn = self.par.blend == undefined || self.par.blend.color != purple_color;
                if first_burn {
                    self.par.blend = {
                        src_mode: bm_src_alpha,
                        dest_mode: bm_one,
                        color: purple_color,
                        alpha: 1.0
                    };
                } else {
                    self.par.blend.alpha = sin(current_time() / 100) * 0.25 + 0.75;
                }
            } else if self.par.blend != undefined && self.par.blend.color == purple_color {
                self.par.blend.alpha = approach(self.par.blend.alpha, 0, 0.05);

                if self.par.blend.alpha == 0 {
                    self.par.blend = undefined;
                }
            }

            //
            if self.iframe_can_invisible {
                if self.receiver.current_iframes > 0 {
                    var player_data = fiddle_get("player");
                    var invisible = floor(self.receiver.current_iframes / player_data.hurtbox.iframe_blinker) % 2;

                    var new_alpha;
                    if !invisible && floor(self.receiver.current_iframes / player_data.hurtbox.iframe_blinker) == 0 {
                        new_alpha = 1.0;
                    } else {
                        new_alpha = player_data.hurtbox.ibounds[!invisible];
                    }

                    self.par.alpha = new_alpha;
                    shadow_caster_set_alpha(shadow_caster, self.par.alpha);
                } else {
                    self.par.alpha = 1.0;
                    shadow_caster_set_alpha(shadow_caster, self.par.alpha);
                    self.iframe_can_invisible = false;
                }
            }

            if has_flag(PAUSE_STATUS, PauseStatus.CUTSCENE) == false {
                //
                ds_list_clear(ARI.transparency_list);
                overlap_instance_list(self.x, self.y, obj_transparency_detector, ARI.transparency_list);

                for (var i = 0; i < ds_list_size(ARI.transparency_list); i++) {
                    var renderer = ARI.transparency_list[| i][$ "renderer"];
                    if renderer != undefined && instance_exists(renderer) {
                        renderer.translucent = true;
                    }

                    var asset = ARI.transparency_list[| i][$ "asset_object_target"];
                    if asset != undefined && instance_exists(asset) {
                        if asset[$ "translucent"] == undefined {
                            self.asset_objects_last_frame.push(asset);
                        }
                        asset.translucent = true;
                    }
                }

                //
                for (var i = self.asset_objects_last_frame.count() - 1; i >= 0; i--) {
                    var asset = self.asset_objects_last_frame.get(i);
                    if asset == undefined || instance_exists(asset) == false {
                        asset.translucent = undefined;
                        self.asset_objects_last_frame.remove(i);
                        continue;
                    }
                    if asset.translucent {
                        asset.image_alpha = approach(asset.image_alpha, 0.5, 0.05);
                        asset.translucent = false;
                    } else {
                        asset.image_alpha = approach(asset.image_alpha, 1.0, 0.05);
                        if asset.image_alpha >= 1.0 {
                            asset.translucent = undefined;
                            self.asset_objects_last_frame.remove(i);
                        }
                    }
                }
            }
        },
        draw: function() {
            //
            if ARI.end_of_day_sequence {
                shadow_caster_set_sprite(self.shadow_caster, undefined);
                return;
            }

            var anim_speed = self.par_anim_spd * (!non_cutscene_pause() || ANCHOR.get_menu(Menu.Textbox) != undefined);
            gpu_set_depth_sub_offset(64);
            fsm.draw();
            gpu_set_depth_sub_offset(0);

            var ratio = DISPLAY.asset_resize();
            var draw_x = floor((x + self.par_offset.x) * ratio) / ratio;
            var draw_y = floor((y + self.par_offset.y + z) * ratio) / ratio;
            self.par.draw(draw_x, draw_y, self.depth);
            self.par.animate(anim_speed);
            fsm.draw_after();

            if self.show_progress_bar || self.progress_bar_alpha > 0 {
                if self.show_progress_bar == false {
                    self.progress_bar_alpha -= 0.055;
                }
                draw_sprite_ext(
                    spr_hold_to_eat_bar,
                    0,
                    self.x + self.progress_bar_offset.x,
                    self.y + self.progress_bar_offset.y,
                    1,
                    1,
                    0,
                    c_white,
                    self.progress_bar_alpha
                );
                draw_sprite_ext(
                    spr_pixel,
                    0,
                    self.x + self.progress_bar_offset.x + 1,
                    self.y + self.progress_bar_offset.y + 1,
                    self.progress_bar_width,
                    2,
                    0,
                    self.progress_bar_color,
                    self.progress_bar_alpha
                );
            }
        },
        draw_end: function() {
            self.bark_emitter.on_draw();
        },
        animation_end: function() {
            self.fsm.anim_end();
        },
        destroy: function() {
            if instance_exists(obj_tile_cursor) {
                instance_destroy(obj_tile_cursor);
            }
        },
        cleanup: function() {
            self.meddler.release_reservations();
            SHADOW_GRID.caster_remove(self.shadow_caster);
        },
    }
);
