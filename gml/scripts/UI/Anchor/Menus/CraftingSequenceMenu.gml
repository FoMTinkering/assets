function CraftingSequenceMenu(crafting_menu, recipe, item_lists, target_time, eases, skill_id) : AnchorMenu(Menu.CraftingSequence) constructor {
    function end_sequence() {
        if self.time_chain != undefined {
            CHAINS.cancel_chain(self.time_chain);
        }
        self.time_chain = new_chain()
            .join(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, FADE_SPEED), function(delta) {
                self.time_backplate.add_alpha(delta);
            })
            .append(LinkId.Function, function() {
                self.time_chain = undefined;
            });

        if self.progress_bar != undefined {
            new_chain()
                .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 30), function(_, a) {
                    self.progress_bar.backplate.set_alpha(a);
                })
        }
        self.mask
            .set_speed(-2)
            .set_animation_end_callback(function() {
                self.close();
                SCREEN_FADER.snap_out();
                SCREEN_FADER.fade_in();
                self.crafting_menu.run_post_sequence();
                MIST.place_on_runtime_blackboard("sequence_complete", true);
                POST_PROCESS_TIME_OVERRIDE = undefined;

                if self.progress_bar != undefined {
                    if self.progress_bar.chain != undefined && self.progress_bar.chain.running {
                        CHAINS.cancel_chain(self.progress_bar.chain);
                    }
                    if self.progress_bar.renown_bar_sound != undefined {
                        TANGO.force_stop(self.progress_bar.renown_bar_sound);
                    }
                    ANCHOR.free_node(self.progress_bar.backplate);
                }
            }, [], true)
    }

    function present_items() {
        var item_list = self.item_lists.pop();
        var len = item_list.count();
        var live_item = item_list.first();
        var tooltip = create_tooltip(live_item, undefined)
            .add_height(28)
            .use_pilot(true)
            .return_to_previous_pilot()
        tooltip.manual_exit_listening = false;

        if len > 1 {
            tooltip.title.set_text(fmt("{} (x{})", live_item.get_display_name(), len));
            tooltip.refresh_title_height();
        }
        var button = tooltip.create_button(
            "misc_local/close",
            function() {
                if !self.item_lists.is_empty() {
                    self.present_items();
                } else {
                    self.end_sequence();
                }
            }
        );
        button.set_tap_sound("SoundEffects/UI/UIExtraPositiveClick");
        if tooltip.stat_root != undefined {
            button.add_y(-14);
        }
        ANCHOR.set_active_pilot(tooltip.pilot);
    }

    function begin_sequence() {
        self.progress_bar = undefined;
        if !self.eases.is_empty() {

            self.progress_bar = new ProgressBar(self.canvas);
            self.progress_bar.backplate
                .set_y(25)
                .set_align(Align.Center, Align.TopIn)
                .set_sprite(spr_ui_skill_progress_bar_backplate)
                .set_alpha(0)

            self.progress_bar.bar.set_sprite(spr_ui_skill_progress_bar)
                .set_x(47)
                .set_height(12)
                .set_width(self.eases.first().first_position)

            self.progress_bar.frontplate.set_sprite(spr_ui_skill_progress_bar_frontplate);

            self.progress_bar.edge.set_sprite(spr_ui_skill_progress_bar_leading_edge);

            self.progress_bar.flash
                .set_sprite(spr_ui_skill_progress_bar_flash)
                .set_align(Align.LeftIn, Align.Middle)
                .set_x(47)

            self.progress_bar.max_width = 126;

            self.skill_ui = render_skill_level(self.progress_bar.frontplate, self.skill_id)
                .set_x(13)
                .set_align(Align.LeftIn, Align.Middle);
            self.skill_ui.update_level(self.eases.first().level);

            self.skill_up = undefined;

            self.progress_bar.level_up_callback = function(order) {
                if self.skill_up == undefined {
                    self.skill_up = rainbow_text(self.progress_bar.backplate, "misc_local/skill_up")
                        .set_y(-10)
                        .set_align(Align.Center, Align.TopOut)
                }

                self.level_up_delay = 120;
                self.skill_ui.update_level(order.level + 1);
            }

            self.progress_bar.level_up_continue_check = function() {
                self.level_up_delay -= 1;
                return self.level_up_delay <= 0;
            }

            self.progress_bar.reward_box.disable();

            new_chain()
                .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 15), function(_, a) {
                    self.progress_bar.backplate.set_alpha(a);
                })
                .append(LinkId.Function, function() {
                    self.progress_bar.perform_eases(self.eases, new_chain());
                })
        }

        new_chain()
            .join(LinkId.Timer, 30)
            .append(LinkId.Ease, new Ease(EaseId.QuadInOut, self.start_time, self.target_time, self.data.duration), function(_, a) {
                MIST.place_on_runtime_blackboard("timelapse_begin", true);
                POST_PROCESS_TIME_OVERRIDE = a;
                self.time.forced_time = a;
                self.time.update();
                self.time_backplate.set_width(self.time.get_width() + 14);
            })
            .append(LinkId.Await, function() {
                return obj_ari.par.animation_complete;
            })
            .append(LinkId.Function, function() {
                MIST.place_on_runtime_blackboard("timelapse_complete", true);
            })
            .append(LinkId.Await, function() {
                return MIST.get_from_runtime_blackboard("spawn_menu") == true;
            })
            .append(LinkId.Function, function() {
                self.present_items();
            })
    }

    self.crafting_menu = crafting_menu;
    self.recipe = recipe;
    self.item_lists = item_lists;
    self.target_time = target_time;
    self.start_time = CLOCK.time;
    self.eases = eases;
    self.skill_id = skill_id;

    //
    //
    POST_PROCESS.update(self.start_time);

    //
    self.mask = ANCHOR.sprite(self.canvas)
        .set_sprite(spr_ui_generic_mask_circle_black)
        .set_speed(2)
        .set_align(Align.Center, Align.Middle)
        .set_animation_end_callback(function() {
            self.mask.set_speed(0);
            self.begin_sequence();
        })

    var true_size = ANCHOR.get_true_size();
    self.left_panel = ANCHOR.nine_slice(self.mask)
        .set_sprite(spr_pixel)
        .set_color(c_black)
        .set_align(Align.LeftOut, Align.Middle)
        .set_size(true_size.x, true_size.y)
    self.top_panel = ANCHOR.nine_slice(self.mask)
        .set_sprite(spr_pixel)
        .set_color(c_black)
        .set_align(Align.Center, Align.TopOut)
        .set_size(true_size.x, true_size.y)
    self.right_panel = ANCHOR.nine_slice(self.mask)
        .set_sprite(spr_pixel)
        .set_color(c_black)
        .set_align(Align.RightOut, Align.Middle)
        .set_size(true_size.x, true_size.y)
    self.bottom_panel = ANCHOR.nine_slice(self.mask)
        .set_sprite(spr_pixel)
        .set_color(c_black)
        .set_align(Align.Center, Align.BottomOut)
        .set_size(true_size.x, true_size.y)

    self.time_backplate = ANCHOR.nine_slice(self.canvas)
        .set_xy(-6, 6)
        .add_z(-10)
        .set_align(Align.RightIn, Align.TopIn)
        .set_sprite(spr_ui_generalstore_inventory_currencytab)
        .set_size(78, 19)
        .enable_day_night_lut()
        .set_alpha(0)

    self.time = new TimeWidget(self.time_backplate, -10 - (SETTINGS.get("twenty_four_hour_clock") ? 4 : 0), 0, Align.RightIn, Align.Middle, self.start_time);
    self.time.time_am_pm.enable_day_night_lut();
    self.time.time_text_minutes.enable_day_night_lut();
    self.time.time_colon.enable_day_night_lut();
    self.time.time_text_hours.enable_day_night_lut();

    self.time_chain = new_chain()
        .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 20), function(delta) {
            self.time_backplate.add_alpha(delta);
        })
        .append(LinkId.Function, function() {
            self.time_chain = undefined;
        })

    self.time_backplate.set_width(self.time.get_width() + 14);
}
