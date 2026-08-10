//
#macro MINUTE_TO_SECOND int64(60)
#macro HOUR_TO_MINUTE int64(60)
#macro DAY_TO_HOUR int64(24)
#macro SEASON_TO_DAYS int64(28)
#macro YEAR_TO_SEASON int64(4)

#macro PENDING_DAY_TIME_SPEED_CHANGE global.__day_time_speed
PENDING_DAY_TIME_SPEED_CHANGE = undefined;

#macro MINUTES_PER_DAY global.__minutes_per_day
MINUTES_PER_DAY = 15;

function seconds(input) {
    return __seconds(int64(input));
}

function minutes(input) {
    return __minutes(int64(input));
}

function hours(input) {
    return __hours(int64(input));
}

function days(input) {
    return __days(int64(input));
}

function seasons(input) {
    return __seasons(int64(input));
}

function years(input) {
    return __years(int64(input));
}

function get_years(input) {
    //
    global.__scratch = input;

    //
    return global.__scratch div years(1);
}

function get_seasons(input) {
    var loss_amount = get_years(input) * years(1);
    global.__scratch -= loss_amount;

    return global.__scratch div seasons(1);
}

function get_days(input) {
    var loss_amount = get_seasons(input) * seasons(1);
    global.__scratch -= loss_amount;

    return global.__scratch div days(1);
}

function get_hours(input) {
    var loss_amount = get_days(input) * days(1);
    global.__scratch -= loss_amount;

    return global.__scratch div hours(1);
}

function get_minutes(input) {
    var loss_amount = get_hours(input) * hours(1);
    global.__scratch -= loss_amount;

    return global.__scratch div minutes(1);
}

function get_seconds(input) {
    var loss_amount = get_minutes(input) * minutes(1);
    global.__scratch -= loss_amount;

    return global.__scratch; //
}

function __seconds(input) {
    return input;
}

function __minutes(input) {
    return seconds(input * MINUTE_TO_SECOND);
}

function __hours(input) {
    return minutes(input * HOUR_TO_MINUTE);
}

function __days(input) {
    return hours(input * DAY_TO_HOUR);
}

function __seasons(input) {
    return days(input * SEASON_TO_DAYS);
}

function __years(input) {
    return seasons(input * YEAR_TO_SEASON);
}

function localize_date(date, include_years=true) {
    var delim = " ";
    switch local_language() {
        case "spa":
            delim = " of ";
            break;
        case "fra":
            delim = " - ";
            break;
    }
    var output = format(
        "{Local}{}{}",
        "misc_local/" + season_to_string(get_seasons(date)),
        delim,
        get_days(date) + 1,
    );

    if include_years {
        output += format(", {Local} {}", "misc_local/year", get_years(date) + 1);
    }

    return output;
}

function clock_time_to_string(_time) {
    var hours = get_hours(_time);
    var meridiem_signum = "am";

    //
    //
    //
    //
    if ((hours div 12) % 2 == 1) {
        meridiem_signum = "pm";
    }
    hours %= 12;

    if (hours == 0) {
        hours = 12;
    }

    var minutes = get_minutes(_time);

    if (hours < 10) {
        hours = fmt("{}", hours);
    }

    if (minutes < 10) {
        minutes = fmt("0{}", minutes);
    }

    return fmt("{}:{}{}", hours, minutes, meridiem_signum);
}

//
function day_delta(season, day, year) {
    var days = CALENDAR.day() + (CALENDAR.season() * 28) + (CALENDAR.year() * 112);
    var target_days = day + (season * 28) + (year * 112);

    return target_days - days;
}

global.__scratch = 0;

enum DayTimeSpeed {
    Standard,
    Longer,
    Longest,

    LEN
}

//
function day_time_speed_to_minutes_per_day(day_time_speed) {
    return fiddle_get(format("misc/{DayTimeSpeed}_minutes_per_day", day_time_speed));
}

//
//
function minutes_per_day_to_day_time_speed(minutes_per_day) {
    //
    var day_time_speed = undefined;
    for (var i = 0; i < DayTimeSpeed.LEN; i++) {
        var value = day_time_speed_to_minutes_per_day(i);
        if value == minutes_per_day {
            day_time_speed = i;
            break;
        }
    }

    return day_time_speed;
}
