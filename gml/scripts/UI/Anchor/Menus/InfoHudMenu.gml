enum InfoHudDepth {
    CalendarDayNum = 100,
    CalendarDayName,
    Calendar,
    EssenceIcon,
    EssenceText,
    CurrencyIcon,
    CurrencyText,
    BottomBackplate,
    TimeHours,
    TimeColon,
    TimeMinutes,
    TimeAmPM,
    TimeRoot,
    MiddleBackplate,
    SeasonName,
    WeatherIcon,
    WeatherIconOutline,
    TopBackplate,
}

function InfoHudMenu() : AnchorMenu(Menu.InfoHud) constructor {
    #macro INFO_HUD_BOTTOM_BACKPLATE_BASE_W 24

    //
    function update_time() {
        self.time_widget.update();

        //
        self.season_name.set_index(CALENDAR.season());

        self.calendar.update();

        //
        var s = ui_icon_for_weather(WEATHER.weather, CALENDAR.season());
        self.weather_icon.set_sprite(s);
    }

    //
    function update_essence() {
        if !requirements_pass(Requirement.CollectEssence) {
            self.essence_icon.set_alpha(0);
            self.bottom_backplate.set_height(15);
            return;
        }
        self.essence_icon.set_alpha(1);
        var s = num_display(ARI.get_essence());
        self.essence_text.set_text(s);
        var new_w = self.get_size_for_bottom_backplate();
        self.bottom_backplate.set_width(new_w);
        self.bottom_backplate.set_height(24);
    }

    function get_size_for_bottom_backplate() {
        var gold_w = sprite_font_width(num_display(ARI.get_gold()), "currency");
        var essence_w = sprite_font_width(num_display(ARI.get_essence()), "currency");
        var width = max(gold_w, essence_w);

        return width + 16;
    }

    function on_think() {
        if !HUD_TARGET {
            return;
        }
        self.update_time();
        if ARI.pinned_spell != undefined {
            self.spell_pin.set_unlocked(can_cast_spell(ARI.pinned_spell));
        }
        self.mount_pin.set_enabled(ARI.mount != undefined);
        if ARI.mount != undefined && instance_exists(obj_ari) {
            self.mount_pin.set_unlocked(obj_ari.can_mount() && ARI.held_animal_id == undefined);
        }
    }

    self.top_backplate = ANCHOR.nine_slice(self.canvas, InfoHudDepth.TopBackplate)
        .set_xy(-6, 6)
        .set_align(Align.RightIn, Align.TopIn)
        .set_sprite(spr_ui_hud_info_backplate_top)
        .enable_day_night_lut()
        .set_size(102, 18)

    self.weather_icon = ANCHOR.sprite(self.top_backplate, InfoHudDepth.WeatherIcon)
        .set_x(7)
        .set_align(Align.LeftIn, Align.Middle)
        .set_sprite(spr_ui_hud_info_backplate_seasonandweather_icon_day_spring_clear)

    self.season_name = ANCHOR.sprite(self.top_backplate, InfoHudDepth.SeasonName)
        .set_xy(-4, 0)
        .set_align(Align.Center, Align.Middle)
        .set_sprite(string_to_asset(format("spr_ui_hud_season_name_baked_text_{}", asset_local_insert())))
        .enable_day_night_lut()

    self.calendar = calendar_widget(self.top_backplate)
        .set_z(InfoHudDepth.Calendar)

    self.middle_backplate = ANCHOR.nine_slice(self.canvas, InfoHudDepth.MiddleBackplate)
        .set_xy(-6, 23)
        .set_align(Align.RightIn, Align.TopIn)
        .set_sprite(spr_ui_hud_info_backplate_middle)
        .enable_day_night_lut()
        .set_size(97, 19)

    self.time_widget = new TimeWidget(self.middle_backplate, -30, 0, Align.RightIn, Align.Middle);

    self.time_widget.time_am_pm.enable_day_night_lut();
    self.time_widget.time_text_minutes.enable_day_night_lut();
    self.time_widget.time_colon.enable_day_night_lut();
    self.time_widget.time_text_hours.enable_day_night_lut();

    self.bottom_backplate = ANCHOR.nine_slice(self.canvas, InfoHudDepth.BottomBackplate)
        .set_xy(-6, 41)
        .set_align(Align.RightIn, Align.TopIn)
        .set_sprite(spr_ui_hud_info_backplate_bottom)
        .enable_day_night_lut()
        .set_size(24, 24)

    self.essence_icon = ANCHOR.sprite(self.bottom_backplate)
        .set_xy(-3, -3)
        .set_sprite(spr_ui_hud_info_essence_icon)
        .set_align(Align.RightIn, Align.BottomIn)
        .enable_day_night_lut();

    self.essence_text = ANCHOR.text(self.essence_icon)
        .set_x(-1)
        .set_sprite_font("currency")
        .set_align(Align.LeftOut, Align.Middle)
        .enable_day_night_lut();

    self.currency_icon = ANCHOR.sprite(self.bottom_backplate)
        .set_xy(-3, 3)
        .set_sprite(spr_ui_hud_info_currency_icon)
        .set_align(Align.RightIn, Align.TopIn)
        .enable_day_night_lut();

    self.currency_text = ANCHOR.text(self.currency_icon)
        .set_x(-1)
        .set_sprite_font("currency")
        .set_align(Align.LeftOut, Align.Middle)
        .enable_day_night_lut();

    self.currency_adder = ANCHOR.text(self.bottom_backplate, InfoHudDepth.CurrencyText)
        .set_xy(-4, 23)
        .set_sprite_font("player_level")
        .set_align(Align.Center, Align.BottomOut)
        .disable()

    self.gold_animator = new GoldAnimator(
        self.bottom_backplate,
        self.currency_text,
        self.currency_adder,
        self.get_size_for_bottom_backplate,
    );

    self.journal_pin = ANCHOR.sprite(self.canvas)
        .set_align(Align.RightIn, Align.BottomIn)
        .set_xy(-8, -7)
        .set_sprite(spr_ui_hud_journal_icon)
        .add_glyph(InputId.OpenJournal)
        .set_tap_callback(function() {
            obj_ari.ui_journal_request = true;
        })

    self.map_pin = ANCHOR.sprite(self.canvas)
        .set_align(Align.RightIn, Align.BottomIn)
        .set_xy(-30, -7)
        .set_sprite(spr_ui_hud_map_icon)
        .add_glyph(InputId.OpenMapMenu)
        .set_tap_callback(function() {
            obj_ari.ui_map_request = true;
        })

    self.spell_pin = ANCHOR.sprite(self.canvas)
        .set_align(Align.RightIn, Align.BottomIn)
        .set_xy(-52, -7)
        .add_glyph(InputId.CastPinnedSpell)
        .disable()

    self.mount_pin = ANCHOR.sprite(self.canvas)
        .set_align(Align.RightIn, Align.BottomIn)
        .set_xy(-74, -7)
        .add_glyph(InputId.Ride)
        .set_sprite(spr_ui_hud_mount_icon_main)
        .set_tap_callback(function() {
            obj_ari.ui_mount_request = true;
        })

    self.journal_pin.glyph_node.set_xy(3, 4);
    self.map_pin.glyph_node.set_xy(3, 4);
    self.spell_pin.glyph_node.set_xy(3, 4);
    self.mount_pin.glyph_node.set_xy(3, 4);

    self.journal_pin.glyph_node.trigger_taps = false;
    self.map_pin.glyph_node.trigger_taps = false;
    self.spell_pin.glyph_node.trigger_taps = false;
    self.mount_pin.glyph_node.trigger_taps = false;

    //
    self.update_time();
    self.update_essence();

    if ARI.pinned_spell != undefined {
        self.spell_pin.set_sprites_from_key(SPELLS[ARI.pinned_spell].icon_key);
        self.spell_pin.enable();
    }

    self.gold_animator.set_gold(ARI.get_gold(), true);
}

