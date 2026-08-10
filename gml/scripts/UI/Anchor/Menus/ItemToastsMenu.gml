#macro ITEM_TOAST_BASE_Y (MIST.running || ANCHOR.get_menu(Menu.Textbox) != undefined ? -110 : -32)

function ItemToastsMenu() : AnchorMenu(Menu.ItemToasts) constructor {
    self.toasts = List();

    function create_pickup(item, count) {
        var live_item = is_struct(item) ? item : new LiveItem(item);
        var name_text = live_item.get_display_name();

        //
        var size = toasts.count();
        for (var i = 0; i < size; i++) {
            var toast = toasts.get(i);
            if toast.live_item.partial_eq(live_item) {
                toast.timer = self.data.duration;
                toast.count_text.count += count;
                toast.count_text.set_text("x" + string(toast.count_text.count));
                toast.update_width();
                return;
            }
        }

        //
        var node = ANCHOR.nine_slice(self.canvas)
            .set_y(ITEM_TOAST_BASE_Y)
            .set_sprite(spr_ui_hud_item_toast_box)
            .set_height(24)
            .set_align(Align.RightIn, Align.BottomIn)

        node.update_width = method(node, function() {
            var width = 33;
            width += self.text.get_width();
            width += self.count_text.get_width();
            self.set_width(width);
        });

        node.timer = self.data.duration;
        node.y_chain = undefined;
        node.live_item = live_item;

        node.icon = item_node(node, live_item)
            .set_xy(6, 0)
            .set_align(Align.LeftIn, Align.Middle)

        node.text = ANCHOR.text(node.icon)
            .set_x(3)
            .set_text(name_text)
            .set_align(Align.RightOut, Align.Middle)
            .set_lut(COMMON_LUT)

        node.count_text = ANCHOR.text(node.text)
            .set_xy(4, 1)
            .set_text("x" + string(count))
            .set_sprite_font("player_level")
            .set_align(Align.RightOut, Align.Middle)
            .set_lut(COMMON_LUT)

        node.count_text.count = count;

        node.update_width();
        node.set_x(node.get_width());

        node.life_chain = new_chain()
            .join(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, node.get_x(), 0, 30),
                function(delta, _, node) {
                    node.add_x(delta);
                }, [node]
            )
            .append(LinkId.Await, function(node) {
                node.timer -= 1;
                return node.timer == 0;
            }, [node])
            .append(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, 0, node.get_width(), 30),
                function(delta, _, node) {
                    node.add_x(delta);
                }, [node]
            )
            .append(LinkId.Function, function(node) {
                ANCHOR.free_node(node);
                self.toasts.remove(0);
            }, [node])

        self.toasts.push(node);

        //
        var y_sep = -24;
        var yy = ITEM_TOAST_BASE_Y;
        size = self.toasts.count();
        for (var i = size - 1, j = 0; i >= 0; --i) {
            var toast = self.toasts.get(i);
            if toast.y_chain != undefined {
                CHAINS.cancel_chain(toast.y_chain);
            }
            toast.y_chain = new_chain()
                .join(
                    LinkId.Ease,
                    new Ease(EaseId.QuartOut, toast.get_y(), yy + (j * y_sep), 10),
                    function(delta, _, toast) {
                        toast.add_y(delta);
                    },
                    [toast]
                )
                .append(LinkId.Function, function(toast) {
                    toast.y_chain = undefined;
                }, [toast])
            ++j;
        }
    }
}
