//
function EodMenu() : AnchorMenu(Menu.Eod) constructor {
    self.life_chain = undefined;
    self.sequence_canvas = undefined;
    self.receipt_button = undefined;
    self.recipe_backplate = undefined;
    self.next_day_button = undefined;
    self.calendar = undefined;
    self.items_sold = undefined;
    self.gold_earned = 0;
    self.renown_earned = 0;
    self.valid_destinations = undefined;
    self.destination_index = undefined;
    self.goto_special_destination = false;
    self.scroller = undefined;
    self.has_prepped = false;
    self.calendar_number = undefined;
    self.calendar_day_name = undefined;
    self.calendar_season = undefined;
    self.pilot = self.new_pilot();
    self.held_point_of_interest = undefined;

    function on_close() {
        ANCHOR.free_node(self.sequence_canvas);
    }

    //
    function init() {
        //
        self.valid_destinations = List();
        self.destination_index = 0;
        var buildings = get_buildings();
        for (var i = 0; i < buildings.count(); i++) {
            var building = buildings.get(i);
            self.valid_destinations.push({
                location_id: building.prototype.location_id,
                dyn_index: building.dyn_index,
                required_position: undefined,
                tilesets: building.prototype.tilesets,
                variant: building.variant
            });
        }

        var animals = get_all_animals();
        for (var i = 0; i < animals.count(); i++) {
            var animal = animals.get(i);

            if animal.is_home() == false {
                self.valid_destinations.push({
                    location_id: animal.location_position.location_id,
                    dyn_index: animal.location_position.dyn_index,
                    required_position: animal.location_position.pos.clone(),
                });
            }
        }

        self.valid_destinations.shuffle();

        //
        CLOCK.time_stopped = true;
        self.canvas.set_alpha(0)

        SCREEN_FADER.fade_out(240, function() {
            array_push(GAME_STATS.bedtimes, clock_time_to_string(CLOCK.time));
            array_push(GAME_STATS.end_of_day_stats, {
                health: ARI.get_health(),
                stamina: ARI.get_stamina(),
            });

            ARI.end_of_day_sequence = true;

            //
            if CLOCK.time < hours(26) {
                var time_now = CLOCK.time;
                CLOCK.time = hours(26);
                npcs_time_jump(hours(26), time_now, true);
                Game.late_warning_issued = true;
            }

            //
            var buildings = get_buildings();
            for (var i = 0; i < buildings.count(); i++) {
                var building = buildings.get(i);
                if building.prototype.player_building_kind == PlayerBuildingKind.Stable {
                    building.stable.on_room_start();
                }
            }

            //
            //
            new_chain()
                .append(LinkId.Timer, 1)
                .append(LinkId.Function, SCREEN_FADER.fade_in, [FADE_SPEED_CUTSCENE]);


            var result = sell_shipping_bin_items();
            self.gold_earned = result.gold_earned;
            self.items_sold = result.items_sold;

            refresh_achievements([Requirement.EarnedGold]);

            self.renown_earned = ARI.pending_renown_entries.sum_with(renown_entry_value);

            //
            self.spawn_menu_nodes();

            //
            self.display_new_point_of_interest();
        });
    }

    function create_list_element() {
        var ui_element = self.scroller.new_element(22)
            .add_to_pilot(self.pilot, true)
            .listen_for_hovers()
            //

        var icon_node = item_node(ui_element)
            .set_xy(4, 2)
            .set_align(Align.LeftIn, Align.TopIn)
        var name = ANCHOR.text(ui_element)
            .set_align(Align.LeftIn, Align.Middle)
            .set_x(26)
            .set_lut(COMMON_LUT)
        var currency_icon_node = ANCHOR.sprite(ui_element)
            .set_align(Align.RightIn, Align.Middle)
            .set_x(-3)
            .set_lut(spr_ui_hud_font_currency_lut, 4)
        var currency_count_node = ANCHOR.text(currency_icon_node)
            .set_align(Align.LeftOut, Align.Middle)
            .set_x(-2)
            .set_sprite_font("currency")
            .set_lut(spr_ui_hud_font_currency_lut, 4)
        var count = ANCHOR.text(name)
            .set_align(Align.RightOut, Align.Middle)
            .set_xy(4, 1)
            .set_sprite_font("player_level")
            .set_lut(COMMON_LUT)

        return {
            ui_element: ui_element,
            icon_node: icon_node,
            name: name,
            currency_icon_node: currency_icon_node,
            currency_count_node: currency_count_node,
            count: count,
        }
    }

    function reset_scroller() {
        self.pilot.reset();
        if self.scroller != undefined {
            self.scroller.free();
        }
        self.scroller = create_scroller(
            self.receipt_backplate,
            Vec2(19, 46),
            Vec2(246, 102),
        );
        self.scroller.subscribe_to_pilot(self.pilot, 21, 19);
        self.scroller.outline
            .set_sprite(spr_ui_eod_summary_outline_box)
            .add_z(-50)
            .enable()
    }

    function build_receipt() {
        self.reset_scroller();

        var ui_element = self.scroller.new_element(22)
            .set_sprites_from_key("spr_ui_generic_box_header")
            .add_z(-1)

        ANCHOR.sprite(ui_element)
            .set_x(5)
            .set_align(Align.LeftIn, Align.Middle)
            .set_sprite(spr_ui_eod_summary_renown_header_icon)

        ANCHOR.text(ui_element)
            .set_align(Align.LeftIn, Align.Middle)
            .set_x(26)
            .set_lut(COMMON_LUT, CommonLutIndex.Header)
            .set_key("misc_local/renown_summary")

        if !ARI.pending_renown_entries.is_empty() {
            var gold_entries = ARI.pending_renown_entries
                .clone()
                .retain(function(v) {
                    return v.type == RenownEntryType.Gold;
                });

            var gold_renown = gold_entries.sum_with(renown_entry_value);

            if gold_renown != 0 {
                var nodes = self.create_list_element();
                nodes.icon_node.set_sprite(spr_ui_eod_summary_sold_items_icon);
                nodes.name.set_key("misc_local/sold_items");
                nodes.currency_icon_node.set_sprite(spr_ui_eod_summary_icon_renown);
                nodes.currency_count_node.set_text(gold_renown);
                nodes.count.set_text(fmt("x{}",
                    ListFromArray(self.items_sold.values()).sum_with(function(v) {
                        return v.count;
                    })
                ));
            }

            var quest_entries = ARI.pending_renown_entries
                .clone()
                .retain(function(v) {
                    return v.type == RenownEntryType.Quest;
                });

            var quest_renown = quest_entries.sum_with(renown_entry_value);

            if quest_renown != 0 {
                var nodes = self.create_list_element();
                nodes.icon_node.set_sprite(spr_ui_eod_summary_quests_icon);
                nodes.name.set_key("misc_local/completed_quests");
                nodes.currency_icon_node.set_sprite(spr_ui_eod_summary_icon_renown);
                nodes.currency_count_node.set_text(quest_renown);
                nodes.count.set_text(fmt("x{}", quest_entries.count()));
            }

            var museum_entries = ARI.pending_renown_entries
                .clone()
                .retain(function(v) {
                    return v.type == RenownEntryType.MuseumDonation;
                });

            var museum_renown = museum_entries.sum_with(renown_entry_value);

            if museum_renown != 0 {
                var nodes = self.create_list_element();
                nodes.icon_node.set_sprite(spr_ui_eod_summary_museum_donations_icon);
                nodes.name.set_key("misc_local/museum_donations");
                nodes.currency_icon_node.set_sprite(spr_ui_eod_summary_icon_renown);
                nodes.currency_count_node.set_text(museum_renown);
                nodes.count.set_text(fmt("x{}", museum_entries.count()));
            }

        } else {
            scroller_none_option(self.scroller);
        }

        var values = self.items_sold.values();

        var ui_element = self.scroller.new_element(22)
            .set_sprites_from_key("spr_ui_generic_box_header")
            .add_z(-1)

        ANCHOR.sprite(ui_element)
            .set_x(5)
            .set_align(Align.LeftIn, Align.Middle)
            .set_sprite(spr_ui_eod_summary_tesserae_header_icon)

        ANCHOR.text(ui_element)
            .set_align(Align.LeftIn, Align.Middle)
            .set_x(26)
            .set_lut(COMMON_LUT, CommonLutIndex.Header)
            .set_key("misc_local/sold_items_summary")

        if array_length(values) != 0 {
            var ordered = ListFromArray(values)
                .sort_with(function(a, b) {
                    return (b.live_item.bin_value() * b.count) - (a.live_item.bin_value() * a.count);
                });

            for (var i = 0; i < ordered.count(); i++) {
                var live_item = ordered.get(i).live_item;
                var item_count = ordered.get(i).count;
                var nodes = self.create_list_element();

                nodes.icon_node.set_to_item(live_item);
                nodes.name.set_text(live_item.get_display_name());
                nodes.currency_icon_node.set_sprite(spr_ui_hud_info_currency_icon);
                nodes.currency_count_node.set_text(live_item.bin_value() * item_count);
                nodes.count.set_text(fmt("x{}", item_count));

                nodes.name.set_max_width(164);
                nodes.name.update_display_text();
                var needed_height = nodes.name.get_height() + 8;
                self.scroller.add_height_to_element(nodes.ui_element, needed_height - nodes.ui_element.get_height())
            }
        } else {
            scroller_none_option(self.scroller);
        }

        ANCHOR.set_active_pilot(self.pilot);
    }

    //
    function spawn_menu_nodes() {

        self.fader = ANCHOR.nine_slice(self.canvas)
            .set_sprite(spr_pixel)
            .set_color(c_black)
            .lock()
            .set_size_to_screen()
            .set_alpha(0)

        self.receipt_backplate = ANCHOR.sprite(self.canvas)
            .set_align(Align.Center, Align.Middle)
            .set_sprite(spr_ui_eod_summary_backplate)

        var date = undefined;
        if local_get_info(LocalInfoRequest.DateOrder) == DateOrder.DayFirst {
            date = fmt(
                "{} {}, {} {}",
                local_get("misc_local/" + season_to_string(CALENDAR.season())),
                CALENDAR.day() + 1,
                local_get("misc_local/year"),
                CALENDAR.year() + 1,
            );
        } else {
               date = fmt(
                "{} {}, {} {}",
                local_get("misc_local/year"),
                CALENDAR.year() + 1,
                local_get("misc_local/" + season_to_string(CALENDAR.season())),
                CALENDAR.day() + 1,
            );
        }

        ANCHOR.text(self.receipt_backplate)
            .set_text(date)
            .set_align(Align.Center, Align.TopIn)
            .set_y(20)
            .set_lut(COMMON_LUT, CommonLutIndex.Header)

        self.build_receipt();

        self.receipt_backplate.set_enabled(self.gold_earned != 0 || self.renown_earned != 0);

        self.renown_box = ANCHOR.nine_slice(self.receipt_backplate)
            .set_sprite(spr_ui_eod_summary_rounded_text_box)
            .set_size(100, 18)
            .set_align(Align.RightIn, Align.BottomIn)
            .set_xy(-19, -35)

        self.gold_box = ANCHOR.nine_slice(self.renown_box)
            .set_sprite(spr_ui_eod_summary_rounded_text_box)
            .set_size(100, 18)
            .set_align(Align.Center, Align.BottomOut)
            .set_y(4)

        self.total = ANCHOR.text(self.renown_box)
            .set_key("misc_local/totals")
            .set_align(Align.LeftIn, Align.TopOut)
            .set_lut(COMMON_LUT)

        var icon = ANCHOR.sprite(self.renown_box)
            .set_align(Align.RightIn, Align.Middle)
            .set_sprite(spr_ui_eod_summary_icon_renown)
            .set_x(-5)

        ANCHOR.text(icon)
            .set_align(Align.LeftOut, Align.Middle)
            .set_xy(-2, 0)
            .set_text(self.renown_earned)
            .set_sprite_font("currency")
            .set_lut(spr_ui_hud_font_currency_lut, 4)

        var icon = ANCHOR.sprite(self.gold_box)
            .set_align(Align.RightIn, Align.Middle)
            .set_sprite(spr_ui_eod_summary_icon_tesserae)
            .set_x(-5)

        ANCHOR.text(icon)
            .set_align(Align.LeftOut, Align.Middle)
            .set_xy(-2, 0)
            .set_text(self.gold_earned)
            .set_sprite_font("currency")
            .set_lut(spr_ui_hud_font_currency_lut, 4)

        player_gold_prefab(self);
        self.gold_backplate.set_think_callback(function() {
            self.gold_backplate.set_alpha(1 - SCREEN_FADER.fade_alpha);
        })

        self.receipt_button = ANCHOR.nine_slice(self.canvas, self.receipt_backplate.get_z() - 10)
            .set_align(Align.LeftIn, Align.BottomIn)
            .set_size(74, 21)
            .set_xy(4, -4)
            .set_sprites_from_key("spr_ui_button_chunky")
            .add_glyph(InputId.MenuBack)
            .add_text_label("misc_local/summary", COMMON_LUT, CommonLutIndex.Dark)
            .set_tap_callback(function() {
                if !self.receipt_backplate.is_unlocked() {
                    self.receipt_backplate.set_enabled(true);
                    ANCHOR.set_active_pilot(self.pilot);
                } else {
                    self.receipt_backplate.set_enabled(false);
                    ANCHOR.release_active_pilot();
                }
            })

        self.receipt_button.text_label
            .set_xy(6, -1)

        ANCHOR.sprite(self.receipt_button)
            .set_sprites_from_key("spr_ui_eod_summary_button_icon")
            .set_key_sprite_target(self.receipt_button)
            .set_xy(6, 4)

        self.next_day_button = ANCHOR.nine_slice(self.canvas, self.receipt_backplate.get_z() - 10)
            .set_align(Align.RightIn, Align.BottomIn)
            .set_size(74, 21)
            .set_xy(-4, -4)
            .set_sprites_from_key("spr_ui_button_chunky_arrow")
            .add_glyph(InputId.Interact)
            .add_text_label("misc_local/next_day", COMMON_LUT, CommonLutIndex.Dark)
            .set_tap_callback(function() {
                self.receipt_button.lock();
                var chain;
                if self.renown_earned != 0 && renown_to_level(ARI.renown) < MAX_RENOWN_LEVEL {
                    chain = self.prep_for_sequence();
                    chain
                        .append(LinkId.Function, function() {
                            ANCHOR.spawn_menu(Menu.RenownSequence);
                        })
                        .append(LinkId.Await, function() {
                            return ANCHOR.get_menu(Menu.RenownSequence) == undefined;
                        });
                } else {
                    chain = self.prep_for_sequence();
                }
                add_rename_popups_to_chain(chain);
                chain.append(LinkId.Function, function() {
                    self.play_calendar_sequence();
                });
                self.next_day_button.lock();
            })

        self.next_day_button.text_label.set_xy(-1, -1);

        self.sequence_canvas = ANCHOR.canvas(ANCHOR.screen_canvas)
            .set_layer(AnchorLayer.AboveFader)
            .set_alpha(0)
            .set_align(Align.Center, Align.Middle)
            .set_size_to_screen();

        new_chain()
            .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 30), function(delta) {
                self.canvas.add_alpha(delta);
            })
    }

    //
    function set_calendar_time(time) {
        if self.calendar_number != undefined {
            ANCHOR.free_node(self.calendar_number);
            ANCHOR.free_node(self.calendar_day_name);
            ANCHOR.free_node(self.calendar_season);
        }
        self.calendar.set_sprite(string_to_asset(format("spr_ui_end_of_day_calendar_backplate_{Season}", get_seasons(time))));
        self.calendar_number = ANCHOR.text(self.calendar)
            .set_text(string(get_days(time) + 1))
            .set_sprite_font("giant_calendar")
            .set_align(Align.Center, Align.Middle)
            .set_lut(spr_ui_calendar_font_lut, get_seasons(time) + 1)
        self.calendar_day_name = ANCHOR.sprite(self.calendar)
            .set_sprite(string_to_asset(format("spr_ui_endoftheday_calendar_weekdays_{}", asset_local_insert())))
            .set_index((days(time) % Day.LEN) + 1)
            .set_align(Align.Center, Align.BottomIn)
            .set_y(-15)
            .set_lut(spr_ui_calendar_font_lut, get_seasons(time) + 1)
        self.calendar_season = ANCHOR.text(self.calendar)
            .set_align(Align.Center, Align.TopIn)
            .set_key("misc_local/" + season_to_string(get_seasons(time)))
            .set_lut(spr_ui_calendar_font_lut, get_seasons(time) + 1)
            .set_y(18)
    }

    //
    //
    function display_new_point_of_interest() {
        //
        //
        var farm = { location_id: LocationId.Farm, dyn_index: undefined, required_position: undefined };
        var target;
        if self.held_point_of_interest != undefined {
            target = {
                location_id: self.held_point_of_interest.location_id,
                dyn_index: self.held_point_of_interest.dyn_index,
                required_position: self.held_point_of_interest.pos,
            };
        } else if self.goto_special_destination == false {
            target = farm;

            self.goto_special_destination = !self.valid_destinations.is_empty() ;
        } else {
            //
            if self.destination_index >= self.valid_destinations.count() {
                self.valid_destinations.shuffle();
                self.destination_index = 0;
            }
            target = self.valid_destinations.get(self.destination_index);
            self.destination_index += 1;

            self.goto_special_destination = false;
        }
        //
        if CURRENT_LOCATION_ID != target.location_id {
            if target.dyn_index != undefined {
                goto_dynamic_location(target.dyn_index, true).no_player(true);
            } else {
                goto_location_id(target.location_id, true).no_player(true);
            }
        }

        //
        self.life_chain = new_chain()
            .join(LinkId.Await, function(target) {
                return CURRENT_LOCATION_ID == target.location_id;
            }, [target])
            .append(LinkId.Function, function(target) {
                if is_struct(target) && CURRENT_LOCATION_ID == LocationId.SmallGreenhouse || CURRENT_LOCATION_ID == LocationId.LargeGreenhouse {
                    tilemap_tileset(strict_layer_tilemap_get_id("Level_0_Walls"), target.tilesets[target.variant]);
                    tilemap_tileset(strict_layer_tilemap_get_id("Level_1_Ceiling"), target.tilesets[target.variant]);
                    tilemap_tileset(strict_layer_tilemap_get_id("Level_0_Floor_A"), target.tilesets[target.variant]);
                }
            }, [target])
            .append(LinkId.Function, function() {
                new_chain()
                    .append(LinkId.Ease, new Ease(EaseId.Linear, 1, 0, FADE_SPEED_CUTSCENE), function(_, a) {
                        self.fader.set_alpha(a);
                    })
                    .append(LinkId.Function, function() {
                        with obj_player_animal {
                            //
                            if CURRENT_LOCATION_ID == LocationId.Farm
                                && !self.can_update_location_position
                                && !self.me.liminal
                            {
                                instance_destroy();
                                continue;
                            }
                            self.eod_bark = 0;
                        }
                    });
            });

        //
        if target.location_id == LocationId.Farm && target.required_position == undefined {
            var pan_frames = (FARM_EXPANDED ? 32 : 23) * 60;
            self.life_chain
                .append(LinkId.Function, function(pan_frames) {
                    //
                    //
                    var ari_house_position = Vec2(732, 667);
                    var start_pos = Vec2Zero();
                    var target_pos = Vec2Zero();
                    var view_size = Vec2(CAMERA.view_width, CAMERA.view_height);

                    //
                    //
                    var pan_vector = Vec2Zero();
                    pan_vector.x = choose(-1, 0, 1);
                    if pan_vector.x == 0 {
                        pan_vector.y = choose(-1, 1);
                    } else {
                        pan_vector.y = choose(-1, 0, 1);
                    }
                    var room_bounds = Vec2(CAMERA.room_view_bound_width, CAMERA.room_view_bound_height);
                    switch pan_vector.x {
                        case -1:
                            start_pos.x = (room_bounds.x - view_size.x) + (view_size.x / 2) - CAMERA.x_buffer;
                            target_pos.x = (view_size.x / 2) + CAMERA.x_buffer;
                            break;
                        case 0:
                            start_pos.x = ari_house_position.x;
                            target_pos.x = start_pos.x;
                            break;
                        case 1:
                            start_pos.x = (view_size.x / 2) + CAMERA.x_buffer;
                            target_pos.x = (room_bounds.x - view_size.x) + (view_size.x / 2)  - CAMERA.x_buffer;
                            break;
                        default: impossible("Unexpected value: {}", pan_vector.x);
                    }
                    switch pan_vector.y {
                        case -1:
                            start_pos.y = (room_bounds.y - view_size.y) + (view_size.y / 2)  - CAMERA.y_buffer;
                            target_pos.y = (view_size.y / 2) + CAMERA.y_buffer;
                            break;
                        case 0:
                            start_pos.y = ari_house_position.y;
                            target_pos.y = start_pos.y
                            break;
                        case 1:
                            start_pos.y = (view_size.y / 2) + CAMERA.y_buffer;
                            target_pos.y = (room_bounds.y - view_size.y) + (view_size.y / 2) - CAMERA.y_buffer;
                            break;
                        default: impossible("Unexpected value: {}", pan_vector.y);
                    }

                    //
                    CAMERA.follow_point_instant(start_pos.x, start_pos.y);
                    CAMERA.pan(target_pos.x, target_pos.y, pan_frames, EaseId.Linear);
                }, [pan_frames])
                .append(LinkId.Timer, pan_frames - FADE_SPEED_CUTSCENE)
        } else {
            //
            self.life_chain
                .join(LinkId.Function, function(target) {
                    if target.required_position == undefined {
                        CAMERA.follow_point_instant(room_width() / 2, room_height() / 2);
                    } else {
                        CAMERA.follow_point_instant(target.required_position.x, target.required_position.y);
                    }
                }, [target])
                .join(LinkId.Timer, 12 * 60)
        }

        if self.held_point_of_interest != undefined {
            return;
        }

        self.life_chain
            .append(LinkId.Ease, new Ease(EaseId.Linear, 0, 1, FADE_SPEED_CUTSCENE), function(_, a) {
                self.fader.set_alpha(a);
            })
            .append(LinkId.Function, function() {
                self.display_new_point_of_interest();
            })
    }

    //
    //
    //
    //
    //
    //
    function prep_for_sequence() {
        if self.has_prepped {
            return new_chain();
        }

        if self.life_chain != undefined {
            CHAINS.cancel_chain(self.life_chain);
            self.life_chain = undefined;
        }

        //
        SCREEN_FADER.fade_out(FADE_SPEED_TRANSITION);

        self.has_prepped = true;

        MUSIC_PLAYER.stop();

        return new_chain()
            .append(LinkId.Await, function() {
                return SCREEN_FADER.is_out();
            })
            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 30), function(_, a) {
                self.sequence_canvas.set_alpha(a);
            })
    }

    //
    function play_calendar_sequence() {
        self.calendar = ANCHOR.sprite(self.sequence_canvas)
            .set_sprite(string_to_asset(format("spr_ui_end_of_day_calendar_backplate_{Season}", CALENDAR.season())))
            .set_align(Align.Center, Align.Middle)

        //
        var target_date = CALENDAR.time + days(1);
        self.events = List();
        for (var i = 0; i < FestivalId.LEN; i++) {
            if
                get_seasons(target_date) == FESTIVALS[i].prototype.date.season
                && get_days(target_date) == FESTIVALS[i].prototype.date.day - 1
                && FESTIVALS[i].prototype.implemented
            {
                self.events.push({
                    type: CalendarEvent.Festival,
                    festival: i,
                });
            }
        }
        var day = get_days(target_date) % Day.LEN;

        if day == Day.Friday {
            self.events.push({
                type: CalendarEvent.FridayNights,
            });
        }

        if day == Day.Saturday && requirements_pass(Requirement.SaturdayMarketUnlocked) {
            self.events.push({
                type: CalendarEvent.SaturdayMarket,
            });
        }

        if array_contains(ELIGIBLE_DATE_DAYS, day) && array_contains(npc_date_eligibility(target_date), true) {
            self.events.push({
                type: CalendarEvent.DateAvailable,
            })
        }

        if ARI.wedding_date != undefined
            && get_seasons(target_date) == get_seasons(ARI.wedding_date)
            && get_days(target_date) == get_days(ARI.wedding_date)
        {
            self.events.push({
                type: CalendarEvent.Wedding,
                is_anniversary: get_years(target_date) != get_years(ARI.wedding_date),
            });
        }

        for (var i = 0; i < array_length(ARI.children); i++) {
            var child = ARI.children[i];
            //
            if get_seasons(target_date) == get_seasons(child.birthday)
                && get_days(target_date) == get_days(child.birthday)
                && get_years(target_date) > get_years(child.birthday)
            {
                self.events.push({
                    type: CalendarEvent.ChildBirthday,
                    child,
                });
            }
        }

        for (var i = 0; i < NpcId.LEN; i++) {
            var npc = NPCS[i];
            if
                npc.has_met()
                && get_days(target_date) == npc.prototype.birthday.day - 1
                && get_seasons(target_date) == npc.prototype.birthday.season
                && npc_is_unlocked(i)
            {
                self.events.push({
                    type: CalendarEvent.NpcBirthday,
                    npc: i,
                });
            }
        }
        if
            get_seasons(target_date) == get_seasons(ARI.birthday)
            && get_days(target_date) == get_days(ARI.birthday)
            {
                self.events.push({
                    type: CalendarEvent.AriBirthday,
                });
            }

        //
        var weather = weather_tomorrow();
        var season = get_seasons(target_date);
        var passes = ARI.perk_active(Perk.Legendary) && !ARI.legendary_fish_caught[season];
        switch season {
            case Season.Spring:
            case Season.Fall:
                passes &= weather == Weather.Special;
                break;
            case Season.Summer:
            case Season.Winter:
                passes &= weather == Weather.HeavyInclement;
                break;
        }

        if passes {
            var icon = undefined;
            switch get_seasons(target_date) {
                case Season.Spring:
                    icon = spr_ui_eod_legendary_fish_icon_cherry_fish;
                    break;
                case Season.Summer:
                    icon = spr_ui_eod_legendary_fish_icon_lightning_fish;
                    break;
                case Season.Fall:
                    icon = spr_ui_eod_legendary_fish_icon_leaf_fish;
                    break;
                case Season.Winter:
                    icon = spr_ui_eod_legendary_fish_icon_snow_fish;
                    break;
            }
            self.events.push({
                type: CalendarEvent.LegendaryFish,
                icon,
            })
        }

        self.set_calendar_time(CALENDAR.time);

        self.build_notifications(target_date);

        var chain = self.prep_for_sequence()
            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, FADE_SPEED), function(_, a) {
                self.calendar.set_alpha(a);
            })
            .append(LinkId.Timer, 60)
            .append(LinkId.Function, function() {
                TANGO.play("SoundEffects/UI/CalendarTickOver");
            })
            .append(LinkId.Ease, new Ease(EaseId.BackIn, 0, 20, 15), function(delta) {
                self.calendar.add_y(delta);
            })
            .append(LinkId.Ease, new Ease(EaseId.Linear, 0, -20, 4), function(delta) {
                self.calendar.add_y(delta);
            })
            .append(LinkId.Function, function() {
                set_rumble(RumbleKind.BuildingComplete);
                self.set_calendar_time(CALENDAR.time + days(1));
            })
            .append(LinkId.Timer, 30)

        if !self.events.is_empty() {
            chain
                .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, FADE_SPEED), function(delta) {
                    self.notification_root.add_alpha(delta);
                })
                .append(LinkId.Timer, 120)
        }

        chain
            .append(LinkId.Timer, 90)
            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, FADE_SPEED), function(delta) {
                self.sequence_canvas.add_alpha(delta);
            })
            .append(LinkId.Function, function() {
                self.end_sequence();
            })
    }

    function build_notifications(target_date) {
        var yy = 0;
        self.notification_root = ANCHOR.positional(self.calendar)
            .set_align(Align.Center, Align.BottomOut)
            .set_xy(6, 6)
            .set_alpha(0);
        for (var i = 0; i < self.events.count(); i++) {
            var event = self.events.get(i);
            var icon = undefined;
            var key = undefined;
            var npcs = undefined;
            switch event.type {
                case CalendarEvent.SaturdayMarket:
                    icon = spr_ui_calendar_icon_event_saturday_market;
                    key = "misc_local/saturday_market";
                    npcs = SATURDAY_MARKET.eligible_vendors();
                    break;
                case CalendarEvent.DateAvailable:
                    icon = spr_ui_journal_quests_heart_subicon;
                    key = "misc_local/date_available";
                    npcs = npc_date_eligibility(target_date);
                    break;
                case CalendarEvent.FridayNights:
                    icon = spr_ui_calendar_icon_event_friday_night_at_the_inn;
                    key = "misc_local/friday_night_at_the_inn";
                    break;
                case CalendarEvent.NpcBirthday:
                    icon = get_npc_icon(event.npc);
                    key = ANCHOR.wrap_for_local(
                        format(
                            local_get("misc_local/birthday_template"),
                            local_get(NPC_PROTOTYPES[event.npc].name),
                        )
                    );
                    break;
                case CalendarEvent.AriBirthday:
                    icon = spr_ui_generic_birthday_icon;
                    key = "misc_local/your_birthday";
                    break;
                case CalendarEvent.LegendaryFish:
                    icon = event.icon;
                    key = "misc_local/legendary_fish_nearby";
                    break;
                case CalendarEvent.Festival:
                    icon = FESTIVALS[event.festival].prototype.icon;
                    key = FESTIVALS[event.festival].prototype.name;
                    break;
                case CalendarEvent.Wedding:
                    icon = spr_ui_calendar_icon_event_wedding;
                    key = event.is_anniversary
                        ? "misc_local/your_anniversary"
                        : "misc_local/your_wedding";
                    break;
                case CalendarEvent.ChildBirthday:
                    icon = event.child.get_small_icon();
                    key = ANCHOR.wrap_for_local(
                        format(
                            local_get("misc_local/birthday_template"),
                            event.child.name,
                        )
                    );
                    break;
            }


            var text = ANCHOR.text(self.notification_root)
                .set_align(Align.Center, Align.TopIn)
                .set_y(yy)
                .set_key(key)

            var icon = ANCHOR.sprite(text)
                .set_sprite(icon)
                .set_align(Align.LeftOut, Align.Middle)
                .set_x(-2)

            if npcs != undefined {
                var underline = ANCHOR.nine_slice(text)
                    .set_align(Align.RightIn, Align.BottomOut)
                    .set_sprite(spr_pixel_nine_slice)
                    .set_size(text.get_width() + 2 + icon.get_width(), 1)

                var those_to_show = [];
                for (var j = 0; j < NpcId.LEN; j++) {
                    if npcs[j] {
                        array_push(those_to_show, j);
                    }
                }

                var icon_positions = centered_positions(array_length(those_to_show), 11, 3);
                for (var j = 0; j < array_length(those_to_show); j++) {
                    ANCHOR.sprite(underline)
                        .set_sprite(get_small_outlined_npc_icon(those_to_show[j]))
                        .set_xy(icon_positions[j], 2)
                        .set_align(Align.Center, Align.BottomOut)
                }
            }

            yy += text.get_height() + (npcs == undefined ? 6 : 20);
        }

        self.calendar.add_y(-yy / 2);
    }

    //
    function end_sequence() {
        LOAD_SEQUENCE.start(
            "misc_local/saving",
            function() {
                with par_animal {
                    instance_destroy();
                }

                new_day();
                CLOCK.time_stopped = true; //

                var path = exact_save_path(Game.unique_identifier, false);
                ARI.save_position = player_wake_position();
                save_game(path);

                self.close();
                create_save_notification(function() {
                    ARI.end_of_day_sequence = false;
                    LEAVING_EOD = true;
                    goto_location_id(ARI.save_position.location_id, true)
                        .set_exact_position(ARI.save_position.pos.x, ARI.save_position.pos.y)
                        .set_arrival_callback(function() {
                            CLOCK.time_stopped = false;
                            LEAVING_EOD = false;
                            wake_up_sequence();
                        });
                    LOAD_SEQUENCE.finish();
                    TANGO.play("SoundEffects/Animals/HaydensRooster");
                });
                return false;
            },
            [],
            FADE_SPEED_TRANSITION,
        );
    }
}

