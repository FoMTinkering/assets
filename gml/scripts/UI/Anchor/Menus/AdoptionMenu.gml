function AdoptionMenu() : AnchorMenu(Menu.Adoption) constructor {
    //
    function on_close() {}

    function setup_left_page(kind_for_pilot) {
        if self.left_scroller != undefined {
            self.left_scroller.free();
        }
        if self.left_title != undefined {
            ANCHOR.free_node(self.left_title);
        }
        if self.left_pilot != undefined {
            self.left_pilot.reset();
        }
        self.left_scroller = create_scroller(self.left_body)
        self.left_scroller.subscribe_to_pilot(self.left_pilot);
        self.left_title = title_for_journal(
            "misc_local/adopt_animals",
            self.left_header,
            spr_ui_haydenstock_icon_hayden,
        );

        for (var i = 0; i < AnimalKind.LEN; i++) {
            var data = ANIMAL_PROTOTYPES[i];
            var dummy = new BaseAnimal(i, data.core.default_icon_variant, Sex.Female);
            dummy.name = animal_is_unlocked(i) ? local_get(data.core.plural_name) : "???";
            var entry = new AnimalEntry(dummy, self.left_scroller, self.left_pilot)
                .add_occupancy_details();

            if !animal_is_unlocked(i) {
                entry.animal_icon.set_color(c_black);
                entry.root.set_soft_locked();
            }

            entry.root
                .set_tap_callback(function(animal_kind) {
                    self.setup_right_page(animal_kind)
                }, [i])
                .set_selected_getter(function(animal_kind) {
                    return self.selected_animal_kind == animal_kind;
                }, [i])

            if i == kind_for_pilot {
                self.pilot.force_select(element);
            }
        }
    }

    function setup_right_page(animal_kind) {
        self.reset_right_page();
        self.selected_animal_kind = animal_kind;

        var animal = ANIMAL_PROTOTYPES[animal_kind];

        var icon_data = get_animal_icon_data(animal_kind);
        self.right_title = title_for_journal(
            animal.core.plural_name,
            self.right_header,
            icon_data.sprite,
        );

        if icon_data.lut != undefined {
            var icon = self.right_title.board_get("icon");
            icon.set_lut(icon_data.lut, icon_data.lut_index);
        }

        //
        self.right_scroller = create_scroller(self.right_body)

        //
        self.right_scroller.subscribe_to_pilot(self.right_pilot);

        var availability = availability_for_animal(animal_kind);
        var has_room = availability.empty > 0;
        var variants = ListFromArray(animal.variants.values());
        variants.retain(function(a) {
            return a.acquirable;
        });
        variants.sort_with(function(a, b) {
            if a.tier == b.tier {
                return string_alphanumeric_comparison(local_get(a.name), local_get(b.name));
            } else {
                return a.tier < b.tier ? -1 : 1;
            }
        });

        for (var i = 0; i < variants.count(); i++) {
            var variant = variants.get(i);
            var gold = animal.pricing.buy_price * animal.pricing.tier_sell_price_multipliers[variant.tier];
            var has_gold = ARI.get_gold() >= gold;
            var unlocked = ARI.animal_variant_unlocks[animal_kind].contains(variant.key);

            var dummy = new BaseAnimal(animal_kind, variant.key, Sex.Female);
            dummy.name = unlocked ? local_get(variant.name) : "???";
            var entry = new AnimalEntry(dummy, self.right_scroller, self.right_pilot)
                .add_currency_details(floor(gold));

            entry.currency_text.set_lut_index(has_gold ? 4 : 5);
            entry.root.set_alpha(has_gold && unlocked && has_room ? 1 : UI_FADE_ALPHA);

            if !unlocked {
                entry.currency_icon.set_alpha(0);
                entry.animal_icon.set_color(c_black);
            } else if has_gold && has_room {
                entry.root.set_tap_callback(function(variant, gold, animal_kind) {
                    self.create_adoption_popup(animal_kind, variant, gold);
                }, [variant, gold, animal_kind])
            }
        }

        //
        ANCHOR.set_active_pilot(self.right_pilot);
    }

    function create_adoption_popup(animal_kind, variant, cost) {
        var dummy_animal = new BaseAnimal(animal_kind, variant.key, Sex.Female);
        var popup = create_animal_naming_popup(dummy_animal);

        popup.cost = cost;
        popup.backplate.set_height(164);
        popup.name_input_plate.add_y(2);

        var price_icon_width = sprite_get_width(spr_ui_journal_inventory_currency_icon);

        var price_text = ANCHOR.text(popup.image_background)
            .set_xy(-price_icon_width / 2, 4)
            .set_sprite_font("currency")
            .set_lut(spr_ui_hud_font_currency_lut, 4)
            .set_text(floor(popup.cost))
            .set_align(Align.Center, Align.BottomOut);

        ANCHOR.sprite(price_text)
            .set_align(Align.RightOut, Align.Middle)
            .set_sprite(spr_ui_journal_inventory_currency_icon);

        popup.add_sex_buttons();

        var cancel_button = popup.create_button("misc_local/cancel");
        popup.create_button("misc_local/confirm", function(popup, dummy_animal) {
            self.lock();
            ANCHOR.spawn_menu(Menu.FarmBuildingSelection)
                .restrict_to_animal_size(ANIMAL_PROTOTYPES[dummy_animal.kind].core.size)
                .set_arrival_callback(function() {
                    self.request_hide(true);
                })
                .set_end_callback(function(idx, popup, dummy_animal) {
                    if idx != undefined {
                        self.adopt_animal_to_building(
                            idx,
                            dummy_animal.kind,
                            popup.sex_current,
                            dummy_animal.variant,
                            popup.cost,
                            popup.name_input.get_text(),
                        );
                    }

                    self.setup_left_page();
                    self.setup_right_page(dummy_animal.kind);
                    self.unlock();
                    self.request_show(0);
                }, [popup, dummy_animal])
                .start();
        }, [popup, dummy_animal]);

        //
        popup.pilot.force_select(cancel_button);

        popup.spawn();
    }

    function adopt_animal_to_building(building_idx, animal_kind, sex, variant, cost, name) {
        if building_idx != undefined {
            //
            ARI.modify_gold(-cost);
            array_push(GAME_STATS.purchases, {
                type: "adoption",
                animal_kind: animal_kind_to_string(animal_kind),
                sex: sex_to_string(sex),
                variant: variant,
                day: total_days(),
                cost: cost,
            });

            //
            var baby = new PlayerAnimal(animal_kind, variant, sex);
            baby.name = name;
            initialize_new_animal_for_ari(baby);
            find_building(building_idx).stable.register(baby);

            //
            array_push(GAME_STATS.animals, {
                source: "adoption",
                animal_kind: animal_kind_to_string(animal_kind),
                sex: sex_to_string(sex),
                variant: variant,
                day: total_days(),
                cost: cost,
                idx: baby.idx
            });
        }
    }

    function reset_right_page() {
        self.selected_animal_kind = undefined;
        self.right_pilot.reset();
        if self.right_scroller != undefined {
            self.right_scroller.free();
        }
        ANCHOR.free_children(self.right_header);
    }

    self.selected_animal_kind = undefined;
    self.left_scroller = undefined;
    self.right_scroller = undefined;
    self.left_title = undefined;
    self.right_title = undefined;
    self.left_pilot = self.new_pilot()
        .allow_vertical_wrapping()
    self.right_pilot = self.new_pilot()
        .allow_vertical_wrapping()

    create_journal_nodes(self.canvas, self);

    self.canvas.set_think_callback(function() {
        //
        var directional_in_page =
            ANCHOR.get_active_pilot() == self.right_pilot
            && ANCHOR.in_directional_control();
        self.left_scroller.canvas.set_alpha(!directional_in_page ? 1 : UI_FADE_ALPHA);
        if directional_in_page {
            GLYPH_GUIDE.set_input(InputId.MenuBack, "misc_local/back");
            if INPUT.take_press(InputId.MenuBack) {
                self.reset_right_page();
                ANCHOR.set_active_pilot(self.left_pilot);
            }
        }
    })

    player_gold_prefab(self);
    self.setup_left_page();
    ANCHOR.set_active_pilot(self.left_pilot);
}

