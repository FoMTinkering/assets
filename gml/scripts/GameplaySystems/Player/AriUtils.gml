#macro HUMAN_WALK_SPEED global.__human_walk_speed
HUMAN_WALK_SPEED = 0;

#macro HUMAN_RUN_SPEED global.__human_run_speed
HUMAN_RUN_SPEED = 0;

#macro HUMAN_SWIM_SLOW global.__human_swim_slow
HUMAN_SWIM_SLOW = 0;

#macro HUMAN_SWIM_FAST global.__human_swim_fast
HUMAN_SWIM_FAST = 0;

#macro MOUNT_WALK_SPEED global.__mount_walk_speed
MOUNT_WALK_SPEED = 0;

#macro MOUNT_RUN_SPEED global.__mount_run_speed
MOUNT_RUN_SPEED = 0;

#macro MOUNT_HORSEPOWER_RUN_SPEED global.__mount_horsepower_run_speed
MOUNT_HORSEPOWER_RUN_SPEED = 0;

#macro HUMAN_RUN_JUMP_DISTANCE 48
#macro HUMAN_WALK_JUMP_DISTANCE 25
#macro HUMAN_WATER_JUMP 36
#macro MOUNT_RUN_JUMP_DISTANCE 78
#macro MOUNT_WALK_JUMP_DISTANCE 30
#macro OVERSLEEP_TIME_TARGET hours(10)

//
function initialize_fiddle_movement_speed() {
    HUMAN_WALK_SPEED = fiddle_get("misc/movement_speeds/walk");
    HUMAN_RUN_SPEED = fiddle_get("misc/movement_speeds/run");
    HUMAN_SWIM_SLOW = fiddle_get("misc/movement_speeds/swim_slow");
    HUMAN_SWIM_FAST = fiddle_get("misc/movement_speeds/swim");
    MOUNT_WALK_SPEED = fiddle_get("misc/movement_speeds/mount_walk");
    MOUNT_RUN_SPEED = fiddle_get("misc/movement_speeds/mount_run");
    MOUNT_HORSEPOWER_RUN_SPEED = fiddle_get("misc/movement_speeds/mount_horsepower_run");
}

enum ArmorSlot {
    Head,
    Chest,
    Hands,
    Legs,
    Boots,
    LEN,
}

//
enum Pronouns {
    TheyThem,
    SheHer,
    HeHim,
    SheThey,
    TheyShe,
    HeThey,
    TheyHe,
    HeShe,
    SheHe,
    ItIts,
    All,
    None,
    LEN,
}

enum EndOfDayStatus {
    Normal,
    Fainted,
    Died,
    Protected,
}

enum HoldToUseStatus {
    Hold,
    Pause,
    Animate,
}

