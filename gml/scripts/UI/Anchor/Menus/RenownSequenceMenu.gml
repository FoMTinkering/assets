function RenownSequenceMenu() : AnchorMenu(Menu.RenownSequence) constructor {
    self.widget = renown_status_widget(self.canvas);
    self.widget.backplate.set_y(-20);
    self.delay = false;

    self.canvas.set_alpha(0);

    self.progress_bar = new ProgressBar(self.canvas, self.widget);

    self.progress_bar.level_up_callback = function(order) {

        //
        self.delay = true;
        new_chain()
            .append(LinkId.Timer, 60)
            .append(LinkId.Function, function(order) {
                self.delay = false;
                var reward;
                var description;
                if RENOWN.rewards.count() > order.level {
                    reward = RENOWN.rewards.get(order.level);
                    description = "misc_local/new_reward_available";
                } else {
                    reward = undefined;
                    description = "misc_local/congratulations_on_your_hard_work";
                }

                TANGO.play("SoundEffects/UI/RenownLevelUp");

                if MIST.is_running() {
                    return;
                }

                var popup = reward_popup(
                    ANCHOR.wrap_for_local(format("{Local} {}", "misc_local/renown_lvl_insert_caps", order.level + 1)),
                    description,
                    "misc_local/level_up",
                    ListFromArray([reward]),
                    AnchorLayer.AboveFader,
                    -10000, //
                );
                popup.title.set_sprite_font("medium_2");
                popup.title.add_y(5);

                var rank = renown_level_to_rank(order.level + 1);
                ANCHOR.sprite(popup.backplate)
                    .set_align(Align.Center, Align.TopIn)
                    .set_y(-12)
                    .set_speed(1)
                    .set_sprite(rank.sprite);
            }, [order])
    }

    self.progress_bar.level_up_continue_check = function() {
        return !self.delay && ANCHOR.get_menu(Menu.Popup) == undefined;
    }

    var ease_orders = calculate_progress_ease_orders(
        renown_to_level(ARI.renown),
        ARI.renown,
        ARI.pending_renown_entries.sum_with(renown_entry_value),
        self.progress_bar.max_width,
        MAX_RENOWN_LEVEL,
        renown_level_total_cost,
        renown_level_individual_cost,
        function(level) {
            return (level + 1) % RENOWN.levels_per_rank == 0;
        }
    );

    //
    var last = ease_orders.last();
    var player_should_win = last != undefined && last.is_level_up && last.level == MAX_RENOWN_LEVEL - 1;
    if player_should_win && !MIST.is_running() {
        last.is_level_up = false;
        last.is_rank_up = false;
        last.end_percentage = max(0.95, last.start_percentage);
        last.end_position = self.progress_bar.max_width * last.end_percentage;
    }

    self.chain = new_chain()
        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 30), function(_, a) {
            self.canvas.set_alpha(a);
        })

    self.progress_bar.perform_eases(ease_orders, self.chain);

    self.chain
        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 30), function(delta) {
            self.canvas.add_alpha(delta);
        })
        .append(LinkId.Function, function() {
            self.close();
        })
}

function renown_status_widget(parent) {
    var nodes = {};

    nodes.backplate = ANCHOR.nine_slice(parent)
        .set_sprite(spr_ui_renown_status_backplate)
        .set_align(Align.Center, Align.Middle)
        .set_size(130, 66);

    var level = renown_to_level(ARI.renown);
    var rank = renown_level_to_rank(level);

    nodes.star = ANCHOR.sprite(nodes.backplate)
        .set_sprite(rank.sprite)
        .set_align(Align.Center, Align.TopIn)
        .set_y(-12)
        .set_speed(1)

    nodes.text = ANCHOR.text(nodes.backplate)
        .set_text(format("{Local}: {Local}", "misc_local/town_rank", rank.name))
        .set_align(Align.Center, Align.Middle)
        .set_lut(spr_ui_renown_status_font_lut)
        .set_y(-4)

    nodes.backplate.set_width(max(nodes.text.get_width() + 26, 130));

    nodes.level = ANCHOR.text(nodes.backplate)
        .set_text(format("{Local} {}", "misc_local/renown_lvl_insert_caps", level))
        .set_sprite_font("medium_2")
        .set_lut(spr_ui_renown_status_font_lut)
        .set_align(Align.Center, Align.BottomIn)
        .set_y(-16)

    return nodes;
}
