function InfoToastsMenu() : AnchorMenu(Menu.InfoToasts) constructor {

    function on_think() {
        var keys = self.ducks.keys();
        for (var i = 0; i < array_length(keys); i++) {
            var v = self.ducks.get(keys[i]);
            v -= 1;
            if v == 0 {
                self.ducks.remove(keys[i]);
            } else {
                self.ducks.set(keys[i], v);
            }
        }
    }

    self.toasts = List();
    self.base_y = 70;
    self.ducks = Map();

    function create_notification(message, duck, icon=spr_ui_hud_quest_toast_icon) {
        if self.ducks.contains_key(message) {
            return false;
        } else if duck != undefined {
            self.ducks.set(message, duck);
        }
        static TEXT_PADDING = 10;
        static MAX_WIDTH = 180;
        var text_x = 9 + sprite_get_width(icon);
        var max_text_width = MAX_WIDTH - text_x - TEXT_PADDING;

        var local = local_get(message);

        var output = ANCHOR.reflow(local, max_text_width, ANCHOR.get_text_font());

        draw_set_font(ANCHOR.get_text_font());
        var node_size = Vec2(
            min(MAX_WIDTH, text_x + TEXT_PADDING + string_width(output)),
            string_height(output) + 12,
        );

        var node = ANCHOR.nine_slice(self.canvas)
            .set_xy(-node_size.x, self.base_y)
            .set_sprite(spr_ui_hud_quest_toast_box)
            .set_size(node_size)
            .set_align(Align.LeftIn, Align.TopIn)
        node
            .board_set("timer", self.data.duration)
            .board_set("y_chain", undefined)
            .board_set("icon", ANCHOR.sprite(node)
                .set_xy(5, 0)
                .set_sprite(icon)
                .set_align(Align.LeftIn, Align.Middle)
            )
            .board_set("text", ANCHOR.text(node)
                .set_x(text_x)
                .set_key(message)
                .set_max_width(max_text_width)
                .set_lut(COMMON_LUT)
                .set_align(Align.LeftIn, Align.Middle)
                .allow_line_breaks()
                .prevent_spillover()
            )
            .board_set("life_chain", new_chain()
                .join(
                    LinkId.Ease,
                    new Ease(EaseId.QuartOut, 0, node.get_width(), 30),
                    function(delta, _, node) {
                        node.add_x(delta);
                    }, [node]
                )
                .append(LinkId.Await, function(node) {
                    node.board_add("timer", -1);
                    return node.board_get("timer") == 0;
                }, [node])
                .append(
                    LinkId.Ease,
                    new Ease(EaseId.QuartOut, 0, -node.get_width(), 30),
                    function(delta, _, node) {
                        node.add_x(delta);
                    }, [node]
                )
                .append(LinkId.Function, function(node) {
                    ANCHOR.free_node(node);
                    self.toasts.remove(0);
                }, [node])
            );
        self.toasts.push(node);

        //
        var y_sep = 0;
        size = self.toasts.count();
        for (var i = size - 1; i >= 0; --i) {
            var toast = self.toasts.get(i);
            if toast.board_get("y_chain") != undefined {
                CHAINS.cancel_chain(toast.board_get("y_chain"));
            }
            toast.board_set("y_chain", new_chain()
                .join(
                    LinkId.Ease,
                    new Ease(EaseId.QuartOut, toast.get_y(), self.base_y + y_sep, 10),
                    function(_, val, toast) {
                        toast.set_y(val);
                    },
                    [toast]
                )
                .append(LinkId.Function, function(toast) {
                    toast.board_set("y_chain", undefined);
                }, [toast])
            );
            y_sep += toast.get_height();
        }
        return true;
    }
}


//
//
//
//
function create_notification(local_key, duck=undefined, icon=undefined) {
    return ANCHOR.get_menu(Menu.InfoToasts).create_notification(local_key, duck, icon)
}
