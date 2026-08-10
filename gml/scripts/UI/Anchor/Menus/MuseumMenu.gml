function MuseumMenu() : AnchorMenu(Menu.Museum) constructor {

    function enter_wing_selection(wing_to_hover) {
        if self.close_requested {
            return;
        }

        ANCHOR.free_children(self.root);
        self.left_page.disable();
        self.right_page.disable();
        self.title.set_key("misc_local/the_museum");
        self.wing_pilot.reset();

        var tile_width = sprite_get_width(spr_ui_museum_fish_wing_button_default);
        var tile_height = sprite_get_width(spr_ui_museum_fish_wing_button_default);
        var horz_layout = centered_positions(2, tile_width, 46);
        var vert_layout = centered_positions(2, tile_height, 24);
        var y_offset = 6;
        for (var i = 0; i < array_length(self.data.wings); i++) {
            var wing_data = self.data.wings[i];
            var wing_key = string_to_museum_wing(wing_data.wing);
            var wing = MUSEUM_DATA.data[wing_key];

            var tile = ANCHOR.sprite(self.root)
                .set_sprites_from_key(wing_data.icon_key)
                .set_xy(horz_layout[i % 2], vert_layout[i div 2] + y_offset)
                .set_align(Align.Center, Align.Middle)
                .add_to_pilot(self.wing_pilot, i % 2 == 1)

            var bubble = ANCHOR.nine_slice(tile)
                .set_sprite(spr_ui_museum_wing_name_bubble)
                .set_align(Align.Center, Align.TopOut)
                .set_size(82, 20)
                .set_y(-4)
                .add_text_label(wing.name, spr_ui_museum_font_lut, 2)
                .disable()

            ANCHOR.sprite(bubble)
                .set_align(Align.Center, Align.BottomOut)
                .set_y(-1)
                .set_sprite(spr_ui_museum_wing_name_bubble_arrow)

            //
            var completion = {
                acquired: 0,
                total: 0,
            };
            var set_keys = wing.sets.keys();
            for (var j = 0; j < array_length(set_keys); j++) {
                var set_key = set_keys[j];
                completion.total += museum_set_size(wing_key, set_key);
                completion.acquired += museum_set_progress(wing_key, set_key);
            }

            var percent = floor(completion.acquired / completion.total * 100);
            var x_off = -sprite_get_width(spr_ui_museum_percent_symbol) / 2;
            var percent = ANCHOR.text(tile)
                .set_text(percent)
                .set_lut(spr_ui_museum_font_lut, 2)
                .set_align(Align.Center, Align.BottomOut)
                .set_sprite_font("player_level")
                .set_xy(x_off, 2)

            ANCHOR.sprite(percent)
                .set_sprite(spr_ui_museum_percent_symbol)
                .set_align(Align.RightOut, Align.Middle)

            tile
                .set_tap_callback(function(wing_key) {
                    self.lock();
                    CHAINS.new_chain()
                        .append(LinkId.Ease, new Ease(EaseId.QuadIn, 1, 0, FADE_SPEED), function(_, a) {
                            self.root.set_alpha(a);
                        })
                        .append(LinkId.Function, function(wing_key) {
                            self.enter_wing(wing_key);
                            self.canvas.board_set("selected_wing", wing_key);
                        }, [wing_key])
                        .append(LinkId.Ease, new Ease(EaseId.QuadIn, 0, 1, FADE_SPEED), function(_, a) {
                            self.left_page.set_alpha(a);
                            self.right_page.set_alpha(a);
                        })
                        .append(LinkId.Function, function() {
                            self.unlock();
                        })
                }, [wing_key])
                .set_think_callback(function(tile, bubble) {
                    bubble.set_enabled(tile.is_hovered())
                }, [tile, bubble])

            if wing_to_hover == wing_key {
                self.wing_pilot.force_select(tile);
            }
        }

        ANCHOR.set_active_pilot(self.wing_pilot);
    }

    function enter_wing(wing_key) {
        if self.close_requested {
            return;
        }

        ANCHOR.free_children(self.root);
        ANCHOR.free_children(self.left_header);
        ANCHOR.free_children(self.left_body);
        ANCHOR.free_children(self.right_body);

        self.left_page.enable();
        self.right_page.enable();
        self.set_pilot.reset();

        var wing = MUSEUM_DATA.data[wing_key];
        self.title.set_key(wing.name);

        var set_title = title_for_journal("misc_local/placeholder", self.left_header)
            .set_lut(spr_ui_museum_font_lut, 3)

        var description_box = ANCHOR.positional(self.left_body)
            .set_align(Align.Center, Align.TopIn)
            .set_size(159, 70)

        self.description = ANCHOR.text(description_box)
            .set_lut(spr_ui_museum_font_lut, 4)
            .set_xy(3, 3)
            .allow_line_breaks()
            .prevent_spillover()

        //
        //
        if local_language() == "jpn" {
            self.description.set_required_padding(2);
            self.description.set_x(2);
        }

        var reward_title = ANCHOR.text(self.left_header)
            .set_key("misc_local/next_reward")
            .set_align(Align.Center, Align.Middle)
            .set_y(90)
            .set_lut(spr_ui_museum_font_lut, 5)

        var reward_box = ANCHOR.positional(self.left_body)
            .set_align(Align.Center, Align.BottomIn)
            .set_size(159, 70)

        var scroller = create_scroller(self.right_body);
        scroller.set_lut(spr_ui_museum_scroll_lut);
        //
        scroller.subscribe_to_pilot(self.set_pilot);
        var order = self.data[$ format("{MuseumWing}_order", wing_key)];
        var completed_sets = 0;
        for (var i = 0; i < array_length(order); i++) {
            var set_key = order[i];
            var progress = museum_set_progress(wing_key, set_key);
            var set_size = museum_set_size(wing_key, set_key);
            var is_complete = progress == set_size && set_size != 0;

            var set = wing.sets.get(set_key);
            var element = scroller.new_element(43)
                .add_to_pilot(self.set_pilot, true)
                .set_selected_getter(function(set_key) {
                    return self.set_selected == set_key;
                }, [set_key])
                .set_tap_callback(function(set, set_key, set_title, description) {
                    set_title.set_key(set.display_name);
                    description.set_key(set.description);
                    self.set_selected = set_key;
                }, [set, set_key, set_title, description])

            var label_lut = spr_ui_museum_set_incomplete_font_lut;
            var element_sprite_key = "spr_ui_museum_box_incomplete";
            if is_complete {
                completed_sets += 1;
                label_lut = spr_ui_museum_set_complete_font_lut;
                element_sprite_key = "spr_ui_museum_box_complete";
            }

            element.set_sprites_from_key(element_sprite_key);
            element.add_text_label(set.display_name, label_lut, 1, 3, 1, 3, 3);
            element.text_label
                .set_align(Align.LeftIn, Align.TopIn)
                .set_xy(3, 2)

            var items = ListFromArray(
                array_map(set.items, function (e) {
                    return new LiveItem(e)
                })
            );
            items.sort_with(function(a, b) {
                return string_alphanumeric_comparison(a.get_display_name(), b.get_display_name());
            });
            var xx = 6;
            var yy = 18;
            for (var j = 0; j < items.count(); j++) {
                var item = items.get(j);
                ANCHOR.sprite(element)
                    .set_sprite(item.get_ui_icon())
                    .set_xy(xx, yy)
                    .set_color(MUSEUM_PROGRESS[item.item_id] ? c_white : MUSEUM_LOCKED_OVERLAY)

                xx += 20;
            }

            var percent_sprites = undefined;
            if set_size == 5 {
                percent_sprites = [
                    spr_ui_museum_set_progress_0,
                    spr_ui_museum_set_progress_20,
                    spr_ui_museum_set_progress_40,
                    spr_ui_museum_set_progress_60,
                    spr_ui_museum_set_progress_80,
                    spr_ui_museum_set_progress_100,
                ];
            } else {
                percent_sprites = [
                    spr_ui_museum_set_progress_0,
                    spr_ui_museum_set_progress_25,
                    spr_ui_museum_set_progress_50,
                    spr_ui_museum_set_progress_75,
                    spr_ui_museum_set_progress_100,
                ];
            }

            var count = array_length(percent_sprites);

            if progress == 0 {
                var index = 0;
            } else {
                var index = min(
                    floor(progress / set_size * count),
                    count - 1,
                );
            }

            ANCHOR.sprite(element)
                .set_align(Align.RightIn, Align.TopIn)
                .set_sprite(percent_sprites[index])
                .set_xy(-4, yy)

            if i == 0 {
                set_title.set_key(set.display_name);
                description.set_key(set.description);
                self.set_selected = set_key;
            }
        }

        //
        var next_reward = wing.rewards.try_get(completed_sets);
        if next_reward != undefined {
            ANCHOR.sprite(reward_box)
                .set_sprite(next_reward.preview_sprite ?? spr_illegal_16)
                .set_align(Align.Center, Align.Middle)
                .set_speed(1)
        } else {
            reward_title.disable();
        }

        ANCHOR.set_active_pilot(self.set_pilot);
    }

    create_journal_nodes(self.canvas, self);

    //
    self.book.set_sprite(spr_ui_museum_background_plate);
    self.left_page.set_sprite(spr_ui_museum_page_layout_left);
    self.right_page.set_sprite(spr_ui_museum_page_layout_right);
    self.left_body
        .set_size(159, 159)
        .add_x(21)
        .add_y(11)
    self.right_body
        .set_size(158, 177)
        .add_x(-21)
        .add_y(-7)
    self.left_header
        .add_x(20)
        .add_y(15)
        .set_size(159, 17)

    self.set_selected = undefined;

    self.wing_pilot = self.new_pilot();

    self.set_pilot = self.new_pilot()
        .allow_vertical_wrapping();

    self.canvas.set_think_callback(function() {
        //
        //
        //
        //
        if self.canvas.is_unlocked() && self.left_page.get_enabled() && INPUT.take_press(InputId.MenuBack) {
            TANGO.play("SoundEffects/UI/UIPopDown");
            self.lock();
            CHAINS.new_chain()
                .append(LinkId.Ease, new Ease(EaseId.QuadIn, 1, 0, FADE_SPEED), function(_, a) {
                    self.left_page.set_alpha(a);
                    self.right_page.set_alpha(a);
                })
                .append(LinkId.Function, function() {
                    ANCHOR.free_children(self.left_header);
                    ANCHOR.free_children(self.left_body);
                    ANCHOR.free_children(self.right_body);
                    self.enter_wing_selection(self.canvas.board_get("selected_wing"));
                })
                .append(LinkId.Ease, new Ease(EaseId.QuadIn, 0, 1, FADE_SPEED), function(_, a) {
                    self.root.set_alpha(a);
                })
                .append(LinkId.Function, function() {
                    self.unlock();
                })
        }
    })

    self.root = ANCHOR.positional(self.book)
        .set_size(self.book.get_size())
        .set_align(Align.Center, Align.Middle)

    self.title = ANCHOR.text(self.book)
        .set_lut(spr_ui_museum_font_lut, 1)
        .set_align(Align.Center, Align.TopIn)
        .set_y(12)

    self.enter_wing_selection();
}

#macro MUSEUM_LOCKED_OVERLAY $2a2a2a

//
function test_museum_wing_ui_registration() {
    for (var i = 0; i < MuseumWing.LEN; i++) {
        var order = fiddle_get(format(
            "ui/menus/standard_menus/museum/{MuseumWing}_order",
            i,
        ));
        var hash = HashSetFromArray(MUSEUM_DATA.data[i].sets.keys());
        for (var j = 0; j < array_length(order); j++) {
            if hash.contains(order[j]) {
                hash.remove(order[j]);
            } else {
                crash("Invalid set for {MuseumWing}: {}", i, order[j]);
            }
        }
        assert(hash.is_empty(), "The following sets are not registered to the UI: {}", hash);
    }
}
