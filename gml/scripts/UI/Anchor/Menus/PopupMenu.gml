function PopupMenu() : AnchorMenu(Menu.Popup) constructor {
    function on_close() {
        self.lock();
        if self.plays_sound {
            TANGO.play("SoundEffects/UI/UIPopDown");
        }
        if self.background != undefined {
            self.background.out();
        }
        if self.mutes_input {
            var popup_stack = ANCHOR.open_menus.clone().retain(function(m) {
                return m.type == Menu.Popup && m.mutes_input && (!m.close_requested || m == self);
            });

            var index = popup_stack.find_lazy(self);
            if index == undefined {
                var err_msg = "A popup was somehow not in the open menu list!";
                if DEBUG_ASSERTIONS {
                    crash(err_msg);
                } else {
                    warn(err_msg);
                    tattletale_report_error_without_panic(err_msg, "");
                }
            }

            if index != popup_stack.count() - 1 {
                var err_msg = "A popup not at the top of the stack was asked to close!";
                if DEBUG_ASSERTIONS {
                    crash(err_msg);
                } else {
                    warn(err_msg);
                    tattletale_report_error_without_panic(err_msg, "");
                }
            }

            popup_stack.pop();

            if index != undefined && popup_stack.is_empty() {
                for (var i = 0; i < ANCHOR.open_menus.count(); i++) {
                    var menu = ANCHOR.open_menus.get(i);
                    if menu != self {
                        menu.unlock();
                    }
                }
            } else {
                popup_stack.last().unlock();
            }
        }
        if self.pilot_cache != undefined && self.return_to_previous_pilot_flag {
            ANCHOR.set_active_pilot(self.pilot_cache);
        }
        if self.close_callback != undefined {
            self.close_callback();
        }
    }

    //
    function create_button(label, callback, args, tap_sound, input_id, auto_position=true, close_on_button_tap=true) {
        callback = callback == undefined ? function() {} : callback;
        args = args == undefined ? [] : args;

        //
        //
        static MIN_WIDTH = 60;
        static PADDING = 18;
        var width = max(MIN_WIDTH, ANCHOR.width_for_text_container(local_get(label), PADDING));
        var backplate = ANCHOR.nine_slice(self.backplate)
            .set_align(Align.Center, Align.BottomIn)
            .set_size(width, COMMON_BUTTON_HEIGHT)
            .set_y(-10)
            .set_sprites_from_key("spr_ui_button")
            .add_text_label(label, COMMON_LUT, CommonLutIndex.Dark)
            .add_hover_outline()
            .set_tap_callback(function(callback, args, close_on_button_tap) {
                if close_on_button_tap {
                    self.close();
                }
                function_execute_alt(callback, args);
            }, [callback, args, close_on_button_tap])
        if tap_sound != undefined {
            backplate.set_tap_sound(tap_sound);
        }
        if self.use_pilot_flag {
            backplate.add_to_pilot(self.pilot);
        }
        self.buttons.push(backplate);
        switch self.buttons.count() {
            case 1:
                input_id = input_id == undefined ? InputId.MenuBack : input_id;
                break;
            case 2:
                input_id = input_id == undefined ? InputId.Interact : input_id;
                if auto_position {
                    self.buttons.first().add_x(-40);
                    self.buttons.last().add_x(40);
                }
                break;
            default:
                if auto_position {
                    warn("Popup cannot automatically space/glyph buttons beyond two!");
                }
                break;
        }
        if input_id != undefined {
            backplate.add_glyph(input_id, self.glyph_control_mode);
        }
        return backplate;
    }

    //
    function add_title(local_key) {
        var width = self.backplate.get_width() - 30;

        self.header = ANCHOR.nine_slice(self.backplate)
            .set_sprite(spr_ui_popup_box_header)
            .set_width(width)
            .set_y(8)
            .set_align(Align.Center, Align.TopIn)

        self.title = ANCHOR.text(self.header)
            .set_align(Align.Center, Align.Middle)
            .set_lut(COMMON_LUT, CommonLutIndex.Header)
            .set_text_align(TextAlign.Center)
            .allow_line_breaks()
            .prevent_spillover()
            .set_key(local_key)

        self.header.set_height(self.title.measure().y + 4);

        self.refresh_backplate_height();
        return self;
    }

    //
    function title_overflow() {
        if self.title == undefined {
            return 0;
        }
        var lines = self.title.lines();
        return floor(self.title.measure().y * (lines - 1) / lines);
    }

    //
    function add_description(local_key) {
        var width = self.backplate.get_width() - 20;
        var minimum_height = self.backplate.get_height() / 2 - 5;

        self.body = ANCHOR.nine_slice(self.backplate)
            .set_sprite(spr_ui_popup_box_textbox)
            .set_width(width)
            .set_align(Align.Center, Align.Middle)
            .set_y(floor(self.title_overflow() / 2))
        self.body_text = ANCHOR.text(self.body)
            .set_align(Align.Center, Align.Middle)
            .set_lut(COMMON_LUT)
            .allow_line_breaks()
            .prevent_spillover()
            .set_required_padding(8)
            .set_key(local_key)
            .set_text_style("popup_description")

        self.body.set_height(max(self.body_text.measure().y + 12, minimum_height));

        self.refresh_backplate_height();
        return self;
    }

    //
    function refresh_backplate_height() {
        var height = 50;
        if self.header != undefined {
            height += self.header.get_height() + self.header.get_y();
        }
        if self.body != undefined {
            height += self.body.get_height();
        }
        self.backplate.set_height(height);
    }

    //
    function include_background(boo=true) {
        self.include_background_flag = boo;
        return self;
    }

    //
    function play_sound(boo=true) {
        self.plays_sound = boo;
        return self;
    }

    //
    function mute_input(boo=true) {
        self.mutes_input = boo;
        return self;
    }

    //
    function fade_speed(spd=FADE_SPEED) {
        self.fade_speed_amount = spd;
        return self;
    }

    //
    function use_pilot(boo=true) {
        self.use_pilot_flag = boo;
        return self;
    }

    //
    //
    function return_to_previous_pilot(boo=true) {
        self.return_to_previous_pilot_flag = boo;
        return self;
    }

    //
    function restrict_glyphs(control) {
        self.glyph_control_mode = control;
        return self;
    }

    //
    function initialize_background() {
        self.include_background();
        self.background = new BackgroundMenu(self, self.background_layer ?? AnchorLayer.ScreenFader, self.background_z);
        self.background.set_fade_speed(self.data.fade_out_frames);
        self.background.in();
        return self;
    }

    //
    function spawn() {
        if self.spawned {
            var err_msg = "Attempted to spawn a popup that was already spawned!";
            if DEBUG_ASSERTIONS {
                crash(err_msg);
            } else {
                warn(err_msg);
                tattletale_report_error_without_panic(err_msg, "");
                return;
            }
        }
        self.spawned = true;
        self.canvas.enable();
        if self.include_background_flag {
            self.initialize_background();
        }
        if self.plays_sound {
            TANGO.play("SoundEffects/UI/UIPopUp");
        }
        if self.mutes_input {
            for (var i = 0; i < ANCHOR.open_menus.count();  i++) {
                var menu = ANCHOR.open_menus.get(i);
                if menu != self {
                    menu.lock();
                }
            }
        }
        self.pilot_cache = ANCHOR.get_active_pilot();
        if self.use_pilot_flag {
            ANCHOR.set_active_pilot(self.pilot);
        }
        self.internal_chain = new_chain()
            .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, self.fade_speed_amount), function(_, ab) {
                self.canvas.set_alpha(ab);
            })
            .append(LinkId.Function, function() {
                self.internal_chain = undefined;
            })

        return self;
    }

    self.controller = instance_exists(Setup) ? Setup : Game;
    self.include_background_flag = true;
    self.background_layer = undefined;
    self.background_z = 0;
    self.background = undefined;
    self.requests = 0;
    self.plays_sound = true;
    self.mutes_input = true;
    self.fade_speed_amount = FADE_SPEED;
    self.return_to_previous_pilot_flag = true;
    self.use_pilot_flag = true;
    self.pilot_cache = undefined;
    self.manual_exit_listening = true;
    self.header = undefined;
    self.name = undefined;
    self.body = undefined;
    self.body_text = undefined;
    self.glyph_control_mode = AnchorControl.Point;
    self.buttons = List();
    self.spawned = false;
    self.close_callback = undefined;
    self.pilot = self.new_pilot()
        .allow_horizontal_wrapping();

    self.canvas
        .set_alpha(0)
        .set_think_callback(function() {
            if !self.close_requested && self.manual_exit_listening {
                self.run_exit_listening();
            }
            if self.mutes_input {
                for (var i = 0; i < InputId.LEN; i++) {
                    INPUT.override_input(i);
                }
            }
        })
        .disable();

    self.backplate = ANCHOR.nine_slice(self.canvas)
        .set_sprite(spr_ui_popup_box)
        .set_width(180)
        .set_align(Align.Center, Align.Middle)
}

//
//
function popup_creator(title, description) {
    var menu = ANCHOR.spawn_menu(Menu.Popup);
    if title != undefined {
        menu.add_title(title);
    }
    if description != undefined {
        menu.add_description(description);
    }
    return menu;
}
