function StorageMenu() : AnchorMenu(Menu.Storage) constructor {
    //
    function on_close() {
        if self.node != undefined && self.node.renderer != undefined {
            self.node.renderer.sprite_index = self.node.renderer.node.prototype.interaction_chest.opening_sprite;
            self.node.renderer.image_index = sprite_get_number(self.node.renderer.sprite_index) - 1;
            self.node.renderer.image_speed = -1;
            TANGO.play(self.node.prototype.interaction_chest.close_sfx, self.node.renderer.x, self.node.renderer.y);
        }
    }

    function build() {
        var storage_info = fiddle_get(format("ui/misc/inventory/storage/{}", self.left.size()));
        var backpack_info = fiddle_get(format("ui/misc/inventory/backpack/{}", self.right.size()))

        self.left_pilot = self.new_pilot();
        self.right_pilot = self.new_pilot();

        self.left_box = ANCHOR.sprite(self.canvas)
            .set_xy(storage_info.storage_x, 8)
            .set_align(Align.LeftIn, Align.Middle)
            .set_sprite(string_to_asset(storage_info.backplate))

        self.right_box = ANCHOR.sprite(self.canvas)
            .set_xy(storage_info.backpack_x, 4)
            .set_align(Align.RightIn, Align.Middle)
            .set_sprite(string_to_asset(backpack_info.backplate))

        self.left_menu = new InventoryMenu(storage_info.rows, left, self.left_pilot);
        self.right_menu = new InventoryMenu(backpack_info.rows, right, self.right_pilot);

        if self.include_left_banner {
            self.left_banner = new StorageBanner(self.left, self, self.left_menu.hand, self.left_pilot, self.right, self.node)
                .with_sort_button(false)
                .with_trash_button();

            if self.include_pull_button {
                self.left_banner.with_pull_button();
            }

            if self.node != undefined {
                self.left_banner.with_icon_button();
            }

            if self.include_left_help_button {
                self.left_banner.with_help_button();
            }

            self.left_banner.build(self.left_box);

            self.left_banner.banner.set_y(1);
            self.left_pilot.request_newline();
        }

        if self.include_right_banner {
            self.right_banner = new StorageBanner(self.right, self, self.right_menu.hand, self.right_pilot, self.left, self.node)
                .with_stack_button(self.use_alt_stack_behavior_flag)
                .with_sort_button();

            if self.include_right_help_button {
                self.right_banner.with_help_button();
            }

            self.right_banner.build(self.right_box);
            self.right_banner.banner.set_y(9);
            self.right_pilot.request_newline();
        }

        self.left_menu.build(0, 0, self.left_box, Align.Center, Align.Middle);
        self.left_menu.use_cursor();
        if self.recipe != undefined {
            self.left_menu.set_to_transfer_control();
        } else {
            self.left_menu.set_to_storage_control();
        }
        self.left_menu.tooltip_on_left = true;

        for (var i = 0; i < left.size(); i++) {
            self.left_menu.slots[i].square
                .set_sprites_from_key("spr_ui_inventory_slot")
                .render_as_nine_slice(false)
        }

        self.right_menu.build(0, 3, self.right_box, Align.Center, Align.Middle);
        self.right_menu.use_cursor();
        if self.recipe != undefined {
            self.right_menu.set_to_transfer_control();
        } else {
            self.right_menu.set_to_storage_control();
        }
        for (var i = 0; i < right.size(); i++) {
            self.right_menu.slots[i].square
                .set_sprites_from_key("spr_ui_inventory_slot")
                .render_as_nine_slice(false)
        }

        self.right_menu.pair_with(self.left_menu);
        self.left_menu.pilot.set_neighbor(self.right_menu.pilot, Cardinal.East);
        self.right_menu.pilot.set_neighbor(self.left_menu.pilot, Cardinal.West);
        self.right_menu.pilot.force_select(self.right_menu.slots[0].square);
        ANCHOR.set_active_pilot(self.right_menu.pilot);

        if self.recipe != undefined {
            self.update_turn_in_listings();
        }

        return self;
    }

    function update_turn_in_listings() {
        if self.listing_plate != undefined {
            ANCHOR.free_node(self.listing_plate);
        }

        static TEXT_PADDING = 55;
        var bounds = Vec2(self.left_box.get_width(), 184);
        draw_set_font(ANCHOR.get_text_font());
        var largest_width = self.listings.fold(0, function(a, v) {
            var width = string_width(listing_label(v));
            return a > width ? a : width;
        });
        var target_width = clamp(largest_width + TEXT_PADDING, bounds.x, bounds.y);

        self.listing_plate = ANCHOR.nine_slice(self.left_box)
            .set_sprite(spr_ui_popup_box)
            .set_width(target_width)
            .set_align(Align.Center, Align.TopOut)
            .set_y(-4)

        var header = ANCHOR.nine_slice(self.listing_plate)
            .set_sprite(spr_ui_tooltip_header_box)
            .set_align(Align.Center, Align.TopIn)
            .set_width(self.listing_plate.get_width())
            .set_height(22)

        ANCHOR.text(header)
            .set_align(Align.Center, Align.Middle)
            .set_y(1)
            .set_lut(COMMON_LUT, CommonLutIndex.Header)
            .set_text_align(TextAlign.Center)
            .set_key("misc_local/required_materials")

        var yy = 0;
        for (var i = 0; i < self.listings.count(); i++) {
            var max_width = self.listing_plate.get_width() - TEXT_PADDING;
            var listing = self.listings.get(i);
            var root = ANCHOR.positional(header)
                .set_align(Align.LeftIn, Align.BottomOut)
                .set_width(self.listing_plate.get_width() - 4)
                .set_xy(2, yy)

            var root_height = render_quest_requirement(listing, root, max_width).name.measure().y + 8;
            root.set_height(root_height);

            yy += root_height;
        }

        self.listing_plate.set_height(yy + header.get_height() + 5);
        var total_height = self.listing_plate.get_height();
        total_height += abs(self.listing_plate.get_y());

        self.left_box.set_y(total_height / 2);
    }

    //
    function set_inventories(left, right) {
        self.left = left;
        self.right = right;
        return self;
    }

    function with_left_banner(boo=true) {
        self.include_left_banner = boo;
        return self;
    }

    function with_right_banner(boo=true) {
        self.include_right_banner = boo;
        return self;
    }

    function with_chest_node(node) {
        self.node = node;
        return self;
    }

    function with_alt_stack_behavior(boo=true) {
        self.use_alt_stack_behavior_flag = boo;
        return self;
    }

    function with_left_help_button(boo=true) {
        self.include_left_help_button = boo;
        return self;
    }

    function with_right_help_button(boo=true) {
        self.include_right_help_button = boo;
        return self;
    }

    function with_pull_button(boo=true) {
        self.include_pull_button = boo;
        return self;
    }

    function with_tags(legal_tags, illegal_tags) {
        for (var i = 0; i < ItemId.LEN; i++) {
            var proto = ITEM_PROTOTYPES[i];
            var legal = true;

            for (var j = 0; j < array_length(legal_tags); j++) {
                legal &= proto.tags.contains(legal_tags[j]);
            }

            for (var j = 0; j < array_length(illegal_tags); j++) {
                legal &= !proto.tags.contains(illegal_tags[j]);
            }

            self.left.maximum_item_counts[i] = legal ? 4 : 0;
        }
        return self;
    }

    function with_recipe(recipe, listing_inventory) {
        self.recipe = HashSetFromArray(struct_get_names(recipe));

        //
        self.left.maximum_item_counts = array_create(ItemId.LEN, 0);
        var keys = struct_get_names(recipe);
        for (var j = 0; j < array_length(keys); j++) {
            var item_id = real(keys[j]);
            var count = recipe[$ item_id];
            self.left.maximum_item_counts[item_id] = count;
        }

        self.listings = List();
        var keys = struct_get_names(recipe);
        for (var i = 0; i < array_length(keys); i++) {
            var item_id = real(keys[i]);
            self.listings.push(Listing.Item(
                item_id,
                listing_inventory ?? self.left,
                recipe[$ item_id],
            ));
        }

        self.subscriber = new InventorySubscriber(self.left);

        self.canvas.set_think_callback(function() {
            if !self.subscriber.pull().is_empty() {
                self.update_turn_in_listings();
            }
        }, [], true)

        return self;
    }

    function drop_currently_held_item() {
        //
        if self.left_menu.hand_node.get_enabled() {
            self.left_menu.hand_node.drop_it = true;
        }
    }

    self.include_left_banner = false;
    self.include_right_banner = false;
    self.left_menu = undefined;
    self.right_menu = undefined;
    self.node = undefined;
    self.use_alt_stack_behavior_flag = false;
    self.recipe = undefined;
    self.listing_plate = undefined;
    self.chest_icon = undefined;
    self.include_left_help_button = false;
    self.include_right_help_button = false;
    self.include_pull_button = true;
}

