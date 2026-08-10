#macro GAME_SECONDS_PER_FRAME (86400 / (MINUTES_PER_DAY * 60 * FPS))
#macro NIGHT_TIME hours(20)
#macro LIGHT_TURN_ON_TIME (NIGHT_TIME - minutes(30))

#macro CLOCK global.__clock
global.__clock = new Clock();

//
function Clock() constructor {
    time = hours(6);
    time_stopped = false;
    side_buffer = 0.0;

    //
    function jump(time) {
        var time_now = self.time;
        trace("jumping {time} to {time}", self.time, time);

        var succeeded = self.set_time(time);

        if succeeded {
            npcs_time_jump(time, time_now);

            if time_to_pet_management(time) != PET.management {
                if instance_exists(obj_pet) {
                    instance_destroy(obj_pet);
                }
                pet_update_at_time(time, true, false);

                //
                //
                if instance_exists(obj_pet) == false {
                    pet_on_room_start();
                }
            }
        }
    }

    //
    //
    function set_time(time) {
        if time < self.time {
            warn("Attempted to set the clock to {}, but it's already {}. We can't go backwards!", time, self.time);
            return false;
        }
        if time > hours(26) {
            warn("Attempted to jump beyond maximum time -- setting to 2am instead...");
            time = hours(26);
        }
        self.time = int64(time);

        return true;
    }


    function update() {
        //
        self.side_buffer += GAME_SECONDS_PER_FRAME * !game_paused() * !self.time_stopped;
        if self.side_buffer >= 1.0 {
            self.time += int64(self.side_buffer);
            self.side_buffer = frac(self.side_buffer);
        }

        //
        self.time = int64(time);
    }

    //
    function hour() {
        return get_hours(self.time);
    }

    //
    function minute() {
        return get_minutes(self.time);
    }

    //
    function is_day() {
        var hour = self.hour();
        return (hour > 5) && (hour < 20);
    }

    //
    function is_night() {
        return !self.is_day();
    }


    toString = function() {
        return clock_time_to_string(self.time);
    }
}
