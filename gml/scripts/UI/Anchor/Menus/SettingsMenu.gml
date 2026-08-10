function SettingsMenu(journal_nodes) : AnchorMenu(Menu.Settings) constructor {
    //
    function on_free() {
        if self.tooltip != undefined {
            self.tooltip.close();
        }
    }

    function create_category(name_key, open_callback, icon_sprite) {
        icon_sprite = icon_sprite == undefined ? string_to_asset(fmt("spr_ui_journal_settings_icon_{}", name_key)) : icon_sprite;
        var element = self.category_scroller.new_element(24)
            .set_tap_callback(function(name_key, open_callback) {
                self.active_page = name_key;
                if self.option_scroller != undefined {
                    self.option_scroller.free();
                }
                self.option_pilot.reset();
                self.option_scroller = create_scroller(self.journal.right_full_body);
                self.option_scroller.subscribe_to_pilot(self.option_pilot);
                open_callback();
                ANCHOR.set_active_pilot(self.option_pilot);
            }, [name_key, open_callback])
            .set_selected_getter(function(name_key) {
                return self.active_page == name_key;
            }, [name_key])
            .add_to_pilot(self.category_pilot, true)
            .add_text_label("misc_local/" + name_key)
        element.text_label
            .set_align(Align.LeftIn, Align.Middle)
            .set_x(23)

        ANCHOR.sprite(element)
            .set_sprite(icon_sprite)
            .set_align(Align.LeftIn, Align.Middle)
            .set_x(3)
        return element;
    }

    //
    //
    //
    //
    function checkbox(key, getter, tap) {
        if getter == undefined {
            getter = function(key) {
                return SETTINGS.get(key);
            }
        }
        if tap == undefined {
            tap = function(key) {
                SETTINGS.set(key, !SETTINGS.get(key));
            }
        }
        var nodes = {};

        nodes.element = self.element("misc_local/" + key)
            .set_tap_callback(function(tap, key) {
                tap(key);
                save_settings();
            }, [tap, key]);

        nodes.element.text_label
            .set_x(18)
            .set_max_width(141)

        nodes.checkbox = ANCHOR.sprite(nodes.element)
            .set_x(4)
            .set_align(Align.LeftIn, Align.Middle)
            .set_think_callback(function(nodes, getter, key) {
                nodes.checkbox.set_sprite(getter(key) ? spr_ui_generic_checkbox_on : spr_ui_generic_checkbox_off)
            }, [nodes, getter, key])

        return nodes;
    }

    //
    function slider(key, getter, setter, sticky_dead_zone) {
        var element = self.element("misc_local/" + key, 32, false);

        element.text_label
            .set_y(4)
            .set_align(Align.LeftIn, Align.TopIn)

        var range = ANCHOR.nine_slice(element)
            .set_align(Align.Center, Align.BottomIn)
            .set_y(-7)
            .set_size(element.get_width() - 8, 4)
            .set_sprite(spr_ui_journal_settings_slider_range)
            .set_hover_sound(undefined)

        if sticky_dead_zone != undefined {
            var line = ANCHOR.nine_slice(range)
                .set_sprite(spr_pixel_nine_slice)
                .set_color(make_color_rgb(145, 121, 138))
                .set_align(Align.Center, Align.Middle)
                .set_size(1, range.get_height() + 4)
        }

        var button = ANCHOR.nine_slice(range)
            .set_sprites_from_key("spr_ui_button")
            .set_size(16, 9)
            .set_align(Align.LeftIn, Align.Middle)
            .set_hover_sound(undefined)
            .add_to_pilot(self.option_pilot, true)
            .mouse_can_escape_tap(false)
            .add_hover_outline()
            .listen_for_hovers()
            .listen_for_taps()




        var max_position = range.get_width() - button.get_width();
        position_to_set = clamp((getter() * 100) * range.get_width(), 0, max_position);
        button.set_x(position_to_set);

        button.set_think_callback(function(button, range, getter, setter, sticky_dead_zone) {
            var max_position = range.get_width() - button.get_width();
            var move_inc = max_position / 10;

            //
            var request_save = false;
            var position_to_set = undefined;
            if ANCHOR.in_directional_control() && button.is_hovered() {
                var move_sign =
                    ANCHOR.press_and_hold_reader.pressed[InputId.Right]
                    - ANCHOR.press_and_hold_reader.pressed[InputId.Left];
                if move_sign != 0 {
                    position_to_set = button.get_x() + move_inc * move_sign;
                    request_save = true;
                }
            } else if button.in_drag() {
                button.blackboard.set("drag_token", true);
                position_to_set = button.get_position_with_drag_applied().x;
            } else {
                request_save = button.blackboard.try_take("drag_token") == true;
            }

            if position_to_set != undefined {
                //
                if position_to_set < move_inc / 2 {
                    position_to_set = 0;
                } else if position_to_set > max_position - (move_inc / 2) {
                    position_to_set = max_position;
                }
                position_to_set = clamp(position_to_set, 0, max_position);
                var ratio = position_to_set / max_position;

                if sticky_dead_zone != undefined && is_between(ratio, 0.5 - sticky_dead_zone, 0.5 + sticky_dead_zone) {
                    ratio = 0.5;
                    button.set_x(max_position / 2);
                } else {
                    button.set_x(position_to_set);
                }

                setter(ratio);
            } else {
                button.set_x(max_position * getter());
            }

            if request_save {
                save_settings();
            }
        }, [button, range, getter, setter, sticky_dead_zone])
    }

    //
    function button(title_key) {
        var tab = self.option_scroller.new_element(42);
        ANCHOR.text(tab)
            .set_xy(7, 2)
            .set_align(Align.LeftIn, Align.TopIn)
            .set_key("misc_local/" + title_key)
            .set_lut(COMMON_LUT)
        var button = ANCHOR.nine_slice(tab)
            .set_align(Align.LeftIn, Align.BottomIn)
            .set_xy(7, -5)
            .set_size(84, COMMON_BUTTON_HEIGHT)
            .set_sprites_from_key("spr_ui_button")
            .add_to_pilot(self.option_pilot, true)
            .add_hover_outline()

        return button;
    }

    //
    //
    function element(label_key, height, accept_inputs=true, font) {
        height = height == undefined ? 33 : height;

        var element = self.option_scroller.new_element(height)
            .add_text_label( //
                label_key,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                font,
            );

        if accept_inputs {
            element.listen_for_hovers();
            element.add_to_pilot(self.option_pilot, true);
        }

        element.text_label
            .set_align(Align.LeftIn, Align.Middle)
            .set_x(7)
        return element;
    }

    function format_resolution(vec) {
        return fmt("{int64}x{int64}", vec.x, vec.y)
    }

    function format_expansion(expansion) {
        var max_expansion = DISPLAY.max_expansion_looks_decent();
        return fmt("{int64}x", max_expansion - expansion + 1);
    }

    function display_mode_key() {
        if window_is_fullscreen() {
            return SETTINGS.get("borderless_fullscreen") ? "misc_local/borderless" : "misc_local/fullscreen";
        } else {
            return "misc_local/windowed";
        }
    }

    self.main_menu = is_menu_room(room());
    self.journal = journal_nodes ?? ANCHOR.get_menu(Menu.Journal);
    self.journal.left_page.set_sprite(spr_ui_journal_book_page_layout_settings_left);
    self.journal.right_page.set_sprite(spr_ui_journal_book_page_layout_settings_right);
    self.journal.book.set_think_callback(function() {
        var directional_in_page = self.active_page != undefined && ANCHOR.in_directional_control();
        self.category_scroller.canvas.set_alpha(!directional_in_page ? 1 : UI_FADE_ALPHA);
        if directional_in_page {
            //
            GLYPH_GUIDE.set_input(InputId.MenuBack, "misc_local/back");
            if INPUT.take_press(InputId.MenuBack) {
                self.option_scroller.free();
                self.option_pilot.reset();
                ANCHOR.set_active_pilot(self.category_pilot);
                self.active_page = undefined;
            }
        }

        if self.active_page == "controls" && ANCHOR.get_menu(Menu.Popup) == undefined {
            //
            GLYPH_GUIDE.set_input(InputId.ResetControls, "misc_local/hold_to_reset");
            if self.hold_reader.process() {
                SETTINGS.set("bindings", default_input_id_bindings());
                BINDINGS = saved_bindings_to_bindings(SETTINGS.get("bindings"));
                save_settings();
                TANGO.play("SoundEffects/UI/UIPlaceBuilding");
            }

            //
            //
            //
            //
            var node = self.option_pilot.get();
            if
                ON_GAMEPAD
                && node != undefined
                && node[$ "input_id"] != undefined
                && BINDINGS.can_remove_binding(node.input_id, node.slot)
            {
                GLYPH_GUIDE.set_input(InputId.SecondaryInteract, "misc_local/remove");
                if INPUT.take_press(InputId.SecondaryInteract) {
                    BINDINGS.set_binding(node.input_id, node.slot, undefined);
                    SETTINGS.set("bindings", BINDINGS.serialize());
                    save_settings();
                }
            }
        }
    });

    self.show_day_time_warning = true;
    self.show_oversleep_warning = true;

    self.active_page = undefined;
    self.category_pilot = self.new_pilot()
        .allow_vertical_wrapping()
    self.option_pilot = self.new_pilot()
        .allow_vertical_wrapping()

    self.hold_reader = new PressAndHoldReader(InputId.ResetControls, 60)
        .tap_on_press(false)
        .disable_input_repetition()

    self.left_title = title_for_journal("misc_local/settings", self.journal.left_header, spr_ui_journal_settings_header_icon);

    self.category_scroller = create_scroller(self.journal.left_body);
    self.option_scroller = undefined;
    self.tooltip = undefined;

    self.categories = {};

    self.rebinding_for_kbm = false;

    self.categories.gameplay = self.create_category("gameplay", function() {
        if ON_GAMEPAD || steam_on_deck() {
            self.glyph_kind = self.button("button_style")
                .add_text_label(format("misc_local/{}", SETTINGS.get("button_glyph_preference")), COMMON_LUT, CommonLutIndex.Dark)
                .set_tap_callback(function() {
                    create_options_popup(
                        "misc_local/choose_a_button_style",
                        List("xbox", "nintendo", "play_station"),
                        function(v) {
                            return local_get(format("misc_local/{}", v));
                        },
                        function(e) {
                            SETTINGS.insert("button_glyph_preference", e);
                            self.glyph_kind.text_label.set_key(format("misc_local/{}", e));
                        },
                        self.new_pilot(),
                    );
                });
        }

        if is_world_room(room())
            && ARI.spouse() == undefined && ARI.fiance() == undefined
            && ARI.tutorials_seen[Tutorial.Engagement]
        {
            self.checkbox(
                "disable_break_ups",
                function(key) {
                    return ARI.disable_break_ups;
                },
                function() {
                    if !ARI.disable_break_ups {
                        var popup = popup_creator();
                        popup.backplate.set_width(240);
                        popup.add_title("misc_local/disable_break_ups");
                        popup.add_description("misc_local/disable_break_ups_description");
                        popup.body_text.set_text_align(TextAlign.Center)
                        popup.create_button("misc_local/close");

                        popup.create_button("misc_local/confirm", function() {
                            ARI.disable_break_ups = true;
                            self.disable_break_up_letters_button.element.set_unlocked(false);
                        });

                        popup.spawn();
                    } else {
                        ARI.disable_break_ups = false;
                        self.disable_break_up_letters_button.element.set_unlocked(true);
                    }
                }
            );

            self.disable_break_up_letters_button = self.checkbox(
                "disable_break_up_letters",
                function(key) {
                    return ARI.disable_break_up_letters || ARI.disable_break_ups;
                },
                function() {
                    if !ARI.disable_break_up_letters {
                        var popup = popup_creator();
                        popup.backplate.set_width(240);
                        popup.add_title("misc_local/disable_break_up_letters");
                        popup.add_description("misc_local/disable_break_up_letters_description");
                        popup.body_text.set_text_align(TextAlign.Center)
                        popup.create_button("misc_local/close");

                        popup.create_button("misc_local/confirm", function() {
                            ARI.disable_break_up_letters = true;
                        });


                        popup.spawn();
                    } else {
                        ARI.disable_break_up_letters = false;
                    }
                }
            );

            self.disable_break_up_letters_button.element.set_unlocked(!ARI.disable_break_ups);
        }

        self.checkbox("rumble");
        self.checkbox("twenty_four_hour_clock");
        self.checkbox("show_hud_numbers", undefined, function() {
            SETTINGS.set("show_hud_numbers", !SETTINGS.get("show_hud_numbers"));
            var menu = ANCHOR.get_menu(Menu.Vitals);
            if menu != undefined {
                menu.set_number_visibility(SETTINGS.get("show_hud_numbers"));
            }
        });
        self.checkbox("pause_on_unfocus");

        if is_world_room(room()) && ARI.spells_learned[Spell.FireBreath] {
            self.checkbox("can_burn_fruit_trees");
        }

        self.checkbox("send_analytics");
        self.checkbox("asymptote",
            function() {
                return SETTINGS.get("asymptote");
            },
            function() {
                SETTINGS.set("asymptote", !SETTINGS.get("asymptote"));
                CAMERA.asymptote = !CAMERA.asymptote;
                save_settings();
            }
        );
    });

    self.categories.display = self.create_category("graphics", function() {
        var display = self.display_mode_key();
        self.display_mode_button = self.button("display_mode")
            .add_text_label(display, COMMON_LUT, CommonLutIndex.Dark)
            .set_tap_callback(function() {
                static LIST = ListFromArray([
                    "misc_local/windowed",
                    "misc_local/fullscreen",
                    "misc_local/borderless"
                ]);

                create_options_popup(
                    "misc_local/choose_display_mode",
                    LIST,
                    function(e) {
                        return local_get(e);
                    },
                    function(e) {
                        if e == "misc_local/windowed" {
                            DISPLAY.set_windowed(
                                SETTINGS.get("window_x"),
                                SETTINGS.get("window_y"),
                                SETTINGS.get("window_expansion"),
                            );
                            SETTINGS.set("open_fscreen", 0);
                            self.resolution_button.unlock();
                        } else {
                            var borderless = e == "misc_local/borderless";
                            SETTINGS.set("borderless_fullscreen", borderless);

                            DISPLAY.set_fullscreen(SETTINGS.get("fscreen_expansion"), borderless);
                            SETTINGS.set("open_fscreen", 1);

                            self.resolution_button.lock();
                        }

                        var output_size = window_get_output_dimensions();
                        self.resolution_button.text_label.set_text(self.format_resolution(Vec2(output_size[0], output_size[1])));
                        self.display_mode_button.text_label.set_key(self.display_mode_key());
                        self.scale_button.text_label.set_text(self.format_expansion(DISPLAY.expansion));
                    },
                    self.new_pilot(),
                );
            })

        var output_size = window_get_output_dimensions();
        var default_display = self.format_resolution(Vec2(output_size[0], output_size[1]));
        self.resolution_button = self.button("resolution")
            .add_text_label(ANCHOR.wrap_for_local(default_display), COMMON_LUT, CommonLutIndex.Dark)
            .set_unlocked(!window_is_fullscreen())
            .set_tap_callback(function() {
                //
                var list = DISPLAY.window_sizes();
                list.retain(function(e) {
                    return e.can_use;
                });
                list.map(function(e) {
                    return e.size;
                });

                create_options_popup(
                    "misc_local/choose_a_resolution",
                    list,
                    self.format_resolution,
                    function(e) {
                        SETTINGS.set("window_x", e.x);
                        SETTINGS.set("window_y", e.y);
                        SETTINGS.set("window_expansion", 0);
                        var menu = ANCHOR.get_menu(Menu.Title);
                        if menu != undefined {
                            menu.refresh_expansion();
                        }
                        DISPLAY.set_windowed(e.x, e.y, 0);
                        var display = self.format_resolution(e);
                        self.resolution_button.text_label.set_text(display);
                        var ex = SETTINGS.get(window_is_fullscreen() ? "fscreen_expansion" : "window_expansion");
                        self.scale_button.text_label.set_text(self.format_expansion(ex));
                    },
                    self.new_pilot(),
                );
            })

        var e = SETTINGS.get(window_is_fullscreen() ? "fscreen_expansion" : "window_expansion");
        self.scale_button = self.button("in_game_scale")
            .add_text_label(ANCHOR.wrap_for_local(self.format_expansion(e)), COMMON_LUT, CommonLutIndex.Dark)
            .set_tap_callback(function() {
                var list = List();
                var max_expansion = DISPLAY.max_expansion_looks_decent();
                for (var i = 0; i <= max_expansion; i++) {
                    list.push(i);
                }

                create_options_popup(
                    "misc_local/choose_a_scale",
                    list,
                    self.format_expansion,
                    function(e) {
                        if is_world_room(room()) {
                            DISPLAY.set_expansion(e);
                        }
                        SETTINGS.set(window_is_fullscreen() ? "fscreen_expansion" : "window_expansion", e);
                        if window_is_fullscreen() {
                            DISPLAY.set_fullscreen(DISPLAY.expansion);
                        } else {
                            var output_size = window_get_output_dimensions();
                            DISPLAY.set_windowed(output_size[0], output_size[1], DISPLAY.expansion);
                        }
                        self.scale_button.text_label.set_text(self.format_expansion(e));
                    },
                    self.new_pilot(),
                )
            });

        self.vsync_button = self.button("vsync")
            .add_text_label(format("misc_local/vsync_{Vsync}", display_get_vsync()), COMMON_LUT, CommonLutIndex.Dark)
            .set_tap_callback(function() {
                var popup = create_options_popup(
                    "misc_local/choose_a_vsync",
                    List(Vsync.Off, Vsync.On, Vsync.Adaptive),
                    function(v) {
                        return local_get(format("misc_local/vsync_{Vsync}", v));
                    },
                    function(vsync) {
                        display_set_vsync(vsync);
                        self.vsync_button.text_label.set_text(local_get(format("misc_local/vsync_{Vsync}", vsync)));
                        SETTINGS.set("vsync", vsync);
                        save_settings();
                    },
                    self.new_pilot(),
                    1,
                );
                popup.buttons.last().set_soft_locked(!display_can_adaptive_vsync());
            });

        self.slider(
            "brightness",
            function() {
                return SETTINGS.get("gamma_slider");
            },
            function(value) {
                SETTINGS.set("gamma_slider", value);
                gpu_set_gamma_scale(value);
            },
            0.09,
        );
        self.slider(
            "saturation",
            function() {
                return SETTINGS.get("saturation_slider");
            },
            function(value) {
                SETTINGS.set("saturation_slider", value);
                gpu_set_saturation_scale(value);
            },
            0.09,
        );

        self.checkbox(
            "frame_rate_cap",
            function(key) {
                return SETTINGS.get(key);
            },
            function() {
                var new_value = !SETTINGS.get("frame_rate_cap");
                SETTINGS.set("frame_rate_cap", new_value);
                display_set_frame_cap(new_value);
                save_settings();
            }
        );

        self.checkbox(
            "snap_frame_rate",
            function(key) {
                return SETTINGS.get(key);
            },
            function() {
                if SETTINGS.get("snap_frame_rate") {
                    //
                    var popup = popup_creator("misc_local/snap_frame_rate", "misc_local/snap_frame_rate_body");
                    popup.body_text.set_text_align(TextAlign.Center)
                    popup.create_button("misc_local/close");

                    popup.create_button("misc_local/disable", function() {
                        SETTINGS.set("snap_frame_rate", false);
                        snap_frame_rate(false);
                        save_settings();
                    });

                    popup.spawn();
                } else {
                    SETTINGS.set("snap_frame_rate", true);
                    snap_frame_rate(true);
                    save_settings();
                }
            }
        );

        self.checkbox(
            "native_cursor",
            function(key) {
                return SETTINGS.get(key);
            },
            function() {
                var new_value = !SETTINGS.get("native_cursor");
                CURSOR.render_strategy = new_value ? CursorRender.Software : CursorRender.OnGpu;
                //
                //
                window_hide_cursor();

                SETTINGS.set("native_cursor", new_value);
                save_settings();
            }
        );
    });

    self.categories.audio = self.create_category("audio", function() {
        self.slider(
            "global_volume",
            function() { return SETTINGS.get("global_volume"); },
            function(value) {
                SETTINGS.set("global_volume", value);

                TANGO.set_bus_volume(TangoBus.SoundEffects, SETTINGS.get("sfx_volume") * value);
                TANGO.set_bus_volume(TangoBus.Music, SETTINGS.get("msc_volume") * value);
                TANGO.set_bus_volume(TangoBus.Ambience, SETTINGS.get("amb_volume") * value);
            },
        );
        self.slider(
            "sfx_volume",
            function() { return SETTINGS.get("sfx_volume"); },
            function(value) {
                SETTINGS.set("sfx_volume", value);
                TANGO.set_bus_volume(TangoBus.SoundEffects, value * SETTINGS.get("global_volume"));
            },
        );
        self.slider(
            "music_volume",
            function() { return SETTINGS.get("msc_volume"); },
            function(value) {
                SETTINGS.set("msc_volume", value);
                TANGO.set_bus_volume(TangoBus.Music, value * SETTINGS.get("global_volume"));
            },
        );
        self.slider(
            "amb_volume",
            function() { return SETTINGS.get("amb_volume"); },
            function(value) {
                SETTINGS.set("amb_volume", value);
                TANGO.set_bus_volume(TangoBus.Ambience, value * SETTINGS.get("global_volume"));
            },
        );

        //
        self.checkbox("pause_audio_on_unfocus");

        //
        self.checkbox("sound_eating_drinking");
        self.checkbox("sound_vocal_text");
        self.checkbox("sound_footsteps");
        self.checkbox("sound_animals");
    });

    self.categories.accessibility = self.create_category("accessibility", function() {
        var current_day_time = PENDING_DAY_TIME_SPEED_CHANGE;
        if current_day_time == undefined {
            current_day_time = minutes_per_day_to_day_time_speed(MINUTES_PER_DAY);
        }

        self.day_time_element = self.button("day_time_speed")
            .add_text_label(format("misc_local/{DayTimeSpeed}", current_day_time), COMMON_LUT, CommonLutIndex.Dark)
            .set_tap_callback(function() {
                //
                if self.show_day_time_warning {
                    self.show_day_time_warning = false;
                    var popup = popup_creator("misc_local/day_time_speed", "misc_local/day_length_warning");
                    popup.create_button("misc_local/close");
                    popup.body_text.set_text_align(TextAlign.Center)
                    popup.spawn();
                }
                await_popup(day_time_speed_popup, [self.day_time_element.text_label]);
            })

        if !is_world_room(room()) {
            self.day_time_element.text_label.set_key("misc_local/in_game_only");
            self.day_time_element.set_soft_locked();
        }

        self.weather_strength = self.button("weather_strength")
            .add_text_label(format("misc_local/weather_{}", SETTINGS.get("weather_strength")), COMMON_LUT, CommonLutIndex.Dark)
            .set_tap_callback(function() {
                create_options_popup(
                    "misc_local/choose_a_weather_strength",
                    List("default", "low", "none"),
                    function(v) {
                        return local_get(format("misc_local/weather_{}", v));
                    },
                    function(e) {
                        SETTINGS.set("weather_strength", e);
                        self.weather_strength.text_label.set_key(format("misc_local/weather_{}", e));

                        if WEATHER != undefined && WEATHER.atmosphere != undefined {
                            WEATHER.set_atmosphere(WEATHER.atmosphere.id);
                        }

                        save_settings();
                    },
                    self.new_pilot(),
                );
            });
        self.checkbox("screenshake");
        self.checkbox("screen_flash");
        self.checkbox("menu_bounce");
        self.checkbox("scrolling_backgrounds");
        if steam_on_deck() {
            self.checkbox("touch_screen");
        }
        self.checkbox(
            "oversleep_penalty",
            function() {
                return SETTINGS.get("oversleep_penalty");
            },
            function() {
                //
                if self.show_oversleep_warning && SETTINGS.get("oversleep_penalty") {
                    self.show_oversleep_warning = false;
                    var popup = popup_creator("misc_local/oversleep_penalty", "misc_local/oversleep_penalty_warning");
                    popup.create_button("misc_local/close");
                    popup.body_text.set_text_align(TextAlign.Center)
                    popup.spawn();
                }

                SETTINGS.set("oversleep_penalty", !SETTINGS.get("oversleep_penalty"));
            },
        );

        if instance_exists(Game) {
            self.button("stuck")
                .add_text_label("misc_local/stuck_fix", COMMON_LUT, CommonLutIndex.Dark)
                .set_soft_locked(!has_unstuck_position())
                .set_tap_callback(function() {
                    if instance_exists(obj_ari) == false || MIST.is_running() || has_unstuck_position() == false {
                        return;
                    }

                    var popup = popup_creator("misc_local/move_title", "misc_local/move_description");
                    popup.create_button("misc_local/no");
                    popup.create_button("misc_local/yes", function() {
                        if is_home_location(CURRENT_LOCATION_ID) {
                            if CURRENT_LOCATION_ID == LocationId.PlayerHomeUpperCentral {
                                var safe_pos = player_home_safe_position(LocationId.PlayerHome);
                                goto_location_id(LocationId.PlayerHome)
                                    .set_exact_position(safe_pos.x, safe_pos.y);
                            } else {
                                var safe_pos = player_home_safe_position(CURRENT_LOCATION_ID);
                                obj_ari.x = safe_pos.x;
                                obj_ari.y = safe_pos.y;
                            }
                        } else if CURRENT_LOCATION_ID == LocationId.Dungeon {
                            var pos = TAXI.resolve_player_position();
                            obj_ari.x = pos.position.x;
                            obj_ari.y = pos.position.y;
                        } else {
                            var unstuck = LOCATIONS[CURRENT_LOCATION_ID].safe_position;
                            if unstuck != undefined {
                                obj_ari.x = unstuck[0];
                                obj_ari.y = unstuck[1];
                            }
                        }
                    });
                    popup.spawn();
                });
        }
    });

    self.categories.controls = self.create_category("controls", function() {
        static GLYPH_NODE = function(parent, xx, input_id, binding_slot) {
            var tab = ANCHOR.nine_slice(parent)
                .set_xy(xx, -5)
                .set_align(Align.LeftIn, Align.BottomIn)
                .set_sprites_from_key("spr_ui_button")
                .add_hover_outline()
                .set_size(40, 26)

            tab.set_tap_callback(function(input_id, slot) {
                self.option_scroller.lock();

                var popup = popup_creator(format("misc_local/input_{InputId}", input_id), "misc_local/press_any_input");
                popup.manual_exit_listening = false;
                popup.confirmation_keycode = undefined;

                if self.rebinding_for_kbm {
                    popup.create_button("misc_local/cancel").remove_glyph();
                    popup
                        .create_button("misc_local/remove", function(popup, input_id, slot) {
                            BINDINGS.set_binding(input_id, slot, undefined);
                            SETTINGS.set("bindings", BINDINGS.serialize());
                            popup.close();
                            self.option_scroller.unlock();
                            save_settings();
                        }, [popup, input_id, slot])
                        .set_unlocked(BINDINGS.can_remove_binding(input_id, slot))
                        .remove_glyph()
                }


                self.option_scroller.unlock();


                popup.backplate
                    .board_set("frame_skip", true)
                    .set_think_callback(function(popup, slot, input_id) {
                        static TAKE_PRESS = function(keycode, slot, input_id, popup) {
                            //
                            var blocker = undefined;
                            var taken_inputs = BINDINGS.inputs_using_keycode(keycode)
                                .retain(function(v, input_id) {
                                    return input_id_to_input_category(v.input_id) == input_id_to_input_category(input_id);
                                }, input_id);

                            for (var i = 0; i < taken_inputs.count(); i++) {
                                var taken_input = taken_inputs.get(i);
                                var override = taken_input.input_id == InputId.LeftMouse && keycode == mb_left; //
                                if !INPUT_UNLISTED[taken_input.input_id] && !override && !(taken_input.input_id == input_id && taken_input.slot == slot) {
                                    blocker = taken_input;
                                }
                            }

                            //
                            var swap_target = I32_MAX;
                            if blocker != undefined {
                                var our_old_binding = BINDINGS.get_binding(input_id, slot);

                                if blocker.input_id == input_id && our_old_binding == undefined {
                                    trace("Special case exit -- would leave our own primary slot empty!");
                                    popup.close();
                                    return; //
                                }

                                //
                                //
                                if
                                    INPUT_REQUIRED[blocker.input_id]
                                    && our_old_binding == undefined
                                    && (blocker.slot == 0 || blocker.slot == 2)
                                {
                                    popup.body_text.set_text(format(
                                        local_get("misc_local/input_in_use"),
                                        local_get(format("misc_local/input_{InputId}", blocker.input_id)),
                                    ));
                                    trace("Rejecting request -- operation would leave {InputId} empty!", blocker.input_id);
                                    return;
                                } else {
                                    swap_target = our_old_binding == undefined ? undefined : our_old_binding.keycode;
                                }
                            } else {
                                trace("No swap needed!");
                            }

                            //
                            if !self.rebinding_for_kbm && popup.confirmation_keycode != keycode {
                                trace("Now confirming...");
                                popup.body_text.set_key("misc_local/press_again_to_confirm");
                                popup.confirmation_keycode = keycode;
                                var display = get_display_for_keycode(keycode);
                                popup.glyph.set_sprite(display.big_sprite);
                                popup.glyph.set_index(display.index);
                                return;
                            }

                            //
                            if swap_target != I32_MAX {
                                trace("Swap {InputId} with {InputId}", blocker.input_id, input_id);
                                BINDINGS.set_binding(blocker.input_id, blocker.slot, swap_target);
                            }

                            BINDINGS.set_binding(input_id, slot, keycode);
                            SETTINGS.set("bindings", BINDINGS.serialize());
                            popup.close();
                            self.option_scroller.unlock();
                            save_settings();

                        }

                        if popup.close_requested {
                            return;
                        }

                        if popup.backplate.blackboard.try_take("frame_skip") {
                            return;
                        }

                        if self.rebinding_for_kbm {
                            for (var i = 0, c = array_length(KEYBOARD_INPUTS); i < c; i++) {
                                var keycode = KEYBOARD_INPUTS[i];

                                //
                                if keycode == vk_backspace {
                                    continue;
                                }

                                if keyboard_check_pressed(keycode) {
                                    TAKE_PRESS(keycode, slot, input_id, popup);
                                    break;
                                }
                            }
                            if !popup.buttons.any(function(v) { return v.is_pressed() } ) {
                                for (var i = 0, c = array_length(MOUSE_BUTTONS); i < c; i++) {
                                    var keycode = MOUSE_BUTTONS[i];

                                    if i == c - 2 {
                                        if mouse_wheel_up() != 0 {
                                            TAKE_PRESS(keycode, slot, input_id, popup);
                                            break;
                                        }
                                    } else if i == c - 1 {
                                        if mouse_wheel_down() != 0 {
                                            TAKE_PRESS(keycode, slot, input_id, popup);
                                            break;
                                        }
                                    } else if mouse_check_button_pressed(keycode) {
                                        TAKE_PRESS(keycode, slot, input_id, popup);
                                        break;
                                    }
                                }
                            }

                        } else {
                            //
                            //
                            for (var i = 0, c = array_length(GAMEPAD_BUTTONS); i < c; i++) {
                                var keycode = GAMEPAD_BUTTONS[i];
                                var taken = false;
                                for (var gp_index = 0; gp_index < GAMEPADS_COUNT; gp_index++) {
                                    if gamepad_is_connected(gp_index) == false {
                                        continue;
                                    }
                                    if gamepad_button_check_pressed(gp_index, keycode) {
                                        TAKE_PRESS(keycode, slot, input_id, popup);
                                        taken = true;
                                        break;
                                    }
                                }
                                if taken {
                                    break;
                                }
                            }
                            for (var i = 0, c = array_length(GAMEPAD_AXIS); i < c; i++) {
                                var axis = GAMEPAD_AXIS[i];
                                var taken = false;
                                for (var gp_index = 0; gp_index < GAMEPADS_COUNT; gp_index++) {
                                    if gamepad_is_connected(gp_index) == false {
                                        continue;
                                    }

                                    var sig = gamepad_axis_value(gp_index, abs(axis));
                                    var success = false;
                                    if sign(axis) {
                                        success = sig >= 0.75;
                                    } else {
                                        success = sig <= -0.75;
                                    }
                                    if success {
                                        TAKE_PRESS(axis, slot, input_id, popup);
                                        taken = true;
                                        break;
                                    }
                                }
                                if taken {
                                    break;
                                }
                            }
                        }
                    }, [popup, slot, input_id]);

                if !self.rebinding_for_kbm {
                    popup.glyph = ANCHOR.sprite(popup.backplate)
                        .set_align(Align.Center, Align.BottomIn)
                        .set_y(-12)

                    var binding = BINDINGS.get_binding(input_id, slot);
                    if binding == undefined {
                        popup.glyph.set_sprite(big_keyboard_keys_sprite());
                        popup.glyph.set_index(0);
                    } else {
                        var display = get_display_for_keycode(binding.keycode);
                        popup.glyph.set_sprite(display.big_sprite);
                        popup.glyph.set_index(display.index);
                    }
                }


                popup.spawn();

            }, [input_id, binding_slot]);

            var glyph = ANCHOR.sprite(tab)
                .set_align(Align.Center, Align.Middle);

            glyph.set_think_callback(function(glyph, input_id, slot) {
                var binding = BINDINGS.get_binding(input_id, slot);
                if binding == undefined {
                    glyph.set_sprite(big_keyboard_keys_sprite());
                    glyph.set_index(0);
                } else if self.rebinding_for_kbm || !input_forbidden_on_gamepad(input_id) {
                    var display = get_display_for_keycode(binding.keycode);
                    glyph.set_sprite(display.big_sprite);
                    glyph.set_index(display.index);
                }
            }, [glyph, input_id, binding_slot]);

            tab.input_id = input_id;
            tab.slot = binding_slot;

            return tab;
        }

        self.option_scroller.set_pilot_padding(19, 3);

        self.rebinding_for_kbm = ON_KBM;

        if ON_GAMEPAD || steam_on_deck() {
            //
            //
            var current_layout = "xbox";
            if SETTINGS.get("bindings")[$ input_id_to_string(InputId.Jump)][2] == "south_face" {
                current_layout = "nintendo";
            }

            self.button_layout = self.button("button_layout")
                .add_text_label(format("misc_local/{}", current_layout), COMMON_LUT, CommonLutIndex.Dark)
                .set_tap_callback(function() {
                    create_options_popup(
                        "misc_local/choose_a_button_layout",
                        List("xbox", "nintendo"),
                        function(v) {
                            return local_get(format("misc_local/{}", v));
                        },
                        function(e) {
                            switch e {
                                case "xbox":
                                    SETTINGS.set("bindings", default_input_id_bindings());
                                    BINDINGS = saved_bindings_to_bindings(SETTINGS.get("bindings"));
                                    break;
                                case "nintendo":
                                    SETTINGS.set("bindings", default_input_id_bindings("switch"));
                                    BINDINGS = saved_bindings_to_bindings(SETTINGS.get("bindings"));
                                    break;
                                default: impossible("unexpected new layout");
                            }
                            self.button_layout.text_label.set_key(format("misc_local/{}", e));
                            save_settings();
                        },
                        self.new_pilot(),
                    );
                });

                self.checkbox(
                    "one_stick_mode",
                    function(key) {
                        return SETTINGS.get(key);
                    },
                    function() {
                        var new_value = !SETTINGS.get("one_stick_mode");

                        if new_value {
                            var popup = popup_creator("misc_local/confirm", "misc_local/warning_one_stick_mode");
                            popup.create_button("misc_local/no");
                            popup.create_button("misc_local/yes", function() {
                                for (var i = 0; i < InputId.LEN; i++) {
                                    var binding_group = BINDINGS.bindings[i];

                                    if binding_group[2] != undefined
                                        && (abs(binding_group[2].keycode) == gp_axisrv || abs(binding_group[2].keycode) == gp_axisrh)
                                    {
                                        binding_group[2] = undefined;
                                    }
                                    if binding_group[3] != undefined
                                        && (abs(binding_group[3].keycode) == gp_axisrv || abs(binding_group[3].keycode) == gp_axisrh)
                                    {
                                        binding_group[3] = undefined;
                                    }
                                }
                                SETTINGS.set("one_stick_mode", true);
                                save_settings();
                            });
                            popup.spawn();
                        } else {
                            SETTINGS.set("one_stick_mode", new_value);
                            save_settings();
                        }
                    }
                );
        }

        for (var input = 0; input < InputId.LEN; input++) {
            if INPUT_UNLISTED[input] {
                continue;
            }
            if (ON_GAMEPAD || steam_on_deck()) && input_forbidden_on_gamepad(input) {
                continue;
            }

            var label = fmt("misc_local/input_{InputId}", input);

            var element = self.option_scroller.new_element(48)
                .add_text_label(label)
            element.text_label
                .set_align(Align.LeftIn, Align.TopIn)
                .set_xy(7, 2)
            var index_one = self.rebinding_for_kbm ? 0 : 2;
            var index_two = self.rebinding_for_kbm ? 1 : 3;
            GLYPH_NODE(element, 7, input, index_one)
                .add_to_pilot(self.option_pilot);
            GLYPH_NODE(element, 64, input, index_two)
                .add_to_pilot(self.option_pilot, true);
        }
    });

    static LANGUAGE_OPTION = function(key) {
        var font = TEXT_STYLES.standard[$ key];
        var element = self.element(
            ANCHOR.wrap_for_local(local_get_info(LocalInfoRequest.DisplayName, key)),
            undefined,
            true,
            font,
        );

        if key != "eng" {
            var beta_tag = ANCHOR.sprite(element)
                .set_sprite(spr_ui_load_save_icon_beta)
                .set_align(Align.RightIn, Align.Middle)
                .set_x(-4)
        }

        element.set_tap_callback(function(element, key) {
            if !element.is_selected() {
                local_set_language(key);
                SETTINGS.set("language", key);
			    ANCHOR.language_refresh();

                save_settings();
                if key != "eng" {
                    var popup = popup_creator();
                    popup.backplate.add_width(170);
                    popup.add_title("misc_local/beta_language_title");
                    popup.add_description("misc_local/beta_language_description");
                    popup.body_text.set_text_align(TextAlign.Center);
                    popup.create_button("misc_local/close");
                    popup.spawn();
                }
            }
        }, [element, key]);
        element.set_selected_getter(function(key) {
            return SETTINGS.get("language") == key;
        }, [key]);
        element.text_label.force_font(font);

        return element;
    }

    if is_menu_room(room()) || DEBUG_TOOLS {
        self.categories.language = self.create_category("language", function() {
            var languages = local_get_all_languages();
            for (var i = 0; i < array_length(languages); i++) {
                LANGUAGE_OPTION(languages[i]);
            }
        });
    }

    self.categories.exit_cat = self.create_category("exit", function() {
        if is_world_room(room()) {
            self.element("misc_local/return_to_main_menu")
                .set_tap_callback(function() {
                    SCREEN_FADER.fade_out(FADE_SPEED_TRANSITION, function() {
                        Game.exit_to_menu();
                    });
                });
        }
        self.element("misc_local/exit_to_desktop")
            .set_tap_callback(function() {
                game_end();
            });
    });

    ANCHOR.set_active_pilot(self.category_pilot);
}

