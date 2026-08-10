#macro PAUSE_STATUS global.__pause_status
global.__pause_status = PauseStatus.EMPTY;

enum PauseStatus {
    EMPTY       = 0,
    CUTSCENE    = 1 << 0,
    WINDOW      = 1 << 1,
    MENU        = 1 << 2,
}

//
//
function game_paused() {
    return PAUSE_STATUS != PauseStatus.EMPTY;
}

//
function non_cutscene_pause() {
    return has_flag(PAUSE_STATUS, PauseStatus.WINDOW)
        || (has_flag(PAUSE_STATUS, PauseStatus.CUTSCENE) == false && has_flag(PAUSE_STATUS, PauseStatus.MENU));
}
