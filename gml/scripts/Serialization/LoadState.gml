#macro CURRENT_SAVE_FOLDER global.__current_save_folder
global.__current_save_folder = undefined;

#macro LoadState global.__load_state_factory
global.__load_state_factory = new LoadStateFactory();

enum LoadStateId {
    New,
    Load,
}

function LoadStateFactory() constructor {
    //
    static New = function(player_data) {
        var game_ident = irandom(I32_MAX);

        return {
            type: LoadStateId.New,

            game_ident,
            player_data,
        }
    }

    //
    static Load = function(save_game_bundle) {
        return {
            type: LoadStateId.Load,
            game_ident: save_game_bundle.game_ident,

            //
            is_manual_save: save_game_bundle.is_manual,
            loader: save_game_bundle.loader,
        }
    }
}