function day_time_speed_popup(label_to_fix) {
    static SET = function(popup, v) {
        popup.button.set_align(popup.ticks[v].get_align().x, Align.Middle);
        popup.ticks[0].set_unlocked(v != 0);
        popup.ticks[1].set_unlocked(v != 1);
        popup.ticks[2].set_unlocked(v != 2);
        var s = day_time_speed_to_string(v);
        popup.label.set_key(format("misc_local/{}", s));
        PENDING_DAY_TIME_SPEED_CHANGE = v;
    }

    var popup = popup_creator("misc_local/day_time_speed");

    popup.range = ANCHOR.nine_slice(popup.backplate)
        .set_align(Align.Center, Align.Middle)
        .set_y(-8)
        .set_size(120, 4)
        .set_sprite(spr_ui_journal_settings_slider_range)
        .set_hover_sound(undefined)

    popup.ticks = [undefined, undefined, undefined];
    popup.ticks[0] = ANCHOR.sprite(popup.range)
        .set_align(Align.LeftIn, Align.Middle)
        .set_sprite(spr_ui_journal_settings_slider_notch_1)
        .set_tap_callback(SET, [popup, DayTimeSpeed.Standard]);

    popup.ticks[1] = ANCHOR.sprite(popup.range)
        .set_align(Align.Center, Align.Middle)
        .set_sprite(spr_ui_journal_settings_slider_notch_1)
        .set_tap_callback(SET, [popup, DayTimeSpeed.Longer]);

    popup.ticks[2] = ANCHOR.sprite(popup.range)
        .set_align(Align.RightIn, Align.Middle)
        .set_sprite(spr_ui_journal_settings_slider_notch_1)
        .set_tap_callback(SET, [popup, DayTimeSpeed.Longest]);

    popup.button = ANCHOR.nine_slice(popup.range)
        .set_sprites_from_key("spr_ui_button")
        .set_size(16, 9)
        .set_align(Align.LeftIn, Align.Middle)
        .set_hover_sound(undefined)
        .add_to_pilot(popup.pilot, true)
        .mouse_can_escape_tap(false)
        .add_hover_outline()
        .listen_for_hovers()
        .listen_for_taps()

    popup.button.set_think_callback(function(popup, SET) {
        static MOVE_INC = 10;

        //
        if ANCHOR.in_directional_control() && popup.button.is_hovered() {
            var move_sign =
                ANCHOR.press_and_hold_reader.pressed[InputId.Right]
                - ANCHOR.press_and_hold_reader.pressed[InputId.Left];
            if move_sign != 0 {
                var current_day_time = PENDING_DAY_TIME_SPEED_CHANGE;
                if current_day_time == undefined {
                    current_day_time = minutes_per_day_to_day_time_speed(MINUTES_PER_DAY);
                }

                SET(popup, wrap(current_day_time + move_sign, DayTimeSpeed.LEN));
            }
        } else if popup.button.in_drag() {
            popup.button.blackboard.set("drag_token", true);

            var xx = MOUSE_GUI_X - ANCHOR.get_screen_position(popup.range).x;
            var ratio = xx / popup.range.get_width();
            if ratio >= 0.66 {
                SET(popup, DayTimeSpeed.Longest);
            } else if ratio >= 0.33 {
                SET(popup, DayTimeSpeed.Longer);
            } else {
                SET(popup, DayTimeSpeed.Standard);
            }

        } else {

        }

    }, [popup, SET]);

    var rect = ANCHOR.nine_slice(popup.range)
        .set_align(Align.Center, Align.TopOut)
        .set_y(-8)
        .set_size(74, 16)
        .set_sprite(spr_ui_generic_rounded_text_box)

    popup.label = ANCHOR.text(rect)
        .set_align(Align.Center, Align.Middle)
        .set_lut(COMMON_LUT, CommonLutIndex.Blue);

    ANCHOR.text(popup.backplate)
        .set_align(Align.Center, Align.BottomIn)
        .set_key("misc_local/day_time_speed_adjustment_note")
        .set_y(-38)
        .set_lut(COMMON_LUT)
        .allow_line_breaks()
        .prevent_spillover()

    popup.backplate.set_height(150);

    popup.create_button("misc_local/confirm", function(label_to_fix) {
        var current_day_time = PENDING_DAY_TIME_SPEED_CHANGE;
        if current_day_time == undefined {
            current_day_time = minutes_per_day_to_day_time_speed(MINUTES_PER_DAY);
        }

        label_to_fix.set_key(format("misc_local/{DayTimeSpeed}", current_day_time));
    }, [label_to_fix]);

    var current_day_time = PENDING_DAY_TIME_SPEED_CHANGE;
    if current_day_time == undefined {
        current_day_time = minutes_per_day_to_day_time_speed(MINUTES_PER_DAY);
    }

    SET(popup, current_day_time);

    popup.spawn();

}
