#macro INPUT global.__input
INPUT = undefined;

//
function Input() constructor {
    //
    if ON_CONSOLE {
        self.active_input_type = InputType.Gamepad;
    } else {
        self.active_input_type = gamepad_connected_count() == 0 ? InputType.Kbm : InputType.Gamepad;
    }
    self.user_is_moving_mouse = false;
    self.mouse_last_frame = Vec2();

    self.input_overrides = array_create(InputId.LEN, false);

    self.raw_keyboard = array_create(array_length(KEYBOARD_INPUTS), DigitalStatus.Off);
    self.raw_mouse = array_create(array_length(MOUSE_BUTTONS), DigitalStatus.Off);
    self.raw_gp_buttons = array_create(array_length(GAMEPAD_BUTTONS), DigitalStatus.Off);
    self.gp_left_stick = Vec2();
    self.gp_right_stick = Vec2();
    self.gp_left_mag = 0;
    self.gp_right_mag = 0;

    //
    function begin_frame() {
        if DEBUG_TOOLS {
            var span = profile_span_start("Input::begin_frame");
        }
        //
        for (var i = 0; i < InputId.LEN; i++) {
            self.input_overrides[i] = false;
        }

        if !steam_on_deck() || SETTINGS.get("touch_screen") == true {
            //
            for (var i = 0, c = array_length(MOUSE_BUTTONS) - 2; i < c; i++) {
                var keycode = MOUSE_BUTTONS[i];

                var current_status = has_flag(self.raw_mouse[i], DigitalStatus.Muted)
                    ? DigitalStatus.Muted : DigitalStatus.Off;

                if mouse_check_button(keycode) {
                    self.active_input_type = InputType.Kbm;
                    current_status = set_flag(current_status, DigitalStatus.On);
                }

                if mouse_check_button_pressed(keycode) {
                    self.active_input_type = InputType.Kbm;
                    current_status = set_flag(current_status, DigitalStatus.Pressed);
                    current_status = remove_flag(current_status, DigitalStatus.Muted);
                }

                if mouse_check_button_released(keycode) {
                    self.active_input_type = InputType.Kbm;
                    current_status = set_flag(current_status, DigitalStatus.Released);
                }

                //
                self.raw_mouse[i] = current_status;
            }

            var mw_up = mouse_wheel_up() ? (DigitalStatus.On | DigitalStatus.Pressed) : DigitalStatus.Off;
            var mw_down = mouse_wheel_down() ? (DigitalStatus.On | DigitalStatus.Pressed) : DigitalStatus.Off;

            if mw_up != DigitalStatus.Off
                || mw_down != DigitalStatus.Off
            {
                self.active_input_type = InputType.Kbm;
            }
            self.raw_mouse[array_length(MOUSE_BUTTONS) - 2] = mw_up;
            self.raw_mouse[array_length(MOUSE_BUTTONS) - 1] = mw_down;

            self.user_is_moving_mouse = false;

            //
            if self.mouse_last_frame.x != MOUSE_GUI_X {
                self.user_is_moving_mouse = true;
                self.active_input_type = InputType.Kbm;
                self.mouse_last_frame.x = MOUSE_GUI_X;
            }
            if self.mouse_last_frame.y != MOUSE_GUI_Y {
                self.user_is_moving_mouse = true;
                self.active_input_type = InputType.Kbm;
                self.mouse_last_frame.y = MOUSE_GUI_Y;
            }
        }

        if !steam_on_deck() {
            //
            for (var i = 0, c = array_length(KEYBOARD_INPUTS); i < c; i++) {
                var keycode = KEYBOARD_INPUTS[i];

                var current_status = has_flag(self.raw_keyboard[i], DigitalStatus.Muted)
                    ? DigitalStatus.Muted : DigitalStatus.Off;

                if keyboard_check(keycode) {
                    self.active_input_type = InputType.Kbm;
                    current_status = set_flag(current_status, DigitalStatus.On);
                }

                if keyboard_check_pressed(keycode) {
                    self.active_input_type = InputType.Kbm;
                    current_status = set_flag(current_status, DigitalStatus.Pressed);
                    current_status = remove_flag(current_status, DigitalStatus.Muted);
                }

                if keyboard_check_released(keycode) {
                    self.active_input_type = InputType.Kbm;
                    current_status = set_flag(current_status, DigitalStatus.Released);
                }

                //
                self.raw_keyboard[i] = current_status;
            }
        }

        //
        var gps_last_frame = GAMEPADS_LAST_FRAME;
        var gps_this_frame = gamepads_connected();

        //
        if array_length(gps_this_frame) > array_length(gps_last_frame) {
            ANCHOR.switch_control(AnchorControl.Directional);
            ANCHOR.try_pilot_hover();

            if GAMEPAD_LOST_POPUP != undefined {
                GAMEPAD_LOST_POPUP.body_text.set_key("misc_local/gamepad_reconnected");
            }
        }

        //
        if array_is_empty(gps_this_frame)
            && array_is_empty(gps_last_frame) == false
            && INPUT.active_input_type == InputType.Gamepad
        {
            if GAMEPAD_LOST_POPUP != undefined {
                GAMEPAD_LOST_POPUP.body_text.set_key("misc_local/reconnect_gamepad");
            } else {
                GAMEPAD_LOST_POPUP = popup_creator("misc_local/gamepad_lost", "misc_local/reconnect_gamepad");
                GAMEPAD_LOST_POPUP.create_button("misc_local/close", function() {
                    GAMEPAD_LOST_POPUP = undefined;
                });
                GAMEPAD_LOST_POPUP.canvas.set_layer_recursive(AnchorLayer.Debug);

                GAMEPAD_LOST_POPUP.spawn();
            }
        }
        GAMEPADS_LAST_FRAME = gps_this_frame;

        self.gp_left_stick.x = 0.0;
        self.gp_left_stick.y = 0.0;
        self.gp_right_stick.x = 0.0;
        self.gp_right_stick.y = 0.0;
        self.gp_left_mag = 0;
        self.gp_right_mag = 0;

        //
        for (var i = 0, c = array_length(GAMEPAD_BUTTONS); i < c; i++) {
            var keycode = GAMEPAD_BUTTONS[i];

            //
            //
            //
            var was_off = self.raw_gp_buttons[i] == DigitalStatus.Off;

            var current_status = has_flag(self.raw_gp_buttons[i], DigitalStatus.Muted)
                ? DigitalStatus.Muted : DigitalStatus.Off;

            for (var gp_index = 0; gp_index < GAMEPADS_COUNT; gp_index++) {
                if gamepad_is_connected(gp_index) == false {
                    continue;
                }

                if gamepad_button_check(gp_index, keycode) {
                    self.active_input_type = InputType.Gamepad;
                    current_status = set_flag(current_status, DigitalStatus.On);
                }

                if was_off && gamepad_button_check_pressed(gp_index, keycode) {
                    self.user_is_moving_mouse = false;
                    self.active_input_type = InputType.Gamepad;
                    current_status = set_flag(current_status, DigitalStatus.Pressed);
                    current_status = remove_flag(current_status, DigitalStatus.Muted);
                }

                if gamepad_button_check_released(gp_index, keycode) {
                    self.user_is_moving_mouse = false;
                    self.active_input_type = InputType.Gamepad;
                    current_status = set_flag(current_status, DigitalStatus.Released);
                }
            }

            //
            //
            //
            if current_status == DigitalStatus.Muted {
                current_status = DigitalStatus.Off;
            }

            //
            self.raw_gp_buttons[i] = current_status;
        }

        for (var gp_index = 0; gp_index < GAMEPADS_COUNT; gp_index++) {
            if gamepad_is_connected(gp_index) == false {
                continue;
            }
            //
            var horizontal_left = gamepad_axis_value(gp_index, gp_axislh);
            var vertical_left = gamepad_axis_value(gp_index, gp_axislv);

            if (horizontal_left * horizontal_left + vertical_left * vertical_left) >= GP_DEAD_ZONE {
                self.gp_left_stick.x = horizontal_left;
                self.gp_left_stick.y = vertical_left;
                self.gp_left_mag = self.gp_left_stick.sqrd_magnitude();
            }

            var horizontal_right = gamepad_axis_value(gp_index, gp_axisrh);
            var vertical_right = gamepad_axis_value(gp_index, gp_axisrv);

            if (horizontal_right * horizontal_right + vertical_right * vertical_right) >= GP_DEAD_ZONE {
                self.gp_right_stick.x = horizontal_right;
                self.gp_right_stick.y = vertical_right;
                self.gp_right_mag = self.gp_right_stick.sqrd_magnitude();
            }
        }

        //
        if SETTINGS.get("one_stick_mode") && self.gp_right_mag >= self.gp_left_mag {
            self.gp_left_stick.x = self.gp_right_stick.x;
            self.gp_left_stick.y = self.gp_right_stick.y;
            self.gp_left_mag = self.gp_right_mag;
        }

        if self.gp_left_mag >= GP_DEAD_ZONE
            || self.gp_right_mag >= GP_DEAD_ZONE
        {
            self.active_input_type = InputType.Gamepad;
            self.user_is_moving_mouse = false;
        }

        if DEBUG_TOOLS {
            profile_span_stop(span);
        }
    }

    //
    function check(input_id) {
        return has_flag(self.raw_status(input_id), DigitalStatus.On);
    }

    //
    function pressed(input_id) {
        return has_flag(self.raw_status(input_id), DigitalStatus.Pressed);
    }

    //
    function released(input_id) {
        return has_flag(self.raw_status(input_id), DigitalStatus.Released);
    }

    //
    function off(input_id) {
        return self.raw_status(input_id) == DigitalStatus.Off;
    }

    //
    //
    function take_press(input_id) {
        return has_flag(self.raw_status(input_id, true), DigitalStatus.Pressed);
    }

    function raw_status(input_id, take=false) {
        //
        if self.input_overrides[input_id] {
            return DigitalStatus.Off;
        }

        //
        var bindings_group = BINDINGS.bindings[input_id];
        var output = DigitalStatus.Off;

        //
        for (var i = 0, c = array_length(bindings_group); i < c; i++) {
            var binding = bindings_group[i];
            if binding == undefined {
                continue;
            }

            switch binding.type {
                case BindingType.Keyboard:
                    output = self.process_binary(output, binding.keycode, KEYBOARD_INPUTS, self.raw_keyboard, take);
                    break;
                case BindingType.Mouse:
                    output = self.process_binary(output, binding.keycode, MOUSE_BUTTONS, self.raw_mouse, take);
                    break;
                case BindingType.GamepadButton:
                    output = self.process_binary(output, binding.keycode, GAMEPAD_BUTTONS, self.raw_gp_buttons, take);
                    break;
                case BindingType.GamepadAxis:
                    switch binding.keycode {
                        case gp_axislh:
                        case -gp_axislh:
                            if self.gp_left_mag >= GP_DEAD_ZONE_UI
                                && self.gp_left_stick.x * sign(binding.keycode) >= GP_PER_AXIS_CHECK
                            {
                                output = set_flag(output, DigitalStatus.On);
                            }
                            break;
                        case gp_axislv:
                        case -gp_axislv:
                            if self.gp_left_mag >= GP_DEAD_ZONE_UI
                                && self.gp_left_stick.y * sign(binding.keycode) >= GP_PER_AXIS_CHECK
                            {
                                output = set_flag(output, DigitalStatus.On);
                            }
                            break;
                        case gp_axisrh:
                        case -gp_axisrh:
                            if self.gp_right_mag >= GP_DEAD_ZONE_UI
                                && self.gp_right_stick.x * sign(binding.keycode) >= GP_PER_AXIS_CHECK
                            {
                                output = set_flag(output, DigitalStatus.On);
                            }
                            break;
                        case gp_axisrv:
                        case -gp_axisrv:
                            if self.gp_right_mag >= GP_DEAD_ZONE_UI
                                && self.gp_right_stick.y * sign(binding.keycode) >= GP_PER_AXIS_CHECK
                            {
                                output = set_flag(output, DigitalStatus.On);
                            }
                            break;
                    }
                    break;
            }
        }

        return output;
    }

    //
    //
    function check_value(input_id) {
        //
        if self.input_overrides[input_id] {
            return 0;
        }

        //
        var bindings_group = BINDINGS.bindings[input_id];
        var output = 0;

        //
        for (var i = 0, c = array_length(bindings_group); i < c; i++) {
            var binding = bindings_group[i];
            if binding == undefined {
                continue;
            }

            switch binding.type {
                case BindingType.Keyboard:
                    if self.process_binary_value(binding.keycode, KEYBOARD_INPUTS, self.raw_keyboard) == 1 {
                        output = 1;
                    }
                    break;

                case BindingType.Mouse:
                    if self.process_binary_value(binding.keycode, MOUSE_BUTTONS, self.raw_mouse) == 1 {
                        output = 1;
                    }
                    break;
                case BindingType.GamepadButton:
                    if self.process_binary_value(binding.keycode, GAMEPAD_BUTTONS, self.raw_gp_buttons) == 1 {
                        output = 1;
                    }
                    break;

                case BindingType.GamepadAxis:
                    switch binding.keycode {
                        case gp_axislh:
                        case -gp_axislh:
                            output = max(self.gp_left_stick.x * sign(binding.keycode), output);
                            break;
                        case gp_axislv:
                        case -gp_axislv:
                            output = max(self.gp_left_stick.y * sign(binding.keycode), output);
                            break;
                        case gp_axisrh:
                        case -gp_axisrh:
                            output = max(self.gp_right_stick.x * sign(binding.keycode), output);
                            break;
                        case gp_axisrv:
                        case -gp_axisrv:
                            output = max(self.gp_right_stick.y * sign(binding.keycode), output);
                            break;
                    }
                    break;
            }
        }

        return output;
    }


    //
    function override_input(input_id) {
        self.input_overrides[input_id] = true;
    }

    //
    function process_binary(output, keycode, button_array, raw_array, take) {
        var idx = array_index(button_array, keycode);
        var raw_io_status = raw_array[idx];

        if has_flag(raw_io_status, DigitalStatus.Released) {
            output = set_flag(output, DigitalStatus.Released);
        }

        if has_flag(raw_io_status, DigitalStatus.Pressed)
            && has_flag(raw_io_status, DigitalStatus.Muted) == false
        {
            output = set_flag(output, DigitalStatus.Pressed)

            //
            if take {
                raw_array[idx] = set_flag(raw_io_status, DigitalStatus.Muted);
            }
        }

        //
        if has_flag(raw_io_status, DigitalStatus.On)
            && has_flag(raw_io_status, DigitalStatus.Muted) == false
        {
            output = set_flag(output, DigitalStatus.On);
        }

        return output;
    }


    //
    function process_binary_value(keycode, button_array, raw_array) {
        var idx = array_index(button_array, keycode);
        var raw_io_status = raw_array[idx];

        if has_flag(raw_io_status, DigitalStatus.On)
            && has_flag(raw_io_status, DigitalStatus.Muted) == false
        {
            return 1;
        }

        return 0;
    }
}

