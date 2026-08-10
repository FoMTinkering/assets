function SaveManager() constructor {
    self.manifest = Map();
    self.bad_vaults = false;
    self.bad_saves = false;

    //
    function get_saves_ordered() {
        var save_bundles = self.manifest.keys();
        array_sort(save_bundles, function(lhs, rhs) {
            return sign(self.manifest.get(rhs).info.last_played - self.manifest.get(lhs).info.last_played);
        });
        return save_bundles;
    }

    //
    //
    if directory_exists(CONFIG_DIRECTORY + "/") == false {
        directory_create(CONFIG_DIRECTORY + "/");
        return;
    }

    var saves_dir = format("{}/saves", CONFIG_DIRECTORY);

    //
    if directory_exists(saves_dir) == false {
        directory_create(saves_dir);
        return;
    }

    //
    //
    var output = vault_assemble_vaults(saves_dir);
    if output != undefined {
        error("failed to assemble vaults: {}", output);

        if RUN_TATTLETALE {
            tattletale_report_error_without_panic("failed to assemble vaults fully", output);
        }

        self.bad_vaults = true;
    }

    //
    var file_names = get_files_in_dir(saves_dir);
    var save_bundles = List();

    //
    for (var i = 0, c = file_names.count(); i < c; i++) {
        var save_path = file_names.get(i);

        if string_ends_with(save_path, ".sav")
            && string_ends_with(save_path, ".old.sav") == false
            && string_ends_with(save_path, ".new.sav") == false
        {
            try {
                var vault_id = vault_open_vault(save_path);
                var fname = filename_change_ext(filename_name(save_path), "");
                var output = string_split(fname, "-");

                var save_ident;
                var is_manual;
                if output[2] == "autosave" {
                    save_ident = undefined;
                    is_manual = false;
                } else {
                    save_ident = string_digits(output[2]);
                    is_manual = true;
                }

                save_bundles.push({
                    save_ident,
                    game_ident: string_digits(output[1]),
                    is_manual,
                    vault_id,
                });
            } catch(_e) {
                if string_ends_with(save_path, "invalid.sav") == false {
                    file_rename(save_path, filename_change_ext(save_path, ".invalid.sav"));
                    self.bad_saves = true;
                }
            }
        }
    }

    //
    for (var i = 0, c = save_bundles.count(); i < c; i++) {
        var save_bundle = save_bundles.get(i);
        var save_path = exact_save_path(save_bundle.game_ident, save_bundle.is_manual, save_bundle.save_ident);

        var loader = new RustLoader(save_bundle.vault_id, save_path);
        var info_data = loader.load_file("info");

        if info_data == undefined {
            warn("save `{}` is missing an `info.json`! Ignoring...", save_path);
            self.bad_saves = true;
        } else {
            self.manifest.set(
                save_path,
                {
                    info: info_data,
                    game_ident: real(save_bundle.game_ident),
                    save_ident: save_bundle.save_ident,
                    is_manual: save_bundle.is_manual,
                    loader,
                }
            );
        }
    }
}
