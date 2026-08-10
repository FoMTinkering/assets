#macro GLYPH_GUIDE global.__glyph_guide
global.__glyph_guide = undefined;

enum GlyphGuidePriority {
    Low,
    Normal,
    High,
}

function GlyphGuideMenu() : AnchorMenu(Menu.GlyphGuide) constructor {
    function set_input(input_id, local_key, priority=GlyphGuidePriority.High) {
        //
        //
        //
        //
        //
        //
        //
        //
        //
        //
        //
        //
        //
        //
        //


        var binding = BINDINGS.get_primary_binding(input_id);
        var new_keycode = binding != undefined ? binding.keycode : undefined;
        for (var i = 0 ; i < InputId.LEN; i++) {
            var current = self.inputs[i];

            //
            if current == undefined || i == input_id {
                continue;
            }

            var binding = BINDINGS.get_primary_binding(i);

            if binding != undefined && binding.keycode == new_keycode {
                if priority > current.priority {
                    self.inputs[i] = undefined;
                    //
                    break;
                } else {
                    return;
                }
            }
        }

        var current = self.inputs[input_id];
        if current == undefined {
            self.inputs[input_id] = {
                input_id: input_id,
                local_key: undefined,
                triggered_this_frame: undefined,
                priority: undefined,
            };
            current = self.inputs[input_id];
        }

        //
        //
        //
        if current.triggered_this_frame && current.priority >= priority {
            return;
        }

        if current.local_key != local_key {
            self.want_reset = true;
        }

        //
        current.local_key = local_key;
        current.priority = priority;
        current.triggered_this_frame = true;
    }

    function process() {
        if instance_exists(Game) && MIST.running && !MIST.active_cutscene.allow_glyph_guide {
            self.canvas.set_alpha(0);
        }

        var defined_inputs = 0;
        var undefined_inputs = 0;
        //
        for (var i = 0; i < InputId.LEN; i++) {
            var input_data = self.inputs[i];
            if input_data == undefined {
                undefined_inputs += 1;
                continue;
            }

            defined_inputs += 1;

            if input_data.triggered_this_frame == false {
                self.inputs[i] = undefined;
                undefined_inputs += 1;
                self.want_reset = true;
            } else {
                input_data.triggered_this_frame = false;
            }
        }

        //
        //
        if defined_inputs == 0 && self.want_reset == false {
            return;
        }

        //
        //
        if undefined_inputs == InputId.LEN {
            if self.canvas.is_unlocked() {
                self.request_hide();
            }
            return;
        }

        if self.want_reset {
            self.want_reset = false;

            //
            self.request_show();

            //
            ANCHOR.free_children(self.backplate);

            self.backplate.set_size(GLYPH_GUIDE_BACKPLATE_BASE_WIDTH, GLYPH_GUIDE_BACKPLATE_BASE_HEIGHT);
            var counter = 0;
            for (var i = 0; i < InputId.LEN; i++) {
                var input_data = self.inputs[i];
                if input_data == undefined {
                    continue;
                }
                add_glyph_to_backplate(self.backplate, input_data, counter);

                counter += 1;
            }
        }
    }

    self.disable();

    #macro GLYPH_GUIDE_BACKPLATE_BASE_WIDTH 55
    #macro GLYPH_GUIDE_BACKPLATE_BASE_HEIGHT 7
    self.backplate = ANCHOR.nine_slice(self.canvas)
        .set_xy(4, -4)
        .set_align(Align.LeftIn, Align.BottomIn)
        .set_sprite(spr_ui_generalstore_prompt_box)
        .set_size(GLYPH_GUIDE_BACKPLATE_BASE_WIDTH, GLYPH_GUIDE_BACKPLATE_BASE_HEIGHT)

    self.canvas.set_alpha(0);
    self.inputs = array_create(InputId.LEN, undefined);
    self.want_reset = false;
}

function add_glyph_to_backplate(backplate, input_data, counter=0) {
    backplate.add_height(18);

    var display = get_display_for_input_id(input_data.input_id);
    var glyph = ANCHOR.sprite(backplate);
    glyph.previous_input_type = INPUT.active_input_type;
    glyph
        .set_align(Align.LeftIn, Align.TopIn)
        .set_xy(2, (18 * counter) + 4)
        .set_sprite(display.big_sprite)
        .set_index(display.index)
        .set_color(display.index == 0 ? c_black : c_white)
        .set_think_callback(function(glyph, input_id) {
            if glyph.previous_input_type != INPUT.active_input_type  {
                glyph.previous_input_type = INPUT.active_input_type;
                var display = get_display_for_input_id(input_id);
                glyph.set_sprite(display.big_sprite);
                glyph.set_index(display.index);
                glyph.set_color(display.index == 0 ? c_black : c_white);
                glyph.text.set_alpha(display.index == 0 ? 0.75 : 1);
            }
        }, [glyph, input_data.input_id]);

    glyph.text = ANCHOR.text(glyph)
        .set_key(input_data.local_key)
        .set_align(Align.RightOut, Align.Middle)
        .set_x(4)
        .set_alpha(display.index == 0 ? 0.75 : 1);

    var width =
        16
        + sprite_get_width(glyph.get_sprite())
        + string_width_font(local_get(input_data.local_key));
    if width > backplate.get_width() {
        backplate.set_width(width);
    }

    return glyph;
}

function create_skip_prompt_for_mist(delay_frames, hold_frames, scene_key) {
    var backplate = ANCHOR.nine_slice(ANCHOR.screen_canvas)
        .set_xy(4, 4)
        .set_align(Align.LeftIn, Align.TopIn)
        .set_sprite(spr_ui_generalstore_prompt_box)
        .set_size(GLYPH_GUIDE_BACKPLATE_BASE_WIDTH, GLYPH_GUIDE_BACKPLATE_BASE_HEIGHT)
        .set_layer(AnchorLayer.AboveFader)
        .set_alpha(0);


    backplate.chain = undefined;
    backplate.scene_key = scene_key;

    backplate.set_think_callback(function(backplate) {
        if !MIST.is_running() || MIST.active_cutscene.id != backplate.scene_key {
            if backplate.chain != undefined {
                CHAINS.cancel_chain(backplate.chain);
                backplate.chain = undefined;
            }
            ANCHOR.free_node(backplate);
            return;
        }
    }, [backplate]);

    backplate.delay_frames = delay_frames;
    backplate.hold_frames = hold_frames;
    backplate.timer = 0;
    backplate.stage = 0;

    backplate.chain = new_chain()
        .append(LinkId.Await, function(backplate) {
            if MIST.blackboard.get("block_skip") == true {
                return false;
            } else if backplate.timer >= backplate.delay_frames {
                backplate.timer = 0;
                return true;
            } else {
                backplate.timer += 1;
                return false;
            }
        }, [backplate])
        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 40), function(_, a, backplate) {
            backplate.set_alpha(a);
        }, [backplate])
        .append(LinkId.Await, function(backplate) {
            if backplate.timer >= backplate.hold_frames + backplate.delay_frames {
                return true;
            } else {
                backplate.timer += 1;
                return false;
            }
        }, [backplate])
        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 40), function(_, a, backplate) {
            backplate.set_alpha(a);
        }, [backplate])
        .append(LinkId.Function, function(backplate) {
            ANCHOR.free_node(backplate);
            backplate.chain = undefined;
        }, [backplate])

    add_glyph_to_backplate(backplate, {
        input_id: InputId.MenuBack,
        local_key: "misc_local/skip",
    });
}
