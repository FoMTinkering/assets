function InboxMenu() : AnchorMenu(Menu.Inbox) constructor {
    create_journal_nodes(self.canvas, self);
    self.left_scroller = undefined;
    self.right_scroller = undefined;
    self.left_title = undefined;
    //
    self.left_pilot = self.new_pilot()
        .allow_vertical_wrapping();
    self.right_pilot = self.new_pilot();
    self.active_letter = undefined;
    self.quests_to_start = List();
    self.viewed_this_time = HashSet();

    self.book.set_sprite(spr_ui_mailbox_backplate);
    self.left_page.set_sprite(spr_ui_mailbox_frontplate_left);
    self.right_page.set_sprite(spr_ui_mailbox_frontplate_right);

    self.book.set_think_callback(function() {
        if self.left_scroller == undefined {
            return;
        }
        var directional_in_page =
            ANCHOR.get_active_pilot()
            == self.right_pilot && ANCHOR.in_directional_control();
        self.left_scroller.canvas.set_alpha(!directional_in_page ? 1 : UI_FADE_ALPHA);
        if directional_in_page {
            GLYPH_GUIDE.set_input(InputId.MenuBack, "misc_local/back");
            if INPUT.take_press(InputId.MenuBack) {
                self.reset_right_page();
                ANCHOR.set_active_pilot(self.left_pilot);
            }
        }
    })

    self.left_title = title_for_journal(
        "misc_local/your_mail",
        self.left_header,
        spr_ui_journal_quests_header_icon,
    );

    function on_close() {
        //
        if TEST_SUITE && !STORY_EXECUTOR_RUNNING {
            return;
        }

        for (var i = 0; i < ARI.inbox.contents.count(); i++) {
            var letter = ARI.inbox.contents.get(i);
            if self.viewed_this_time.contains(letter.name) && !letter.items_taken {
                var items = LETTERS.get(letter.name).items;
                for (var j = 0; j < items.count(); j++) {
                    var entry = items.get(j);
                    var item = undefined;
                    var count = 1;
                    if entry[$ "recipe"] != undefined {
                        item = new LiveItem(ItemId.RecipeScroll, entry.recipe);
                    } else {
                        item = entry.item;
                        count = entry.count;
                    }
                    repeat count {
                        drop_item(item, obj_ari.x, obj_ari.y);
                    }
                }
                letter.items_taken = true;
            }
        }

        while !self.quests_to_start.is_empty() {
            var quest = self.quests_to_start.pop();
            QUEST_LOG.start(quest);
            create_quest_popup(quest);
        }
    }

    //
    //
    //
    //
    //

    function setup_left_page(position_for_scroller) {
        ANCHOR.free_children(self.left_body);
        if self.left_scroller != undefined {
            self.left_scroller.free();
        }
        self.left_pilot.reset();

        self.left_scroller = create_scroller(self.left_body)
            .subscribe_to_pilot(self.left_pilot)
            .set_pilot_padding(32, 32)

        if ARI.inbox.contents.is_empty() {
            scroller_none_option(self.left_scroller);
        } else {
            for (var i = ARI.inbox.contents.count() - 1; i >= 0; i--) {
                var content = ARI.inbox.contents.get(i);
                var key = content.name;
                var letter = LETTERS.get(key);
                var subject_text = filter_text_for_textbox(local_get(letter.subject));
                var element = self.left_scroller.new_element()
                    .add_text_label("misc_local/placeholder")
                    .set_alpha(!content.read ? 1 : 0.5)
                    .add_to_pilot(self.left_pilot, true)
                    .set_label(key)
                    .set_selected_getter(function(key) {
                        return self.active_letter != undefined && self.active_letter.name == key;
                    }, [key]);

                element.text_label
                    .set_max_width(111)
                    .set_ghost_key(letter.subject)
                    .set_text(subject_text)
                    .set_x(28)
                    .set_align(Align.LeftIn, Align.Middle)

                element.npc_face = ANCHOR.sprite(element)
                    .set_sprite(get_npc_icon(letter.npc))
                    .set_align(Align.LeftIn, Align.Middle)
                    .set_x(2)

                var involved_quest = letter.quest_to_start ?? letter.quest_to_progress;
                if involved_quest != undefined {
                    var quest = QUESTS.get(involved_quest);
                    element.type_icon = ANCHOR.sprite(element)
                        .set_sprite(string_to_asset(format("spr_ui_journal_quests_{QuestCategory}_subicon", quest.category)))
                        .set_xy(2, 2)
                }

                var envelope = ANCHOR.sprite(element)
                    .set_sprite(
                        content.read
                            ? spr_ui_journal_quests_read_icon
                            : spr_ui_journal_quests_unread_icon
                    )
                    .set_align(Align.RightIn, Align.Middle)
                    .set_x(-5)
                    .set_speed(.75)

                if !content.items_taken && !letter.items.is_empty() {
                    var attachment = ANCHOR.sprite(envelope)
                        .set_align(Align.LeftIn, Align.BottomIn)
                        .set_sprite(spr_ui_journal_quests_attached_item_icon)

                    attachment.set_think_callback(function(content, attachment) {
                        if content.items_taken {
                            attachment.disable();
                        }
                    }, [content, attachment]);
                }

                element.set_tap_callback(function(content, envelope, element) {
                    var letter = LETTERS.get(content.name);
                    if !content.read {
                        content.read = true;
                        element.set_alpha(0.5);
                        if letter.quest_to_start != undefined {
                            self.quests_to_start.push(letter.quest_to_start);
                        }

                        if letter.quest_to_progress != undefined {
                            var active = QUEST_LOG.active.get(letter.quest_to_progress);
                            if active != undefined {
                                active.progress();
                            } else {
                                warn("Skipping progression on {} because it is not active!", letter.quest_to_progress);
                            }
                        }
                    }
                    envelope.set_sprite(spr_ui_journal_quests_read_icon);
                    self.setup_right_page(content, letter);
                }, [content, envelope, element])
            }

            if position_for_scroller != undefined {
                self.left_scroller.scroll_by_amount(position_for_scroller - 2);
            }
        }

        ANCHOR.set_active_pilot(self.left_pilot);
    }

    function setup_right_page(content, letter) {
        self.reset_right_page();
        self.active_letter = content;
        self.viewed_this_time.insert(self.active_letter.name);

        self.right_scroller = create_scroller(self.right_body)
            .subscribe_to_pilot(self.right_pilot)
            .set_pilot_padding(32, 32)
            .scroll_with_stick()

        //
        var description_text =
            filter_text_for_textbox(local_get(letter.body_key))
            + format("\n\n{Local}", NPC_PROTOTYPES[letter.npc].name)

        //
        var element = self.right_scroller.new_element()
            .add_to_pilot(self.right_pilot, true)

        var text = ANCHOR.text(element)
            .set_xy(4, 4)
            .allow_line_breaks()
            .set_ghost_key(letter.body_key)
            .set_text(description_text)
            .set_lut(COMMON_LUT)

        var full_height = text.measure().y + 8;

        self.right_scroller.add_height_to_element(element, full_height - element.get_height());

        if !letter.items.is_empty() {
            var header_element = self.right_scroller.new_element(21)
                .set_sprites_from_key("spr_ui_generic_box_header")
                .add_z(-1)
                .add_text_label("misc_local/attached_items", COMMON_LUT, CommonLutIndex.Header)

            ANCHOR.sprite(header_element)
                .set_sprite(spr_ui_journal_quests_rewards_icon)
                .set_x(3)
                .set_align(Align.LeftIn, Align.Middle)

            for (var i = 0; i < letter.items.count(); i++) {
                var listing = letter.items.get(i).listing;

                static MAX_WIDTH = 130;

                var element = self.right_scroller.new_element(0)
                    .add_to_pilot(self.right_pilot, true)

                var nodes = render_quest_reward(listing, element, MAX_WIDTH);
                self.right_scroller.add_height_to_element(element, nodes.name.measure().y + 8);

                element.set_think_callback(function(element, nodes) {
                    if self.active_letter == undefined {
                        return; //
                    }
                    if element.get_alpha() == 1 && self.active_letter.items_taken {
                        nodes.name.strike_through();
                        element.set_alpha(UI_FADE_ALPHA);
                    }
                }, [element, nodes])

            }

            var element = self.right_scroller.new_element(36)
                .set_sprite(spr_nothing_nineslice)
            self.accept_button = ANCHOR.nine_slice(element)
                .set_align(Align.Center, Align.Middle)
                .set_size(96, 20)
                .set_tap_sound("SoundEffects/UI/UIExtraPositiveClick")
                .set_sprites_from_key("spr_ui_button")
                .add_hover_outline()
                .add_glyph(InputId.Interact, AnchorControl.Point)
                .add_text_label("misc_local/take_items", COMMON_LUT, CommonLutIndex.Dark)
                .add_to_pilot(self.right_pilot)
                .set_unlocked(!self.active_letter.items_taken)
                .set_tap_callback(function(letter) {
                    for (var i = 0; i < letter.items.count(); i++) {
                        var entry = letter.items.get(i);
                        var item = undefined;
                        var count = 1;
                        if entry[$ "recipe"] != undefined {
                            item = new LiveItem(ItemId.RecipeScroll, entry.recipe);
                        } else {
                            item = entry.item;
                            count = entry.count;
                        }
                        ARI.give_item(item, count, true, false);
                    }
                    self.active_letter.items_taken = true;
                    self.accept_button.lock();
                }, [letter])
        }

        ANCHOR.set_active_pilot(self.right_pilot);
    }

    function reset_right_page() {
        self.active_letter = undefined;
        self.right_pilot.reset();
        ANCHOR.free_children(self.right_body);
        if self.right_scroller != undefined {
            self.right_scroller.free();
        }
    }

    self.setup_left_page();
}
