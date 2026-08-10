#macro LOCATIONS global.__locations
global.__locations = undefined;

#macro MIST_SIGHT_LIST global.__mist_list
global.__mist_list = List();

function load_locations() {
    LOCATIONS = array_create(LocationId.LEN, undefined);
    var locations = fiddle_get("locations");
    var location_default = locations[$ "default"];
    var keys = struct_get_names(locations);
    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];
        if key == "default" {
            continue;
        }
        var location_id = string_to_location_id(key);
        var location = locations[$ key];
        var gm_room_name = location[$ "gm_room"] ?? location_default.gm_room;
        if gm_room_name == "<..>" {
            gm_room_name = fmt("rm_{}", key);
        }
        var map_location = location[$ "map_location"] ?? location_default.map_location;
        if map_location == "<..>" {
            map_location = key;
        }

        var music = location[$ "music"] ?? location_default.music;
        if music == "<n/a>" {
            music = undefined;
        } else if !is_struct(music) {
            music = { day: audio_asset_assert_exists(music), night: undefined };
        } else {
            audio_asset_assert_exists(music.day);
            audio_asset_assert_exists(music.night);
        }

        var ambience = location[$ "ambience"] ?? location_default.ambience;
        if ambience == "<n/a>" {
            ambience = undefined;
        } else if !is_struct(ambience) {
            ambience = { day: audio_asset_assert_exists(ambience), night: audio_asset_assert_exists(ambience) };
        } else {
            audio_asset_assert_exists(ambience.day);
            audio_asset_assert_exists(ambience.night);
        }

        map_location = string_to_location_id(map_location);

        var bug_boxes = undefined;
        if location[$ "bug_boxes"] != undefined {
            bug_boxes = new SlowVotes();
            for (var j = 0; j < array_length(location.bug_boxes); j++) {
                var bug_box = [
                    fiddle_deserialize_vec2(location.bug_boxes[j][0]),
                    fiddle_deserialize_vec2(location.bug_boxes[j][1]),
                ];
                var area = (bug_box[1].x - bug_box[0].x) * (bug_box[1].y - bug_box[0].y);

                bug_boxes.add_candidate(bug_box, area);
            }
        }
        var bug_water_boxes = undefined;
        if location[$ "bug_water_boxes"] != undefined {
            bug_water_boxes = new SlowVotes();
            for (var j = 0; j < array_length(location.bug_water_boxes); j++) {
                var bug_box = [
                    fiddle_deserialize_vec2(location.bug_water_boxes[j][0]),
                    fiddle_deserialize_vec2(location.bug_water_boxes[j][1]),
                ];
                var area = (bug_box[1].x - bug_box[0].x) * (bug_box[1].y - bug_box[0].y);

                bug_water_boxes.add_candidate(bug_box, area);
            }
        }

        if location["mist_sights"] != undefined {
            for (var sight_idx = 0; sight_idx < array_length(location.mist_sights); sight_idx++) {
                MIST_SIGHT_LIST.push({
                    location_id,
                    pos: Vec2(location.mist_sights[sight_idx][0], location.mist_sights[sight_idx][1])
                });
            }
        }

        LOCATIONS[location_id] = {
            id: location_id,
            name: location[$ "name"],
            forageables: location[$ "forageables"] ?? location_default.forageables,
            bugs: location[$ "bugs"] ?? location_default.bugs,
            gm_room: string_to_asset(gm_room_name),
            outdoor: location[$ "outdoor"] ?? location_default.outdoor,
            farm: location[$ "farm"] ?? location_default.farm,
            npc_farm: location[$ "npc_farm"] ?? location_default.npc_farm,
            serializable: location[$ "serializable"] ?? location_default.serializable,
            reset_every_night: location[$ "reset_every_night"] ?? location_default.reset_every_night,
            map_location: map_location,
            music: music,
            ambience: ambience,
            dig_sites: location[$ "dig_sites"] ?? location_default.dig_sites,
            special_dig_sites: location[$ "special_dig_sites"] ?? location_default.special_dig_sites,
            inhibit_music: location[$ "inhibit_music"] ?? location_default.inhibit_music,
            bird_count: fiddle_deserialize_vec2(location[$ "bird_count"]),
            building: location[$ "building"],
            npa_spawn_points: location[$ "npa_spawn_points"] ?? [],
            replace_tilemaps: location[$ "replace_tilemaps"] ?? location_default.replace_tilemaps,
            ignore_seasons: location[$ "ignore_seasons"] ?? location_default.ignore_seasons,
            bug_tag: parse_bug_tag(location[$ "bug_tag"] ?? location_default.bug_tag),
            lost_and_found: location[$ "lost_and_found"] ?? location_default.lost_and_found,
            bug_boxes,
            bug_water_boxes,
            safe_position: location[$ "safe_position"],
            wall_shadows: location["wall_shadows"],
        };
    }
}

//
function location_id_to_gm_room(location_id) {
    if location_id == LocationId.Dungeon {
        return DUNGEON_RUNNER.current_level().gm_room;
    }
    return LOCATIONS[location_id].gm_room;
}

//
function gm_room_to_location_id(rm) {
    if is_dungeon_room(rm) && !is_special_dungeon_room(rm) {
        return LocationId.Dungeon;
    }
    for (var i = 0; i < LocationId.LEN; i++) {
        if LOCATIONS[i].gm_room == rm {
            return i;
        }
    }

    return undefined;
}

//
function display_location(loc_id, dyn_index, rm) {
    if loc_id == LocationId.Dungeon {
        return format("Dungeon<{gm_room}>", rm);
    }
    if dyn_index != undefined {
        return format("{LocationId}<dyn {}>", loc_id, dyn_index);
    } else {
        return location_id_to_string(loc_id);
    }
}

function is_home_location(location) {
    return LOCATIONS[location].building == "player_home";
}

//
//
//
//
#macro PLAYER_LOCATION_NEIGHBORS global.__player_location_neighbors
PLAYER_LOCATION_NEIGHBORS = array_create_ext(LocationId.LEN, function(v) {
    switch v {
        case LocationId.PlayerHome: return [
            LocationId.PlayerHomeWest,
            LocationId.PlayerHomeEast,
            LocationId.PlayerHomeUpperCentral,
            LocationId.Farm,
        ];
        case LocationId.PlayerHomeWest: return [
            LocationId.PlayerHome,
            LocationId.PlayerHomeUpperWest,
        ];
        case LocationId.PlayerHomeEast: return [
            LocationId.PlayerHome,
            LocationId.PlayerHomeUpperEast,
        ];
        case LocationId.PlayerHomeUpperWest: return [
            LocationId.PlayerHomeWest,
            LocationId.PlayerHomeUpperCentral,
        ];
        case LocationId.PlayerHomeUpperEast: return [
            LocationId.PlayerHomeEast,
            LocationId.PlayerHomeUpperCentral,
        ];
        case LocationId.PlayerHomeUpperCentral: return [
            LocationId.PlayerHome,
            LocationId.PlayerHomeUpperEast,
            LocationId.PlayerHomeUpperWest,
        ];
        case LocationId.Farm: return [
            LocationId.PlayerHome,
        ];
        default: return undefined;
    }
});

//
function location_room_functions() {
    for (var i = 0; i < LocationId.LEN; i++) {
        if i != LocationId.Dungeon {
            var gm_room = location_id_to_gm_room(i);
            assert_eq(i, gm_room_to_location_id(gm_room));
        }
    }
}
