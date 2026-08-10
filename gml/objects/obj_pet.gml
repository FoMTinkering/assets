object_create(
    "obj_pet",
    object_reserve("par_animal"),
    {
        sprite_index: undefined,
        create: function() {
            //
            self.me = PET;

            event_inherit(ObjectEvent.Create);

            //
            self.can_update_location_position = false;
            self.pathfinding_agent = new PathfindingAgent(new PathfindingMeddler(PathfindingAgentKind.Animal, self));
            self.pathfinding_agent.should_reserve_squares = false;

            self.try_leave_farm = false;
            self.try_leave_house = false;

            //
            self.deferred_job_active_status = undefined;
            self.image_speed_backup = undefined;

            self.job_instances = undefined;

            //
            self.me.instance = self;
            self.mask_index = spr_pet_mask;

            //
            function set_sprites(animation) {
                self.me.animation = animation;
                self.sprites = self.me.active_sprites();
                self.sprite_index = self.sprites.base_sprite;

                self.update_bark_offset();
            }

            function put_down() {
                //
                self.fsm.change_state(PetState.Wander);

                //
                ARI.held_animal_id = undefined;
                obj_ari.par.held_animal_render_callback = undefined;
            }

            function create_animal_currency_dance(currency_amount, face_ari) {
                self.setup_celebration_animation(face_ari);

                //
                self.fsm.blackboard.set("on_animation_complete_params", [currency_amount, self.x, self.y]);
                self.fsm.blackboard.set("on_animation_complete", function(currency_amount, xx, yy) {
                    new_chain()
                        .append(LinkId.Timer, 40)
                        .append(
                            LinkId.Function,
                            function(xx, yy, currency_amount, og_location_id) {
                                if CURRENT_LOCATION_ID == og_location_id {
                                    drop_item_stack(xx, yy, ListFromArray(array_create(currency_amount, new LiveItem(ItemId.AnimalCurrency))));
                                } else {
                                    GRIDS[og_location_id].lost_items.push({
                                        x: xx * 8 + irandom(8),
                                        y: yy * 8 + irandom(8),
                                        items: ListFromArray(ListFromArray(array_create(currency_amount, new LiveItem(ItemId.AnimalCurrency)))),
                                    });
                                }

                                array_push(GAME_STATS.animal_bead_drops, {
                                    amount: currency_amount,
                                    day: total_days(),
                                });
                            },
                            [xx, yy, currency_amount, CURRENT_LOCATION_ID]
                        )
                    }
                );
            }

            function state_can_head_home() {
                switch self.fsm.current_state_id() {
                    case PetState.Idle:
                        //
                        return !self.fsm.current_state().door_handler;
                    case PetState.Wander:
                    case PetState.Animate:
                        return true;
                    case PetState.Pathfinding:
                    case PetState.Held:
                    case PetState.MoveDirected:
                        return false;
                }
            }

            function go_home() {
                if self.try_leave_house
                    && is_home_location(CURRENT_LOCATION_ID)
                {
                    self.try_leave_house = false;

                    if self.fsm.current_state_id() == PetState.Pathfinding {
                        //
                        self.fsm.blackboard.insert("wander_direction_override", 90);
                        self.fsm.change_state(PetState.Wander);
                    }

                    //
                    PET.location_id = CURRENT_LOCATION_ID;
                } else {
                    self.try_leave_farm = true;
                }
            }

            function go_to_farm() {
                self.try_leave_house = true;
            }

            function pathfind_to_home_from_farm() {
                var doors = instances_of_object(obj_door);
                var door;
                for (var i = 0; i < array_length(doors); i++) {
                    if doors[i]["stable_door"] == undefined {
                        door = doors[i];
                    }
                }
                assert_defined(door, "we somehow failed to find a door on the farm");

                var dest_x = door.x;
                var dest_y = door.y + 8;

                var path = PATHFINDING.calculate_local_path(
                    self.x,
                    self.y,
                    dest_x,
                    dest_y,
                    true,
                );

                //
                PET.location_id = pet_valid_house_location();
                PET.job_active = false;

                if path != undefined {
                    self.fsm.blackboard.insert("itinerary", new Itinerary(List(
                        new ItineraryItem(
                            new LocationPosition(CURRENT_LOCATION_ID, Vec2(self.x, self.y)),
                            new LocationPosition(CURRENT_LOCATION_ID, Vec2(dest_x, dest_y)),
                            path.distance,
                            path.output_list,
                        ),
                    )));
                    self.fsm.blackboard.insert("cardinal", Cardinal.North);
                    self.fsm.blackboard.insert("destroy_after_move_directed", true);
                    self.fsm.blackboard.insert("door_handler", true);
                    self.fsm.change_state(PetState.Pathfinding);
                }
            }

            function default_initialization(bb) {
                if ARI.held_animal_id == PET_ID {
                    return PetInitialization.Held;
                }

                if self.me.job_active && self.me.job != PetJob.None {
                    var job_setup_data = PET_PROTOTYPE.job_setup_data[self.me.job];
                    assert_eq(
                        self.me.location_id,
                        job_setup_data.location_id,
                        "pet is in {LocationId}, not {LocationId}, and job is active",
                        self.me.location_id,
                        job_setup_data.location_id,
                    );

                    //
                    self.x = job_setup_data.pet_position.x;
                    self.y = job_setup_data.pet_position.y;

                    self.job_instances = [];

                    for (var i = 0; i < array_length(job_setup_data.props); i++) {
                        var prop = job_setup_data.props[i];

                        var inst = instance_create_layer(
                            prop.position.x,
                            prop.position.y,
                            "Instances",
                            obj_assetobject,
                            {
                                sprite_index: prop.sprite,
                                z: 0,
                                original_blend: c_white,
                                on_floor: false,
                            }
                        );
                        array_push(self.job_instances, inst);
                    }

                    return PetInitialization.DoJob;
                }

                //
                if is_home_location(CURRENT_LOCATION_ID)
                    && CLOCK.time < hours(9)
                    && chance_percent(75)
                {
                    var pet_bed = undefined;
                    with obj_node_renderer {
                        if self.object_category == ObjectCategory.Furniture && self.node.prototype.pet_bed {
                            pet_bed = self;
                            break;
                        }
                    }

                    //
                    if pet_bed != undefined {
                        self.x = pet_bed.x;
                        self.y = pet_bed.y;

                        bb.set("renderer_to_track", pet_bed);

                        return PetInitialization.Bed;
                    }
                }

                //
                if is_home_location(CURRENT_LOCATION_ID) && chance_percent(25) {
                    var pet_dish = undefined;
                    with obj_node_renderer {
                        if self.object_category == ObjectCategory.Furniture
                            && self.node.prototype.pet_dish != undefined
                        {
                            pet_dish = self;
                            break;
                        }
                    }

                    //
                    if pet_dish != undefined {
                        self.x = pet_dish.x;
                        self.y = pet_dish.y + pet_dish.node.prototype.pet_dish.offset.y;

                        var cardy = choose(Cardinal.West, Cardinal.East);
                        bb.set("animation_direction_override", cardinal_to_angle(cardy));

                        if cardy == Cardinal.West {
                            self.x -= pet_dish.node.prototype.pet_dish.offset.x;
                        } else {
                            self.x += pet_dish.node.prototype.pet_dish.offset.x;
                        }

                        bb.set("renderer_to_track", pet_dish);

                        return PetInitialization.EatDish;
                    }
                }

                return try_position_pet() ? PetInitialization.Normal : undefined;
            }

            function on_pet() {
                if self.me.has_been_pat == false {
                    self.bark_emitter.emit(BarkId.Heart, BarkType.Thought);
                    self.me.pet();
                }
                if SETTINGS.get("sound_animals") {
                    TANGO.play(self.me.positive_react_tango_event_name(), self.x, self.y);
                }
            }

            //
            function on_alteration() {
                if self.fsm.current_state_id() == PetState.Animate
                    && PET_PROTOTYPE.variants.get(PET.variant).sprites.contains_key(PET.animation) == false
                {
                    var animation = select_random_animation_for_pet(self);
                    if animation == undefined {
                        self.fsm.change_state(PetState.Idle);
                    } else {
                        self.fsm.blackboard.set("animation", animation);
                        self.fsm.change_state(PetState.Animate);
                    }
                } else if self.fsm.current_state_id() == PetState.UsingToy {
                    var state = self.fsm.current_state();
                    
                    if state.toy.prototype.animal_toy.centered_pets[self.me.pet_kind()] == false {
                        interact(state.toy);
                    }
                } else {
                    self.set_sprites(PET.animation);
                }
            }

            //
            self.register_interaction(
                InputId.Interact,
                "misc_local/feed",
                function() {
                    var held_item = ARI.inventory.slot(ARI.held_item_index).pop();
                    self.me.feed(held_item);
                    self.bark_emitter.emit(BarkId.Music, BarkType.Thought, true);
                    PET.has_eaten = true;

                    //
                    if SETTINGS.get("sound_animals") {
                        TANGO.play(self.me.positive_react_tango_event_name(), self.x, self.y);
                    }
                    self.create_animal_currency_dance(held_item.prototype.pet_treat.tier + 1, true);

                    //
                    obj_ari.enter_action_animation(self.x, self.y);
                },
                function() {
                    if ARI.held_animal_id != undefined
                        || self.fsm.current_state_id() == PetState.UsingToy
                        || obj_ari.is_mounted()
                        || PET.has_eaten
                        || (self.me.job_active && self.me.job != PetJob.None)
                    {
                        return false;
                    }
                    var held_item = ARI.held_item();
                    if held_item == undefined || held_item.prototype.pet_treat == undefined {
                        return false;
                    }
                    return held_item.prototype.pet_treat.pet_kinds[self.me.pet_kind()];
                }
            );

            //
            self.register_interaction(
                InputId.Interact,
                "misc_local/pick_up",
                function() {
                    self.fsm.change_state(PetState.Held);
                    self.on_pet();
                },
                function() {
                    return ARI.held_animal_id == undefined
                        && (self.me.job_active == false || self.me.job == PetJob.None)
                        && self.fsm.current_state_id() != PetState.UsingToy
                        && SCREEN_FADER.is_in()
                        && obj_ari.fsm.current_state_id() != PlayerState.Swim
                        && !obj_ari.is_mounted();
                }
            );

            //
            self.register_interaction(
                InputId.Interact,
                "misc_local/check_pet",
                function() {
                    //
                    obj_ari.face_dir(point_direction(obj_ari.x, obj_ari.y, self.x, self.y));
                    obj_ari.set_idle_simple();

                    var conversation = PET_PROTOTYPE.job_setup_data[self.me.job].conversation_name;
                    play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[conversation]);
                },
                function() {
                    return ARI.held_animal_id == undefined
                        && self.me.job_active
                        && self.me.job != PetJob.None
                        && SCREEN_FADER.is_in()
                        && obj_ari.fsm.current_state_id() != PlayerState.Swim
                        && !obj_ari.is_mounted();
                }
            );

            //
            self.register_interaction(
                InputId.SecondaryInteract,
                "misc_local/pet",
                self.pet_animal_interaction,
                function() {
                    return ARI.held_animal_id == undefined
                        && (self.me.job_active == false || self.me.job == PetJob.None)
                        && self.fsm.current_state_id() != PetState.UsingToy
                        && SCREEN_FADER.is_in()
                        && obj_ari.fsm.current_state_id() != PlayerState.Swim
                        && !obj_ari.is_mounted();
                }
            );

            self.me.set_cardinality(irandom(Cardinal.LEN - 1));

            var bb = Map();
            var initial_state;

            var pet_initialization = undefined;
            if override_pet_initialization == undefined {
                pet_initialization = self.default_initialization(bb);
            } else {
                pet_initialization = override_pet_initialization;
            }

            if pet_initialization == undefined {
                error("we failed to make a pet!");
                self.fsm = undefined;
                instance_destroy(self);
                return;
            }

            switch pet_initialization {
                case PetInitialization.Normal:
                    initial_state = PetState.Idle;

                    if chance_percent(50) {
                        var animation = select_random_animation_for_pet(self);
                        if animation != undefined {
                            bb.set("animation", animation);
                            initial_state = PetState.Animate;
                        }
                    }
                    break;
                case PetInitialization.Bed:
                    initial_state = PetState.Animate;
                    bb.insert("animation", "sleep");
                    break;
                case PetInitialization.DoJob:
                    initial_state = PetState.Animate;
                    bb.insert("animation", "action");
                    break;
                case PetInitialization.Held:
                    initial_state = PetState.Held;
                    break;
                case PetInitialization.EatDish:
                    initial_state = PetState.Animate;
                    bb.insert("animation", "eat");
                    break;
                case PetInitialization.EnterViaDoor:
                    if CURRENT_LOCATION_ID == LocationId.Farm {
                        var our_door = instance_find(obj_door, 0);
                        self.x = our_door.x;
                        self.y = our_door.y - 8;

                        bb.insert("cardinal", Cardinal.South);
                        bb.insert("door_handler", true);
                        bb.insert("wander_direction_override", 270);
                        initial_state = PetState.Idle;
                    } else {
                        var dest_x = undefined;
                        var dest_y = undefined;

                        //
                        with obj_roomtransition {
                            //
                            if self.player_direction == DirectionAngle.Down {
                                dest_x = self.x;
                                dest_y = self.y;
                                break;
                            }
                        }

                        self.x = dest_x;
                        self.y = dest_y;

                        PET.cardinality = Cardinal.North;
                        initial_state = PetState.MoveDirected;
                        bb.insert("wander_direction_override", 90);
                    }
                    break;
                case PetInitialization.Cutscene:
                    initial_state = PetState.Cutscene;
                    break;
                default: impossible("unexpected pet initialization: {}", pet_initialization);
            }

            trace("Pet initialized with {PetInitialization} at {}x{}", pet_initialization, self.x, self.y);

            //
            if array_length(self.me.items_to_pop) > 0 {
                var current_item_id = self.me.items_to_pop[0];
                var current_item_count = 1;

                var c = new_world_chain(self, CURRENT_LOCATION_ID)
                    .append(LinkId.Timer, 60);

                //
                c.append(LinkId.Function, function() {
                    self.bark_emitter.emit(BarkId.Heart, BarkType.Thought);
                    //
                    if SETTINGS.get("sound_animals") {
                        TANGO.play(self.me.positive_react_tango_event_name(), self.x, self.y);
                    }
                });

                for (var i = 1; i < array_length(self.me.items_to_pop); i++) {
                    var new_item_id = self.me.items_to_pop[i];
                    if new_item_id != current_item_id || current_item_count == 99 {
                        //
                        c
                            .append(LinkId.Function, function(item_id, amount_to_clear) {
                                drop_item_stack(
                                    self.x,
                                    self.y,
                                    ListFromArray(array_create(amount_to_clear, new LiveItem(item_id)))
                                );
                                array_delete(PET.items_to_pop, 0, amount_to_clear);
                            }, [current_item_id, current_item_count])
                            .append(LinkId.Timer, 30);

                        current_item_id = new_item_id;
                        current_item_count = 1;
                    } else {
                        current_item_count += 1;
                    }
                }

                //
                c
                    .append(LinkId.Function, function(item_id, amount_to_clear) {
                        drop_item_stack(
                            self.x,
                            self.y,
                            ListFromArray(array_create(amount_to_clear, new LiveItem(item_id)))
                        );
                        array_delete(PET.items_to_pop, 0, amount_to_clear);
                    }, [current_item_id, current_item_count]);
            }

            self.fsm = StateMachineBuilder(PetState.LEN)
                .add_state(StateBuilder(PetState.Idle)
                    .start(function() {
                        self.door_handler = self.blackboard.try_take("door_handler", false);
                        if self.door_handler {
                            self.timer_max = 90;
                            PET.cardinality = self.blackboard.take("cardinal");
                            self.owner.set_sprites("idle");
                            self.has_opened_door = false;
                        } else {
                            animal_idle_start(self);
                        }
                    })
                    .step(function() {
                        if self.door_handler && self.has_opened_door == false && self.fsm.state_frame >= 30 {
                            var door = instance_nearest(owner.x, owner.y, obj_door);
                            if door != undefined {
                                door.request_open(1);
                                door.requests = 100000;
                                self.has_opened_door = true;
                            }
                        }

                        if self.fsm.state_frame >= self.timer_max {
                            if self.door_handler {
                                self.fsm.change_state(PetState.MoveDirected);
                            } else if choose(true, false) {
                                self.fsm.change_state(PetState.Wander);
                            } else {
                                var animation = select_random_animation_for_pet(owner);
                                if animation != undefined {
                                    self.blackboard.set("animation", animation);
                                    self.fsm.change_state(PetState.Animate);
                                }
                            }
                        }
                    })
                    .stop(function() {
                        if self.fsm.next_state == undefined || self.fsm.next_state.state_id != PetState.MoveDirected {
                            //
                            var door = instance_nearest(owner.x, owner.y, obj_door);
                            if door != undefined {
                                door.requests = 0;
                            }
                        }
                    })
                    .spawn()
                )
                .add_state(StateBuilder(PetState.Wander)
                    .start(function() {
                        animal_wander_start(self);
                    })
                    .step(function() {
                        if animal_wander_step(self) {
                            if self.owner.ignore_collision {
                                self.fsm.change_state(PetState.Wander);
                            } else {
                                self.fsm.change_state(PetState.Idle);
                            }
                            self.owner.ignore_collision = false;
                        }
                    })
                    //
                    //
                    .spawn()
                )
                .add_state(StateBuilder(PetState.Animate)
                    .start(function() {
                        animal_animate_start(self);
                        self.renderer_to_track = self.blackboard.try_take("renderer_to_track");

                        //
                        if self.renderer_to_track != undefined && instance_exists(self.renderer_to_track) == false {
                            self.renderer_to_track = undefined;
                        }
                    })
                    .step(function() {
                        if animal_animate_step(self)
                            || (self.renderer_to_track != undefined && instance_exists(self.renderer_to_track) == false)
                        {
                            self.fsm.change_state(PetState.Idle);
                        }
                    })
                    .stop(function() {
                        animal_animate_stop(self);
                    })
                    .spawn()
                )
                .add_state(StateBuilder(PetState.Pathfinding)
                    .create(function() {
                        animal_pathfind_create(self);
                    })
                    .start(function() {
                        animal_pathfind_start(self);
                    })
                    .step(function() {
                        var complete = animal_pathfind_step(self);

                        if complete {
                            if self.destroy_on_end {
                                instance_destroy(owner);
                            } else {
                                var next_state = has_flag(PAUSE_STATUS, PauseStatus.CUTSCENE)
                                    ? PetState.Cutscene
                                    : PetState.Idle;
                                self.fsm.change_state(next_state);
                            }
                        }
                    })
                    .stop(function() {
                        animal_pathfind_stop(self);
                    })
                    .spawn()
                )
                .add_state(StateBuilder(PetState.Held)
                    .start(function() {
                        owner.set_sprites("idle");

                        ARI.held_animal_id = PET_ID;
                        obj_ari.par.held_animal_render_callback = function(xx, yy, flipper) {
                            var old_image_xscale = owner.image_xscale;
                            owner.image_xscale = flipper;
                            owner.draw_routine(xx, yy);
                            owner.image_xscale = old_image_xscale;
                        };
                        shadow_caster_set_sprite(owner.shadow_caster, undefined);

                        //
                        //
                        //
                        //
                        //
                        if owner.me.management == PetManagement.Afternoon
                            && owner.me.job_active == false
                            && WEATHER.is_inclement() == false
                        {
                            owner.deferred_job_active_status = true;
                        }
                    })
                    .step(function() {
                        //
                        owner.x = obj_ari.x;
                        owner.y = obj_ari.y;

                        owner.me.location_id = CURRENT_LOCATION_ID;
                        owner.me.location_dyn_index = CURRENT_DYN_INDEX;

                        owner.me.set_cardinality(obj_ari.cardinal);

                        //
                        owner.update_bark_offset();

                        owner.image_xscale = obj_ari.cardinal == Cardinal.West ? -1 : 1;
                    })
                    .spawn()
                )
                .add_state(StateBuilder(PetState.MoveDirected)
                    .start(function() {
                        //
                        self.owner.set_sprites("walk");

                        self.destroy_at_end = self.blackboard.try_take("destroy_after_move_directed", false);
                    })
                    .step(function() {
                        //
                        owner.ignore_collision = true;

                        switch PET.cardinality {
                            case Cardinal.North:
                                owner.move.y = -0.35;
                                break;
                            case Cardinal.South:
                                owner.move.y = 0.35;
                                break;
                            case Cardinal.West:
                                owner.move.x = -0.35;
                                break;
                            case Cardinal.East:
                                owner.move.x = 0.35;
                                break;
                        }

                        if self.fsm.state_frame >= 60 {
                            if self.destroy_at_end {
                                instance_destroy(owner);
                            } else {
                                self.fsm.change_state(PetState.Wander);
                            }
                        }
                    })
                    .stop(function() {
                        var door = instance_nearest(owner.x, owner.y, obj_door);
                        if door != undefined {
                            door.requests = 0;
                        }
                        owner.ignore_collision = false;
                    })
                    .spawn()
                )
                .add_state(StateBuilder(PetState.UsingToy)
                    .start(function() {
                        self.toy = self.blackboard.take("toy");
                        self.animal_toy_position = self.blackboard.take("animal_toy_position");
                        self.idle = self.toy.prototype.animal_toy.animal_idle != undefined ? self.toy.prototype.animal_toy.animal_idle : "idle";

                        switch self.animal_toy_position {
                            case AnimalToyPosition.Left:
                                self.attach_point_track = self.toy.prototype.animal_toy.attach_points.left;
                                owner.me.set_cardinality(Cardinal.East);
                                break;
                            case AnimalToyPosition.Right:
                                self.attach_point_track = self.toy.prototype.animal_toy.attach_points.right;
                                owner.me.set_cardinality(Cardinal.West);
                                break;
                            case AnimalToyPosition.Center:
                                self.attach_point_track = self.toy.prototype.animal_toy.attach_points.center;
                                owner.me.set_cardinality(Cardinal.East);
                                break;
                        }

                        //
                        var current_attach = self.attach_point_track[0];
                        owner.x = self.toy.renderer.x + current_attach.offset.x;
                        owner.y = self.toy.renderer.y + current_attach.offset.y;

                        owner.inhibit_shadow = toy.prototype.animal_toy.inhibit_shadow;
                        if owner.inhibit_shadow {
                            shadow_caster_set_sprite(owner.shadow_caster, undefined);
                        }
                        owner.inhibit_depth = toy.prototype.animal_toy.inhibit_depth;
                        if owner.inhibit_depth {
                            owner.depth = self.toy.renderer.depth - 1;
                        }

                        self.last_frame = -1;
                        self.celebrate_blocker = false;
                    })
                    .step(function() {
                        self.toy.renderer.image_speed = 1.0;
                        if floor(self.toy.renderer.image_index) == self.last_frame {
                            return;
                        }
                        self.last_frame = floor(self.toy.renderer.image_index);

                        var current_attach = self.attach_point_track[self.last_frame];
                        owner.x = self.toy.renderer.x + current_attach.offset.x;
                        owner.y = self.toy.renderer.y + current_attach.offset.y;

                        owner.update_bark_offset();

                        if current_attach.celebrate {
                            if self.celebrate_blocker {
                                self.celebrate_blocker = false;
                                return;
                            }
                            if chance_percent(self.toy.prototype.animal_toy.celebrate_chance) {
                                owner.set_sprites(PET_PROTOTYPE.celebration_animation);

                                owner.bark_emitter.emit(BarkId.CuteFace, BarkType.Thought);
                                self.celebrate_blocker = self.toy.prototype.animal_toy.celebrate_blocker;
                            }
                        }

                        if current_attach.play_animation != undefined {
                            owner.set_sprites(current_attach.play_animation);
                            owner.image_index = 0;
                        }

                        if current_attach.tango != undefined && SETTINGS.get("sound_animals") {
                            TANGO.play(current_attach.tango, owner.x, owner.y);
                        }
                    })
                    .anim_end(function() {
                        owner.set_sprites(self.idle);
                    })
                    .stop(function() {
                        self.toy.animal_count -= 1;

                        if self.toy.animal_count <= 0 {
                            self.toy.renderer.set_sprite(self.toy.prototype.cardinal_data[self.toy.cardinal_index].sprite);
                            stop_animal_toy_sfx(self.toy);
                        }

                        owner.inhibit_shadow = false;
                        owner.inhibit_depth = false;
                    })
                    .spawn()
                )
                .add_state(StateBuilder(PetState.Cutscene)
                    .start(function() {
                        self.owner.x = round(self.owner.x);
                        self.owner.y = round(self.owner.y);

                        PET.cardinality = Cardinal.North;
                        self.door_handler = self.blackboard.try_take("door_handler", false);
                        if self.door_handler {
                            self.timer_max = 90;
                            PET.cardinality = self.blackboard.take("cardinal");
                            self.has_opened_door = false;
                        }

                        self.owner.set_sprites("idle");
                    })
                    .step(function() {
                        if self.door_handler == false {
                            return;
                        }

                        if self.has_opened_door == false && self.fsm.state_frame >= 30 {
                            var door = instance_nearest(owner.x, owner.y, obj_door);
                            if door != undefined {
                                door.request_open(1);
                                door.requests = 100000;
                                self.has_opened_door = true;
                            }
                        }

                        if self.fsm.state_frame >= self.timer_max {
                            self.fsm.change_state(PetState.MoveDirected);
                        }
                    })
                    .spawn()
                )
                .spawn(initial_state, self, bb);

        },
        step: function() {
            if non_cutscene_pause() {
                if self.fsm.current_state_id() == PetState.UsingToy {
                    var cs = self.fsm.current_state();
                    cs.toy.renderer.image_speed = 0.0;
                }

                if self.image_speed_backup == undefined {
                    self.image_speed_backup = self.image_speed;
                }
                self.image_speed = 0;
                return;
            }

            //
            if self.image_speed_backup != undefined {
                self.image_speed = self.image_speed_backup;
                self.image_speed_backup = undefined;
            }

            event_inherit(ObjectEvent.Step);

            //
            if has_flag(PAUSE_STATUS, PauseStatus.CUTSCENE) {
                return;
            }

            //
            if CLOCK.time >= hours(7)
                && self.fsm.current_state_id() == PetState.Animate
                && PET.animation == "sleep"
            {
                self.fsm.change_state(PetState.Wander);
            }

            //
            if self.try_leave_house
                && self.fsm.current_state_id() != PetState.Pathfinding
                && self.fsm.current_state_id() != PetState.Held
            {
                var dest_x = 0;
                var dest_y = 0;

                with obj_roomtransition {
                    if destination_id == LocationId.Farm {
                        //
                        dest_x = self.x + 8;
                        dest_y = self.y + 16;
                        break;
                    }
                }

                var path = PATHFINDING.calculate_local_path(
                    self.x,
                    self.y,
                    dest_x,
                    dest_y,
                    true,
                );

                self.deferred_job_active_status = true;

                if path != undefined {
                    self.fsm.blackboard.insert("itinerary", new Itinerary(List(
                        new ItineraryItem(
                            new LocationPosition(CURRENT_LOCATION_ID, Vec2(self.x, self.y)),
                            new LocationPosition(CURRENT_LOCATION_ID, Vec2(dest_x, dest_y)),
                            path.distance,
                            path.output_list,
                        ),
                    )));
                    self.fsm.blackboard.insert("destroy_after_pathfind", true);
                    self.fsm.change_state(PetState.Pathfinding);
                }
            }

            //
            if self.try_leave_farm
                && self.state_can_head_home()
                && CURRENT_LOCATION_ID == LocationId.Farm
            {
                self.pathfind_to_home_from_farm();
            }
        },
        draw: function() {
            if self.fsm.current_state_id() == PetState.Held {
                return;
            }

            event_inherit(ObjectEvent.Draw);
        },
        draw_end: function() {
            self.bark_emitter.on_draw(!non_cutscene_pause());
        },
        animation_end: function() {
            event_inherit(ObjectEvent.AnimationEnd);

            if has_flag(PAUSE_STATUS, PauseStatus.CUTSCENE) == false
                && self.me.job_active
                && self.me.job != PetJob.None
                && chance_percent(50)
            {
                self.me.set_cardinality(irandom(Cardinal.LEN - 1));
            }
        },
        destroy: function() {
            event_inherit(ObjectEvent.Destroy);

            //
            if self.me.job_active && self.job_instances != undefined {
                for (var i = 0; i < array_length(self.job_instances); i++) {
                    instance_destroy(self.job_instances[i]);
                }
                self.job_instances = undefined;
            }
        },
        cleanup: function() {
            event_inherit(ObjectEvent.Cleanup);

            if self.deferred_job_active_status != undefined && self.fsm.current_state_id() != PetState.Held {
                if self.deferred_job_active_status {
                    self.me.job_active = true;
                    self.me.location_id = location_for_job(self.me.job);
                } else {
                    self.me.job_active = false;
                    self.me.location_id = pet_valid_house_location();
                }
            }

            self.me.instance = undefined;
        },
    }
);
