#macro TAXI global.__taxi
global.__taxi = undefined;

//
//
function goto_location_id(location_id, instant=false) {
    var gm_room = location_id_to_gm_room(location_id);
    return goto_gm_room(gm_room, instant);
}

//
//
function goto_dynamic_location(dyn_index, instant=false) {
    var gm_room = location_id_to_gm_room(DYNAMIC_GRIDS.get(dyn_index).location_id);
    var itin = TaxiItinerary(gm_room, dyn_index);
    itin.set_instant(instant);
    TAXI.taxi_player(itin);
    return itin;
}

//
//
function goto_gm_room(gm_room, instant=false) {
    var itin = TaxiItinerary(gm_room);
    itin.set_instant(instant);
    TAXI.taxi_player(itin);
    return itin;
}

enum TaxiItineraryMode {
    General,
    Tag,
    Exact,
}

//
function TaxiItinerary(gm_room, dyn_index) {
    return {
        mode: TaxiItineraryMode.General,
        instant: false,
        player_sleep_flag: false,
        gm_room: gm_room,
        destination: gm_room_to_location_id(gm_room),
        dyn_index: dyn_index,
        player_tag: undefined,
        player_position: undefined,
        player_flag: true,
        arrival_callback: undefined,
        arrival_callback_args: [],
        run_prologue: false,
        mines: undefined,
        set_arrival_callback: function(func, args) {
            self.arrival_callback_args = args == undefined ? [] : args;
            self.arrival_callback = func;
            return self;
        },
        set_instant: function(bool) {
            self.instant = bool;
            return self;
        },
        set_specific_location_tag: function(string) {
            self.mode = TaxiItineraryMode.Tag;
            self.player_tag = string;
            return self;
        },
        set_exact_position: function(x, y) {
            self.mode = TaxiItineraryMode.Exact;
            self.player_position = Vec2(x, y);
            return self;
        },
        set_player_asleep_flag: function() {
            self.player_sleep_flag = true;
            return self;
        },
        no_player: function() {
            self.player_flag = false;
            return self;
        }
    }
}