function create_sort_icon(banner, xx, inventory, pilot, include_glyph=true) {
    var node = ANCHOR.sprite(banner);
    node
        .set_x(xx)
        .set_align(Align.Center, Align.Middle)
        .set_sprites_from_key("spr_ui_inventory_sort_button")
        .set_tap_callback(function(inventory) {
            inventory.sort();
        }, [inventory])
        .add_to_pilot(pilot)
    if include_glyph {
        node.add_glyph(InputId.SecondaryInteract, AnchorControl.Point);
        node.glyph_node.add_xy(-2, -1);
    }
    return node;
}

enum ChestIcon {
    Farming,
    Hay,
    Vegetable,
    Fruit,
    Flower,
    Fishing,
    Insects,
    Mining,
    Monster,
    Blacksmithing,
    Archaeology,
    Forage,
    Chicken,
    Seashell,
    Cow,
    //
    Food,
    Espresso,
    Crafting,
    Refine,
    Museum,
    Gift,
    Crown,
    Mill,
    Spring,
    Summer,
    Autumn,
    Winter,
    Music,
    Coin,
    Furniture,
    Decor,
    Rugs,
    Flooring,
    Wallpaper,
    Lamp,
    Gem,
    Magic,
    Mana,
    Stamina,
    Health,
    Essence,
    LEN
}

