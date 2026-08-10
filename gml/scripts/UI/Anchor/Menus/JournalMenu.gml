function JournalMenu() : AnchorMenu(Menu.Journal) constructor {
    self.sub_menu = undefined;

    function on_close() {
        if self.sub_menu != undefined {
            self.sub_menu.close();
        }
    }

    //
    function reset() {
        ANCHOR.free_children(self.canvas);
        if self.sub_menu != undefined {
            self.sub_menu.close();
        }
        self.initialize();
    }

    //
    function initialize() {
        create_journal_nodes(self.canvas, self);

        self.tabs = Map();
        self.page_order = List();
        var pages = fiddle_get("ui/journal_pages/pages");
        static BASE_Y = 14;
        static INC = 23;
        for (var i = 0; i < array_length(pages); i++) {
            var menu = string_to_menu(pages[i].menu);
            var key = pages[i].tab_sprite_key;
            self.page_order.push(menu);
            var yy = (INC * i) + BASE_Y;
            var node = ANCHOR.sprite(self.book);
            self.tabs.set(
                menu,
                node
                    .set_position(6, yy, JournalDepth.SelectedTab)
                    .set_align(Align.RightIn, Align.TopIn)
                    .set_bbox_offset(0, 1, 0, -1)
                    .set_sprites_from_key(key)
                    .board_set("default_sprite_key", key)
                    .board_set("selected_sprite_key", format("{}_selected", key))
                    .set_tap_callback(function(menu) {
                        if self.sub_menu.type != menu {
                            self.set_active_sub_menu(menu);
                        }
                    }, [menu])
            );
        }

        self.check_for_cosmetic_alert();
    }

    //
    function set_active_sub_menu(menu) {
        self.reset();
        //
        if menu == Menu.QuestLog {
            self.sub_menu = ANCHOR.spawn_menu(menu, self, QuestLogContext.Journal);
        } else if Menu.Customization {
            self.sub_menu = ANCHOR.spawn_menu(menu, self, ARI);
        } else {
            self.sub_menu = ANCHOR.spawn_menu(menu);
        }

        var keys = self.tabs.keys();
        for (var i = 0; i < array_length(keys); i++) {
            var this_tab_menu = keys[i];
            var tab = self.tabs.get(this_tab_menu);
            tab.set_sprites_from_key(menu == real(this_tab_menu)
                ? tab.board_get("selected_sprite_key")
                : tab.board_get("default_sprite_key")
            );
        }

        //
        //
        //
        if SETTINGS.get("menu_bounce") {
            self.book.add_y(1);
            new_chain().join(LinkId.Ease, new Ease(EaseId.Linear, 1, 0, 10), function (delta) {
                self.book.add_y(delta);
            })
        }
    }

    //
    function check_for_cosmetic_alert() {
        if is_menu_room(room()) {
            return;
        }

        var any = false;
        var unlocked = ARI.cosmetic_unlocks.keys();
        for (var i = 0; i < array_length(unlocked); i++) {
            if !ARI.seen_cosmetics.contains(unlocked[i]) {
                any = true;
                break;
            }
        }

        if !any {
            return;
        }

        var alert = ANCHOR.sprite(self.tabs.get(Menu.Customization))
            .set_sprite(spr_ui_journal_customization_new_unlock_icon_flashy)
            .set_align(Align.RightIn, Align.TopIn)
            .set_xy(2, -2)
            .set_speed(1)

        alert.set_think_callback(function(alert) {
            if self.sub_menu.type == Menu.Customization {
                ANCHOR.free_node(alert);
            }
        }, [alert])
    }

    self.canvas.set_think_callback(function() {
        if self.close_requested {
            return;
        }

        //
        var modifier = INPUT.pressed(InputId.MenuTabRight) - INPUT.pressed(InputId.MenuTabLeft);
        if modifier != 0 {
            var index = wrap(
                self.page_order.find_lazy(self.sub_menu.type) + modifier,
                self.page_order.count()
            );
            TANGO.play("SoundEffects/UI/UIJournalTabSwitch");
            var page = self.page_order.get(index);
            self.set_active_sub_menu(page);
        }

        if INPUT.take_press(InputId.OpenMapMenu) {
            if ANCHOR.get_menu(Menu.Map) != undefined {
                self.close();
            } else {
                self.set_active_sub_menu(Menu.Map);
            }
        }

        //
        //
        var settings = ANCHOR.get_menu(Menu.Settings);
        var ignore = settings != undefined && settings.active_page == "controls";

        if !ignore && INPUT.take_press(InputId.OpenJournal) {
            self.close();
        }
    });

    self.tabs = undefined;
    self.page_order = undefined;
    self.initialize();
}

