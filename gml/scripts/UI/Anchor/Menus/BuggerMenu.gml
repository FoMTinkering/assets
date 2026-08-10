function BuggerMenu() : AnchorMenu(Menu.Bugger) constructor {
    command_history = List();
    cli_output = List();
    hovered_command_history_index = 0;

    function on_think() {
        if self.cli_input.get_takes_input() == false {
            return;
        }

        self.cli_suggestion.set_text(BUGGER.find_suggestion() ?? self.cli_input.get_text());

        if keyboard_check_pressed(vk_enter) {
            var command = self.cli_input.get_text();
            self.cli_input.set_text("");
            if command != "" {
                self.post(">> " + command);
                BUGGER.execute_command(command);
                self.command_history.push(command);
                self.hovered_command_history_index = command_history.count() - 1;
            }
        }

        if keyboard_check_pressed(vk_up) {
            if self.command_history.count() == 0 return;
            self.cli_input.set_text(self.command_history.get(self.hovered_command_history_index));
            if self.hovered_command_history_index > 0 self.hovered_command_history_index -= 1;
        }

        if keyboard_check_pressed(vk_down) {
            if self.hovered_command_history_index >= self.command_history.count() - 1 {
                self.cli_input.set_text("");
                return;
            }
            if self.hovered_command_history_index < self.command_history.count() {
                self.hovered_command_history_index += 1;
            }
            self.cli_input.set_text(command_history.get(hovered_command_history_index));
        }

        if (keyboard_check_pressed(vk_tab) || keyboard_check_pressed(vk_right)) {
            var suggestion = BUGGER.find_suggestion();
            if suggestion != undefined {
                self.cli_input.set_text(suggestion);
            }
        }

        if keyboard_check_control_modifier() {
            if keyboard_check_pressed(ord("C")) {
                clipboard_set_text(self.cli_input.get_text());
            } else if keyboard_check_pressed(ord("V")) {
                self.cli_input.set_text(self.cli_input.get_text() + clipboard_get_text());
            }
        }
    }

    window = ANCHOR.nine_slice(canvas)
        .set_sprite(spr_pixel)
        .set_align(Align.LeftIn, Align.BottomIn)
        .set_color(c_black)
        .set_max_alpha(0.75)
        .set_alpha(0.75)
        .set_size_to_screen()

    cli_log = ANCHOR.text(window)
        .set_xy(0, -24)
        .set_line_height(8)
        .set_align(Align.LeftIn, Align.BottomIn);

    cli_suggestion = ANCHOR.text(window)
        .set_align(Align.LeftIn, Align.BottomIn)
        .set_alpha(0.35);

    cli_input = ANCHOR.text(window)
        .set_size(window.get_width(), window.get_height())
        .set_align(Align.LeftIn, Align.BottomIn)

    function post(str) {
        self.cli_output.push(str);
        var text = "";
        var height = 0;
        for (var i = 0, c = self.cli_output.count(); i < c; i++) {
            //
            text += self.cli_output.get(i) + "\n";
            height += self.cli_log.line_height;
        }
        self.cli_log.set_text(text);

        if !steam_on_deck() {
            trace(str);
        }
    }

    function show() {
        canvas.enable();
    }

    function hide() {
        canvas.disable();
    }

    //
    function echo(str) {
        if str != undefined {
            var a = array_create(argument_count);
            for (var i = 0; i < argument_count; i++) {
                a[i] = argument[i];
            }
            str = a;
        }
        str = script_execute_alt(fmt, str);

        self.post(str);
    }
}