enum StorageBannerFlag {
    NONE = 0,
    ICON = 1,
    SORT = 1 << 1,
    TRASH = 1 << 2,
    HELP = 1 << 3,
    STACK = 1 << 4,
    PULL = 1 << 5,
}

function StorageBanner(inventory, menu, hand, pilot, pair, node) constructor {
    self.inventory = inventory;
    self.menu = menu;
    self.hand = hand;
    self.pilot = pilot;
    self.pair = pair;
    self.node = node;
    self.flag = StorageBannerFlag.NONE;
    self.count = 0;
    self.use_alt_stack_behavior_flag = false;
    self.include_sort_glyph = true;

    function with_icon_button() {
        assert_neq(self.node, undefined, "Cannot have an icon button without a node!");
        self.flag |= StorageBannerFlag.ICON;
        self.count += 1;
        return self;
    }

    function with_sort_button(include_glyph=true) {
        self.flag |= StorageBannerFlag.SORT;
        self.include_sort_glyph = include_glyph;
        self.count += 1;
        return self;
    }

    function with_trash_button() {
        self.flag |= StorageBannerFlag.TRASH;
        self.count += 1;
        return self;
    }

    function with_help_button() {
        self.flag |= StorageBannerFlag.HELP;
        self.count += 1;
        return self;
    }

    function with_stack_button(alt_behavior=false) {
        self.flag |= StorageBannerFlag.STACK;
        self.use_alt_stack_behavior_flag = alt_behavior;
        self.count += 1;
        return self;
    }

    function with_pull_button() {
        assert_neq(self.node, undefined, "Cannot have a pull button without a node!");
        self.flag |= StorageBannerFlag.PULL;
        self.count += 1;
        return self;
    }


    function spawn_icon_selection_popup() {
        var popup = popup_creator("misc_local/select_icon");
        popup.backplate.set_size(180, 48);

        var options = array_create_ext(ChestIcon.LEN, function(i) {
            return i;
        });

        array_insert(options, 0, I32_MAX);

        var layout = new GridLayout(ListFromArray(options), popup.pilot);

        var container_size = layout.container_size();
        var container = ANCHOR.positional(popup.backplate)
            .set_size(container_size)
            .set_align(Align.Center, Align.Middle)
            .set_y(9)

        popup.backplate.add_height(container_size.y);

        while layout.has_next() {
            var next = layout.next(container);

            if next.asset != undefined && self.node != undefined {
                var unlocked = true;
                var icon_to_set = undefined;
                if next.asset != I32_MAX {
                    icon_to_set = next.asset;
                    next.icon.set_sprite(string_to_asset(format("spr_ui_storage_chest_bark_icon_{ChestIcon}", next.asset)));
                    if next.asset == self.node.chest_icon {
                        popup.pilot.force_select(next.square);
                    }
                } else {
                    icon_to_set = undefined;
                    next.icon.set_sprites_from_key("spr_ui_journal_customization_slot_icon_none");
                }

                if unlocked || icon_to_set == undefined {
                    next.square.set_tap_callback(function(popup, icon_to_set) {
                        self.menu.drop_currently_held_item();

                        self.node.chest_icon = icon_to_set;
                        if icon_to_set == undefined {
                            self.icon.set_sprites_from_key("spr_ui_journal_customization_slot_icon_none");
                        } else {
                            self.icon.set_sprite(string_to_asset(format("spr_ui_storage_chest_bark_icon_{ChestIcon}", icon_to_set)));
                        }
                        popup.close();
                    }, [popup, icon_to_set]);
                }
            }
        }

        popup.spawn();
    }

    function build(parent) {
        self.banner = ANCHOR.sprite(parent)
            .set_align(Align.LeftIn, Align.TopOut)
            .set_sprite(string_to_asset(format("spr_ui_inventory_ribbon_{}_icon_backplate", self.count)));

        var layout = centered_positions(self.count, 22, 2);
        var layout_index = 0;

        if has_flag(self.flag, StorageBannerFlag.STACK) {
            self.stack_icon = ANCHOR.sprite(self.banner)
                .set_x(layout[layout_index] - 2)
                .set_align(Align.Center, Align.Middle)
                .set_sprites_from_key("spr_ui_inventory_stack_button")
                .set_tap_callback(function() {
                    for (var i = 0; i < self.inventory.size(); i++) {
                        var slot = self.inventory.slot(i);
                        if slot.count != 0 {
                            var check = self.use_alt_stack_behavior_flag
                                ? self.pair.can_add(slot.item.item_id)
                                : self.pair.item_id_quantity(slot.item.item_id) != 0;
                            if check {
                                var count = min(slot.count, self.pair.room_for_item(slot.item));
                                var not_added = self.pair.add(slot.item, count);
                                slot.remove(count - not_added);
                            }
                        }
                    }
                })
                .add_to_pilot(self.pilot)

            layout_index += 1;
        }

        if has_flag(self.flag, StorageBannerFlag.ICON) {
            self.icon_button = ANCHOR.sprite(self.banner)
                .set_x(layout[layout_index] - 2)
                .set_align(Align.Center, Align.Middle)
                .set_sprites_from_key("spr_ui_inventory_select_icon_button")
                .set_tap_callback(function() {
                    self.menu.drop_currently_held_item();
                    self.spawn_icon_selection_popup();
                })
                .add_to_pilot(self.pilot)

            self.icon = ANCHOR.sprite(self.icon_button)
                .set_align(Align.Center, Align.Middle)
                .set_y(-1)
                .set_sprite(self.node != undefined && self.node.chest_icon != undefined
                    ? string_to_asset(format("spr_ui_storage_chest_bark_icon_{ChestIcon}", self.node.chest_icon))
                    : spr_ui_storage_chest_bark_icon_empty
                );

            layout_index += 1;
        }

        if has_flag(self.flag, StorageBannerFlag.PULL) {
            self.pull_icon = ANCHOR.sprite(self.banner)
                .set_x(layout[layout_index] - 2)
                .set_align(Align.Center, Align.Middle)
                .set_tap_callback(function() {
                    self.menu.drop_currently_held_item();
                    var popup = popup_creator(
                        "misc_local/crafting_storage",
                        self.node.use_in_crafting
                            ? "misc_local/crafting_storage_disable"
                            : "misc_local/crafting_storage_enable"
                    );

                    popup.create_button("misc_local/close");
                    popup.create_button(
                        self.node.use_in_crafting ? "misc_local/disable" : "misc_local/enable",
                        function() {
                            self.node.use_in_crafting = !self.node.use_in_crafting;
                            self.pull_icon.set_sprites_from_key(
                                self.node.use_in_crafting
                                    ? "spr_ui_inventory_storage_pull_button_open"
                                    : "spr_ui_inventory_storage_pull_button_closed"
                            )
                        },
                    );
                    popup.spawn();
                })
                .add_to_pilot(self.pilot)

            self.pull_icon.set_sprites_from_key(
                self.node.use_in_crafting
                    ? "spr_ui_inventory_storage_pull_button_open"
                    : "spr_ui_inventory_storage_pull_button_closed"
            );

            layout_index += 1;
        }

        if has_flag(self.flag, StorageBannerFlag.SORT) {
            self.sort_icon = create_sort_icon(self.banner, layout[layout_index] - 2, self.inventory, self.pilot, self.include_sort_glyph);
            layout_index += 1;
        }

        if has_flag(self.flag, StorageBannerFlag.TRASH) {
            self.trash_icon = ANCHOR.sprite(self.banner)
                .set_x(layout[layout_index] - 2)
                .set_align(Align.Center, Align.Middle)
                .set_sprites_from_key("spr_ui_inventory_trash_button")
                .set_tap_sound("SoundEffects/UI/UITrashItem")
                .lock()
                .add_glyph(InputId.Throw)
                .add_to_pilot(self.pilot)
                .set_tap_callback(function() {
                    if keyboard_check(vk_shift) {
                        self.hand.slot(0).drain();
                    } else {
                        self.hand.slot(0).pop();
                    }
                    self.trash_icon.add_y(-4);
                    new_chain()
                        .join(LinkId.Ease, new Ease(EaseId.ElasticOut, 0, 4, 30), function(delta) {
                            self.trash_icon.add_y(delta);
                        })
                        .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0.5, 1, 30), function(_, a) {
                            self.trash_icon.set_alpha(a);
                        });
                })
                .set_think_callback(function() {
                    var item = self.hand.slot(0).item;
                    self.trash_icon.set_unlocked(item != undefined && !item_is_soulbound(item.item_id));
                })

            layout_index += 1;
        }

        if has_flag(self.flag, StorageBannerFlag.HELP) {

            self.help = ANCHOR.sprite(self.banner)
                .set_x(layout[layout_index] - 2)
                .set_align(Align.Center, Align.Middle)
                .set_sprites_from_key("spr_ui_inventory_help_button")
                .set_tap_callback(function() {
                    self.menu.drop_currently_held_item();
                    var popup = popup_creator();

                    popup.add_title("misc_local/inventory_management");

                    popup.backplate.set_size(
                        210,
                        INPUT.active_input_type != InputType.Gamepad ? 166 : 120,
                    );

                    var lmb = get_display_for_input_id(InputId.LeftMouse);
                    var main = get_display_for_input_id(InputId.Interact);
                    var second = get_display_for_input_id(InputId.PickUpOne);
                    var third = get_display_for_input_id(InputId.SecondaryInteract);

                    popup.header
                        .set_xy(0, 0)
                        .set_sprite(spr_ui_tooltip_header_box)
                        .set_size(popup.backplate.get_width(), 36)

                    var box_one = ANCHOR.nine_slice(popup.backplate)
                        .set_sprite(spr_ui_generic_box_main)
                        .set_y(44)
                        .set_align(Align.Center, Align.TopIn)
                        .set_size(180, 22)

                    ANCHOR.text(box_one)
                        .set_lut(COMMON_LUT)
                        .set_align(Align.LeftIn, Align.Middle)
                        .set_x(4)
                        .set_key("misc_local/transfer_all")

                    var glyph = ANCHOR.sprite(box_one)
                        .set_align(Align.RightIn, Align.Middle)
                        .set_x(-8)
                        .set_sprite(main.big_sprite)
                        .set_index(main.index)

                    if INPUT.active_input_type != InputType.Gamepad {

                        ANCHOR.text(glyph)
                            .set_align(Align.LeftOut, Align.Middle)
                            .set_lut(COMMON_LUT, CommonLutIndex.Gray)
                            .set_text("/")
                            .set_x(-3)

                        var glyph = ANCHOR.sprite(glyph)
                            .set_align(Align.LeftOut, Align.Middle)
                            .set_sprite(lmb.big_sprite)
                            .set_index(lmb.index)
                            .set_x(-13)

                        ANCHOR.text(glyph)
                            .set_align(Align.LeftOut, Align.Middle)
                            .set_lut(COMMON_LUT, CommonLutIndex.Gray)
                            .set_text("+")
                            .set_x(-3)

                        ANCHOR.sprite(glyph)
                            .set_sprite(big_keyboard_keys_sprite())
                            .set_index(array_index(KEYBOARD_INPUTS, vk_shift) + 1)
                            .set_align(Align.LeftOut, Align.Middle)
                            .set_x(-13)
                    }

                    var box_two = ANCHOR.nine_slice(box_one)
                        .set_sprite(spr_ui_generic_box_main)
                        .set_y(-1)
                        .set_align(Align.Center, Align.BottomOut)
                        .set_size(180, 22)

                    ANCHOR.text(box_two)
                        .set_lut(COMMON_LUT)
                        .set_align(Align.LeftIn, Align.Middle)
                        .set_x(4)
                        .set_key("misc_local/transfer_one")

                    var glyph = ANCHOR.sprite(box_two)
                        .set_align(Align.RightIn, Align.Middle)
                        .set_x(-8)
                        .set_sprite(second.big_sprite)
                        .set_index(second.index)

                    if INPUT.active_input_type != InputType.Gamepad {
                        ANCHOR.text(glyph)
                            .set_align(Align.LeftOut, Align.Middle)
                            .set_lut(COMMON_LUT, CommonLutIndex.Gray)
                            .set_text("+")
                            .set_x(-3)

                        ANCHOR.sprite(glyph)
                            .set_sprite(big_keyboard_keys_sprite())
                            .set_index(array_index(KEYBOARD_INPUTS, vk_shift) + 1)
                            .set_align(Align.LeftOut, Align.Middle)
                            .set_x(-13)
                    }

                    if self.menu.right_menu.control_mode != InventoryControlMode.Transfer {
                        popup.backplate.add_height(24);

                        var box_three = ANCHOR.nine_slice(box_two)
                            .set_sprite(spr_ui_generic_box_main)
                            .set_y(-1)
                            .set_align(Align.Center, Align.BottomOut)
                            .set_size(180, 22)

                        ANCHOR.text(box_three)
                            .set_lut(COMMON_LUT)
                            .set_align(Align.LeftIn, Align.Middle)
                            .set_x(4)
                            .set_key("misc_local/pick_up_inv")

                        glyph = ANCHOR.sprite(box_three)
                            .set_align(Align.RightIn, Align.Middle)
                            .set_x(-8)
                            .set_sprite(third.big_sprite)
                            .set_index(third.index)

                        if INPUT.active_input_type != InputType.Gamepad {
                            ANCHOR.text(glyph)
                                .set_align(Align.LeftOut, Align.Middle)
                                .set_lut(COMMON_LUT, CommonLutIndex.Gray)
                                .set_text("/")
                                .set_x(-3)

                            var glyph = ANCHOR.sprite(glyph)
                                .set_align(Align.LeftOut, Align.Middle)
                                .set_sprite(lmb.big_sprite)
                                .set_index(lmb.index)
                                .set_x(-13)

                            var box_four = ANCHOR.nine_slice(box_three)
                                .set_sprite(spr_ui_generic_box_main)
                                .set_y(-1)
                                .set_align(Align.Center, Align.BottomOut)
                                .set_size(180, 22)

                            ANCHOR.text(box_four)
                                .set_lut(COMMON_LUT)
                                .set_align(Align.LeftIn, Align.Middle)
                                .set_x(4)
                                .set_key("misc_local/pick_up_one_inv")

                            glyph = ANCHOR.sprite(box_four)
                                .set_align(Align.RightIn, Align.Middle)
                                .set_x(-8)
                                .set_sprite(second.big_sprite)
                                .set_index(second.index)

                            var box_five = ANCHOR.nine_slice(box_four)
                                .set_sprite(spr_ui_generic_box_main)
                                .set_y(-1)
                                .set_align(Align.Center, Align.BottomOut)
                                .set_size(180, 22)

                            ANCHOR.text(box_five)
                                .set_lut(COMMON_LUT)
                                .set_align(Align.LeftIn, Align.Middle)
                                .set_x(4)
                                .set_key("misc_local/pick_up_half")

                            glyph = ANCHOR.sprite(box_five)
                                .set_align(Align.RightIn, Align.Middle)
                                .set_sprite(second.big_sprite)
                                .set_index(second.index)
                                .set_x(-8)

                            ANCHOR.text(glyph)
                                .set_align(Align.LeftOut, Align.Middle)
                                .set_lut(COMMON_LUT, CommonLutIndex.Gray)
                                .set_text("+")
                                .set_x(-3)

                            ANCHOR.sprite(glyph)
                                .set_sprite(big_keyboard_keys_sprite())
                                .set_align(Align.LeftOut, Align.Middle)
                                .set_index(array_index(KEYBOARD_INPUTS, vk_control) + 1)
                                .set_x(-13)
                        }
                    }

                    popup.create_button("misc_local/close");

                    popup.spawn();
                })
                .add_to_pilot(self.pilot)

            layout_index += 1;
        }

        return self;
    }
}
