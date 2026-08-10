//
function InventoryMenu(row_length, inventory, pilot, use_buy_numbers=false, filter_callback=undefined) constructor {
    #macro INVENTORY_SLOT_SIZE 22
    #macro INVENTORY_SLOT_PADDING 2

    //
    //
    function pair_with(other_inventory) {
        ANCHOR.free_node(self.hand_node);
        self.hand = other_inventory.hand;
        self.hand_node = other_inventory.hand_node;
        self.pair = other_inventory.inventory;
        other_inventory.pair = self.inventory;
        self.refresh();
        other_inventory.refresh();
    };

    //
    function listen_for_updates() {
        //
        var updates = self.inventory_subscriber.pull();
        var any_updates = !updates.is_empty();
        var play_sound = false;
        for (var i = 0; i < updates.count(); i++) {
            var slot = updates.get(i);
            var nodes = self.slots[slot.index];
            var previous_item = nodes.item.board_try_take("previous_item");
            var previous_count = nodes.item.board_try_take("previous_count", 0);
            self.refresh_slot(slot);

            var play_sound = false;
            if slot.count == 0 {
                play_sound = previous_count != 0;
            } else {
                var item_updated = previous_item == undefined || !previous_item.partial_eq(slot.item);
                var count_larger = previous_count < slot.count;
                if item_updated || count_larger {
                    play_sound = true;
                    nodes.item.set_y(-4);
                    new_chain()
                        .join(LinkId.Ease, new Ease(EaseId.ElasticOut, -4, 0, 30), function(_, a, item) {
                            item.set_y(a);
                        }, [nodes.item])
                        .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0.5, nodes.item.get_alpha(), 30), function(_, a, item) {
                            item.set_alpha(a);
                        }, [nodes.item]);
                }
            }

        };

        if any_updates {
            self.refresh();
        }

        //
        var hand = self.hand_subscriber.pull();
        for (var i = 0; i< hand.count(); i++) {
            var slot = hand.get(i);
            var active = self.hand_node.get_enabled();
            if active && slot.count == 0 {
                self.hand_node.disable();
            } else if !active && slot.count > 0 {
                self.hand_node.enable();
                if self.tooltip != undefined {
                    self.hand_node.set_z(self.tooltip.backplate.get_z() - 1);
                }
                TANGO.play("SoundEffects/UI/UIInventoryPickUp");

                //
                play_sound = false;
            }
        }

        if play_sound {
            var sound = "SoundEffects/UI/UIInventoryPutDown";
            if self.play_special_full_sound {
                var all_full = self.inventory.slots.every(function(slot) {
                    return slot.item != undefined;
                });
                if all_full {
                    sound = "SoundEffects/UI/UIIncrement";
                }
            }
            TANGO.play(sound);
        }
    }

    //
    function create_hand_node() {
        var icon = item_node(ANCHOR.screen_canvas)
            .set_alpha(0.5)
            .set_align(Align.LeftIn, Align.TopIn)
            .set_layer_recursive(AnchorLayer.Popup);
        icon.drop_it = false;
        icon.source_inventory = self.inventory;

        icon.set_think_callback(function(icon) {

            //
            if INPUT.take_press(InputId.MenuBack) || self.hand_node.drop_it {
                self.hand_node.drop_it = false;
                var items = self.hand.slot(0).drain();
                while !items.is_empty() {
                    //
                    //
                    //
                    //
                    //
                    //
                    //
                    var item = items.pop();
                    if !icon.source_inventory.can_add(item) {
                        drop_item(item, obj_ari.x, obj_ari.y);
                    } else {
                        icon.source_inventory.add(item);
                    }
                }
                return;
            }
            self.hand_node.drop_it = false;

            //
            var slot = self.hand.slot(0);
            icon.set_to_item(slot.item, slot.count);
            icon.set_alpha(0.5)

            //
            if ANCHOR.in_directional_control() {
                var pilot = ANCHOR.get_active_pilot();
                var slot = pilot.get();
                var true_pos = ANCHOR.get_screen_position(slot);
                icon.set_xy(
                    true_pos.x + slot.get_width() - 5,
                    true_pos.y + slot.get_height() - 5,
                );
            } else {
                icon.set_xy(MOUSE_GUI_X, MOUSE_GUI_Y);
            }
        }, [icon])

        return icon;
    }

    function refresh() {
        self.inventory.slots.for_each(function(slot) {
            self.refresh_slot(slot);
        });
    }

    //
    function refresh_slot(slot) {
        var nodes = self.slots[slot.index];
        var new_item = slot.item;
        var new_count = slot.count;

        //
        if new_count == 0 {
            nodes.item.disable();
            return;
        }

        nodes.item.enable();

        var soft_lock = false;

        //
        if self.pair != undefined && self.transfer_only_flag && !self.pair.can_add(new_item) {
            soft_lock = true;
        }

        //
        if self.filter_callback != undefined && !self.filter_callback(slot) {
            soft_lock = true;
        }

        //
        nodes.item.set_to_item(new_item, new_count);
        nodes.item.set_alpha(soft_lock ? 0.5 : 1);

        //
        nodes.item.board_set("previous_item", new_item);
        nodes.item.board_set("previous_count", new_count);
        nodes.square.board_set("soft_locked", soft_lock);
    }

    //
    //
    function build(xx, yy, menu_parent, align_horz, align_vert) {
        self.hand_node = create_hand_node();
        self.hand_node.disable();

        var size = self.inventory.size();
        var canvas_width_padding = 10;
        var canvas_height_padding = 10;
        var box_size = calculate_box_size_for_inventory(self.inventory, self.row_length);

        self.canvas = ANCHOR.canvas(menu_parent)
            .set_xy(xx, yy)
            .set_align(align_horz, align_vert)
            .set_size(box_size.x, box_size.y)
            .set_think_callback(function() {
                self.listen_for_updates();
            })
            .set_free_callback(function() {
                ANCHOR.free_node(self.hand_node);

                //
                var slot = self.hand.slot(0);
                if slot.count != 0 {
                    ARI.give_item(slot.item, slot.count);
                    slot.remove(slot.count);
                }
            });

        //
        for (var i = 0; i < size; i++) {
            var slot_x = ((i mod self.row_length) * (INVENTORY_SLOT_SIZE + INVENTORY_SLOT_PADDING)) + canvas_width_padding;
            var slot_y = ((i div self.row_length) * (INVENTORY_SLOT_SIZE + INVENTORY_SLOT_PADDING)) + canvas_height_padding;
            var inventory_slot = self.inventory.slot(i);

            var square = ANCHOR.nine_slice(self.canvas, 50)
                .set_size(22, 22)
                .set_sprites_from_key("spr_ui_generic_box")
                .set_xy(slot_x, slot_y)
                .add_to_pilot(self.pilot)
                .listen_for_hovers()
                .board_set("index", i)
                .set_think_callback(function(slot_index, inventory_slot) {
                    var slot = self.slots[slot_index];
                    var square = slot.square;
                    var item = slot.item;

                    //
                    if self.show_tooltips_flag && item.get_enabled() && square.hover_duration() >= 30 {
                        var this_item = inventory_slot.item;
                        if self.tooltip == undefined && this_item != undefined { //
                            self.tooltip = create_tooltip(this_item, square, tooltip_on_left);
                        }
                    } else if self.tooltip != undefined && self.tooltip.source_node == square {
                        self.tooltip.close();
                        self.tooltip = undefined;
                    }

                    //
                    if !square.is_hovered() {
                        square.set_sprite(square.enabled_sprite);
                    } else if square.board_get("soft_locked") {
                        if ANCHOR.take_tap() {
                            TANGO.play("SoundEffects/UI/UIUnableToInteract");
                        }
                        square.set_sprite(square.hovered_untappable_sprite);
                    } else {
                        self.input_check(slot_index);

                        var valid = true;
                        if self.hand.is_empty() {
                            valid = item.get_enabled();
                        } else {
                            valid = inventory_slot.valid_for(self.hand.slot(0).item);
                        }

                        if valid {
                            square.set_sprite(square.hovered_sprite);
                        } else if true || ANCHOR.in_directional_control() {
                            square.set_sprite(square.hovered_untappable_sprite);
                        }
                    }
                }, [i, inventory_slot])

            var item = item_node(square);

            if !inventory_slot.required_tags.is_empty() {
                var icon = undefined;
                if inventory_slot.required_tags.contains("head") {
                    icon = spr_ui_journal_inventory_equip_icons_helmet_main;
                } else if inventory_slot.required_tags.contains("chest") {
                    icon = spr_ui_journal_inventory_equip_icons_top_main;
                } else if inventory_slot.required_tags.contains("accessory") {
                    icon = spr_ui_journal_inventory_equip_icons_accessory_main;
                } else if inventory_slot.required_tags.contains("legs") {
                    icon = spr_ui_journal_inventory_equip_icons_pants_main;
                } else if inventory_slot.required_tags.contains("boots") {
                    icon = spr_ui_journal_inventory_equip_icons_shoes_main;
                }

                var tag_icon = ANCHOR.sprite(square)
                    .set_sprite(icon);

                tag_icon.set_think_callback(function(tag_icon, inventory_slot) {
                    tag_icon.set_alpha(inventory_slot.count == 0 ? 1 : 0)
                }, [tag_icon, inventory_slot])
            }

            if i mod row_length == row_length - 1 {
                self.pilot.request_newline();
            }

            array_push(self.slots, {
                square: square,
                item: item,
            });

            self.refresh_slot(self.inventory.slot(i));
        }
    }

    function input_check(index) {
        //
        var hand_slot = self.hand.slot(0);
        var our_slot = self.inventory.slot(index);
        var hand_item = hand_slot.item;
        var hand_count = hand_slot.count;
        var our_item = our_slot.item;
        var our_count = our_slot.count;
        var dir_control = ANCHOR.in_directional_control();

        //
        var main_tapped = dir_control ? ANCHOR.tap_pressed() : INPUT.pressed(InputId.LeftMouse);
        var second_tapped = INPUT.pressed(InputId.PickUpOne);
        var third_tapped = dir_control ? INPUT.pressed(InputId.SecondaryInteract) : false;

        //
        var action = undefined;
        var secondary_behavior = false;
        if hand_item != undefined && our_slot.valid_for(hand_item) {
            if main_tapped || third_tapped {
                action = InventoryAction.PutDown;
            } else if second_tapped && (our_item == undefined || our_item.partial_eq(hand_item)) {
                action = dir_control ? InventoryAction.PutDown : InventoryAction.PickUp;
                secondary_behavior = true;
            }
        } else if our_item != undefined {
            switch self.control_mode {
                case InventoryControlMode.Basic:
                    if main_tapped || second_tapped || third_tapped {
                        action = InventoryAction.PickUp;
                        secondary_behavior = second_tapped;
                    }
                    break;
                case InventoryControlMode.Storage:
                    if main_tapped || second_tapped {
                        if keyboard_check(vk_control) && second_tapped {
                            action = InventoryAction.PickUp;
                            secondary_behavior = true;
                        } else {
                            if dir_control {
                                action = InventoryAction.Transfer;
                            } else {
                                action = keyboard_check(vk_shift)
                                    ? InventoryAction.Transfer
                                    : InventoryAction.PickUp;
                            }
                            secondary_behavior = second_tapped;
                        }
                    } else if third_tapped {
                        action = InventoryAction.PickUp;
                    }
                    break;
                case InventoryControlMode.Transfer:
                    if main_tapped || second_tapped || third_tapped {
                        action = InventoryAction.Transfer;
                        secondary_behavior = second_tapped;
                    }
                    break;
            }
        }

        switch action {
            case InventoryAction.PickUp:
                if secondary_behavior {
                    var amount_to_transfer = keyboard_check(vk_control) ? floor(our_slot.count / 2) : 1;

                    //
                    if amount_to_transfer > 0
                        && our_item != undefined
                        && self.hand.room_for_item(our_item) >= amount_to_transfer
                    {
                        our_slot.remove(amount_to_transfer);
                        hand_slot.add(our_item, amount_to_transfer);
                        self.hand_node.source_inventory = self.inventory;
                    }
                } else {
                    //
                    //
                    var room_for_item = hand_slot.room_for_item(our_item);
                    if hand_item == undefined || room_for_item > 0 {
                        var amount_to_move = min(room_for_item, our_count);
                        our_slot.remove(amount_to_move);
                        hand_slot.add(our_item, amount_to_move);
                        self.hand_node.source_inventory = self.inventory;
                    }
                }
                break;
            case InventoryAction.PutDown:
                var deposit_items = false;
                if our_item != undefined {
                    //
                    if our_item.partial_eq(hand_item) {
                        deposit_items = true;
                    } else if !our_slot.one_slot || hand_slot.count == 1{
                        hand_slot.swap(our_slot);
                        self.hand_node.source_inventory = self.inventory;
                    }
                } else if our_slot.valid_for(hand_item) {
                    deposit_items = true;
                }

                if deposit_items {
                    var amount = secondary_behavior
                        ? 1
                        : min(hand_count, our_slot.room_for_item(hand_item));
                    our_slot.add(hand_item, amount);
                    hand_slot.remove(amount);
                    self.hand_node.source_inventory = self.inventory;
                }
                break;
            case InventoryAction.Transfer:
                //
                var transfer_item = hand_item != undefined ? hand_item : our_item;
                var transfer_slot = hand_item != undefined ? hand_slot : our_slot;
                var transfer_count = hand_item != undefined ? hand_count : our_count;
                var amount_to_transfer = min(
                    self.pair.room_for_item(transfer_item),
                    secondary_behavior ? 1 : transfer_count,
                );
                self.pair.add(transfer_item, amount_to_transfer);
                transfer_slot.remove(amount_to_transfer);
                break;
        }

    }

    function set_to_basic_control() {
        self.control_mode = InventoryControlMode.Basic;
    }

    function set_to_storage_control() {
        self.control_mode = InventoryControlMode.Storage;
    }

    function set_to_transfer_control() {
        self.control_mode = InventoryControlMode.Transfer;
    }

    function show_tooltips(boo=true) {
        self.show_tooltips_flag = boo;
    }

    //
    //
    function transfer_only(boo=true) {
        self.transfer_only_flag = boo; //
        return self;
    }

    function use_cursor() {
        self.cursor = ANCHOR.sprite(self.canvas, 0)
            .set_sprite(spr_ui_inventory_slot_outline_hovered)
            .set_think_callback(function() {
                if
                    self.pilot.get() != undefined
                    && self.pilot.get().is_hovered()
                    && (ANCHOR.get_active_pilot() == self.pilot || ANCHOR.in_point_control())
                    && self.pilot.get().blackboard.contains_key("index") //
                {
                    var node = self.pilot.get();
                    self.cursor.set_alpha(1);
                    var pos = ANCHOR.get_relative_position(node, self.canvas);
                    self.cursor.set_xy(pos.x - 2, pos.y - 2);
                    if !self.hand.is_empty() || self.slots[node.board_get("index")].item.get_enabled() {
                        self.cursor.set_sprite(spr_ui_inventory_slot_outline_hovered);
                    } else {
                        self.cursor.set_sprite(spr_ui_inventory_slot_outline_hovered_untappable);
                    }
                } else {
                    self.cursor.set_alpha(0);
                }
            })
    }

    self.inventory = inventory;
    self.inventory_subscriber = new InventorySubscriber(self.inventory);
    self.row_length = row_length;
    self.use_buy_numbers = use_buy_numbers;
    self.pilot = pilot;
    self.hand = Inventory(1);
    self.hand_subscriber = new InventorySubscriber(self.hand);
    self.hand_node = undefined;
    self.required_tags = List();
    self.pair = undefined;
    self.slots = [];
    self.tooltip = undefined;
    self.show_tooltips_flag = true;
    self.filter_callback = filter_callback;
    self.transfer_only_flag = true;
    self.cursor = undefined;
    self.tooltip_on_left = false;
    self.control_mode = InventoryControlMode.Basic;
    self.play_special_full_sound = false;
}

function calculate_box_size_for_inventory(inventory, row_length, width_padding=10, height_padding=10) {
    var size = inventory.size();
    var rows = ceil(size / row_length);
    var canvas_width =
        width_padding * 2
        + (min(row_length, size) * (INVENTORY_SLOT_SIZE + INVENTORY_SLOT_PADDING))
        - INVENTORY_SLOT_PADDING;
    var canvas_height =
        height_padding * 2
        + (rows * (INVENTORY_SLOT_SIZE + INVENTORY_SLOT_PADDING))
        - INVENTORY_SLOT_PADDING;

    return Vec2(canvas_width, canvas_height);
}

enum InventoryControlMode {
    Basic,
    Storage,
    Transfer,
    Swap,
}

enum InventoryAction {
    PickUp,
    PutDown,
    Transfer,
}
