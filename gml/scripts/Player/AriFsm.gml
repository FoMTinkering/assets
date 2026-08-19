enum PlayerState {
    Default,
    Celebrate,
    Cutscene,
    Knockback,
    Jump,
    DownSmash,
    Hurt,
    Electrocute,
    AnimateAndThen,
    Swim,
    ThrowItem,

    HoldToUse,
    Tool,
    Sword,
    Fishing,

    WhirlPool,
    Spell,

    Diving,
    Underwater,
    Resurface,
    Pathfind,
    Dummy,

    MountDefault,
    MountJump,

    LEN,
}

enum SoundPriority {
    BadSfx,
    GoodSfx,
}


function AriFsm() {
    return StateMachineBuilder(PlayerState.LEN)
    .add_state(StateBuilder(PlayerState.Default)
        .create(function() {
            self.input = Vec2(0, 0);
            self.move = Vec2(0, 0);
            self.dir = 0;

            self.blink_rate = fiddle_deserialize_vec2(fiddle_get("misc/ari_animation/blink_rate"));
            self.idle_variance_rate = fiddle_deserialize_vec2(fiddle_get("misc/ari_animation/idle_variance_rate"));
            self.blink_timer = irandom_range(blink_rate.x, blink_rate.y) * 60;

            self.hold_checks = array_create(InputId.LEN, undefined);
            self.relative_cell_select = Vec2();
            self.in_idle_animation = false;
            self.delayed_audio = undefined;

            function drop_animal() {
                var animal_inst = undefined;

                if ARI.held_animal_id == PET_ID {
                    animal_inst = obj_pet;
                } else {
                    with obj_player_animal {
                        if self.me.idx == ARI.held_animal_id {
                            animal_inst = self.id;
                        }
                    }
                }
                assert_neq(animal_inst, undefined, "Held animal was not found!");
                ARI.held_animal_id = undefined;

                if GRID.node_collideable[GRID.node_index_for_room_position(owner.x, owner.y + 8)] == false {
                    animal_inst.x = owner.x;
                    animal_inst.y = owner.y + 8;
                } else {
                    animal_inst.x = owner.x;
                    animal_inst.y = owner.y;
                }

                animal_inst.put_down();
            }

            function reset_idle_timer() {
                self.idle_timer = 60 * irandom_range(self.idle_variance_rate.x, self.idle_variance_rate.y);
                self.stashed_cardinal = undefined;
                self.target_idle = AnimationName.Idle;
            }
        })
        .start(function() {
            self.item_cool_down = 0;
            self.owner.par.set_animation(AnimationName.Idle);

            ARI.check_for_held_items(self.owner);
            self.in_idle_animation = false;
            self.delayed_audio = undefined;

            self.saved_heading = undefined;
            reset_idle_timer();

            //
            //
            //
            self.furniture_heading = undefined;
        })
        .step(function() {
            if self.owner.should_faint() {
                return;
            }

            if self.owner.check_for_menu_opens() {
                reset_idle_timer();
                owner.set_animation(AnimationName.Idle);
                return;
            }

            if owner.should_die() {
                return;
            }
            self.owner.emit_fire();
            var ui_request = owner.ui_mount_request;
            owner.ui_mount_request = false;
            var big_chicken = self.blackboard.try_take("big_chicken", false);
            if (self.fsm.state_frame > 15 || big_chicken)
                && (ui_request || INPUT.pressed(InputId.Ride))
                && ARI.mount != undefined
                && ARI.held_animal_id == undefined
            {
                if !self.owner.can_mount() && !big_chicken {
                    create_notification("misc_local/you_cant_do_that_here");
                }  else {
                    TANGO.play("SoundEffects/Animals/SteedSummon");
                    create_animation_effect(owner.x + irandom(8), owner.y - irandom_range(4, 16), -10_000, spr_fx_poof1_essence_once);
                    create_animation_effect(owner.x - irandom(8), owner.y - irandom_range(4, 16), -10_000, spr_fx_poof1_essence_once);
                    create_animation_effect(owner.x + irandom(8), owner.y - irandom_range(4, 16), -10_000, spr_fx_poof1_essence_once);
                    create_animation_effect(owner.x - irandom(8), owner.y - irandom_range(4, 16), -10_000, spr_fx_poof1_essence_once);

                    owner.fsm.change_state(PlayerState.MountDefault);
                    return;
                }
            }

            if
                ARI.held_animal_id == undefined
                && ARI.pinned_spell != undefined
                && can_cast_spell(ARI.pinned_spell)
                && (INPUT.pressed(InputId.CastPinnedSpell) || self.owner.ui_spell_request)
            {
                self.fsm.blackboard.set("spell", ARI.pinned_spell);
                self.fsm.blackboard.set("hold_to_use", !self.owner.ui_spell_request);
                self.fsm.change_state(PlayerState.Spell);
                self.owner.ui_spell_request = false;
                return;
            }

            //
            if owner.quest_handle_queries() {
                return;
            }

            var preset_mod = 0;
            if INPUT.pressed(InputId.NextPreset) {
                preset_mod = 1;
            } else if INPUT.pressed(InputId.LastPreset) {
                preset_mod = -1;
            }
            var new_preset_index = wrap(ARI.preset_index_selected + preset_mod, ARI.presets.count());
            if new_preset_index != ARI.preset_index_selected && ARI.fire_breath_time <= 0 {

                if ARI.held_item() != undefined {
                    obj_ari.fsm.blackboard.set("unset_modifiers", true);
                }

                TANGO.play("SoundEffects/Inventory/SuccessfulCatchFishOrBug", self.owner.x, self.owner.y);
                obj_ari.change_preset(new_preset_index);
                obj_ari.fsm.change_state(PlayerState.AnimateAndThen);
                obj_ari.fsm.blackboard.set("animation", AnimationName.Celebrate);
                obj_ari.fsm.blackboard.set("hold_animation_forever", false);
                repeat 50 {
                    create_debris(
                        obj_ari.x + obj_ari.dust_particles.get_x_offset() + irandom_range(-10, 10),
                        obj_ari.y + obj_ari.dust_particles.get_y_offset() + irandom_range(-10, 10),
                        obj_ari.depth-1,
                        spr_part_rundirt,
                        obj_ari.dust_particles
                    );
                }
            }

            self.idle_timer -= 1;
            if self.idle_timer <= 0 {
                reset_idle_timer();

                if CLOCK.time >= NIGHT_TIME || ((ARI.get_stamina() / ARI.get_max_stamina()) < 0.25) {
                    self.stashed_cardinal = self.owner.cardinal;
                    self.target_idle = AnimationName.Tired;
                    self.owner.set_cardinal(Cardinal.South);
                    self.owner.par.unset_all_modifiers();
                    self.in_idle_animation = true;
                    self.delayed_audio = undefined;
                }
            }

            if self.owner.par.held_sprite != undefined {
                reset_idle_timer();
            }

            if self.in_idle_animation {
                if self.owner.par.is_broadcasting(BroadcastMessage.START_ACTION)
                    && self.delayed_audio != undefined
                {
                    TANGO.play(self.delayed_audio, owner.x, owner.y);
                    self.delayed_audio = undefined;
                }

                if self.owner.par.animation_complete && self.owner.par.base_animation() {
                    //
                    if self.stashed_cardinal != undefined {
                        self.owner.set_cardinal(self.stashed_cardinal);
                    }
                    self.target_idle = AnimationName.Idle;
                    reset_idle_timer();
                    self.in_idle_animation = false;
                    self.delayed_audio = false;
                }
            }

            //
            self.input.x = INPUT.check_value(InputId.Right) - INPUT.check_value(InputId.Left);
            self.input.y = INPUT.check_value(InputId.Down) - INPUT.check_value(InputId.Up);

            if ON_GAMEPAD {
                //
                //
                ARI.run_toggle = self.input.sqrd_magnitude() > 0.25;
            } else {
                //
                ARI.run_toggle = !INPUT.check(InputId.Walk);
            }

            var spd = ARI.get_move_speed();
            var sticky_patch = overlap_point(owner.x, owner.y, [obj_sticky_patch, obj_hot_patch]);
            if sticky_patch != undefined {

                if sticky_patch.object_index == obj_sticky_patch && ARI.perk_active(Perk.QuickFooted) {
                    if !sticky_patch.has_granted_speedup {
                        var time = CALENDAR.unified_time();
                        sticky_patch.has_granted_speedup = true;
                        ARI.status_effects.register(
                            StatusEffectId.SlimeDash,
                            ARI.perk_value(Perk.QuickFooted),
                            time,
                            time + minutes(fiddle_get("perks/quick_footed/duration_minutes")),
                        );
                        GAME_STATS.perks[$ perk_to_string(Perk.QuickFooted)] += 1;
                    }
                } else {
                    spd *= sticky_patch.slow;
                }
            }

            if INPUT.user_is_moving_mouse {
                owner.using_mouse = true;
            }

            //
            self.move.x = 0;
            self.move.y = 0;

            //
            if input.is_zero() == false {
                var dir = point_direction(0, 0, input.x, input.y);

                reset_idle_timer();

                if owner.using_mouse {
                    if self.saved_heading == undefined {
                        var current_pointing = abs(angle_difference(
                            (point_direction((obj_ari.x div 16) * 16, (obj_ari.y div 16) * 16, (mouse_x() div 16) * 16, (mouse_y() div 16) * 16) div 45) * 45,
                            dir
                        ));
                        if current_pointing >= 135 {
                            owner.using_mouse = false;
                        } else {
                            self.saved_heading = dir;
                        }
                    } else if dir != self.saved_heading {
                        self.saved_heading = undefined;
                        owner.using_mouse = false;
                    }

                    //
                    if ON_GAMEPAD {
                        owner.using_mouse = false;
                        self.saved_heading = undefined;
                    }
                }

                //
                self.move.x += lengthdir_x(spd, dir);
                self.move.y += lengthdir_y(spd, dir);

                if abs(self.move.x) < 0.0001 {
                    self.move.x = 0;
                }
                if abs(self.move.y) < 0.0001 {
                    self.move.y = 0;
                }

                self.owner.face_dir(dir);

                //
                obj_tile_cursor.state = TileCursorState.Hidden;
            }

            self.owner.collision_check(self.move);

            //
            if move.is_zero() {
                var success = owner.set_animation(self.target_idle);
                if success && self.target_idle == AnimationName.Tired {
                    self.delayed_audio = "SoundEffects/Ari/Yawn";
                }
            } else if ARI.run_toggle {
                owner.set_animation(AnimationName.Run);
            } else {
                owner.set_animation(AnimationName.Walk);
            }

            //
            ARI.check_for_held_items(owner);
            check_footsteps(self.owner, self.move, MountCycle.None);

            //
            move_ari(self.owner, self.move);

            var held_item = ARI.held_item();
            if held_item != undefined {
                if held_item.prototype.use == ItemUse.PlaceObject {
                    var proto = NODE_PROTOTYPES[held_item.prototype.object];
                    if INPUT.user_is_moving_mouse == false && (self.input.is_zero() == false || self.furniture_heading != self.owner.cardinal) {
                        //
                        self.furniture_heading = self.owner.cardinal;

                        var calc_rot = furniture_rotation_amount(owner.cardinal_placement, proto);
                        var rotation_matrix = furniture_calc_rot_to_rotation_matrix(calc_rot, proto);
                        var size = furniture_size(rotation_matrix, proto);
                        var rot_data = furniture_mask_prep_vecdata(proto.size, rotation_matrix);

                        self.relative_cell_select.x = 2.0;
                        self.relative_cell_select.y = 0.0;

                        switch self.furniture_heading {
                            case Cardinal.East:
                                self.relative_cell_select.x += 1 + size.x div 2;
                                break;
                            case Cardinal.West:
                                self.relative_cell_select.x += size.x div 2;
                                break;
                            case Cardinal.North:
                                self.relative_cell_select.x += size.y div 2;
                                break;
                            case Cardinal.South:
                                self.relative_cell_select.x += size.y div 2;
                                break;
                        }

                        //
                        var rotated_relative = relative_cell_select.rotate(cardinal_to_mat2(owner.cardinal));

                        var candidate_x = owner.x div 8;
                        var candidate_y = owner.y div 8;

                        var extrude_x = 0;
                        var extrude_y = 0;

                        var ni = GRID.try_node_index_for_cell(candidate_x + (size.x div 2) - 1, candidate_y);
                        var right_ok = ni != undefined && GRID.tile_flag_satisfies_node(ni, proto.rule_grid[# proto.size.x - 1, proto.size.y div 2]);

                        var ni = GRID.try_node_index_for_cell(candidate_x - (size.x div 2), candidate_y);
                        var left_ok = ni != undefined && GRID.tile_flag_satisfies_node(ni, proto.rule_grid[# 0, proto.size.y div 2]);

                        var ni = GRID.try_node_index_for_cell(candidate_x, candidate_y - (size.y div 2));
                        var top_ok = ni != undefined && GRID.tile_flag_satisfies_node(ni, proto.rule_grid[# proto.size.x div 2, 0]);

                        var ni = GRID.try_node_index_for_cell(candidate_x, candidate_y + (size.y div 2) - 1);
                        var bot_ok = ni != undefined && GRID.tile_flag_satisfies_node(ni, proto.rule_grid[# proto.size.x div 2, proto.size.y - 1]);

                        if right_ok == false && left_ok {
                            for (var j = (size.x div 2) - 2; j >= 0; j--) {
                                var ni = GRID.try_node_index_for_cell(candidate_x + j, candidate_y);
                                var right_ok = ni != undefined && GRID.tile_flag_satisfies_node(ni, proto.rule_grid[# proto.size.x - 1, proto.size.y div 2]);
                                if right_ok {
                                    extrude_x = j - ((size.x div 2) - 1);
                                    break;
                                }
                            }
                        }

                        if right_ok && left_ok == false {
                            for (var j = (size.x div 2) - 1; j >= 0; j--) {
                                var ni = GRID.try_node_index_for_cell(candidate_x - j, candidate_y);
                                var right_ok = ni != undefined && GRID.tile_flag_satisfies_node(ni, proto.rule_grid[# 0, proto.size.y div 2]);
                                if right_ok {
                                    extrude_x = (size.x div 2) - j;
                                    break;
                                }
                            }
                        }

                        if top_ok == false && bot_ok {
                            for (var j = (size.y div 2) - 1; j >= 0; j--) {
                                var ni = GRID.try_node_index_for_cell(candidate_x, candidate_y - j);
                                var right_ok = ni != undefined && GRID.tile_flag_satisfies_node(ni, proto.rule_grid[# proto.size.x div 2, 0]);
                                if right_ok {
                                    extrude_y = (size.y div 2) - j;
                                    break;
                                }
                            }
                        }

                        if top_ok && bot_ok == false {
                            for (var j = (size.y div 2) - 1; j >= 0; j--) {
                                var ni = GRID.try_node_index_for_cell(candidate_x, candidate_y + j);
                                var right_ok = ni != undefined && GRID.tile_flag_satisfies_node(ni, proto.rule_grid[# proto.size.x div 2, proto.size.y - 1]);
                                if right_ok {
                                    extrude_y = j - ((size.y div 2) - 1);
                                    break;
                                }
                            }
                        }

                        candidate_x += extrude_x;
                        candidate_y += extrude_y;

                        //
                        var x_output = rotated_relative.x;
                        var y_output = rotated_relative.y;

                        {
                            //
                            for (var j = abs(rotated_relative.x); j > 0; j--) {
                                var success = furniture_test_flag_mask(
                                    rot_data,
                                    GRID,
                                    candidate_x + j * sign(rotated_relative.x) - (size.x div 2),
                                    candidate_y - (size.y div 2),
                                    proto,
                                    rotation_matrix,
                                    true
                                );

                                if success {
                                    x_output = j * sign(rotated_relative.x);
                                    break;
                                }
                            }

                            var x_is_good = furniture_test_flag_mask(
                                rot_data,
                                GRID,
                                candidate_x + x_output - (size.x div 2),
                                candidate_y - (size.y div 2),
                                proto,
                                rotation_matrix,
                                true
                            );
                            if x_is_good == false {
                                //
                                for (var j = 0; j < abs(rotated_relative.x); j++) {
                                    var is_okay = furniture_test_flag_mask(
                                        rot_data,
                                        GRID,
                                        candidate_x - j * sign(rotated_relative.x) - (size.x div 2),
                                        candidate_y - (size.y div 2),
                                        proto,
                                        rotation_matrix,
                                        true
                                    );

                                    if is_okay {
                                        x_output = -j * sign(rotated_relative.x);
                                        break;
                                    }
                                }
                            }

                            //
                            for (var j = abs(rotated_relative.y); j > 0; j--) {
                                var success = furniture_test_flag_mask(
                                    rot_data,
                                    GRID,
                                    candidate_x + x_output - (size.x div 2),
                                    candidate_y + j * sign(rotated_relative.y) - (size.y div 2),
                                    proto,
                                    rotation_matrix,
                                    true
                                );

                                if success {
                                    y_output = j * sign(rotated_relative.y);
                                    break;
                                }
                            }

                            var y_is_good = furniture_test_flag_mask(
                                rot_data,
                                GRID,
                                candidate_x + x_output - (size.x div 2),
                                candidate_y + y_output - (size.y div 2),
                                proto,
                                rotation_matrix,
                                true
                            );
                            if y_is_good == false {
                                //
                                for (var j = 0; j < abs(rotated_relative.y); j++) {
                                    var is_okay = furniture_test_flag_mask(
                                        rot_data,
                                        GRID,
                                        candidate_x + x_output - (size.x div 2),
                                        candidate_y - j * sign(rotated_relative.y) - (size.y div 2),
                                        proto,
                                        rotation_matrix,
                                        true
                                    );

                                    if is_okay {
                                        y_output = -j * sign(rotated_relative.y);
                                        break;
                                    }
                                }
                            }
                        }

                        rotated_relative.x = x_output + extrude_x;
                        rotated_relative.y = y_output + extrude_y;

                        //
                        self.relative_cell_select = rotated_relative.rotate(cardinal_to_inverse_mat2(owner.cardinal));
                    }
                    var output = INPUT.pressed(InputId.RotateLeft) - INPUT.pressed(InputId.RotateRight);
                    if output != 0 && array_length(proto.cardinals) > 1 {
                        TANGO.play("SoundEffects/UI/UIRotateBuilding");
                    }
                    owner.cardinal_placement += output;
                } else if self.furniture_heading != undefined {
                    owner.cardinal_placement = 0;
                    for (var i = 0, c = array_length(self.hold_checks); i < c; i++) {
                        self.hold_checks[i] = undefined;
                    }

                    self.furniture_heading = undefined;
                    self.relative_cell_select.set_zero();
                }

                owner.update_cell_select(held_item.prototype, self.hold_checks, self.relative_cell_select);
            }

            //
            var can_check_interactable = true;
            if self.owner.check_pressed_input(InputId.Jump) {
                self.owner.check_jump(
                    self.input.x,
                    self.input.y,
                    ARI.run_toggle ? HUMAN_RUN_JUMP_DISTANCE : HUMAN_WALK_JUMP_DISTANCE,
                    false,
                );
                self.fsm.change_state(PlayerState.Jump);
                can_check_interactable = false;
            }

            update_depth_items(self.owner);
            var trans = owner.try_room_transition();
            if trans != undefined {
                owner.leave_room(trans.player_direction, HUMAN_WALK_SPEED * trans.spd_multiplier);
            }

            if can_check_interactable {
                var selection = find_nearest_interactable(self.owner.collision_list, self.owner);
                if selection != undefined {
                    var cback = selection.attempt_interact();
                    if cback != undefined {
                        cback();
                    }
                }
            }

            var holding_animal = ARI.held_animal_id != undefined;
            //
            if holding_animal {
                //
                GLYPH_GUIDE.set_input(InputId.Interact, "misc_local/put_down", GlyphGuidePriority.Normal);
                if self.owner.check_pressed_input(InputId.Interact) {
                    drop_animal();
                }
            }

            //
            var live_item = ARI.held_item();
            var pressed = false;

            if holding_animal == false && live_item != undefined {
                if live_item.can_use() {
                    switch live_item.prototype.use {
                        case ItemUse.UseTool:
                        case ItemUse.Attack:
                        case ItemUse.PlantSeed:
                        case ItemUse.PlantSapling:
                        case ItemUse.Bait:
                            pressed = INPUT.pressed(InputId.UseToolCharged) || INPUT.check(InputId.UseToolRepeated);
                            break;
                        case ItemUse.PlaceObject:
                        case ItemUse.PlaceTile:
                        case ItemUse.PlantGrass:
                        case ItemUse.Blueprint:
                            pressed = INPUT.pressed(place_object_input_id());
                            break;
                        default:
                            pressed = INPUT.pressed(InputId.Interact);
                            break;
                    }

                    if pressed && ARI.fire_breath_time <= 0 {
                        var use_item_output = use_item(live_item, self.owner.cell_select.clone());
                        switch use_item_output {
                            case UseItemSuccess.Remove:
                                ARI.inventory.slot(ARI.held_item_index).pop();
                                break;
                            case UseItemSuccess.RemoveLater:
                                obj_ari.fsm.blackboard.set("remove_item_at", ARI.held_item_index);
                                break;
                            case UseItemSuccess.None:
                            case undefined:
                                break;
                            default: impossible("unexpected output from `use_item`");
                        }
                    }
                }

                if self.owner.check_pressed_input(InputId.Throw)
                    && pressed == false
                    && !item_is_soulbound(live_item.item_id)
                    && ARI.fire_breath_time <= 0
                {
                    var items_thrown = undefined;
                    if live_item.prototype.use == ItemUse.Bomb {
                        items_thrown = List(ARI.inventory.slot(ARI.held_item_index).pop());
                    } else {
                        items_thrown = ARI.inventory.slot(ARI.held_item_index).drain();
                    }
                    self.blackboard.set("items_thrown", items_thrown);
                    self.fsm.change_state(PlayerState.ThrowItem);
                }
            }

            //
            self.blink_timer -= 1;

            if self.blink_timer <= 0 && self.target_idle == AnimationName.Idle {
                self.blink_timer = irandom_range(blink_rate.x, blink_rate.y) * 60;

                self.owner.set_animation(AnimationName.Blink);
            }
        })
        .stop(function() {
            //
            self.in_idle_animation = false;
            self.delayed_audio = undefined;

            ARI.check_for_held_items(owner);
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Spell)
        .create(function() {
            #macro CUTSCENE_SPELL_SIGNUM 999999

            function progress_bar_offset() {
                owner.progress_bar_offset.x = owner.par_offset.x
                    + owner.par.slots[AnimationSlot.HeldItem].base.current_frame.offset.x
                    + 9
                    - (sprite_get_width(spr_hold_to_eat_bar) div 2);

                owner.progress_bar_offset.y = owner.par_offset.y
                    + owner.par.slots[AnimationSlot.HeldItem].base.current_frame.offset.y
                    + 9
                    - (sprite_get_height(spr_hold_to_eat_bar) div 2);
            }
        })
        .start(function() {
            self.spell = self.blackboard.take("spell");
            self.owner.set_cardinal(Cardinal.South);
            self.owner.par.remove_held_sprite();
            self.owner.par.unset_all_modifiers();
            ARI.held_item_last_frame = undefined;

            self.owner.par.set_animation(AnimationName.SpellcastStart);
            self.sound = undefined;
            if !MIST.is_running() || MIST.blackboard.get("mute_spell") != true {
                self.sound = TANGO.play(self.spell == Spell.SacredLight ? "SoundEffects/Ari/MagicVoidLight" : "SoundEffects/Ari/MagicGeneric");
            }
            self.stop_sound = true;
            did_cast_spell = false;

            self.loop_timer = self.blackboard.try_take("loop_timer", 0);
            self.hold_to_use = self.blackboard.try_take("hold_to_use", false);

            if self.hold_to_use {
                owner.show_progress_bar = true;
                owner.progress_bar_color = make_color_rgb(233, 233, 233);
                owner.progress_bar_alpha = 1.0;
                owner.progress_bar_width = 0;
            }

            self.progress_bar_offset();

            if self.spell == Spell.Growth {
                obj_tile_cursor.select();
                obj_tile_cursor.complex_draw(true, (owner.x div 8) - 5, (owner.y div 8) - 5, 11, 11);
            }
        })
        .step(function() {
            //
            self.owner.emit_fire();

            self.progress_bar_offset();
            //
            if self.spell == Spell.Growth {
                var current_anim = self.owner.par.base_animation();

                if current_anim != AnimationName.SpellcastEnd {
                    //
                    var x_pos = ((obj_ari.x div 16) * 16) div 8;
                    var y_pos = ((obj_ari.y div 16) * 16) div 8;

                    obj_tile_cursor.select();
                    obj_tile_cursor.complex_draw(true, x_pos - 2, y_pos - 2, 7, 7);

                    var tag = irandom(I32_MAX);
                    for (var xx = x_pos - 2; xx < (x_pos + 4); xx++) {
                        for (var yy = y_pos - 2; yy < (y_pos + 4); yy++) {
                            var ni = GRID.try_node_index_for_cell(xx, yy);
                            if ni == undefined {
                                return;
                            }
                            var cat = object_id_to_object_category(GRID.node_object_id[ni]);
                            var should_highlight;
                            switch cat {
                                case ObjectCategory.Crop:
                                case ObjectCategory.Grass:
                                case ObjectCategory.Bush:
                                    should_highlight = GRID.node_parent[ni].last_update != tag;
                                    break;
                                case ObjectCategory.Tree:
                                    //
                                    //
                                    var center_stump_x = GRID.node_top_left_x[ni] + 3;
                                    var center_stump_y = GRID.node_top_left_y[ni] + 3;

                                    should_highlight = GRID.node_parent[ni].last_update != tag
                                        && center_stump_x == xx
                                        && center_stump_y == yy;
                                    break;
                                default:
                                    should_highlight = false;
                                    break;
                            }

                            if should_highlight {
                                GRID.node_parent[ni].last_update = tag;

                                var r = GRID.node_parent[ni].renderer;
                                if r == undefined || instance_exists(r) == false {
                                    continue;
                                }

                                r.highlight_interactable = true;
                                r.highlighter.override_strength = 0.10
                                    * sin(self.fsm.state_frame * pi / 26)
                                    + 0.20;
                            }
                        }
                    }
                }
            }

            var passes = self.owner.par.animation_complete;
            if self.owner.par.base_animation() == AnimationName.SpellcastLoop {
                self.loop_timer -= 1;
                passes = self.loop_timer <= 0 || MIST.blackboard.try_take("end_spell_cast") == true;
            }

            if passes {
                switch self.owner.par.base_animation() {
                    case AnimationName.SpellcastStart:
                        create_animation_effect(self.owner.x, self.owner.y, self.owner.depth + 1, spr_rainspell_dirt_continuous_dissipate_loop);
                        self.owner.par.set_animation(AnimationName.SpellcastLoop);
                        self.progress_bar_offset();

                        break;
                    case AnimationName.SpellcastLoop:
                        //
                        owner.progress_bar_color = make_color_rgb(251, 247, 247);
                        owner.show_progress_bar = false;

                        if self.spell != CUTSCENE_SPELL_SIGNUM {
                            cast_spell(self.spell);
                        }

                        if !MIST.is_running() {
                            ARI.modify_mana(-SPELLS[self.spell].cost);
                        }

                        did_cast_spell = true;
                        set_rumble(RumbleKind.SpellExecute);

                        create_animation_effect(self.owner.x, self.owner.y, self.owner.depth + 1, spr_rainspell_dirt_poof_back_dissipate_start);
                        create_animation_effect(self.owner.x, self.owner.y, self.owner.depth - 1, spr_rainspell_dirt_poof_front_dissipate_start);
                        self.owner.par.set_animation(AnimationName.SpellcastEnd);
                        break;

                    case AnimationName.SpellcastEnd:
                        owner.progress_bar_offset = fiddle_deserialize_vec2(
                            fiddle_get("player/progress_bar_normal_offset")
                        );
                        self.owner.par.set_animation(AnimationName.Idle);
                        self.fsm.change_state(self.blackboard.try_take("end_state", PlayerState.Default));
                        self.stop_sound = false;
                        break;

                    default:
                        //
                        self.fsm.change_state(PlayerState.Default);
                        if did_cast_spell == false && self.spell != CUTSCENE_SPELL_SIGNUM {
                            cast_spell(self.spell);
                            ARI.modify_mana(-SPELLS[self.spell].cost);
                        }
                        break;
                }
            }

            //
            self.vfx_sprite = undefined;
            self.vfx_frame = 0;

            switch self.owner.par.base_animation() {
                case AnimationName.SpellcastStart:
                    if self.spell == Spell.FireBreath {
                        self.vfx_sprite = spr_fx_player_spellcast_fire_spellcast_start_s;
                    } else {
                        self.vfx_sprite = spr_fx_player_spellcast_spellcast_start_s;
                    }

                    if self.hold_to_use && INPUT.check(InputId.CastPinnedSpell) == false {
                        self.owner.par.set_animation(AnimationName.Idle);
                        self.fsm.change_state(PlayerState.Default);
                    } else {
                        owner.progress_bar_width = clamp((self.fsm.state_frame div 7.8) - 1, 0, 10);
                    }
                    break;
                case AnimationName.SpellcastLoop:
                    if self.hold_to_use && INPUT.check(InputId.CastPinnedSpell) == false {
                        self.owner.par.set_animation(AnimationName.Idle);
                        self.fsm.change_state(PlayerState.Default);
                    } else {
                        owner.progress_bar_width = clamp((self.fsm.state_frame div 7.8) - 1, 0, 10);
                    }
                    if self.spell == Spell.FireBreath {
                        self.vfx_sprite = spr_fx_player_spellcast_fire_spellcast_loop_s;
                    } else {
                        self.vfx_sprite = spr_fx_player_spellcast_spellcast_loop_s;
                    }
                    break;
                case AnimationName.SpellcastEnd:
                    owner.progress_bar_width = 10;
                    if self.spell == Spell.FireBreath {
                        self.vfx_sprite = spr_fx_player_spellcast_fire_spellcast_end_s;
                    } else {
                        self.vfx_sprite = spr_fx_player_spellcast_spellcast_end_s;
                    }
                    break;
            }

            self.vfx_frame = self.owner.par.base_current_frame_index();
        })
        .draw_after(function() {
            //
            if self.vfx_sprite != undefined {
                with self.owner {
                    draw_sprite(other.vfx_sprite, other.vfx_frame, self.x, self.y + self.z);
                }
            }
        })
        .stop(function() {
            owner.show_progress_bar = false;
            owner.progress_bar_offset = fiddle_deserialize_vec2(
                fiddle_get("player/progress_bar_normal_offset")
            );

            if self.stop_sound && self.sound != undefined {
                TANGO.request_stop(self.sound);
            }
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Celebrate)
        .start(function() {
            self.in_water = GRID.node_terrain_kind[GRID.node_index_for_room_position(self.owner.x, self.owner.y)] == TerrainKind.Water;

            self.owner.set_cardinal(Cardinal.South);
            self.owner.par.unset_all_modifiers();
            self.owner.set_animation(self.in_water ? AnimationName.SwimCelebrate : AnimationName.Celebrate);

            self.celebration_data = self.blackboard.take("celebration_data");
            TANGO.play("SoundEffects/Inventory/SuccessfulCatchFishOrBug", self.owner.x, self.owner.y);
        })
        .step(function() {
            if self.owner.par.is_broadcasting(BroadcastMessage.START_ACTION) && self.celebration_data != undefined {
                //
                var item = is_array(self.celebration_data.item) ? self.celebration_data.item[0] : self.celebration_data.item;
                self.owner.par.set_held_sprite(item.get_ui_icon());
            }
        })
        .draw_after(function() {
            //
            if self.owner.par.animation_complete {
                //
                //
                //
                if CLOCK.time >= hours(26) {
                    ARI.end_of_day_status = undefined;
                    self.owner.should_faint(true);
                } else {
                    self.fsm.change_state(self.in_water ? PlayerState.Swim : PlayerState.Default);
                }
            }
        })
        .stop(function() {
            self.owner.par.remove_held_sprite();
            self.owner.par.set_base_loop();
            if is_array(self.celebration_data.item) {
                for (var i = 0, ic = array_length(self.celebration_data.item); i < ic; i++) {
                    ARI.give_item(self.celebration_data.item[i]);
                }
            } else {
                ARI.give_item(self.celebration_data.item);
            }

            if chance_percent(ARI.perk_value(Perk.LuckyHaul) + ARI.perk_value(Perk.LuckyHaulTwo)) && self.celebration_data.is_fish && self.celebration_data.fish_prototype.legendary == false {
                item_from_critical_poof(obj_ari.x, obj_ari.y, self.celebration_data.item);
            }

            if chance_percent(ARI.perk_value(Perk.AbyssalAscendence)) && self.celebration_data.is_fish {
                item_from_critical_poof(obj_ari.x, obj_ari.y, ItemId.AbyssalChest);
            }

            var card = self.blackboard.try_take("cardinal_before");
            if card != undefined {
                self.owner.set_cardinal(card);
            }
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Hurt)
        .create(function() {
            self.hurt_timer = fiddle_get("player/hurt_timer");
        })
        .start(function() {
            var blinky_eyes = self.blackboard.try_take("blinky_eyes", false);
            owner.par.unset_all_modifiers();
            owner.par.remove_held_sprite();
            owner.start_hurt_state();

            if blinky_eyes {
                owner.set_animation(AnimationName.HurtBlink);
            } else {
                owner.set_animation(AnimationName.Hurt);
            }

            self.animate_by_timer = blinky_eyes;
        })
        .draw_after(function() {
            var ender = false;
            if self.animate_by_timer {
                ender = fsm.state_frame >= self.hurt_timer;
            } else if self.owner.par.animation_complete {
                ender = true;
            }

            if ender {
                fsm.change_state(self.blackboard.try_take("end_state", PlayerState.Default));
            }
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Electrocute)
        .create(function() {
            var f = fiddle_get("player");
            self.hurt_timer = f.hurt_timer;

            self.yellow_outline = array_map(f.electrocute.yellow_outline, array_to_rgb);
            self.blue_outline = array_map(f.electrocute.blue_outline, array_to_rgb);

            self.yellow_blend = array_map(f.electrocute.yellow_blend, array_to_rgb);
            self.blue_blend = array_map(f.electrocute.blue_blend, array_to_rgb);
        })
        .start(function() {
            var electrocute_kind = self.blackboard.take("electrocute_kind");
            var static_effect = undefined;

            switch electrocute_kind {
                case ElectrocuteKind.Yellow:
                    self.electrocute_colors = self.yellow_blend;
                    self.colors = self.yellow_outline;
                    static_effect = spr_fx_monster_enchantern_static;
                    break;
                case ElectrocuteKind.Blue:
                    self.electrocute_colors = self.blue_blend;
                    self.colors = self.blue_outline;
                    static_effect = spr_fx_monster_enchantern_blue_static;
                    break;
                default: impossible();
            }

            self.electrocute_idx = 0;
            owner.par.blend = {
                src_mode: bm_src_alpha,
                dest_mode: bm_one,
                color: self.electrocute_colors[self.electrocute_idx],
                alpha: 1.0
            };

            if self.owner.par.base_animation() == AnimationName.Idle {
                owner.set_animation(AnimationName.Hurt);
            } else {
                owner.set_animation(AnimationName.HurtBlink);
            }

            //
            var item = ARI.held_item();
            if item != undefined && (item.prototype.use == ItemUse.UseTool || item.prototype.use == ItemUse.Attack) {
                self.owner.par.set_attachment(item_id_to_string(item.item_id));
            }
            owner.par.render_tool_effect = false;

            //
            owner.par_anim_spd = 0;
            owner.par.perform_outline = true;

            //
            self.static_effect = create_animation_effect(owner.x, owner.y, owner.depth + 1, static_effect);

            owner.save_iframes();

            TANGO.play("SoundEffects/Ari/TakeElectricDamage", owner.x, owner.y);
        })
        .draw_after(function() {
            //
            RUMBLE = undefined;
            if SETTINGS.get("rumble") {
                var rumble_amount = 0;
                if fsm.state_frame < (self.hurt_timer * 0.5) {
                    rumble_amount = sin(fsm.state_frame * pi / (self.hurt_timer * 0.5));
                } else {
                    rumble_amount = 1;
                }

                for (var gp_index = 0; gp_index < GAMEPADS_COUNT; gp_index++) {
                    if gamepad_is_connected(gp_index) {
                        gamepad_set_vibration(gp_index, rumble_amount, rumble_amount);
                    }
                }
            }

            if fsm.state_frame % 6 == 0 {
                self.electrocute_idx += 1;
                if owner.par.perform_outline == undefined {
                    //
                    owner.par.perform_outline = self.colors[(self.electrocute_idx div 2) % 2];
                } else {
                    owner.par.perform_outline = undefined;
                }

                if owner.par.blend != undefined {
                    if self.electrocute_idx >= array_length(self.electrocute_colors) {
                        owner.par.blend = undefined;
                    } else {
                        owner.par.blend.color = self.electrocute_colors[self.electrocute_idx];
                    }
                }
            }

            owner.par_offset.x = owner.default_par_offset.x + perlin_noise_get(0) * sign(perlin_noise_get(50) * 2.0 - 1.0);
            owner.par_offset.y = owner.default_par_offset.y + perlin_noise_get(1) * sign(perlin_noise_get(100) * 2.0 - 1.0);

            if fsm.state_frame >= self.hurt_timer {
                fsm.change_state(self.blackboard.try_take("end_state", PlayerState.Default));
            }
        })
        .stop(function() {
            owner.par_anim_spd = owner.default_par_anim_spd;
            owner.par.render_tool_effect = true;
            owner.par_offset.x = owner.default_par_offset.x;
            owner.par_offset.y = owner.default_par_offset.y;
            owner.par.perform_outline = undefined;

            if instance_exists(self.static_effect) {
                instance_destroy(self.static_effect);
            }

            if SETTINGS.get("rumble") {
                for (var gp_index = 0; gp_index < GAMEPADS_COUNT; gp_index++) {
                    if gamepad_is_connected(gp_index) {
                        gamepad_set_vibration(gp_index, 0, 0);
                    }
                }
            }

            owner.restore_iframes();
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Cutscene)
        .create(function() {
            self.watch_target = undefined;
            self.set_depth = true;
        })
        .start(function() {
            var do_not_set_to_idle = blackboard.try_take("do_not_set_idle", false);
            if do_not_set_to_idle == false {
                self.owner.par.set_animation(AnimationName.Idle);
            }
        })
        .step(function() {
            if self.set_depth {
                owner.depth = get_instance_depth(owner.y);
            }

            //
            if owner.breathe_fire_in_other_states {
                self.owner.emit_fire();
            }

            self.watch_target = self.blackboard.try_take("watch_target");
            if (self.watch_target != undefined && instance_exists(self.watch_target)) {
                var a = point_direction(
                    owner.x,
                    owner.y,
                    self.watch_target.x,
                    self.watch_target.y
                );
                self.owner.face_dir(a);
            }
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Pathfind)
        .create(function() {
            self.cardinality = Cardinal.South;
            self.move = Vec2();
            self.move_accel = Vec2(1, 1);

            //
            self.pathfinding_agent = new PathfindingAgent(undefined);

            self.pos = Vec2();
        })
        .start(function() {
            self.animation = self.fsm.blackboard.try_take("use_run_animation", false)
                ? AnimationName.Run
                : AnimationName.Walk;

            self.cardinality = self.owner.cardinal;
            var itinerary = self.blackboard.take("itinerary", "Ari did not have an itinerary set!");
            self.move_accel = self.blackboard.try_take("move_accel", self.move_accel);
            var snap_to_position = self.pathfinding_agent.set_path(
                itinerary,
                0,
            );
            self.owner.x = snap_to_position.x;
            self.owner.y = snap_to_position.y;

            self.pos.x = self.owner.x;
            self.pos.y = self.owner.y;
        })
        .stop(function() {
            self.blackboard.set("last_move", self.cardinality);
        })
        .step(function() {
            //
            if owner.breathe_fire_in_other_states {
                self.owner.emit_fire();
            }

            self.move.set_zero();

            //
            self.pathfinding_agent.move_along_path();
            var reached_end = pathfinding_util_move_along_path(self.owner, self.move_accel, self.move, self.pathfinding_agent, undefined);

            //
            if self.move.is_zero() == false {
                self.owner.set_cardinal(self.move.cardinality_heuristic());
            }

            if reached_end {
                owner.set_animation(AnimationName.Idle);
                self.fsm.change_state(self.blackboard.try_take("end_state", PlayerState.Cutscene));
            } else {
                owner.set_animation(self.animation);
            }

            check_footsteps(self.owner, self.move, MountCycle.None);

            //
            self.owner.x += self.move.x;
            self.owner.y += self.move.y;

            var ni = GRID.node_index_for_room_position(self.owner.x, self.owner.y);
            if GRID.node_object_id[ni] != undefined {
                GRID.node_parent[ni].renderer.collide(true, self.owner.cardinal);
            }

            update_depth_items(self.owner);
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Knockback)
        .start(function() {
            self.spd = self.blackboard.take("spd");
            self.move = Vec2();
            var item = ARI.held_item();
            if item != undefined && item.prototype.use == ItemUse.UseTool || item.prototype.use == ItemUse.Attack {
                self.owner.par.set_attachment(item_id_to_string(item.item_id));
                self.owner.par.tool_effect = owner.current_tool_effect(false);
            }
        })
        .step(function() {
            //
            self.move.x = self.spd.x;
            self.move.y = self.spd.y;

            self.spd.x *= 0.9;
            self.spd.y *= 0.9;

            self.owner.collision_check(self.move);
            move_ari(self.owner, self.move);
            update_depth_items(self.owner);

            if abs(self.spd.x) < 0.5 && abs(self.spd.y) < 0.5 {
                fsm.change_state(PlayerState.Default);
            }
        })
        .draw_after(function() {
            if self.owner.par.animation_complete {
                self.owner.par.set_animation(AnimationName.Idle);
            }
        })
        .stop(function() {
            self.owner.par.remove_attachment();
            self.owner.par.tool_effect = ToolEffect.None;
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Jump)
        .create(function() {
            function can_down_smash_on_pos(xx, yy) {
                //
                with owner {
                    if overlap_instance_any(xx, yy, par_monster) || overlap_instance_any(xx, yy, par_NPC) {
                        return false;
                    }
                }

                return owner.check_bbox_at_point(xx, yy, function(xx, yy) {
                    var ni = GRID.node_index_for_room_position(xx, yy);
                    if ni == undefined {
                        return false;
                    }

                    return GRID.node_collideable[ni] == false && GRID.node_terrain_kind[ni] != TerrainKind.Water;
                });
            }
        })
        .start(function() {
            //
            var ni = GRID.try_node_index_for_room_position(self.owner.x, self.owner.y);
            if ni != undefined && GRID.node_terrain_kind[ni] == TerrainKind.Water {
                TANGO.play("SoundEffects/Ari/ExitWater");
            } else {
                TANGO.play("SoundEffects/Ari/Jump");
            }

            self.owner.par.set_animation(AnimationName.Jump);
            self.jspd = self.owner.jump_data.spd;
            self.jump_spd = Vec2(
                (self.owner.jump_goal.x - self.owner.x) / self.owner.jump_data.frames,
                (self.owner.jump_goal.y - self.owner.y) / self.owner.jump_data.frames
            );
            self.dir = self.owner.dir;
            self.transition_on_finish = false;
            self.enter_jump_attack = false;
            //
            self.wants_down_attack = false;

            owner.receiver.status = set_flag(owner.receiver.status, ReceiverStatus.Aerial);
            self.move = Vec2();
            self.max_move_frames = self.owner.jump_data.frames;
            self.goal_x = self.owner.jump_goal.x;
            self.goal_y = self.owner.jump_goal.y;
        })
        .step(function() {
            self.owner.emit_fire();
            self.jspd += self.owner.jump_data.grv;
            self.owner.z += self.jspd;

            var ni = GRID.node_index_for_room_position(self.owner.x, self.owner.y);

            ARI.check_for_held_items(self.owner);

            if (self.owner.check_pressed_input(InputId.UseToolCharged) || self.owner.check_pressed_input(InputId.UseToolRepeated))
                && ARI.fire_breath_time <= 0
            {
                self.wants_down_attack = true;
            }

            if self.owner.z >= 0 {
                //
                self.jspd = 0;
                self.owner.z = 0;

                if self.transition_on_finish {
                    self.owner.leave_room(self.dir, HUMAN_WALK_SPEED);
                } else if GRID.node_terrain_kind[ni] == TerrainKind.Water {
                    //
                    self.fsm.change_state(PlayerState.Swim);
                    create_animation_effect(self.owner.x, self.owner.y, self.owner.depth + 8, spr_fx_water_player_splash);
                    TANGO.play("SoundEffects/Ari/EnterWater");
                    set_rumble(RumbleKind.ToolWeak);
                } else {
                    //
                    self.fsm.change_state(self.blackboard.try_take("end_state", PlayerState.Default));
                    self.owner.dust_particle_burst();

                    try_play_footstep_at_position(self.owner.x, self.owner.y, self.owner.cardinal, false, MountCycle.None, self.owner);
                    set_rumble(RumbleKind.ToolWeak);
                }
            } else if MIST.running == false && self.enter_jump_attack == false && self.wants_down_attack {
                //
                var live_item = ARI.held_item();
                if live_item != undefined && live_item.prototype.use == ItemUse.Attack && ARI.held_animal_id == undefined {
                    self.enter_jump_attack = true;
                    self.blackboard.set("downsmash_item", ARI.held_item());
                }
            }

            if self.fsm.state_frame < self.max_move_frames {
                self.move.x = self.jump_spd.x;
                self.move.y = self.jump_spd.y;

                //
                if self.fsm.state_frame == (self.max_move_frames - 1) {
                    self.move.x = 0;
                    self.move.y = 0;

                    owner.x = self.goal_x;
                    owner.y = self.goal_y;
                }
            } else {
                self.move.x = 0;
                self.move.y = 0;
            }

            move_ari(self.owner, self.move);
            update_depth_items(self.owner);

            //
            if self.transition_on_finish == false {
                var trans = self.owner.try_room_transition();
                if trans != undefined {
                    self.dir = trans.player_direction;
                    self.transition_on_finish = true;
                }
            }

            //
            if self.enter_jump_attack
                && ARI.perk_active(Perk.JumpAttack)
                && self.jspd > -1
                && self.can_down_smash_on_pos(self.owner.x, self.owner.y)
            {
                self.fsm.change_state(PlayerState.DownSmash);
            }
        })
        .stop(function() {
            if owner.par.base_animation() == AnimationName.Hurt {
                owner.par.set_base_loop();
                owner.end_hurt_state();
            }
            owner.receiver.status = remove_flag(owner.receiver.status, ReceiverStatus.Aerial);
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.DownSmash)
        .start(function() {
            TANGO.play("SoundEffects/Tools/SwordDownsmashStart", self.owner.x, self.owner.y);

            self.played_sound = false;
            self.tarball = undefined;

            self.jspd = 3.0;

            var live_item = self.blackboard.take("downsmash_item");
            self.damage = live_item != undefined ? live_item.prototype.damage : 0  + ARI.get_equipment_bonus_from(Infusion.Sharp, "amount");
            //
            //
            self.move = Vec2();
            self.waiting_on_message = true;

            //
            self.ground_pound_lock = false;

            //
            if self.owner.cardinal == Cardinal.North || self.owner.cardinal == Cardinal.South {
                self.owner.set_cardinal(Cardinal.East);
            }
            self.owner.par.unset_all_modifiers();
            self.owner.par.set_attachment(item_id_to_string(live_item.item_id))
            self.owner.set_animation(AnimationName.DownAttack);
            self.owner.par.tool_effect = owner.current_tool_effect(false);

            //
            create_animation_effect(self.owner.x, self.owner.y + 1 + owner.z, self.owner.depth - 1, spr_fx_attack_sword_ground_pound_shine);

            owner.receiver.status = set_flag(owner.receiver.status, ReceiverStatus.UntimedInvulnerable);

            //
            function on_hit() {
                ARI.modify_health(ARI.get_equipment_bonus_from(Infusion.Leeching, "amount"));

                if self.played_sound == false {
                    TANGO.play("SoundEffects/Tools/SwordDownsmashSucceed", self.owner.x, self.owner.y);
                    self.played_sound = true;
                }
            }
        })
        .step(function() {
            self.owner.emit_fire();
            if self.waiting_on_message {
                if self.owner.par.is_broadcasting(BroadcastMessage.START_ACTION) {
                    self.waiting_on_message = false;
                } else {
                    return;
                }
            }

            if self.owner.z < 0 {
                self.jspd += self.owner.jump_data.grv * 2.0;
                self.owner.z += self.jspd;
            } else {
                self.owner.z = 0;

                if self.ground_pound_lock == false {
                    //
                    self.ground_pound_lock = true;

                    CAMERA.add_trauma_sep(0.3, 0.4);

                    var back = undefined;
                    var front = undefined;
                    switch owner.current_tool_effect(false) {
                        case ToolEffect.None:
                        case ToolEffect.Critical: //
                            back = spr_fx_attack_sword_ground_pound_back;
                            front = spr_fx_attack_sword_ground_pound_front;
                            break;
                        case ToolEffect.Ice:
                            back = spr_fx_attack_sword_ground_pound_ice_back;
                            front = spr_fx_attack_sword_ground_pound_ice_front;
                            break;
                        case ToolEffect.Venom:
                            back = spr_fx_attack_sword_ground_pound_venom_back;
                            front = spr_fx_attack_sword_ground_pound_venom_front;
                            break;
                        case ToolEffect.Fire:
                            back = spr_fx_attack_sword_ground_pound_fire_back;
                            front = spr_fx_attack_sword_ground_pound_fire_front;
                            break;
                        default: impossible("unexpected effect_status: {}", effect_status);
                    }

                    create_animation_effect(self.owner.x, self.owner.y, get_floor_depth() - 1, back);
                    create_animation_effect(self.owner.x, self.owner.y, get_floor_depth() - 1, front);

                    if ARI.held_item() != undefined {
                        self.damage += ARI.held_item().prototype.damage;
                    }

                    //
                    self.damage *= ARI.status_effects.get_effect_value(StatusEffectId.FireSword);

                    self.tarball = TarballBuilder(
                            self.owner.x,
                            self.owner.y,
                            8,
                            8,
                            self.damage * !owner.wimp_mode,
                            CombatTarget.Enemy,
                        )
                        .set_circle()
                        .set_shield_break()
                        .set_fire_oil(ARI.status_effects.get_effect_value(StatusEffectId.FireSword, 0) > 0)
                        .set_venomous(ARI.status_effects.get_effect_value(StatusEffectId.VenomSword, 0) > 0)
                        .set_frozen(ARI.status_effects.get_effect_value(StatusEffectId.IceSword, 0) > 0)
                        .set_timer(15)
                        .set_override_pos_offset(8, 8)
                        .notify(self)
                        .gen();
                    self.tarball.original_x = self.owner.x;
                    self.tarball.original_y = self.owner.y;

                    //
                    self.tarball.x = self.owner.x - 4;
                    self.tarball.y = self.owner.y - 4;

                    self.tarball.callback_per_frame = method(self.tarball, function() {
                        var size = 8 * lerp(1, 8, 1 - (self.destruction_timer / 15));

                        x = self.original_x - size / 2;
                        y = self.original_y - size / 2;

                        self.dimensions.x = size;
                        self.dimensions.y = size;

                        return true;
                    });

                    if ARI.status_effects.get_effect_value(StatusEffectId.IceSword, 0) > 0 {
                        TANGO.play("SoundEffects/Tools/SwordDownsmashIceLayer");
                    }

                    if ARI.status_effects.get_effect_value(StatusEffectId.VenomSword, 0) > 0 {
                        TANGO.play("SoundEffects/Tools/SwordDownsmashPoisonLayer");
                    }

                    if ARI.status_effects.get_effect_value(StatusEffectId.FireSword, 0) > 0 {
                        TANGO.play("SoundEffects/Tools/SwordDownsmashFireLayer");
                    }
                } else if self.played_sound == false {
                    self.played_sound = true;
                    TANGO.play("SoundEffects/Tools/SwordDownsmashFail", self.owner.x, self.owner.y);
                    set_rumble(RumbleKind.DownsmashFail);
                }
            }

            update_depth_items(self.owner);
        })
        .draw_after(function() {
            if self.owner.par.animation_complete {
                self.fsm.change_state(PlayerState.Default);
            }
        })
        .stop(function() {
            if self.owner.receiver != undefined && instance_exists(self.owner.receiver) {
                ds_list_clear(self.owner.receiver.damaged);
            }
            //
            self.owner.y -= self.owner.z;
            self.owner.z = 0;

            //
            self.owner.buffered_input = undefined;
            self.owner.buffered_tick = undefined;

            owner.receiver.status = remove_flag(owner.receiver.status, ReceiverStatus.UntimedInvulnerable);

            //
            self.owner.par.tool_effect = ToolEffect.None;
            self.owner.par.remove_attachment();
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.AnimateAndThen)
        .start(function() {
            self.old_cardinality = self.owner.cardinal;
            //
            //
            self.change_cardinal = self.blackboard.try_take("only_south", true);
            if self.change_cardinal {
                self.owner.set_cardinal(Cardinal.South);
            }

            var animation = self.blackboard.take("animation");
            self.owner.par.set_animation(animation);

            var sfx = self.blackboard.try_take("sound");
            if sfx != undefined {
                TANGO.play(sfx, owner.x, owner.y);
            }

            self.hold_animation_forever = self.blackboard.try_take("hold_animation_forever", false);

            if self.hold_animation_forever {
                self.owner.par.set_base_hold_on_last_frame();
            }
            self.approach_z = self.blackboard.try_take("approach_z", false);
            self.execute_always = self.blackboard.try_take("execute_always", false);

            if self.blackboard.try_take("unset_modifiers", false) {
                owner.par.unset_all_modifiers();
                owner.par.remove_held_sprite();
                ARI.held_item_last_frame = undefined;
                ARI.held_animal_last_frame = undefined;
            }
        })
        .step(function() {
            update_depth_items(self.owner);
            if self.owner.par.is_broadcasting(BroadcastMessage.START_ACTION) || self.owner.par.is_modifier_broadcasting(BroadcastMessage.START_ACTION)
            {
                var cback = self.blackboard.try_take("on_start_action");
                if cback != undefined {
                    cback();
                }
            }

            if self.approach_z {
                owner.z = approach(owner.z, 0, 1);
            }
        })
        .draw_after(function() {
            if self.hold_animation_forever == false && self.owner.par.animation_complete {
                self.fsm.change_state(self.blackboard.try_take("end_state", PlayerState.Default));
            }
        })
        .stop(function() {
            if self.change_cardinal {
                self.owner.set_cardinal(self.old_cardinality);
            }
            self.owner.par.set_base_loop();

            if self.execute_always {
                var cback = self.blackboard.try_take("on_start_action");
                if cback != undefined {
                    cback();
                }
            }
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Swim)
        .create(function() {
            self.spd = 0;
            self.dir = 0;
            self.input = Vec2(0, 0);
            self.move = Vec2(0, 0);
            self.scare_rad = 32;
        })
        .start(function() {
            self.swim_sound = undefined;

            self.owner.par.set_animation(AnimationName.SwimIdle);

            //
            self.owner.par.remove_held_sprite();
            self.owner.par.unset_all_modifiers();

            shadow_caster_set_sprite(self.owner.shadow_caster, undefined);
        })
        .stop(function() {
            if self.swim_sound != undefined {
                self.swim_sound.force_stop();
            }
            //
            self.swim_sound = undefined;
            shadow_caster_set_sprite(self.owner.shadow_caster, spr_npc_shadow);
        })
        .step(function() {
            self.owner.emit_fire();
            if self.owner.check_for_menu_opens() || self.owner.should_faint() || self.owner.should_die() {
                return;
            }

            //
            self.input.x = INPUT.check_value(InputId.Right) - INPUT.check_value(InputId.Left);
            self.input.y = INPUT.check_value(InputId.Down) - INPUT.check_value(InputId.Up);

            if ON_GAMEPAD {
                //
                //
                ARI.run_toggle = self.input.sqrd_magnitude() > 0.25;
            } else {
                //
                ARI.run_toggle = !INPUT.check(InputId.Walk);
            }

            self.spd = ARI.get_swim_speed();

            //
            self.move.x = 0;
            self.move.y = 0;

            //
            ds_list_clear(self.owner.collision_list);
            overlap_point_list(self.owner.x, self.owner.y, obj_fish_school, self.owner.collision_list);
            for (var i = 0; i < ds_list_size(self.owner.collision_list); i++) {
                with self.owner.collision_list[| i] {
                    if !self.crashed {
                        if ARI.perk_active(Perk.SchoolCrasher) {
                            for (var j = 0; j < round(self.fish_in_school.count() / 2); j++) {
                                var fish = self.fish_in_school.get(j);
                                if fish.prototype.legendary == false {
                                    item_from_critical_poof(x, y, fish.item);
                                } else if ARI.legendary_fish_caught[CALENDAR.season()] == false {
                                    item_from_critical_poof(x, y, fish.item);
                                }
                            }
                            GAME_STATS.perks[$ perk_to_string(Perk.SchoolCrasher)] += 1;
                        }
                        self.fsm.change_state_instant(FishSchoolState.Disperse);
                        self.crashed = true;
                    }
                }
            }

            if self.owner.check_pressed_input(InputId.Jump) {
                self.owner.check_jump(
                    self.input.x,
                    self.input.y,
                    HUMAN_WATER_JUMP,
                    true,
                );
                if self.owner.jump_goal.is_zero() == false {
                    create_animation_effect(self.owner.x, self.owner.y, self.owner.depth + 7, spr_fx_reel_fish_splash_top);

                    self.fsm.change_state(PlayerState.Jump);
                }
            }

            if self.input.is_zero() {
                //
                if self.swim_sound != undefined {
                    self.swim_sound.request_stop();
                }
                self.swim_sound = undefined;

                self.owner.set_animation(AnimationName.SwimIdle);
            } else {
                //
                if self.swim_sound == undefined {
                    self.swim_sound = new SoundInstanceController(TANGO.play("SoundEffects/Ari/Swim"));
                }
                //
                if self.owner.par.animation_complete {
                    self.swim_sound = undefined;
                }
                self.owner.set_animation(AnimationName.Swim);

                self.dir = point_direction(0, 0, self.input.x, self.input.y);
                self.owner.face_dir(self.dir);

                self.move.x = lengthdir_x(self.spd, self.dir);
                self.move.y = lengthdir_y(self.spd, self.dir);

                self.owner.collision_check(self.move, true);
            }

            var selection = find_nearest_interactable(self.owner.collision_list, self.owner);
            if selection != undefined {
                var cback = selection.attempt_interact();
                if cback != undefined {
                    cback();
                }
            }

            check_footsteps(self.owner, self.move, MountCycle.None);
            //
            move_ari(self.owner, self.move);
            update_depth_items(self.owner);

            //
            var trans = self.owner.try_room_transition();
            if trans != undefined {
                self.owner.leave_room(trans.player_direction, HUMAN_WALK_SPEED * trans.spd_multiplier);
            }
            //
            var inst = collision_circle(self.owner.x, self.owner.y, self.scare_rad, obj_fishy);
            if(inst != undefined) {
                inst.trigger_escape(false, point_direction(self.owner.x, self.owner.y, inst.x, inst.y));
            }
            ds_list_clear(self.owner.collision_list);
            overlap_point_list(self.owner.x, self.owner.y, obj_fish_school, self.owner.collision_list);
            for (var i = 0; i < ds_list_size(self.owner.collision_list); i++) {
                with self.owner.collision_list[| i] {
                    if self.fsm.current_state_id() != FishSchoolState.Disperse {
                        self.fsm.change_state_instant(FishSchoolState.Disperse);
                    }
                }
            }
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Diving)
        .start(function() {
            self.owner.par.set_animation(AnimationName.Submerge);
            //
            self.owner.par.unset_all_modifiers();
            owner.receiver.status = set_flag(owner.receiver.status, ReceiverStatus.UntimedInvulnerable);
        })
        .draw_after(function() {
            if self.owner.par.animation_complete {
                self.fsm.change_state(PlayerState.Underwater);
            }
        })
        .stop(function() {
            owner.receiver.status = remove_flag(owner.receiver.status, ReceiverStatus.UntimedInvulnerable);
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Underwater)
        .start(function() {
            self.owner.par.unset_all_animations();
            self.dive_counter = self.blackboard.take("dive_counter");
            self.is_magnetic = true;
            shadow_caster_set_sprite(self.owner.shadow_caster, undefined);
            owner.receiver.status = set_flag(owner.receiver.status, ReceiverStatus.UntimedInvulnerable);
        })
        .step(function() {
            if self.is_magnetic {
                //
                var water_obj = self.blackboard.get("water_object");
                var spd = ARI.get_swim_speed() / 2;

                //
                self.owner.x = approach(self.owner.x, water_obj.x, spd);
                self.owner.y = approach(self.owner.y, water_obj.y, spd);

                self.is_magnetic = !(self.owner.x == water_obj.x && self.owner.y == water_obj.y);
            }

            self.dive_counter--;
            if self.dive_counter > 0 {
                return;
            }

            var on_completion_underwater_behavior = self.blackboard.take("underwater_behavior");
            switch on_completion_underwater_behavior {
                case DiveBehavior.Divespot:
                    var water_object = self.blackboard.take("water_object");
                    var celebration_data = water_object.dive_loot.get_celebration_data();
                    ARI.gain_xp(Skill.Fishing, XpValue.harvest_dive_spot);
                    TANGO.play("SoundEffects/Ari/DiveUp");
                    create_animation_effect(self.owner.x, self.owner.y, self.owner.depth + 8, spr_fx_water_player_splash);

                    try_gather_item_spawn(GatherDropChance.DiveSpot, obj_ari.x, obj_ari.y);

                    array_push(GAME_STATS.dives, {
                        item: celebration_data.item.pretty_print(),
                        day: total_days(),
                    });

                    self.owner.celebrate_loot(celebration_data);
                    instance_destroy(water_object);
                    break;
                case DiveBehavior.Whirlpool:
                    self.fsm.change_state(PlayerState.WhirlPool);
                    break;
            }
        })
        .stop(function() {
            shadow_caster_set_sprite(self.owner.shadow_caster, spr_npc_shadow);
            owner.receiver.status = remove_flag(owner.receiver.status, ReceiverStatus.UntimedInvulnerable);
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Resurface)
        .start(function() {
            self.owner.par.unset_all_modifiers();
            self.owner.par.set_animation(AnimationName.Emerge);
            owner.receiver.status = set_flag(owner.receiver.status, ReceiverStatus.UntimedInvulnerable);

            TANGO.play("SoundEffects/Ari/DiveUp");
            TANGO.play("SoundEffects/Entrances/WhirlpoolUp");
            self.owner.depth = get_instance_depth(self.owner.y);
        })
        .draw_after(function() {
            if self.owner.par.animation_complete {
                self.fsm.change_state(PlayerState.Swim);
            }
        })
        .stop(function() {
            owner.receiver.status = remove_flag(owner.receiver.status, ReceiverStatus.UntimedInvulnerable);
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.WhirlPool)
        .create(function() {
            self.pool_sister = undefined;
            self.pool_goal_pos = Vec2(0,0);
            self.pool_start_pos = Vec2(0,0);
        })
        .start(function() {
            self.owner.par.unset_all_animations();
            TANGO.play("SoundEffects/Entrances/WhirlpoolDown", self.owner.x, self.owner.y);

            self.pool_sister = self.blackboard.take("water_object").pool_sister;
            self.pool_goal_ease_x = new Ease(EaseId.QuadInOut, self.owner.x, self.pool_sister.x, 120);
            self.pool_goal_ease_y = new Ease(EaseId.QuadInOut, self.owner.y, self.pool_sister.y + 2, 120);
            self.whirlpool_counter = 0;

            owner.receiver.status = set_flag(owner.receiver.status, ReceiverStatus.UntimedInvulnerable);
            shadow_caster_set_sprite(self.owner.shadow_caster, undefined);

        })
        .step(function() {
            self.owner.x = self.pool_goal_ease_x.calculate_value(self.whirlpool_counter);
            self.owner.y = self.pool_goal_ease_y.calculate_value(self.whirlpool_counter);

            self.whirlpool_counter += 1;

            if point_distance(self.owner.x, self.owner.y, self.pool_sister.x, self.pool_sister.y + 2) < 1 {
                self.owner.x = self.pool_sister.x;
                self.owner.y = self.pool_sister.y;

                self.fsm.change_state(PlayerState.Resurface);
            }
        })
        .stop(function() {
            shadow_caster_set_sprite(self.owner.shadow_caster, spr_npc_shadow);
            owner.receiver.status = remove_flag(owner.receiver.status, ReceiverStatus.UntimedInvulnerable);
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.ThrowItem)
        .start(function() {
            self.items_thrown = self.blackboard.take("items_thrown");
            self.has_items = self.items_thrown.first() != undefined;
            self.do_not_make_item = self.blackboard.try_take("do_not_make_item", false);

            if self.has_items {
                self.owner.par.set_held_sprite(self.items_thrown.first().get_ui_icon());
            }
            self.owner.par.set_animation(AnimationName.Throw);

            self.item_has_been_thrown = false;
        })
        .step(function() {
            update_depth_items(self.owner);

            if self.item_has_been_thrown == false && self.owner.par.base_current_frame_index() == 2 {
                self.item_has_been_thrown = true;

                //
                if self.has_items == false {
                    return;
                }

                //
                if self.do_not_make_item {
                    self.owner.par.remove_held_sprite();
                    return;
                }
                throw_item(self.owner, self.items_thrown);
            }
        })
        .draw_after(function() {
            if self.owner.par.animation_complete {
                self.fsm.change_state(PlayerState.Default);
            }
        })
        .stop(function() {
            if self.item_has_been_thrown == false && self.has_items {
                throw_item(self.owner, self.items_thrown);
            }
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.HoldToUse)
        .create(function() {
            self.modifier = 1;
        })
        .start(function() {
            self.cached_cardinal = self.owner.cardinal;
            self.owner.set_cardinal(Cardinal.South);
            self.live_item = self.blackboard.take("live_item");

            self.owner.par.unset_all_modifiers();
            self.owner.par_anim_spd = 0;

            var held_spr_name = self.live_item.get_ui_icon();
            self.owner.par.set_held_sprite(held_spr_name);

            self.animation_name = AnimationName.Identify;
            self.modifier = 1;
            var sfx = "SoundEffects/UI/HoldActionShort";

            switch self.live_item.prototype.use {
                case ItemUse.Consume:
                    self.animation_name = AnimationName.Eat;
                    if ARI.perk_active(Perk.Snacktime) {
                        self.modifier = 0.5;
                        sfx = "SoundEffects/UI/HoldActionShorter";
                    }
                    break;
                case ItemUse.IdentifyItem:
                case ItemUse.OpenChest:
                case ItemUse.UnlockDate:
                case ItemUse.UnlockSong:
                    self.modifier = 3;
                    sfx = "SoundEffects/UI/HoldActionLong";
                    break;
                case ItemUse.UnlockCosmetic:
                case ItemUse.LearnRecipe:
                case ItemUse.UnlockAnimalCosmetic:
                case ItemUse.CrackEgg:
                case ItemUse.UnlockPetCosmetic:
                case ItemUse.UnlockPetSkin:
                    self.modifier = 2;
                    sfx = "SoundEffects/UI/HoldActionMedium";
                    break;
                case ItemUse.ExpandInventory:
                case ItemUse.CrackEssenceStone:
                case ItemUse.GainGold:
                case ItemUse.UnpackBundle:
                    self.modifier = 1;
                    sfx = "SoundEffects/UI/HoldActionShort";
                    break;
                case ItemUse.ApplyOil:
                case ItemUse.Wallpaper:
                case ItemUse.Flooring:
                    break;
                default: impossible("unexpected item_use `{}`", self.live_item.prototype.use);
            }
            self.execute_instantly = self.blackboard.try_take("execute_instantly", false);

            self.tango_sound = self.execute_instantly ? undefined : TANGO.play(sfx, owner.x, owner.y);
            self.owner.set_animation(self.animation_name);

            self.internal_state = HoldToUseStatus.Hold;
            self.did_action = false;

            self.hold_time = 40 * self.modifier;


            self.owner.show_progress_bar = true;
            self.owner.progress_bar_alpha = 1;

            if self.execute_instantly {
                self.internal_state = HoldToUseStatus.Animate;
                self.owner.par_anim_spd = self.owner.default_par_anim_spd;

                self.owner.show_progress_bar = false;
                self.owner.progress_bar_alpha = 0;
            }
        })
        .step(function() {
            switch self.internal_state {
                case HoldToUseStatus.Hold:
                    if fsm.state_frame >= 8 && INPUT.check(InputId.Interact) == false {
                        fsm.change_state(self.blackboard.try_take("end_state", PlayerState.Default));
                    }
                    if fsm.state_frame >= self.hold_time {
                        self.internal_state = HoldToUseStatus.Pause;
                    }
                    break;

                case HoldToUseStatus.Pause:
                    if fsm.state_frame >= (self.hold_time + 6) {
                        self.internal_state = HoldToUseStatus.Animate;
                        self.owner.par_anim_spd = self.owner.default_par_anim_spd;
                    }
                    break;

                case HoldToUseStatus.Animate:
                    break;
            }
        })
        .draw_after(function() {
            if self.internal_state == HoldToUseStatus.Animate
                && self.owner.par.is_broadcasting(BroadcastMessage.START_ACTION)
                && self.did_action == false
            {
                var slot = self.blackboard.try_take("remove_item_at");
                if slot != undefined {
                    ARI.inventory.slot(slot).pop();
                }

                var sfx = undefined;
                var exit_immediately = true;
                set_rumble(RumbleKind.ToolStrong);

                switch self.live_item.prototype.use {
                    case ItemUse.Consume:
                        var hp_gain = self.live_item.prototype.health_modifier;
                        var stam_gain = self.live_item.prototype.stamina_modifier;

                        exit_immediately = false;
                        var tool_sfx = fiddle_get("tool_fx");
                        if SETTINGS.get("sound_eating_drinking") {
                            sfx = self.live_item.prototype.tags.contains("drink_sound")
                                ? tool_sfx.food.drink_sfx
                                : tool_sfx.food.eat_sfx;

                            if stam_gain != 0 && hp_gain == 0 && self.live_item.prototype.max_stamina_modifier == 0 {
                                TANGO.play("SoundEffects/Ari/ReplenishOnlyStamina");
                            }
                        }

                        array_push(GAME_STATS.items_eaten, {
                            item: item_id_to_string(self.live_item.item_id),
                            day: total_days(),
                            hour: CLOCK.hour(),
                            minute: CLOCK.minute(),
                        });

                        //
                        if self.live_item.infusion != undefined {
                            var time = CALENDAR.unified_time();
                            switch self.live_item.infusion {
                                case Infusion.StackingSpeed:
                                    var effect = INFUSIONS.get(Infusion.StackingSpeed);
                                    ARI.status_effects.register(
                                        StatusEffectId.StackingSpeed,
                                        effect.amount,
                                        time,
                                        time + hours(effect.duration_hours),
                                        true
                                    );
                                    break;
                                case Infusion.Restorative:
                                    var len = INFUSIONS.get(Infusion.Restorative).duration_hours;
                                    ARI.status_effects.register(
                                        StatusEffectId.Restorative,
                                        undefined,
                                        time,
                                        time + hours(len),
                                    );
                                    break;
                                case Infusion.Speedy:
                                    var speedy = INFUSIONS.get(Infusion.Speedy);
                                    var len = speedy.duration_hours;
                                    var modifier = 1;
                                    var speed_percentage = speedy.percentage;
                                    if ARI.perk_active(Perk.CaffeineCrimes) {
                                        speed_percentage += speedy.percentage - 1;
                                        modifier = 2;
                                    }

                                    ARI.status_effects.register(
                                        StatusEffectId.Speedy,
                                        speed_percentage,
                                        time,
                                        time + hours(len * modifier),
                                    );
                                    break;
                                case Infusion.Fairy:
                                    ARI.status_effects.register(
                                        StatusEffectId.Fairy,
                                        undefined,
                                        time,
                                        I32_MAX,
                                    );
                                    break;
                                case Infusion.Magical:
                                    ARI.modify_mana(4);
                                    break;
                                case Infusion.VenomSword:
                                    var effect = INFUSIONS.get(Infusion.VenomSword);

                                    //
                                    ARI.status_effects.cancel(StatusEffectId.IceSword);
                                    ARI.status_effects.cancel(StatusEffectId.FireSword);

                                    ARI.status_effects.register(
                                        StatusEffectId.VenomSword,
                                        1,
                                        time,
                                        time + hours(effect.duration_hours),
                                    );

                                    break;
                                case Infusion.IceSword:
                                    var effect = INFUSIONS.get(Infusion.IceSword);

                                    //
                                    ARI.status_effects.cancel(StatusEffectId.FireSword);
                                    ARI.status_effects.cancel(StatusEffectId.VenomSword);

                                    ARI.status_effects.register(
                                        StatusEffectId.IceSword,
                                        1,
                                        time,
                                        time + hours(effect.duration_hours),
                                    );
                                    break;
                                case Infusion.FireSword:
                                    var effect = INFUSIONS.get(Infusion.FireSword);

                                    //
                                    ARI.status_effects.cancel(StatusEffectId.IceSword);
                                    ARI.status_effects.cancel(StatusEffectId.VenomSword);

                                    ARI.status_effects.register(
                                        StatusEffectId.FireSword,
                                        effect.percentage,
                                        time,
                                        time + hours(effect.duration_hours),
                                    );
                                    break;
                                default: break;
                            }
                        };

                        var skip_apply = hp_gain == 0 && stam_gain == 0;
                        if self.live_item.prototype.max_health_modifier != 0 {
                            if SETTINGS.get("sound_eating_drinking") {
                                TANGO.play("SoundEffects/Ari/EatHeartContainer");

                            }
                            skip_apply = true;
                            new_chain()
                                .append(LinkId.Timer, 30)
                                .append(LinkId.Function, function(live_item) {
                                    ARI.base_health += live_item.prototype.max_health_modifier;
                                    ANCHOR.get_menu(Menu.Vitals).set_max_health(ARI.base_health);
                                    ARI.modify_health(live_item.prototype.health_modifier, false);
                                }, [self.live_item])
                        }

                        if self.live_item.prototype.max_stamina_modifier != 0 {
                            if SETTINGS.get("sound_eating_drinking") {
                                TANGO.play("SoundEffects/Ari/DrinkStaminaPotion");
                            }
                            skip_apply = true;
                            new_chain()
                                .append(LinkId.Timer, 30)
                                .append(LinkId.Function, function(live_item) {
                                    ARI.base_stamina += live_item.prototype.max_stamina_modifier;
                                    ANCHOR.get_menu(Menu.Vitals).set_max_stamina(ARI.base_stamina);
                                    if ARI.get_stamina() < ARI.get_max_stamina() {
                                        ARI.modify_stamina(live_item.prototype.stamina_modifier, false);
                                    }
                                }, [self.live_item])
                        }

                        if self.live_item.prototype.mana_modifier != undefined {
                            if SETTINGS.get("sound_eating_drinking") {
                                TANGO.play("SoundEffects/Ari/DrinkManaPotion");
                            }
                            skip_apply = true;
                            ARI.set_mana(ARI.mana_current + self.live_item.prototype.mana_modifier);
                        }

                        if !skip_apply {
                            hp_gain = ARI.max_health_can_add(hp_gain);
                            stam_gain = ARI.max_stamina_can_add(stam_gain);

                            ARI.modify_health(hp_gain);

                            if hp_gain != 0 {
                                spawn_health_numbers(
                                    owner,
                                    fiddle_get("player").damage_number_offset,
                                    hp_gain,
                                    DamageNumber.Health,
                                );
                            }

                            if ARI.get_stamina() < ARI.get_max_stamina() && stam_gain != 0 {
                                ARI.modify_stamina(stam_gain);
                                spawn_health_numbers(
                                    owner,
                                    -(-fiddle_get("player").damage_number_offset + (hp_gain == 0 ? 0 : 10)),
                                    stam_gain,
                                    DamageNumber.Stamina,
                                );
                            }
                        }
                        break;
                    case ItemUse.ApplyOil:
                        if self.live_item.infusion != undefined {
                            var time = CALENDAR.unified_time();
                            var bark_icon_to_spawn = undefined;
                            var sfx = undefined;
                            switch self.live_item.infusion {
                                case Infusion.VenomSword:
                                    var effect = INFUSIONS.get(Infusion.VenomSword);

                                    //
                                    ARI.status_effects.cancel(StatusEffectId.IceSword);
                                    ARI.status_effects.cancel(StatusEffectId.FireSword);

                                    ARI.status_effects.register(
                                        StatusEffectId.VenomSword,
                                        1,
                                        time,
                                        time + hours(effect.duration_hours),
                                    );

                                    bark_icon_to_spawn = spr_ui_tooltip_infusion_icon_sword_venom;
                                    sfx = "SoundEffects/Tools/SwordDownsmashPoisonLayer";

                                    break;
                                case Infusion.IceSword:
                                    var effect = INFUSIONS.get(Infusion.IceSword);

                                    //
                                    ARI.status_effects.cancel(StatusEffectId.FireSword);
                                    ARI.status_effects.cancel(StatusEffectId.VenomSword);

                                    ARI.status_effects.register(
                                        StatusEffectId.IceSword,
                                        1,
                                        time,
                                        time + hours(effect.duration_hours),
                                    );

                                    bark_icon_to_spawn = spr_ui_tooltip_infusion_icon_sword_ice;
                                    sfx = "SoundEffects/Tools/SwordDownsmashIceLayer";

                                    break;
                                case Infusion.FireSword:
                                    var effect = INFUSIONS.get(Infusion.FireSword);

                                    //
                                    ARI.status_effects.cancel(StatusEffectId.IceSword);
                                    ARI.status_effects.cancel(StatusEffectId.VenomSword);

                                    ARI.status_effects.register(
                                        StatusEffectId.FireSword,
                                        effect.percentage,
                                        time,
                                        time + hours(effect.duration_hours),
                                    );

                                    bark_icon_to_spawn = spr_ui_tooltip_infusion_icon_sword_fire;
                                    sfx = "SoundEffects/Tools/SwordDownsmashFireLayer";
                                    break;
                            }

                            //
                            if bark_icon_to_spawn != undefined {
                                var rend = create_renderer_at_depth(0, undefined, undefined);
                                rend.draw_call = method(rend.draw_call, function() {
                                    if self.frame >= 30 {
                                        self.y -= 0.25;
                                        self.image_alpha -= 0.025;
                                    }

                                    self.frame += 1;

                                    if self.image_alpha <= 0.0 {
                                        instance_destroy(self);
                                    } else {
                                        draw_sprite_ext(
                                            self.bark_icon_to_spawn,
                                            0,
                                            self.x,
                                            self.y - 32,
                                            1,
                                            1,
                                            0,
                                            c_white,
                                            floor(self.image_alpha * 20.0) / 20.0, //
                                        );
                                    }
                                });
                                rend.x = owner.x - sprite_get_width(bark_icon_to_spawn) * 0.5;
                                rend.y = owner.y - sprite_get_height(bark_icon_to_spawn) * 0.5;
                                rend.depth = -100000;
                                rend.frame = 0;
                                rend.bark_icon_to_spawn = bark_icon_to_spawn;
                            }
                            if sfx != undefined {
                                TANGO.play(sfx, owner.x, owner.y);
                            }
                        }
                        break;
                    case ItemUse.IdentifyItem:
                        ARI.give_item(self.live_item.inner_item);
                        ARI.gain_xp(Skill.Archaeology, XpValue.identify_artifact);
                        if self.live_item.gold_to_gain != undefined {
                            ARI.modify_gold(self.live_item.gold_to_gain);
                            array_push(GAME_STATS.income, {
                                type: "identification",
                                amount: self.live_item.gold_to_gain,
                                day: total_days(),
                            });
                        }
                        break;
                    case ItemUse.OpenChest:
                        var table = undefined;
                        switch self.live_item.item_id {
                            case ItemId.TreasureBoxWood:
                                table = FISH_CHEST.wood;
                                break;

                            case ItemId.TreasureBoxCopper:
                                table = FISH_CHEST.copper;
                                break;

                            case ItemId.TreasureBoxSilver:
                                table = FISH_CHEST.silver;
                                break;

                            case ItemId.TreasureBoxGold:
                                table = FISH_CHEST.gold;
                                break;

                            case ItemId.AbyssalChest:
                                table = FISH_CHEST.abyss;
                                break;
                            default: impossible("unexpected `OpenChest` use in `{}`", self.live_item);
                        }

                        //
                        for (var attempt = 0; attempt < 100; attempt++) {
                            var item_data = table.items[irandom(array_length(table.items) - 1)];
                            switch item_data.chest_kind {
                                case FishChestItemKind.Item:
                                    drop_item(array_create(item_data.count, item_data.item), obj_ari.x, obj_ari.y)
                                    break;
                                case FishChestItemKind.Recipe:
                                    //
                                    if ari_has_recipe_anywhere(item_data.item) {
                                        continue;
                                    }
                                    drop_item(new LiveItem(ItemId.RecipeScroll, item_data.item), obj_ari.x, obj_ari.y);
                                    break;
                                case FishChestItemKind.Cosmetic:
                                    if ari_has_cosmetic_anywhere(item_data.cosmetic) {
                                        continue;
                                    }
                                    var lv = new LiveItem(ItemId.Cosmetic);
                                    lv.cosmetic = item_data.cosmetic;

                                    drop_item(lv, obj_ari.x, obj_ari.y);
                                    break;
                            }
                            break;
                        }

                        var gold_amount = irandom_range(table.gold[0], table.gold[1]);
                        gold_amount = (gold_amount div 25) * 25;

                        var hundos = gold_amount div 100;
                        for (var i = 0; i < hundos; i++) {
                            drop_item_stack(obj_ari.x, obj_ari.y, ListFromArray(array_create_ext(100, function(_) {
                                var li = new LiveItem(ItemId.LargeMobCoin);
                                li.auto_use = true;
                                li.gold_to_gain = 1;

                                return li;
                            })));
                        }

                        gold_amount -= hundos * 100;
                        var tfs = gold_amount div 25;
                        for (var i = 0; i < tfs; i++) {
                            drop_item_stack(obj_ari.x, obj_ari.y, ListFromArray(array_create_ext(25, function(_) {
                                var li = new LiveItem(ItemId.MediumMobCoin);
                                li.auto_use = true;
                                li.gold_to_gain = 1;

                                return li;
                            })));
                        }
                        break;
                    case ItemUse.UnlockCosmetic:
                        ARI.cosmetic_unlocks.insert(self.live_item.cosmetic);
                        new_item_popup(self.live_item);
                        break;
                    case ItemUse.UnlockAnimalCosmetic:
                        ARI.animal_cosmetic_unlocks[self.live_item.animal_cosmetic.animal]
                            .insert(self.live_item.animal_cosmetic.cosmetic);
                        new_item_popup(self.live_item);
                        break;
                    case ItemUse.CrackEgg:
                        var variants = ARI.animal_variant_unlocks[AnimalKind.Horse];
                        variants.insert("giant_chicken_gold");
                        variants.insert("giant_chicken_white");
                        var popup = new_item_popup(self.live_item, true);

                        rainbow_text(popup.title.parent, "misc_local/big_chicken_exclamation")
                            .set_align(Align.Center, Align.Middle);

                        popup.title.disable();

                        //
                        TANGO.play("SoundEffects/Animals/ChickenPositiveReact", owner.x, owner.y);
                        var emitters = array_create(50);
                        for (var i = 0; i < 50; i++) {
                            var snd;
                            switch i % 5 {
                                case 0: snd = "SoundEffects/Animals/ChickenBabyAmbient"; break;
                                case 1: snd = "SoundEffects/Animals/ChickenAAmbient"; break;
                                case 2: snd = "SoundEffects/Animals/ChickenBAmbient"; break;
                                case 3: snd = "SoundEffects/Animals/ChickenCAmbient"; break;
                                case 4: snd = "SoundEffects/Animals/ChickenDAmbient"; break;
                            }
                            array_push(emitters, new SoundInstanceController(TANGO.play(snd, owner.x, owner.y)));
                        }

                        new_chain().append(LinkId.Await, function(emitters) {
                            if !game_paused() {
                                if ARI.mount != undefined {
                                    ARI.mount.kind = AnimalKind.Horse;
                                    ARI.mount.prototype = ANIMAL_PROTOTYPES[AnimalKind.Horse];
                                    ARI.mount.kind = AnimalKind.Horse;
                                    ARI.mount.variant = "giant_chicken_white";
                                    ARI.mount.cosmetic = undefined;
                                    ARI.mount_mirroring_animal = undefined;
                                    obj_ari.ui_mount_request = true;
                                    self.blackboard.insert("big_chicken", true);
                                }

                                for (var i = 0; i < array_length(emitters); i++) {
                                    var emitter = emitters[i];
                                    if emitter != undefined {
                                        emitter.request_stop();
                                    }
                                }
                                return true;
                            } else if TICK % 45 == 0 {
                                TANGO.play("SoundEffects/Animals/ChickenPositiveReact", obj_ari.x, obj_ari.y);
                            }
                            return false;
                        }, [emitters]);

                        break;
                    case ItemUse.UnlockPetCosmetic:
                        array_push(ARI.pet_cosmetic_sets_unlocked, self.live_item.pet_cosmetic_set_name);
                        new_item_popup(self.live_item);
                        break;
                    case ItemUse.UnlockPetSkin:
                        array_push(ARI.pet_skin_unlocks, self.live_item.prototype.pet_skin_unlock);
                        new_item_popup(self.live_item);
                        break;
                    case ItemUse.UnlockDate:
                        ARI.date_unlocks[self.live_item.prototype.date_unlock] = true;
                        new_date_popup(self.live_item.prototype.date_unlock);
                        break;
                    case ItemUse.UnlockSong:
                        array_push(ARI.song_unlocks, self.live_item.prototype.song);
                        new_item_popup(self.live_item);
                        break;
                    case ItemUse.LearnRecipe:
                        if self.live_item.prototype.set_unlock != undefined {
                            for (var i = 0; i < ItemId.LEN; i++) {
                                var proto = ITEM_PROTOTYPES[i];
                                if proto.tags.contains(self.live_item.prototype.set_unlock) {
                                    ARI.unlock_recipe(i, false);
                                }
                            }
                            new_item_popup(self.live_item);
                        } else {
                            if ARI.recipe_unlocks[self.live_item.inner_item] {
                                create_notification("misc_local/known_recipe");
                            } else {
                                ARI.unlock_recipe(self.live_item.inner_item);
                            }
                        }

                        break;
                    case ItemUse.Wallpaper:
                        DECOR.apply_wallpaper(self.live_item.prototype.wallpaper, self.live_item.prototype.door_mold, true, self.live_item.infusion);
                        TANGO.play("SoundEffects/UI/UIPlaceBuilding");
                        break;
                    case ItemUse.Flooring:
                        DECOR.apply_flooring(self.live_item.prototype.flooring, true, self.live_item.infusion);
                        TANGO.play("SoundEffects/UI/UIPlaceBuilding");
                        break;
                    case ItemUse.GainGold:
                        sfx = "SoundEffects/Inventory/PurseOfTesserae";
                        ARI.modify_gold(self.live_item.gold_to_gain);
                        array_push(GAME_STATS.income, {
                            type: "purse",
                            amount: self.live_item.gold_to_gain,
                            day: total_days(),
                        });
                        break;
                    case ItemUse.ExpandInventory:
                        create_notification("misc_local/inventory_size_increased");
                        ARI.inventory.resize(self.live_item.prototype.new_inventory_size);
                        TANGO.play("SoundEffects/Inventory/PurseOfTesserae");
                        break;
                    case ItemUse.CrackEssenceStone:
                        TANGO.play("SoundEffects/Objects/ReabsorbEssenceCrystal");

                        //
                        var value = 0;
                        for (var i = 0; self.live_item.prototype.recipe.components.count(); i++) {
                            var component = self.live_item.prototype.recipe.components.get(i);
                            if component.type == RecipeComponentType.Essence {
                                value = component.count;
                                break;
                            }
                        }
                        ARI.modify_essence(value);
                        break;
                    case ItemUse.UnpackBundle:
                        for (var i = 0; i < array_length(self.live_item.prototype.item_bundle); i++) {
                            var entry = self.live_item.prototype.item_bundle[i];
                            ARI.give_item(entry[0], entry[1]);
                        }
                        break;
                }

                self.owner.par.remove_held_sprite();
                if sfx != undefined {
                    TANGO.play(sfx);
                }
                self.did_action = true;

                if exit_immediately {
                    self.fsm.change_state(self.blackboard.try_take("end_state", PlayerState.Default));
                    return;
                }
            }

            if self.did_action {
                if self.owner.par.animation_complete {
                    self.fsm.change_state(self.blackboard.try_take("end_state", PlayerState.Default));
                }

                owner.progress_bar_alpha -= 0.055;
            }

            owner.progress_bar_color = self.internal_state == HoldToUseStatus.Hold ? make_color_rgb(233, 233, 233) : make_color_rgb(251, 247, 247);
            owner.progress_bar_width = clamp((fsm.state_frame div (4 * self.modifier)) - 1, 0, 10);
        })
        .stop(function() {
            self.owner.par_anim_spd = self.owner.default_par_anim_spd;
            self.owner.show_progress_bar = false;

            if self.tango_sound != undefined {
                TANGO.request_stop(self.tango_sound);
            }

            //
            ARI.held_item_last_frame = undefined;
            ARI.held_animal_last_frame = undefined;
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Tool)
        .create(function() {
            function hoe(target_pos) {
                var success = hoe_node(GRID, target_pos.x, target_pos.y, self.tango_doppel);
                if success {
                    var stamina = abs(live_item.prototype.stamina_cost);

                    ARI.gain_essence(1, 8 * (target_pos.x + 1), 8 * (target_pos.y + 1));
                    ARI.modify_stamina(-1 * stamina);
                    ARI.gain_xp(Skill.Farming, XpValue.till_dirt);

                    var animation_effect = create_animation_effect(
                        target_pos.x * 8 + 8,
                        target_pos.y * 8 + 8,
                        self.owner.depth,
                        spr_fx_poof1_dirt_once
                    );

                    var critical = chance_percent(ARI.perk_value(Perk.NiceSwing));
                    if critical && abs(self.tool_charge_stamina_cumulative) < (self.tool_charge_stamina_pre + live_item.prototype.stamina_cost) {
                        GAME_STATS.perks[$ perk_to_string(Perk.NiceSwing)] += 1;
                        animation_effect.image_idx = 4;
                        animation_effect.stamina_return = abs(live_item.prototype.stamina_cost);
                        animation_effect.image_idx_func = method(animation_effect, function() {
                            create_critical_swing_poof(x, y, x, y, depth, self.stamina_return);
                        });
                        self.tool_charge_stamina_gain += live_item.prototype.stamina_cost;
                    }
                }
            }

            function axe(target_pos, doppel) {
                var success = chop_node(GRID, target_pos.x, target_pos.y, self.live_item.prototype, self.range_pattern == RangePattern.One ? 0 : -1, doppel);
                if success {
                    ARI.gain_essence(1, 8 * (target_pos.x + 1), 8 * (target_pos.y + 1));
                    ARI.modify_stamina(self.live_item.prototype.stamina_cost);

                    var _ispr = spr_impact_side;
                    var _l = 21;
                    var _ya = -6;
                    var _d = self.owner.depth - 2;

                    switch self.cached_cardinal {
                        case Cardinal.South:
                            _l = 8;
                            _ispr = spr_impact_vert;
                            _ya = 0
                            break;

                        case Cardinal.North:
                            _l = 14;
                            _d = obj_ari.depth + 1;
                            _ispr = spr_impact_vert;
                            _ya = 0;
                            break;
                    }

                    var in_angles = cardinal_to_angle(self.cached_cardinal);

                    var _impact = instance_create_depth(
                        obj_ari.x + lengthdir_x(_l, in_angles),
                        obj_ari.y + lengthdir_y(_l, in_angles) + _ya,
                        _d,
                        obj_impact
                    );

                    _impact.sprite_index = _ispr;
                    _impact.image_xscale = self.cached_cardinal == Cardinal.West ? -1 : 1;
                    _impact.image_yscale = self.cached_cardinal == Cardinal.North ? -1 : 1;
                }

            }

            function pick_axe(target_pos, doppel) {
                var pick_result = pick_node(GRID, target_pos.x, target_pos.y, self.live_item.prototype, self.range_pattern == RangePattern.One ? 0 : -1, undefined, doppel);
                if pick_result == PickResult.Nothing {
                    return;
                }

                if pick_result != PickResult.Furniture {
                    ARI.gain_essence(self.live_item.prototype.quality + 1, 8 * (target_pos.x + 1), 8 * (target_pos.y + 1));
                    ARI.modify_stamina(self.live_item.prototype.stamina_cost);
                }

                switch pick_result {
                    case PickResult.Rock:
                        //
                        break;
                    case PickResult.DigSite:
                        ARI.gain_xp(Skill.Archaeology, XpValue.break_dig_spot);
                        break;
                    case PickResult.Furniture:
                        //
                        break;
                }

                var spr = spr_impact_side;
                var length = 21;
                var y_offset = -6;
                var new_depth = self.owner.depth - 2;

                if cardinal_is_vertical(self.cached_cardinal) {
                    spr = spr_impact_vert;
                    y_offset = 0;

                    if self.cached_cardinal == Cardinal.North {
                        length = 14;
                        new_depth = obj_ari.depth+1;
                    } else {
                        length = 8;
                    }
                }

                var card_as_angles = cardinal_to_angle(self.cached_cardinal);

                var _impact = instance_create_depth(
                    obj_ari.x + lengthdir_x(length, card_as_angles),
                    obj_ari.y + lengthdir_y(length, card_as_angles) + y_offset,
                    new_depth,
                    obj_impact
                );
                _impact.sprite_index = spr;
                _impact.image_xscale = self.cached_cardinal == Cardinal.West ? -1 : 1;
            }

            function shovel(target_pos, doppel) {
                var dig_site_result = shovel_node(GRID, target_pos.x, target_pos.y, doppel);
                if has_flag(dig_site_result, ShovelResult.SHOW_POOF) {
                    create_animation_effect(
                        target_pos.x * 8 + 8,
                        target_pos.y * 8 + 8,
                        self.owner.depth,
                        spr_fx_poof1_dirt_once
                    );
                }

                if has_flag(dig_site_result, ShovelResult.GIVE_ESSENCE) {
                    ARI.gain_essence(self.live_item.prototype.quality + 1, 8 * (target_pos.x + 1), 8 * (target_pos.y + 1));
                    ARI.modify_stamina(self.live_item.prototype.stamina_cost);
                }

                if has_flag(dig_site_result, ShovelResult.GAIN_DIG_SITE_EXPERIENCE) {
                    ARI.gain_xp(Skill.Archaeology, XpValue.break_dig_spot);
                }
            }

            function watering_can(target_pos) {
                var live_item = self.live_item;
                var _water_quality = live_item.prototype.quality;
                var execute_instantly = self.execute_instantly;
                var cat = collision_rectangle(target_pos.x * 8, target_pos.y * 8, target_pos.x * 8 + 8, target_pos.y * 8 + 8, obj_monster_cat);

                if cat != undefined
                    && cat.fsm.current_state_id() != CatState.Petrified
                    && cat.config.water_hater
                {
                    cat.watered = true;
                }
                if can_water_node(GRID, GRID.node_index_for_cell(target_pos.x, target_pos.y)) {
                    var ni = GRID.node_index_for_cell(target_pos.x, target_pos.y);

                    var critical = chance_percent(ARI.perk_value(Perk.Bountiful));
                    var object_id = GRID.node_object_id[ni];

                    if object_id == ObjectId.MagicKey {
                        critical = false;
                    }

                    var animation_effect = create_animation_effect(target_pos.x * 8 + 8, target_pos.y * 8 + 8, owner.depth, spr_water_effect);
                    animation_effect.caller = self;

                    with animation_effect {
                        self.grid_x = target_pos.x;
                        self.grid_y = target_pos.y;
                        self.water_quality = _water_quality;
                        self.live_item = live_item;
                        self.object_id = object_id;
                        self.critical = critical;
                        var chain = new_chain();
                        if execute_instantly == false {
                            chain
                                .append(LinkId.Await, function() {
                                    return image_index >= 3;
                                });
                        }

                        chain.append(LinkId.Function, function() {
                            var success = water_node(GRID, self.grid_x, self.grid_y);
                            //
                            if success {
                                //
                                ARI.gain_essence(self.live_item.prototype.quality + 1, 8 * (self.grid_x + 1), 8 * (grid_y + 1));
                                ARI.modify_stamina(self.live_item.prototype.stamina_cost);
                                ARI.gain_xp(Skill.Farming, XpValue.water_dirt);
                                if self.critical && object_id_to_object_category(self.object_id) == ObjectCategory.Crop {
                                    item_from_critical_poof(self.grid_x * 8 + 8, self.grid_y * 8 + 8, string_to_item_id(format("seed_{}", object_id_to_string(self.object_id))));
                                    GAME_STATS.perks[$ perk_to_string(Perk.Bountiful)] += 1;
                                }
                            }
                        });

                        //
                        if execute_instantly == false {
                            chain
                                .append(LinkId.Await, function() {
                                    return image_index >= 8;
                                });
                        }

                        chain.append(LinkId.Function, function() {
                            if GRID.location_id == LocationId.Farm
                                && chance_percent(ARI.perk_value(Perk.Refreshing))
                                && abs(caller.tool_charge_stamina_cumulative) < (caller.tool_charge_stamina_pre + live_item.prototype.stamina_cost)
                            {
                                GAME_STATS.perks[$ perk_to_string(Perk.Refreshing)] += 1;
                                create_critical_swing_poof(x, y, 8 * (self.grid_x + 1), 8 * (self.grid_y + 1), depth, abs(live_item.prototype.stamina_cost));

                                caller.tool_charge_stamina_cumulative += live_item.prototype.stamina_cost;
                            }
                        });
                    };
                } else {
                    set_rumble(RumbleKind.ToolInvalid);
                }
            }

            function net(target_pos) {
                static NET_TARGETS = [obj_monster_clod_bomb, obj_monster_clod_projectile];
                //
                ds_list_clear(owner.collision_list);

                var count = collision_rectangle_list(
                    target_pos.x * 8,
                    target_pos.y * 8,
                    target_pos.x * 8 + 16,
                    target_pos.y * 8 + 16,
                    [obj_bug, obj_monster_clod_projectile, obj_monster_clod_bomb],
                    owner.collision_list,
                );

                for (var i = 0; i < count; i++) {
                    var inst = owner.collision_list[|i];
                    if ARI.get_stamina() - self.live_item.prototype.stamina_cost < 0 {
                        break;
                    }
                    switch inst.object_index {
                        case obj_monster_clod_projectile:
                        case obj_monster_clod_bomb:
                            inst.captured = true;
                            array_push(self.bug, new LiveItem(inst.object_index == obj_monster_clod_bomb ? ItemId.Bomb : ItemId.OreStone));
                            break;
                        default:
                            array_push(GAME_STATS.bugs_caught, {
                                bug: item_id_to_string(inst.item_id),
                                day: total_days(),
                            });
                            array_push(self.bug, new LiveItem(inst.item_id));
                    }
                    instance_destroy(inst);
                    ARI.modify_stamina(self.live_item.prototype.stamina_cost);
                }

                if count == 0 {
                    //
                    if collision_rectangle(target_pos.x * 8 - 1, target_pos.y * 8 - 1, target_pos.x * 8 + 9, target_pos.y * 8 + 9, obj_bug) != undefined {
                        TANGO.play("SoundEffects/Tools/BugNetSwingMiss");
                    } else {
                        TANGO.play("SoundEffects/Tools/AxeAndPickSwing");
                    }
                } else {
                    TANGO.play("SoundEffects/Tools/BugNetSwingSuccess");
                }
            }

            function sow(target_pos) {
                var seed_sfx = fiddle_get("tool_fx/seed");
                if can_plant_seed(target_pos.x, target_pos.y, self.live_item.prototype.crop_object) == false {
                    //
                    TANGO.play(
                        seed_sfx.invalid_sfx,
                        target_pos.x * 8,
                        target_pos.y * 8
                    );

                    if self.live_item.prototype.crop_object == ObjectId.MagicKey
                        && CURRENT_LOCATION_ID != LocationId.PriestessQuarters
                    {
                        play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.CannotPlantKey]);
                        self.fsm.change_state_instant(PlayerState.Default);
                    }
                } else {
                    var index = self.blackboard.get("remove_item_at");
                    if index == undefined {
                        return;
                    }

                    var val = ARI.inventory.slot(index).pop();
                    if val == undefined {
                        return;
                    }

                    TANGO.play(seed_sfx.plant_sfx, target_pos.x * 8, target_pos.y * 8);

                    //
                    var card_as_angles = cardinal_to_angle(self.cached_cardinal);
                    self.x_range = lengthdir_x(2, card_as_angles);
                    self.y_range = lengthdir_y(2, card_as_angles);
                    var _seed = create_animation_effect(
                        target_pos.x * 8 + 8,
                        target_pos.y * 8 + 8,
                        owner.depth - 1,
                        spr_seed_fx_strip7
                    );

                    _seed.image_idx = 3;

                    self.seed_position = target_pos.clone();
                    _seed.image_idx_func = function() {
                        var success = plant_seed(
                            GRID,
                            self.seed_position.x,
                            self.seed_position.y,
                            self.live_item.prototype.crop_object
                        );

                        if success != undefined {
                            ARI.gain_xp(Skill.Farming, XpValue.plant_seed);
                            ARI.modify_stamina(self.live_item.prototype.stamina_cost);

                            if chance_percent(ARI.perk_value(Perk.GreenThumb)) {
                                GAME_STATS.perks[$ perk_to_string(Perk.GreenThumb)] += 1;
                                var vfx = create_critical_swing_poof(
                                    self.seed_position.x * 8 + 8,
                                    self.seed_position.y * 8,
                                    self.seed_position.x,
                                    self.seed_position.y,
                                    self.owner.depth - 16,
                                    0,
                                    0,
                                    function() {
                                        var water = create_animation_effect(x, y + 8, self.depth, spr_water_effect);
                                        water.image_idx = 3;
                                        water.image_idx_func = function() {
                                            water_node(GRID, self.water_position.x, self.water_position.y);
                                        }
                                    }
                                );
                                vfx.water_position = self.seed_position;
                            }
                        }
                    }

                    //
                    _seed.image_idx_func();
                    _seed.image_idx_func = undefined;
                }
            }

            function sapling() {
                if self.live_item.prototype.use == ItemUse.PlantSapling {
                    var sapling_sfx = fiddle_get("tool_fx/sapling");
                    var success = plant_sapling(
                        GRID,
                        (self.target_pos.x div 2) * 2,
                        (self.target_pos.y div 2) * 2,
                        self.live_item.prototype.sapling
                    );

                    if success == undefined {
                        TANGO.play(sapling_sfx.invalid_sfx, self.target_pos.x * 8, self.target_pos.y * 8);
                    } else {
                        set_rumble(RumbleKind.ToolStrong);
                        ARI.inventory.slot(self.blackboard.take("remove_item_at")).pop();

                        //
                        create_animation_effect(
                            target_pos.x * 8 + 24,
                            target_pos.y * 8 + 24,
                            self.owner.depth,
                            spr_fx_poof1_dirt_once
                        );

                        TANGO.play(sapling_sfx.plant_sfx, self.target_pos.x * 8, self.target_pos.y * 8);
                        ARI.gain_xp(Skill.Farming, XpValue.plant_seed);
                    }
                } else {
                    var success = plant_grass(
                        GRID,
                        (self.target_pos.x div 2) * 2,
                        (self.target_pos.y div 2) * 2,
                        self.live_item.prototype.plant_grass
                    );

                    if success == false {
                        TANGO.play("SoundEffects/Tools/SeedUseInvalid", self.target_pos.x * 8, self.target_pos.y * 8);
                    } else {
                        set_rumble(RumbleKind.ToolWeak);
                        ARI.inventory.slot(self.blackboard.take("remove_item_at")).pop();

                        //
                        create_animation_effect(
                            target_pos.x * 8 + 8,
                            target_pos.y * 8 + 8,
                            self.owner.depth,
                            spr_fx_poof1_dirt_once
                        );

                        TANGO.play("SoundEffects/Tools/GrassPlantSuccess", self.target_pos.x * 8, self.target_pos.y * 8);
                        ARI.gain_xp(Skill.Farming, XpValue.plant_seed);
                    }
                }
            }
            self.tango_doppel = new TangoDoppel();
            self.tool_sfx = undefined;
            self.tool_charge = 0;
            self.tool_charge_released = false;
            self.tool_charge_stamina_cumulative = 0;
            self.tool_charge_stamina_pre = ARI.stamina_current;
            self.tool_charge_stamina_gain = 0;
            self.range_pattern = RangePattern.One;
            self.range_pattern_max = RangePattern.SixByNine;
            self.tool_set_animation = true
        })
        .start(function() {
            self.cached_cardinal = self.owner.cardinal;
            self.has_done = false;
            //
            self.tool_charge_stamina_cumulative = 0;
            self.tool_charge_stamina_gain = 0;
            self.tool_charge_stamina_pre = ARI.stamina_current;
            self.tool_charge = 0;
            self.tool_charge_released = false;
            self.tool_set_animation = true;
            //
            self.animation_name = self.blackboard.take("animation_name");
            self.live_item = self.blackboard.take("live_item");
            self.target_pos = self.blackboard.take("target_pos");
            //
            self.range_pattern = RangePattern.One;
            self.range_pattern_max = quality_to_range_pattern(self.live_item.prototype.quality);
            self.swing_override = undefined;
            self.owner.par.unset_all_modifiers();
            self.owner.par.set_animation(self.animation_name);

            self.care_about_objects_in_charged_cast = false;
            self.bug = [];

            var tool_sfx = fiddle_get("tool_fx");
            switch self.animation_name {
                case AnimationName.Net:
                    self.owner.par.set_attachment(item_id_to_string(self.live_item.item_id));
                    self.callback = net;

                    if owner.using_mouse {
                        self.owner.set_cardinal(mouse_cardinal());
                    }
                    self.has_done = false;

                    break;
                case AnimationName.Sow:
                    self.owner.par.set_held_sprite(
                        self.live_item.prototype.sow_sprite,
                        0,
                        undefined,
                        undefined,
                        undefined,
                    );
                    self.callback = sow;
                    self.range_pattern_max = RangePattern.One;

                    if ARI.perk_active(Perk.SuperbSower) {
                        if ARI.inventory.slot(ARI.held_item_index).count >= 54 {
                            self.range_pattern_max = RangePattern.SixByNine;
                        } else if ARI.inventory.slot(ARI.held_item_index).count >= 36 {
                            self.range_pattern_max = RangePattern.SixBySix;
                        } else if ARI.inventory.slot(ARI.held_item_index).count >= 18 {
                            self.range_pattern_max = RangePattern.ThreeBySix;
                        } else if ARI.inventory.slot(ARI.held_item_index).count >= 9 {
                            self.range_pattern_max = RangePattern.ThreeByThree;
                        } else if ARI.inventory.slot(ARI.held_item_index).count >= 3 {
                            self.range_pattern_max = RangePattern.OneByThree;
                        } else {
                            self.range_pattern_max = RangePattern.One;
                        }
                    }
                    self.care_about_objects_in_charged_cast = true;
                    break;
                case AnimationName.ChargeHoe:
                    self.owner.par.set_attachment(item_id_to_string(self.live_item.item_id));
                    self.callback = self.hoe;
                    self.tool_sfx = tool_sfx.hoe_shovel_swing_sfx;
                    self.owner.par.set_base_hold_on_last_frame();
                    break;
                case AnimationName.Till:
                    self.owner.par.set_attachment(item_id_to_string(self.live_item.item_id));
                    self.callback = self.hoe;
                    self.tool_sfx = tool_sfx.hoe_shovel_swing_sfx;
                    break;
                case AnimationName.Axe:
                    self.owner.par.set_attachment(item_id_to_string(self.live_item.item_id));
                    self.tool_sfx = tool_sfx.axe_pickaxe_swing_sfx;
                    if self.blackboard.try_take("is_pick_axe", false) {
                        self.callback = self.pick_axe;
                    } else {
                        self.callback = self.axe;
                    }
                    self.care_about_objects_in_charged_cast = true;
                    break;
                case AnimationName.Shovel:
                    self.tool_sfx = tool_sfx.hoe_shovel_swing_sfx;
                    self.owner.par.set_attachment(item_id_to_string(self.live_item.item_id));
                    self.callback = self.shovel;
                    break;
                case AnimationName.Water:
                    self.tool_sfx = tool_sfx.water.start_sfx;
                    self.owner.par.set_attachment(item_id_to_string(self.live_item.item_id));
                    self.callback = watering_can;
                    break;
                case AnimationName.Action:
                    self.callback = sapling;
                    self.care_about_objects_in_charged_cast = true;
                    break;
                default: impossible("we don't know how to handle what you're trying to do");
            }
            self.execute_instantly = self.blackboard.try_take("execute_instantly", false);
            if self.execute_instantly {
                self.callback(self.target_pos, self.tango_doppel);
                self.fsm.change_state(PlayerState.Default);
                self.has_done = true;
            }
            if self.animation_name == AnimationName.Action || self.range_pattern_max == RangePattern.One {
                self.tool_charge_released = true;
            }
        })
        .step(function() {
            update_depth_items(self.owner);
            if self.tool_charge_released == false {
                if self.fsm.state_frame > 15 {
                    obj_tile_cursor.is_charging = true;
                } else {
                    //
                    obj_tile_cursor.target_alpha = 0.75;
                }

                if INPUT.check(InputId.UseToolCharged) && CLOCK.time < hours(26) {
                    if self.animation_name != AnimationName.ChargeHoe && self.owner.par.is_broadcasting(BroadcastMessage.CHARGE_FRAME) {
                        self.owner.par_anim_spd = 0;
                    }
                    self.tool_charge += ARI.status_effects.get_effect_value(StatusEffectId.Speedy);
                    if self.tool_charge > fiddle_get("misc/tool_range_cycle_rate") {
                        self.tool_charge = 0;
                        self.range_pattern += 1;

                        //
                        if self.range_pattern > self.range_pattern_max {
                            self.range_pattern = RangePattern.One;
                        }
                        var stamina = abs(live_item.prototype.stamina_cost);
                        var can_afford = range_pattern_to_count(self.range_pattern) * stamina <= ARI.get_stamina();
                        if can_afford == false {
                            TANGO.play("SoundEffects/Ari/NotEnoughStamina");
                            self.range_pattern = RangePattern.One;
                        }

                        //
                        TANGO.play(range_pattern_to_blip_sound(self.range_pattern));
                        self.swing_override = range_pattern_to_swing_sound(self.range_pattern);
                    }
                } else {
                    if self.animation_name == AnimationName.ChargeHoe {
                        self.owner.par.set_animation(AnimationName.Till);
                    }
                    self.owner.par_anim_spd = self.owner.default_par_anim_spd;
                    self.tool_charge_released = true;
                }

                if obj_tile_cursor.is_charging
                    && (INPUT.pressed(InputId.Right)
                    || INPUT.pressed(InputId.Left)
                    || INPUT.pressed(InputId.Up)
                    || INPUT.pressed(InputId.Down))
                {
                    //
                    self.fsm.change_state(self.blackboard.try_take("end_state", PlayerState.Default));
                    obj_tile_cursor.state = TileCursorState.Hidden;
                    obj_tile_cursor.show_tile_cursor = false;
                    return;
                }
            }

            var targets = range_pattern_to_targets(self.target_pos.x, self.target_pos.y, self.range_pattern, self.owner.cardinal);

            //
            if self.tool_charge_released == false || self.has_done || self.owner.par.is_broadcasting(BroadcastMessage.START_ACTION) == false {
                //
                //
                if self.has_done == false && obj_tile_cursor.is_charging {
                    obj_tile_cursor.state = TileCursorState.Idle;
                    obj_tile_cursor.target_alpha = 0.75;
                    obj_tile_cursor.show_tile_cursor = true;

                    obj_tile_cursor.clear_charging_shadows();
                    for (var i = 0, c = targets.count(); i < c; i++) {
                        obj_tile_cursor.add_charging_shadow(targets.get(i), self.live_item.prototype);
                    }
                }

                return;
            }
            self.has_done = true;
            if self.tool_sfx != undefined {
                //
                if self.swing_override != undefined {
                    TANGO.play(self.swing_override);
                }

                TANGO.play(self.tool_sfx);
            }

            if matches(
                self.animation_name,
                AnimationName.Sow,
                AnimationName.ChargeHoe,
                AnimationName.Till,
                AnimationName.Axe,
                AnimationName.Shovel,
                AnimationName.Net,
                AnimationName.Water
            ) {
                obj_tile_cursor.state = TileCursorState.Hidden;
                obj_tile_cursor.target_alpha = 0.0;
            }

            var node_tick = irandom(I32_MAX);
            var lightweight_affects = self.live_item.prototype.tool_type != ToolType.Axe
                && self.live_item.prototype.tool_type != ToolType.PickAxe ? [] : undefined;

            for (var i = 0; i < targets.count(); i++) {
                var target = targets.get(i);
                var ni = GRID.try_node_index_for_cell(target.x, target.y);
                if ni == undefined {
                    continue;
                }

                if self.care_about_objects_in_charged_cast {
                    //
                    if object_id_to_object_category(GRID.node_object_id[ni]) == ObjectCategory.Tree
                        && ((target.x != GRID.node_parent[ni].top_left_x + 2 && target.x != GRID.node_parent[ni].top_left_x + 3)
                        || (target.y != GRID.node_parent[ni].top_left_y + 2 && target.y != GRID.node_parent[ni].top_left_y + 3))
                    {
                        continue;
                    }

                    if GRID.node_object_id[ni] != undefined && GRID.node_parent[ni].last_update == node_tick {
                        continue;
                    }
                }

                var stam_spent = ARI.stamina_current;
                var valid_target = false;

                switch self.live_item.prototype.tool_type {
                    case ToolType.Axe:
                        valid_target = can_chop_node(GRID, ni, self.live_item.prototype, target.x, target.y)
                            && GRID.node_parent[ni] != undefined
                            && GRID.node_parent[ni][$ "last_update"] != node_tick;
                        break;
                    case ToolType.PickAxe:
                        valid_target = can_pick_node(GRID, ni, self.live_item.prototype.quality)
                            && GRID.node_parent[ni] != undefined
                            && GRID.node_parent[ni][$ "last_update"] != node_tick;
                        break;
                    case ToolType.Hoe:
                        valid_target = can_hoe_node(GRID, ni)
                            && array_contains(lightweight_affects, GRID.try_node_index_for_cell((target.x div 2) * 2, (target.y div 2) * 2)) == false;
                        break;
                    case ToolType.Shovel:
                        valid_target = can_shovel_node(target.x, target.y)
                            && array_contains(lightweight_affects, GRID.try_node_index_for_cell((target.x div 2) * 2, (target.y div 2) * 2)) == false;
                        break;
                    case ToolType.WateringCan:
                        valid_target = can_water_node(GRID, ni)
                            && array_contains(lightweight_affects, GRID.try_node_index_for_cell((target.x div 2) * 2, (target.y div 2) * 2)) == false;
                        break;
                }

                if valid_target
                    && self.live_item.infusion == Infusion.Lightweight
                    && chance_percent(ARI.get_equipment_bonus_from(Infusion.Lightweight, "percentage"))
                {
                    create_critical_swing_poof(obj_ari.x, obj_ari.y, 8 * (target.x + 1), 8 * (target.y + 1), obj_ari.depth, abs(self.live_item.prototype.stamina_cost));

                    if self.live_item.prototype.tool_type == ToolType.Axe
                        || self.live_item.prototype.tool_type == ToolType.PickAxe
                    {
                        GRID.node_parent[ni].last_update = node_tick;
                    } else {
                        array_push(lightweight_affects, GRID.try_node_index_for_cell((target.x div 2) * 2, (target.y div 2) * 2));
                    }
                }

                self.callback(target, self.tango_doppel);
                stam_spent -= ARI.stamina_current;
                self.tool_charge_stamina_cumulative += stam_spent;
            }
            if self.tool_charge_stamina_cumulative != 0 {
                switch self.range_pattern {
                    case RangePattern.ThreeBySix:
                        TANGO.play("SoundEffects/Tools/ChargeStrike/ImpactThreeBySix")
                        break;
                    case RangePattern.SixBySix:
                        TANGO.play("SoundEffects/Tools/ChargeStrike/ImpactSixBySix")
                        break;
                    case RangePattern.SixByNine:
                        TANGO.play("SoundEffects/Tools/ChargeStrike/ImpactSixByNine")
                        break;
                }
            }
            tango_doppel.resolve();
        })
        .draw_after(function() {
            if self.tool_charge_released && self.owner.par.animation_complete {
                if self.animation_name == AnimationName.Net && array_length(self.bug) != 0 {
                    for (var i = 0, ic = array_length(self.bug); i < ic; i++) {
                        var item_id = self.bug[i].item_id;
                        if item_id != ItemId.OreStone && item_id != ItemId.Bomb {
                            try_gather_item_spawn(GatherDropChance.BugCaught, obj_ari.x, obj_ari.y);
                        }
                    }

                    obj_ari.celebrate_loot({
                        item: self.bug,
                        is_fish: false
                    });
                } else {
                    self.fsm.change_state(self.blackboard.try_take("end_state", PlayerState.Default));
                }
            }
        })
        .stop(function() {
            self.owner.par_anim_spd = self.owner.default_par_anim_spd;
            self.owner.par.remove_attachment();
            self.owner.par.remove_held_sprite();
            self.owner.par.set_base_loop();
            self.tool_sfx = undefined;
            self.bug = [];

            obj_tile_cursor.clear_charging_shadows();
            obj_tile_cursor.show_tile_cursor = false;
            obj_tile_cursor.is_charging = false;
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Fishing)
        .create(function() {
            function is_available() {
                return self.fsm.current_state_id() == FishingState.Wait;
            }

            self.internal_fsm_builder = StateMachineBuilder(FishingState.LEN)
                .add_state(StateBuilder(FishingState.Windup)
                    .start(function() {
                        self.indicator_menu = ANCHOR.spawn_menu(Menu.FishingIndicator);
                        self.bait = fsm.blackboard.try_take("bait");
                        self.bait_prototype = fsm.blackboard.try_take("bait_prototype");

                        if self.bait {
                            self.owner.owner.par.unset_all_modifiers();
                            self.owner.owner.set_animation(AnimationName.Throw);
                            self.owner.owner.par.set_held_sprite(self.bait_prototype.attract.hold_sprite);
                        } else {
                            self.owner.owner.set_animation(AnimationName.FishCast);
                        }

                        self.owner.owner.par_anim_spd = 0;
                        self.windup_tick = 0.1;
                        self.windup = 0;
                        self.windup_counter = 0;
                    })
                    .step(function() {
                        if INPUT.pressed(InputId.Interact) || INPUT.pressed(InputId.MenuBack) {
                            self.owner.owner.fsm.change_state(PlayerState.Default);
                            return;
                        }

                        if INPUT.check(InputId.UseToolCharged) || INPUT.check(InputId.UseToolRepeated) {
                            self.windup_counter++;
                            self.windup = self.windup_counter * self.windup_tick;
                            var _windup = min(ARI.held_item().prototype.range, floor(self.windup));

                            var cardinal_as_angles = cardinal_to_angle(self.owner.cached_cardinal);

                            FISHING.fishing_grid_position.x = FISHING.fishing_grid_position_start.x + lengthdir_x(_windup, cardinal_as_angles);
                            FISHING.fishing_grid_position.y = FISHING.fishing_grid_position_start.y + lengthdir_y(_windup, cardinal_as_angles);

                            //
                            CAMERA.follow_point(FISHING.fishing_grid_position.x * OBJECT_CELL_SIZE, FISHING.fishing_grid_position.y * OBJECT_CELL_SIZE);
                        } else {
                            var ni = GRID.try_node_index_for_cell(FISHING.fishing_grid_position.x, FISHING.fishing_grid_position.y);
                            if ni != undefined && GRID.node_terrain_kind[ni] == TerrainKind.Water && GRID.node_collideable[ni] == false {
                                self.fsm.change_state(FishingState.Cast);
                                fsm.blackboard.set("bait", self.bait);
                                fsm.blackboard.set("bait_prototype", self.bait_prototype);
                            } else {
                                self.owner.fsm.change_state(PlayerState.Default);
                            }
                        }
                    })
                    .stop(function() {
                        self.indicator_menu.release();
                        self.owner.owner.par_anim_spd = self.owner.owner.default_par_anim_spd;

                        if self.bait {
                            self.owner.owner.par.remove_held_sprite();
                            self.owner.owner.par.set_held_sprite(self.bait_prototype.attract.hold_sprite);
                        }

                    })
                    .spawn()
                )
                .add_state(StateBuilder(FishingState.Cast)
                    .start(function() {
                        var fishing_sfx = fiddle_get("tool_fx/fishing");
                        self.bait = fsm.blackboard.try_take("bait", false);
                        self.bait_prototype = fsm.blackboard.try_take("bait_prototype", undefined);

                        var bobber = instance_create_depth(obj_ari.x, obj_ari.y - 36, obj_ari.depth - 5, obj_bobber, {
                            bait_prototype: self.bait_prototype
                        });

                        if self.bait {
                            ARI.inventory.slot(ARI.held_item_index).pop();
                            bobber.sprite_index = self.bait_prototype.attract.spin_sprite;
                        } else {
                            self.owner.owner.par.set_base_hold_on_last_frame();
                            TANGO.play(fishing_sfx.casting_sfx, obj_ari.x, obj_ari.y);
                            self.bobber_fly_sound = new SoundInstanceController(TANGO.play(fishing_sfx.bobber_fly_sfx, obj_bobber.x, obj_bobber.y));
                        }

                        self.owner.owner.par.remove_held_sprite();
                    })
                    .step(function() {
                        //
                        if self.bait && self.owner.owner.par.animation_complete {
                            self.owner.owner.par.set_animation(AnimationName.Idle);
                        }
                        if obj_bobber.has_landed == false {
                            return;
                        }
                        self.fsm.change_state(FishingState.Wait);

                        //
                        var fishing_sfx = fiddle_get("tool_fx/fishing");
                        TANGO.play(fishing_sfx.bobber_land_sfx, obj_ari.x, obj_ari.y);
                        TANGO.play(fishing_sfx.splash_sfx, obj_ari.x, obj_ari.y);

                        if self.bait {
                            obj_ari.fsm.change_state(PlayerState.Default);
                        } else {
                            self.bobber_fly_sound.force_stop();
                        }
                    })
                    .stop(function() {
                        fsm.blackboard.set("bait", undefined);
                    })
                    .spawn()
                )
                .add_state(StateBuilder(FishingState.Wait)
                    .step(function() {
                        var bite_data = FISHING.get_subscriber(self.owner.owner.id);

                        if bite_data.kind == FishingEvent.Bite {
                            self.owner.owner.set_animation(AnimationName.FishBite, SetAnimationOverride.OverrideAnyway);
                            bite_data.kind = FishingEvent.None;
                        }

                        if INPUT.check(InputId.UseToolCharged) || INPUT.check(InputId.UseToolRepeated) {
                            var fishing_sfx = fiddle_get("tool_fx/fishing");
                            TANGO.play(fishing_sfx.retract_sfx, obj_bobber.x, obj_bobber.y);
                            if FISHING.bite_timer > 0 {
                                FISHING.notify(FishingEvent.Caught, FISHING.interested_fish);
                                self.fsm.blackboard.set("celebration_data", FISHING.interested_fish.get_celebration_data_essence_exp());
                                self.fsm.blackboard.set("essence_exp", FISHING.interested_fish.get_celebration_data_essence_exp());
                                self.fsm.blackboard.set("fish_size", FISHING.interested_fish.size);
                                FISHING.bite_timer = 0;
                            } else {
                                //
                                FISHING.notify(FishingEvent.Missed, FISHING.interested_fish);
                                game_stats_increment(GAME_STATS, "fish_missed");
                            }
                            self.fsm.change_state(FishingState.Reel);
                            obj_bobber.fsm.change_state(BobberState.Reel);
                        }
                    })
                    .stop(function() {
                    })
                    .spawn()
                )
                .add_state(StateBuilder(FishingState.Reel)
                    .start(function() {
                        self.owner.owner.set_animation(AnimationName.FishReel);
                    })
                    .stop(function() {
                        self.celebration_data = self.fsm.blackboard.try_take("celebration_data");
                        self.essence_exp = self.fsm.blackboard.try_take("essence_exp");
                        self.fish_size = self.fsm.blackboard.try_take("fish_size");

                        if self.celebration_data == undefined {
                            return;
                        }
                        var fishing_sfx = fiddle_get("tool_fx/fishing");
                        TANGO.play(fishing_sfx.pullout_sfx, obj_bobber.x, obj_bobber.y);

                        //
                        if self.essence_exp != undefined {
                            ARI.gain_essence(
                                essence_exp.essence,
                                obj_ari.x,
                                obj_ari.y
                            );
                            var mod_stamina = ARI.stamina_current;
                            ARI.modify_stamina(essence_exp.stamina_modifier);

                            if chance_percent(ARI.perk_value(Perk.CatchOfTheDay)) {
                                GAME_STATS.perks[$ perk_to_string(Perk.CatchOfTheDay)] += 1;
                                create_critical_swing_poof(obj_ari.x, obj_ari.y, obj_ari.x, obj_ari.y, -10000, mod_stamina - ARI.stamina_current, -1000);
                            }

                            var xp = fish_size_to_xp_value(self.fish_size);
                            ARI.gain_xp(Skill.Fishing, xp);
                        }

                        array_push(GAME_STATS.fish_caught, {
                            fish: self.celebration_data.item.pretty_print(),
                            day: total_days(),
                        });
                        obj_ari.celebrate_loot(self.celebration_data);
                        set_rumble(RumbleKind.FishingSuccess);

                        if chance_percent(fiddle_get("misc/lovely_seashell_chance") * 100)
                            && array_contains(ARI.date_unlocks, true)
                            && CURRENT_LOCATION_ID == LocationId.Beach
                            && !ARI.date_unlocks[Date.Beach]
                            && !any_item_matches(ItemId.LovelySeashell)
                        {
                            item_from_critical_poof(obj_ari.x, obj_ari.y, ItemId.LovelySeashell);
                        }

                        if FISHING.interested_fish.prototype.legendary {
                            //
                            with obj_fishy {
                                if self.fish_loot.prototype.item == FISHING.interested_fish.prototype.item {
                                    self.trigger_escape();
                                }
                            }

                            with obj_fish_school {
                                for (var i = 0; i < self.fish_in_school.count(); i++) {
                                    if self.fish_in_school.get(i).prototype.item == FISHING.interested_fish.prototype.item {
                                        self.fish_in_school.remove(i);
                                        i -= 1;
                                    }
                                }

                                if self.fish_in_school.count() == 0 {
                                    self.fsm.change_state_instant(FishSchoolState.Disperse);
                                    TANGO.play("SoundEffects/Animals/ManyFishRun", self.x, self.y);
                                }
                            }

                            ARI.legendary_fish_caught[CALENDAR.season()] = true;
                        }

                        try_gather_item_spawn(GatherDropChance.FishCaught, obj_ari.x, obj_ari.y);
                    })
                    .spawn()
                )
        })
        .start(function() {
            self.bait = self.blackboard.try_take("bait", false);
            self.bait_prototype = self.blackboard.try_take("bait_prototype", undefined);
            self.blackboard.set("cardinal_before", owner.cardinal);
            self.target_pos = self.blackboard.take("target_pos");
            self.live_item = self.blackboard.take("live_item");
            self.cached_cardinal = self.owner.cardinal;

            if self.bait == false {
                self.owner.par.set_attachment(item_id_to_string(self.live_item.item_id));
                var quality = self.live_item.prototype.quality;
                with obj_fishy {
                    self.fish_refresh_mask(quality);
                }
            }


            //
            FISHING.fishing_grid_position_start = self.target_pos.clone();
            FISHING.fishing_grid_position = self.target_pos.clone();

            var m = Map();
            m.set("bait", self.bait);
            m.set("bait_prototype", self.bait_prototype);
            m.set("remove_item_at", self.fsm.blackboard.try_take("remove_item_at"));
            self.internal_fsm = self.internal_fsm_builder
                .spawn(
                    FishingState.Windup,
                    self,
                    m,
                );
        })
        .step(function() {
            if self.owner.should_faint() {
                return;
            }

            self.internal_fsm.new_tick();
            self.internal_fsm.step();
        })
        .draw_after(function() {
            self.internal_fsm.draw_after();
        })
        .stop(function() {
            //
            //
            //
            //
            CAMERA.follow_instance(obj_ari);
            self.owner.par_anim_spd = self.owner.default_par_anim_spd;
            self.owner.par.set_base_loop();
            self.internal_fsm.destroy();
            self.internal_fsm.cleanup();
            FISHING.interested_fish = undefined;
            FISHING.missed = undefined;
            if instance_exists(obj_bobber) {
                instance_destroy(obj_bobber);
            }
        })
        .anim_end(function() {
            self.internal_fsm.anim_end();
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Sword)
        .create(function() {
            function next_swing() {
                self.combo_state += 1;
                self.blackboard.set("input_buffer", false);
                self.can_go_to_next_combo = false;
                self.input_buffer = false;

                var snd;
                var anim_name;

                switch self.combo_state {
                    case 0:
                        snd = "SoundEffects/Tools/SwordSwing";
                        anim_name = AnimationName.Combo1;
                        break;

                    case 1:
                        snd = "SoundEffects/Tools/SwordSwingComboLV2";
                        anim_name = AnimationName.Combo2;
                        break;

                    case 2:
                        snd = "SoundEffects/Tools/SwordSwingComboLV3";
                        anim_name = AnimationName.Combo3;
                        self.max_push_spd = 2.5;
                        break;
                    default: return;
                }

                self.is_critical = is_dungeon_room(room())
                    && (chance_percent(ARI.perk_value(Perk.TrueStrike) + ARI.perk_value(Perk.TrueStrikeTwo)) || owner.crit);
                self.can_make_tarball = true;
                self.cancel_tarball();
                self.max_push_spd = 1.75;

                switch self.cached_cardinal {
                    case Cardinal.East:
                        self.push_spd.x = self.max_push_spd;
                        break;
                    case Cardinal.North:
                        self.push_spd.y = -self.max_push_spd;
                        break;
                    case Cardinal.West:
                        self.push_spd.x = -self.max_push_spd;
                        break;
                    case Cardinal.South:
                        self.push_spd.y = self.max_push_spd;
                        break;
                }

                //
                TANGO.play(snd);

                var effect_status = owner.current_tool_effect(self.is_critical);

                var extra_snd = undefined;
                switch effect_status {
                    case ToolEffect.Ice:
                        extra_snd = "SoundEffects/Tools/SwordSwingIceLayer";
                        break;
                    case ToolEffect.Venom:
                        extra_snd = "SoundEffects/Tools/SwordSwingPoisonLayer";
                        break;
                    case ToolEffect.Fire:
                        extra_snd = "SoundEffects/Tools/SwordSwingFireLayer";
                        break;
                    case ToolEffect.Critical:
                        extra_snd = "SoundEffects/Ari/Crit";
                        break;
                }
                if extra_snd != undefined {
                    TANGO.play(extra_snd);
                }

                self.owner.set_animation(anim_name);
                self.owner.par.tool_effect = effect_status;
            }

            function on_hit(rcvr) {
                ARI.modify_health(ARI.get_equipment_bonus_from(Infusion.Leeching, "amount"));

                CAMERA.add_trauma(0.2);
                var dir = point_direction(owner.x, owner.y, rcvr.parent_id.x, rcvr.parent_id.y);
                var dist;
                with owner {
                    dist = distance_to_object(rcvr);
                }
                var dist_x = lengthdir_x(dist, dir);
                var dist_y = lengthdir_y(dist, dir);

                //
                self.push_spd.x = clamp(dist_x / 6, -self.max_push_spd, self.max_push_spd);
                if abs(self.push_spd.x) <= (self.max_push_spd / 10) {
                    self.push_spd.x = 0;
                }

                self.push_spd.y = clamp(dist_y / 6, -self.max_push_spd, self.max_push_spd);
                if abs(self.push_spd.y) <= (self.max_push_spd / 10) {
                    self.push_spd.y = 0;
                }

                if self.push_spd.sqrd_magnitude() > ((self.max_push_spd * self.max_push_spd) / 4) {
                    self.push_spd.normalized(self.max_push_spd / 2)
                }
            }

            function cancel_tarball() {
                //
                if self.tarball != undefined {
                    instance_destroy(self.tarball);
                    self.tarball = undefined;
                }
            }

            function make_tarball(owner) {
                //
                if self.combo_state < 0 || self.combo_state > 2 {
                    return;
                }

                var x_mask = cardinal_is_horizontal(self.cached_cardinal);

                var player_data = fiddle_get("player");
                var sword_swing = player_data.large.sword_swing[self.combo_state][$ cardinal_to_string(self.cached_cardinal)];

                var width = sword_swing.dims[0];
                var height = sword_swing.dims[1];

                var critical_damage = self.is_critical ? 2 : 1;
                var dmg = 0;

                var instant_kill = false;

                dmg += self.sword.prototype.damage + ARI.get_equipment_bonus_from(Infusion.Sharp, "amount");
                if self.sword.infusion == Infusion.InstantKill
                    && chance_percent(INFUSIONS.get(Infusion.InstantKill).percentage)
                {
                    instant_kill = true;
                }
                dmg *= 1 + (0.25 * ARI.status_effects.get_effect_value(StatusEffectId.SureStrike, 0));
                dmg *= critical_damage * !owner.wimp_mode;

                if self.combo_state == 2 {
                    dmg *= 1.5;
                }

                dmg *= ARI.status_effects.get_effect_value(StatusEffectId.FireSword);

                dmg = round(dmg);

                //
                var tarball = TarballBuilder(
                        owner.x,
                        owner.y,
                        width,
                        height,
                        dmg,
                        CombatTarget.Enemy,
                    )
                    .set_knockback(5.5, 6.5, 48)
                    .set_parent(owner)
                    .set_offset(sword_swing.offset[0], sword_swing.offset[1])
                    .set_push_force_mask(x_mask, !x_mask)
                    .set_heavy(self.combo_state == 2)
                    .set_critical(self.is_critical)
                    .set_fire_oil(ARI.status_effects.get_effect_value(StatusEffectId.FireSword, 0) > 0)
                    .set_venomous(ARI.status_effects.get_effect_value(StatusEffectId.VenomSword, 0) > 0)
                    .set_frozen(ARI.status_effects.get_effect_value(StatusEffectId.IceSword, 0) > 0)
                    .set_instant_kill(instant_kill)
                    .notify(self)
                    .gen();

                with tarball {
                    object_event(self.object_index, ObjectEvent.Step)();
                }

                return tarball;
            }

            function player_requested_move() {
                var inputs = [InputId.Left, InputId.Right, InputId.Up, InputId.Down, InputId.Jump];
                for (var i = 0; i< array_length(inputs); i++) {
                    var input = inputs[i];
                    if INPUT.check(input) {
                        return true;
                    }
                }
                return false;
            }

            self.push_spd = Vec2();
            self.max_push_spd = 0;
            self.tarball = undefined;
            self.move = Vec2();
            self.input = Vec2();
        })
        .start(function() {
            self.combo_state = -1;
            self.can_make_tarball = false;
            self.move.set_zero();
            self.input.set_zero();
            self.push_spd.set_zero();
            self.max_push_spd = 0;

            self.input_buffer = false;
            self.sword = self.blackboard.take("sword")

            self.owner.par.set_attachment(item_id_to_string(sword.item_id));

            self.cached_cardinal = self.owner.cardinal;
            self.dir = cardinal_to_angle(self.cached_cardinal);

            self.next_swing();
        })
        .step(function() {
            if self.owner.check_for_menu_opens() {
                return;
            }

            self.owner.emit_fire();

            if self.can_make_tarball && self.owner.par.is_broadcasting(BroadcastMessage.START_ACTION) {
                self.tarball = make_tarball(self.owner);
                self.can_make_tarball = false;
            }

            if self.owner.par.is_broadcasting(BroadcastMessage.FINISH_ACTION) {
                self.can_go_to_next_combo = true;
                self.cancel_tarball();
            }

            self.owner.collision_check(self.move);
            move_ari(self.owner, self.move);
            update_depth_items(self.owner);

            if INPUT.pressed(InputId.UseToolCharged) || INPUT.pressed(InputId.UseToolRepeated) {
                self.input_buffer = true;
            }

            //
            if self.input_buffer && self.can_go_to_next_combo {
                self.next_swing();
            } else if (self.can_go_to_next_combo && self.player_requested_move()) || self.owner.par.animation_complete {
                self.fsm.change_state_instant(PlayerState.Default);
            }
        })
        .end_step(function() {
            //
            if self.owner.par.is_broadcasting(BroadcastMessage.PUSH_FORWARD) {
                self.move.x = self.push_spd.x;
                self.move.y = self.push_spd.y;
            } else {
                self.move.set_zero();
            }
            owner.face_dir(self.dir);
        })
        .stop(function() {
            self.cancel_tarball();

            //
            self.owner.par.tool_effect = ToolEffect.None;
            self.owner.par.remove_attachment();
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.Dummy)
        .create(function() {
            self.move = Vec2(0,0);
            self.spd = 0;
        })
        .start(function() {
            self.cached_cardinal = self.owner.cardinal;
            self.spd = self.blackboard.try_take("spd", 0);
            owner.receiver.status = set_flag(owner.receiver.status, ReceiverStatus.UntimedInvulnerable);

            self.is_mounted = self.blackboard.try_take("was_mounted", false);
            self.override_depth = self.blackboard.try_take("override_depth");

            //
            frame = 0;
            timer = 0;

            if self.is_mounted {
                self.last_animation = self.blackboard.take("last_mounted_animation");
                shadow_caster_set_sprite(owner.shadow_caster, ARI.mount.active_sprites().shadow);
            }
        })
        .step(function() {
            if self.spd != 0 {
                var dir = cardinal_to_angle(self.cached_cardinal);

                self.move.x = lengthdir_x(self.spd, dir);
                self.move.y = lengthdir_y(self.spd, dir);

                check_footsteps(self.owner, self.move, MountCycle.None);
            }

            ARI.check_for_held_items(owner);
            move_ari(self.owner, self.move);
            update_depth_items(self.owner);

            if self.override_depth != undefined {
                owner.depth = self.override_depth;
            }

            if self.is_mounted {
                mounted_par_offsets(false);
            }
        })
        .draw(function() {
            if self.is_mounted == false {
                return;
            }

            mounted_draw(self.last_animation);
        })
        .draw_after(function() {
            if self.is_mounted == false {
                return;
            }

            mounted_draw_after();
        })
        .stop(function() {
            owner.receiver.status = remove_flag(owner.receiver.status, ReceiverStatus.UntimedInvulnerable);
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.MountDefault)
        .create(function() {
            self.input = Vec2(0, 0);
            self.move = Vec2(0, 0);
            self.dir = 0;
            self.par_animation = 0;

            self.in_idle_variant = false;

            function new_animal_animation(target_mount_animation) {
                if target_mount_animation == "idle" && self.in_idle_variant {
                    return;
                }

                ARI.mount.animation = target_mount_animation;

                //
                self.frame = 0;
                self.timer = 0;
                self.frame_ticked_over = false;
            }

            function random_idle_time() {
                return irandom_range(120, 240);
            }

            self.idle_variants = List();
        })
        .start(function() {
            self.owner.set_animation(AnimationName.Ride);
            self.par_animation = AnimationName.Ride;
            obj_tile_cursor.state = TileCursorState.Hidden;

            //
            shadow_caster_set_sprite(owner.shadow_caster, ARI.mount.active_sprites().shadow);

            //
            //
            frame = 0;
            timer = 0;

            frame_ticked_over = false;

            //
            self.idle_timer = self.random_idle_time();

            //
            self.idle_variants.clear();
            self.idle_variants.push("idle_2");
            self.idle_variants.push("blink");

            //
            for (var i = 3; i < 10; i++) {
                var this_idle = format("idle_{}", i);
                if ARI.mount.has_animation(this_idle) {
                    self.idle_variants.push(this_idle);
                } else {
                    break;
                }
            }

            self.in_idle_variant = false;

            self.mount_cycle_override = undefined;
            if ARI.mount.variant == "giant_chicken_white"
                || ARI.mount.variant == "giant_chicken_gold"
            {
                self.mount_cycle_override = MountCycle.Back;
            }
        })
        .step(function() {
            //
            self.owner.emit_fire();

            if self.owner.should_faint() {
                return;
            }

            if self.owner.check_for_menu_opens() {
                owner.set_animation(AnimationName.Ride);
                return;
            }

            //
            if owner.should_die() {
                return;
            }

            //
            var ui_request = owner.ui_mount_request;
            owner.ui_mount_request = false;
            if self.fsm.state_frame > 15 && (ui_request || INPUT.pressed(InputId.Ride) || owner.overlaps_mount_blocker()) {
                owner.fsm.change_state(PlayerState.Default);
                return;
            }

            //
            if owner.quest_handle_queries() {
                return;
            }

            ARI.check_for_held_items(self.owner);

            //
            self.input.x = INPUT.check_value(InputId.Right) - INPUT.check_value(InputId.Left);
            self.input.y = INPUT.check_value(InputId.Down) - INPUT.check_value(InputId.Up);

            if ON_GAMEPAD {
                //
                //
                ARI.run_toggle = self.input.sqrd_magnitude() > 0.25;
            } else {
                //
                ARI.run_toggle = !INPUT.check(InputId.Walk);
            }

            //
            var spd = ARI.get_move_speed(true);
            self.move.x = 0;
            self.move.y = 0;

            //
            if input.is_zero() {
                self.idle_timer -= 1;

                if self.in_idle_variant == false && self.idle_timer <= 0 {
                    var animation = undefined;
                    repeat 5 {
                        animation = self.idle_variants.choose_random();
                        if ARI.mount.has_animation_with_cardinal(animation, ARI.mount.cardinality) {
                            break;
                        } else {
                            animation = undefined;
                        }
                    };
                    if animation == undefined {
                        self.idle_timer = self.random_idle_time();
                    } else {
                        self.new_animal_animation(animation);
                        self.in_idle_variant = true;
                    }
                }
            } else {
                var dir = point_direction(0, 0, input.x, input.y);

                //
                self.move.x += lengthdir_x(spd, dir);
                self.move.y += lengthdir_y(spd, dir);

                if abs(self.move.x) < 0.0001 {
                    self.move.x = 0;
                }
                if abs(self.move.y) < 0.0001 {
                    self.move.y = 0;
                }

                self.owner.face_dir(dir);

                self.idle_timer = self.random_idle_time();
                self.in_idle_variant = false;
            }

            if self.in_idle_variant && self.frame_ticked_over && floor(self.frame) == 0 {
                self.in_idle_variant = false;
                self.idle_timer = self.random_idle_time();
                self.new_animal_animation("idle");
            }

            //
            ARI.mount.cardinality = owner.cardinal;

            self.owner.collision_check(self.move);

            //
            if ARI.perk_active(Perk.HarvestHorse) {
                var ni = GRID.try_node_index_for_room_position(self.owner.x, self.owner.y);
                if ni != undefined
                    && object_id_to_object_category(GRID.node_object_id[ni]) == ObjectCategory.Crop
                    && can_interact(GRID.node_parent[ni]) //
                {
                    interact(GRID.node_parent[ni]);
                }
            }

            //
            var new_player_animation;
            if move.is_zero() {
                new_player_animation = AnimationName.Ride;
            } else if ARI.run_toggle {
                new_player_animation = AnimationName.RideRun;
            } else {
                new_player_animation = AnimationName.RideWalk;
            }
            owner.set_animation(new_player_animation);

            if self.move.is_zero() == false && self.frame_ticked_over && (floor(self.frame) == 0 || floor(self.frame == 2)) {
                var mount_cycle = self.mount_cycle_override;
                if mount_cycle == undefined {
                    if floor(self.frame) == 0 {
                        mount_cycle = MountCycle.Front;
                    } else {
                        mount_cycle = MountCycle.Back;
                    }
                }
                check_footsteps(self.owner, self.move, mount_cycle);
            }

            //
            move_ari(self.owner, self.move);

            //
            update_depth_items(self.owner);
            var trans = owner.try_room_transition();
            if trans != undefined {
                owner.leave_room(trans.player_direction, HUMAN_WALK_SPEED * trans.spd_multiplier);
            }

            //
            var can_check_interactable = true;
            if self.owner.check_pressed_input(InputId.Jump) {
                self.owner.check_jump(
                    self.input.x,
                    self.input.y,
                    ARI.run_toggle ? MOUNT_RUN_JUMP_DISTANCE : MOUNT_WALK_JUMP_DISTANCE,
                    false,
                );
                self.fsm.change_state(PlayerState.MountJump);
                can_check_interactable = false;
            }

            if can_check_interactable {
                var selection = find_nearest_interactable(self.owner.collision_list, self.owner);
                if selection != undefined {
                    var cback = selection.attempt_interact();
                    if cback != undefined {
                        cback();
                    }
                }
            }

            mounted_par_offsets(self.in_idle_variant);
        })
        .draw(function() {
            if ARI.mount == undefined {
                return;
            }
            mounted_draw(self.par_animation);
        })
        .draw_after(function() {
            if ARI.mount == undefined {
                return;
            }
            self.frame_ticked_over = mounted_draw_after();
        })
        .stop(function() {
            //
            owner.par_offset.x = owner.default_par_offset.x;
            owner.par_offset.y = owner.default_par_offset.y;

            shadow_caster_set_sprite(owner.shadow_caster, spr_npc_shadow);

            //
            ARI.held_item_last_frame = undefined;
            ARI.held_animal_last_frame = undefined;
            self.in_idle_variant = false;

            if !matches(self.fsm.next_state.state_id, PlayerState.MountJump, PlayerState.Dummy) {
                TANGO.play("SoundEffects/Animals/SteedDesummon");
                create_animation_effect(owner.x + irandom(8), owner.y - irandom_range(4, 16), -100000, spr_fx_poof1_essence_once);
                create_animation_effect(owner.x - irandom(8), owner.y - irandom_range(4, 16), -100000, spr_fx_poof1_essence_once);
                create_animation_effect(owner.x + irandom(8), owner.y - irandom_range(4, 16), -100000, spr_fx_poof1_essence_once);
                create_animation_effect(owner.x - irandom(8), owner.y - irandom_range(4, 16), -100000, spr_fx_poof1_essence_once);
            }
        })
        .spawn()
    )
    .add_state(StateBuilder(PlayerState.MountJump)
        .create(function() {
            function new_animal_animation(target_mount_animation) {
                ARI.mount.animation = target_mount_animation;

                //
                self.frame = 0;
                self.timer = 0;
            }
        })
        .start(function() {
            TANGO.play("SoundEffects/Ari/Jump");
            self.owner.dust_particle_burst();

            self.owner.set_animation(AnimationName.RideJump);

            self.jspd = self.owner.jump_data.spd;
            self.jump_spd = Vec2(
                (self.owner.jump_goal.x - self.owner.x) / self.owner.jump_data.frames,
                (self.owner.jump_goal.y - self.owner.y) / self.owner.jump_data.frames
            );
            self.dir = self.owner.dir;
            self.transition_on_finish = false;
            self.move = Vec2();

            shadow_caster_set_sprite(owner.shadow_caster, ARI.mount.active_sprites().shadow);

            //
            //
            frame = 0;
            timer = 0;
        })
        .step(function() {
            self.owner.emit_fire();
            self.jspd += self.owner.jump_data.grv;
            self.owner.z += self.jspd;

            var ni = GRID.node_index_for_room_position(self.owner.x, self.owner.y);

            ARI.check_for_held_items(self.owner);

            if self.owner.z >= 0 {
                //
                self.jspd = 0;
                self.owner.z = 0;

                if self.transition_on_finish {
                    self.owner.leave_room(self.dir, HUMAN_WALK_SPEED);
                } else if GRID.node_terrain_kind[ni] == TerrainKind.Water {
                    //
                    //
                    self.fsm.change_state(PlayerState.Swim);
                    create_animation_effect(self.owner.x, self.owner.y, self.owner.depth + 8, spr_fx_water_player_splash);
                    set_rumble(RumbleKind.ToolWeak);
                } else {
                    //
                    self.fsm.change_state(self.blackboard.try_take("end_state", PlayerState.MountDefault));
                    self.owner.dust_particle_burst();

                    try_play_footstep_at_position(self.owner.x, self.owner.y, self.owner.cardinal, true, MountCycle.Back, self.owner);
                    set_rumble(RumbleKind.ToolWeak);
                }
            }

            //
            self.move.x = self.jump_spd.x;
            self.move.y = self.jump_spd.y;

            move_ari(self.owner, self.move);
            update_depth_items(self.owner);

            //
            if self.transition_on_finish == false {
                var trans = self.owner.try_room_transition();
                if trans != undefined {
                    self.dir = trans.player_direction;
                    self.transition_on_finish = true;
                }
            }

            mounted_par_offsets(false);
        })
        .draw(function() {
            mounted_draw(AnimationName.RideJump);
        })
        .draw_after(function() {
            mounted_draw_after();
        })
        .stop(function() {
            //
            owner.par_offset.x = owner.default_par_offset.x;
            owner.par_offset.y = owner.default_par_offset.y;

            shadow_caster_set_sprite(owner.shadow_caster, spr_npc_shadow);
        })
        .spawn()
    );
}

enum DiveBehavior {
    Divespot,
    Whirlpool
}

function throw_item(owner, items_thrown) {

    //
    var offset = Vec2(0,0);
    var xx = owner.x;
    var yy = owner.y;

    var final_x = owner.x;
    var final_y = owner.y;

    var x_offset = 0;
    var y_offset = 0;

    var obj = obj_item;
    if items_thrown.first().prototype.use == ItemUse.Bomb {
        obj = obj_player_bomb;
    }

    //
    if owner.fsm.current_state_id() == PlayerState.ThrowItem {
        offset = owner.par.slots[AnimationSlot.HeldItem].base.animation[1].offset;
        x_offset = sprite_get_width(owner.par.held_sprite.sprite_index) / 2;
        y_offset = sprite_get_height(owner.par.held_sprite.sprite_index);

        owner.par.remove_held_sprite();
        ARI.held_item_last_frame = undefined;

        //
        if obj == obj_player_bomb {
            owner.par.remove_held_sprite();
            owner.par.unset_modifier(AnimationName.Pickup);
        }

        var flipper = owner.par.cardinal == Cardinal.West ? -1 : 1;
        xx = owner.x + owner.par_offset.x + offset.x + x_offset * flipper;
        yy = owner.y;

        //
        var distance = random_range(40, 52);
        var dir = cardinal_to_angle(obj_ari.cardinal);
        final_x = owner.x + lengthdir_x(distance, dir);
        final_y = owner.y + lengthdir_y(distance, dir);
    }

    //
    var inst = instance_create_layer(xx, yy, "Instances", obj);
    inst.arc = true;
    inst.final_x = final_x
    inst.final_y = final_y

    inst.draw_z_offset = owner.par_offset.y + offset.y + y_offset;
    inst.final_draw_z_offset = 0;

    //
    //
    inst.start_z = 8;
    inst.z = -8;

    inst.move_draw_z = true;
    inst.start_small = false;
    inst.thrown_by_ari = true;
    inst.setup(items_thrown);
    inst.started_in_collision = false;
    TANGO.play("SoundEffects/Inventory/ItemDrop", xx, yy);
}

function move_ari(owner, move) {
    owner.x += move.x;
    owner.y += move.y;

    //
    if move.is_zero() {
        owner.x = round(owner.x);
        owner.y = round(owner.y);
    }

    if self.fsm.current_state_id() != PlayerState.Dummy {
        //
        var _bound = 1 + (OBJECT_CELL_SIZE / 2);
        assert(
            (owner.x > _bound) || (owner.x < room_width() - _bound) || (owner.y > _bound) || (owner.y < room_height() - _bound),
            "the player is outside the room. they ended up at ({}, {}), and our bounds are [({}, {}), ({}, {})]",
            owner.x, owner.y, _bound, room_width() - _bound, _bound, room_height() - _bound
        );
    }

    owner.meddler.update(owner.x, owner.y);
}

function update_depth_items(owner) {
    owner.depth = get_instance_depth(owner.y);
    owner.player_collect_items();
}

function check_footsteps(owner, move, mount_cycle) {
    var ni = GRID.try_node_index_for_room_position(owner.x, owner.y);
    if ni == undefined {
        error("We are in the void ({}x{} / {}x{})! Get back to the ground, Ari!", owner.x div 8, owner.y div 8, owner.x, owner.y);
        return;
    }
    switch GRID.node_terrain_kind[ni] {
        case TerrainKind.Water:
        case TerrainKind.Ground:
        case TerrainKind.Lava:
            break;
        case undefined:
            error("We are in the void ({}x{} / {}x{})! Get back to the ground, Ari!", owner.x div 8, owner.y div 8, owner.x, owner.y);
            return;
        default: impossible("We tried to walk on unimplemented/unwalkable terrain");
    }

    if move.is_zero() == false {
        if owner.is_mounted() {
            var is_running = owner.par.base_animation() == AnimationName.RideRun;
            try_play_footstep_at_position(owner.x, owner.y, owner.cardinal, is_running, mount_cycle, owner);
        } else if owner.par.new_frame
            && owner.par.is_broadcasting(BroadcastMessage.EMIT_FOOTSTEP_SOUND)
        {
            var is_running = owner.par.base_animation() == AnimationName.Run;

            try_play_footstep_at_position(owner.x, owner.y, owner.cardinal, is_running, mount_cycle, owner);
        }
    }
}

function create_critical_swing_poof(xx, yy, target_x, target_y, target_depth, amount, morsel_depth=0, func=undefined) {
    var critical_vfx = create_animation_effect(xx, yy, target_depth, spr_fx_critical_swing_poof);
    TANGO.play("SoundEffects/Inventory/StaminaPreSpawnPoof", xx, yy);
    critical_vfx.target_x = target_x;
    critical_vfx.target_y = target_y;
    critical_vfx.amt = amount;
    critical_vfx.depth_level_target = morsel_depth;

    critical_vfx.image_idx = 4;
    if func == undefined {
        critical_vfx.image_idx_func = method(critical_vfx, function() {
            create_morsels(
                self.target_x,
                self.target_y,
                24,
                MorselType.Stamina,
                self.amt,
                depth_level_target,
            );
        });
    } else {
        critical_vfx.image_idx_func = method(critical_vfx, func);
    }

    return critical_vfx;
}

function TangoDoppel() constructor {
    self.sounds = List();
    function play_good(sound, x, y) {
        self.sounds.push({
            sound: sound,
            good: true,
            pos: Vec2(x, y)
        });
    }
    function play_bad(sound, x, y) {
        self.sounds.push({
            sound: sound,
            good: false,
            pos: Vec2(x, y)
        });
    }
    function resolve() {
        var has_good_sfx = false;
        //
        for (var i = 0, c = self.sounds.count(); i < c; i++) {
            var sfx = self.sounds.get(i);
            if sfx.good {
                has_good_sfx = true;
                break;
            }
        }
        //
        for (var i = 0, c = self.sounds.count(); i < c; i++) {
            var sfx = self.sounds.get(i);
            if has_good_sfx {
                if sfx.good {
                    TANGO.play(sfx.sound, sfx.pos.x, sfx.pos.y);
                }
            } else {
                TANGO.play(sfx.sound, sfx.pos.x, sfx.pos.y);
            }
        }
        self.sounds.clear();
    }
}

function mounted_par_offsets(in_idle_variant) {
    //
    var ari_animal_offset_x = 0.0;
    var ari_animal_offset_y = 0.0;

    try {
        var offsets;
        if ARI.mount.variant == "giant_chicken_white"
            || ARI.mount.variant == "giant_chicken_gold"
        {
            offsets = fiddle_get(format("ranching/giant_chicken_player_offsets/{}/player_offsets", ARI.mount.animation));
        } else {
            offsets = ARI.mount.prototype.animations.get(ARI.mount.animation)[$ "player_offsets"];
        }
        if offsets != undefined {
            var cardinal = owner.cardinal == Cardinal.West ? Cardinal.East : owner.cardinal;
            var data;
            if in_idle_variant {
                data = offsets[$ cardinal_to_string(cardinal)][0];
            } else {
                var offset_array = offsets[$ cardinal_to_string(cardinal)];
                if offset_array == undefined {
                    data = [0.0, 0.0];
                } else {
                    data = offset_array[min(array_length(offset_array) - 1, self.frame)];
                }
            }
            ari_animal_offset_x = data[0];

            //
            if owner.cardinal == Cardinal.West {
                ari_animal_offset_x *= -1;
            }
            ari_animal_offset_y = data[1];
        }
    } catch (_error) {
        //
        error("incorrect self.frame -- was set to `{}`", self.frame);
    }

    //
    owner.par_offset.x = owner.default_par_offset.x + ari_animal_offset_x;
    owner.par_offset.y = owner.default_par_offset.y + ari_animal_offset_y;
    shadow_caster_set_sprite(owner.shadow_caster, ARI.mount.active_sprites().shadow);

    //
    owner.par.unset_all_modifiers();
}

function mounted_draw(animation) {
    var sprites = ARI.mount.active_sprites();
    var ratio = DISPLAY.asset_resize();
    var owner_x = floor(owner.x * ratio) / ratio;
    var owner_y = floor((owner.y + owner.z) * ratio) / ratio;

    animal_set_up_draw(sprites);
    draw_sprite_ext(
        sprites.base_sprite,
        self.frame,
        owner_x,
        owner_y,
        owner.cardinal == Cardinal.West ? -1 : 1,
        1,
        0,
        c_white,
        0.0,
    );

    if sprites.base_cosmetic != undefined {
        gpu_set_extra(UberShaderKind.Overlay);
        draw_sprite_ext(
            sprites.base_cosmetic,
            self.frame,
            owner_x,
            owner_y,
            owner.cardinal == Cardinal.West ? -1 : 1,
            1,
            0,
            c_white,
            0.0,
        );
    }

    gpu_reset_extra();
    owner.par.base_to_frame(animation, self.frame);
}

function mounted_draw_after() {
    var ratio = DISPLAY.asset_resize();
    var owner_x = floor(owner.x * ratio) / ratio;
    var owner_y = floor((owner.y + owner.z) * ratio) / ratio;

    var sprites = ARI.mount.active_sprites();
    if sprites.top_sprite != undefined {
        animal_set_up_draw(sprites);
        draw_sprite_ext(
            sprites.top_sprite,
            self.frame,
            owner_x,
            owner_y,
            owner.cardinal == Cardinal.West ? -1 : 1,
            1,
            0,
            c_white,
            0.0,
        );
        gpu_reset_extra();
    }

    if sprites.top_cosmetic != undefined {
        gpu_set_extra(UberShaderKind.Overlay);
        draw_sprite_ext(
            sprites.top_cosmetic,
            self.frame,
            owner_x,
            owner_y,
            owner.cardinal == Cardinal.West ? -1 : 1,
            1,
            0,
            c_white,
            0.0,
        );
        gpu_reset_extra();
    }

    var sprite_info = sprite_get_info(sprites.base_sprite);
    var frame_info = sprite_info.frame_info;

    //
    self.timer += (40 / 60) * (!non_cutscene_pause() || ANCHOR.get_menu(Menu.Textbox) != undefined);

    if self.timer >= frame_info[clamp(self.frame, 0, array_length(frame_info) - 1)].duration {
        //
        self.timer -= frame_info[clamp(self.frame, 0, array_length(frame_info) - 1)].duration;
        self.frame = (self.frame + 1) % sprite_info.num_subimages;

        return true;
    }

    return false;
}
