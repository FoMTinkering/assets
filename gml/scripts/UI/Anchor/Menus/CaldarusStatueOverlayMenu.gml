function CaldarusStatueOverlayMenu() : AnchorMenu(Menu.CaldarusStatueOverlay) constructor {
    function in() {
        new_chain()
            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 180), function(_, ab) {
                self.caldarus.set_alpha(ab);
            })
            .append(LinkId.Timer, 5)
            .append(LinkId.Function, function() {
                self.caldarus.set_sprite(spr_farm_dragonstatue_restored_glowing_spring);
            })

    }

    function out() {
        new_chain()
            .join(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 180), function(_, ab) {
                self.caldarus.set_alpha(ab);
            })
            .append(LinkId.Function, function() {
                self.close();
            })
    }

    self.caldarus = ANCHOR.sprite(self.canvas)
        .set_sprite(spr_farm_dragonstatue_restored_spring)
        .set_align(Align.Center, Align.Middle)
        .set_y(-60)
        .set_alpha(0)
        .set_speed(1)
        .set_think_callback(function() {
            //
            var menu = ANCHOR.get_menu(Menu.Textbox);
            if menu != undefined {
                self.caldarus.set_z(menu.canvas.get_z() + 5);
            }
        })
        .set_animation_end_callback(function() {
            self.caldarus.set_sprite(spr_farm_dragonstatue_restored_spring);
        })
}