//
function Taxi() constructor {
    self.location_last = undefined;
    self.index_last = undefined;
    self.location_current = undefined;
    self.itinerary = undefined;
    self.room_swap_request = undefined;

    //
    function current_location_id() {
        return self.location_current;
    }

    //
    function is_traveling() {
        return self.itinerary != undefined;
    }

    //
    //
    function taxi_player(taxi_itinerary) {
        assert(is_world_room(room()), "You MUST use `enter_world` to enter the world!");
        self.location_last = self.current_location_id();
        self.index_last = CURRENT_DYN_INDEX;
        self.itinerary = taxi_itinerary;
        //
        if self.itinerary.instant {
            self.room_swap_request = self.itinerary.gm_room;
        } else {
            SCREEN_FADER.fade_out(FADE_SPEED_TRANSITION, function() {
                self.room_swap_request = self.itinerary.gm_room;
            });
        }

        //
        //
        if MUSIC_PLAYER.is_on() {
            var potential_track = MUSIC_PLAYER.selector(self.itinerary.destination);
            if !matches(potential_track, undefined, MUSIC_PLAYER.current_track()) {
                MUSIC_PLAYER.stop();
            }
        }
    }

    //
    function enter_world(is_manual_save, run_prologue=false, location_position) {
        var location = run_prologue ? LocationId.AdelinesOffice : location_position.location_id;
        assert(
            !is_world_room(room()) && self.location_current == undefined,
            "`enter_world` is only for... entering the world. We are in room {GmRoom} and location_current = {LocationId}",
            room(), self.location_current,
        );
        self.itinerary = TaxiItinerary(location_id_to_gm_room(location))
            //
            .set_instant(true)
            .set_arrival_callback(function(is_manual_save, run_prologue, location_position) {
                //
                //
                var dir = ARI.player_dir_game_start ?? 0;

                var pos = run_prologue ? Vec2Zero() : location_position.pos;

                self.place_player_in_room(pos, dir);

                if run_prologue {
                    request_hud_hide();
                    MIST.run_scene("prologue");
                } else if is_manual_save == false {
                    wake_up_sequence();
                }

            }, [is_manual_save, run_prologue, location_position])
        self.room_swap_request = self.itinerary.gm_room;
        self.itinerary.run_prologue = run_prologue;
        self.depart();
    }

    //
    //
    function resolve_player_position() {
        var direction_to_face = 0;

        var position = undefined;

        var special_override = matches(self.location_last, LocationId.VoidSeal, LocationId.RuinsSeal)
            && matches(CURRENT_LOCATION_ID, LocationId.VoidSeal, LocationId.RuinsSeal);

        //
        if is_dungeon_room(room()) && !special_override {
            if ARI.used_elevator && CURRENT_LOCATION_ID != LocationId.SeridiasChamber {
                position = Vec2(
                    obj_dungeon_elevator.x,
                    obj_dungeon_elevator.y + 24,
                );
            } else {
                if is_special_dungeon_room(room()) {
                    var point = trellis_point_find_by_name(
                        location_id_to_gm_room(CURRENT_LOCATION_ID),
                        "ari_spawn",
                        TrellisPointDataRequest.DIRECTION
                    );
                    assert_defined(point, "failed to find ari_spawn point");
                    position = Vec2(point.x, point.y);
                    direction_to_face = cardinal_to_angle(point.direction);
                } else {
                    position = Vec2(
                        obj_dungeon_ladder_up.x,
                        obj_dungeon_ladder_up.y + 8,
                    );
                }
            }
        } else {
            //
            var found_transition = undefined;

            for (var i = 0; i < instance_number(obj_roomtransition); i++) {
                var inst = instance_find(obj_roomtransition, i);
                switch self.itinerary.mode {
                    case TaxiItineraryMode.General:
                        if inst.destination_id == self.location_last && inst.dyn_index == self.index_last {
                            found_transition = inst;
                        }
                        break;
                    case TaxiItineraryMode.Tag:
                        if self.itinerary.player_tag == inst.specific_key {
                            found_transition = inst;
                        }
                        break;
                    default: impossible("Unexpected TaxiItineraryMode: {}", self.itinerary_mode);
                }
                if found_transition != undefined {
                    direction_to_face = (found_transition.player_direction + 180) mod 360;
                    var w = (found_transition.bbox_right - found_transition.bbox_left) / 2;
                    var h = (found_transition.bbox_bottom - found_transition.bbox_top) / 2;
                    position = Vec2(
                        found_transition.x + w + lengthdir_x(w + 8, direction_to_face),
                        found_transition.y + h + lengthdir_y(h + 8, direction_to_face),
                    );
                    break;
                }
            }
        }

        //
        if position == undefined {
            if LOCATIONS[CURRENT_LOCATION_ID].safe_position != undefined {
                if !TEST_SUITE {
                    warn("Could not find any transition. Dropping player at safe position...");
                }
                position = Vec2(LOCATIONS[CURRENT_LOCATION_ID].safe_position[0], LOCATIONS[CURRENT_LOCATION_ID].safe_position[1]);
            } else {
                if !TEST_SUITE {
                    warn("Could not find any transition. Dropping player at the center of the room...");
                }
                position = Vec2(room_width() / 2, room_height() / 2);
            }
        }

        return {
            position: position,
            direction: direction_to_face,
        }
    }

    //
    function place_player_in_room(position, direction_to_face) {
        obj_ari.x = position.x;
        obj_ari.y = position.y;

        obj_ari.face_dir(direction_to_face);
        CAMERA.follow_instance_instant(obj_ari);
        tango_listener_position(position.x, position.y);

        if ARI.held_animal_id != undefined {
            obj_ari.summon_held_animal();
        }
    }

    //
    function arrive() {
        self.location_current = self.itinerary.destination;
        if self.itinerary.player_flag {
            var position;
            var direction_to_face = 0;

            if self.itinerary.mode == TaxiItineraryMode.Exact {
                position = self.itinerary.player_position;
            } else {
                var pos_dir = self.resolve_player_position();
                position = pos_dir.position;
                direction_to_face = pos_dir.direction;
            }

            self.place_player_in_room(position, direction_to_face);
        } else {
            instance_destroy(obj_ari);
        }
        if self.itinerary.player_sleep_flag {
            wake_up_sequence();
        }
        if self.itinerary.arrival_callback != undefined {
            function_execute_alt(self.itinerary.arrival_callback, self.itinerary.arrival_callback_args);
        }
        if !self.itinerary.instant {
            SCREEN_FADER.fade_in(FADE_SPEED_TRANSITION, function() {
                if room() == rm_farm {
                    with obj_node_renderer {
                        if self.object_id == ObjectId.Mailbox && ARI.inbox.has_unread_mail() {
                            self.bouncer.override_request_bounce = 30;
                        }
                    }
                }
            });
        }

        self.itinerary = undefined;
        self.chain = undefined;
        var key = location_id_to_string(CURRENT_LOCATION_ID);
        var visits = GAME_STATS.location_visits[key] ?? 0;
        GAME_STATS.location_visits[key] = visits + 1;
    }

    //
    function depart() {
        if self.room_swap_request != undefined {
            if self.itinerary.mines != undefined {
                DUNGEON_RUNNER.post_proceed(self.itinerary.mines);
            }

            trace(
                "Executing a swap to '{}'",
                display_location(
                    self.itinerary.destination,
                    self.itinerary.dyn_index,
                    self.room_swap_request,
                ),
            );
            room_goto(self.room_swap_request);

            var output = self.room_swap_request;
            self.room_swap_request = undefined;

            return output;
        } else {
            return undefined;
        }
    }
}
