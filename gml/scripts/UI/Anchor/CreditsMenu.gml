function CreditsMenu(canvas) : AnchorMenu(Menu.Credits) constructor {

    self.canvas = canvas;
    self.base = ANCHOR.nine_slice(self.canvas)
        .set_sprite(spr_pixel)
        .set_color($543013)
        .set_size_to_screen()

    self.credits = fiddle_get("ui/credits");
    self.chain = undefined;
    self.active_credit = undefined;
    self.special_freeze_signal = undefined;
    self.freeze_signal = false;
    self.canvas = canvas;
    self.spd = 0;
    self.rush = false;

    function on_close() {
        if self.chain.running {
            CHAINS.cancel_chain(self.chain);
        }
    }

    self.canvas.set_think_callback(function() {
        self.rush = keyboard_check(vk_anykey) || mouse_check_button(mb_any) || gamepad_check_any();
        if self.freeze_signal {
            self.spd = 0;
        } else {
            self.spd = self.rush ? -1.5 : -0.4;
        }
    });

    var npc_studio = self.credits.npc_studio;
    self.chain = new_chain();

    var logo = ANCHOR.sprite(self.base)
        .set_align(Align.Center, Align.Middle)
        .set_y(-40)
        .set_sprite(spr_ui_title_screen_fom_logo)
        .set_alpha(0)

    var a_game_by = ANCHOR.text(logo)
        .set_align(Align.Center, Align.BottomOut)
        .set_y(30)
        .set_key("misc_local/a_game_by")

    var a_game_by = ANCHOR.sprite(a_game_by)
        .set_align(Align.Center, Align.BottomOut)
        .set_y(8)
        .set_sprite(spr_ui_title_screen_logo_static)

    //
    //
    self.bpm = 90;
    self.beat_len = (60 / self.bpm) * 60;
    self.fade_len = 25;

    ANCHOR.get_menu(Menu.Title).ready_for_music = true;
    MUSIC_PLAYER.refresh();

    self.chain.append(LinkId.Timer, self.beat_len);


    self.chain.append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, self.beat_len), function(_, a, logo) {
        logo.set_alpha(a);
    }, [logo]);

    self.chain.append(LinkId.Timer, self.beat_len * 3);

    self.chain.append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, self.beat_len), function(_, a, logo) {
        logo.set_alpha(a);
    }, [logo]);

    self.chain.append(LinkId.Timer, self.beat_len * 2 - self.fade_len);

    for (var i = 0; i < array_length(npc_studio); i++) {
        self.chain.append(LinkId.Function, function(entry) {
            var y_mod = entry[$ "secondary_credit"] != undefined ? -5 : 0;
            var name = ANCHOR.text(self.base)
                .set_align(Align.Center, Align.Middle)
                .set_y(-10 + y_mod)
                .set_text(entry.name)
                .force_font(fnt_mistria_birdseed)
                .set_alpha(0)

            var credit = ANCHOR.text(self.base)
                .set_align(Align.Center, Align.Middle)
                .set_y(10 + y_mod)
                .set_alpha(0)
                .set_text(entry.credit)
                .force_font(fnt_mistria_birdseed)
                .set_lut(spr_ui_dialogue_font_lut, 9)


            if entry[$ "secondary_credit"] != undefined {
                ANCHOR.text(credit)
                    .set_align(Align.Center, Align.BottomOut)
                    .set_y(3)
                    .set_text(entry.secondary_credit)
                    .force_font(fnt_mistria_birdseed)
                    .set_lut(spr_ui_dialogue_font_lut, 15)
            }

            self.active_credit = {
                name,
                credit,
                ease_in: new Ease(EaseId.QuartOut, 0, 1, self.fade_len),
                ease_out: new Ease(EaseId.QuartOut, 1, 0, self.fade_len),
                timer: 0,
            };
        }, [npc_studio[i]]);

        self.chain.append(LinkId.Await, function() {
            self.active_credit.timer += self.rush ? 3 : 1;
            var a = self.active_credit.ease_in.calculate_value(self.active_credit.timer);
            self.active_credit.name.set_alpha(a);
            self.active_credit.credit.set_alpha(a);
            if self.active_credit.timer >= self.active_credit.ease_in.duration {
                self.active_credit.timer = 0;
                return true;
            }
            return false;
        });

        self.chain.append(LinkId.Await, function() {
            self.active_credit.timer += self.rush ? 5 : 1;
            if self.active_credit.timer >= (self.beat_len * 4) - (self.fade_len * 2) {
                self.active_credit.timer = 0;
                return true;
            }
            return false;
        });

        self.chain.append(LinkId.Await, function() {
            self.active_credit.timer += self.rush ? 3 : 1;
            var a = self.active_credit.ease_out.calculate_value(self.active_credit.timer);
            self.active_credit.name.set_alpha(a);
            self.active_credit.credit.set_alpha(a);
            return self.active_credit.timer >= self.active_credit.ease_out.duration;
        });

        self.chain.append(LinkId.Function, function() {
            ANCHOR.free_node(self.active_credit.name);
            ANCHOR.free_node(self.active_credit.credit);
            self.active_credit = undefined;
        });

        self.chain.append(LinkId.Timer, self.beat_len);
    }

    function run_additional_group(title, contributors) {
        var root = ANCHOR.positional(self.base)
            .set_align(Align.Center, Align.BottomOut)
            .set_width(300);

        self.chain.append(LinkId.Function, function(root, title, contributors) {

            root.set_think_callback(function(root) {
                root.add_y(self.spd);
            }, [root])

            ANCHOR.text(root)
                .set_text(title)
                .force_font(fnt_mistria_birdseed)
                .set_align(Align.Center, Align.TopIn)
                .set_text_align(TextAlign.Center)

            var yy = 30;
            static INC = 22;
            for (var i = 0; i < array_length(contributors); i++) {
                var entry = contributors[i];

                var node = ANCHOR.text(root)
                    .set_align(Align.LeftIn, Align.TopIn)
                    .set_y(yy)
                    .set_text(entry.credit)
                    .force_font(fnt_mistria_birdseed)

                for (var j = 0; j < array_length(entry.names); j++) {
                    var credit = ANCHOR.text(root)
                        .set_align(Align.RightIn, Align.TopIn)
                        .set_y(yy)
                        .set_text(entry.names[j])
                        .force_font(fnt_mistria_birdseed)
                        .set_lut(spr_ui_dialogue_font_lut, 9)

                    yy += INC;
                }

                yy += INC;
            }

            //
            credit.stop = false;
            credit.disable_lut();
            credit.set_think_callback(function(credit, title) {
                if credit.stop {
                    return;
                }
                if ANCHOR.get_screen_position(credit).y < 200 {
                    self.special_freeze_signal = title;
                    credit.stop = true;
                }
            }, [credit, title])

        }, [root, title, contributors])

        self.chain.append(LinkId.Await, function(title) {
            return self.special_freeze_signal == title;
        }, [title]);
    }

    self.run_additional_group("Additional Contributions", self.credits.additional_contributions);
    self.run_additional_group("Japanese Localization\n8-4, Ltd.", self.credits.eight_four);
    self.run_additional_group("Shloc Ltd.", self.credits.shloc);

    self.chain.append(LinkId.Function, function() {
        self.special_root = ANCHOR.positional(self.base)
            .set_align(Align.Center, Align.BottomOut)
            .set_width(370)
            .set_y(90)
            .set_think_callback(function() {
                self.special_root.add_y(self.spd);
            })

        ANCHOR.text(self.special_root)
            .set_text("Special Thanks")
            .force_font(fnt_mistria_birdseed)
            .set_align(Align.Center, Align.TopIn)

        var contributors = self.credits.special_thanks;
        var yy = 30;
        static INC = 22;
        var align = Align.LeftIn;
        for (var i = 0; i < array_length(contributors); i++) {
            var entry = contributors[i];

            ANCHOR.text(self.special_root)
                .set_y(yy)
                .set_align(align, Align.TopIn)
                .set_text(entry)
                .force_font(fnt_mistria_birdseed)

            switch align {
                case Align.LeftIn:
                    align = Align.RightIn;
                    break;
                case Align.RightIn:
                    align = Align.LeftIn;
                    yy += INC;
                    break;
            }
        }

        yy += 90;
        var licenses = ANCHOR.text(self.special_root)
            .set_text("Thank you to all our open source projects. Licenses included in the projects.")
            .force_font(fnt_mistria_birdseed)
            .set_align(Align.Center, Align.TopIn)
            .set_text_align(TextAlign.Center)
            .set_y(yy)

        yy += 90;
        var fmod = ANCHOR.text(self.special_root)
            .set_text("Made using FMOD Studio by Firelight Technologies Pty Ltd.")
            .force_font(fnt_mistria_birdseed)
            .set_align(Align.Center, Align.TopIn)
            .set_text_align(TextAlign.Center)
            .set_y(yy)

        yy += 120;

        var top = ANCHOR.text(self.special_root)
            .set_text("Thank you to Yasuhiro Wada & Eric Barone")
            .force_font(fnt_mistria_birdseed)
            .set_lut(spr_ui_dialogue_font_lut, 15)
            .set_text_align(TextAlign.Center)
            .set_align(Align.Center, Align.TopIn)
            .set_y(yy)

        var mid = ANCHOR.text(top)
            .set_text("For founding the farm-sim genre we love so dearly,\nand inspiring us to make our own contribution.")
            .set_text_align(TextAlign.Center)
            .force_font(fnt_mistria_birdseed)
            .set_align(Align.Center, Align.BottomOut)
            .set_y(2)

        ANCHOR.text(mid)
            .set_text("And most of all, thank you for playing!")
            .set_text_align(TextAlign.Center)
            .force_font(fnt_mistria_birdseed)
            .set_lut(spr_ui_dialogue_font_lut, 9)
            .set_align(Align.Center, Align.BottomOut)
            .set_y(24)


        //
        mid.set_think_callback(function(mid) {
            var pos = ANCHOR.get_relative_position(mid, self.base)
            if pos.y <= (self.base.get_height() / 2) - 20 {
                self.freeze_signal = true;
            }
        }, [mid])

        self.chain.append(LinkId.Await, function() {
            return self.freeze_signal;
        })

        self.chain.append(LinkId.Timer, 240);

        self.chain.append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 45), function(_, a, node) {
            node.set_alpha(a);
        }, [top]);


        self.chain.append(LinkId.Timer, 60);

        self.chain.append(LinkId.Function, function() {
            var menu = ANCHOR.get_menu(Menu.Title);
            if menu != undefined && menu.top_menu == self {
                menu.transition_back();
            } else {
                self.close();
            }
        });
    })
}