function sell_shipping_bin_items() {
    //
    var items = List();
    var items_sold = Map();

    //
    var bins = shipping_bins();
    for (var i = 0; i < bins.count(); i++) {
        var bin = bins.get(i);

        items.transfer(bin.inventory.drain());
    }

    var gold_earned = 0;
    for (var i = 0; i < items.count(); i++) {
        var live_item = items.get(i);

        //
        gold_earned += live_item.bin_value();

        ARI.items_sold[live_item.item_id] += 1;

        //
        var key = live_item.pretty_print();
        if items_sold.contains_key(key) {
            items_sold.get(key).count += 1;
        } else {
            items_sold.insert(key, {
                live_item: live_item,
                count: 1,
            })
        }
    }
    ARI.modify_gold(gold_earned);
    array_push(GAME_STATS.end_of_day_balance, {
        balance: ARI.get_gold(),
        day: total_days(),
    });
    array_push(GAME_STATS.income, {
        type: "sold_items",
        amount: gold_earned,
        day: total_days(),
    });
    var sold = [];
    var values = items_sold.values();
    for (var i = 0; i < array_length(values); i++) {
        array_push(sold, {
            item: values[i].live_item.pretty_print(),
            count: values[i].count,
            income: values[i].live_item.bin_value() * values[i].count,
        });
    }
    array_push(GAME_STATS.items_sold_each_day, sold);

    //
    if gold_earned != 0 {
        ARI.pending_renown_entries.push(RenownEntry.Gold(gold_earned));
    }

    return {
        gold_earned,
        items_sold,
    };
}

enum CalendarEvent {
    Festival,
    NpcBirthday,
    SaturdayMarket,
    FridayNights,
    AriBirthday,
    LegendaryFish,
    DateAvailable,
    Wedding,
    ChildBirthday,
    LEN,
}
