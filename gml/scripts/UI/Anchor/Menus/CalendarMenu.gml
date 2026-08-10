function CalendarMenu(ari) : AnchorMenu(Menu.Calendar) constructor {
    self.filter = function(time) {
        var year = years(get_years(self.time));
        return time >= year && time < year + years(1);
    };
    self.show_events_flag = true;
    self.pilot = undefined;
    self.pilot_cache = undefined;
    self.time = 0;
    self.ari = ARI;
    self.select_callback = undefined;
    self.show_year_flag = true;
    self.today = undefined;
    self.text_for_banner = undefined;

    function on_close() {
        if self.pilot_cache != undefined {
            ANCHOR.set_active_pilot(self.pilot_cache);
        }
    }

    //
    function with_time(time) {
        self.time = time;
        return self;
    }

    //
    function with_today(today) {
        self.today = today;
        return self;
    }

    //
    function with_ari(ari) {
        self.ari = ari;
        return self;
    }

    //
    //
    //
    function with_filter(filter) {
        self.filter = filter;
        return self;
    }

    //
    function show_events(show_events_flag=true) {
        self.show_events_flag = show_events_flag;
        return self;
    }

    //
    //
    function enable_selection(select_callback) {
        self.select_callback = select_callback;
        return self;
    }

    //
    function show_year(show_year_flag=true) {
        self.show_year_flag = show_year_flag;
        return self;
    }

    function with_banner(banner) {
        self.text_for_banner = banner;
        return self;
    }

    //
    function build() {
        var season = get_seasons(self.time);
        var day = get_days(self.time);

        self.backplate = ANCHOR.sprite(self.canvas)
            .set_align(Align.Center, Align.Middle)
            .set_sprite(string_to_asset(format("spr_ui_calendar_backplate_{Season}", season)))

        if self.text_for_banner != undefined {
            var width = string_width_font(self.text_for_banner) + 32;
            self.banner = ANCHOR.nine_slice(self.backplate)
                .set_size(width, 14)
                .set_align(Align.Center, Align.TopIn)
                .set_sprite(spr_ui_generalstore_prompt_box)
                .add_text_label(self.text_for_banner)
        }

        self.title = ANCHOR.text(self.backplate)
            .set_align(Align.Center, Align.TopIn)
            .set_xy(5, 13)
            .set_lut(COMMON_LUT)

        self.arrow_left_button = ANCHOR.nine_slice(self.backplate)
            .set_sprites_from_key(format("spr_ui_calendar_button_{Season}", season))
            .set_size(16)
            .add_glyph(InputId.MenuTabLeft, undefined, true)
            .set_tap_sound("SoundEffects/UI/UIJournalTabSwitch")
            .set_xy(8, 12)
            .set_tap_callback(function() {
                self.time -= seasons(1);
                self.refresh();
            })

        self.arrow_left_icon = ANCHOR.sprite(self.arrow_left_button)
            .set_align(Align.Center, Align.Middle)
            .set_sprites_from_key(format("spr_ui_calendar_left_arrow_{Season}", season))
            .set_key_sprite_target(self.arrow_left_button)

        self.arrow_right_button = ANCHOR.nine_slice(self.backplate)
            .set_sprites_from_key(format("spr_ui_calendar_button_{Season}", season))
            .set_size(16)
            .add_glyph(InputId.MenuTabRight)
            .set_tap_sound("SoundEffects/UI/UIJournalTabSwitch")
            .set_xy(-8, 12)
            .set_align(Align.RightIn, Align.TopIn)
            .set_tap_callback(function() {
                self.time += seasons(1);
                self.refresh();
            })

        self.arrow_right_icon = ANCHOR.sprite(self.arrow_right_button)
            .set_align(Align.Center, Align.Middle)
            .set_sprites_from_key(format("spr_ui_calendar_right_arrow_{Season}", season))
            .set_key_sprite_target(self.arrow_right_button)

        self.season_icon = ANCHOR.sprite(self.title)
            .set_align(Align.LeftOut, Align.Middle)
            .set_x(-2)

        self.grid_area = ANCHOR.positional(self.backplate)
            .set_xy(18, 52)
            .set_size(274, 157)

        self.refresh();

        return self;
    }

    //
    function refresh() {
        var season = get_seasons(self.time);
        var day = get_days(self.time);
        var year = get_years(self.time);

        if self.pilot_cache == undefined {
            self.pilot_cache = ANCHOR.get_active_pilot();
        }
        self.pilot = self.new_pilot()
            .allow_horizontal_wrapping()
            .allow_vertical_wrapping()

        self.backplate.set_sprite(string_to_asset(format("spr_ui_calendar_backplate_{Season}", season)))

        var lut_index = season + 1;
        var season_display = local_get(format("misc_local/{Season}", season));
        var year_insert = self.show_year_flag ? format(" - {Local} {}", "misc_local/year", year + 1) : "";
        self.title.set_text(season_display + year_insert);
        self.title.set_lut_index(lut_index + 8);
        self.season_icon.set_sprite(string_to_asset(format(
            "spr_ui_calendar_icon_{}",
            season == Season.Fall ? "autumn" : season_to_string(season)
        )));

        self.arrow_left_button.set_sprites_from_key(format("spr_ui_calendar_button_{Season}", season));
        self.arrow_left_icon.set_sprites_from_key(format("spr_ui_calendar_left_arrow_{Season}", season));
        self.arrow_right_button.set_sprites_from_key(format("spr_ui_calendar_button_{Season}", season));
        self.arrow_right_icon.set_sprites_from_key(format("spr_ui_calendar_right_arrow_{Season}", season));

        var previous_season_valid = false;
        var next_season_valid = false;
        var start_of_season = self.time - days(get_days(self.time));
        for (var i = 0; i < 28; i++) {
            var previous = start_of_season - seasons(1) + days(i);
            var next = start_of_season + seasons(1) + days(i);
            previous_season_valid |= previous > 0 && self.filter(previous);
            next_season_valid |= self.filter(next);
        }

        self.arrow_left_button.set_unlocked(previous_season_valid);
        self.arrow_right_button.set_unlocked(next_season_valid);

        ANCHOR.free_children(self.grid_area);
        var assets = ListFromArray(array_create_ext(28, identity));
        var layout = new GridLayout(assets, self.pilot, 7, 40);
        while layout.has_next() {
            var output = layout.next(self.grid_area);
            var this_time = start_of_season + days(output.iter);
            var passes_filter = self.filter(this_time);
            var alpha = 1;
            if !passes_filter || (self.today != undefined && this_time < self.today) {
                alpha = 0.4;
            }

            var tile = output.square;
            tile
                .listen_for_hovers()
                .set_sprites_from_key("spr_nothing_nineslice")
                .set_hovered_untappable_sprite(spr_ui_generic_box_hovered_untappable)
                .set_hovered_sprite(spr_ui_generic_box_hovered_untappable)

            if self.time == this_time && ANCHOR.in_directional_control() {
                self.pilot.force_select(tile);
            }

            if self.select_callback != undefined {
                tile.set_tap_callback(function(this_time) {
                    self.time = this_time;
                    self.select_callback(self);
                }, [this_time]);
                tile.set_soft_locked(!passes_filter);
            }

            var num = ANCHOR.text(tile)
                .set_xy(3, 3)
                .set_sprite_font("calendar_font_number")
                .set_lut(spr_ui_calendar_font_number_lut)
                .set_text(get_days(this_time) + 1)
                .set_alpha(alpha)
                .set_z(tile.get_z() - 50);

            //
            //
            //
            //
            var events = List();
            if self.show_events_flag {
                if ARI.wedding_date != undefined
                    && season == get_seasons(ARI.wedding_date)
                    && get_days(this_time) == get_days(ARI.wedding_date)
                {
                    events.push({
                        sprite: spr_ui_calendar_icon_event_wedding,
                        pos: Vec2(-3, -3),
                        text: get_years(ARI.wedding_date) == get_years(this_time)
                            ? local_get("misc_local/your_wedding")
                            : local_get("misc_local/your_anniversary"),
                    });
                }

                if ARI.pending_child != undefined
                    && season == get_seasons(ARI.pending_child.due_date)
                    && get_days(this_time) == get_days(ARI.pending_child.due_date)
                {
                     events.push({
                        sprite: spr_ui_calendar_icon_event_baby,
                        pos: Vec2(-3, -3),
                        text: local_get("misc_local/due_date"),
                     });
                }

                for (var i = 0; i < FestivalId.LEN; i++) {
                    var festival = FESTIVALS[i];
                    if !festival.prototype.implemented {
                        continue;
                    }
                    if festival.prototype.date.season == season && festival.prototype.date.day - 1 == get_days(this_time) {
                        events.push({
                            sprite: festival.prototype.icon,
                            pos: Vec2(-3, -3),
                            text: local_get(festival.prototype.name),
                        });
                    }
                }


                for (var i = 0; i < array_length(ARI.children); i++) {
                    var child = ARI.children[i];
                    if season == get_seasons(child.birthday) && get_days(this_time) == get_days(child.birthday) {
                        events.push({
                            sprite: child.get_small_icon(),
                            pos: Vec2(-3, -3),
                            text: format(local_get("misc_local/birthday_template"), child.name),
                        });
                    }
                }


                for (var i = 0; i < NpcId.LEN; i++) {
                    var npc = NPCS[i];
                    if npc.has_met()
                        && npc_is_unlocked(i)
                        && npc.prototype.birthday.season == season
                        && npc.prototype.birthday.day - 1 == get_days(this_time)
                    {
                        events.push({
                            sprite: get_npc_icon(i),
                            pos: Vec2Zero(),
                            text: format(local_get("misc_local/birthday_template"), local_get(npc.prototype.name)),
                        });
                    }
                }
            }

            //
            if season == get_seasons(self.ari.birthday) && get_days(this_time) == get_days(self.ari.birthday) {
                events.push({
                    sprite: spr_ui_generic_birthday_icon,
                    text: format(local_get("misc_local/birthday_template"), self.ari.name),
                    pos: Vec2(-2, -2),
                });
            }

            var text = "";
            for (var i = 0; i < events.count(); i++) {
                var event = events.get(i);
                text += event.text + "\n";
                if i > 1 {
                    continue;
                }

                var xx = i == 0 ? event.pos.x : abs(event.pos.x);
                var align = i == 0 ? Align.RightIn : Align.LeftIn;
                ANCHOR.sprite(tile)
                    .set_xy(xx, event.pos.y)
                    .set_align(align, Align.BottomIn)
                    .set_sprite(event.sprite)
                    .set_alpha(alpha)
                    .set_z(tile.get_z() - 50)

            }

            if this_time == self.today {
                num.set_lut(spr_ui_calendar_weekdays_lut, lut_index);
            }

            if text != "" {
                text = string_delete(text, string_length(text), 1);
                var width = string_width_font(text) + 24;
                var height = string_height(text) + 8;
                var bubble = ANCHOR.nine_slice(tile);
                bubble
                    .set_sprite(spr_ui_calendar_popup_box)
                    .set_size(width, height)
                    .set_alpha(0)
                    .set_align(Align.Center, Align.TopOut)
                    .set_z(tile.get_z() - 200)
                    .set_think_callback(function(tile, bubble) {
                        bubble.set_alpha(tile.is_hovered())
                    }, [tile, bubble])

                var text = ANCHOR.text(bubble)
                    .set_text(text)
                    .set_text_align(TextAlign.Center)
                    .set_align(Align.Center, Align.Middle)
                    .set_lut(COMMON_LUT)
            }

            if output.iter mod 4 == 0 {
                var n = output.iter div 4;
                ANCHOR.sprite(self.grid_area)
                    .set_xy((39 * n) + 12, -11)
                    .set_sprite(string_to_asset(format("spr_ui_hud_font_calendar_weekdays_{}", asset_local_insert())))
                    .set_index(n)
                    .set_lut(spr_ui_calendar_weekdays_lut, lut_index)
            }
        }

        ANCHOR.set_active_pilot(self.pilot);
    }

}

function spawn_calendar_ui(time) {
    return ANCHOR.spawn_menu(Menu.Calendar).with_time(time);
}
