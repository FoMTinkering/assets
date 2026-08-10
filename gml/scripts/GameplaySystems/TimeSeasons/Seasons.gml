enum Day {
    Monday,
    Tuesday,
    Wednesday,
    Thursday,
    Friday,
    Saturday,
    Sunday,
    LEN
}

enum Season {
    Spring,
    Summer,
    Fall,
    Winter,
    LEN
}

//
function go_back_a_season(season) {
    if season == Season.Spring {
        return Season.Winter;
    }
    return season - 1;
}
