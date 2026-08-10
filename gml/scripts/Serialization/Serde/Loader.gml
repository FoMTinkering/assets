//
function RustLoader(vault_id, save_path) constructor {
    assert_neq(vault_id, -1, "rust loader given with a bad vault");

    self.save_path = save_path;
    self.vault_id = vault_id;
    self.cannot_be_ran = false;

    //
    function load_file(file_name) {
        try {
            var text = vault_load_file(self.vault_id, file_name);
            if text == undefined {
                warn("failed to find file: {}", file_name);
                self.cannot_be_ran = true;
                return undefined;
            }
            return json_parse(text);
        } catch(_) {
            warn("'{}' could not be parsed!", file_name);
            self.cannot_be_ran = true;
            return undefined;
        }
    }

    //
    function has_file(file_name) {
        return vault_has_file(self.vault_id, file_name);
    }

    //
    function load_farm_buffer() {
        try {
            return vault_load_farm_buffer(self.vault_id);
        } catch(e) {
            warn("farm buffer could not be read: {}", e);
            self.cannot_be_ran = true;
            return undefined;
        }
    }

    function mark_invalid() {
        vault_mark_invalid(self.vault_id);
        vault_close_vault(self.vault_id);
    }

    function close_vault() {
        vault_close_vault(self.vault_id);
    }
}
