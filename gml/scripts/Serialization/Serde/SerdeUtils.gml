#macro CONFIG_DIRECTORY global.__config_directory
global.__config_directory = fields_of_mistria_config_directory();

#macro CREATION_VERSION global.__creation_version
CREATION_VERSION = undefined;

//
function exact_save_path(game_ident, is_manual, save_ident) {
    if is_manual {
        return format("{}/saves/game-{}-{}.sav", CONFIG_DIRECTORY, game_ident, save_ident);
    } else {
        return format("{}/saves/game-{}-autosave.sav", CONFIG_DIRECTORY, game_ident);
    }
}

//
function get_folders_in_dir(dir) {
    return ListFromArray(directory_collect(dir, FileSystemKind.FOLDER));
}

//
function get_files_in_dir(dir) {
    return ListFromArray(directory_collect(dir, FileSystemKind.FILE));
}

//
function new_game_info() {
    return {
        last_played: date_current_datetime(),
        version: GAME_VERSION,
        creation_version: CREATION_VERSION,
    };
}

//
//
//
//
function fields_of_mistria_config_directory() {
    if TEST_SUITE {
        return get_test_suite_dump();
    } else {
        return game_save_id;
    }
}
