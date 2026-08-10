#macro MUSIC_PLAYER global.__music_player
MUSIC_PLAYER = undefined;

#macro AMBIENCE_PLAYER global.__ambience_player
AMBIENCE_PLAYER = undefined;

function SceneAudioPlayer(selector) constructor {
    self.selector = selector;
    self.play_all_children = false;
    self.crossfade = false;
    self.state = SceneAudioState.Off;
    self.locked = false;
    self.controller = undefined;
    self.requested_track = undefined;

    //
    //
    function refresh() {
        var selection = self.selector(instance_exists(Game) ? CURRENT_LOCATION_ID : undefined);

        if self.state.id == SceneAudioStateId.On {
            if selection == undefined || selection != self.state.track {
                self.requested_track = selection;

                if !self.crossfade || selection == undefined {
                    self.stop();
                } else {
                    self.controller.request_stop();
                    self.state = SceneAudioState.Off;
                    self.play(selection);
                }


            }
        } else {
            self.requested_track = selection;
        }
    }

    //
    function on_step() {
        switch self.state.id {
            case SceneAudioStateId.TransitionOff:
                var all_dead = true;
                for (var i = 0; i < array_length(self.controller.ids); i++) {
                    if TANGO.instance_alive(self.controller.ids[i]) {
                        all_dead = false;
                        break;
                    }
                }
                if all_dead {
                    self.state = SceneAudioState.Off;
                }
                break;
            case SceneAudioStateId.Off:
                if self.requested_track != undefined {
                    self.play(self.requested_track);
                    self.requested_track = undefined;
                }
                break;
        }
    }

    //
    //
    function play(track) {
        trace("Playing track: {}", track);
        self.state = SceneAudioState.On(track);
        self.controller = new SoundInstanceController(TANGO.play(track));
    }

    //
    //
    function stop(custom_release_length) {
        if self.state.id == SceneAudioStateId.On {
            self.state = SceneAudioState.TransitionOff;
            self.controller.request_stop(custom_release_length);
        }
    }

    //
    function is_on() {
        return self.state.id == SceneAudioStateId.On;
    }

    //
    function current_track() {
        if !self.is_on() {
            return undefined;
        }
        return self.state.track;
    }
}