#macro BINDINGS global.__bindings
BINDINGS = undefined;

function Bindings() constructor {
    self.bindings = array_create(InputId.LEN, undefined);
    apply_func(self.bindings, function() {
        return [undefined, undefined, undefined, undefined];
    });

    //
    function set_binding(input_id, slot, keycode) {
        var bindings = self.bindings[input_id];
        var is_primary = matches(slot, 0, 2);
        if keycode == undefined {
            if is_primary && bindings[slot + 1] != undefined {
                trace("Replacing {InputId}'s primary slot with secondary slot.", input_id)
                keycode = bindings[slot + 1].keycode;
                bindings[slot + 1] = undefined;
            } else {
                trace("Removing {InputId}:{}.", input_id, slot)
                bindings[slot] = undefined;
                return;
            }
        }
        //
        //
        //
        //
        trace("Set {InputId}:{} to {}.", input_id, slot, opt_and_then(keycode, keycode_to_string));
        assert(keycode != undefined || self.can_remove_binding(input_id, slot), "Attempted to bind an illegal slot!");
        bindings[slot] = {
            keycode: keycode,
            type: keycode_to_binding_type(keycode),
        };
    }

    //
    function can_remove_binding(input_id, slot) {
        //
        if INPUT_UNLISTED[input_id] {
            return false;
        }

        //
        //
        var primary_slot = slot <= 1 ? 0 : 2;
        var is_primary = primary_slot == slot;
        var primary_filled = self.get_binding(input_id, primary_slot) != undefined;
        var secondary_filled = self.get_binding(input_id, primary_slot + 1) != undefined;
        var would_be_empty = is_primary ? !secondary_filled : !primary_filled;
        return !would_be_empty || !INPUT_REQUIRED[input_id]
    }

    //
    function get_binding(input_id, slot) {
        return self.bindings[input_id][slot];
    }

    //
    //
    function get_primary_binding(input_id) {
        return self.get_binding(input_id, ON_GAMEPAD ? 2 : 0);
    }

    //
    function inputs_using_keycode(keycode) {
        var output = List();
        for (var i = 0; i < InputId.LEN; i++) {
            for (var j = 0; j < array_length(self.bindings[i]); j++) {
                var binding = self.bindings[i][j];
                if binding != undefined && binding.keycode == keycode {
                    output.push({
                        input_id: i,
                        slot: j,
                    });
                }
            }
        }
        return output;
    }

    //
    function serialize() {
        var bindings = {};
        for (var i = 0; i < InputId.LEN; i++) {
            var a = [];
            bindings[$ input_id_to_string(i)] = a;
            for (var j = 0; j < array_length(self.bindings[i]); j++) {
                var binding = self.bindings[i][j];
                array_push(a, opt_and_then(binding, function(v) {
                    return keycode_to_string(v.keycode);
                }));
            }
        }
        return bindings;
    }
}
