function SellAnimalsMenu() : AnchorMenu(Menu.SellAnimals) constructor {

    function setup_left_page() {
        if self.left_scroller != undefined {
            self.left_scroller.free();
        }
        if self.left_pilot != undefined {
            self.left_pilot.reset();
        }
        self.left_scroller = create_scroller(self.left_body);
        self.left_scroller.subscribe_to_pilot(self.left_pilot, 4, 4);

        self.animals = get_all_animals()
            .retain(function(animal) {
                return !self.basket.contains(animal);
            });

        if self.animals.is_empty() {
            scroller_none_option(self.left_scroller);
            return;
        }

        var blacklist = self.basket
            .map_to(function(v) {
                return v.idx;
            })
            .to_array();

        populate_scroller_with_farm_buildings(self.left_scroller, self.left_pilot, undefined, undefined, blacklist)
            .for_each(function(entry) {
                var animal = entry.animal;
                entry.add_currency_details(animal.sell_value());

                entry.root.set_tap_callback(function(animal) {
                    if animal.is_incubating {
                        BREEDING_ANIMAL_CTX.animal_name = animal.name;
                        var popup = popup_creator("misc_local/pregnant_cannot_sell", "misc_local/pregnant_cannot_sell_description");
                        popup.body_text.text = filter_text_for_textbox(popup.body_text.text);
                        popup.create_button("misc_local/close", function() {
                            BREEDING_ANIMAL_CTX.animal_name = undefined;
                        });
                        popup.spawn();
                    } else {
                        var index = self.left_pilot.position.y;
                        self.basket.push(animal);
                        self.setup_left_page();
                        self.setup_right_page();

                        if ANCHOR.in_directional_control() {
                            self.left_pilot.select_at_index_clamped(index);
                        }
                    }
                }, [animal]);
            });

        ANCHOR.set_active_pilot(self.left_pilot);
    }

    function setup_right_page() {
        self.reset_right_page();

        self.right_scroller = create_scroller(self.right_body);
        self.right_scroller.subscribe_to_pilot(self.right_pilot, 6, 6);

        if self.basket.is_empty() {
            scroller_none_option(self.right_scroller);
            return;
        }

        for (var i = 0; i < self.basket.count(); i++) {
            var animal = self.basket.get(i);

            var entry = new AnimalEntry(animal, self.right_scroller, self.right_pilot)
                .add_sex_icon()
                .add_currency_details(animal.sell_value())

            entry.root.set_tap_callback(function(animal) {
                var index = self.right_pilot.position.y;
                self.basket.remove(self.basket.find_lazy(animal));
                self.setup_left_page();
                self.setup_right_page();

                var node = self.left_pilot.get();
                if node != undefined {
                    ANCHOR.hover_node(node);
                }

                if ANCHOR.in_directional_control() {
                    self.right_pilot.select_at_index_clamped(index);
                    ANCHOR.set_active_pilot(self.right_pilot);
                }
            }, [animal]);
        }

        var total_plate = ANCHOR.nine_slice(self.right_scroller.root)
            .set_xy(3, self.right_scroller.root_bottom_y + 8)
            .set_size(98, 18)
            .set_sprite(spr_ui_journal_animal_rounded_text_box)

        ANCHOR.text(total_plate)
            .set_key("misc_local/total")
            .set_lut(COMMON_LUT)
            .set_align(Align.LeftIn, Align.Middle)
            .set_x(3)

        var currency_icon = ANCHOR.sprite(total_plate)
            .set_sprite(spr_ui_journal_inventory_currency_icon)
            .set_align(Align.RightIn, Align.Middle)
            .set_xy(-3, 1)

        var value = self.basket.sum_with(function(v) {
            return v.sell_value();
        });
        ANCHOR.text(currency_icon)
            .set_align(Align.LeftOut, Align.Middle)
            .set_text(value)
            .set_sprite_font("currency")
            .set_x(-2)
            .set_lut(spr_ui_hud_font_currency_lut, 8)

        ANCHOR.nine_slice(total_plate)
            .set_x(9)
            .set_align(Align.RightOut, Align.Middle)
            .set_size(45, 18)
            .set_sprites_from_key("spr_ui_button")
            .add_text_label("misc_local/sell", COMMON_LUT, CommonLutIndex.Dark)
            .add_to_pilot(self.right_pilot)
            .add_hover_outline()
            .set_tap_callback(function() {
                var key = self.basket.count() == 1
                    ? "misc_local/confirm_sell_animals_singular"
                    : "misc_local/confirm_sell_animals_plural";

                var popup = popup_creator("misc_local/confirmation", key);
                popup.create_button("misc_local/no");
                popup.create_button("misc_local/yes", function() {
                    var value = self.basket.sum_with(function(v) {
                        v.stable.deregister(v);

                        //
                        if FESTIVALS[FestivalId.Animal].is_today() {
                            var path = format(
                                "festival_selected_{AnimalSize}_animal",
                                v.prototype.core.size,
                            );
                            var entry = ARI.quest_artifacts.get(path);
                            if entry == v.idx {
                                ARI.quest_artifacts.remove(path);
                            }
                        }

                        for (var i = 0; i < array_length(GAME_STATS.animals); i++) {
                            var stat = GAME_STATS.animals[i];
                            if stat.idx == v.idx {
                                stat.sold = true;
                                break;
                            }
                        }

                        //
                        if v.instance != undefined {
                            instance_destroy(v.instance);
                        }
                        if v.idx == ARI.held_animal_id {
                            ARI.held_animal_id = undefined;
                        }

                        if v.idx == ARI.mount_mirroring_animal {
                            ARI.mount_mirroring_animal = undefined;
                        }

                        return v.sell_value();
                    });
                    ARI.modify_gold(value);
                    array_push(GAME_STATS.income, {
                        type: "sold_animals",
                        amount: value,
                        day: total_days(),
                    });
                    self.basket.clear();
                    self.setup_left_page();
                    self.setup_right_page();
                    ANCHOR.set_active_pilot(self.left_pilot);
                    self.left_pilot.force_select(self.left_pilot.get(0, 0));
                });
                popup.spawn();

            })

        self.right_scroller.add_vertical_space(34);
    }

    function reset_right_page() {
        self.right_pilot.reset();
        if self.right_scroller != undefined {
            self.right_scroller.free();
        }
        ANCHOR.free_children(self.right_body);
    }

    self.left_scroller = undefined;
    self.right_scroller = undefined;
    self.left_pilot = self.new_pilot()
        .allow_vertical_wrapping()
    self.right_pilot = self.new_pilot()
        .allow_vertical_wrapping()

    self.left_pilot.set_neighbor(self.right_pilot, Cardinal.East);
    self.right_pilot.set_neighbor(self.left_pilot, Cardinal.West);

    self.basket = List();

    create_journal_nodes(self.canvas, self);

    player_gold_prefab(self);

    self.setup_left_page();
    self.setup_right_page();

    self.left_title = title_for_journal(
        "misc_local/your_animals",
        self.left_header,
        spr_ui_ranching_coop_header_icon,
    );

    self.right_title = title_for_journal(
        "misc_local/sell_animals",
        self.right_header,
        spr_ui_haydenstock_icon_hayden,
    );
}
