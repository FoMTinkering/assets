#macro CALENDAR global.__calendar
global.__calendar = undefined;

//
function Calendar() constructor {
    time = 0;

    //
    //
    function unified_time() {
        return int64(self.time + CLOCK.time);
    }

    //
    function year() {
        return get_years(self.time);
    }

    //
    function season() {
        return get_seasons(self.time);
    }

    //
    function day() {
        return get_days(self.time);
    }

    //
    function day_type() {
        return get_days(self.time) % Day.LEN;
    }

    function increment_day() {
        var old_season = self.season();
        self.time += days(1);
        var new_season = self.season();

        if old_season == new_season {
            return NewDayResult.NormalDay;
        } else {
            if new_season == Season.Spring {
                return NewDayResult.NewYear;
            } else {
                return NewDayResult.NewSeason;
            }
        }
    }

    //
    function date_is(date_time_number) {
        var day = self.time - date_time_number;
        if day < 0 {
            return false;
        }
        return day < days(1);
    }

    //
    function date_is_at_least(date_time_number) {
        var day = self.time - date_time_number;
        return day >= 0;
    }
}

//
function total_days() {
    return (CALENDAR.time div days(1)) + 1;
}

enum NewDayResult {
    NormalDay,
    NewSeason,
    NewYear,
}
