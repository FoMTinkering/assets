function ToolbarMenu() : AnchorMenu(Menu.Toolbar) constructor {

    function on_free() {
        //
        if self.active_drag != undefined {
            ANCHOR.free_node(self.active_drag.preview_node);
        }
    }

    //
    function create_preview_node(index) {
        var square = self.slots[index].square;
        var true_pos = ANCHOR.get_screen_position(square);
        return ANCHOR.sprite(ANCHOR.screen_canvas)
            .set_sprite(self.slots[index].item.get_sprite())
            .set_alpha(0.5)
            .set_xy(
                true_pos.x + MOUSE_GUI_X - ANCHOR.last_mouse_press.x,
                true_pos.y + MOUSE_GUI_Y - ANCHOR.last_mouse_press.y,
            )
            .set_layer(AnchorLayer.Popup)
            .set_think_callback(function() {
                var mouse_released = INPUT.released(InputId.LeftMouse);
                self.active_drag.preview_node
                    .add_x(MOUSE_GUI_X - ANCHOR.last_mouse_pos.x)
                    .add_y(MOUSE_GUI_Y - ANCHOR.last_mouse_pos.y);

                //
                if mouse_released {
                    //
                    for (var i = 0; i < 10; i++) {
                        var slot = self.slots[i];
                        var inv_index = i + (10 * self.page);
                        if slot.square.is_hovered() && inv_index != self.active_drag.inventory_index {
                            var slot_one = ARI.inventory.slot(self.active_drag.inventory_index);
                            var slot_two = ARI.inventory.slot(inv_index);
                            slot_one.swap(slot_two);

                            //
                            static BOUNCE_ITEM = function(node) {
                                node.add_y(-4);
                                node.set_alpha(0.5);
                                new_chain()
                                    .join(LinkId.Ease, new Ease(EaseId.ElasticOut, 0, 4, 30), function(delta, _, node) {
                                        node.add_y(delta);
                                    }, [node])
                                    .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 0.5, 30), function(delta, _, node) {
                                        node.add_alpha(delta);
                                    }, [node]);
                            }

                            BOUNCE_ITEM(slot.item);
                            if self.page == self.active_drag.page {
                                BOUNCE_ITEM(self.slots[self.active_drag.index].item);
                            }
                            break;
                        }
                    }

                    //
                    ANCHOR.free_node(self.active_drag.preview_node);
                    self.active_drag = undefined;
                    return;
                }
            })
    }

    //
    function set_cursor_to_index(index) {
        TANGO.play("SoundEffects/UI/UISelectTool");
        var normalized_index = index mod 10;
        self.cursor
            .set_x(5 + 22 * normalized_index)
            .set_index(0)
            .set_speed(1);
        self.cursor_index.set_index((normalized_index + 1) mod 10)
    }

    //
    function update() {
        for (var i = self.page * 10; i < (self.page * 10) + 10; i++) {
            var slot = self.slots[i % 10];

            //
            var inv_slot = ARI.inventory.slot(i);
            if inv_slot.item == undefined {
                slot.item.disable();
                continue;
            }

            //
            slot.item.enable();
            slot.item.set_to_item(inv_slot.item, inv_slot.count);
        }
    }

    function on_think() {
        if !HUD_TARGET {
            return;
        }

        if !instance_exists(obj_ari) {
            return;
        }

        if !self.subscriber.pull().is_empty() {
            self.update();
        }

        self.press_and_hold_reader.process();

        var sig =
            self.press_and_hold_reader.pressed[InputId.ToolbarIncDown]
            - self.press_and_hold_reader.pressed[InputId.ToolbarIncUp];
        if sig == 0 && ARI.inventory.size() > 10 {
            if INPUT.take_press(InputId.NextToolbarTab) {
                sig = 10;
            } else if INPUT.take_press(InputId.LastToolbarTab) {
                sig = -10;
            }
        }

        //
        //
        if sig != 0 {
            var normalized = ARI.held_item_index mod 10;
            var target = normalized + sig;
            var pages = ARI.inventory.size() div 10;
            var page_val = self.page;
            if target >= 10 {
                page_val = wrap(page_val + 1,  pages);
                target = target % 10;
            } else if target < 0 {
                target = 10 - abs(target);
                page_val = wrap(page_val - 1, pages);
            }
            var inventory_target = target + 10 * page_val;

            if ARI.set_held_item_index(inventory_target) && page_val != self.page {
                self.page = page_val;
                self.update();
            }
        }
    }

    self.subscriber = new InventorySubscriber(ARI.inventory);

    self.backplate = ANCHOR.positional(self.canvas)
        .set_xy(0, -7)
        .set_size(218, 20)
        .set_align(Align.Center, Align.BottomIn);

    var tab = function(index, sprite, highlight_sprite) {
        var xx = -1 + (18 * index);
        var node = ANCHOR.sprite(self.backplate);
        node
            .set_xy(xx, -15)
            .set_sprite(sprite)
            .enable_day_night_lut()
            .set_speed(1)
            .set_hover_sound(undefined)
            .board_set("hover_timer", 0)
            .set_think_callback(function(node, index, sprite, highlight_sprite) {
                //
                var needed_size = index == 0 ? 20 : 10 * (index + 1);
                var valid = ARI.inventory.size() >= needed_size;
                node.set_unlocked(valid);
                node.set_alpha(valid ? 1 : 0);
                if !valid {
                    return;
                }

                static DESIRED_Z_MOD = [
                    [0, 1, 2],
                    [1, 0, 1],
                    [2, 1, 0],
                ];

                var base_z = self.backplate.get_z() - 10;
                node.set_z(base_z + DESIRED_Z_MOD[self.page][index]);

                //
                var item_hovered_over_tab = self.active_drag != undefined
                    && node.is_hovered()
                    && index != self.page;
                node.set_sprite(item_hovered_over_tab ? highlight_sprite : sprite);
                if item_hovered_over_tab {
                    node.board_add("hover_timer", 1);
                    if node.board_get("hover_timer") > self.data.tab_hover_time {
                        self.page = index;
                        self.update();
                    }
                } else {
                    node.board_set("hover_timer", 0);
                }
            }, [node, index, sprite, highlight_sprite])
            .set_animation_end_callback(function(node, sprite) {
                if node.get_sprite() == sprite {
                    node.set_speed(0);
                }
            }, [node, sprite])
            .set_tap_callback(function(index) {
                self.page = index;
                var normalized = ARI.held_item_index mod 10;
                ARI.set_held_item_index(normalized + (10 * index));
                self.update();
            }, [index])
            .set_selected_getter(function(index) {
                return self.page == index;
            }, [index])
    }

    self.tabs = [
        tab(0, spr_ui_hud_toolbar_backplate_tab_day_a, spr_ui_hud_toolbar_backplate_tab_highlight_a),
        tab(1, spr_ui_hud_toolbar_backplate_tab_day_b, spr_ui_hud_toolbar_backplate_tab_highlight_b),
        tab(2, spr_ui_hud_toolbar_backplate_tab_day_c, spr_ui_hud_toolbar_backplate_tab_highlight_c),
    ];

    self.active_drag = undefined;
    self.page = 0;

    self.slots = [];
    for (var i = 0; i < 10; i++) {
        var slot_x = 22 * i;
        var square = ANCHOR.sprite(self.backplate);
        square
            .set_xy(slot_x, 1)
            .set_speed(1)
            .set_bbox_offset(0, -3, 0, 2)
            .set_tap_sound(undefined)
            .set_label("toolbar_slot")
            .listen_for_hovers()
            .enable_day_night_lut()
            .set_think_callback(function(index, square) {
                if square.is_hovered() {
                    if obj_ari.fsm.current_state_id() == PlayerState.HoldToUse && self.active_drag != undefined {
                        ANCHOR.free_node(self.active_drag.preview_node);
                        self.active_drag = undefined;
                        return;
                    }
                    //
                    //
                    //
                    //
                    INPUT.take_press(InputId.LeftMouse);
                    var mouse_released = mouse_check_button_released(mb_left);
                    if mouse_released && square.is_hovered() {
                        ARI.set_held_item_index(index + self.page * 10)
                    }

                    var drag =
                        ANCHOR.point_in_node(square, ANCHOR.last_mouse_press.x, ANCHOR.last_mouse_press.y)
                        && point_distance(MOUSE_GUI_X, MOUSE_GUI_Y, ANCHOR.last_mouse_press.x, ANCHOR.last_mouse_press.y) > 4
                        && mouse_check_button(mb_left)

                    //
                    if drag && self.active_drag == undefined && self.slots[index].item.get_enabled() {
                        self.active_drag = {
                            index: index,
                            inventory_index: index + (10 * self.page),
                            page: self.page,
                            preview_node: self.create_preview_node(index),
                        };
                    }
                }

                //
                var hovered_for_drag = self.active_drag != undefined && square.is_hovered();
                if hovered_for_drag {
                    square.set_sprite(spr_ui_hud_toolbar_backplate_slot_highlight);
                } else if index == ARI.held_item_index mod 10 {
                    square.set_sprite(spr_toolbar_slot_selected);
                } else {
                    square.set_sprite(spr_toolbar_slot);
                }
            }, [i, square])

        //
        var item = item_node(square)
            .set_xy(1, 2)
            .set_align(Align.LeftIn, Align.TopIn)
            .set_speed(1);

        item.set_think_callback(function(index, item) {
            item.set_alpha(
                self.active_drag != undefined && self.active_drag.inventory_index == index + (10 * self.page)
                ? 0
                : 1
            )
        }, [i, item])

        //
        array_push(self.slots, {
            square: square,
            item: item,
        });
    }

    self.front_plate = ANCHOR.sprite(self.backplate, 5)
        .set_xy(-8, -4)
        .set_sprite(spr_toolbar_bake)
        .enable_day_night_lut();

    self.cursor = ANCHOR.sprite(self.front_plate)
        .set_xy(5, 1)
        .set_sprite(spr_ui_hud_toolbar_backplate_cursor)
        .set_index(3)
        .set_animation_end_callback(function() {
            self.cursor.set_speed(0);
        })
        .set_think_callback(function() {
            for (var i = 0; i < 10; i++) {
                var input = number_to_input(i);
                if INPUT.pressed(input) {
                    ARI.set_held_item_index((i == 0 ? 9 : i - 1) + self.page * 10);
                    return;
                }
            }
        })
    self.cursor_index = ANCHOR.sprite(self.cursor)
        .set_xy(-8, -8)
        .set_sprite(spr_ui_hud_toolbar_selected_baked_text)
        .set_align(Align.Center, Align.Middle)
        .set_index(1)

    self.press_and_hold_reader = new PressAndHoldReader([InputId.ToolbarIncUp, InputId.ToolbarIncDown]);

    self.update();
}