function wake_up_sequence() {
    if DEBUG_TOOLS && environment_get_variable("FOM_QUICK_CMD") != undefined {
        return;
    }

    //
    if CALENDAR.time == ARI.wedding_date {
        ARI.end_of_day_status = undefined;
        MIST.request_scene("wedding");
        return;
    }

    if ARI.pending_child != undefined && ARI.pending_child.due_date <= CALENDAR.time {
        ARI.end_of_day_status = undefined;
        switch ARI.pending_child.utero {
            case Utero.Ari:
                MIST.request_scene("player_delivery");
                break;
            case Utero.Spouse:
                MIST.request_scene("spouse_delivery");
                break;
            case Utero.Stork:
                MIST.request_scene("stork_delivery");
                break;
        }
        return;
    }

    var eod = EndOfDayStatus.Normal;

    if SETTINGS.get("oversleep_penalty") {
        eod = ARI.end_of_day_status ?? eod;
    }

    obj_ari.fsm.change_state(PlayerState.Dummy);
    obj_ari.cardinal = Cardinal.South;
    obj_ari.par.set_cardinal(Cardinal.South);
    obj_ari.set_animation(AnimationName.SleepLoop);
    obj_ari.par.unset_modifier(AnimationName.Pickup);
    update_depth_items(obj_ari);

    if !matches(eod, EndOfDayStatus.Normal, EndOfDayStatus.Protected) {
        //
        //
        Game.animal_eat = true;

        obj_ari.set_animation(AnimationName.Idle);

        ARI.set_stamina(ARI.get_stamina() * 0.75, false, true);
        ARI.set_health(ARI.get_health() * 0.75, false, true);
        CLOCK.jump(OVERSLEEP_TIME_TARGET);
    }

    if TEST_SUITE {
        obj_ari.fsm.change_state(PlayerState.Default);
        ARI.end_of_day_status = undefined;
        return;
    }

    var c = new_chain()
        .append(LinkId.Timer, 30)
        .append(LinkId.Function, function() {
            update_depth_items(obj_ari);
            obj_ari.set_animation(AnimationName.SleepEnd);
        })
        .append(LinkId.Await, function() {
            obj_ari.set_cardinal(Cardinal.South);
            if obj_ari.par.animation_complete {
                ARI.held_item_last_frame = undefined;

                with par_NPC {
                    if self.me.is_roommate() {
                        self.me.brain.blackboard.insert("set_can_talk_on_arrival", true);
                    }
                }
                return true;
            }
            return false;
        });

    if eod == EndOfDayStatus.Normal {
        c.append(LinkId.Function, function() {
            obj_ari.fsm.change_state(PlayerState.Default);
        });
    } else {
        c.append(LinkId.Function, function(eod) {
            obj_ari.set_animation(AnimationName.Idle);
            if eod != EndOfDayStatus.Protected {
                obj_ari.bark_emitter.emit(BarkId.Annoyed, BarkType.Thought, true);
            }
        }, [eod])
        .append(LinkId.Await, function() {
            return !obj_ari.bark_emitter.is_barking();
        })
        .append(LinkId.Function, function(eod) {
            var full_name = format("Conversations/start_day_status/{EndOfDayStatus}", eod);
            play_conversation_from_path(NpcId.Caldarus, full_name, function() {
                obj_ari.fsm.change_state(PlayerState.Default);
            });
        }, [eod]);
    }

    c.append(LinkId.Function, function() {
        var photo_id = ARI.quest_artifacts.try_take("wedding_photo_index");
        if photo_id != undefined {
            var photo_card = new LiveItem(DATES[Date.Wedding].photo_item);
            photo_card.date_photo = array_length(DATE_PHOTOS) - 1;
            ARI.give_item(photo_card);
            spawn_date_photo(photo_card.date_photo);
        }
    });

    c.append(LinkId.Function, function() {
        ARI.end_of_day_status = undefined;
    })
}

function item_from_critical_poof(xx, yy, drop_bundle, direction_min=0, direction_max=360, stack_items=false) {
    var real_drop = drop_item_input_cleanup(drop_bundle);
    if real_drop == undefined {
        return;
    }
    for (var i = 0, ic = array_length(real_drop); i < ic; i++) {
        var live_item = real_drop[i];
        if live_item.item_id == ItemId.RecipeScroll || live_item.item_id == ItemId.CraftingScroll {
            ARI.recipes_created[live_item.inner_item] = true;
        }

        if live_item.prototype.set_unlock != undefined {
            ARI.recipes_created[live_item.item_id] = true;
        }

        if live_item.prototype.tags.contains("legendary_fish") {
            ARI.legendary_fish_caught[CALENDAR.season()] = true;
        }
    }

    var critical_vfx = create_animation_effect(xx, yy, -100000, spr_fx_critical_swing_poof);
    critical_vfx.drop_bundle = real_drop;
    critical_vfx.direction_min = direction_min;
    critical_vfx.direction_max = direction_max;
    TANGO.play("SoundEffects/Inventory/StaminaPreSpawnPoof", xx, yy);
    critical_vfx.image_idx = 4;

    if !stack_items {
        critical_vfx.image_idx_func = method(critical_vfx, function() {
            //
            if self.drop_bundle == undefined {
                return;
            }

            for (var i = 0; i < array_length(self.drop_bundle); i++) {
                drop_item_default_setup(
                    instance_create_layer(self.x, self.y, "Instances", obj_item),
                    List(self.drop_bundle[i]),
                    drop_item_random_dir_distance(self.direction_min, self.direction_max),
                );
            }
            TANGO.play("SoundEffects/Inventory/ItemDrop", self.x, self.y);
        });
    } else {
        critical_vfx.image_idx_func = method(critical_vfx, function() {
            drop_item_default_setup(
                instance_create_layer(self.x, self.y, "Instances", obj_item),
                ListFromArray(self.drop_bundle),
                drop_item_random_dir_distance(self.direction_min, self.direction_max),
            );
            TANGO.play("SoundEffects/Inventory/ItemDrop", self.x, self.y);
        });
    }
}

