function select_random_animation_for_animal(owner) {
    var animations = owner.me.animations();
    var animation_keys = animations.keys();
    var animation_keys_len = array_length(animation_keys);
    repeat (animation_keys_len * 2) {
        var key = animation_keys[irandom(animation_keys_len - 1)];
        var data = animations.get(key);

        //
        if !data.randomly_selected {
            continue;
        }
        if CLOCK.time < data.time_range.x || CLOCK.time > data.time_range.y {
            continue;
        }
        if owner.me.is_baby() && !array_contains(data.valid_for, "baby") {
            continue;
        }
        if data.valid_for != undefined && !array_contains(data.valid_for, sex_to_string(owner.me.sex)) {
            continue;
        }

        //
        if key == "sleep" && owner.me.is_home() == false {
            continue;
        }

        return key;
    }

    return undefined;
}

function select_random_animation_for_pet(owner) {
    var animations = owner.me.animations();
    var animation_keys = animations.keys();
    var animation_keys_len = array_length(animation_keys);
    repeat (animation_keys_len * 2) {
        var key = animation_keys[irandom(animation_keys_len - 1)];
        var data = animations.get(key);

        //
        if !data.randomly_selected {
            continue;
        }
        if CLOCK.time < data.time_range.x || CLOCK.time > data.time_range.y {
            continue;
        }

        //
        if array_contains(data.white_list, PET_PROTOTYPE.variants.get(owner.me.variant).pet_kind) == false {
            continue;
        }

        //
        if key == "sleep" && owner.me.is_home() == false {
            continue;
        }

        return key;
    }

    return undefined;
}

function animal_idle_start(state) {
    var anim = CLOCK.time >= NIGHT_TIME ? "sleep" : "idle";
    state.owner.set_sprites(anim);
    state.owner.image_index = irandom(sprite_get_number(state.owner.sprite_index) - 1);

    var duration = state.owner.me.active_animation().duration;
    if duration == undefined {
        state.timer_max = I32_MAX;
    } else {
        state.timer_max = irandom_range(duration.x * 60, duration.y * 60);
    }
}

function animal_wander_start(state) {
    state.owner.set_sprites("walk");
    state.dir = irandom(360);

    //
    //
    if state.owner.should_use_hop_movement() {
        state.dir = (state.dir div 90) * 90;
    }
    state.dir = state.blackboard.try_take("wander_direction_override", state.dir);

    //
    state.owner.me.set_cardinality(angle_to_cardinal(state.dir));
    var duration = state.owner.me.active_animation().duration;
    state.timer_max = irandom_range(duration.x * 90, duration.y * 90);
}

function animal_wander_step(state) {
    state.owner.move.x = lengthdir_x(state.owner.move_accel.x, state.dir);
    state.owner.move.y = lengthdir_y(state.owner.move_accel.y, state.dir);

    return state.fsm.state_frame >= state.timer_max
        || state.owner.collision_last_frame != MovementCollisionDirection.NONE;
}

function animal_wander_stop(state) {
    //
    if state.owner.can_update_location_position {
        state.owner.me.location_position.location_id = CURRENT_LOCATION_ID;
        state.owner.me.location_position.dyn_index = CURRENT_DYN_INDEX;
        state.owner.me.location_position.pos.x = state.owner.x;
        state.owner.me.location_position.pos.y = state.owner.y;
    }
}

function animal_pathfind_create(state) {
    state.pos = Vec2();
}

function animal_pathfind_start(state) {
    //
    self.itinerary = state.blackboard.take("itinerary");
    self.destination = self.itinerary.items.get(self.itinerary.cursor).target_location.pos.clone();
    state.owner.pathfinding_agent.set_path(itinerary, 0);

    state.owner.set_sprites("walk");
    destroy_on_end = state.blackboard.try_take("destroy_after_pathfind", false);
    wait_timer = 0;
}