//
//
function GoldAnimator(backplate, text, adder, width_getter) constructor {
    self.gold_to_add = 0;
    self.gold_true = 0;
    self.gold_chain = undefined;
    self.bottom_backplate_chain = undefined;
    self.gold_life_timer = 0;
    self.backplate = backplate;
    self.backplate_base_width = width_getter();
    self.backplate_target_width = self.backplate_base_width;
    self.text = text;
    self.adder = adder;
    self.width_getter = width_getter;
    self.adder.set_free_callback(function() {
        if self.gold_chain != undefined {
            CHAINS.cancel_chain(self.gold_chain);
        }
    })

    //
    //
    //
    //
    //
    //
    function set_gold(val, instant=false) {
        //
        if !self.backplate.get_enabled() {
            instant = true;
        }
        //
        if instant {
            self.gold_true = val;
            self.update_text(true);
            return;
        }

        //
        if val == self.gold_true {
            self.adder.set_y(GOLD_ADDER_Y);
            self.adder.disable();
            self.gold_to_add = 0;
            self.gold_life_timer = 0;
            if self.gold_chain != undefined {
                CHAINS.cancel_chain(self.gold_chain);
                self.gold_chain = undefined;
            }
            return;
        }

        //
        var delta = val - self.gold_true;
        self.gold_to_add += delta - self.gold_to_add;

        //
        //
        //
        self.gold_life_timer = MENUS.get(Menu.InfoHud).gold_adder_wait_time;

        //
        if self.gold_chain == undefined {

            //
            TANGO.play(
                sign(self.gold_to_add) == 1
                ? "SoundEffects/Inventory/StoreSell"
                : "SoundEffects/Inventory/StorePurchase"
            );

            self.update_adder();

            self.sound_ticker = 1;

            //
            self.gold_chain = new_chain()
                //
                .join(LinkId.Ease, new Ease(EaseId.BackOut, 0, -15, 10), function(delta) {
                    self.adder.add_y(delta);
                })
                .join(LinkId.Ease, new Ease(EaseId.Linear, 0, 1, 10), function(delta) {
                    self.adder.add_alpha(delta);
                })

                //
                .append(LinkId.Await, function() {
                    self.update_adder();
                    self.gold_life_timer -= 1;
                    return self.gold_life_timer == 0;
                })

                //
                //
                .append(LinkId.Await, function() {
                    self.update_adder();

                    //
                    //
                    //
                    var multi = max(1, abs(self.gold_to_add) div 10);

                    //
                    if sign(self.gold_to_add) == 1 {
                        var amount = min(multi, self.gold_to_add);
                        self.gold_to_add -= amount;
                        self.gold_true += amount;
                    } else {
                        var amount = max(-multi, self.gold_to_add);
                        self.gold_to_add -= amount;
                        self.gold_true += amount;
                    }

                    //
                    if TICK mod min(7, floor(self.sound_ticker)) == 0 {
                        TANGO.play("SoundEffects/Inventory/CoinRackup");
                    }
                    self.sound_ticker += 0.07;

                    //
                    self.update_text();

                    //
                    return abs(self.gold_to_add) <= 0;
                })

                //
                .append(LinkId.Ease, new Ease(EaseId.BackIn, 0, 15, 10), function(delta) {
                    self.adder.add_y(delta);
                })
                .join(LinkId.Ease, new Ease(EaseId.Linear, 0, 1, 10), function(delta) {
                    self.adder.add_alpha(-delta);
                })

                //
                .append(LinkId.Function, function() {
                    self.adder.disable();
                    self.gold_to_add = 0;
                    self.gold_chain = undefined;
                })
        }
    }

    //
    function update_adder() {
        //
        var color =
            sign(self.gold_to_add) == 1
            ? make_color_rgb(255, 206, 74)
            : make_color_rgb(255, 82, 72);

        //
        var prefix = sign(self.gold_to_add) == 1 ? "+" : "-";

        //
        self.adder.enable();
        self.adder
            .set_color(color)
            .set_text(prefix + num_display(abs(self.gold_to_add)));
    }

    //
    function update_text(instant=false) {
        var new_w = self.width_getter();

        var gold_text = num_display(self.gold_true); //
        self.text.set_text(gold_text);

        //
        if instant {
            self.backplate.set_width(new_w);
            self.backplate_target_width = new_w;
            return;
        }

        //
        if self.bottom_backplate_chain == undefined || self.backplate_target_width != new_w {
            self.backplate_target_width = new_w;

            //
            if self.bottom_backplate_chain != undefined {
                CHAINS.cancel_chain(self.bottom_backplate_chain);
            }

            //
            self.bottom_backplate_chain = new_chain()
                .join(
                    LinkId.Ease,
                    new Ease(
                        EaseId.QuartOut,
                        self.backplate.get_width(),
                        new_w,
                        15
                    ),
                    function (_, abs_val) {
                        self.backplate.set_width(abs_val);
                    }
                )
                .append(LinkId.Function, function() {
                    self.bottom_backplate_chain = undefined;
                });
        }

    }
}
