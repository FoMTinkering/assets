#macro PLAYTIME global.__playtime
PLAYTIME = undefined;

function LoadMenu(canvas) : AnchorMenu(Menu.Load) constructor {
    self.selected_path = undefined;
    self.canvas = canvas;

    self.backplate = ANCHOR.sprite(self.canvas)
        .set_sprite(spr_ui_load_save_backplate)
        .set_align(Align.Center, Align.Middle)

    self.title = ANCHOR.text(self.backplate)
        .set_align(Align.Center, Align.TopIn)
        .set_y(9)
        .set_key("misc_local/load_game")
        .set_lut(COMMON_LUT, CommonLutIndex.Header)

    self.icon = ANCHOR.sprite(self.title)
        .set_align(Align.LeftOut, Align.Middle)
        .set_x(-2)
        .set_sprite(spr_ui_popup_diary_header_icon)

    self.pilot = self.new_pilot()
        .allow_vertical_wrapping()

    self.scroller = undefined;

    function refresh() {
        if self.scroller != undefined {
            self.scroller.free();
        }
        self.pilot.reset();
        self.scroller = create_scroller(
            self.backplate,
            Vec2(2, 31),
            Vec2(363, 176)
        );
        self.scroller.subscribe_to_pilot(self.pilot);

        for (var i = 0; i < Setup.load_menu_data.count(); i++) {
            var data = Setup.load_menu_data.get(i);
            var element = self.scroller.new_element(60)
                .add_to_pilot(self.pilot, true)
                .set_tap_callback(function(data) {
                    var mcp = new MultipleChoicePopup("misc_local/load_game");

                    mcp.option("misc_local/load_game", function(data) {
                        var title_menu = ANCHOR.get_menu(Menu.Title);
                        var load_bundle = Setup.save_manager.manifest.get(data.path);
                        title_menu.enter_game(LoadState.Load(load_bundle));
                    }, [data]);

                    mcp.option("misc_local/delete", function(data) {
                        var popup = popup_creator("misc_local/confirmation", "misc_local/delete_save_confirmation");
                        popup.create_button("misc_local/no");
                        popup.create_button("misc_local/yes", function(data) {
                            var output = file_delete(data.path);
                            if output != undefined {
                                error("failed to delete a file!");
                            }
                            vault_close_all_vaults();
                            Setup.save_manager = new SaveManager();
                            var index = Setup.load_menu_data.find_lazy(data);
                            Setup.load_menu_data.remove(index);
                            self.refresh();
                        }, [data]);
                        popup.spawn();
                    }, [data]);

                }, [data])

            var ari_box = ANCHOR.sprite(element)
                .set_x(12)
                .set_align(Align.LeftIn, Align.Middle)

            switch get_seasons(data.calendar_time) {
                case Season.Spring:
                    ari_box.set_sprite(spr_ui_load_save_sprite_bg_spring)
                    break;
                case Season.Summer:
                    ari_box.set_sprite(spr_ui_load_save_sprite_bg_summer)
                    break;
                case Season.Fall:
                    ari_box.set_sprite(spr_ui_load_save_sprite_bg_fall)
                    break;
                case Season.Winter:
                    ari_box.set_sprite(spr_ui_load_save_sprite_bg_winter)
                    break;
                default: impossible("Unexpected Season: {}", get_seasons(data.calendar_time));
            }

            ANCHOR.create_ari_node(ari_box, data.preset, 25, 36, 1, self.scroller.canvas);

            ANCHOR.text(ari_box)
                .set_xy(12, -1)
                .set_align(Align.RightOut, Align.TopIn)
                .set_text(data.name)
                .set_lut(COMMON_LUT)

            var farm_icon = ANCHOR.sprite(ari_box)
                .set_align(Align.RightOut, Align.TopIn)
                .set_xy(11, 13)
                .set_sprite(spr_ui_generic_my_farm_icon)

            ANCHOR.text(farm_icon)
                .set_x(3)
                .set_align(Align.RightOut, Align.Middle)
                .set_text(data.farm_name)
                .set_lut(COMMON_LUT, CommonLutIndex.Blue)

            var play_time = ANCHOR.text(ari_box)
                .set_align(Align.RightOut, Align.TopIn)
                .set_xy(12, 25)
                .set_key("misc_local/play_time")
                .set_lut(COMMON_LUT)

            var true_seconds = floor(max(data.playtime, 0));
            var true_minutes = true_seconds div 60;
            var true_hours = true_minutes div 60;
            var seconds_display = true_seconds % 60;
            var minutes_display = true_minutes % 60;
            minutes_display = string_length(minutes_display) == 1 ? "0" + string(minutes_display) : minutes_display;
            seconds_display = string_length(seconds_display) == 1 ? "0" + string(seconds_display) : seconds_display;
            ANCHOR.text(play_time)
                .set_align(Align.RightOut, Align.Middle)
                .set_xy(4, 1)
                .set_sprite_font("save_load")
                .set_lut(COMMON_LUT, CommonLutIndex.Green)
                .set_text(fmt("{}:{}:{}", true_hours, minutes_display, seconds_display))

            var gold_icon = ANCHOR.sprite(ari_box)
                .set_align(Align.RightOut, Align.BottomIn)
                .set_xy(12, -1)
                .set_sprite(spr_ui_journal_inventory_currency_icon)

            var gold_text = ANCHOR.text(gold_icon)
                .set_align(Align.RightOut, Align.Middle)
                .set_x(2)
                .set_text(data.stats.gold)
                .set_sprite_font("currency")
                .set_lut(spr_ui_journal_inventory_currency_font_lut)

            var essence_icon = ANCHOR.sprite(gold_text)
                .set_align(Align.RightOut, Align.Middle)
                .set_x(5)
                .set_sprite(spr_ui_journal_inventory_essence_icon)

            ANCHOR.text(essence_icon)
                .set_align(Align.RightOut, Align.Middle)
                .set_x(2)
                .set_text(data.stats.essence)
                .set_sprite_font("currency")
                .set_lut(spr_ui_journal_inventory_currency_font_lut);

            var ten_am = SETTINGS.get("oversleep_penalty") && opt_and_then(data.stats[$ "end_of_day_status"], function(s) {
                return string_to_end_of_day_status(s) != EndOfDayStatus.Normal;
            });
            var time = ten_am ? OVERSLEEP_TIME_TARGET : data.clock_time;

            var time_widget = new TimeWidget(element, -9, 7, Align.RightIn, Align.TopIn, time);
            time_widget.time_root.set_lut(spr_ui_journal_inventory_currency_font_lut);
            time_widget.time_am_pm.set_lut(spr_ui_journal_inventory_currency_font_lut);
            time_widget.time_text_minutes.set_lut(spr_ui_journal_inventory_currency_font_lut);
            time_widget.time_colon.set_lut(spr_ui_journal_inventory_currency_font_lut);
            time_widget.time_text_hours.set_lut(spr_ui_journal_inventory_currency_font_lut);

            var s = ui_icon_for_weather(
                string_to_weather(data.weather.forecast[get_days(data.calendar_time)]),
                get_seasons(data.calendar_time),
            );
            var weather_icon = ANCHOR.sprite(element)
                .set_align(Align.RightIn, Align.TopIn)
                .set_xy(-9, 20)
                .set_sprite(s)

            ANCHOR.text(weather_icon)
                .set_align(Align.LeftOut, Align.Middle)
                .set_x(-3)
                .set_lut(COMMON_LUT)
                .set_text(
                    format(
                        "{Local} {}",
                        "misc_local/" + season_to_string(get_seasons(data.calendar_time)),
                        get_days(data.calendar_time) + 1,
                    )
                );

            var year_icon = ANCHOR.sprite(element)
                .set_align(Align.RightIn, Align.TopIn)
                .set_sprite(spr_ui_journal_inventory_calendar_icon)
                .set_xy(-9, 34)

            ANCHOR.text(year_icon)
                .set_x(-3)
                .set_lut(COMMON_LUT)
                .set_align(Align.LeftOut, Align.Middle)
                .set_text(format("{Local} {}", "misc_local/year", get_years(data.calendar_time) + 1))

            var renown_icon = ANCHOR.sprite(element)
                .set_align(Align.RightIn, Align.TopIn)
                .set_sprite(spr_ui_journal_inventory_renown_icon)
                .set_xy(-9, 46)

            ANCHOR.text(renown_icon)
                .set_x(-3)
                .set_lut(COMMON_LUT, CommonLutIndex.Green)
                .set_align(Align.LeftOut, Align.Middle)
                .set_text(format("Lvl {}", renown_to_level(data.stats.renown)),)

            var is_auto = string_pos("autosave", data.path) != 0;
            ANCHOR.sprite(ari_box)
                .set_sprite(is_auto ? spr_ui_load_save_icon_autosave : spr_ui_load_save_icon_manual_save)
        }

        ANCHOR.set_active_pilot(self.pilot);
    }
    self.refresh();
}