//
//
//
function title_for_journal(local_key, header, icon_sprite) {
    var title = ANCHOR.text(header)
        .set_align(Align.Center, Align.Middle)
        .set_key(local_key)
        .prevent_spillover()
        .set_lut(COMMON_LUT, CommonLutIndex.Header);

    //

    if icon_sprite != undefined {
        title.board_set(
            "icon",
            ANCHOR.sprite(header)
                .set_sprite(icon_sprite)
                .set_align(Align.LeftIn, Align.Middle)
                .set_x(3)
        );
    }

    return title;
}

//
//
//
//
//
//
//
//
function create_journal_nodes(canvas, target) {
    static DATA = MENUS.get(Menu.Journal);
    static PAGE_OFFSET = array_to_vec2(DATA.page_offset);
    static PAGE_SIZE = array_to_vec2(DATA.page_size);
    static HEADER_SIZE = array_to_vec2(DATA.header_size);
    static HEADER_OFFSET = array_to_vec2(DATA.header_offset);
    static BODY_SIZE = array_to_vec2(DATA.body_size);
    static BODY_OFFSET = array_to_vec2(DATA.body_offset);

    if canvas == undefined {
        canvas = ANCHOR.canvas(ANCHOR.screen_canvas)
        .set_size_to_minspec()
        .set_align(Align.Center, Align.Middle);
    }

    target = target == undefined ? {} : target;
    target.canvas = canvas;

    //
    target.book = ANCHOR.sprite(canvas)
        .set_z(JournalDepth.Book)
        .set_align(Align.Center, Align.Middle)
        .set_sprite(spr_ui_journal_backplate)

    //
    target.left_page = ANCHOR.sprite(target.book)
        .set_sprite(spr_ui_journal_book_page_layout_quests_left)
        .set_position(PAGE_OFFSET.x, PAGE_OFFSET.y, JournalDepth.Pages)

    //
    target.right_page = ANCHOR.sprite(target.book)
        .set_sprite(spr_ui_journal_book_page_layout_quests_right)
        .set_position(-PAGE_OFFSET.x, PAGE_OFFSET.y, JournalDepth.Pages)
        .set_align(Align.RightIn, Align.TopIn)

    //
    target.left_header = ANCHOR.positional(target.left_page)
        .set_xy(HEADER_OFFSET.x, HEADER_OFFSET.y)
        .set_size(HEADER_SIZE)

    //
    target.right_header = ANCHOR.positional(target.right_page)
        .set_align(Align.RightIn, Align.TopIn)
        .set_xy(-HEADER_OFFSET.x, HEADER_OFFSET.y)
        .set_size(HEADER_SIZE)

    //
    target.left_body = ANCHOR.positional(target.left_page)
        .set_xy(BODY_OFFSET.x, BODY_OFFSET.y)
        .set_size(BODY_SIZE)

    //
    target.right_body = ANCHOR.positional(target.right_page)
        .set_align(Align.RightIn, Align.TopIn)
        .set_xy(-BODY_OFFSET.x, BODY_OFFSET.y)
        .set_size(BODY_SIZE)

    //
    target.right_full_body = ANCHOR.positional(target.right_page)
        .set_align(Align.RightIn, Align.TopIn)
        .set_xy(-HEADER_OFFSET.x, HEADER_OFFSET.y)
        .set_size(BODY_SIZE.x, BODY_SIZE.y + HEADER_SIZE.y + 1)

    return target;
}

enum JournalDepth {
    SelectedTab = 100,
    MapName,
    MapArrows,
    MapGrid = 200,
    MapUnselectedTab = 300,
    Pages = 400,
    UnselectedTab,
    Book = 500,
}
