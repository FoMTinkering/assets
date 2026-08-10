//
function RustSaver(save_path, save_on_vault) constructor {
    //
    if save_on_vault != undefined {
        self.vault_id = save_on_vault;
        self.is_patch = true;
    } else {
        self.vault_id = vault_create_empty_vault(save_path);
        self.is_patch = false;
    }
    self.save_path = save_path;
    self.farm_buffer_saved = false;

    //
    function save_file(file_name, value) {
        var json_value = json_stringify_handle_numbers(value);
        vault_overwrite_file(self.vault_id, file_name, json_value);
    }

    //
    function save_farm_buffer(buffer) {
        assert(!self.farm_buffer_saved, "you tried to save the farm buffer twice!");

        self.farm_buffer_saved = true;
        vault_overwrite_farm_buffer(self.vault_id, buffer);
        buffer_delete(buffer);
    }

    //
    function save_to_disk(info_blob) {
        static MAX_ATTEMPTS = 3;
        trace("Saving to `{}`", self.save_path);

        self.save_file("info", info_blob);

        var success = false;
        var attempts = 0;
        while success == false && attempts <= MAX_ATTEMPTS {
            try {
                vault_save_vault(self.vault_id);
                success = true;
            } catch(e) {
                error("failed save attempt: {}", e);
            }
            attempts += 1;
        }

        if success == false {
            return false;
        }

        if self.is_patch == false {
            vault_close_vault(self.vault_id);
        }

        return true;
    }
}
