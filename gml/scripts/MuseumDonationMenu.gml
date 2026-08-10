function spawn_museum_donation_menu() {
    var basket = Inventory(25);
    basket.maximum_item_counts = array_create(ItemId.LEN, 0);
    for (var i = 0; i < ItemId.LEN; i++) {
        if MUSEUM_DATA.museum_items[i] && !MUSEUM_PROGRESS[i] {
            basket.maximum_item_counts[i] = 1;
        }
    }

    var menu = ANCHOR.spawn_menu(Menu.Storage)
        .set_inventories(basket, ARI.inventory)
        .with_right_banner()
        .with_alt_stack_behavior()
        .build();

    menu.left_menu.canvas.add_y(-12);

    menu.left_menu.pilot.request_newline();
    var button = ANCHOR.nine_slice(menu.left_box);
    button
        .set_sprites_from_key("spr_ui_button")
        .set_size(68, 18)
        .set_align(Align.Center, Align.BottomIn)
        .set_y(-27)
        .add_text_label("misc_local/donate", COMMON_LUT, CommonLutIndex.Dark)
        .set_tap_sound("SoundEffects/UI/UIExtraPositiveClick")
        .add_to_pilot(menu.left_menu.pilot)
        .add_hover_outline()
        .set_think_callback(function(button, basket) {
            button.set_unlocked(!basket.is_empty());
        }, [button, basket])
        .set_tap_callback(function(menu, basket) {
            var results = basket.drain().map(function(item) {
                return donate_item_to_museum(item.item_id);
            });

            handle_donation_ui_for_results(results);

            refresh_achievements([
                Requirement.CompletedMuseum,
                Requirement.CompletedMuseumSet,
                Requirement.CompletedMuseumSetWithin,
            ]);

            T2R.write("completed_museum", requirements_pass(ACHIEVEMENTS[Achievement.CelebratedCurator]));

            menu.close();
        }, [menu, basket])

    button.text_label.set_x(6)

    ANCHOR.sprite(button.text_label)
        .set_sprite(spr_ui_bark_icon_museum)
        .set_align(Align.LeftOut, Align.Middle)
        .set_x(3)

    menu.left_menu.set_to_transfer_control();
    menu.right_menu.set_to_transfer_control();

    return menu;
}

//
//
function handle_donation_ui_for_results(results, spawn_popups=true) {
    var completions = results
        .clone()
        .retain(function(result) {
            return result.type == DonationResult.CompletedSet;
        });

    var items_donated = results
        .clone()
        .map(function(result) {
            return result.item_donated;
        });

    if spawn_popups {
        var visited_sets = HashSet();

        var len = results.count();
        for (var i = 0; i < len; i++) {
            var result = results.get(i);
            if result.type == DonationResult.None {
                continue;
            }

            var unique_key = format("{MuseumWing}__{}", result.wing, result.set);
            if visited_sets.insert(unique_key) {
                continue;
            }

            if result.type == DonationResult.ProgressMade {
                await_popup(function(result, items_donated) {
                    new_donation_popup(result.wing, result.set, items_donated);
                }, [result, items_donated]);
            }

            var completion_idx = completions.find(function(completion, wing, set) {
                return completion.wing == wing && completion.set == set;
            }, result.wing, result.set);

            if completion_idx == undefined {
                continue;
            }

            var completion = completions.get(completion_idx);

            array_push(GAME_STATS.set_completions, {
                set: completion.set.name,
                wing: museum_wing_to_string(completion.wing),
                day: total_days(),
            });

            await_popup(function(result) {
                var popup = reward_popup(
                    result.set.display_name,
                    "misc_local/new_reward_unlocked",
                    "misc_local/set_completed",
                    result.rewards,
                );

                popup.title.set_text_style("standard");
                popup.title.set_y(16);
                popup.rainbow_root.set_y(-10);

                result.rewards.for_each(function(reward) {
                    consume_reward(reward).for_each(function(e) {
                        ARI.give_item(e, 1, false, false);
                    });
                });
            }, [completion])
        }
    }
}

