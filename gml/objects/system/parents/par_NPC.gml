object_create(
    "par_NPC",
    object_reserve("par_interactable"),
    {
        sprite_index: undefined,
        create: function() {
            event_inherit(ObjectEvent.Create, par_interactable);
            self.selection_priority = 1;
            z = 0;
            y_offset = 0;
            kiss_particle = undefined;
            kiss_sound = undefined;

            shadow_caster = SHADOW_GRID.caster_create(x, y);
            shadow_caster_set_sprite(shadow_caster, spr_npc_shadow);
            mask_index = spr_npc_mask;
            drink_override = undefined;
            kissing = false;

            function DummyExitConditionFactory() constructor {
                static Timer = function(timer_max) {
                    return {
                        type: DummyExitConditionId.Timer,
                        timer_max: timer_max,
                    }
                }
                static Position = function(position) {
                    return {
                        type: DummyExitConditionId.Position,
                        position: position,
                    }
                }
                static Never = {
                    type: DummyExitConditionId.Never,
                }
            }

            global.dummy_exit_condition_factory = new DummyExitConditionFactory();
            #macro DummyExitCondition global.dummy_exit_condition_factory

            //
            function look_for_entry_transition() {
                var trellis_point = trellis_point_by_location_position(self.me.location_position);
                if trellis_point != undefined {
                    switch trellis_point.object_index {
                        case obj_trellis_point_transition:
                            var card = cardinal_to_inverse(trellis_point.direction);
                            switch card {
                                case Cardinal.North:
                                    self.y += 32;
                                    break;
                                case Cardinal.West:
                                    self.x += 32;
                                    break;
                                case Cardinal.South:
                                    self.y -= 32;
                                    break;
                                case Cardinal.East:
                                    self.x -= 32;
                                    break;
                                default: impossible("Unexpected Cardinal: {}", card);
                            }
                            self.position.x = self.x;
                            self.position.y = self.y;
                            self.me.set_cardinality(card);
                            break;
                        case obj_trellis_point_door:
                            //
                            var nearest = instance_nearest(self.x, self.y, obj_door);
                            if nearest != undefined {
                                nearest.request_open();
                                self.y -= 32;
                                self.position.y = self.y;
                                self.me.set_cardinality(Cardinal.South);
                            }
                            break;
                        default: return;
                    }

                    //
                    //
                    self.depth = get_instance_depth(self.y, self.z);
                    shadow_caster_set_position(self.shadow_caster, self.x, self.y);

                    //
                    self.fsm.blackboard.set(
                        "dummy_exit_condition",
                        DummyExitCondition.Position(trellis_point.location_position.pos)
                    );
                    self.fsm.blackboard.set("dummy_exit_callback", function() {});

                    self.fsm.change_state_instant(NpcState.Dummy);
                    self.fsm.blackboard.set("start_dummy_walk", true);
                }
            }

            //
            function update_position() {
                //
                //
                self.position.set_add(move_spd);

                //
                self.x = self.position.x;
                self.y = self.position.y;
            }

            function create_default_fsm() {
                return StateMachineBuilder(NpcState.LEN)
                    .add_state(StateBuilder(NpcState.Default)
                        .start(function() {
                            if self.owner.me.animation == self.owner.get_walk_animation() {
                                self.owner.me.set_animation("idle");
                            }
                            //
                            self.owner.zone = T2R.read(format("{NpcId}_zone", owner.npc_id))

                            //
                            var trellis_point = trellis_point_by_location_position(self.owner.me.location_position);
                            if trellis_point != undefined && !MIST.is_running() {
                                //
                                self.owner.me.set_cardinality(trellis_point.direction);

                                //
                                if
                                    trellis_point.object_index == obj_trellis_point_seat
                                    && self.owner.me.is_seated() == false
                                    && self.owner.me.try_set_animation("sit") == false
                                {
                                        error("{NpcId} does not have a valid `sit` animation, but one was requested!", self.owner.npc_id);
                                        self.owner.me.set_animation("idle");
                                }
                            }

                            self.owner.update_cardinality();
                            self.owner.update_animation();
                        })
                        .step(function() {
                            if self.owner.me.itinerary != undefined && !self.owner.kissing {
                                self.fsm.change_state(NpcState.Pathfinding);
                            }
                        })
                        .draw(function() {
                            var ratio = DISPLAY.asset_resize();
                            var draw_x = floor(owner.x * ratio) / ratio;
                            var draw_y = floor(owner.y * ratio) / ratio + owner.y_offset;

                            draw_sprite_ext(owner.sprite_index, owner.image_index, draw_x, draw_y, self.owner.image_xscale, 1, 0, self.owner.image_blend, self.owner.image_alpha);

                            if self.owner.drink_animation != undefined {
                                draw_sprite_ext(
                                    self.owner.drink_animation,
                                    owner.image_index,
                                    draw_x,
                                    floor((owner.y + owner.drink_offset) * ratio) / ratio,
                                    self.owner.image_xscale,
                                    1,
                                    0,
                                    self.owner.image_blend,
                                    1
                                );
                            }
                        })
                        .stop(function() {
                            self.owner.chat_partner = undefined;
                            self.owner.chat_timer = undefined;
                        })
                        .spawn()
                    )
                    .add_state(StateBuilder(NpcState.Pathfinding)
                        .create(function() {
                            self.active_block = undefined;

                            function begin_pathfinding() {
                                self.itinerary = pathfinding_util_get_itinerary();
                                var err = pathfinding_util_create_local_path(self.itinerary, self.owner);
                                if err != undefined {
                                    error("itinerary is {}", self.itinerary);
                                    error("current_item path = {}", self.itinerary.current_item().local_path);

                                    crash("{NpcId} cannot get to their destination: {}", owner.me.id, err);
                                }
                                owner.position.x = owner.x;
                                owner.position.y = owner.y;

                                self.owner.me.set_animation(self.owner.get_walk_animation());

                                //
                                with par_NPC {
                                    self.update_talk_status();
                                }
                                //
                                self.owner.zone = T2R.read(format("{NpcId}_zone", owner.npc_id))

                                self.can_reset = false;
                            }

                            function bop_along_path() {
                                var completed = pathfinding_util_move_along_path(owner.position, owner.move_accel, owner.move_spd, self.owner.pathfinding_agent, self.owner);

                                if completed {
                                    //
                                    self.owner.me.location_position = self.itinerary
                                        .current_item()
                                        .target_location
                                        .clone();

                                    self.owner.x = self.owner.me.location_position.pos.x;
                                    self.owner.y = self.owner.me.location_position.pos.y;

                                    //
                                    if self.itinerary.on_last_item() {
                                        self.owner.me.brain.blackboard.set("pathfind_complete", true);
                                        self.owner.me.simulated_distance_traveled = 0;
                                        self.owner.me.itinerary = undefined;

                                        //
                                        run_brain(self.owner.me.brain);
                                        self.owner.me.activity_handler.run();
                                        run_brain(self.owner.me.brain);

                                        if self.owner.me.itinerary != undefined {
                                            self.begin_pathfinding();
                                        } else {
                                            self.fsm.change_state(NpcState.Default);
                                        }
                                    } else {
                                        //
                                        var trellis_point = trellis_point_by_location_position(self.owner.me.location_position);
                                        assert_defined(
                                            trellis_point,
                                            "{NpcId} failed to find a TrellisPoint! Npc is at {}.",
                                            self.owner.me.id,
                                            self.owner.me.location_position,
                                        );

                                        //
                                        self.owner.pathfinding_agent.clear_all_reservations();
                                        self.owner.me.location_position = self.owner.pathfinding_agent.itinerary.advance_path();
                                        self.owner.me.simulated_distance_traveled = 0;

                                        //
                                        switch trellis_point.object_index {
                                            case obj_trellis_point_door:
                                                var nearest = instance_nearest(self.owner.x, self.owner.y, obj_door);
                                                var wait_time = 0;
                                                if nearest != undefined {
                                                    nearest.request_open();
                                                    var angle = point_direction(self.owner.x, self.owner.y, nearest.x, nearest.y);
                                                    self.owner.me.set_cardinality(angle_to_cardinal(angle));
                                                    wait_time = nearest.get_wait_time();
                                                }
                                                self.owner.dummy_walk_out_of_room();
                                                new_chain()
                                                    .join(LinkId.Timer, wait_time)
                                                    .append(LinkId.Function, function() {
                                                        self.fsm.blackboard.set("start_dummy_walk", true);
                                                    });
                                                break;
                                            case obj_trellis_point_transition:
                                                //
                                                self.owner.me.set_cardinality(trellis_point.direction);
                                                self.owner.dummy_walk_out_of_room();
                                                self.fsm.blackboard.set("start_dummy_walk", true);
                                                break;
                                            default: impossible("TrellisPoint '{}' was used as a Pathfinding door, but is neither a door or transition.", trellis_point.name);
                                        }
                                    }
                                }
                            }
                        })
                        .start(function() {
                            self.begin_pathfinding();

                            self.manual_halt = false;
                        })
                        .step(function() {
                            var in_pet_animation = (owner.npc_id == NpcId.Dozy || owner.npc_id == NpcId.Henrietta)
                                && self.owner.me.animation == self.owner.pet_animation;

                            if in_pet_animation {
                                self.owner.anim_speed = 1;
                            }

                            self.manual_halt = in_pet_animation || self.owner.kissing;

                            if self.manual_halt {
                                return;
                            }

                            //
                            //
                            var walk_anim = self.owner.get_walk_animation();
                            if walk_anim != self.owner.me.animation {
                                self.owner.me.set_animation(walk_anim);
                            }

                            //
                            if self.active_block != undefined {
                                if self.owner.pathfinding_agent.path_check_error() == undefined {
                                    //
                                    self.active_block = undefined;
                                } else {
                                    self.active_block.timer -= 1;
                                    if self.active_block.timer == 0 {
                                        if self.active_block.stage == 0 {
                                            //
                                            self.owner.bark_emitter.emit(BarkId.Ellipses);
                                            self.active_block.stage = 1;
                                            self.active_block.timer = fiddle_get("misc/npc_behavior/path_block_reroute_delay");
                                        } else {
                                            //
                                            var blocked_squares = array_clone(obj_ari.meddler.held_squares);

                                            //
                                            var final_position = self.owner.pathfinding_agent.todo_list().first();
                                            final_position = final_position.x + final_position.y * GRID.dims.x;
                                            var current_position = self.owner.x div 8 + (self.owner.y div 8) * GRID.dims.x;

                                            var blocked_poses = List();

                                            for (var i = 0, c = array_length(blocked_squares); i < c; i++) {
                                                var vec1_square_id = blocked_squares[i];
                                                if vec1_square_id == undefined {
                                                    break;
                                                }

                                                if vec1_square_id == final_position {
                                                    //
                                                    self.active_block = { stage: 0, timer: fiddle_get("misc/npc_behavior/path_block_bark_delay") };
                                                    return;
                                                }

                                                //
                                                if vec1_square_id == current_position {
                                                    blocked_squares[i] = undefined;
                                                    continue;
                                                }

                                                var reservation = PATHFINDING.reservation(vec1_square_id);

                                                //
                                                //
                                                //
                                                //
                                                if reservation != undefined
                                                    && owner.pathfinding_agent.meddler != undefined
                                                    && reservation.id != owner.pathfinding_agent.meddler.id
                                                {
                                                    blocked_poses.push(vec1_square_id);
                                                    PATHFINDING.set_local_position_is_taken(
                                                        vec1_square_id mod GRID.dims.x,
                                                        vec1_square_id div GRID.dims.x,
                                                        true
                                                    );
                                                }
                                            }

                                            //
                                            var err = undefined;
                                            {
                                                var itinerary_item = self.itinerary.items.get(self.itinerary.cursor);
                                                var new_path_data = PATHFINDING.calculate_local_path(
                                                    owner.x,
                                                    owner.y,
                                                    itinerary_item.target_location.pos.x,
                                                    itinerary_item.target_location.pos.y,
                                                );
                                                if new_path_data == undefined {
                                                    err = PATHFINDING.last_error;
                                                } else {
                                                    itinerary_item.local_path = new_path_data.output_list;
                                                    itinerary_item.local_path_distance = new_path_data.distance;
                                                }
                                            }

                                            for (var i = 0, c = blocked_poses.count(); i < c; i++) {
                                                var square = blocked_poses.get(i);
                                                PATHFINDING.set_local_position_is_taken(
                                                    square mod GRID.dims.x,
                                                    square div GRID.dims.x,
                                                    false
                                                );
                                            }

                                            //
                                            if err != undefined {
                                                self.active_block = { stage: 0, timer: fiddle_get("misc/npc_behavior/path_block_bark_delay") };
                                                return;
                                            }

                                            self.active_block = undefined;
                                        }
                                    }
                                    return;
                                }
                            }

                            //
                            self.owner.position.set(self.owner);
                            self.owner.move_spd.set_zero();

                            //
                            switch self.owner.pathfinding_agent.move_along_path() {
                                case MoveAlongPathResponse.Ok:
                                    if self.can_reset {
                                        self.blackboard.set("secondary_pathfinding_actor", false);
                                        self.can_reset = false;
                                    }

                                    bop_along_path();
                                    break;
                                case MoveAlongPathResponse.Err:
                                    switch self.owner.pathfinding_agent.err_response {
                                        case PathfindingPathErrKind.Npc:
                                            if self.blackboard.get("secondary_pathfinding_actor") {
                                                self.can_reset = true;
                                                bop_along_path();
                                            } else {
                                                var blocked_squares = self.owner.pathfinding_agent.squares_to_check();

                                                //
                                                var final_position = self.owner.pathfinding_agent.todo_list().first();
                                                final_position = final_position.x + final_position.y * GRID.dims.x;
                                                var current_position = self.owner.x div 8 + (self.owner.y div 8) * GRID.dims.x;

                                                var crash_on_invalid_end = false;

                                                for (var i = 0, c = array_length(blocked_squares); i < c; i++) {
                                                    var square = blocked_squares[i];
                                                    if square == undefined {
                                                        break;
                                                    }

                                                    var vec1_square_id = square.x div 8 + (square.y div 8) * GRID.dims.x;
                                                    //
                                                    if vec1_square_id == current_position {
                                                        continue;
                                                    }

                                                    var reservation = PATHFINDING.reservation(vec1_square_id);

                                                    //
                                                    //
                                                    if reservation != undefined
                                                        && reservation.agent_kind == PathfindingAgentKind.Npc
                                                        && owner.pathfinding_agent.meddler != undefined
                                                        && reservation.id != owner.pathfinding_agent.meddler.id
                                                    {
                                                        var other_npc_is_pathfinding = reservation.owner.fsm.current_state_id() == NpcState.Pathfinding;
                                                        if vec1_square_id == final_position && other_npc_is_pathfinding == false {
                                                            error(
                                                                "{NpcId} is in position {}, but {NpcId} wants to pathfind to that spot as well.",
                                                                reservation.owner.me.id,
                                                                self.owner.pathfinding_agent.todo_list().first(),
                                                                self.owner.me.id,
                                                            );
                                                            crash_on_invalid_end = true;
                                                        }

                                                        if other_npc_is_pathfinding {
                                                            reservation.owner.fsm.blackboard.set("secondary_pathfinding_actor", true);
                                                        }

                                                        PATHFINDING.set_local_position_is_taken(square.x div 8, square.y div 8, true);
                                                    }
                                                }

                                                //
                                                var err = undefined;
                                                {
                                                    var itinerary_item = self.itinerary.items.get(self.itinerary.cursor);
                                                    var new_path_data = PATHFINDING.calculate_local_path(
                                                        owner.x,
                                                        owner.y,
                                                        itinerary_item.target_location.pos.x,
                                                        itinerary_item.target_location.pos.y,
                                                    );

                                                    if new_path_data == undefined {
                                                        err = PATHFINDING.last_error;
                                                    } else {
                                                        itinerary_item.local_path = new_path_data.output_list;
                                                        itinerary_item.local_path_distance = new_path_data.distance;
                                                    }
                                                }

                                                for (var i = 0, c = array_length(blocked_squares); i < c; i++) {
                                                    var square = blocked_squares[i];
                                                    if square == undefined {
                                                        break;
                                                    }

                                                    PATHFINDING.set_local_position_is_taken(square.x div 8, square.y div 8, false);
                                                }

                                                if err != undefined {
                                                    if err == PathfindErr.InvalidEndUnit && crash_on_invalid_end {
                                                        impossible("could not create path or gracefully handle it: {PathfindErr}", err);
                                                    }

                                                    //
                                                    var itinerary_item = self.itinerary.items.get(self.itinerary.cursor);
                                                    var new_path_data = PATHFINDING.calculate_local_path(
                                                        owner.x,
                                                        owner.y,
                                                        itinerary_item.target_location.pos.x,
                                                        itinerary_item.target_location.pos.y,
                                                    );
                                                    assert_neq(new_path_data, undefined, "failed to build fallback path for {NpcId} / {}", owner.npc_id, PATHFINDING.last_error);
                                                    itinerary_item.local_path = new_path_data.output_list;
                                                    itinerary_item.local_path_distance = new_path_data.distance;

                                                    //
                                                    self.blackboard.set("secondary_pathfinding_actor", true);
                                                }
                                            }
                                            break;
                                        case PathfindingPathErrKind.Player:
                                            //
                                            self.active_block = { stage: 0, timer: fiddle_get("misc/npc_behavior/path_block_bark_delay") };
                                            break;

                                        //
                                        case PathfindingPathErrKind.Animal:
                                        case PathfindingPathErrKind.NewCollision:
                                            bop_along_path();
                                            break;
                                        default: impossible("unexpected err type {}", err);
                                    }

                                    break;
                                default: impossible("unexpected move along path response");
                            }
                        })
                        .end_step(function() {
                            if self.manual_halt || self.owner.kissing {
                                return;
                            }

                            pathfinding_util_end_step();

                            //
                            //
                            //
                            if self.owner.move_spd.is_zero() == false {
                                var cardinality = self.owner.move_spd.cardinality_heuristic();
                                self.owner.me.set_cardinality(cardinality);
                            }
                        })
                        .draw(function() {
                            var ratio = DISPLAY.asset_resize();
                            var draw_x = floor(owner.x * ratio) / ratio;
                            var draw_y = floor(owner.y * ratio) / ratio + owner.y_offset;

                            if self.manual_halt == false {
                                self.owner.image_index = self.active_block != undefined ? 0 : owner.image_index;
                                self.owner.anim_speed = self.active_block != undefined ? 0 : 1;

                                if owner.npc_id == NpcId.Dozy && self.active_block != undefined {
                                    //
                                    var card_to_use = self.owner.animator.cardinality == Cardinal.West
                                        ? Cardinal.East
                                        : self.owner.animator.cardinality;
                                    self.owner.sprite_index = string_to_asset(format("spr_npc_dozy_spring_idle_{}", cardinal_to_string(card_to_use)));
                                }
                            }
                            draw_sprite_ext(self.owner.sprite_index, self.owner.image_index, draw_x, draw_y, self.owner.image_xscale, 1, 0, self.owner.image_blend, self.owner.image_alpha);
                        })
                        .spawn()
                    )
                    .add_state(StateBuilder(NpcState.Dummy)
                        .start(function() {
                            if self.owner.me.is_seated() {
                                self.owner.me.set_animation("sit");
                            } else {
                                self.owner.me.set_animation("idle");
                            }
                            self.exit_condition = self.blackboard.try_take("dummy_exit_condition", DummyExitCondition.Never);
                            self.exit_callback = self.blackboard.try_take("dummy_exit_callback");
                            self.timer = 0;
                            self.active = false;
                        })
                        .step(function() {
                            if self.blackboard.try_take("start_dummy_walk") {
                                self.active = true;
                                self.owner.me.set_animation(self.owner.get_walk_animation());
                            }
                            if self.active {
                                self.owner.move_spd.x = lengthdir_x(self.owner.move_accel.x, cardinal_to_angle(self.owner.animator.cardinality));
                                self.owner.move_spd.y = lengthdir_y(self.owner.move_accel.y, cardinal_to_angle(self.owner.animator.cardinality));
                            }
                        })
                        .end_step(function() {
                            if !self.active {
                                return;
                            }
                            self.owner.update_position();
                            var complete = false;
                            switch self.exit_condition.type {
                                case DummyExitConditionId.Position:
                                    if self.owner.position.eq_floored(self.exit_condition.position) {
                                        complete = true;
                                    }
                                    break;
                                case DummyExitConditionId.Timer:
                                    self.timer += 1;
                                    if self.timer == self.exit_condition.timer_max {
                                        complete = true;
                                    }
                                    break;
                                case DummyExitConditionId.Never:
                                    break;
                                default: impossible("Unexpected DummyExitConditionid: {}", self.exit_condition.type);
                            }
                            if complete {
                                if self.owner.me.itinerary != undefined {
                                    self.fsm.change_state(NpcState.Pathfinding);
                                } else {
                                    self.fsm.change_state(NpcState.Default);
                                }
                                self.exit_callback();
                            }
                        })
                        .draw(function() {
                            var ratio = DISPLAY.asset_resize();
                            var draw_x = floor(owner.x * ratio) / ratio;
                            var draw_y = floor(owner.y * ratio) / ratio + owner.y_offset;

                            draw_sprite_ext(self.owner.sprite_index, self.owner.image_index, draw_x, draw_y, self.owner.image_xscale, 1, 0, self.owner.image_blend, self.owner.image_alpha);
                        })
                        .spawn()
                    )
            }

            function update_cardinality() {
                self.image_xscale = self.me.cardinality != Cardinal.West ? 1 : -1;
                self.animator.set_cardinality(self.me.cardinality);
            }

            function update_animation() {
                //
                var sprite_pack_collection = self.me
                    .wardrobe
                    .outfit_current
                    .cycles
                    .get(self.me.animation);

                //
                if is_nullish(sprite_pack_collection) {
                    sprite_pack_collection = self.me
                        .wardrobe
                        .outfits
                        .get(self.me.prototype.fallback_outfit)
                        .cycles
                        .get(self.me.animation);
                }

                //
                if is_nullish(sprite_pack_collection) {
                    sprite_pack_collection = self.me
                        .wardrobe
                        .outfits
                        .get(self.me.prototype.fallback_outfit)
                        .cycles
                        .get("idle");
                }

                //
                assert_neq(
                    sprite_pack_collection,
                    undefined,
                    "{NpcId} does not have animation '{}'",
                    self.me.id,
                    self.me.animation,
                );

                if sprite_pack_collection != self.animator.sprite_pack_collection {
                    self.animator.set_animation(sprite_pack_collection);
                    self.drink_animation = undefined;
                }

                self.clean_eat_and_drink();
                if self.me.animation == "eat" && !self.me.is_animal() { //
                    self.setup_eating();
                } else if self.me.animation == "drink" {
                    self.setup_drinking();
                }
            }

            function try_draw_child() {
               var child = self.me.held_child();

                if child == undefined {
                    return;
                }

                var sprite = try_string_to_asset(format(
                    "spr_npc_{NpcId}_baby_{ChildId}_{ChildSkinTone}_{}_{Cardinal}",
                    self.me.id,
                    child.id,
                    child.skin_tone,
                    self.me.animation,
                    self.me.cardinality == Cardinal.West ? Cardinal.East : self.me.cardinality,
                ));

                if sprite == undefined {
                    return;
                }


                var ratio = DISPLAY.asset_resize();
                var draw_x = floor(self.x * ratio) / ratio;
                var draw_y = floor(self.y * ratio) / ratio + self.y_offset;

                draw_sprite_ext(
                    sprite,
                    self.image_index,
                    draw_x,
                    draw_y,
                    self.image_xscale,
                    1,
                    0,
                    self.image_blend,
                    self.image_alpha,
                );
            }

            function get_walk_animation() {
                if !MIST.is_running() {
                    return "walk";
                }
                var val = MIST.blackboard.get(format("{NpcId}_walk_animation_override", self.npc_id));
                return val ?? "walk";
            }

            function clean_eat_and_drink() {
                if self.eat_animation != undefined && instance_exists(self.eat_animation) {
                    instance_destroy(self.eat_animation);
                    self.eat_animation = undefined;
                }
                if self.eat_plate != undefined && instance_exists(self.eat_plate) {
                    instance_destroy(self.eat_plate);
                    self.eat_plate = undefined;
                }

                T2R.write(format("{NpcId}_eating", self.npc_id), undefined);
                T2R.write(format("{NpcId}_drinking", self.npc_id), undefined);
            }

            //
            //
            function setup_eating(eat_anim_item_id) {
                //
                self.clean_eat_and_drink();

                //
                self.animator.set_index(irandom(self.animator.current.info.num_subimages - 1));

                if eat_anim_item_id == undefined {
                    var cranched_number = (self.x * self.y * self.me.id) % (CALENDAR.time + 1);

                    var inn_items = INN_STOCK.fold(List(), function(a, v) {
                        a.copy_from(v.items);
                        return a;
                    });

                    for (var i = 0; i < 100; i++) {
                        var maybe = inn_items.choose_random(cranched_number + i).item_id;

                        var proto = ITEM_PROTOTYPES[maybe];
                        if proto.use == ItemUse.Consume && proto.tags.contains("drink") == false {
                            eat_anim_item_id = maybe;
                            break;
                        }
                    }


                    if eat_anim_item_id == undefined {
                        var items = List();
                        for (var i = 0; i < ItemId.LEN; i++) {
                            if ITEM_PROTOTYPES[i].tags.contains("food") {
                                items.push(i);
                            }
                        }

                        eat_anim_item_id = items.choose_random();
                    }
                }

                var xx = self.x;
                var yy = self.y;

                var bundle = fiddle_get(format("misc/eating/{Cardinal}", self.animator.cardinality));

                xx += bundle.offset[0];
                yy += bundle.offset[1];

                var plate = string_to_asset(bundle.plate);

                var renderer = instance_create_layer(
                    xx,
                    yy,
                    "Instances",
                    obj_assetobject,
                    {
                        sprite_index: ITEM_PROTOTYPES[eat_anim_item_id].icon_sprite,
                        z: -8,
                    }
                );
                T2R.write(format("{NpcId}_eating", self.npc_id), item_id_to_string(eat_anim_item_id));
                T2R.write(format("{NpcId}_drinking", self.npc_id), undefined);

                var plate_renderer = undefined;

                if ITEM_PROTOTYPES[eat_anim_item_id].tags.contains("inn_plate") {
                    plate_renderer = instance_create_layer(
                        xx,
                        yy,
                        "Instances",
                        obj_assetobject,
                        {
                            sprite_index: plate,
                            z: -7,
                        }
                    );
                    plate_renderer.z -= 7;
                }

                self.eat_animation = renderer;
                self.eat_plate = plate_renderer;
            }

            function setup_drinking() {

                //
                self.clean_eat_and_drink();

                var cardy = self.animator.cardinality == Cardinal.West ? Cardinal.East : self.animator.cardinality;

                //
                self.animator.set_index(irandom(self.animator.current.info.num_subimages - 1));

                var prefs = fiddle_get(format("npcs/{NpcId}/drink_preferences", self.me.id));

                var options = ["water"];
                if T2R.read(format("{NpcId}_can_drink", self.npc_id)) != false {
                    for (var i = CLOCK.hour(); i >= 6; i--) {
                        var data_on_hour = prefs[$ string(i)];
                        if data_on_hour != undefined {
                            options = data_on_hour;
                            break;
                        }
                    }
                }

                var cranched_number = (self.x * self.y * self.me.id) % (CALENDAR.time + 1);
                random_set_seed(cranched_number);
                var idx = irandom_range(0, array_length(options) - 1);
                randomize();

                T2R.write(format("{NpcId}_eating", self.npc_id), undefined);
                T2R.write(format("{NpcId}_drinking", self.npc_id), options[idx]);
                if cardy != Cardinal.North {
                    var asset = fiddle_get(format("misc/npc_drinks/{}/{Cardinal}", self.drink_override ?? options[idx], cardy));
                    self.drink_animation = string_to_asset(asset);
                } else {
                    self.drink_animation = undefined;
                }

            }

            function setup_kiss_particle() {
                new_world_chain(self, CURRENT_LOCATION_ID)
                    .append(LinkId.Await, function() {
                        return self.me.animation == "kiss";
                    })
                    .append(LinkId.Timer, 120)
                    .append(LinkId.Function, function() {
                        if self.kissing == false {
                            return;
                        }
                        if self.kiss_particle != undefined {
                            instance_destroy(self.kiss_particle);
                        }
                        self.kiss_sound = TANGO.play("SoundEffects/SpecialEvents/KissStart");
                        self.kiss_particle = instance_create_depth(self.x + 8 * self.image_xscale, self.y, self.depth - 1, obj_animation_effect);
                        self.kiss_particle.sprite_index = spr_fx_kiss_start;
                        self.kiss_particle.image_idx = sprite_get_number(spr_fx_kiss_start);
                        self.kiss_particle.live_on_anim_end = true;
                        self.kiss_particle.image_idx_func = function() {
                            self.kiss_particle.sprite_index = spr_fx_kiss_loop;
                        }
                    })
                    .append(LinkId.Await, function() {
                        if self.kissing == false {
                            return true;
                        }

                        if !INPUT.check(InputId.SecondaryInteract) {
                            if self.kiss_particle == undefined {
                                return true;
                            }
                            self.kiss_particle.image_idx = sprite_get_number(spr_fx_kiss_loop);
                            self.kiss_particle.image_idx_func = function() {
                                new_chain()
                                    .append(LinkId.Timer, 1) //
                                    .append(LinkId.Function, function() {
                                        if self.kiss_particle == undefined {
                                            return;
                                        }
                                        self.kiss_particle.image_idx = sprite_get_number(spr_fx_kiss_end);
                                        self.kiss_particle.sprite_index = spr_fx_kiss_end;
                                        self.kiss_particle.image_idx_func = function() {
                                            instance_destroy(self.kiss_particle);
                                            self.kiss_particle = undefined;
                                        };
                                    })
                            }
                            return true;
                        }
                        return false;
                    })
            }

            //
            function handle_thinking() {
                if self.bark_emitter.is_barking() || self.chat_partner != undefined || MIST.running {
                    return;
                }

                static INTERVAL = fiddle_get("misc/npc_behavior/thought_interval");
                if self.think_timer == undefined {
                    self.think_timer = irandom_range(INTERVAL[0], INTERVAL[1])
                }
                self.think_timer -= 1;
                if self.think_timer <= 0 {
                    var bark = irandom(BarkId.LEN - 1);
                    while BANNED_BARKS.contains(bark) {
                        bark = irandom(BarkId.LEN - 1);
                    }
                    self.bark_emitter.emit(bark, BarkType.Thought);
                    self.think_timer = irandom_range(INTERVAL[0], INTERVAL[1]);
                }
            }

            //
            function handle_chatting() {
                static MAX_DIST = fiddle_get("misc/npc_behavior/max_chat_distance");
                static INTERVAL = fiddle_get("misc/npc_behavior/chat_interval");
                static CUTSCENE_INTERVAL = fiddle_get("misc/npc_behavior/cutscene_chat_interval");
                static SCAN_FREQ = fiddle_get("misc/npc_behavior/chat_scan_frequency");

                //
                if self.chat_partner == undefined && !MIST.running {
                    if self.chat_scan_timer == undefined {
                        self.chat_scan_timer = irandom(SCAN_FREQ);
                    }
                    self.chat_scan_timer = wrap(self.chat_scan_timer - 1, SCAN_FREQ);
                    if self.chat_scan_timer == 0 {

                        //
                        var npcs_present = instance_number(par_NPC);
                        var closest_npc = undefined;
                        for (var i = 0; i < npcs_present; i++) {
                            var npc = instance_find(par_NPC, i);
                            if npc.id == self.id {
                                continue;
                            }

                            //
                            var distance = point_distance(npc.x, npc.y, self.x, self.y);
                            var within_range = distance <= MAX_DIST && self.zone == npc.zone;
                            var already_chatting = npc.chat_partner != undefined;
                            if within_range
                                && !already_chatting
                                && npc.fsm.current_state_id() == NpcState.Default
                                && (closest_npc == undefined || distance < closest_npc.distance)
                            {
                                closest_npc = {
                                    id: npc.me.id,
                                    distance: distance,
                                }
                            }

                            //
                            if closest_npc != undefined {
                                self.chat_with(closest_npc.id);
                            }
                        }
                    }
                } else {
                    //
                    //
                    if self.chat_partner == undefined
                        || !instance_exists(self.chat_partner)
                        || !(MIST.running || point_distance(self.x, self.y, self.chat_partner.x, self.chat_partner.y) < MAX_DIST)
                    {
                        self.chat_partner = undefined;
                        self.chat_timer = undefined;

                        //
                        if MIST.running == false {
                            var trellis_point = trellis_point_by_location_position(self.me.location_position);
                            if trellis_point != undefined {
                                //
                                self.me.set_cardinality(trellis_point.direction);
                            }
                        }

                        return;
                    }

                    //
                    self.chat_timer -= 1;
                    if self.chat_timer <= 0 && !self.chat_partner.bark_emitter.is_barking() {
                        var bark = irandom(BarkId.LEN - 1);
                        while BANNED_BARKS.contains(bark) {
                            bark = irandom(BarkId.LEN - 1);
                        }
                        self.bark_emitter.emit(bark, BarkType.Speech);
                        self.chat_timer = irandom_range(INTERVAL[0], INTERVAL[1]);
                    }
                }
            }

            function animate() {
                self.image_speed = 0; //
                self.animator.animate(self.anim_speed);
                self.sprite_index = self.animator.sprite();
                self.image_index = self.animator.index();
                self.image_xscale = self.animator.cardinality != Cardinal.West ? 1 : -1;
                if self.animator.animation_is_over && self.reset_cycle_name != undefined {
                    self.me.set_cardinality(self.reset_cycle_cardinality ?? self.me.cardinality);
                    self.me.set_animation(self.reset_cycle_name);
                    self.reset_cycle_name = undefined;
                    self.reset_cycle_cardinality = undefined;
                }
            }

            function dummy_walk_out_of_room() {
                self.fsm.blackboard.set("dummy_exit_condition", DummyExitCondition.Timer(60));
                self.fsm.blackboard.set("dummy_exit_callback", function() {
                    self.me.simulated_distance_traveled = 0;
                    instance_destroy(self.id);
                })
                self.fsm.change_state_instant(NpcState.Dummy);
            }

            //
            function talk(conversation, cb, args) {
                //
                obj_ari.face_dir(cardinal_to_inverse(angle_to_cardinal(point_direction(self.x, self.y, obj_ari.x, obj_ari.y))) * 90);
                obj_ari.set_idle_simple();
                obj_ari.par.unset_modifier(AnimationName.Blink);

                //
                play_conversation(self.npc_id, conversation, cb, args);

                if string_pos("basement_line", conversation) != 0 {
                    array_push(GAME_STATS.basement_lines, {
                        npc: npc_id_to_string(self.me.id),
                        day: total_days(),
                        hour: CLOCK.hour(),
                        minute: CLOCK.minute(),
                        position: string(self.me.location_position),
                    });
                }
            }

            //
            function receive_gift(item) {
                var data = self.me.give_gift(item);
                self.bark_emitter.emit(data.bark);
                self.talk(data.convo);
            }

            //
            function my_query_quests() {
                static OUTPUT = List();
                OUTPUT.clear();
                var active_quest_names = QUEST_LOG.active.keys();
                for (var i = 0, c = array_length(active_quest_names); i < c; i++) {
                    var quest_data = QUEST_LOG.active.get(active_quest_names[i]);
                    var task = quest_data.quest.tasks.get(quest_data.current_stage);
                    var my_npc_query = task.query_targets.find(function(qt, my_id) {
                        return qt.type == QuestQueryType.Npc && qt.npc_name == my_id;
                    }, self.npc_id);

                    if my_npc_query != undefined
                        && fulfills_all_requirements(task.requirements, quest_data.blackboard, QUEST_LOG.blackboard)
                    {
                        OUTPUT.push([quest_data, active_quest_names[i], task.query_targets.get(my_npc_query).npc_conversation]);
                    }
                }

                return OUTPUT;
            }

            function update_talk_status() {
                self.possible_next_conversation = T2R.request_conversation(self.npc_id);
                self.conversation_available = self.possible_next_conversation != undefined;

                self.is_group_conversation = false;
                if self.possible_next_conversation != undefined {
                    self.is_group_conversation = T2R.conversation_is_group(self.possible_next_conversation);
                }
            }

            function can_talk() {
                return self.me.talk_flag && self.fsm.current_state_id() != NpcState.Dummy;
            }

            function chat_with(other_npc_id) {
                static INTERVAL = fiddle_get("misc/npc_behavior/chat_interval");
                static CUTSCENE_INTERVAL = fiddle_get("misc/npc_behavior/cutscene_chat_interval");

                var other_npc = instance_find(npc_id_to_gm_obj_id(other_npc_id), 0);
                assert_neq(
                    other_npc,
                    undefined,
                    "{NpcId} attempted to chat with {NpcId}, who was not present in the current room.",
                    self.npc_id,
                    other_npc_id,
                );

                self.chat_partner = other_npc;
                other_npc.chat_partner = self;

                var max_time = MIST.running ? CUTSCENE_INTERVAL[1] : INTERVAL[1];
                self.chat_timer = irandom(max_time);
                other_npc.chat_timer = irandom(max_time);

                if self.me.animation == "idle" {
                    self.me.set_cardinality(angle_to_cardinal(point_direction(self.x, self.y, other_npc.x, other_npc.y)));
                }
                if other_npc.me.animation == "idle" {
                    other_npc.me.set_cardinality(angle_to_cardinal(point_direction(other_npc.x, other_npc.y, self.x, self.y)));
                }
            }

            //
            function initialize(npc, override_state) {
                self.me = npc;
                self.update_cardinality();
                self.update_animation();
                self.animate(0);
                self.drink_offset = fiddle_get(format("npcs/{NpcId}", self.me.id))[$ "drink_offset"] ?? 0;
                self.me.brain.blackboard.set("instance",self.id);

                var initial_state = NpcState.Default;
                if self.me.itinerary != undefined {
                    initial_state = NpcState.Pathfinding;
                }
                if override_state != undefined {
                    initial_state = override_state;
                }
                self.fsm = self.create_default_fsm().spawn(initial_state, self, Map());

                if self.me.is_animal() && self.me.is_roommate() && self.me.at_farm() {
                    var success = try_position_pet();
                    if !success {
                        warn("Failed to place {NpcId} -- moving to safe location", self.npc_id);
                        var pos = player_home_safe_position(CURRENT_LOCATION_ID);
                        self.x = pos.x;
                        self.y = pos.y;
                    }
                    self.me.location_position = new LocationPosition(CURRENT_LOCATION_ID, Vec2(self.x, self.y));
                }
            }

            //
            function update_dialogue_pip() {
                self.bouncer.status = InteractBounceStatus.None;
                //
                //
                if self.can_talk() == false || MIST.running || instance_exists(obj_ari) == false || obj_ari.is_mounted() {
                    return;
                }

                self.bouncer.status = InteractBounceStatus.Distant;
                var target = 0;
                if distance_to_ari_interactable() < self.interact_distance {
                    target = BARK_MIN_ALPHA;
                }
                self.bouncer.alpha = approach(self.bouncer.alpha, target, BARK_FADE_SPEED);

                self.bouncer.update();
            }

            //
            move_accel = Vec2(HUMAN_WALK_SPEED, HUMAN_WALK_SPEED);

            //
            move_spd = Vec2(0, 0);

            //
            position = Vec2Object(self);
            self.pathfinding_agent = new PathfindingAgent(new PathfindingMeddler(PathfindingAgentKind.Npc, self));

            self.npc_id = gm_obj_id_to_npc_id(object_index);
            self.debug_name = npc_id_to_string(self.npc_id);
            self.animator = new NpcAnimationHandler(self)
            self.anim_speed = 1;
            self.reset_cycle_name = undefined;
            self.reset_cycle_cardinality = undefined;
            self.bark_emitter = new BarkEmitter(self, 0, -38);
            self.bark_emitter.modifier = function(bark_id) {
                if bark_id == BarkId.RelationshipStatus {
                    return self.me.is_partner()
                        ? BarkId.Heart
                        : BarkId.CuteFace;
                } else {
                    return bark_id;
                }
            }
            self.chat_partner = undefined;
            self.chat_scan_timer = undefined;
            self.chat_timer = undefined;
            self.think_timer = undefined;
            self.eat_animation = undefined;
            self.eat_plate = undefined;
            self.drink_animation = undefined;
            self.drink_offset = undefined;
            self.possible_next_conversation = undefined;
            self.conversation_available = false;
            self.want_to_talk_timer = 0;
            self.needs_talk_status_update = true;
            self.hold_power = undefined;
            self.withhold_pip = false;
            self.is_group_conversation = false;
            self.restore_animation = undefined;
            self.restore_cardinality = undefined;
            self.zone = T2R.read(format("{NpcId}_zone", self.npc_id));

            self.heart_particle_bundle = new ParticleBundle()
                .set_animate(true)
                .set_follow_object(self.id)
                .set_speed(0.3)
                .set_speed_increase(-0.01)
                .set_gravity(0)
                .set_gravity_increase(-0.03)
                .set_sway(true)
                .set_sway_dir(270)
                .set_rotation_speed(0);

            self.interactable_mode = InteractableMode.Circle;
            var f_i = fiddle_get("interaction/npcs");
            self.circle_size = f_i.circle_size;
            self.interact_distance = f_i.distance;
            self.interact_nudge_distance = f_i.nudge_distance;
            self.offset_with_cardinal = true;

            self.bounce_y_offset = undefined;
            switch npc_id {
                case NpcId.Dell:
                    self.bark_emitter.y_offset = -34;
                    self.bounce_y_offset = -22;
                    break;
                case NpcId.Dozy:
                    self.bark_emitter.y_offset = -33;
                    self.bounce_y_offset = -21;
                case NpcId.Henrietta:
                    self.bark_emitter.y_offset = -30;
                    self.bounce_y_offset = -18;
                    break;
                case NpcId.Luc:
                    self.bark_emitter.y_offset = -33;
                    self.bounce_y_offset = -21;
                    break;
                case NpcId.Maple:
                    self.bark_emitter.y_offset = -35;
                    self.bounce_y_offset = -23;
                    break;
                default:
                    self.bark_emitter.y_offset = -38;
                    self.bounce_y_offset = -26;
                    break;
            }

            self.register_interaction(
                InputId.Interact,
                "misc_local/talk",
                function() {
                    self.possible_next_conversation = T2R.request_conversation(self.npc_id);
                    if self.possible_next_conversation != undefined {
                        self.talk(self.possible_next_conversation);
                    }
                },
                function() {
                    return self.can_talk()
                        && (self.npc_id != NpcId.Caldarus || !caldarus_is_sleeping())
                        && self.my_query_quests().is_empty()
                        && ari_can_talk();
                }
            );

            self.register_interaction(
                InputId.Interact,
                "misc_local/turn_in_quest_input",
                function() {
                    var quest_blobs = self.my_query_quests();
                    if quest_blobs.count() > 1 {
                        create_options_popup(
                            "misc_local/select_a_quest",
                            quest_blobs,
                            function(blob) {
                                return local_get(blob[0].quest.name);
                            },
                            function(blob) {
                                create_quest_turn_in_popup(blob[0], blob[1], self.npc_id, blob[2]);
                            },
                            undefined,
                            1,
                        )
                    } else {
                        var quest_blob = quest_blobs.first();
                        create_quest_turn_in_popup(quest_blob[0], quest_blob[1], self.npc_id, quest_blob[2]);
                    }
                },
                function() {
                    return !self.my_query_quests().is_empty()
                        && (self.npc_id != NpcId.Caldarus || !caldarus_is_sleeping())
                        && (instance_exists(obj_ari) == false || obj_ari.is_mounted() == false);
                }
            );

            self.register_interaction(
                InputId.Throw,
                "misc_local/propose",
                function() {
                    if self.npc_id == NpcId.Caldarus && !requirements_pass(Requirement.ClosedFinalSeal) {
                        self.talk(GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.CaldarusProposalEdgeCase]);
                    } else {
                        self.talk(format(
                            "Cutscenes/Heart Events/{}/{NpcId}_ten_hearts/engagement_ring_{NpcId}",
                            capitalize(npc_id_to_string(self.npc_id)),
                            self.npc_id,
                            self.npc_id,
                        ));
                    }
                },
                function() {
                    var held_item = ARI.held_item();
                    if held_item == undefined {
                        return false;
                    }

                    return held_item.item_id == ItemId.EngagementRing
                        && self.me.heart_level() >= 10
                        && self.me.is_dating()
                        && ARI.fiance() == undefined
                        && ARI.spouse() == undefined;
                }
            )

            self.register_interaction(
                InputId.Throw,
                "misc_local/discuss",
                function() {
                    var anim = self.me.animation;
                    self.me.set_animation(self.me.is_seated() ? "sit" : "idle");
                    self.talk(
                        format("Conversations/family_planning/family_planning_{NpcId}", self.npc_id),
                        function(_, anim) {
                            if T2R.read("pending_stork_visit") == true {
                                remove_item_from_world(ItemId.MysticalFeather);
                            }
                            self.me.set_animation(anim);
                        },
                        [anim]
                    );
                },
                function() {
                    var held_item = ARI.held_item();
                    if held_item == undefined {
                        return false;
                    }

                    return held_item.prototype.item_id == ItemId.MysticalFeather
                        && self.me.is_spouse()
                        && ARI.pending_child == undefined;
                }
            )

            self.register_interaction(
                InputId.Throw,
                "misc_local/give_item",
                function() {
                    var held_item = ARI.inventory.slot(ARI.held_item_index).pop();
                    self.receive_gift(held_item);
                },
                function() {
                    if ari_can_talk() == false {
                        return false;
                    }

                    if !self.me.gift_flag {
                        return false;
                    }
                    if self.npc_id == NpcId.Caldarus && caldarus_is_sleeping() {
                        return false;
                    }
                    var held_item = ARI.held_item();
                    return
                        held_item != undefined
                        && held_item.prototype.giftable
                        && !held_item.prototype.tags.contains_any_value_from(self.me.prototype.banned_gift_tags)
                        && npc_is_unlocked(self.npc_id);
                }
            );

            self.register_interaction(
                InputId.Throw,
                "misc_local/invite_on_date",
                function() {
                    date_selection_ui(self.npc_id);
                },
                function() {
                    return self.me.can_go_on_dates()
                        && ari_eligible_for_date(self.npc_id)
                        && npc_is_unlocked(self.npc_id)
                        && self.me.animation != "sleep";
                }
            );

            var valid_date_target = false;
            for (var i = 0; i < FestivalId.LEN; i++) {
                var festival = FESTIVALS[i];
                if festival.is_today() && festival.prototype.npc_date != undefined {

                    //
                    var participants = FESTIVALS[i].prototype.npc_date.participants;
                    valid_date_target = participants[$ npc_id_to_string(self.npc_id)] != undefined;
                    break;
                }
            }

            if valid_date_target && npc_is_unlocked(self.npc_id) {
                self.register_interaction(
                    InputId.Throw,
                    festival.prototype.interact_local,
                    function() {
                        var festival_id = todays_festival();
                        var data = FESTIVALS[festival_id].prototype;
                        var my_data = data.npc_date.participants[$ npc_id_to_string(self.npc_id)];
                        var line = undefined;
                        var accepts = true;
                        if self.me.is_best_friend() {
                            line = my_data.friend_decline_line;
                            accepts = false;
                        } else if my_data.super_accept != undefined && requirements_pass(my_data.super_accept.requirements)  {
                            line = my_data.super_accept.line;
                        } else if requirements_pass(my_data.basic_accept.requirements) {
                            line = my_data.basic_accept.line;
                        } else {
                            line = my_data.decline_line;
                            accepts = false;
                        }

                        //
                        if festival_id == FestivalId.Harvest
                            && self.npc_id == NpcId.Caldarus
                            && accepts
                            && requirements_pass(Requirement.ClosedFinalSeal)
                        {
                            line = GpTriggeredConversation.HarvestCaldarusBasicAcceptEog;
                        }

                        var cb = undefined;

                        if accepts {
                            if data.npc_date.item != undefined {
                                ARI.inventory.slot(ARI.held_item_index).pop();
                            }
                            ARI.festival_date_partner = self.npc_id;
                            T2R.write(
                                format("{FestivalId}_date_partner", festival_id),
                                npc_id_to_string(self.npc_id),
                            );

                            //
                            self.me.add_heart_points(fiddle_get("misc/gift_giving/hearts/birthday_boost"));
                            //
                            if data.npc_date.manual {
                                cb = function(_, _data, festival_id, npc_id) {
                                    t2_write_world_fact(format("{FestivalId}_date_partner", festival_id), npc_id_to_string(npc_id));
                                    //
                                    start_date_cutscene(ARI.festival_date_partner, Date.HarvestDance);
                                }
                            }
                        }

                        self.talk(GAMEPLAY_CONVERSATIONS[line], cb, [data, festival_id, npc_id]);
                    },
                    function() {
                        if !npc_is_unlocked(self.npc_id) {
                            return false;
                        }

                        if instance_exists(obj_ari) && obj_ari.is_mounted() {
                            return false;
                        }
                        if ARI.festival_date_partner != undefined {
                            return false;
                        }

                        //
                        if ARI.spouse() != undefined && !self.me.is_partner() {
                            return false;
                        }

                        var held_item = ARI.held_item();

                        for (var i = 0; i < FestivalId.LEN; i++) {
                            var festival = FESTIVALS[i];
                            var festival_check = undefined;
                            if festival.is_today() && festival.prototype.npc_date != undefined {
                                festival_check = festival;
                                break;
                            }
                        }

                        if festival_check == undefined {
                            return false;
                        }

                        if festival_check.prototype.npc_date.item == undefined {
                            return true;
                        }

                        return
                            held_item != undefined
                            && held_item.item_id == festival_check.prototype.npc_date.item;
                    }
                );
            }

            self.register_interaction(
                InputId.Throw,
                "misc_local/go_to_festival",
                function() {
                    var popup = popup_creator("misc_local/go_to_festival", "misc_local/go_to_shooting_star_confirmation");
                    popup.create_button("misc_local/not_yet");
                    popup.create_button("misc_local/yes", function() {
                        goto_location_id(LocationId.Summit);
                    });
                    popup.spawn();
                },
                function() {
                    return (instance_exists(obj_ari) == false || obj_ari.is_mounted() == false)
                        && CLOCK.time >= NIGHT_TIME
                        && ARI.festival_date_partner == self.npc_id
                        && FESTIVALS[FestivalId.ShootingStar].is_today()
                        && npc_is_unlocked(self.npc_id);
                }
            );


            self.register_interaction(
                //
                //
                //
                //
                //
                InputId.Throw,
                "misc_local/hold_child",
                function() {
                    self.me.held_child().set_location(ChildLocation.WithAri);
                },
                function() {
                    return self.me.held_child() != undefined && ARI.held_child() == undefined;
                }
            );

            self.register_interaction(
                //
                InputId.Throw,
                "misc_local/give_child",
                function() {
                    self.talk(GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.TakeBaby], function() {
                        if ANCHOR.get_menu(Menu.Textbox).driver.prompt_index_selected == 0 {
                            ARI.held_child().set_location(ChildLocation.WithSpouse);
                        }
                    })
                },
                function() {
                    return self.me.is_spouse()
                        && self.me.held_child() == undefined
                        && ARI.held_child() != undefined;
                }
            );

            self.register_interaction(
                InputId.SecondaryInteract,
                "misc_local/kiss",
                function() {
                    self.kissing = true;
                    var old_card = self.me.cardinality;
                    var old_anim = self.me.animation;
                    self.me.set_animation("idle");
                    var target = Vec2(self.x, self.y);
                    var dir_sign = sign(self.x - obj_ari.x);
                    if dir_sign == -1 {
                        target.x += 16;
                        self.me.set_cardinality(Cardinal.East);
                    } else {
                        target.x -= 16;
                        self.me.set_cardinality(Cardinal.West);
                    }
                    var kiss_card = self.me.cardinality;
                    self.setup_kiss_particle();
                    var success = try_path_ari_to(target);
                    var chain = new_world_chain(self, CURRENT_LOCATION_ID);
                    if success {
                        chain.append(LinkId.Await, function() {
                            return !obj_ari.fsm.check_state_inclusive(PlayerState.Pathfind);
                        });
                    }
                    chain.append(LinkId.Function, function(kiss_card) {
                        obj_ari.face_dir(cardinal_to_inverse(kiss_card) * 90);
                        obj_ari.fsm.blackboard.set("do_not_set_idle", true);
                        obj_ari.fsm.change_state_instant(PlayerState.Cutscene);
                        obj_ari.par.set_animation(AnimationName.Kiss);
                        self.me.set_animation("kiss");
                        self.me.set_cardinality(kiss_card);
                        self.anim_speed = 1;
                        obj_ari.par_anim_spd = obj_ari.default_par_anim_spd;
                    }, [kiss_card]);
                    chain.append(LinkId.Timer, 65);
                    chain.append(LinkId.Function, function() {
                        self.anim_speed = 0;
                        obj_ari.par_anim_spd = 0;
                    });
                    chain.append(LinkId.Await, function() {
                        return !INPUT.check(InputId.SecondaryInteract);
                    });
                    chain.append(LinkId.Function, function() {
                        if self.kiss_sound != undefined {
                            TANGO.request_stop(self.kiss_sound);
                        }
                        self.kiss_sound = undefined;
                        self.anim_speed = 1;
                        obj_ari.par_anim_spd = obj_ari.default_par_anim_spd;
                    });
                    chain.join(LinkId.Timer, 9)
                    chain.append(LinkId.Function, function(old_anim, old_card) {
                        obj_ari.fsm.change_state(PlayerState.Default);

                        //
                        if old_anim == "sleep" {
                            old_anim = "idle";
                        }
                        self.me.set_animation(old_anim);
                        self.me.set_cardinality(old_card);
                        self.bark_emitter.emit(BarkId.Heart, BarkType.Speech);
                        obj_ari.bark_emitter.emit(BarkId.Heart, BarkType.Speech);
                        self.kissing = false;
                    }, [old_anim, old_card]);
                },
                function() {
                    return self.me.is_partner()
                        && matches(self.fsm.current_state_id(), NpcState.Default, NpcState.Pathfinding) //
                        && !self.me.is_seated() //
                },
                false, //
            );

            if self.npc_id == NpcId.Dozy || self.npc_id == NpcId.Henrietta {
                if self.npc_id == NpcId.Dozy {
                    self.pet_animation = "tailwag";
                    self.pet_loops_requested = 3;
                    self.pet_sound = "SoundEffects/Animals/DozyBark";
                } else {
                    self.pet_animation = "crow";
                    self.pet_loops_requested = 1;
                    self.pet_sound = "SoundEffects/Animals/ChickenHenriettaCutscene";
                }

                self.register_interaction(
                    InputId.Interact,
                    "misc_local/pet",
                    function() {
                        //
                        obj_ari.enter_action_animation(self.x, self.y);

                        //
                        var reset_cycle_name = self.me.animation;
                        var reset_cycle_cardinality = self.animator.cardinality;

                        //
                        self.animator.cardinality = angle_to_cardinal(point_direction(self.x, self.y, obj_ari.x, obj_ari.y));
                        self.me.set_animation(self.pet_animation);
                        self.reset_cycle_name = reset_cycle_name;
                        self.reset_cycle_cardinality = reset_cycle_cardinality;
                        self.animator.loops_requested = self.pet_loops_requested;

                        //
                        self.bark_emitter.emit(BarkId.CuteFace, BarkType.Thought);
                        TANGO.play(self.pet_sound, self.x, self.y);
                    },
                    function() {
                        return !self.can_talk()
                            && self.my_query_quests().is_empty()
                            && self.me.animation != self.pet_animation
                            && (instance_exists(obj_ari) == false || obj_ari.is_mounted() == false);
                    }
                );
            }

            self.star_offset = Vec2Zero();
        },
        step: function() {
            depth = get_instance_depth(y, z);

            if self.kiss_particle != undefined && !self.kissing {
                instance_destroy(self.kiss_particle);
                self.kiss_particle = undefined;
            }

            if non_cutscene_pause() {
                return;
            }

            //
            //
            if self.needs_talk_status_update {
                self.update_talk_status();
                self.needs_talk_status_update = false;
            }

            fsm.step();

            if !instance_exists(self) {
                return;
            }

            if self.pathfinding_agent.meddler != undefined {
                self.pathfinding_agent.meddler.update(x, y);
            }
            self.handle_chatting();
            self.handle_thinking();
        },
        step_begin: function() {
            fsm.new_tick();
        },
        step_end: function() {
            if !non_cutscene_pause() {
                fsm.end_step();
            }

            if instance_exists(self) == false {
                return;
            }

            if !non_cutscene_pause() {
                self.update_dialogue_pip();
            }

            if !non_cutscene_pause() || (ANCHOR.get_menu(Menu.Textbox) != undefined && MIST.running == false) {
                self.animate();
            }

            var y_off = MIST.is_running() && MIST.blackboard.get("offset_shadows_while_seated") && self.me.is_seated() ? -4 : 0;
            shadow_caster_set_position(self.shadow_caster, x, y + y_off);

            if self.fsm.current_state_id() != NpcState.Dummy {
                var ni = GRID.try_node_index_for_room_position(x, y);
                if ni != undefined && GRID.node_object_id[ni] != undefined {
                    GRID.node_parent[ni].renderer.collide(!self.move_spd.is_zero(), self.me.cardinality);
                }
            }
        },
        draw: function() {
            if self.me.cardinality == Cardinal.North {
                self.try_draw_child();
            }

            fsm.draw();

            if self.me.cardinality != Cardinal.North {
                self.try_draw_child();
            }

            if MIST.running {
                return;
            }

            if self.kissing {
                return;
            }

            var menu = ANCHOR.get_menu(Menu.Textbox);
            if menu != undefined {
                return;
            }

            var spr;
            switch self.bouncer.status {
                case InteractBounceStatus.None:
                    return;
                case InteractBounceStatus.Distant:
                    //
                    if self.bark_emitter.is_barking() {
                        return;
                    }

                    spr = self.is_group_conversation ? spr_ui_dialogue_speech_bubble_group_small : spr_ui_dialogue_speech_bubble_small;
                    break;
                case InteractBounceStatus.Main:
                    //
                    spr = self.is_group_conversation ? spr_ui_dialogue_speech_bubble_group_big : spr_ui_dialogue_speech_bubble_big;
                    break;
                default: impossible("unexpected pip: {}", self.bouncer.status);
            }
            draw_sprite_ext(spr, 0, self.x, self.y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
        },
        draw_end: function() {
            self.bark_emitter.on_draw();
        },
        destroy: function() {
            event_inherit(ObjectEvent.Destroy, par_interactable);
            self.fsm.destroy();
        },
        cleanup: function() {
            //
            self.fsm.cleanup();
            self.pathfinding_agent.clear_all_reservations();
            self.me.brain.blackboard.set("manual_override", false);
            self.me.brain.blackboard.set("instance", undefined);
            self.animator.stop_sound();
            self.clean_eat_and_drink();

            if self.kiss_sound != undefined {
                TANGO.force_stop(self.kiss_sound);
            }

            SHADOW_GRID.caster_remove(self.shadow_caster);
            T2R.write(format("{NpcId}_eating", self.npc_id), undefined);
            T2R.write(format("{NpcId}_drinking", self.npc_id), undefined);
        },
    }
);
