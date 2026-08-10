function AlmanacMenu() : AnchorMenu(Menu.Almanac) constructor {
    //
    function create_category(data) {
        var local_key = data[$ "local_key"] ?? "misc_local/" + data.key;
        var icon = data[$ "icon_sprite"] != undefined
            ? string_to_asset(data.icon_sprite)
            : string_to_asset(fmt("spr_ui_journal_almanac_icon_{}", data.key));

        //
        //
        var seen_keys = HashSet();
        var item_list = List();
        var tags = ListFromArray(data.tags);
        for (var i = 0; i < ItemId.LEN; i++) {
            var proto = ITEM_PROTOTYPES[i];
            if !seen_keys.contains(proto.recipe_key) && proto.tags.contains_any_value_from(tags) {
                seen_keys.insert(proto.recipe_key);
                item_list.push(i);
            }
        }

        item_list.sort_with(function(e1, e2) {
            return string_alphanumeric_comparison(
                local_get(ITEM_PROTOTYPES[e1].name_key),
                local_get(ITEM_PROTOTYPES[e2].name_key),
            );
        });

        var items_acquired = item_list.sum_with(function(item_id) {
            return ARI.items_acquired[item_id];
        });

        var element = self.category_scroller.new_element()
            .add_text_label(local_key)
            .add_to_pilot(self.left_pilot, true)
            .set_tap_callback(function(item_list, data, icon, local_key) {
                self.open_item_list(item_list, icon, local_key);
                self.active_page = data.key;
            }, [item_list, data, icon, local_key])
            .set_selected_getter(function(key) {
                return self.active_page == key;
            }, [data.key]);

        element.text_label
            .set_align(Align.LeftIn, Align.TopIn)
            .set_xy(21, 3)

        var icon = ANCHOR.sprite(element.text_label)
            .set_sprite(icon)
            .set_align(Align.LeftOut, Align.Middle)
            .set_x(-4)

        ANCHOR.text(element)
            .set_sprite_font("player_level")
            .set_text(fmt("{}/{}", items_acquired, item_list.count()))
            .set_xy(21, 20)
            .mirror_node_lut(element.text_label)

        return element;
    }

    //
    function open_item_list(list, icon, title) {
        if self.item_scroller != undefined {
            self.item_scroller.free();
        }
        self.item_scroller = create_scroller(self.journal.right_full_body)
            .subscribe_to_pilot(self.right_pilot);
        if self.tooltip != undefined {
            self.tooltip.close();
            self.tooltip = undefined;
        }
        self.right_pilot.reset();

        var element = self.item_scroller.new_element();
        self.item_scroller.add_height_to_element(element, 23);

        var icon_node = ANCHOR.sprite(element)
            .set_sprite(icon)
            .set_xy(5, 9)

        ANCHOR.text(icon_node)
            .set_lut(COMMON_LUT)
            .set_key(title)
            .set_align(Align.RightOut, Align.Middle)
            .set_x(3)

        var base_x = 3;
        var base_y = 27;
        var horz_spacing = 2;
        var vert_spacing = 2;
        var i = 0;
        var j = 0;
        for (var iter = 0; iter < list.count(); iter++) {
            if i == 6 {
                i = 0;
                j += 1;
                self.item_scroller.add_height_to_element(element, 27);
                self.right_pilot.request_newline();
            }
            var item_id = list.get(iter);
            var acquired = ARI.items_acquired[item_id];
            var xx = base_x + (24 + horz_spacing) * i;
            var yy = base_y + (24 + vert_spacing) * j;
            var square = common_slice(element, 24, 24)
                .set_xy(xx, yy)
                .board_set("hover_timer", 0)
                .listen_for_hovers()
                .add_to_pilot(self.right_pilot)

            ANCHOR.sprite(square)
                .set_sprite(acquired ? ITEM_PROTOTYPES[item_id].icon_sprite : spr_ui_generic_lock_icon)
                .set_align(Align.Center, Align.Middle)

            if acquired {
                square.set_think_callback(function(square, item_id) {
                    //
                    if square.hover_duration() >= 30 {
                        if self.tooltip == undefined {
                            self.tooltip = create_tooltip(item_id, square);
                        }
                    } else if self.tooltip != undefined && self.tooltip.source_node == square {
                        self.tooltip.close();
                        self.tooltip = undefined;
                    }
                }, [square, item_id, acquired])
            }
            i += 1;
        }
        ANCHOR.set_active_pilot(self.right_pilot);
    }

    self.active_page = undefined;

    self.journal = ANCHOR.get_menu(Menu.Journal);
    self.journal.left_page.set_sprite(spr_ui_journal_book_page_layout_almanac_left);
    self.journal.right_page.set_sprite(spr_ui_journal_book_page_layout_almanac_right);

    self.title = title_for_journal("misc_local/the_almanac", self.journal.left_header, spr_ui_journal_almanac_header_icon)
        .set_think_callback(function() {
            var directional_in_page = self.active_page != undefined && ANCHOR.in_directional_control();
            self.category_scroller.canvas.set_alpha(!directional_in_page ? 1 : UI_FADE_ALPHA);
            if directional_in_page {
                GLYPH_GUIDE.set_input(InputId.MenuBack, "misc_local/back");
                if INPUT.take_press(InputId.MenuBack) {
                    self.item_scroller.free();
                    self.right_pilot.reset();
                    self.active_page = undefined;
                    ANCHOR.set_active_pilot(self.left_pilot);
                }
            }
        }, [])

    self.left_pilot = self.new_pilot()
        .allow_vertical_wrapping();
    self.right_pilot = self.new_pilot()
        .allow_vertical_wrapping()
        .allow_horizontal_wrapping();

    self.category_scroller = create_scroller(self.journal.left_body)
        .subscribe_to_pilot(self.left_pilot);

    self.item_scroller = undefined;

    self.tooltip = undefined;

    self.categories = List();
    for (var i = 0; i < array_length(self.data.categories); i++) {
        self.categories.push(
            self.create_category(self.data.categories[i])
        );
    }

    ANCHOR.set_active_pilot(self.left_pilot);
}