function animal_pathfind_step(state) {
    //
    switch state.owner.pathfinding_agent.move_along_path() {
        case MoveAlongPathResponse.Ok:
            self.wait_timer = 0;
            state.owner.set_sprites("walk");
            state.pos.x = owner.x;
            state.pos.y = owner.y;

            if owner.should_use_hop_movement()
                && owner.me.animation == "walk"
                && owner.image_index >= 2
            {
                owner.move_accel.x = 0;
                owner.move_accel.y = 0;
            } else {
                var spd = owner.me.move_accel();
                owner.move_accel.x = spd.x;
                owner.move_accel.y = spd.y;
            }

            var complete = pathfinding_util_move_along_path(
                state.pos,
                state.owner.move_accel,
                state.owner.move_spd,
                state.owner.pathfinding_agent,
            );

            //
            //
            state.owner.x += state.owner.move_spd.x;
            state.owner.y += state.owner.move_spd.y;

            if state.owner.move_spd.is_zero() == false {
                state.owner.me.set_cardinality(state.owner.move_spd.to_cardinal());
            }
            state.owner.move_spd.set_zero();

            return complete;

        case MoveAlongPathResponse.Err:
            self.wait_timer += 1;
            state.owner.set_sprites("idle");

            if self.wait_timer >= 120 {
                var new_path_data = PATHFINDING.calculate_local_path(
                    owner.x,
                    owner.y,
                    self.destination.x,
                    self.destination.y,
                );

                if new_path_data == undefined {
                    err = PATHFINDING.last_error;
                } else {
                    self.itinerary.current_item().local_path = new_path_data.output_list;
                    self.itinerary.current_item().local_path_distance = new_path_data.distance;
                }

                self.wait_timer = 0;
            }
            return false;
    }
}

function animal_pathfind_stop() {
    owner.me.simulated_distance_traveled = 0;
    owner.wants_to_eat = undefined;
}

function animal_animate_start(state) {
    var animation = state.blackboard.take("animation");
    state.owner.set_sprites(animation);
    state.owner.me.set_cardinality(angle_to_cardinal(state.blackboard.try_take("animation_direction_override", irandom(360))));

    state.animation = state.owner.me.active_animation();
    state.timer_max = I32_MAX;

    state.cycle_count = state.blackboard.try_take("force_end_after_animation");

    if state.animation.duration != undefined {
        state.timer_max = irandom_range(state.animation.duration.x * 60, state.animation.duration.y * 60);
    }
}

function animal_animate_step(state) {
    if instance_at_animation_end(state.owner) {
        if state.cycle_count != undefined {
            state.cycle_count -= 1;

            if state.cycle_count <= 0 {
                return true;
            } else {
                state.owner.image_index = 0;
            }
        }

        if state.animation.end_with_animation {
            return true;
        }
    }

    if state.fsm.state_frame >= state.timer_max {
        return true;
    }

    return false;
}

function animal_animate_stop(state) {
    var callback = state.blackboard.try_take("on_animation_complete");
    if callback != undefined {
        var callback_params = state.blackboard.try_take("on_animation_complete_params") ?? [];
        function_execute_alt(callback, callback_params);
    }
}

//
function cleanup_food(instance, node_idx, in_room_end) {
    switch object_id_to_object_category(GRID.node_object_id[node_idx]) {
        case ObjectCategory.Grass:
            instance.me.feed(ItemId.GrassSeed);
            array_push(GAME_STATS.animal_eats, {
                source: "graze",
                item: "grass_seed",
                day: total_days(),
            });
            erase_object_node_by_parent(GRID, GRID.node_parent[node_idx]);
            return false;

        case ObjectCategory.Crop:
            var crop_proto = GRID.node_parent[node_idx].prototype;
            instance.me.feed(crop_proto.harvest);

            array_push(GAME_STATS.animal_eats, {
                source: "graze",
                item: item_id_to_string(crop_proto.harvest),
                day: total_days(),
            });

            if in_room_end {
                if ARI.perk_active(Perk.CurrencyOfCare) {
                    GRID.lost_items.push({
                        x: instance.x,
                        y: instance.y,
                        items: ListFromArray(array_create(crop_proto.currency, new LiveItem(ItemId.AnimalCurrency))),
                    });
                }
            } else {
                instance.create_animal_currency_dance(crop_proto.currency, false);
            }
            process_crop_harvest(GRID.node_parent[node_idx], instance.me.cardinality);
            return true;

        default: impossible("unexpected object_category");
    }
}

function cleanup_food_effects(instance, category) {
    switch category {
        case ObjectCategory.Grass:
            if instance_exists(instance) {
                create_grass_debris(instance);
                owner.bark_emitter.emit(BarkId.Yum, BarkType.Thought);
                TANGO.play("SoundEffects/Objects/SmallBushDestroy", instance.x, instance.y);
            }
            break;

        case ObjectCategory.Crop:
            if instance_exists(instance) {
                TANGO.play("SoundEffects/Objects/SmallBushDestroy", instance.x, instance.y);
                owner.bark_emitter.emit(BarkId.Music, BarkType.Thought);
            }
            break;
        default: impossible("unexpected object_category");
    }
}
