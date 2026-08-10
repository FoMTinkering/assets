function DaycareMenu() : AnchorMenu(Menu.Daycare) constructor {
    //
    function on_close() {}

    function setup_left_page() {
        if self.left_scroller != undefined {
            self.left_scroller.free();
        }
        if self.left_title != undefined {
            ANCHOR.free_node(self.left_title);
        }
        if self.left_pilot != undefined {
            self.left_pilot.reset();
        }
        self.left_scroller = create_scroller(self.left_body);
        self.left_scroller.subscribe_to_pilot(self.left_pilot, 4, 4);
        self.left_title = title_for_journal(
            "misc_local/your_animals",
            self.left_header,
            spr_ui_ranching_coop_header_icon,
        );

        var entries = populate_scroller_with_farm_buildings(self.left_scroller);

        for (var i = 0; i < entries.count(); i++) {
            var entry = entries.get(i);
            var animal = entry.animal;

            var button = ANCHOR.nine_slice(entry.root)
                .set_align(Align.RightIn, Align.Middle)
                .add_to_pilot(self.left_pilot, true)
                .set_x(-4)
                .set_size(26, 20)
                .set_sprites_from_key("spr_ui_button")
                .add_hover_outline()

            button.set_tap_callback(function(animal, i) {
                if animal.is_incubating {
                    BREEDING_ANIMAL_CTX.animal_name = animal.name;
                    var popup = popup_creator("misc_local/pregnant_cannot_move", "misc_local/pregnant_cannot_move_description");
                    popup.body_text.text = filter_text_for_textbox(popup.body_text.text);
                    popup.create_button("misc_local/close", function() {
                        BREEDING_ANIMAL_CTX.animal_name = undefined;
                    });
                    popup.spawn();
                } else {
                    var popup = popup_creator("misc_local/send_to_daycare", "misc_local/daycare_confirmation");
                    popup.create_button("misc_local/no");
                    popup.create_button("misc_local/yes", function(animal, i) {
                        animal.stable.deregister(animal);
                        DAYCARE.push(animal);

                        //
                        if animal.instance != undefined {
                            instance_destroy(animal.instance);
                        }
                        if animal.idx == ARI.held_animal_id {
                            ARI.held_animal_id = undefined;
                        }

                        var position_for_scroller = self.left_scroller.get_current_y();
                        self.setup_left_page();
                        self.setup_right_page();

                        var target = clamp(i, 0, array_length(self.left_pilot.map) - 1);
                        self.left_pilot.force_select(self.left_pilot.map[target][0]);
                        self.left_scroller.scroll_by_amount(position_for_scroller - 2);
                    }, [animal, i]);
                    popup.spawn();
                }
            }, [animal, i])

            ANCHOR.sprite(button)
                .set_sprites_from_key("spr_ui_ranching_daycare_right_button")
                .set_key_sprite_target(button)
                .set_align(Align.Center, Align.Middle)
        }
    }

    function setup_right_page() {
        self.reset_right_page();

        self.right_title = title_for_journal(
            "misc_local/daycare",
            self.right_header,
            spr_ui_haydenstock_icon_hayden,
        );

        self.right_scroller = create_scroller(self.right_body);
        self.right_scroller.subscribe_to_pilot(self.right_pilot, 4, 4);

        for (var i = 0; i < DAYCARE.count(); i++) {
            var animal = DAYCARE.get(i);
            var availability = availability_for_animal(animal.kind);
            var has_room = availability.empty != 0;
            var entry = new AnimalEntry(animal, self.right_scroller)
                .add_sex_icon()

            entry.animal_icon
                .set_x(4)
                .set_align(Align.RightOut, Align.Middle);

            entry.root.text_label
                .set_align(Align.RightIn, Align.Middle)
                .set_x(-28)

            entry.root.set_alpha(has_room ? 1 : UI_FADE_ALPHA);

            var button = ANCHOR.nine_slice(entry.root)
                .set_align(Align.LeftIn, Align.Middle)
                .set_x(4)
                .add_to_pilot(self.right_pilot, true)
                .set_size(26, 20)
                .set_sprites_from_key("spr_ui_button")
                .set_unlocked(has_room)
                .add_hover_outline()

            button.set_tap_callback(function(animal, i) {
                var popup = popup_creator("misc_local/remove_from_daycare", "misc_local/daycare_remove_confirmation");

                popup.create_button("misc_local/no");
                popup.create_button("misc_local/yes", function(animal, i) {
                    self.lock();
                    ANCHOR.spawn_menu(Menu.FarmBuildingSelection)
                        .restrict_to_animal_size(animal.prototype.core.size)
                        .set_arrival_callback(function() {
                            self.request_hide(true);
                        })
                        .set_end_callback(function(idx, animal, i) {
                            self.request_show(true);
                            self.unlock();
                            if idx != undefined {
                                var stable = find_building(idx).stable;
                                stable.register(animal);
                                DAYCARE.remove(DAYCARE.find_lazy(animal));

                                var position_for_left = self.left_scroller.get_current_y();
                                var position_for_right = self.right_scroller.get_current_y();

                                self.setup_left_page();
                                self.setup_right_page();

                                var target = clamp(i, 0, array_length(self.right_pilot.map) - 1);
                                self.right_pilot.force_select(self.right_pilot.map[target][0]);
                                self.left_scroller.scroll_by_amount(position_for_left - 2);
                                self.right_scroller.scroll_by_amount(position_for_right - 2);

                                ANCHOR.set_active_pilot(self.right_pilot);
                            }
                        }, [animal, i])
                        .start();
                }, [animal, i]);
                popup.spawn();
            }, [animal, i])

            ANCHOR.sprite(button)
                .set_sprites_from_key("spr_ui_ranching_daycare_left_button")
                .set_key_sprite_target(button)
                .set_align(Align.Center, Align.Middle)
        }

        if DAYCARE.is_empty() {
            scroller_none_option(self.right_scroller);
        }
    }

    function reset_right_page() {
        self.right_pilot.reset();
        if self.right_scroller != undefined {
            self.right_scroller.free();
        }
        if self.right_title != undefined {
            ANCHOR.free_node(self.right_title);
        }
    }

    self.left_scroller = undefined;
    self.right_scroller = undefined;
    self.left_title = undefined;
    self.right_title = undefined;
    self.left_pilot = self.new_pilot()
        .allow_vertical_wrapping()
    self.right_pilot = self.new_pilot()
        .allow_vertical_wrapping()

    self.left_pilot.set_neighbor(self.right_pilot, Cardinal.East);
    self.right_pilot.set_neighbor(self.left_pilot, Cardinal.West);

    create_journal_nodes(self.canvas, self);

    self.setup_left_page();
    self.setup_right_page();
    ANCHOR.set_active_pilot(self.left_pilot);
}
