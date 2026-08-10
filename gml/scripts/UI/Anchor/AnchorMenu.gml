#macro MENUS global.__menus
global.__menus = undefined;

//
function load_menus() {
    var collection = Map();
    var toml_data = MapWrap(fiddle_get_directory("ui/menus"));
    //
    //
    //
    //
    var default_menu = toml_data.take("default")[$ "default"];
    var file_keys = toml_data.keys();

    //
    for (var i = 0; i < array_length(file_keys); i++) {
        var file_name = file_keys[i];
        var this_file = MapWrap(toml_data.get(file_name));
        var file_default = patch_object(this_file.take("default"), clone_value(default_menu));

        //
        var menu_keys = this_file.keys();
        for (var j = 0; j < array_length(menu_keys); j++) {

            //
            var menu_key = menu_keys[j];
            var menu_data = patch_object(this_file.get(menu_key), clone_value(file_default));
            apply_func(menu_data, function(e) {
                return e == "<n/a>" ? undefined : e;
            });

            //
            switch menu_data.pause {
                case "main":
                    menu_data.pause = PauseStatus.MENU;
                    break;
                case "cutscene":
                    menu_data.pause = PauseStatus.CUTSCENE;
                    break;
                default:
                    menu_data.pause = PauseStatus.EMPTY;
                    break;
            }

            //
            menu_data.layer = string_to_anchor_layer(menu_data.layer);

            //
            collection.insert(string_to_menu(menu_key), menu_data);
        }
    }

    return collection;
}

