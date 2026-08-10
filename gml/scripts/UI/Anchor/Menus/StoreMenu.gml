function StoreMenu(store, markup=1) : AnchorMenu(Menu.Store) constructor {
    self.stock = undefined;
    self.basket_total = 0;
    self.store = STORES[store];
    self.categories = undefined;
    self.carousel = undefined;
    self.price_markup = markup;

    //
    obj_ari.set_idle_simple();

    function create_ghost(sprite, parent) {
        var ghost = ANCHOR.sprite(parent)
            .set_sprite(sprite)

        new_chain()
            .join(LinkId.Ease, new Ease(EaseId.Linear, 0, -15, 15), function (delta, _, ghost) {
                ghost.add_y(delta);
            }, [ghost])
            .join(LinkId.Ease, new Ease(EaseId.Linear, 1, 0, 15), function (delta, _, ghost) {
                ghost.add_alpha(delta);
            }, [ghost])
            .append(LinkId.Function, function (ghost) {
                ANCHOR.free_node(ghost);
            }, [ghost])
    }

    function init() {
        ANCHOR.free_children(self.header);
        self.categories = create_store_stock(self.store.id);

        var icons = self.categories.map_to(function(v) {
            return v.icon;
        });

        if self.categories.count() > 1 {
            self.carousel = new Carousel();
            self.carousel.layout = self.data.carousel_layout;
            self.carousel.spawn(icons, self.header, self.carousel_callback);
            ANCHOR.sprite(self.header)
                .set_sprite(spr_ui_store_carousel_window_bg)
                .set_align(Align.Center, Align.Middle)
                .set_z(self.carousel.root.get_z() + 1)
                .set_x(self.carousel.window.get_x())
        }

        self.select_category(0);

        var item = self.stock.first();
        if item != undefined {
            self.spawn_tooltip(item);
        }
    }

    function select_category(index) {
        self.stock = self.categories.get(index).items;
        for (var i = 0, c = self.shelf_item_nodes.count(); i < c; i++) {
            var nodes = self.shelf_item_nodes.get(i);
            var item = self.stock.try_get(i);
            if item != undefined {
                var sprite = item.get_ui_icon();
                var value = item.store_value();
                nodes.icon.enable();
                nodes.icon.unlock();
                nodes.shadow.enable();
                nodes.icon.set_sprite(sprite);
                nodes.price.set_text(round(value * self.price_markup));
            } else {
                nodes.icon.disable();
                nodes.icon.lock();
                nodes.shadow.disable();
            }
        }
        self.update_prices();

        var node = self.shelf_item_nodes.first().icon;
        if self.stock.is_empty() {
            node.enable();
            node.unlock();
            node.set_alpha(0);
            node.listen_for_taps(false);
            if self.tooltip != undefined {
                self.tooltip.close();
                self.tooltip.request_hide(0);
            }
        } else {
            node.set_alpha(1);
            node.listen_for_taps(true);
        }

        if ANCHOR.get_active_pilot() != self.inventory_pilot {
            ANCHOR.set_active_pilot(self.shop_pilot);
        }
    }

    function update_prices() {
        self.basket_total = self.basket.slots.sum_with(function(slot) {
            if slot.count == 0 {
                return 0;
            } else {
                return (slot.item.store_value() * self.price_markup) * slot.count;
            }
        });
        self.total_count
            .set_text(self.basket_total)
            .set_lut_index(self.basket_total > ARI.get_gold() ? 5 : 4);
        var remaining_gold = ARI.get_gold() - self.basket_total;
        var cap = self.stock.count();
        if !DEBUG_ASSERTIONS {
            cap = min(cap, self.shelf_item_nodes.count());
        }
        for (var i = 0; i < cap; i++) {
            var item = self.stock.get(i);
            var text = self.shelf_item_nodes.get(i).price;
            var value = round(item.store_value() * self.price_markup);
            text.set_color(value > remaining_gold ? CANNOT_AFFORD_TEXT_COLOR : c_white);
        }
        self.buy_button.set_unlocked(remaining_gold >= 0 && self.basket_total > 0);
    }

    function carousel_callback(cat_index) {
        self.select_category(cat_index);
        if ANCHOR.get_active_pilot() != self.inventory_pilot {
            self.shop_pilot.goto_default();
            ANCHOR.hover_node(self.shop_pilot.get());
        }
        var item = self.stock.first();
        if item != undefined {
            self.spawn_tooltip(item);
        }
    }

    function spawn_tooltip(item) {
        if self.tooltip != undefined {
            self.tooltip.close();
            self.tooltip.request_hide(0);
        }

        self.tooltip = create_tooltip(item, undefined, false, true, self.price_markup);
        self.tooltip.request_show(0);

        var node_pos = ANCHOR.get_screen_position(self.receipt);
        self.tooltip.backplate
            .set_align(Align.LeftIn, Align.TopIn)
            .set_xy(node_pos.x, node_pos.y + self.receipt.get_height() + 2)
    }

    player_gold_prefab(self, true);
    self.tooltip = undefined;

    self.inventory_pilot = self.new_pilot()
    self.shop_pilot = self.new_pilot()
        .allow_vertical_wrapping()

    self.inventory_pilot.set_neighbor(self.shop_pilot, Cardinal.West);
    self.shop_pilot.set_neighbor(self.inventory_pilot, Cardinal.East);

    self.shelf = ANCHOR.sprite(self.canvas)
        .set_x(20)
        .set_align(Align.LeftIn, Align.Middle)
        .set_sprite(spr_ui_store_backplate)

    self.header = ANCHOR.positional(self.shelf)
        .set_align(Align.Center, Align.TopIn)
        .set_size(140, 21)
        .set_y(11)

    #macro SHELF_ITEM_START_X 30
    #macro SHELF_ITEM_START_Y 42
    #macro SHELF_Y_SPACING 14
    #macro SHELF_ITEM_X_PADDING 10
    #macro SHELF_ITEM_Y_PADDING 9
    #macro SHELF_ITEM_SIZE 20

    //
    static ITEM_SIZE = 20;
    static ROWS = 5;
    static COLUMNS = 5;
    self.shelf_item_nodes = List();
    for (var i = 0; i < ROWS * COLUMNS; i++) {
        var x_slot = i mod COLUMNS;
        var y_slot = i div COLUMNS;
        var xx = SHELF_ITEM_START_X + (x_slot * (ITEM_SIZE + SHELF_ITEM_X_PADDING));
        var yy = SHELF_ITEM_START_Y + (y_slot * (ITEM_SIZE + SHELF_Y_SPACING));

        var shadow_node = ANCHOR.sprite(self.shelf, self.shelf.get_z() - 1)
            .set_xy(xx + 2, yy + 12)
            .set_sprite(spr_ui_generalstore_icon_shadow)
            .set_alpha(0.25)

        var icon_node = ANCHOR.sprite(self.shelf, self.shelf.get_z() - 2);
        icon_node
            .set_xy(xx, yy)
            .board_set("hover_timer", 0)
            .add_to_pilot(self.shop_pilot)
            .enable_tap_repeating()
            .set_think_callback(function(i) {
                if self.stock.is_empty() {
                    return;
                }

                var item = self.stock.get(i);

                var icon = self.shelf_item_nodes.get(i).icon;
                icon.set_outline_sprite(icon.is_hovered() ? item.get_ui_outline() : undefined);

                //
                if
                    icon.is_hovered()
                    && !self.tooltip.item.partial_eq(item)
                {
                    self.spawn_tooltip(item);
                }
            }, [i])
            .set_tap_callback(function(i) {
                var item = self.stock.get(i);
                var can_add = self.basket.can_add(item);

                //
                if item.max_purchase() == 1 {
                    can_add &= !self.basket.slots.any(function(slot, item) {
                        return slot.item != undefined && slot.item.partial_eq(item);
                    }, item)
                }

                if can_add {
                    self.basket.add(item);
                    var icon = self.shelf_item_nodes.get(i).icon;
                    self.create_ghost(icon.get_sprite(), icon);
                    self.update_prices();
                }
            }, [i])

        var price_node = ANCHOR.text(icon_node, self.shelf.get_z() - 3)
            .set_xy(3, 1)
            .set_align(Align.RightIn, Align.BottomIn)
            .set_sprite_font("price")

        ANCHOR.sprite(price_node, self.shelf.get_z() - 4)
            .set_y(1)
            .set_sprite(spr_ui_generalstore_price_currency_icon)
            .set_align(Align.RightOut, Align.BottomIn)

        icon_node.disable();
        icon_node.lock();
        shadow_node.disable();

        self.shelf_item_nodes.push({
            icon: icon_node,
            shadow: shadow_node,
            price: price_node,
        });

        //
        if x_slot == COLUMNS - 1 {
            self.shop_pilot.request_newline();
        }
    }

    self.receipt = ANCHOR.sprite(self.canvas)
        .set_xy(-20, -54)
        .set_align(Align.RightIn, Align.Middle)
        .set_sprite(spr_ui_store_receipt_backplate)

    self.title = ANCHOR.text(self.receipt)
        .set_y(15)
        .set_align(Align.Center, Align.TopIn)
        .set_key(self.store.name)
        .set_lut(COMMON_LUT, CommonLutIndex.Header)
        .allow_line_breaks()
        .prevent_spillover()

    self.total_box = ANCHOR.nine_slice(self.receipt)
        .set_size(104, 18)
        .set_xy(10, -11)
        .set_align(Align.LeftIn, Align.BottomIn)
        .set_sprite(spr_ui_store_total_rounded_text_box)

    self.total_label = ANCHOR.text(self.total_box)
        .set_align(Align.LeftIn, Align.Middle)
        .set_x(4)
        .set_key("misc_local/total")
        .set_lut(COMMON_LUT)

    self.total_icon = ANCHOR.sprite(self.total_box)
        .set_sprite(spr_ui_store_price_currency_icon)
        .set_align(Align.RightIn, Align.Middle)
        .set_xy(-3, 2)

    self.total_count = ANCHOR.text(self.total_icon)
        .set_text("0")
        .set_xy(-1, -1)
        .set_sprite_font("currency")
        .set_align(Align.LeftOut, Align.Middle)
        .set_lut(spr_ui_hud_font_currency_lut, 4)

    self.basket = Inventory(6);

    self.basket_ui = new InventoryMenu(6, self.basket, self.inventory_pilot);

    self.basket_ui.build(
        0,
        3,
        self.receipt,
        Align.Center,
        Align.Middle,
    );

    self.inventory_pilot.request_newline();
    self.buy_button = ANCHOR.nine_slice(self.receipt)
        .set_xy(-16, -10)
        .set_align(Align.RightIn, Align.BottomIn)
        .set_size(45, 18)
        .set_sprites_from_key("spr_ui_button")
        .add_hover_outline()
        .add_text_label("misc_local/buy", COMMON_LUT, CommonLutIndex.Dark)
        .add_to_pilot(self.inventory_pilot)
        .set_tap_sound("SoundEffects/Inventory/StorePurchase")
        .set_tap_callback(function() {
            var l = self.basket.drain();

            l.for_each(function(item) {
                array_push(GAME_STATS.purchases, {
                    type: "store",
                    item: item.pretty_print(),
                    cost: item.store_value(),
                    day: total_days(),
                });
            })

            //
            var item_list_of_lists = List();
            for (var i = 0; i < l.count(); i++) {
                var item = l.get(i);

                //
                if item.prototype.purchased_once_per_year {
                    ARI.annual_item_purchase_bans[item.item_id] = true;
                }

                var idx = item_list_of_lists.find(function(inner_list, item) {
                    return inner_list.first().partial_eq(item) && inner_list.count() < item.prototype.max_stack;
                }, item);

                if idx == undefined {
                    item_list_of_lists.push(List(item));
                } else {
                    item_list_of_lists.get(idx).push(item);
                }
            }

            item_list_of_lists.for_each(function(item_data) {
                ARI.give_item(item_data.first(), item_data.count(), true, false);
            });
            ARI.modify_gold(-self.basket_total);
            self.close();
        })

    self.press_and_hold_reader = new PressAndHoldReader([InputId.LeftMouse, InputId.Interact]);

    self.basket_ui.input_check = function(index) {
        var any = self.press_and_hold_reader.process();

        if any {
            var slot = self.basket_ui.slots[index];
            if !slot.square.is_unlocked() || self.basket.slot(index).count == 0 {
                return;
            }
            if keyboard_check(vk_shift) {
                self.basket.slot(index).drain();
            } else {
                self.basket.slot(index).pop();
            }

            self.update_prices();
        }
    }

    self.on_close = function() {
        if self.tooltip != undefined {
            self.tooltip.close();
        }
    }

    self.init();
}
