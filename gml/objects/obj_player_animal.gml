object_create(
    "obj_player_animal",
    object_reserve("par_animal"),
    {
        sprite_index: undefined,
        liminal_on_screen: false,
        create: function() {
            //
            event_inherit(ObjectEvent.Create);

            self.check_collision = function(xx, yy) {
                var ni = GRID.try_node_index_for_room_position(xx, yy);
                if ni == undefined {
                    return true;
                }

                if GRID.node_object_id[ni] != undefined {
                    if GRID.node_object_id[ni] == self.object_id_to_ignore {
                        return false;
                    } else {
                        self.object_id_to_ignore = undefined;
                    }
                }

                return GRID.node_collideable[ni];
            }

            self.pathfinding_agent = new PathfindingAgent(new PathfindingMeddler(PathfindingAgentKind.Animal, self));
            self.pathfinding_agent.should_reserve_squares = false;
            self.bark_signal = undefined;
            self.wants_to_eat = undefined;
            self.eod_bark = 0;
            self.weather_bark = -1;
            self.bark_on_sight_timer = -1;
            self.image_speed_backup = undefined;
            self.object_id_to_ignore = undefined;

            self.mask_index = self.me.prototype.core.size == AnimalSize.Large ? spr_large_animal_mask : spr_small_animal_mask;

            var sparkle_range = fiddle_get("ranching/misc/treat_sparkle_frequency");
            self.treat_sparkle_timer = self.me.ate_breeding_treat ? irandom_range(sparkle_range[0], sparkle_range[1]) : undefined;

            function try_accept_pathfinding_request() {
                if self.fsm.blackboard.contains_key("itinerary") {
                    self.fsm.change_state(AnimalState.Pathfinding);
                    return true;
                }
                return false;
            }

            function on_pet() {
                if self.me.can_pet() == false {
                    return;
                }
                self.me.pet();
                ARI.gain_essence(self.me.prototype.petting.essence_points, obj_ari.x, obj_ari.y);
                ARI.modify_stamina(-1 * self.me.prototype.petting.stamina_cost);
                self.bark_emitter.emit(BarkId.Heart, BarkType.Thought);

                if SETTINGS.get("sound_animals") {
                    var sounds = self.me.sounds();
                    TANGO.play(sounds.positive_react, self.x, self.y);
                }
            }

            function put_down() {
                //
                self.fsm.change_state(AnimalState.Wander);

                //
                ARI.held_animal_id = undefined;
                obj_ari.par.held_animal_render_callback = undefined;
            }

            function try_find_food() {
                //
                var food_data = find_nearest_animal_food(x, y, self.me.is_baby() ? self.me.prototype.eating.baby_offset : self.me.prototype.eating.offset);
                if food_data != undefined {
                    self.fsm.blackboard.insert("itinerary", new Itinerary(List(
                        food_data.item,
                    )));
                    self.wants_to_eat = {
                        node: food_data.node,
                        item: food_data.item,
                        cardinal: food_data.cardinal,
                        location_position: food_data.item.target_location,
                        time: CLOCK.time,
                    };
                    self.fsm.change_state(AnimalState.Pathfinding);

                    return true;
                } else {
                    return false;
                }
            }

            function try_confirm_eating() {
                if self.wants_to_eat == undefined {
                    return false;
                }

                //
                var wants_to_eat = self.wants_to_eat;
                self.wants_to_eat = undefined;

                var inst_index = GRID.node_index_for_cell(wants_to_eat.node.top_left_x, wants_to_eat.node.top_left_y);
                //
                if GRID.node_object_id[inst_index] == wants_to_eat.node.object_id {
                    if self.can_update_location_position {
                        self.me.location_position = wants_to_eat.location_position;
                    }
                    self.me.eat_data = wants_to_eat;

                    return true;
                } else {
                    return false;
                }
            }

            function create_animal_currency_dance(currency_amount, face_ari) {
                if !ARI.perk_active(Perk.CurrencyOfCare) {
                    return;
                }
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
                                        items: ListFromArray(array_create(currency_amount, new LiveItem(ItemId.AnimalCurrency))),
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

            self.register_interaction(
                InputId.Interact,
                "misc_local/feed",
                function() {
                    var item = ARI.held_item();
                    if item.item_id == self.me.prototype.breeding.treat {
                        var animals = self.me.stable.animals();
                        var blocking_animal = animals.find_value(function(v) {
                            return v.idx != self.me.idx
                                && v.ate_breeding_treat
                                && v.kind == self.me.kind
                                && v.sex == self.me.sex
                                && v.breeding_with == undefined;
                        });

                        var partner_animal = animals.find_value(function(v) {
                            return v.ate_breeding_treat
                                && v.kind == self.me.kind
                                && v.sex != self.me.sex
                                && v.breeding_with == undefined;
                        });

                        BREEDING_ANIMAL_CTX.animal_name = self.me.name;

                        var convo = undefined;
                        if self.me.is_incubating {
                            convo = GpTriggeredConversation.AnimalTreatAlreadyIncubating;
                        } else if self.me.ate_breeding_treat {
                            convo = GpTriggeredConversation.AnimalTreatAlreadyTaken;
                        } else if self.me.is_baby() {
                            convo = GpTriggeredConversation.AnimalTreatBaby;
                        } else if points_to_animal_heart_level(self.me.heart_points) < fiddle_get("ranching/misc/min_heart_level_for_breeding") {
                            convo = GpTriggeredConversation.AnimalTreatBelowTwoHearts;
                        } else if self.me.stable.availability() < 1 {
                            convo = GpTriggeredConversation.AnimalTreatNoRoom;
                        } else if self.me.prototype.breeding.uses_egg && self.me.stable.incubator_availability() < 1 {
                            convo = GpTriggeredConversation.AnimalTreatNoIncubatorSpace;
                        } else if blocking_animal != undefined {
                            BREEDING_ANIMAL_CTX.breeding_partner = blocking_animal.name;
                            var key = self.me.sex == Sex.Male
                                ? self.me.prototype.core.male_other
                                : self.me.prototype.core.female_other;
                            BREEDING_ANIMAL_CTX.animal_pair = capitalize(local_get(key));
                            BREEDING_ANIMAL_CTX.treat_item = item.get_display_name();
                            convo = GpTriggeredConversation.AnimalTreatAlreadyTakenByOther;
                        } else {
                            if partner_animal == undefined {
                                convo = GpTriggeredConversation.AnimalTreatInitial;
                            } else {
                                convo = GpTriggeredConversation.AnimalTreatSecond;

                                BREEDING_ANIMAL_CTX.breeding_partner = partner_animal.name;
                            }

                            if self.me.sex == Sex.Male {
                                BREEDING_ANIMAL_CTX.animal_pair = local_get(self.me.prototype.core.female_other);
                            } else {
                                BREEDING_ANIMAL_CTX.animal_pair = local_get(self.me.prototype.core.male_other);
                            }
                        }

                        play_conversation_from_path(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[convo], function(driver, animal, last_convo, partner_animal) {
                            BREEDING_ANIMAL_CTX.animal_name = undefined;
                            BREEDING_ANIMAL_CTX.animal_pair = undefined;
                            BREEDING_ANIMAL_CTX.breeding_partner = undefined;
                            BREEDING_ANIMAL_CTX.treat_item = undefined;

                            if driver.prompt_index_selected != 0 {
                                return;
                            }

                            //
                            ARI.inventory.slot(ARI.held_item_index).pop();
                            animal.ate_breeding_treat = true;

                            if partner_animal != undefined {
                                animal.breeding_with = partner_animal.idx;
                                partner_animal.breeding_with = animal.idx;
                            }
                            if animal.instance != undefined {
                                var range = fiddle_get("ranching/misc/treat_sparkle_frequency");
                                animal.instance.treat_sparkle_timer = irandom_range(range[0], range[1]);

                                var sex_icon = animal.sex == Sex.Male ? BarkId.BreedMale : BarkId.BreedFemale;
                                animal.instance.bark_emitter.emit(sex_icon, BarkType.Thought, true);
                                if SETTINGS.get("sound_animals") {
                                    TANGO.play(animal.sounds().positive_react, animal.instance.x, animal.instance.y);
                                }
                                animal.instance.setup_celebration_animation(true);

                                //
                                obj_ari.enter_action_animation(animal.instance.x, animal.instance.y);

                                if last_convo && partner_animal.instance != undefined {
                                    var sex_icon = partner_animal.sex == Sex.Male ? BarkId.BreedMale : BarkId.BreedFemale;
                                    partner_animal.instance.bark_emitter.emit(sex_icon, BarkType.Thought, true);
                                    if SETTINGS.get("sound_animals") {
                                        TANGO.play(partner_animal.sounds().positive_react, partner_animal.instance.x, partner_animal.instance.y);
                                    }
                                }
                            }
                        }, [self.me, convo == GpTriggeredConversation.AnimalTreatSecond, partner_animal]);
                    } else {
                        var held_item = ARI.inventory.slot(ARI.held_item_index).pop();
                        self.me.feed(held_item);
                        self.bark_emitter.emit(BarkId.Music, BarkType.Thought, true);
                        if SETTINGS.get("sound_animals") {
                            TANGO.play(self.me.sounds().positive_react, self.x, self.y);
                        }
                        self.create_animal_currency_dance(item_prototype_to_beads(held_item.prototype), true);

                        array_push(GAME_STATS.animal_eats, {
                            source: "hand_feed",
                            item: held_item.pretty_print(),
                            day: total_days(),
                        });

                        //
                        obj_ari.enter_action_animation(self.x, self.y);
                    }
                },
                function() {
                    if ARI.held_animal_id != undefined || self.fsm.current_state_id() == AnimalState.UsingToy {
                        return false;
                    }
                    if obj_ari.is_mounted() {
                        return false;
                    }
                    var held_item = ARI.held_item();
                    if held_item == undefined {
                        return false;
                    }

                    if held_item.prototype.soulbind != undefined {
                        return false;
                    }

                    if !ARI.perk_active(Perk.CurrencyOfCareThree) && (held_item.prototype.recipe != undefined && !held_item.prototype.tags.contains("animal_feed")) {
                        return false;
                    }

                    if held_item.item_id == self.me.prototype.breeding.treat {
                        return true;
                    }
                    if self.me.has_eaten {
                        return false;
                    }

                    //
                    if held_item.prototype.edible || held_item.prototype.tags.contains("animals_can_eat") {
                        return true;
                    }

                    if held_item.prototype.animal_feed == undefined  {
                        return false;
                    }

                    return held_item.prototype.animal_feed.animal_size == self.me.prototype.core.size;
                }
            );

            switch self.me.prototype.petting.kind {
                case PettingKind.Pet:
                    self.register_interaction(
                        InputId.Interact,
                        "misc_local/pet",
                        self.pet_animal_interaction,
                        function() {
                            return ARI.held_animal_id == undefined
                                && self.fsm.current_state_id() != AnimalState.UsingToy
                                && SCREEN_FADER.is_in() //
                                && !obj_ari.is_mounted();
                        },
                    );
                    break;
                case PettingKind.PickUp:
                    self.register_interaction(
                        InputId.Interact,
                        "misc_local/pick_up",
                        function() {
                            if self.me.can_pet() {
                                self.on_pet();
                            }
                            self.fsm.change_state(AnimalState.Held);
                        },
                        function() {
                            return ARI.held_animal_id == undefined
                                && self.fsm.current_state_id() != AnimalState.UsingToy
                                && SCREEN_FADER.is_in()
                                && obj_ari.fsm.current_state_id() != PlayerState.Swim
                                && !obj_ari.is_mounted();
                        }
                    );
                    break;
                default: impossible(
                    "Unexpected PettingKind: {PettingKind}",
                    self.me.prototype.petting.kind,
                );
            }

            self.register_interaction(
                InputId.SecondaryInteract,
                "misc_local/inspect",
                function() {
                    var menu = ANCHOR.spawn_menu(Menu.Journal);
                    menu.set_active_sub_menu(Menu.Animal);
                    for (var i = 0; i < array_length(menu.sub_menu.left_pilot.map); i++) {
                        var node = menu.sub_menu.left_pilot.map[i][0];
                        if node.board_get("animal") == self.me {
                            menu.sub_menu.left_pilot.force_select(node);
                            menu.sub_menu.select_animal(self.me);
                            menu.sub_menu.scroller.scroll_by_amount(node.get_y());
                        }
                    }
                },
                function() {
                    var csi = self.fsm.current_state_id();
                    return csi != AnimalState.Held
                        && csi != AnimalState.UsingToy
                        && SCREEN_FADER.is_in();
                }
            );

            if LOCATIONS[CURRENT_LOCATION_ID].outdoor && !me.has_been_outside {
                var outdoor_hearts = fiddle_get("ranching/misc/heart_points/go_outside");
                self.weather_bark = 45;

                if WEATHER.is_inclement() {
                    outdoor_hearts *= -1;
                }  else {
                    //
                    ARI.gain_xp(Skill.Ranching, ANIMAL_XP.go_outside);
                }
                me.add_heart_points(outdoor_hearts);
                me.has_been_outside = true;
            }

            //
            if self.me.bark_on_sight != undefined {
                self.weather_bark = -1;

                self.bark_on_sight_timer = 45;
            }

            var initial_state;
            var bb = Map();

            if self.me.idx == ARI.held_animal_id {
                initial_state = AnimalState.Held;
            } else if CURRENT_LOCATION_ID == LocationId.Farm {
                if self.me.eat_data != undefined {
                    initial_state = AnimalState.Eat;
                } else if self.me.liminal {
                    if self.liminal_on_screen {
                        initial_state = AnimalState.Wander;

                        var wander_dir = 0;
                        if self.me.prototype.core.size == AnimalSize.Large {
                            wander_dir = 270;
                        }
                        bb.insert("wander_direction_override", wander_dir);
                        bb.insert("wander_out_of_building", true);
                        self.object_id_to_ignore = self.me.stable.building.prototype.object_id;
                    } else if self.me.has_eaten == false {
                        var food_data = find_nearest_animal_food(x, y, self.me.is_baby() ? self.me.prototype.eating.baby_offset : self.me.prototype.eating.offset);

                        if food_data == undefined {
                            initial_state = AnimalState.Wander;
                        } else {
                            self.me.eat_data = {
                                node: food_data.node,
                                item: food_data.item,
                                cardinal: food_data.cardinal,
                                location_position: food_data.item.target_location
                            };

                            self.me.location_position = food_data.item.target_location.clone();
                            x = self.me.location_position.pos.x;
                            y = self.me.location_position.pos.y;

                            initial_state = AnimalState.Eat;
                        }
                    } else {
                        var chill_data = find_nearest_place_to_chill(x, y);
                        if chill_data != undefined {
                            self.me.location_position = chill_data.target_location.clone();
                            x = self.me.location_position.pos.x;
                            y = self.me.location_position.pos.y;
                        }

                        initial_state = AnimalState.Wander;
                    }

                    self.weather_bark = 45;
                    self.me.liminal = false;
                } else {
                    initial_state = AnimalState.Idle;
                    self.dir = irandom_range(0, 360);
                }
            } else {
                //
                self.me.eat_data = undefined;
                initial_state = AnimalState.Idle;
                self.dir = irandom_range(0, 360);
            }

            self.fsm = StateMachineBuilder(AnimalState.LEN)
                .add_state(StateBuilder(AnimalState.Idle)
                    .start(function() {
                        animal_idle_start(self);
                    })
                    .step(function() {
                        if self.owner.try_accept_pathfinding_request() {
                            return;
                        }

                        if self.fsm.state_frame >= self.timer_max {
                            //
                            var can_wander = !self.owner.me.is_home()
                                || self.owner.me.prototype.behavior.can_wander_in_home;

                            if can_wander == false && self.fsm.last_state_id != AnimalState.Animate {
                                var animation = select_random_animation_for_animal(owner);
                                if animation != undefined {
                                    self.blackboard.set("animation", animation);
                                    self.fsm.change_state(AnimalState.Animate);
                                }
                            } else if CURRENT_LOCATION_ID == LocationId.Farm
                                && self.owner.me.has_eaten == false
                            {
                                var found_food = self.owner.try_find_food();
                                if found_food == false {
                                    self.fsm.change_state(AnimalState.Wander);
                                }
                            } else if can_wander {
                                self.fsm.change_state(AnimalState.Wander);
                            } else {
                                var animation = select_random_animation_for_animal(owner);
                                if animation != undefined {
                                    self.blackboard.set("animation", animation);
                                    self.fsm.change_state(AnimalState.Animate);
                                }
                            }
                        }
                        self.owner.update_bark_offset();
                    })
                    .spawn()
                )
                .add_state(StateBuilder(AnimalState.Wander)
                    .start(function() {
                        self.wander_out_of_building = self.blackboard.try_take("wander_out_of_building") ?? false;
                        animal_wander_start(self);
                    })
                    .step(function() {
                        if self.owner.try_accept_pathfinding_request() {
                            return;
                        }

                        self.owner.update_bark_offset();

                        if animal_wander_step(self) {
                            if self.wander_out_of_building
                                && self.fsm.state_frame >= self.timer_max
                            {
                                if owner.me.prototype.core.size == AnimalSize.Small {
                                    var target = round(owner.x / 8) * 8;
                                    if abs(owner.x - target) < 1.0 {
                                        owner.x = target;
                                    } else {
                                        return;
                                    }
                                } else {
                                    var target = round(owner.y / 8) * 8;
                                    if abs(owner.y - target) < 1.0 {
                                        owner.y = target;
                                    } else {
                                        return;
                                    }
                                }
                            }

                            //
                            //
                            var was_ignoring_collision = owner.ignore_collision;
                            owner.ignore_collision = false;

                            if CURRENT_LOCATION_ID == LocationId.Farm
                                && self.owner.me[$ "has_eaten"] == false
                            {
                                var found_food = self.owner.try_find_food();
                                if found_food == false {
                                    self.fsm.change_state(AnimalState.Idle);
                                }
                            } else {
                                if was_ignoring_collision {
                                    self.fsm.change_state(AnimalState.Wander);
                                } else {
                                    self.fsm.change_state(AnimalState.Idle);
                                }
                            }
                        }
                    })
                    .stop(function() {
                        animal_wander_stop(self);
                    })
                    .spawn()
                )
                .add_state(StateBuilder(AnimalState.Animate)
                    .start(function() {
                        animal_animate_start(self);
                    })
                    .step(function() {
                        if self.owner.try_accept_pathfinding_request() {
                            return;
                        }

                        if animal_animate_step(self) {
                            self.fsm.change_state(AnimalState.Idle);
                        }
                    })
                    .stop(function() {
                        animal_animate_stop(self);
                    })
                    .spawn()
                )
                .add_state(StateBuilder(AnimalState.Pathfinding)
                    .create(function() {
                        animal_pathfind_create(self);
                        self.finish_food = function(in_room_end) {
                            if owner.try_confirm_eating(in_room_end) {
                                owner.x = owner.me.eat_data.node.top_left_x * 8;
                                owner.y = owner.me.eat_data.node.top_left_y * 8;
                                cleanup_food(owner, GRID.node_index_for_cell(owner.me.eat_data.node.top_left_x, owner.me.eat_data.node.top_left_y), in_room_end);
                                owner.me.eat_data = undefined;
                                return true;
                            }

                            return false;
                        };
                    })
                    .start(function() {
                        animal_pathfind_start(self);
                    })
                    .step(function() {
                        var complete = animal_pathfind_step(self);

                        if complete {
                            if self.destroy_on_end {
                                instance_destroy(owner);
                            } else if self.blackboard.try_take("move_directed_on_end", false) {
                                self.fsm.change_state(AnimalState.MoveDirected);
                            } else {
                                //
                                var is_eating = owner.try_confirm_eating();

                                if is_eating {
                                    self.fsm.change_state(AnimalState.Eat);
                                } else {
                                    self.fsm.change_state(AnimalState.Idle);
                                }
                            }
                        }

                        //
                        if owner.bark_signal != undefined && owner.bark_signal.has_barked == false {
                            var should_bark = false
                            var dist = 0;
                            with owner {
                                dist = distance_to_object(obj_ari);
                            }

                            if dist < 48 {
                                should_bark = true;
                            } else if owner.pathfinding_agent.todo_list().count() <= 6 {
                                should_bark = true;
                            }

                            if should_bark {
                                owner.bark_signal.has_barked = true;

                                if !owner.me.has_eaten {
                                    owner.bark_emitter.emit(BarkId.Hungry, BarkType.Thought);
                                } else if owner.bark_signal.food_at_home {
                                    //
                                    if owner.me.prototype.core.size == AnimalSize.Small {
                                        owner.bark_emitter.emit(BarkId.Seed, BarkType.Thought);
                                    } else {
                                        owner.bark_emitter.emit(BarkId.Hay, BarkType.Thought);
                                    };
                                } else {
                                    owner.bark_emitter.emit(BarkId.Yum, BarkType.Thought);
                                }

                                TANGO.play("SoundEffects/Barks/BubbleNeutral", owner.x, owner.y);
                            }
                        }
                    })
                    .stop(function() {
                        animal_pathfind_stop(self);
                    })
                    .spawn()
                )
                .add_state(StateBuilder(AnimalState.Eat)
                    .create(function() {
                        self.finish_food = function(in_room_end) {
                            if GRID.location_id != LocationId.Farm || GRID.node_object_id[self.eating_instance_node] == undefined {
                                return false;
                            }

                            var cat = object_id_to_object_category(GRID.node_object_id[self.eating_instance_node]);
                            cleanup_food_effects(self.partner, cat);
                            return cleanup_food(owner, self.eating_instance_node, in_room_end);
                        };
                    })
                    .start(function() {

                        //
                        self.owner.me.set_cardinality(owner.me.eat_data.cardinal);
                        self.owner.set_sprites("eat");

                        self.partner = owner.me.eat_data.node.renderer;
                        if instance_is_alive(self.partner) {
                            self.partner.collide(true, self.owner.me.cardinality);
                        }
                        self.time_to_finish = CLOCK.time;
                        self.eating_instance_node = GRID.node_index_for_cell(owner.me.eat_data.node.top_left_x, owner.me.eat_data.node.top_left_y);

                        owner.me.eat_data = undefined;
                    })
                    .step(function() {
                        if GRID.node_object_id[self.eating_instance_node] == undefined {
                            self.owner.try_find_food();
                            return;
                        } else {
                            var node = GRID.node_parent[self.eating_instance_node];
                            //
                            //
                            if object_id_to_object_category(node.prototype.object_id) == ObjectCategory.Crop {
                                var day_to_stage;
                                if node.prototype.post_harvest_day_to_stage != undefined && node.regrow_cycle {
                                    day_to_stage = node.prototype.post_harvest_day_to_stage;
                                } else {
                                    day_to_stage = node.prototype.day_to_stage;
                                }

                                if node.stage != day_to_stage.last() {
                                    self.fsm.change_state(AnimalState.Idle);
                                }
                            }
                        }

                        if instance_is_alive(self.partner)
                            && self.owner.image_index >= self.owner.me.prototype.eating.shake_frames.x
                            && self.owner.image_index < self.owner.me.prototype.eating.shake_frames.y
                        {
                            self.partner.collide(true, self.owner.me.cardinality);
                        }

                        //
                        if ((CLOCK.time - time_to_finish) >= minutes(fiddle_get("misc/eat_time")))
                            || ANCHOR.get_menu(Menu.Eod) != undefined
                        {
                            var dancing = self.finish_food(false);
                            if dancing == false {
                                self.fsm.change_state(AnimalState.Idle);
                            }
                        }
                    })
                    .spawn()
                )
                .add_state(StateBuilder(AnimalState.Held)
                    .start(function() {
                        owner.set_sprites("idle");

                        ARI.held_animal_id = owner.me.idx;
                        obj_ari.par.held_animal_render_callback = function(xx, yy, flipper) {
                            var old_image_xscale = owner.image_xscale;
                            owner.image_xscale = flipper;
                            owner.draw_routine(xx, yy);
                            owner.image_xscale = old_image_xscale;
                        };
                        shadow_caster_set_sprite(owner.shadow_caster, undefined);
                        needs_offset = false;
                    })
                    .step(function() {
                        //
                        owner.x = obj_ari.x;
                        owner.y = obj_ari.y;

                        owner.me.location_position.location_id = CURRENT_LOCATION_ID;
                        owner.me.location_position.dyn_index = CURRENT_DYN_INDEX;
                        owner.me.location_position.pos.x = owner.x;
                        owner.me.location_position.pos.y = owner.y;

                        owner.me.set_cardinality(obj_ari.cardinal);

                        //
                        owner.update_bark_offset();

                        owner.image_xscale = obj_ari.cardinal == Cardinal.West ? -1 : 1;
                    })
                    .spawn()
                )
                .add_state(StateBuilder(AnimalState.UsingToy)
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
                            default: impossible("Non pet animals only expect L/R positions, not {}", self.animal_toy_position);

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
                                owner.set_sprites(owner.me.prototype.celebration_data.adult_animation);
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
                .add_state(StateBuilder(AnimalState.MoveDirected)
                    .start(function() {
                        var move_directed_cardinal = self.blackboard.try_take("move_directed_cardinal");
                        if move_directed_cardinal != undefined {
                            self.owner.me.cardinality = move_directed_cardinal;
                        }
                        self.owner.set_sprites("walk");
                        self.owner.update_bark_offset();
                        self.spd = self.owner.me.move_accel();
                        self.total_distance = self.blackboard.try_take("move_directed_distance", 30);
                    })
                    .step(function() {
                        //
                        owner.ignore_collision = true;

                        switch self.owner.me.cardinality {
                            case Cardinal.North:
                                owner.move.y = -self.spd.y;
                                self.total_distance -= self.spd.y;
                                break;
                            case Cardinal.South:
                                owner.move.y = self.spd.y;
                                self.total_distance -= self.spd.y;
                                break;
                            case Cardinal.West:
                                owner.move.x = -self.spd.x;
                                self.total_distance -= self.spd.x;
                                break;
                            case Cardinal.East:
                                owner.move.x = self.spd.x;
                                self.total_distance -= self.spd.x;
                                break;
                        }

                        if self.total_distance <= 0.0 {
                            instance_destroy(owner);
                        }
                    })
                    .spawn()
                )
                .spawn(initial_state, self, bb);
        },
        step: function() {
            if non_cutscene_pause() {
                if self.fsm.current_state_id() == AnimalState.UsingToy {
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

            if !instance_exists(self) {
                return;
            }

            if CURRENT_LOCATION_ID == LocationId.Farm
                && self.bark_emitter.is_barking() == false
                && ANCHOR.get_menu(Menu.Eod) != undefined
                && SCREEN_FADER.is_in()
            {
                if self.eod_bark <= 0 {
                    self.bark_emitter.emit(BarkId.Annoyed, BarkType.Thought);
                    self.eod_bark = irandom_range(360, 360);
                } else {
                    self.eod_bark -= 1;
                }
            }

            //
            if self.bark_on_sight_timer > -1
                && self.bark_emitter.is_barking() == false
                && instance_exists(obj_ari)
                && (point_distance(self.x, self.y, obj_ari.x, obj_ari.y) < 128)
            {
                //
                if self.me.bark_on_sight == BarkId.Annoyed {
                    TANGO.play(self.me.sounds().negative_react, self.x, self.y);
                }

                self.bark_emitter.emit(self.me.bark_on_sight, BarkType.Thought);
                self.me.bark_on_sight = undefined;
                self.bark_on_sight_timer = -1;
            }

            //
            if self.weather_bark > 0 {
                self.weather_bark -= 1;

                if self.weather_bark <= 0 {
                    self.weather_bark = -1;

                    if WEATHER.is_inclement() {
                        self.bark_emitter.emit(BarkId.Annoyed, BarkType.Thought);
                    } else {
                        self.bark_emitter.emit(BarkId.Summer, BarkType.Thought);
                    }
                }
            }

            if self.treat_sparkle_timer != undefined {
                self.treat_sparkle_timer -= 1;
                if self.treat_sparkle_timer <= 0 {
                    create_animation_effect(x + self.me.prototype.breeding.sparkle_offset.x, y + self.me.prototype.breeding.sparkle_offset.y, depth + self.me.prototype.breeding.sparkle_offset.y, spr_part_sparkle_item_icon);
                    var range = fiddle_get("ranching/misc/treat_sparkle_frequency");
                    self.treat_sparkle_timer = irandom_range(range[0], range[1]);
                }
            }
        },
        draw: function() {
            if self.fsm.current_state_id() == AnimalState.Held {
                return;
            }

            event_inherit(ObjectEvent.Draw);
        },
        draw_end: function() {
            self.bark_emitter.on_draw(!non_cutscene_pause());
        },
        cleanup: function() {
            event_inherit(ObjectEvent.Cleanup);

            self.pathfinding_agent.clear_all_reservations();
            //
            if TAXI.is_traveling() {
                self.try_confirm_eating();
            }
        },
    }
);