//
//
function AnchorMenu(type) constructor {
    //
    self.type = type;

    //
    self.data = MENUS.get_unwrap(type);

    //
    //
    self.close_requested = false;

    //
    self.free_requested = false;

    //
    self.pilots = List();

    //
    self.hide_requests = 0;

    //
    self.internal_chain = undefined;

    //
    self.canvas = undefined;

    //
    self.background = undefined;

    //
    //
    self.listen_for_exit_flag = self.data.listen_for_exit;

    //
    function initialize() {
        //
        if self.data.canvas_kind != undefined {
            self.canvas = ANCHOR.canvas(ANCHOR.screen_canvas, 100, self.data.layer)
                .set_align(Align.Center, Align.Middle);

            self.canvas.source_menu = self;
            switch self.data.canvas_kind {
                case "screen":
                    self.canvas.set_size_to_screen();
                    break;
                case "minspec":
                    self.canvas.set_size_to_minspec();
                    break;
                default: impossible("Unexpected canvas_kind for {Menu}: {}", self.type, self.data.canvas_kind);
            }
        }

        //
        if is_world_room(room()) {
            PAUSE_STATUS = set_flag(PAUSE_STATUS, self.data.pause);
        }

        //
        if self.data.has_background {
            assert_neq(self.canvas, undefined, "we can't have a background without a canvas, what are you crazy");
            self.background = new BackgroundMenu(self, AnchorLayer.Hud);
            self.background.in();
        }

        //
        if self.data.sounds != undefined {
            TANGO.play(self.data.sounds.open);
        }

        //
        if self.data.open_transition {
            self.canvas.set_alpha(0);
            self.request_show();
        }
    }

    //
    //
    function on_close() {}

    //
    //
    //
    //
    //
    function on_free() {}

    //
    function on_think() {}

    //
    function think() {
        if self.close_requested {
            return;
        }

        var glyph_count = array_length(self.data.glyph_guides);
        for (var i = 0; i < glyph_count; i++) {
            var guide = self.data.glyph_guides[i];
            GLYPH_GUIDE.set_input(guide[0], guide[1]);
        }

        self.on_think();

        if self.listen_for_exit_flag {
            self.run_exit_listening();
        }
    }

    //
    //
    //
    function run_exit_listening() {
        GLYPH_GUIDE.set_input(InputId.MenuBack, "misc_local/close");
        var is_unlocked = self.canvas != undefined ? self.canvas.is_unlocked() : true;
        if is_unlocked {
            var click_close = false;
            if self.data.backplate_name != undefined {
                click_close = ANCHOR.check_for_click_close(self[$ self.data.backplate_name]);
            }
            if click_close || INPUT.take_press(InputId.MenuBack) {
                self.close();
                return;
            }
        }
    }

    //
    //
    function close(prevent_audio=false) {
        //
        if self.close_requested {
            return;
        }

        //
        self.close_requested = true;

        //
        if !prevent_audio && self.data.sounds != undefined {
            TANGO.play(self.data.sounds.close);
        }

        //
        self.lock();

        //
        if self.data.has_background {
            self.background.out();
        }

        //
        var active_pilot = ANCHOR.get_active_pilot();
        if self.pilots.contains(active_pilot) {
            ANCHOR.release_active_pilot();
        }

        //
        if self.data.close_transition {
            self.request_hide();
            new_chain().append(LinkId.Await, function() {
                if !self.in_transition() {
                    self.free_requested = true;
                    return true;
                }
                return false;
            })
        } else {
            //
            self.free_requested = true;
        }

        //
        self.on_close();
    }

    //
    //
    //
    function free() {
        assert(self.close_requested, "{Menu} freed before close -- use `close` instead of `free`!", self.type);

        //
        if self.canvas != undefined {
            ANCHOR.free_node(self.canvas);
        }
        self.on_free();
    }

    //
    function in_transition() {
        return self.internal_chain != undefined;
    }

    //
    function listen_for_exit(boo=false) {
        self.listen_for_exit_flag = boo;
        return self;
    }

    //
    //
    function new_pilot() {
        var pilot = new Pilot();
        self.pilots.push(pilot);
        return pilot;
    }

    //
    function request_hide(frames) {
        frames = frames == undefined ? self.data.fade_out_frames : frames;
        var instant = frames == 0;
        self.hide_requests += 1;
        if self.hide_requests > 1 && !instant {
            return;
        }
        if self.internal_chain != undefined && self.internal_chain.running {
            CHAINS.cancel_chain(self.internal_chain);
            self.internal_chain = undefined;
        }
        self.lock();
        if instant {
            self.canvas.set_alpha(0);
            self.canvas.disable();
            if self.data.has_background {
                self.background.out_now();
            }
        } else {
            if self.data.has_background {
                self.background.out();
            }
            self.internal_chain = new_chain()
                .append(LinkId.Ease, new Ease(EaseId.QuartOut, self.canvas.get_alpha(), 0, frames), function(_, a) {
                    self.canvas.set_alpha(a);
                })
                .append(LinkId.Function, function() {
                    self.disable();
                    self.internal_chain = undefined;
                });
        }
    }

    //
    function request_show(frames) {
        frames = frames == undefined ? self.data.fade_in_frames : frames;
        var instant = frames == 0;
        self.hide_requests = max(self.hide_requests - 1, 0);
        if self.hide_requests == 0 {
            if self.data.has_background {
                self.background.in();
            }
            self.enable();
            if self.internal_chain != undefined {
                CHAINS.cancel_chain(self.internal_chain);
                self.internal_chain = undefined;
            }
            if instant {
                self.canvas.set_alpha(1);
                if self.data.has_background {
                    self.background.in_now();
                }
                self.unlock();
            } else {
                if self.data.has_background {
                    self.background.in();
                }
                self.internal_chain = new_chain()
                    .append(LinkId.Ease, new Ease(EaseId.QuartOut, self.canvas.get_alpha(), 1, frames), function(_, a) {
                        self.canvas.set_alpha(a);
                    })
                    .append(LinkId.Function, function() {
                        self.internal_chain = undefined;
                        self.unlock();
                    });
            }
        }
    }

    //
    function lock() {
        if self.canvas == undefined {
            return;
        }
        self.canvas.lock();
    }

    //
    function unlock() {
        if self.canvas == undefined {
            return;
        }
        self.canvas.unlock();
    }

    //
    function disable() {
        if self.canvas != undefined {
            self.canvas.disable();
        }
        if self.background != undefined {
            self.background.background.disable();
        }
    }

    //
    function enable() {
        if self.canvas != undefined {
            self.canvas.enable();
        }
        if self.background != undefined {
            self.background.background.enable();
        }
    }

    toString = function() {
        return fmt("Anchor Menu ({Menu})", self.type);
    }

    //
    //
    self.initialize();
}
