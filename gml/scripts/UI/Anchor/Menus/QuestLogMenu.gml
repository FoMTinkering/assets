enum QuestLogContext {
    Journal,
    RequestBoard,
    TaliChallengeBoard,
    StillwellChallengeBoard,
    LEN
}

function QuestLogMenu(journal, context) : AnchorMenu(Menu.QuestLog) constructor {
    self.journal = journal;
    self.context = context;
    self.active_quest = undefined;
    self.left_scroller = undefined;
    self.right_scroller = undefined;
    self.left_title = undefined;
    self.right_title = undefined;
    self.left_pilot = self.new_pilot()
        .allow_vertical_wrapping();
    self.right_pilot = self.new_pilot();

    function initialize() {
        var title = undefined;
        switch self.context {
            case QuestLogContext.Journal:
                title = "misc_local/active_quests";
                self.journal.left_page.set_sprite(spr_ui_journal_book_page_layout_quests_left);
                self.journal.right_page.set_sprite(spr_ui_journal_book_page_layout_quests_right);
                break;
            case QuestLogContext.RequestBoard:
                title = "misc_local/available_quests";
                self.journal.book.set_sprite(spr_ui_noticeboard_backplate);
                self.journal.left_page.set_sprite(spr_ui_noticeboard_frontplate_left);
                self.journal.right_page.set_sprite(spr_ui_noticeboard_frontplate_right);
                break;
            case QuestLogContext.TaliChallengeBoard:
                title = "misc_local/cooking_challenges";
                self.journal.book.set_sprite(spr_ui_taliferro_quest_backplate);
                self.journal.left_page.set_sprite(spr_ui_taliferro_quest_frontplate_left);
                self.journal.right_page.set_sprite(spr_ui_taliferro_quest_frontplate_right);
                break;
            case QuestLogContext.StillwellChallengeBoard:
                title = "misc_local/mission_quests";
                self.journal.book.set_sprite(spr_ui_taliferro_quest_backplate);
                self.journal.left_page.set_sprite(spr_ui_taliferro_quest_frontplate_left);
                self.journal.right_page.set_sprite(spr_ui_taliferro_quest_frontplate_right);
                break;
            default: impossible("Unexpected QuestLogContext: {QuestLogContext}", self.context);
        }

        self.journal.book.set_think_callback(function() {
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
            title,
            self.journal.left_header,
            spr_ui_journal_quests_header_icon,
        );

        self.right_title = title_for_journal(
            "misc_local/quest_details",
            self.journal.right_header,
            spr_ui_journal_quests_details_icon,
        );

        self.setup_left_page();
    }

    function setup_left_page(position_for_scroller) {
        ANCHOR.free_children(self.journal.left_body);
        if self.left_scroller != undefined {
            self.left_scroller.free();
        }
        self.left_pilot.reset();

        var active_list = undefined;

        switch self.context {
            case QuestLogContext.Journal:
                active_list = ListFromArray(QUEST_LOG.active.keys());
                break;
            case QuestLogContext.RequestBoard:
                active_list = REQUEST_BOARD;
                break;
            case QuestLogContext.TaliChallengeBoard:
                active_list = List()
                var challenge = available_tali_challenge();
                if challenge != undefined {
                    active_list.push(challenge);
                }
                break;
            case QuestLogContext.StillwellChallengeBoard:
                active_list = List()
                var challenge = available_stillwell_challenge();
                if challenge != undefined {
                    active_list.push(challenge);
                }
                break;
            default: impossible("Unexpected QuestLogContext: {QuestLogContext}", self.context);
        }

        self.left_scroller = create_scroller(self.journal.left_body)
            .subscribe_to_pilot(self.left_pilot)
            .set_pilot_padding(32, 32)

        if active_list.is_empty() {
            scroller_none_option(self.left_scroller, 40);
            ANCHOR.set_active_pilot(self.left_pilot);
            return;
        }

        var populate_quest_elements = function(list) {
            for (var j = 0; j < list.count(); j++) {
                var key = list.get(j);
                var quest = QUESTS.get(key);
                var element = self.left_scroller.new_element()
                    .add_text_label(quest.name)
                    .board_set("quest_name", key)
                    .add_to_pilot(self.left_pilot, true)
                    .set_selected_getter(function(key) {
                        return self.active_quest == key;
                    }, [key]);

                element.text_label
                    .set_x(28)
                    .set_align(Align.LeftIn, Align.Middle)
                    .set_max_width(111)

                //
                var overflow = element.text_label.measure().y - element.get_height();
                if overflow > 0 {
                    self.left_scroller.add_height_to_element(element, overflow + 6);
                }

                ANCHOR.sprite(element)
                    .set_sprite(get_npc_icon(quest.npc_for_icon))
                    .set_align(Align.LeftIn, Align.Middle)
                    .set_x(2)

                ANCHOR.sprite(element)
                    .set_sprite(CATEGORY_VISUALS[quest.category].icon)
                    .set_xy(2, 2)

                var envelope = ANCHOR.sprite(element)
                    .set_sprite(
                        REQUEST_BOARD_READ_ENTRIES.contains(key)
                            ? spr_ui_journal_quests_read_icon
                            : spr_ui_journal_quests_unread_icon
                    )
                    .set_align(Align.RightIn, Align.Middle)
                    .set_x(-5)

                element.set_tap_callback(function(key, envelope) {
                    REQUEST_BOARD_READ_ENTRIES.insert(key);
                    envelope.set_sprite(spr_ui_journal_quests_read_icon);
                    self.setup_right_page(key);
                }, [key, envelope])
            }
        }

        if self.context != QuestLogContext.Journal {
            active_list.sort_with(function(e1, e2) {
                return string_alphanumeric_comparison(local_get(QUESTS.get(e1).name), local_get(QUESTS.get(e2).name));
            });

            populate_quest_elements(active_list);
        } else {
            var collection = array_create_ext(QuestCategory.LEN, EmptyList);

            for (var i = 0; i < active_list.count(); i++) {
                var key = active_list.get(i);
                var quest = QUESTS.get(key);
                collection[quest.category].push(key);
            }

            for (var i = 0; i < QuestCategory.LEN; i++) {
                var category = collection[i];

                if category.is_empty() {
                    continue;
                }

                category.sort_with(function(e1, e2) {
                    return string_alphanumeric_comparison(local_get(QUESTS.get(e1).name), QUESTS.get(e2).name);
                });

                var visuals = CATEGORY_VISUALS[i];
                self.left_scroller.new_header(visuals.icon, visuals.title);

                populate_quest_elements(category);
            }
        }

        if position_for_scroller != undefined {
            self.left_scroller.scroll_by_amount(position_for_scroller - 2);
        }

        ANCHOR.set_active_pilot(self.left_pilot);
    }

    function setup_right_page(quest_key) {
        self.reset_right_page();

        self.active_quest = quest_key;

        var quest = QUESTS.get_unwrap(self.active_quest);
        var active_quest_data = QUEST_LOG.active.get(self.active_quest);
        var active_blackboard = undefined;
        if active_quest_data != undefined {
            active_blackboard = active_quest_data.blackboard;
        }

        self.right_scroller = create_scroller(self.journal.right_body)
            .subscribe_to_pilot(self.right_pilot)
            .set_pilot_padding(32, 32)

        //

        var element = self.right_scroller.new_element(35)
            .add_to_pilot(self.right_pilot, true)
            .add_text_label("misc_local/placeholder")
            .board_set("open", false)

        //
        element.text_label
            .set_align(Align.LeftIn, Align.TopIn)
            .set_xy(4, 4)

        //
        //
        element.text_label.prevent_spillover(false);

        //
        var force = !local_has_translation(local_language(), quest.description);
        var description_text = filter_text_for_textbox(local_get(quest.description));
        var full_height = ANCHOR.text_height(description_text, element.text_label.get_max_size().x, undefined, undefined, force) + 8;
        var short_text = elide_text(description_text, element.text_label.get_max_size().x, 2, true, undefined, force);

        //
        var ellipses = local_get(fiddle_get("misc_local/ellipses"));
        if force {
            short_text = string_replace(short_text, ellipses, "...");
        }

        element.text_label.set_ghost_key(quest.description);
        element.text_label.set_text(short_text);

        //
        if string_pos(ellipses, short_text) {
            //
            var expand_arrow = ANCHOR.sprite(element)
                .set_sprites_from_key("spr_ui_journal_quests_expand_arrow_icon")
                .set_key_sprite_target(element)
                .set_align(Align.RightIn, Align.BottomIn)
                .set_xy(-4, -4)

            element.set_tap_callback(function(element, description, short_text, full_height, expand_arrow) {
                if element.board_get("open") {
                    element.text_label.set_text(short_text);
                    self.right_scroller.add_height_to_element(element, -(full_height - 35));
                    element.board_set("open", false);
                    expand_arrow.enable();
                } else {
                    element.text_label.set_text(description);
                    self.right_scroller.add_height_to_element(element, full_height - element.get_height());
                    element.board_set("open", true);
                    expand_arrow.disable();
                }
            }, [element, description_text, short_text, full_height, expand_arrow])
        }

        //
        if !quest.tasks.is_empty() {
            var header_element = self.right_scroller.new_element(21)
                .set_sprites_from_key("spr_ui_generic_box_header")
                .add_z(-10)
                .add_text_label("misc_local/objectives", COMMON_LUT, CommonLutIndex.Header);

            header_element.z_mod = -5;

            ANCHOR.sprite(header_element)
                .set_sprite(spr_ui_journal_quests_objectives_icon)
                .set_x(3)
                .set_align(Align.LeftIn, Align.Middle)

            var max_index = 0;
            if self.context == QuestLogContext.Journal {
                var max_index = min(active_quest_data.current_stage, quest.tasks.count() - 1);
            }

            for (var i = 0; i <= max_index; i++) {
                //
                var objective = quest.tasks.get(i);

                var element = self.right_scroller.new_element(0)
                    .add_text_label(objective.description)
                    .add_to_pilot(self.right_pilot, true);

                element.text_label
                    .set_align(Align.LeftIn, Align.TopIn)
                    .set_xy(4, 4)

                self.right_scroller.add_height_to_element(element, element.text_label.measure().y + 8);

                if i != max_index {
                    element.text_label
                        .strike_through()
                        .set_alpha(UI_FADE_ALPHA)
                    continue;
                }

                //
                gather_listings_from_requirements(objective.requirements, active_blackboard).for_each(function(listing) {
                    static MAX_WIDTH = 121;

                    var element = self.right_scroller.new_element(0)
                        .add_to_pilot(self.right_pilot, true)

                    var nodes = render_quest_requirement(listing, element, MAX_WIDTH);
                    self.right_scroller.add_height_to_element(element, nodes.name.measure().y + 8);
                });
            }
        }

        //
        var rewards = gather_listings_from_quest_rewards(quest.reward_list);
        if !rewards.is_empty() {
            var header_element = self.right_scroller.new_element(21)
                .set_sprites_from_key("spr_ui_generic_box_header")
                .add_z(-10)
                .add_text_label("misc_local/rewards", COMMON_LUT, CommonLutIndex.Header)

            header_element.z_mod = -5;

            ANCHOR.sprite(header_element)
                .set_sprite(spr_ui_journal_quests_rewards_icon)
                .set_x(3)
                .set_align(Align.LeftIn, Align.Middle)

            rewards.for_each(function(listing) {
                static MAX_WIDTH = 121;

                var element = self.right_scroller.new_element(0)
                    .add_to_pilot(self.right_pilot, true)

                var nodes = render_quest_reward(listing, element, MAX_WIDTH);
                self.right_scroller.add_height_to_element(element, nodes.name.measure().y + 8);
            });
        }

        //
        if matches(self.context, QuestLogContext.RequestBoard,QuestLogContext.TaliChallengeBoard, QuestLogContext.StillwellChallengeBoard) {
            var element = self.right_scroller.new_element(36)
                .set_sprite(spr_nothing_nineslice)
            ANCHOR.nine_slice(element)
                .set_align(Align.Center, Align.Middle)
                .set_size(96, 20)
                .set_tap_sound("SoundEffects/UI/UIExtraPositiveClick")
                .set_sprites_from_key("spr_ui_button")
                .add_hover_outline()
                .add_glyph(InputId.Interact, AnchorControl.Point)
                .add_text_label("misc_local/accept_request", COMMON_LUT, CommonLutIndex.Dark)
                .add_to_pilot(self.right_pilot)
                .set_tap_callback(function() {
                    QUEST_LOG.start(self.active_quest);

                    if !matches(context, QuestLogContext.TaliChallengeBoard, QuestLogContext.StillwellChallengeBoard) {
                        REQUEST_BOARD.remove(REQUEST_BOARD.find_lazy(self.active_quest));
                    }

                    if QUESTS.get(self.active_quest).category == QuestCategory.Crown {
                        ARI.crown_cooldown = 7;
                    }

                    var position_for_scroller = self.left_scroller.get_current_y();
                    self.setup_left_page(position_for_scroller);
                    ANCHOR.free_children(self.journal.right_body);
                })
        }

        ANCHOR.set_active_pilot(self.right_pilot);
    }

    function reset_right_page() {
        self.right_pilot.reset();
        ANCHOR.free_children(self.journal.right_body);
        if self.right_scroller != undefined {
            self.right_scroller.free();
        }
    }

    self.initialize();
}

//
function gather_listings_from_quest_rewards(rewards) {
    return rewards.fold(List(), function(a, reward) {
        switch reward.type {
            case QuestRewardType.Item:
                a.push(Listing.Item(reward.item, undefined, reward.amount));
                break;
            case QuestRewardType.Gold:
                a.push(Listing.Gold(reward.amount));
                break;
            case QuestRewardType.RecipeScroll:
                var item = new LiveItem(ItemId.RecipeScroll, reward.item);
                a.push(Listing.Item(item));
                break;
            case QuestRewardType.CraftingScroll:
                var item = new LiveItem(ItemId.CraftingScroll, reward.item);
                a.push(Listing.Item(item));
                break;
            case QuestRewardType.Tiers:
                //
                //
                break;
            case QuestRewardType.AnimalCosmetic:
                var item = new LiveItem(ItemId.AnimalCosmetic);
                item.animal_cosmetic = {
                    animal: reward.animal,
                    cosmetic: reward.cosmetic,
                };
                a.push(Listing.Item(item));
                break;
            case QuestRewardType.PlayerCosmetic:
                var item = new LiveItem(ItemId.Cosmetic);
                item.cosmetic = reward.cosmetic;
                a.push(Listing.Item(item));
                break;
            case QuestRewardType.Renown:
                a.push(Listing.Custom(
                    spr_ui_journal_inventory_renown_icon_large,
                    "misc_local/renown",
                    reward.value,
                ));
                break;
            case QuestRewardType.LookupKey:
                var value = ARI.quest_artifacts.get(reward.key);
                if value != undefined {
                    var item = reward_to_live_item(parse_reward(value));
                    if item != undefined {
                        a.push(Listing.Item(item));
                    }
                }
                break;
            default: break;
        }
        return a;
    })
}

//
//
//
function gather_listings_from_requirements(requirements, blackboard) {
    var output = List();
    for (var i = 0; i < Requirement.LEN; i++) {
        var requirement = requirements[i];
        if requirement == undefined {
            continue;
        }

        switch i {
            case Requirement.SuppliedItems:
                for (var j = 0; j < array_length(requirement); j++) {
                    var this_req = requirement[j];
                    var inventory = undefined;
                    var icon = undefined;
                    if this_req.type == SupplyType.Chest {
                        var point = trellis_point_location_position(this_req.point);
                        var ni = GRIDS[point.location_id].node_index_for_cell(point.pos.x div 8, point.pos.y div 8);
                        inventory = GRIDS[point.location_id].node_parent[ni].inventory;
                        icon = spr_ui_crafting_icon_storage;
                    } else {
                        inventory = SEAL_INVENTORIES[this_req.seal];
                        icon = spr_ui_journal_quests_icon_seal;
                    }

                    for (var k = 0; k < ItemId.LEN; k++) {
                        if this_req.items[k] == 0 {
                            continue;
                        }

                        output.push(Listing.Item(
                            k,
                            inventory,
                            this_req.items[k],
                            icon,
                        ));
                    }
                }
                break;
            case Requirement.MetNpc:
                var progress = 0;
                for (var j = 0; j < array_length(requirement); j++) {
                    if NPCS[requirement[j]].has_met() {
                        progress += 1;
                    }
                }
                output.push(Listing.Custom(
                    spr_ui_dialogue_speech_bubble_group_big,
                    "misc_local/introductions",
                    array_length(requirement),
                    progress,
                ));
                break;
            default:
                var iter_target = [];
                if requirement_field_is_array(i) {
                    iter_target = requirement;
                } else if requirement != undefined {
                    iter_target = [requirement];
                }

                for (var j = 0; j < array_length(iter_target); j++) {
                    var l = try_requirement_to_listing(i, iter_target[j], blackboard);
                    if l != undefined {
                        output.push(l)
                    }
                }
                break;
        }
    }

    return output;
}

//
//
function try_requirement_to_listing(requirement, data, blackboard) {
    switch requirement {
        case Requirement.HasItem: return Listing.Item(data[0], ARI.inventory, data[1]);
        case Requirement.HasGold: return Listing.Gold(data);
        case Requirement.ShippedTag:
            var registration = QUEST_TAG_REGISTRATIONS.get(data[0]);
            var ari_has = 0;
            if blackboard != undefined {
                var starting_amount = blackboard.get(format("{}_needed", data[0])) - data[1];
                ari_has = ARI.times_item_tag_sold(data[0]) - starting_amount;
            } else {
                ari_has = 0;
            }
            return Listing.Custom(
                ITEM_PROTOTYPES[registration.item_for_icon].icon_sprite,
                registration.text,
                data[1],
                ari_has,
            );
        case Requirement.ShippedItem:
            var ari_has = 0;
            if blackboard != undefined {
                var starting_amount = blackboard.get(format("{ItemId}_needed", data[0])) - data[1];
                ari_has = ARI.items_sold[data[0]] - starting_amount;
            } else {
                ari_has = 0;
            }
            return Listing.Custom(
                ITEM_PROTOTYPES[data[0]].icon_sprite,
                ITEM_PROTOTYPES[data[0]].name_key,
                data[1],
                ari_has,
            );
        case Requirement.DefeatedMonster:
            var ari_has = 0;
            if blackboard != undefined {
                var starting_amount = blackboard.get(format("{MonsterCategory}_needed", data[0])) - data[1];
                ari_has = ARI.monsters_killed(data[0]) - starting_amount;
            } else {
                ari_has = 0;
            }
            var info = monster_category_to_ui_info(data[0]);
            return Listing.Custom(
                info.icon,
                info.label,
                data[1],
                ari_has,
            );
            break;
        case Requirement.Custom:
            if data[$ "gather"] != undefined {
                var item = string_to_item_id(data.gather.item);
                return Listing.Custom(
                    ITEM_PROTOTYPES[item].icon_sprite,
                    ITEM_PROTOTYPES[item].name_key,
                    undefined,
                    total_item_count(item),
                );
            }
            return undefined;
        default: return undefined;
    }
}

//
//
function render_quest_requirement(listing, element, max_width) {
    var icon = ANCHOR.sprite(element)
        .set_sprite(listing_icon(listing))
        .set_x(2)
        .set_align(Align.LeftIn, Align.Middle)

    var name = ANCHOR.text(icon)
        .set_text(listing_label(listing))
        .set_x(2)
        .set_max_width(max_width)
        .set_align(Align.RightOut, Align.Middle)
        .set_lut(COMMON_LUT, can_fulfill_listing(listing)
            ? CommonLutIndex.Standard
            : CommonLutIndex.Red
        );

    var count = ANCHOR.text(element)
        .set_sprite_font("item_count")
        .set_text(listing_count_text(listing))
        .set_lut(spr_ui_hud_font_currency_lut, can_fulfill_listing(listing) ? 0 : 1)
        .set_align(Align.RightIn, Align.Middle)
        .set_x(-6)

    var sub = listing_sub_icon(listing);
    if sub != undefined {
        ANCHOR.sprite(count)
            .set_align(Align.LeftOut, Align.Middle)
            .set_x(-2)
            .set_sprite(sub)
    }

    return {
        icon,
        name,
        count,
    }
}

function render_quest_reward(listing, element, max_width) {
    var icon = ANCHOR.sprite(element)
        .set_sprite(listing_icon(listing))
        .set_x(2)
        .set_align(Align.LeftIn, Align.Middle)

    var name = ANCHOR.text(icon)
        .set_text(listing_label(listing))
        .set_x(4)
        .set_max_width(max_width ?? element.get_width() - 31)
        .set_align(Align.RightOut, Align.Middle)
        .set_lut(COMMON_LUT)

    var count = ANCHOR.text(icon)
        .set_sprite_font("item_count")
        .set_text(listing_count_text(listing, false))
        .set_align(Align.RightIn, Align.BottomIn)
        .set_enabled(listing.amount > 1)

    return {
        icon,
        name,
        count,
    }
}

//
//
function create_quest_turn_in_popup(active_quest, quest_name, npc_id, npc_conversation) {
    var task = active_quest.quest.tasks.get(active_quest.current_stage);
    var popup = __base_quest_popup(
        active_quest.quest.name,
        task.turn_in_description,
        gather_listings_from_requirements(task.requirements, active_quest.blackboard),
        render_quest_requirement,
    );

    popup.create_button("misc_local/cancel");
    var turn_in_button = popup.create_button(task.turn_in_button_label, function(active_quest, npc_id, npc_conversation) {
        //
        if npc_conversation != undefined {
            //
            if instance_exists(self) {
                obj_ari.face_dir(point_direction(obj_ari.x, obj_ari.y, self.x, self.y));
            }
            obj_ari.set_idle_simple();

            play_conversation_from_path(
                npc_id,
                npc_conversation,
                function(_driver, active_quest) {
                    new_chain().append(LinkId.Await, function(active_quest) {
                        if MIST.is_running() {
                            return false;
                        }
                        var output = active_quest.progress();
                        active_quest.handle_progress_output(output);
                        return true;
                    }, [active_quest]);
                },
                [active_quest],
            );
        }

    }, [active_quest, npc_id, npc_conversation]);

    turn_in_button.set_unlocked(
        fulfills_all_requirements(task.requirements, active_quest.blackboard, QUEST_LOG.blackboard)
    );

    popup.quest_name = quest_name;

    popup.spawn();
}

function create_quest_complete_popup(finished_active_quest) {
    var granted_rewards = grant_quest_rewards(finished_active_quest.quest.reward_list);

    //
    if TEST_SUITE {
        return;
    }

    var listings = gather_listings_from_quest_rewards(granted_rewards);
    var popup = __base_quest_popup(
        finished_active_quest.quest.name,
        "misc_local/quest_complete",
        listings,
        render_quest_reward,
    );

    var button = popup.create_button("misc_local/close");

    popup.pilot.force_select(button);

    popup.spawn();

    //
    if finished_active_quest.quest_name == "gossip_for_elsie" {
        await_popup(spawn_tutorial, [Tutorial.ElsieGossip]);
    }
}

//
//
//
//
function __base_quest_popup(title, description, listings, renderer, max_width=121) {
    var popup = popup_creator(title, description);

    popup.original_body_height = popup.body.get_height();
    popup.original_body_y = popup.body.get_y();
    popup.original_backplate_height = popup.backplate.get_height();

    popup.start_index = 0;

    if !listings.is_empty() {
        popup.body_text
            .set_align(Align.Center, Align.TopOut)
            .set_y(-4)

        popup.inner_root = ANCHOR.positional(popup.body);

        static GENERATE_PAGE = function(popup, listings, max_width, renderer) {
            ANCHOR.free_children(popup.inner_root);
            var is_expanded = listings.count() > 5;
            popup.body.set_y(popup.original_body_y);
            popup.body.set_height(popup.original_body_height);
            popup.backplate.set_height(popup.original_backplate_height);

            var yy = 0;
            for (var i = popup.start_index; i < min(popup.start_index + 5, listings.count()); i++) {
                var listing = listings.get(i);
                var root = ANCHOR.positional(popup.inner_root)
                    .set_width(161)
                    .set_y(yy)

                var root_height = renderer(listing, root, max_width).name.measure().y + 8;
                root.set_height(root_height);
                yy += root_height;

                if is_expanded {
                    var page_count = ceil(listings.count() / 5);
                    var current_page = (popup.start_index div 5) + 1;
                    popup.page_number.set_text(format("{}/{}", current_page, page_count));
                }
            }

            popup.body.set_height(is_expanded
                ? max(yy, root_height * 5)
                : yy
            );

            if popup.body_text.lines() == 2 {
                popup.backplate.add_height(11);
                popup.body.add_y(5);
            }

            popup.backplate.add_height(popup.body.get_height() - popup.original_body_height + 8);
            popup.body.add_y(is_expanded ? -4 : 6);

            if is_expanded {
                popup.backplate.add_height(20);
                popup.left_button.set_unlocked(popup.start_index != 0);
                popup.right_button.set_unlocked(listings.count() - (popup.start_index + 5) > 0);
            }
        }

        if listings.count() > 5 {

            popup.left_button = ANCHOR.nine_slice(popup.body)
                .set_sprites_from_key("spr_ui_button")
                .set_size(18, 18)
                .set_align(Align.Center, Align.BottomOut)
                .set_xy(-48, 8)
                .add_glyph(InputId.MenuTabLeft, undefined, true)
                .add_hover_outline()
                .add_to_pilot(popup.pilot)
                .set_tap_sound("SoundEffects/UI/UIJournalTabSwitch")
                .set_tap_callback(function(GENERATE_PAGE, popup, listings, max_width, renderer) {
                    popup.start_index -= 5;
                    GENERATE_PAGE(popup, listings, max_width, renderer);
                }, [GENERATE_PAGE, popup, listings, max_width, renderer])

            ANCHOR.sprite(popup.left_button)
                .set_align(Align.Center, Align.Middle)
                .set_sprites_from_key("spr_ui_cooking_left_arrow")
                .set_key_sprite_target(popup.left_button)

            popup.right_button = ANCHOR.nine_slice(popup.body)
                .set_sprites_from_key("spr_ui_button")
                .set_size(18, 18)
                .set_align(Align.Center, Align.BottomOut)
                .set_xy(48, 8)
                .add_glyph(InputId.MenuTabRight, undefined, true)
                .add_hover_outline()
                .add_to_pilot(popup.pilot, true)
                .set_tap_sound("SoundEffects/UI/UIJournalTabSwitch")
                .set_tap_callback(function(GENERATE_PAGE, popup, listings, max_width, renderer) {
                    popup.start_index += 5;
                    GENERATE_PAGE(popup, listings, max_width, renderer);
                }, [GENERATE_PAGE, popup, listings, max_width, renderer])

            ANCHOR.sprite(popup.right_button)
                .set_align(Align.Center, Align.Middle)
                .set_sprites_from_key("spr_ui_cooking_right_arrow")
                .set_key_sprite_target(popup.left_button)

            popup.page_number = ANCHOR.text(popup.body)
                .set_align(Align.Center, Align.BottomOut)
                .set_y(13)
                .set_sprite_font("medium_2")
                .set_lut(COMMON_LUT)
        }

        GENERATE_PAGE(popup, listings, max_width, renderer);
    }

    return popup;
}

function spawn_request_board_menu() {
    var baby = ANCHOR.spawn_menu(Menu.BabyJournal);
    var menu = ANCHOR.spawn_menu(Menu.QuestLog, baby, QuestLogContext.RequestBoard);
    baby.sub_menu = menu;
    return menu;
}

function spawn_quest_log_menu(journal) {
    var menu = ANCHOR.spawn_menu(Menu.QuestLog);
    journal = journal == undefined ? create_journal_nodes() : journal;
    menu.build(journal, QuestLogContext.Journal);
    journal.sub_menu = menu;
    return menu;
}

function spawn_tali_challenge_menu() {
    var baby = ANCHOR.spawn_menu(Menu.BabyJournal);
    var menu = ANCHOR.spawn_menu(Menu.QuestLog, baby, QuestLogContext.TaliChallengeBoard);
    baby.sub_menu = menu;
    return menu;
}

function spawn_stillwell_challenge_menu() {
    var baby = ANCHOR.spawn_menu(Menu.BabyJournal);
    var menu = ANCHOR.spawn_menu(Menu.QuestLog, baby, QuestLogContext.StillwellChallengeBoard);
    baby.sub_menu = menu;
    return menu;
}

#macro CATEGORY_VISUALS global.__quest_category_visuals
CATEGORY_VISUALS = [
    { title: "misc_local/story_quests", icon: spr_ui_journal_quests_story_header_icon },
    { title: "misc_local/crown_requests", icon: spr_ui_journal_quests_renown_subicon },
    { title: "misc_local/cooking_challenges", icon: spr_ui_journal_quests_taliferro_header_icon },
    { title: "misc_local/mission_quests", icon: spr_ui_journal_quests_stillwell_mission_header_icon },
    { title: "misc_local/heart_quests", icon: spr_ui_journal_quests_heart_header_icon },
    { title: "misc_local/requests", icon: spr_ui_journal_quests_fetch_header_icon },
];
