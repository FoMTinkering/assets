function TitleMenu() : AnchorMenu(Menu.Title) constructor {
    self.pilot = self.new_pilot();
    self.pilot.allow_vertical_wrapping();
    self.top_canvas = undefined;
    self.top_menu = undefined;
    self.transition_fade_frames = DEBUG_TOOLS ? 0 : 20;
    self.transition_hold_frames = DEBUG_TOOLS ? 0 : 5;
    self.continue_button = undefined;
    self.allow_skipping = true;
    self.skip_in_progress = false;
    self.ready_for_music = false;
    self.menu_target = Menu.Title;

    function on_think() {
        if self.top_menu != undefined && self.top_canvas.is_unlocked() {

            //
            if self.top_menu.type != Menu.Credits {
                GLYPH_GUIDE.set_input(InputId.MenuBack, "misc_local/back");
            }

            if INPUT.take_press(InputId.MenuBack) {
                self.transition_back();
            }
        }

        if self.allow_skipping
            && (
                INPUT.take_press(InputId.MenuBack)
                    || INPUT.take_press(InputId.Interact)
                    || INPUT.take_press(InputId.LeftMouse)
            )
        {
            if !SCREEN_FADER.is_in() {
                SCREEN_FADER.snap_in();
            }
            self.skip_in_progress = true;
            if self.internal_chain != undefined {
                if self.internal_chain.running {
                    while run_chain(self.chain) == false {}
                }
                self.internal_chain = undefined;
            }
            if self.chain != undefined && self.chain.running {
                while run_chain(self.chain) == false {}
            }
            self.skip_in_progress = false;
        }
    }

    function on_close() {
        if self.chain != undefined && self.chain.running {
            CHAINS.cancel_chain(self.chain);
        }
    }

    function refresh_expansion() {
        var expansion = 0;
        if steam_on_deck() {
            expansion = 0;
        } else if CAMERA.view_height >= 2160 {
            expansion = 1;
        } else if CAMERA.view_height >= 1440 {
            expansion = 2;
        }
        DISPLAY.set_expansion(expansion);
    }

    function start() {
        self.refresh_expansion();
        self.chain = new_chain();
        if !DEBUG_TOOLS && !FROM_GAME {
            self.setup_npc_studio_logo();
            self.setup_fmod_logo();
        }

        //
        self.chain.append(LinkId.Function, function() {
            self.chain = new_chain();

            self.chain.append(LinkId.Function, self.setup_background);

            self.chain.append(LinkId.Function, self.setup_main_screen);
        })
    }

    function setup_npc_studio_logo() {
        var background = ANCHOR.nine_slice(self.canvas)
            .set_sprite(spr_pixel)
            .set_size_to_screen()
            .set_color(c_black)

        var npc_studio_logo = ANCHOR.sprite(background)
            .set_align(Align.Center, Align.Middle)
            .set_sprite(spr_ui_title_screen_logo_animation)
            .set_y(-12)
            .set_alpha(0)


        self.chain
            .append(LinkId.Timer, 30)
            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 30), function(_, a, logo) {
                logo.set_alpha(a);
            }, [npc_studio_logo])
            .join(LinkId.Function, function(logo) {
                logo.set_speed(1);
                TANGO.play("Music/Jingles/NPCLogo");
            }, [npc_studio_logo])
            .append(LinkId.Await, function(logo) {
                if logo.at_animation_end() || self.skip_in_progress {
                    logo.set_speed(0);
                    return true;
                }
                return false;
            }, [npc_studio_logo])
            .append(LinkId.Timer, 90)
            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 60), function(_, a, logo) {
                logo.set_alpha(a);
            }, [npc_studio_logo])
            .append(LinkId.Timer, 10)
            .append(LinkId.Function, function(background) {
                ANCHOR.free_node(background);
            }, [background])
    }

    function setup_fmod_logo() {
        var background = ANCHOR.nine_slice(self.canvas)
            .set_sprite(spr_pixel)
            .set_size_to_screen()
            .set_color(c_black)
            .set_alpha(0)

        //
        //
        //
        //
        //
        //
        //
        //
        var pixel_destroying_resize = NORMAL_MINSPEC_HEIGHT / window_get_output_height();
        var ratio_of_ratios = pixel_destroying_resize / DISPLAY.inverse_asset_resize();
        pixel_destroying_resize *= ratio_of_ratios;

        var fmod_logo = ANCHOR.sprite(background)
            .set_align(Align.Center, Align.Middle)
            .set_sprite(spr_fmod_logo)
            .set_alpha(0)
            .set_scale(
                pixel_destroying_resize,
                pixel_destroying_resize,
            );

        self.chain
            .append(LinkId.Function, function(background) {
                background.set_alpha(1);
            }, [background])
            .append(LinkId.Timer, 30)
            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 60), function(_, a, logo) {
                logo.set_alpha(a);
            }, [fmod_logo])
            .append(LinkId.Timer, 90)
            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 60), function(_, a, logo) {
                logo.set_alpha(a);
            }, [fmod_logo])
            .append(LinkId.Timer, 30)
            .append(LinkId.Function, function(background) {
                ANCHOR.free_node(background);
            }, [background])
    }

    function setup_main_screen() {
        self.ready_for_music = true;
        MUSIC_PLAYER.refresh();

        self.sha_text = ANCHOR.text(self.canvas)
            .set_align(Align.LeftIn, Align.BottomIn)
            .set_x(2)
            .set_lut(COMMON_LUT, CommonLutIndex.WhiteOnGreen)
            .force_font(fnt_mistria_birdseed)
            .set_think_callback(function() {
                var sha = os_get_sha();
                var tampered = checksum_assets_are_tampered() || checksum_cli_is_utilized();
                var display = format("v{SemVer}", GAME_VERSION);
                if tampered {
                    display += " (modified)";
                }
                if sha != undefined
                    && (keyboard_check_control_modifier()
                        || (gamepad_is_connected(0) && gamepad_button_check(0, gp_shoulderlb) && gamepad_button_check(0, gp_shoulderrb))
                    )
                {
                    display += format(" ({})", sha);
                }
                self.sha_text.set_text(display);
            })

        if DEBUG_TOOLS {
            var t = ANCHOR.text(self.canvas)
                .set_text("tools")
                .set_align(Align.LeftIn, Align.BottomIn)
                .set_xy(2, -12)
                .set_lut(COMMON_LUT, CommonLutIndex.WhiteOnGreen)
                .force_font(fnt_mistria_birdseed)

            ANCHOR.sprite(t)
                .set_sprite(spr_ui_generic_checkbox_on)
                .set_align(Align.RightOut, Align.Middle)
                .set_x(2)
        }

        if DEBUG_ASSERTIONS {
            var t = ANCHOR.text(self.canvas)
                .set_text("asserts")
                .set_align(Align.LeftIn, Align.BottomIn)
                .set_xy(2, -24)
                .set_lut(COMMON_LUT, CommonLutIndex.WhiteOnGreen)
                .force_font(fnt_mistria_birdseed)

            ANCHOR.sprite(t)
                .set_sprite(spr_ui_generic_checkbox_on)
                .set_align(Align.RightOut, Align.Middle)
                .set_x(2)
        }

        ANCHOR.text(self.canvas)
            .set_text("© 2024-2026 NPC Studio")
            .set_align(Align.RightIn, Align.BottomIn)
            .set_x(-2)
            .set_lut(COMMON_LUT, CommonLutIndex.WhiteOnGreen)
            .force_font(fnt_mistria_birdseed)

        self.logo = ANCHOR.sprite(self.canvas)
            .set_align(Align.Center, Align.Middle)
            .set_y(-90)
            .set_sprite(spr_ui_title_screen_fom_logo)
            .set_alpha(0)

        if DEBUG_TOOLS {
            self.logo.set_alpha(1);

            self.all_unlocks = ANCHOR.nine_slice(self.canvas)
                .set_sprites_from_key("spr_ui_button")
                .set_size(22, 22)
                .set_align(Align.RightIn, Align.TopIn)
                .set_xy(-8, 8)

            self.all_unlocks.icon = ANCHOR.sprite(self.all_unlocks)
                .set_align(Align.Center, Align.Middle)
                .set_sprites_from_key(ALL_UNLOCKS
                    ? "spr_ui_journal_meta_icon_all_unlocks"
                    : "spr_ui_journal_meta_icon_no_unlocks"
                )
                .set_key_sprite_target(self.all_unlocks)

            self.all_unlocks.set_tap_callback(function() {
                ALL_UNLOCKS = !ALL_UNLOCKS;
                self.all_unlocks.icon.set_sprites_from_key(
                    ALL_UNLOCKS
                        ? "spr_ui_journal_meta_icon_all_unlocks"
                        : "spr_ui_journal_meta_icon_no_unlocks"
                );
            });

            self.story_enabled = ANCHOR.nine_slice(self.canvas)
                .set_sprites_from_key("spr_ui_button")
                .set_size(22, 22)
                .set_align(Align.RightIn, Align.TopIn)
                .set_xy(-8, 34)

            self.story_enabled.icon = ANCHOR.sprite(self.story_enabled)
                .set_align(Align.Center, Align.Middle)
                .set_sprites_from_key(STORY_ENABLED
                    ? "spr_ui_journal_meta_icon_story_enabled"
                    : "spr_ui_journal_meta_icon_story_disabled"
                )
                .set_key_sprite_target(story_enabled)

            self.story_enabled.set_tap_callback(function() {
                STORY_ENABLED = !STORY_ENABLED;
                self.story_enabled.icon.set_sprites_from_key(
                    STORY_ENABLED
                        ? "spr_ui_journal_meta_icon_story_enabled"
                        : "spr_ui_journal_meta_icon_story_disabled"
                );
            });
        } else {
            self.chain
                .append(LinkId.Await, function() {
                    return SCREEN_FADER.active_fade == undefined;
                })
                .append(LinkId.Timer, 30)
                .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 20), function(_, a) {
                    self.logo.set_alpha(a);
                })
        }

        var button = function(local_key, callback) {
            var button = ANCHOR.nine_slice(self.button_root)
                .set_size(90, 24)
                .set_align(Align.Center, Align.TopIn)
                .set_y(self.button_position)
                .set_alpha(0)
                .add_to_pilot(self.pilot, true)
                .set_sprites_from_key("spr_ui_main_menu_button")
                .set_locked_sprite(spr_ui_main_menu_button_main)
                .set_tap_callback(callback)
                .add_text_label(local_key, COMMON_LUT, CommonLutIndex.BlackOnBeige)
                .add_hover_outline(spr_ui_main_menu_button_hover_outline)
                .lock()

            button.text_label.add_y(-1);

            button.update_width = function(button) {
                static WIDTH_DATA = fiddle_get("ui/misc/local_adjustments/title_menu_button");
                button.set_width(WIDTH_DATA[$ local_language()] ?? WIDTH_DATA[$ "default"]);
                button.hover_outline.set_size(button.width + 4, button.height + 4)
            };

            button.set_think_callback(button.update_width, [button]);

            if !DEBUG_TOOLS {
                self.chain
                    .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 12), function(_, a, button) {
                        button.set_alpha(a);
                    }, [button])
                    .join(LinkId.Ease, new Ease(EaseId.BackOut, self.button_position - 30, self.button_position, 12), function(_, a, button) {
                        button.set_y(a);
                    }, [button])
                    .append(LinkId.Function, function(button) {
                        button.unlock();
                        if button.blackboard.get("hover_when_done") {
                            self.pilot.force_select(button);
                        }
                    }, [button])
            } else {
                button.unlock();
                button.set_alpha(1);
            }

            self.button_position += button.get_height() + 6;
            self.total_height = button.get_height() + button.get_y();

            return button;
        }

        var can_load = !array_is_empty(Setup.save_manager.get_saves_ordered());
        self.button_position = 0;
        self.total_height = 0;
        self.button_root = ANCHOR.positional(self.logo)
            .set_align(Align.Center, Align.BottomOut)
            .set_y(can_load ? 9 : 24)
            .set_width(90)

        var continue_button = undefined;
        if can_load {
            continue_button = button("misc_local/continue", function() {
                if LOAD_SEQUENCE.is_active() {
                    return;
                }
                var save_path = Setup.save_manager.get_saves_ordered()[0];
                self.enter_game(LoadState.Load(Setup.save_manager.manifest.get(save_path)));
            });

            //
            //
            //
            continue_button.set_think_callback(function(continue_button) {
                continue_button.set_unlocked(!Setup.load_menu_data.is_empty() && !TAXI.is_traveling());
                continue_button.update_width(continue_button);
            }, [continue_button], true)
        }
        var new_button = button("misc_local/new_game", function() {
            var ari_data = {
                name: local_get("misc_local/default_player_name"),
                farm_name: local_get("misc_local/default_farm_name"),
                pronouns: default_pronouns(),
                presets: List(create_default_player_animation_assets()),
                preset_index_selected: 0,
                cosmetic_unlocks: ALL_UNLOCKS
                    ? HashSetFromArray(PLAYER_ANIMATION_DATABASE.player_assets.keys())
                    : default_cosmetic_unlocks(),
                seen_cosmetics: default_cosmetic_unlocks(),
                birthday: DEFAULT_ARI_BIRTHDAY,
            };
            self.enter_game(LoadState.New(ari_data));
        });
        var first_button = continue_button ?? new_button;
        first_button.blackboard.set("hover_when_done", true);
        if can_load {
            button("misc_local/load_game", function() {
                self.transition_to(Menu.Load);
            });
        }
        button("misc_local/settings", function() {
            self.transition_to(Menu.Settings);
        });
        button("misc_local/credits", function() {
            self.ready_for_music = false;
            self.transition_to(Menu.Credits);
        });
        button("misc_local/exit", function() {
            var popup = popup_creator("misc_local/exit_game", "misc_local/exit_confirm");
            popup.create_button("misc_local/cancel");
            popup.create_button("misc_local/exit", function() {
                game_end();
            });
            popup.spawn();
        });

        self.button_root.set_height(self.total_height);

        ANCHOR.set_active_pilot(self.pilot);
        if !DEBUG_TOOLS {
            SCREEN_FADER.snap_out();
            SCREEN_FADER.fade_in(60);
        }

        self.chain.append(LinkId.Function, function() {
            self.allow_skipping = false;

            if DISPLAY_INVALID_SAVE_POPUP > 1 {
                var popup = popup_creator("misc_local/invalid_save", "misc_local/invalid_header_body");
                popup.create_button("misc_local/close");
                popup.spawn();
                DISPLAY_INVALID_SAVE_POPUP = 0;
            } else if DISPLAY_INVALID_SAVE_POPUP == 1 {
                create_invalid_save_popup();
                DISPLAY_INVALID_SAVE_POPUP = 0;
            }

            if DISPLAY_BETA_LANGUAGE_WARNING {
                DISPLAY_BETA_LANGUAGE_WARNING = false;
                await_popup(function() {
                    var popup = popup_creator("misc_local/beta_language_title", "misc_local/beta_language_description");
                    popup.create_button("misc_local/close");
                    popup.spawn();
                });
            }
        });
    }

    function setup_background() {
        CAMERA.follow_point_instant(room_width() / 2, room_height() / 2);
        strict_layer_set_visible("Assets", true);
        strict_layer_set_visible("Mountains", true);
        strict_layer_set_visible("Clouds", true);
        background_set_color(make_color_rgb(103, 180, 223), 1.0);
    }

    function transition_to(menu) {
        self.menu_target = menu;
        MUSIC_PLAYER.refresh();
        assert_eq(self.top_canvas, undefined);

        self.request_hide(self.transition_fade_frames);
        new_chain()
            .append(LinkId.Await, function() {
                return self.internal_chain == undefined;
            })
            .append(LinkId.Timer, self.transition_hold_frames)
            .append(LinkId.Function, function(menu) {
                self.top_canvas = ANCHOR.canvas(ANCHOR.screen_canvas)
                    .set_layer(AnchorLayer.Standard)
                    .set_align(Align.Center, Align.Middle)
                    .set_size_to_screen()
                    .set_alpha(0)

                switch menu {
                    case Menu.Settings:
                        var nodes = create_journal_nodes(self.top_canvas);
                        self.top_menu = ANCHOR.spawn_menu(Menu.Settings, nodes);
                        break;
                    case Menu.Load:
                        self.top_menu = ANCHOR.spawn_menu(Menu.Load, self.top_canvas);
                        break;
                    case Menu.Credits:
                        self.top_menu = ANCHOR.spawn_menu(Menu.Credits, self.top_canvas);
                        break;
                    default: impossible("Unexpected Menu: {Menu}", menu);
                }

                self.top_menu.canvas = self.top_canvas;
                self.top_menu.request_show(self.transition_fade_frames);
            }, [menu]);
    }

    function transition_back() {
        self.ready_for_music = true;
        self.menu_target = Menu.Title;
        MUSIC_PLAYER.refresh();
        self.top_menu.request_hide(self.transition_fade_frames);
        new_chain()
            .append(LinkId.Await, function() {
                return self.top_menu.internal_chain == undefined;
            })
            .append(LinkId.Timer, self.transition_hold_frames)
            .append(LinkId.Function, function() {
                self.top_menu.close();
                self.request_show(self.transition_fade_frames);
                ANCHOR.free_node(self.top_canvas);
                self.top_canvas = undefined;
                self.top_menu = undefined;
                ANCHOR.set_active_pilot(self.pilot);
                ANCHOR.hover_node(self.pilot.map[self.pilot.position.y][self.pilot.position.x]);
            })
    }

    //
    function enter_game(load_state) {
        if load_state.type == LoadStateId.Load {
            var ok = patch_save(load_state.loader);
            if !ok {
                create_invalid_save_popup();
                return;
            }
        }
        self.lock();
        if self.top_menu != undefined {
            self.top_menu.request_hide(self.transition_fade_frames);
        }
        if self.continue_button != undefined {
            ANCHOR.free_node(self.continue_button);
        }
        LOAD_SEQUENCE.start(
            "misc_local/loading",
            function(load_state) {
                self.close();
                Setup.enter_game(load_state);
                if self.top_menu != undefined {
                    self.top_menu.close();
                    ANCHOR.free_node(self.top_canvas);
                }
            },
            [load_state],
            DEBUG_TOOLS ? 1 : 60,
        );
    }
}