//
function all_player_beds() {
    var output = List();

    for (var i = 0; i < LocationId.LEN; i++) {
        var grid = GRIDS[i];
        if !is_home_location(i) || grid == undefined {
            continue;
        }

        var node_tick = irandom(I32_MAX);
        for (var xx = 0; xx < grid.dims.x; xx++) {
            for (var yy = 0; yy < grid.dims.y; yy++) {
                var ni = grid.node_index_for_cell(xx, yy);
                var node = grid.node_parent[ni];
                if node == undefined {
                    continue;
                }
                if node.last_update == node_tick {
                    continue;
                }
                var category = object_id_to_object_category(grid.node_object_id[ni]);
                node.last_update = node_tick;
                if category == ObjectCategory.Furniture && node.prototype.bed_kind != undefined {
                    output.push({
                        location_id: i,
                        ni,
                    });
                }
            }
        }
    }

    return output;
}

//
//
function player_bed() {
    if ARI.last_bed_used == undefined
        || GRIDS[ARI.last_bed_used.location_id].node_parent[ARI.last_bed_used.ni] == undefined
    {
        warn("Couldn't find Ari's last used bed! Finding a different one...");
        return all_player_beds().first();
    } else {
        return ARI.last_bed_used;
    }
}

//
//
function player_wake_position() {
    var bed = player_bed();

    if bed != undefined {
        var node = GRIDS[bed.location_id].node_parent[bed.ni];
        var offset = bed_sleep_offset(node.object_id);
        return new LocationPosition(
            bed.location_id,
            Vec2(node.top_left_x * 8 + offset.x, node.top_left_y * 8 + offset.y),
        );
    } else {
        warn("Couldn't find any bed for Ari! Using a safe position...");
        return new LocationPosition(
            LocationId.PlayerHome,
            player_home_safe_position(LocationId.PlayerHome),
        );
    }
}

function has_unstuck_position() {
    return is_home_location(CURRENT_LOCATION_ID)
        || CURRENT_LOCATION_ID == LocationId.Dungeon
        || LOCATIONS[CURRENT_LOCATION_ID].safe_position != undefined;
}

//
function player_home_safe_position(location_id) {
    switch location_id {
        case LocationId.PlayerHome:
            if DECOR.size_upgrade == HomeUpgrade.Small {
                return Vec2(184, 244);
            } else {
                return Vec2(184, 308);
            }
        break;
        case LocationId.PlayerHomeUpperCentral:
                //
                //
                return Vec2(184, 300);
            break;

        case LocationId.PlayerHomeEast:
        case LocationId.PlayerHomeUpperEast:
            return Vec2(79, 160);
        break;

        case LocationId.PlayerHomeWest:
        case LocationId.PlayerHomeUpperWest:
            return Vec2(288, 160);
        break;

        default: impossible("Location {LocationId} is not a valid home location", location_id);
    }
}

//
function player_home_random_position(location_id) {
    static MAX_ATTEMPTS = 100;
    var grid = GRIDS[location_id];
    var boundary = undefined;
    if location_id == LocationId.PlayerHome {
        boundary = DECOR.size_upgrade == HomeUpgrade.Small
            ? [11, 13, 34, 28]
            : [7, 13, 38, 36];
    } else if is_home_location(location_id) {
        boundary = [11, 13, 34, 40];
    } else {
        boundary = [0, 0, grid.dims.x - 1, grid.dims.y - 1];
    }
    for (var i = 0; i < MAX_ATTEMPTS; i++) {
        var xx = irandom_range(boundary[0], boundary[2]);
        var yy = irandom_range(boundary[1], boundary[3]);
        var ni = grid.node_index_for_cell(xx, yy);
        if grid.node_collideable[ni] == false {
            return Vec2(xx * 8 , yy * 8);
        }
    }

    return player_home_safe_position(location_id);
}

function create_default_mount(kind) {
    var animal = new NonPlayerAnimal(AnimalKind.Horse, kind, Sex.Male);
    animal.days_old = 10;
    animal.name = local_get(format("misc_local/{}", kind));
    return animal;
}

function item_was_purchased_today(live_item) {
    var today = total_days();
    var this_item = live_item.pretty_print();

    try {
        for (var i = array_length(GAME_STATS.purchases) - 1; i >= 0; i--) {
            var purchase = GAME_STATS.purchases[i];
            if purchase.day != today {
                break;
            }

            if purchase.item == this_item {
                return true;
            }
        }
    } catch (e) {
        return false;
    }

    return false;
}

