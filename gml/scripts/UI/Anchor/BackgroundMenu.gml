//
function BackgroundMenu(menu, anchor_layer, z_offset=0) constructor {
    self.fade_chain = undefined;
    self.target_alpha = fiddle_get("ui/misc/background_alpha");
    self.fade_speed = fiddle_get("ui/menus/default/default/fade_in_frames");

    self.background = ANCHOR.nine_slice(ANCHOR.screen_canvas, z_offset, anchor_layer)
        .set_sprite(spr_pixel)
        .set_color(c_black)
        .set_alpha(0)
        .set_label(fmt("menu_background_{Menu}", menu.type))
        .set_size_to_screen()
        .set_think_callback(function(menu) {
            if menu.close_requested {
                ANCHOR.free_node(self.background);
            }
        }, [menu])

    function set_fade_speed(spd) {
        self.fade_speed = spd;
        return self;
    }

    function in() {
        if self.fade_chain != undefined {
            CHAINS.cancel_chain(self.fade_chain);
        }
        self.fade_chain = new_chain()
            .join(LinkId.Ease, new Ease(EaseId.QuartOut, self.background.get_alpha(), self.target_alpha, self.fade_speed), function(delta) {
                self.background.add_alpha(delta);
            })
            .append(LinkId.Function, function() {
                self.fade_chain = undefined;
            })
    }

    function in_now() {
        if self.fade_chain != undefined {
            CHAINS.cancel_chain(self.fade_chain);
            self.fade_chain = undefined;
        }
        self.background.set_alpha(self.target_alpha);
    }

    function out() {
        if self.fade_chain != undefined {
            CHAINS.cancel_chain(self.fade_chain);
        }
        self.fade_chain = new_chain()
            .join(LinkId.Ease, new Ease(EaseId.QuartOut, self.target_alpha, self.background.get_alpha(), self.fade_speed), function(delta) {
                self.background.add_alpha(delta);
            })
            .append(LinkId.Function, function() {
                self.fade_chain = undefined;
            })
    }

    function out_now() {
        if self.fade_chain != undefined {
            CHAINS.cancel_chain(self.fade_chain);
            self.fade_chain = undefined;
        }
        self.background.set_alpha(0);
    }
}