function in_game_music_selector(location_id) {
    //
    if MIST.is_running() {
        var request = MIST.blackboard.get("requested_music");
        if request != undefined {
            return request;
        } else if MIST.active_cutscene.cut_off_music || MIST.blackboard.get("halt_music") {
            return undefined;
        }
    }

    //
    if MIST.halt_music_until_room_swap {
        return undefined;
    }

    //
    var location = LOCATIONS[location_id];
    if location.inhibit_music {
        return undefined;
    }

    //
    if ANCHOR.get_menu(Menu.Eod) != undefined {
        if Game.prevent_eod_music_stop && self.state.id == SceneAudioStateId.On {
            return self.state.track;
        } else {
            return undefined;
        }
    }

    //
    if is_dungeon_room(room()) && !is_special_dungeon_room(room()) {
        if DUNGEON_RUNNER.blocking_music {
            return undefined;
        } else {
            return DUNGEON.biomes[DUNGEON_BIOME].music;
        }
    }

    //
    if location.building == "inn" {
        static THRESHOLD = fiddle_get("misc/inn/busy_threshold");

        //
        var count = 0;
        for (var i = 0; i < NpcId.LEN; i++) {
            if NPC_WHITELIST[i] && NPCS[i].location_position.location_id == LocationId.Inn {
                count += 1;
            }
        }

        return count >= THRESHOLD
            ? "Music/Location Tracks/InnMoreBusy"
            : "Music/Location Tracks/InnLessBusy";
    }

    //
    for (var i = 0; i < FestivalId.LEN; i++) {
        var f = FESTIVALS[i];
        if f.is_today()
            && f.prototype.location_music[location_id] != undefined
            && f.prototype.implemented
        {
            var music = f.prototype.location_music[location_id];
            var music_for_time = CLOCK.is_day()
                ? music[$ "day"]
                : music[$ "night"];
            if music_for_time != undefined {
                return music_for_time;
            }
        }
    }

    //
    if location_id == LocationId.Town
        && CLOCK.is_day()
        && CALENDAR.day_type() == Day.Saturday
        && SATURDAY_MARKET.active
    {
        return "Music/Location Tracks/Festival";
    }

    //
    //
    var crystal_override = CURRENT_DYN_INDEX != undefined
        ? ARI.dyn_song_overrides[string(CURRENT_DYN_INDEX)]
        : ARI.song_overrides[location_id];
    var crystal_overrides_unique = crystal_override != undefined
        && is_home_location(location_id);

    //
    if location.music != undefined && !crystal_overrides_unique {
        var key = CLOCK.is_day() ? "day" : "night";
        var track = location.music[$ key];
        if track != undefined {
            return track;
        }
    }

    //
    var menu = ANCHOR.get_menu(Menu.Customization);
    if menu != undefined && menu.override_music {
        return "Music/Events/DragonCutscene";
    }

    //
    crystal_override = location.map_location == LocationId.Town
        ? ARI.song_overrides[LocationId.Town]
        : crystal_override;

    if crystal_override != undefined {
        return SONGS[crystal_override].track;
    }

    //
    if CLOCK.is_day() {
        var weather = WEATHER_PROTOTYPES[WEATHER.weather];
        var weather_track = weather.music[CALENDAR.season()];
        if weather_track != undefined && WEATHER.under_spell == false {
            return weather_track;
        }

        //
        if CALENDAR.year() >= 1 {
            switch CALENDAR.season() {
                case Season.Spring: return "Music/Playlists/Spring Year 2 Plus";
                case Season.Summer: return "Music/Playlists/Summer Year 2 Plus";
                case Season.Fall: return "Music/Playlists/Fall Year 2 Plus";
                case Season.Winter: return "Music/Playlists/Winter Year 2 Plus";
            }
        } else {
            switch CALENDAR.season() {
                case Season.Spring: return "Music/Playlists/Spring";
                case Season.Summer: return "Music/Playlists/Summer";
                case Season.Fall: return "Music/Playlists/Fall";
                case Season.Winter: return "Music/Playlists/Winter";
            }
        }
    }

    //
    return undefined;
}

function menu_music_selector() {
    var menu = ANCHOR.get_menu(Menu.Title);
    if menu == undefined || !menu.ready_for_music {
        return undefined;
    }
    if menu.menu_target == Menu.Credits {
        return "Music/Menu Tracks/Tsukihotaru";
    } else {
        return "Music/Menu Tracks/Main Theme";
    }
}

function in_game_ambience_selector(location_id) {
    //
    if MIST.is_running() {
        if MIST.blackboard.get("block_ambience") == true {
            return undefined;
        }
        var val = MIST.blackboard.try_take("ambience_override");
        if val != undefined {
            return val;
        }
    }

    //
    var location = LOCATIONS[location_id];
    if location.ambience != undefined {
        var key = CLOCK.is_day() ? "day" : "night";
        var track = location.ambience[$ key];
        if track != undefined {
            return track;
        }
    }

    //
    if LOCATIONS[location_id].outdoor {
        switch CALENDAR.season() {
            case Season.Spring: return CLOCK.is_night() ? "Ambience/SpringNightRandom" : "Ambience/SpringDayRandom";
            case Season.Summer: return CLOCK.is_night() ? "Ambience/SummerNightRandom" : "Ambience/SummerDayRandom";
            case Season.Fall: return CLOCK.is_night() ? "Ambience/FallNightRandom" : "Ambience/FallDayRandom";
            case Season.Winter: return CLOCK.is_night() ? "Ambience/WinterNightRandom" : "Ambience/WinterDayRandom";
            default: impossible("Unexpected Season: {Season}", CALENDAR.season());
        }
    } else {
        return undefined;
    }
}

function menu_ambience_selector() {
    return undefined;
}

enum SceneAudioStateId {
    Off,
    On,
    TransitionOff,
    LEN,
}

function SceneAudioStateFactory() constructor {
    static Off = {
        id: SceneAudioStateId.Off,
    };

    static On = function(track) {
        return {
            id: SceneAudioStateId.On,
            track,
        };
    };

    static TransitionOff = {
        id: SceneAudioStateId.TransitionOff,
    };

}
#macro SceneAudioState global.__scene_audio_state_factory
SceneAudioState = new SceneAudioStateFactory();
