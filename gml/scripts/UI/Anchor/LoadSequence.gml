#macro LOAD_SEQUENCE global.__load_sequence
global.__load_sequence = undefined;

//
//
//
//
//
//
function LoadSequence() constructor {
    self.active = false;

    self.text = ANCHOR.text(ANCHOR.screen_canvas, 0, AnchorLayer.AboveFader)
        .set_alpha(0)
        .set_align(Align.LeftIn, Align.BottomIn)
        .set_xy(5, -5)

    //
    //
    //
    //
    //
    function start(local_key, callback, args, fade_speed=FADE_SPEED) {
        self.active = true;
        self.text.set_key(local_key);

        SCREEN_FADER.fade_out(fade_speed, function(callback, args) {
            new_chain()
                .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 15), function(_, a) {
                    self.text.set_alpha(a);
                })
                .append(LinkId.Timer, 1) //
                .append(LinkId.Function, function(callback, args) {
                    var result = function_execute_alt(callback, args);
                    if result {
                        self.finish();
                    }
                }, [callback, args])
        }, [callback, args]);
    }

    //
    function finish() {
        new_chain()
            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 15), function(_, a) {
                self.text.set_alpha(a);
            })
            .append(LinkId.Function, function() {
                if !MIST.is_running() {
                    SCREEN_FADER.fade_in();
                }
                self.active = false;
                ANCHOR.free_node(self.text);
            })
    }

    //
    function is_active() {
        return self.active;
    }
}

//
function create_save_notification(callback, args) {
    var node = ANCHOR.text(ANCHOR.screen_canvas, 0, AnchorLayer.AboveFader)
        .set_key("misc_local/save_complete")
        .set_lut(spr_ui_saveload_font_lut, 4)
        .set_align(Align.RightIn, Align.BottomOut)
        .set_x(-4)

    ANCHOR.sprite(node)
        .set_sprite(spr_ui_saveload_icon_save)
        .set_lut(spr_ui_saveload_font_lut, 4)
        .set_align(Align.LeftOut, Align.Middle)
        .set_x(-1)

    //
    var menu = ANCHOR.get_menu(Menu.InfoHud);
    if menu != undefined {
        new_chain()
            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 20), function(_, a, menu) {
                menu.journal_pin.set_alpha(a);
                menu.map_pin.set_alpha(a);
                menu.spell_pin.set_alpha(a);
                menu.mount_pin.set_alpha(a);
            }, [menu])
            .append(LinkId.Timer, 140)
            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 20), function(_, a, menu) {
                menu.journal_pin.set_alpha(a);
                menu.map_pin.set_alpha(a);
                menu.spell_pin.set_alpha(a);
                menu.mount_pin.set_alpha(a);
            }, [menu])
    }

    TANGO.play("SoundEffects/UI/SuccessfulSave");
    var chain = new_chain()
        .append(LinkId.Ease, new Ease(EaseId.ElasticInOut, 0, -18, 60), function(_, a, node) {
            node.set_y(a);
        }, [node])
        .append(LinkId.Timer, 60)
        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 30), function(_, a, node) {
            node.set_alpha(a);
        }, [node])
        .append(LinkId.Function, function(node) {
            ANCHOR.free_node(node);
        }, [node]);
    if callback != undefined {
        chain.append(LinkId.Function, callback, args ?? []);
    }
}