function ari_can_talk() {
    //
    if instance_exists(obj_ari) == false {
        return true;
    }

    return obj_ari.is_mounted() == false && ARI.fire_breath_time <= 0;
}

function ari_teleport_to_room(destination_location, destination_x, destination_y) {
    //
    new_chain()
        .append(LinkId.Await, function() {
            return obj_ari.fsm.check_state_inclusive(PlayerState.Pathfind) == false;
        })
        .append(LinkId.Function, function() {
            //
            obj_ari.set_cardinal(Cardinal.South);
            obj_ari.fsm.change_state(PlayerState.Dummy);
            TANGO.play("SoundEffects/Entrances/Teleport", obj_ari.x, obj_ari.y);

            if ARI.held_animal_id == undefined
                && (ARI.held_item() == undefined || ARI.held_item().prototype.hold_over_head == false)
            {
                obj_ari.par.set_animation(AnimationName.Celebrate);
                obj_ari.par.set_base_hold_on_last_frame();
            }
        })
        .append(LinkId.Ease, new Ease(EaseId.SineIn, 0.0, 1.0, 30), function(_, ab) {
            obj_ari.par.blend = {
                src_mode: bm_src_alpha,
                dest_mode: bm_inv_src_alpha,
                color: c_white,
                alpha: floor(ab * 10.0) / 10.0,
            };
        })
        .append(LinkId.Timer, 6)
        .append(LinkId.Function, function() {
            obj_ari.par.blend = undefined;
            obj_ari.image_alpha = 0.0;
            obj_ari.par.alpha = 0.0;
            shadow_caster_set_alpha(obj_ari.shadow_caster, 0.0);

            create_animation_effect(
                obj_ari.x,
                obj_ari.y,
                -10000,
                spr_fx_teleport_disappear
            );
        })
        .append(LinkId.Timer, 25)
        .append(LinkId.Function, function(destination_location, destination_x, destination_y) {
            goto_location_id(destination_location)
                .set_exact_position(destination_x, destination_y);
        }, [destination_location, destination_x, destination_y])
        .append(LinkId.Await, function(destination_location) {
            return CURRENT_LOCATION_ID == destination_location;
        }, [destination_location])
        .append(LinkId.Function, function() {
            //
            obj_ari.set_cardinal(Cardinal.South);
            obj_ari.fsm.change_state(PlayerState.Dummy);
            if ARI.held_animal_id == undefined
                && (ARI.held_item() == undefined || ARI.held_item().prototype.hold_over_head == false)
            {
                obj_ari.par.set_animation(AnimationName.Celebrate);
                obj_ari.par.set_base_hold_on_last_frame();
            }

            shadow_caster_set_alpha(obj_ari.shadow_caster, 0.0);
            //
            obj_ari.image_alpha = 0.0;
            obj_ari.par.alpha = 0.0;

            create_animation_effect(
                obj_ari.x,
                obj_ari.y,
                -10000,
                spr_fx_teleport_appear
            );
            TANGO.play("SoundEffects/Entrances/TeleportEnd", obj_ari.x, obj_ari.y);
        })
        .append(LinkId.Timer, 49)
        .append(LinkId.Function, function() {
            shadow_caster_set_alpha(obj_ari.shadow_caster, 1.0);
            obj_ari.image_alpha = 1.0;
            obj_ari.par.alpha = 1.0;

            //
            obj_ari.par.blend = {
                src_mode: bm_src_alpha,
                dest_mode: bm_inv_src_alpha,
                color: c_white,
                alpha: 1.0,
            };
        })
        .append(LinkId.Ease, new Ease(EaseId.Linear, 1.0, 0.0, 45), function(_, ab) {
            obj_ari.par.blend = {
                src_mode: bm_src_alpha,
                dest_mode: bm_inv_src_alpha,
                color: c_white,
                alpha: floor(ab * 10.0) / 10.0,
            };
        })
        .append(LinkId.Function, function() {
            obj_ari.par.blend = undefined;
            obj_ari.fsm.change_state(PlayerState.Default);
            obj_ari.par.set_base_loop();
        });
}

#macro PRONOUNS global.__pronouns
PRONOUNS = undefined;

function load_pronouns() {
    return local_get_pronouns();
}

function default_pronouns() {
    return local_get_default_pronouns();
}

