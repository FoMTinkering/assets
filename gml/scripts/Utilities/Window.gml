#macro FOCUS global.__focus
global.__focus = undefined;

enum NewWindowState {
    Focused,
    Unfocused,
}

//
function Focus() constructor {
    self.focus_cache = true;

    //
    //
    //
    function out_of_focus() {
        return !self.focus_cache;
    }

    //
    function check_for_update() {
        var old_focus = self.focus_cache;
        self.focus_cache = window_has_focus();

        if old_focus != self.focus_cache {
            if self.focus_cache {
                return NewWindowState.Focused;
            } else {
                return NewWindowState.Unfocused;
            }
        }

        return undefined;
    }

    function on_end_step() {
        if !ON_CONSOLE && !CI && SETTINGS.get("pause_on_unfocus") {
            switch FOCUS.check_for_update() {
                case NewWindowState.Focused:
                    trace("Window has regained focus. Unpausing game...");
                    if is_world_room(room()) {
                        PAUSE_STATUS = remove_flag(PAUSE_STATUS, PauseStatus.WINDOW);
                    }

                    if SETTINGS.get("pause_audio_on_unfocus") {
                        tango_pause_all(false);
                    }
                    break;

                case NewWindowState.Unfocused:
                    trace("Window has lost focus. Pausing game...");
                    if is_world_room(room()) {
                        PAUSE_STATUS = set_flag(PAUSE_STATUS, PauseStatus.WINDOW);
                    }

                    if SETTINGS.get("pause_audio_on_unfocus") {
                        tango_pause_all(true);
                    }
                    break;

                case undefined:
                    //
                    break;
            }
        }
    }
}