function museum_set_popup(wing, set_name) {
    var set = MUSEUM_DATA.data[wing].sets.get(set_name);
    var assets = ListFromArray(set.items);
    var padding = 12;

    var popup = popup_creator("misc_local/placeholder");
    popup.backplate.set_width(202);

    popup.header
        .set_xy(0, 0)
        .set_sprite(spr_ui_tooltip_header_box)
        .set_size(popup.backplate.get_width(), 36)

    popup.title
        .set_align(Align.Center, Align.Middle)
        .set_key(set.display_name)

    var layout = new GridLayout(assets, undefined, assets.count());
    var container_size = layout.container_size();

    popup.backplate.set_height(
        popup.header.get_height() + padding + container_size.y + padding + COMMON_BUTTON_HEIGHT + 10
    );

    var container = ANCHOR.positional(popup.backplate)
        .set_size(container_size)
        .set_align(Align.Center, Align.TopIn)
        .set_y(popup.header.get_height() + padding)

    while layout.has_next() {
        var next = layout.next(container);
        if next.asset != undefined {
            var item = new LiveItem(next.asset);

            next.icon
                .set_sprite(item.get_ui_icon())
                .set_color(MUSEUM_PROGRESS[item.item_id] ? c_white : MUSEUM_LOCKED_OVERLAY)
        }
    }

    popup.create_button("misc_local/close");

    popup.spawn();
}

function new_donation_popup(wing, set, new_items) {
    var popup = popup_creator("misc_local/placeholder", "misc_local/placeholder");
    popup.backplate.set_size(202, 112);

    popup.header
        .set_xy(0, 0)
        .set_sprite(spr_ui_tooltip_header_box)
        .set_size(popup.backplate.get_width(), 36)

    popup.title
        .set_align(Align.Center, Align.Middle)
        .set_key(set.display_name)

    popup.body
        .set_size(popup.backplate.get_width(), 42)
        .set_align(Align.Center, Align.BottomIn)
        .set_sprite(spr_ui_tooltip_new_item_description_box)

    popup.body_text
        .set_align(Align.Center, Align.TopIn)
        .set_y(7)
        .set_text_align(TextAlign.Center)
        .set_key(set.description)

    var assets = ListFromArray(set.items);

    popup.backplate.add_height(popup.body_text.get_height());
    popup.body.add_height(popup.body_text.get_height());

    var columns = min(assets.count(), 8);

    var layout = new GridLayout(assets, undefined, columns);

    var container_size = layout.container_size();
    var container = ANCHOR.positional(popup.body)
        .set_size(container_size)
        .set_align(Align.Center, Align.TopOut)
        .set_xy(-12, -7)

    //
    popup.backplate.add_height(max(0, container_size.y - 24));

    while layout.has_next() {
        var next = layout.next(container);
        if next.asset != undefined {
            var item = new LiveItem(next.asset);

            next.icon
                .set_sprite(item.get_ui_icon())
                .set_color(MUSEUM_PROGRESS[item.item_id] ? c_white : MUSEUM_LOCKED_OVERLAY)

            if new_items.contains(next.asset) {

                var temp = ANCHOR.sprite(next.icon)
                    .set_align(Align.Center, Align.Middle)
                    .set_sprite(next.icon.get_sprite())
                    .set_color(MUSEUM_LOCKED_OVERLAY)

                new_chain()
                    .append(LinkId.Timer, 20)
                    .append(LinkId.Ease, new Ease(EaseId.Linear, 1, 0, 30), function(_, a, temp) {
                        temp.set_alpha(a);
                    }, [temp])
            }
        }
    }

    var progress = museum_set_progress(wing, set.name);
    var set_size = museum_set_size(wing, set.name);
    var percent_sprites = [
        spr_ui_museum_set_progress_0,
        spr_ui_museum_set_progress_20,
        spr_ui_museum_set_progress_40,
        spr_ui_museum_set_progress_60,
        spr_ui_museum_set_progress_80,
        spr_ui_museum_set_progress_100,
    ];
    var count = array_length(percent_sprites);

    if progress == 0 {
        var index = 0;
    } else {
        var index = min(
            floor(progress / set_size * count),
            count - 1,
        );
    }

    ANCHOR.sprite(container)
        .set_align(Align.RightOut, Align.Middle)
        .set_sprite(percent_sprites[index])
        .set_x(4)

    popup.create_button("misc_local/close");

    var ribbon = ANCHOR.nine_slice(popup.header)
        .set_sprite(spr_ui_tooltip_new_item_ribbon_box)
        .set_size(30, 20)
        .set_y(-14)

    ANCHOR.sprite(ribbon)
        .set_sprite(spr_ui_tooltip_new_item_ribbon_left)
        .set_align(Align.LeftOut, Align.Middle)

    var new_text = wavy_text(ribbon, "misc_local/new_exclamation", COMMON_LUT, CommonLutIndex.BlackOnYellow, 1)
        .set_align(Align.LeftIn, Align.Middle)

    ribbon.set_width(new_text.get_width() + 4)

    TANGO.play("SoundEffects/NPCs/DialogSparkle");

    popup.spawn();
}
