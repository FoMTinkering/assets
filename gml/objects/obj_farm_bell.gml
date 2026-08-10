object_create(
    "obj_farm_bell",
    object_reserve("par_interactable"),
    {
        sprite_index: undefined,
        create: function() {
            //
            event_inherit(ObjectEvent.Create);

            depth = get_instance_depth(y);

            var fiddle_data = fiddle_get("interaction/farm_bell_offset");
            self.offset_x = fiddle_data[0];
            self.offset_y = fiddle_data[1];
            self.count = 0;

            image_speed = 0;

            self.chain = undefined;

            function bell_out(anim=true) {
                if anim {
                    image_speed = 1;
                    self.sprite_index = self.ringing_sprite;
                    self.count = 0;
                    TANGO.play("SoundEffects/Objects/BellBringOutside");
                }
                var some_door = instance_nearest(self.node.renderer.x, self.node.renderer.y, obj_door);
                self.chain = self.send_out_the_animals(some_door);
                self.chain.append(LinkId.Function, function() {
                    self.chain = undefined;
                });
            }

            function bell_in(anim=true) {
                if anim {
                    image_speed = 1;
                    self.sprite_index = self.ringing_sprite;
                    self.count = 0;
                    TANGO.play("SoundEffects/Objects/BellBringInside");
                }
                var some_door = instance_nearest(self.node.renderer.x, self.node.renderer.y, obj_door);
                self.chain = self.send_in_the_animals(some_door);
                self.chain.append(LinkId.Function, function() {
                    self.chain = undefined;
                });
            }

            //
            self.register_interaction(
                InputId.Interact,
                "misc_local/bell",
                function() {
                    self.mcp = new MultipleChoicePopup("misc_local/bell");

                    self.mcp.option("misc_local/bell_out", function() {
                        self.bell_out();
                    });

                    self.mcp.option("misc_local/bell_in", function() {
                        self.bell_in();
                    });

                    self.mcp.option("misc_local/close", function() {});
                },
                function() {
                    return self.chain == undefined;
                }
            );

            function send_out_the_animals(some_door) {
                //
                var animals = node.stable.animals();
                for (var i = 0; i < animals.count(); i++) {
                    var animal = animals.get(i);

                    //
                    if animal.is_home() {
                        //
                        animal.location_position = new LocationPosition(
                            LocationId.Farm,
                            Vec2(
                                building_send_animal_in_x(animal.stable.building),
                                building_send_animal_in_y(animal.stable.building),
                            ),
                        );

                        animal.liminal = true;
                    }
                }

                var c = new_world_chain(self.id, CURRENT_LOCATION_ID)
                .append(LinkId.Timer, 30);
                if self.node.prototype.open_door {
                    c.append(LinkId.Function, function(some_door) {
                        if some_door != undefined && instance_exists(some_door) {
                            some_door.request_open(1);
                            some_door.requests = 100000;
                        }
                    }, [some_door])
                    .append(LinkId.Timer, 60);
                }

                for (var i = 0; i < animals.count(); i++) {
                    c.append(LinkId.Function, function(animal) {
                        //
                        if ANCHOR.get_menu(Menu.Eod) != undefined {
                            return;
                        }

                        //
                        //
                        if animal.instance == undefined {
                            animal.instance = instance_create_layer(
                                building_send_animal_out_x(animal.stable.building),
                                building_send_animal_out_y(animal.stable.building),
                                "Instances",
                                obj_player_animal,
                                {
                                    me: animal,
                                    liminal_on_screen: true,
                                }
                            );
                        }

                    }, [animals.get(i)])
                    .append(LinkId.Timer, 120);
                }

                if self.node.prototype.open_door {
                    c.append(LinkId.Function, function(some_door) {
                        if some_door != undefined && instance_exists(some_door) {
                            some_door.requests = 0;
                        }
                    }, [some_door]);
                }

                return c;
            }

            function send_in_the_animals(some_door) {
                //
                var animals = node.stable.animals();
                for (var i = 0; i < animals.count(); i++) {
                    var animal = animals.get(i);

                    //
                    if animal.idx == ARI.held_animal_id {
                        continue;
                    }

                    //
                    animal.send_to_stall_point();
                    if animal.instance == undefined {
                        continue;
                    }

                    var bark_signal = {
                        has_barked: false,
                        food_at_home: false,
                    };

                    if animal.has_eaten == false
                        && animal.eat_data == undefined
                        && animal_try_to_eat_from_stable(animal, node.stable)
                    {
                        bark_signal.food_at_home = true;
                    }

                    animal.instance.bark_signal = bark_signal;

                    //
                    if animal.instance != undefined
                        && instance_exists(animal.instance)
                        && animal.instance.fsm.current_state_id() == AnimalState.UsingToy
                    {
                        if animal.instance.fsm.current_state().toy != undefined {
                            animal.instance.y = animal.instance.fsm.current_state().toy.renderer.y;
                            animal.instance.object_id_to_ignore = animal.instance.fsm.current_state().toy.object_id;
                        }

                        animal.instance.fsm.change_state(AnimalState.Wander);
                    }
                }

                //
                with obj_player_animal {
                    self.can_update_location_position = false;
                }

                var c = new_world_chain(self.id, CURRENT_LOCATION_ID)
                .append(LinkId.Timer, 30);

                if self.node.prototype.open_door {
                    c.append(LinkId.Function, function(some_door) {
                        if some_door != undefined && instance_exists(some_door) {
                            some_door.request_open(1);
                            some_door.requests = 100000;
                        }
                    }, [some_door]);
                }

                //
                for (var i = 0; i < animals.count(); i++) {
                    c
                    .append(LinkId.Function, function(animal) {
                        if animal.instance == undefined || ARI.held_animal_id == animal.idx {
                            return;
                        }

                        //
                        var path = PATHFINDING.calculate_local_path(
                            animal.instance.x,
                            animal.instance.y,
                            building_send_animal_in_x(animal.stable.building),
                            building_send_animal_in_y(animal.stable.building),
                        );

                        if path == undefined {
                            //
                            //
                            error("we couldn't get animal {} home today!", animal.name);
                            return;
                        }

                        animal.instance.fsm.blackboard.insert("itinerary", new Itinerary(List(
                            new ItineraryItem(
                                Vec2(animal.instance.x, animal.instance.y),
                                new LocationPosition(
                                    LocationId.Farm,
                                    Vec2(
                                        building_send_animal_in_x(animal.stable.building),
                                        building_send_animal_in_y(animal.stable.building),
                                    ),
                                ),
                                path.distance,
                                path.output_list,
                            )
                        )));
                        animal.instance.fsm.change_state(AnimalState.Pathfinding);
                        animal.instance.fsm.blackboard.insert("move_directed_on_end", true);
                        animal.instance.fsm.blackboard.insert("move_directed_cardinal", cardinal_to_inverse(animal.stable.building.prototype.exit_direction));

                        var dist;
                        if cardinal_is_vertical(animal.stable.building.prototype.exit_direction) {
                            dist = abs(animal.stable.building.prototype.send_animal_in_offset.y);
                        } else {
                            dist = abs(animal.stable.building.prototype.send_animal_in_offset.x);
                        }
                        animal.instance.fsm.blackboard.insert("move_directed_distance", dist);
                    }, [animals.get(i)])
                    .append(LinkId.Timer, 60);
                }

                //
                c.append(LinkId.Await, function(animals) {
                    for (var i = 0; i < animals.count(); i++) {
                        var inst = animals.get(i).instance;
                        if inst != undefined && inst.fsm.current_state_id() == AnimalState.Pathfinding
                            || CURRENT_LOCATION_ID != LocationId.Farm
                        {
                            return false;
                        }
                    }

                    return true;
                }, [animals]);

                if self.node.prototype.open_door {
                    //
                    c.append(LinkId.Function, function(some_door) {
                        if some_door != undefined && instance_exists(some_door) == false {
                            return;
                        }
                        some_door.requests = 0;
                    }, [some_door]);
                }

                return c;
            }

            self.shadow_caster = SHADOW_GRID.caster_create(x, y);
            shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));
        },
        animation_end: function() {
            if sprite_index != self.ringing_sprite {
                return;
            }

            self.count += 1;

            if self.count > 3 {
                sprite_index = self.idle_sprite;
            }
        },
    }
);
