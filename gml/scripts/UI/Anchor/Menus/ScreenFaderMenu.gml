#macro FADE_SPEED_TRANSITION fiddle_get("ui/menus/misc_menus/screen_fader/fade_speed")
#macro FADE_SPEED_CUTSCENE fiddle_get("ui/menus/misc_menus/screen_fader/cutscene_fade_speed")

#macro SCREEN_FADER global.__screen_fader
global.__screen_fader = undefined;

//
function ScreenFaderMenu() : AnchorMenu(Menu.ScreenFader) constructor {
    //
    //
    //
    //
    function fade_in(duration=FADE_SPEED_TRANSITION, callback=undefined, args=[]) {
        self.end_fade();
        var duration_normalized = self.fade_alpha * duration;
        if duration_normalized == 0 {
            if callback != undefined {
                function_execute_alt(callback, args);
            }
            return;
        }
        self.active_fade = {
            ease: new Ease(EaseId.Linear, self.fade_alpha, 0, duration_normalized),
            timer: 0,
            callback: callback,
            args: args,
        }
    }

    //
    //
    //
    //
    function fade_out(duration=FADE_SPEED_TRANSITION, callback=undefined, args=[]) {
        self.end_fade();
        var duration_normalized = duration - (self.fade_alpha * duration);
        if duration_normalized == 0 {
            if callback != undefined {
                function_execute_alt(callback, args);
            }
            return;
        }
        self.active_fade = {
            ease: new Ease(EaseId.Linear, self.fade_alpha, 1, duration_normalized),
            timer: 0,
            callback: callback,
            args: args,
        }
    }

    //
    function snap_in() {
        self.end_fade();
        self.fade_alpha = 0;
        self.canvas.set_alpha(0);
    }

    //
    function snap_out() {
        self.end_fade();
        self.fade_alpha = 1;
        self.canvas.set_alpha(1);
    }

    //
    function end_fade() {
        if self.active_fade == undefined {
            return;
        }
        var callback = self.active_fade.callback;
        var args = self.active_fade.args;
        self.active_fade = undefined;

        if callback != undefined {
            function_execute_alt(callback, args);
        }
    }

    //
    function is_in() {
        return self.fade_alpha == 0 && self.active_fade == undefined;
    }

    //
    function is_out() {
        return self.fade_alpha == 1 && self.active_fade == undefined;
    }


    self.fade_alpha = 0;
    self.active_fade = undefined;

    self.canvas.set_think_callback(function() {
        if self.active_fade != undefined {
            self.active_fade.timer += 1;
            self.fade_alpha = self.active_fade.ease.calculate_value(self.active_fade.timer);
            if self.active_fade.timer >= self.active_fade.ease.duration + 1 {
                self.end_fade();
            }
        }
        self.canvas.set_alpha(self.fade_alpha);
    })

    self.bkg = ANCHOR.sprite(self.canvas, undefined, AnchorLayer.ScreenFader)
        .set_sprite(spr_pixel)
        .set_color(c_black)
        .lock()
        .set_scale_to_screen()

}