//
function try_path_ari_to(target_pos) {
    var path_data = PATHFINDING.calculate_local_path(
        obj_ari.x,
        obj_ari.y,
        target_pos.x,
        target_pos.y,
    );
    if path_data == undefined {
        return false;
    } else {
        obj_ari.fsm.blackboard.set("itinerary", new Itinerary(List(new ItineraryItem(
            new LocationPosition(CURRENT_LOCATION_ID, Vec2(obj_ari.x, obj_ari.y)),
            new LocationPosition(CURRENT_LOCATION_ID, target_pos),
            0,
            path_data.output_list
        ))));

        obj_ari.fsm.blackboard.set("move_accel", Vec2(HUMAN_WALK_SPEED, HUMAN_WALK_SPEED));
        obj_ari.fsm.blackboard.set("end_state", PlayerState.Default);
        obj_ari.fsm.change_state(PlayerState.Pathfind);
        return true;
    }
}

function mouse_cardinal() {
    var xx = mouse_x() - obj_ari.x;
    var yy = mouse_y() - obj_ari.y;
    if abs(xx) > abs(yy) {
        return xx < 0 ? Cardinal.West : Cardinal.East;
    } else {
        return yy < 0 ? Cardinal.North : Cardinal.South;
    }
}

function date_eligible_for_wedding(time) {
    var season = get_seasons(time);
    var day = get_days(time);
    for (var i = 0; i < FestivalId.LEN; i++) {
        var festival = FESTIVALS[i];
        if !festival.prototype.implemented {
            continue;
        }
        if festival.prototype.date.season == season && festival.prototype.date.day - 1 == day {
            return false;
        }
    }

    if season == get_seasons(ARI.birthday) && day == get_days(ARI.birthday) {
        return false;
    }

    if !is_between_inclusive(time, ARI.proposal_date + days(5), ARI.proposal_date + days(14)) {
        return false;
    }

    return true;
}

function process_proposal(fiance) {
    T2R.write(format("{NpcId}_status", fiance), "fiance");
    ARI.proposal_date = CALENDAR.time;
    if !ARI.disable_break_ups {
        for (var i = 0; i < NpcId.LEN; i++) {
            var npc = NPCS[i];
            if npc.is_dating() {
                T2R.write(format("{NpcId}_status", i), "best_friend");
                T2R.write(format("{NpcId}_is_ex", i), true);
            }

            npc.report_relationship();
        }
    }

    t2_write_world_fact("disabled_break_up_content", ARI.disable_break_ups || ARI.disable_break_up_letters);
    t2_write_world_fact("proposed_today", true);

    remove_item_from_world(ItemId.EngagementRing);
    ARI.recipe_unlocks[ItemId.EngagementRing] = false;

    ARI.wedding_date = ARI.proposal_date;
    while !date_eligible_for_wedding(ARI.wedding_date) {
        ARI.wedding_date += days(1);
    }

    spawn_calendar_ui(ARI.wedding_date)
        .with_filter(date_eligible_for_wedding)
        .with_today(CALENDAR.time)
        .with_banner("misc_local/select_your_wedding_day")
        .enable_selection(function(ui) {
            var popup = popup_creator(
                "misc_local/confirmation",
                ANCHOR.wrap_for_local(format(
                    local_get("misc_local/wedding_date_confirmation"),
                    localize_date(ui.time, false)
                )),
            );
            popup.create_button("misc_local/no");
            popup.create_button("misc_local/yes", function(ui) {
                ARI.wedding_date = ui.time;
                ui.close();
            }, [ui]);
            popup.spawn();
        })
        .build();
}

//
function process_marriage(spouse) {
    T2R.write(format("{NpcId}_status", spouse), "spouse");
    NPCS[spouse].report_relationship();
    report_children_facts();
}

//
//
function build_obj_ari_par_from(preset) {
    with obj_ari {
        ARI.animation_assets().assets.for_each(function(asset) {
            self.par.remove_asset(asset.name);
        });
        preset.apply_to_par(self.par);

        handle_child_on_par(self.par);
    }
}

//
function handle_child_on_par(par) {
    if ARI == undefined {
        return;
    }
    var child = ARI.held_child();
    if child != undefined {
        par.slots[AnimationSlot.BackGear].asset = undefined;
        par.slots[AnimationSlot.BackGear].lut_data = undefined;

        par.set_asset(child.get_player_asset(), 1);
    } else {
        for (var i = 0; i < array_length(ARI.children); i++) {
            var child = ARI.children[i];
            par.remove_asset(child.get_player_asset());
        }
    }
}