function create_animal_naming_popup(animal_to_render) {
    var popup = create_naming_popup();
    popup.sex_current = animal_to_render.sex;
    popup.variant = animal_to_render.variant;
    popup.animal = render_animal_in_ui(animal_to_render, popup.image_background);
    popup.name_input.set_text(animal_to_render.name);

    popup.random_button.set_tap_callback(function(popup) {
        var name = popup.name_input.get_text();
        var new_name = name;
        while new_name == name {
            new_name = random_animal_name(popup.sex_current);
        }
        popup.name_input.set_text(new_name);
    }, [popup])

    popup.add_sex_buttons = method(popup, function() {
        var female_button = ANCHOR.nine_slice(self.inner_backplate)
            .set_align(Align.LeftIn, Align.BottomOut)
            .set_xy(40, 5)
            .set_size(22)
            .add_to_pilot(self.pilot)
            .set_sprites_from_key("spr_ui_button")
            .add_hover_outline()
            .set_tap_callback(function() {
                self.sex_current = Sex.Female;
            })

        ANCHOR.sprite(female_button)
            .set_sprites_from_key("spr_ui_ranching_adoption_female_button")
            .set_align(Align.Center, Align.Middle)
            .set_key_sprite_target(female_button)

        var female_check = ANCHOR.sprite(female_button)
            .set_align(Align.LeftOut, Align.Middle)
            .set_x(-4)
            .set_tap_callback(function(female_button) {
                ANCHOR.tap_node(female_button);
            }, [female_button])

        female_check.set_think_callback(function(female_check) {
            female_check.set_sprite(self.sex_current == Sex.Female
                ? spr_ui_generic_checkbox_on
                : spr_ui_generic_checkbox_off
            );
        }, [female_check])

        var male_button = ANCHOR.nine_slice(self.inner_backplate)
            .set_align(Align.RightIn, Align.BottomOut)
            .set_xy(-40, 5)
            .set_size(22)
            .add_to_pilot(self.pilot, true)
            .add_hover_outline()
            .set_sprites_from_key("spr_ui_button")
            .set_tap_callback(function() {
                self.sex_current = Sex.Male;
            })

        ANCHOR.sprite(male_button)
            .set_sprites_from_key("spr_ui_ranching_adoption_male_button")
            .set_align(Align.Center, Align.Middle)
            .set_key_sprite_target(male_button)

        var male_check = ANCHOR.sprite(male_button)
            .set_sprite(spr_ui_generic_checkbox_off)
            .set_align(Align.RightOut, Align.Middle)
            .set_x(4)
            .set_tap_callback(function(male_button) {
                ANCHOR.tap_node(male_button);
            }, [male_button])

        male_check.set_think_callback(function(male_check) {
            male_check.set_sprite(self.sex_current == Sex.Male
                ? spr_ui_generic_checkbox_on
                : spr_ui_generic_checkbox_off
            );
        }, [male_check])
    });

    return popup;
}
