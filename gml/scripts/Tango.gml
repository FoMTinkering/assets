#macro TANGO global.__tango
global.__tango = undefined;

#macro AUDIO_LISTENER_X global.__audio_listener_x
global.__audio_listener_x = -1000;

#macro AUDIO_LISTENER_Y global.__audio_listener_y
global.__audio_listener_y = -1000;

//
function Tango() constructor {
    //
    //
    function play(asset_name, xx, yy, user_pitch_change=1.0) {
        if !DEBUG_ASSERTIONS && !tango_name_exists(asset_name) {
            return undefined;
        }
        return tango_play(asset_name, xx, yy, user_pitch_change);
    }

    //
    //
    //
    function request_stop(instance_idx) {
        if !DEBUG_ASSERTIONS && instance_idx == undefined {
            return;
        }
        tango_request_stop(instance_idx);
    }

    //
    //
    //
    //
    //
    //
    function force_stop(instance_idx) {
        if !DEBUG_ASSERTIONS && instance_idx == undefined {
            return;
        }
        tango_force_stop(instance_idx);
    }

    //
    function update_instance_position(instance_idx, xx, yy) {
        if !DEBUG_ASSERTIONS && instance_idx == undefined {
            return;
        }
        tango_update_instance_position(instance_idx, xx, yy);
    }

    //
    function set_bus_volume(bus, volume) {
        //
        tango_set_bus_volume(bus, volume * volume * volume);
    }

    //
    function instance_alive(idx) {
        if idx == undefined {
            return false;
        }
        return tango_event_instance_status(idx) != TangoPlaybackState.Stopped;
    }

    //
    function name_exists(asset_name) {
        return tango_name_exists(asset_name);
    }

    //
    var global_volume = SETTINGS.get("global_volume");
    self.set_bus_volume(
        TangoBus.SoundEffects,
        global_volume * SETTINGS.get("sfx_volume"),
    );
    self.set_bus_volume(
        TangoBus.Music,
        global_volume * SETTINGS.get("msc_volume"),
    );
    self.set_bus_volume(
        TangoBus.Ambience,
        global_volume * SETTINGS.get("amb_volume"),
    );
}

//
function SoundInstanceController(ids) constructor {
    self.ids = is_array(ids) ? ids : [ids];

    function force_stop() {
        for (var i = 0, c = array_length(self.ids); i < c; i++) {
            var idx = self.ids[i];

            TANGO.force_stop(idx);
        }
    }

    function request_stop(custom_release_length) {
        for (var i = 0, c = array_length(self.ids); i < c; i++) {
            var idx = self.ids[i];

            TANGO.request_stop(idx, custom_release_length);
        }
    }

    function update_instance_position(xx, yy) {
        for (var i = 0, c = array_length(self.ids); i < c; i++) {
            var idx = self.ids[i];
            if idx != undefined && TANGO.instance_alive(idx) {
                TANGO.update_instance_position(idx, xx, yy);
            }
        }
    }
}

//
function set_listener_position(xx, yy) {
    AUDIO_LISTENER_X = xx;
    AUDIO_LISTENER_Y = yy;

    tango_listener_position(xx, yy);
}
