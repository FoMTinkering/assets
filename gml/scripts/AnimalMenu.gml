function AnimalMenu() : AnchorMenu(Menu.Animal) constructor {
    self.journal = ANCHOR.get_menu(Menu.Journal);
    self.journal.left_page.set_sprite(spr_ui_journal_book_page_layout_animals_left);
    self.journal.right_page.set_sprite(spr_ui_journal_book_page_layout_animals_right);

    function build_left_page(animal_to_scroll_to) {
        if self.scroller != undefined {
            self.scroller.free();
        }

        self.left_pilot.reset();
        self.scroller = create_scroller(self.journal.left_body);
        self.scroller.subscribe_to_pilot(self.left_pilot);

        //
        if ARI.mount != undefined {
            self.scroller.new_header(spr_ui_journal_mount_horseshoe_icon, "misc_local/mount");

            var entry = new AnimalEntry(ARI.mount, self.scroller, self.left_pilot);

            entry.root.set_selected_getter(function() {
                return self.selected_animal == ARI.mount;
            });
            entry.root.set_tap_callback(function() {
                self.select_animal(ARI.mount);
            });
        }

        //
        if PET.unlocked() {

            self.scroller.new_header(spr_ui_journal_pets_header_icon, "misc_local/pet_noun");

            var entry = new AnimalEntry(PET, self.scroller, self.left_pilot)
                .add_heart_details()
                .add_petting_details()
                .add_sex_icon()

            entry.root.set_selected_getter(function() {
                return self.selected_animal == PET;
            });
            entry.root.set_tap_callback(function() {
                self.select_animal(PET);
            });

            entry.animal_icon.set_think_callback(function(entry) {
                var prototype = PET_PROTOTYPE.variants.get(PET.variant);
                entry.animal_icon.set_sprite(prototype.ui_icon);
                if prototype.lut != undefined {
                    entry.animal_icon.set_lut(prototype.lut, prototype.lut_index);
                } else {
                    entry.animal_icon.disable_lut();
                }
            }, [entry]);

        }

        populate_scroller_with_farm_buildings(self.scroller, self.left_pilot)
            .for_each(function(entry, animal_to_scroll_to) {
                var animal = entry.animal;

                entry.root.set_selected_getter(function(animal) {
                    return self.selected_animal == animal;
                }, [animal]);
                entry.root.set_tap_callback(function(animal) {
                    self.select_animal(animal);
                }, [animal]);

                if animal_to_scroll_to == animal {
                    self.scroller.scroll_by_amount(entry.root.get_y());
                    self.left_pilot.force_select(entry.root);
                }

                entry.add_heart_details();
                entry.add_sex_icon();
                entry.add_food_details();
                entry.add_petting_details();
                entry.add_pregnancy_details();
            }, [animal_to_scroll_to]);
    }

    function build_right_page() {
        self.animal_backplate = ANCHOR.nine_slice(self.journal.right_full_body)
            .set_xy(6, 10)
            .set_size(88, 88)
            .set_sprite(spr_ui_journal_animal_preview_box)

        self.award = ANCHOR.sprite(self.journal.right_full_body)
            .set_xy(8, 13)

        self.detail_zone = ANCHOR.positional(self.journal.right_full_body)
            .set_size(82, 126)
            .set_align(Align.RightIn, Align.TopIn)

        self.type_label = ANCHOR.text(self.detail_zone)
            .set_align(Align.Center, Align.TopIn)
            .set_y(4)
            .set_key("misc_local/type")
            .set_lut(COMMON_LUT)

        self.type_backplate = ANCHOR.nine_slice(self.type_label)
            .set_sprite(spr_ui_journal_animal_rounded_text_box)
            .set_size(74, 16)
            .set_align(Align.Center, Align.BottomOut)
            .set_y(3)

        self.type_field = ANCHOR.text(self.type_backplate)
            .set_align(Align.Center, Align.Middle)
            .set_lut(COMMON_LUT)

        self.appearance_button = ANCHOR.nine_slice(self.type_field)
            .set_align(Align.Center, Align.BottomOut)
            .set_size(74, 22)
            .set_y(14)
            .set_sprites_from_key("spr_ui_button")
            .add_hover_outline()
            .disable()
            .add_to_pilot(self.right_pilot, true)
            .set_tap_callback(function() {
                if self.selected_animal == ARI.mount {
                    self.spawn_steed_appearance_popup();
                } else {
                    spawn_pet_appearance_popup();
                }
            })

        self.appearance_button_icon = ANCHOR.sprite(self.appearance_button)
            .set_sprites_from_key(self.selected_animal == PET
                ? "spr_ui_journal_animal_steed_appearance_icon"
                : "spr_ui_journal_animal_pet_appearance_icon"
            )
            .set_align(Align.Center, Align.Middle)
            .set_key_sprite_target(self.appearance_button)

        self.rarity_label = ANCHOR.text(self.type_backplate)
            .set_align(Align.Center, Align.BottomOut)
            .set_y(6)
            .set_key("misc_local/color_rarity")
            .set_lut(COMMON_LUT)

        self.rarity_backplate = ANCHOR.nine_slice(self.rarity_label)
            .set_sprite(spr_ui_journal_animal_rounded_text_box)
            .set_size(74, 16)
            .set_align(Align.Center, Align.BottomOut)
            .set_y(3)

        self.rarity_field = ANCHOR.text(self.rarity_backplate)
            .set_align(Align.Center, Align.Middle)
            .set_lut(COMMON_LUT)

        self.cosmetic_button = ANCHOR.nine_slice(self.detail_zone)
            .set_align(Align.Center, Align.BottomIn)
            .set_size(74, 22)
            .set_y(-18)
            .set_sprites_from_key("spr_ui_button")
            .add_hover_outline()
            .lock()
            .add_to_pilot(self.right_pilot, true)
            .set_tap_callback(function() {
                if self.selected_animal == PET {
                    self.spawn_pet_cosmetic_popup();
                } else {
                    self.spawn_animal_cosmetic_popup();
                }
            })

        self.cosmetic_button_icon = ANCHOR.sprite(self.cosmetic_button)
            .set_sprites_from_key("spr_ui_journal_animal_cosmetics_button_icon")
            .set_align(Align.Center, Align.Middle)
            .set_key_sprite_target(self.cosmetic_button)
            .set_alpha(0.5)
    }

    function reset_right_page() {
        self.selected_animal = undefined;
        ANCHOR.free_children(self.field_zone);
        ANCHOR.free_children(self.animal_backplate);
        ANCHOR.set_active_pilot(self.left_pilot);
        self.rarity_label.enable();
        self.type_field.enable();
        self.rarity_field.enable();
        self.right_pilot.reset();
        self.award.disable();
        self.appearance_button.disable();
        self.cosmetic_button.disable();
    }

    function select_animal(animal) {
        self.reset_right_page();

        self.selected_animal = animal;

        var dir = Cardinal.East;
        if animal == PET {
            dir = PET_PROTOTYPE.variants.get(PET.variant).preview_direction;
        }

        render_animal_in_ui(self.selected_animal, self.animal_backplate, dir);

        if self.selected_animal == ARI.mount {
            self.appearance_button.enable();
            self.appearance_button.add_to_pilot(self.right_pilot, true);
            self.appearance_button_icon.set_sprites_from_key("spr_ui_journal_animal_steed_appearance_icon");
            self.type_field
                .set_key("misc_local/mist")
                .enable()
            self.rarity_label.disable();
            self.rarity_backplate.disable();
            self.award.disable();
        } else if self.selected_animal == PET {
            self.appearance_button.enable();
            self.appearance_button.add_to_pilot(self.right_pilot, true);
            self.appearance_button_icon.set_sprites_from_key("spr_ui_journal_animal_pet_appearance_icon");
            self.type_field
                .set_key(format("misc_local/{PetKind}", PET.pet_kind()))
                .enable()
            self.rarity_label.disable();
            self.rarity_backplate.disable();
            self.award.disable();
            self.cosmetic_button.enable();
            self.cosmetic_button.unlock();
            self.cosmetic_button.add_to_pilot(self.right_pilot, true);
            self.cosmetic_button_icon.set_alpha(1);
        } else {
            self.appearance_button.disable();
            self.type_field
                .set_key(animal.prototype.core.name)
                .enable()
            self.rarity_label.enable();
            self.rarity_backplate.enable();
            self.rarity_field
                .set_key(format("misc_local/tier_{}", animal.tier()))
                .enable()

            self.cosmetic_button.enable();
            self.cosmetic_button.set_unlocked(!animal.is_baby());
            self.cosmetic_button_icon.set_alpha(!animal.is_baby() ? 1 : 0.5);
            self.cosmetic_button.add_to_pilot(self.right_pilot, true);

            var award_sprite = undefined;
            if animal.festival_tier != undefined {
                var tier_insert = undefined;
                switch animal.festival_tier {
                    case 1:
                        tier_insert = "bronze";
                        break;
                    case 2:
                        tier_insert = "silver";
                        break;
                    case 3:
                        tier_insert = "gold";
                        break;
                }
                award_sprite = try_string_to_asset(format(
                    "spr_ui_journal_animal_icon_festival_{}_{}",
                    animal.prototype.core.size == AnimalSize.Small ? "ribbon" : "trophy",
                    tier_insert,
                ));
            }

            if award_sprite != undefined {
                self.award.enable();
                self.award.set_sprite(award_sprite);
            } else {
                self.award.disable();
            }
        }

        self.fields = new JournalFields(self.field_zone, self.right_pilot);

        self.name_field = self.fields.new_field(spr_ui_generic_animal_name_icon, animal.name, CommonLutIndex.Blue);

        self.name_field.set_tap_callback(function() {
            text_input_popup("misc_local/enter_new_name", self.selected_animal.name, ANIMAL_NAME_MAX_WIDTH, function(txt) {
                self.selected_animal.name = txt;
                self.select_animal(self.selected_animal);
                self.right_pilot.force_select(self.name_field);
            });
        });

        if self.selected_animal == PET {
            //
            self.sex_field = self.fields.new_field(
                self.selected_animal.sex == Sex.Female
                    ? spr_ui_generic_female_icon
                    : spr_ui_generic_male_icon,
                local_get(format("misc_local/{Sex}", self.selected_animal.sex)),
                CommonLutIndex.Standard,
            );

            var job_key = PET.job == undefined
                ? "misc_local/none_alt"
                : format("misc_local/pet_job_{PetJob}", PET.job);

            self.job_field = self.fields.new_field(spr_ui_generic_job_icon, local_get(job_key), CommonLutIndex.Blue);
            self.job_field.set_tap_callback(function() {
                var popup = scrolling_popup("misc_local/select_a_job");

                //
                for (var i = 0; i < PetJob.LEN; i++) {
                    var element = popup.scroller.new_element()
                        .add_text_label(format("misc_local/pet_job_{PetJob}", i))
                        .set_tap_callback(function(popup, job) {
                            popup.close();

                            if PET.job == job {
                                return;
                            }

                            if PET.job_active {
                                if instance_exists(obj_pet) {
                                    instance_destroy(obj_pet);
                                }

                                //
                                if ARI.held_animal_id == PET_ID {
                                    ARI.held_animal_id = undefined;
                                    ARI.held_animal_last_frame = undefined;
                                    ARI.held_item_last_frame = undefined;

                                    //
                                    //
                                    //
                                    if instance_exists(obj_ari)  {
                                        obj_ari.par.remove_held_sprite();
                                        obj_ari.par.unset_modifier(AnimationName.Pickup);
                                        obj_ari.par.held_animal_render_callback = undefined;
                                    }
                                }
                                PET.job = job;

                                //
                                //
                                //
                                if PET.job_active {
                                    PET.location_id = location_for_job(PET.job);
                                    if PET.location_id == CURRENT_LOCATION_ID {
                                        spawn_pet();
                                    }
                                }
                            } else {
                                PET.job = job;
                            }

                            self.job_field.text_node.set_key(format("misc_local/pet_job_{PetJob}", job));
                        }, [popup, i])

                    element.add_to_pilot(popup.pilot, true);
                    element.text_label
                        .set_x(23)
                        .set_align(Align.LeftIn, Align.Middle)

                    var icon = i == PetJob.None
                        ? spr_ui_icon_pet_job_none
                        : PET_PROTOTYPE.job_setup_data[i].icon;

                    element.job_icon = ANCHOR.sprite(element.text_label)
                        .set_sprite(icon)
                        .set_x(-3)
                        .set_align(Align.LeftOut, Align.Middle)
                }

                popup.spawn();
            });

        } else if self.selected_animal != ARI.mount {

            var in_daycare = DAYCARE.contains(self.selected_animal);
            var text;
            var icon;
            if in_daycare {
                text = "In Daycare";
                icon = get_small_npc_icon(NpcId.Hayden);
            } else {
                text = self.selected_animal.stable.building.name;
                icon = spr_ui_generic_animal_barn_icon;
            }
            self.home_field = self.fields.new_field(icon, text, CommonLutIndex.Blue);

            if !in_daycare {
                self.home_field.set_tap_callback(function() {
                    self.journal.lock();

                    if self.selected_animal.is_incubating {
                        BREEDING_ANIMAL_CTX.animal_name = self.selected_animal.name;
                        var popup = popup_creator("misc_local/pregnant_cannot_move", "misc_local/pregnant_cannot_move_description");
                        popup.body_text.text = filter_text_for_textbox(popup.body_text.text);
                        popup.create_button("misc_local/close", function() {
                            BREEDING_ANIMAL_CTX.animal_name = undefined;
                        });
                        popup.spawn();
                    } else {
                        if ARI.held_animal_id == self.selected_animal.idx
                            && self.selected_animal.instance != undefined
                        {
                            self.selected_animal.instance.put_down();
                            ARI.held_animal_id = undefined;
                        }
                        ANCHOR.spawn_menu(Menu.FarmBuildingSelection)
                            .restrict_to_animal_size(self.selected_animal.prototype.core.size)
                            .set_arrival_callback(function() {
                                self.journal.request_hide(0);
                            })
                            .set_end_callback(function(idx) {
                                var old_building_idx = self.selected_animal.stable.building.dyn_index;

                                if idx != undefined && idx != old_building_idx {
                                    var old_building = find_building(old_building_idx);
                                    var new_building = find_building(idx);

                                    old_building.stable.deregister(self.selected_animal);
                                    new_building.stable.register(self.selected_animal);
                                }
                                self.journal.unlock();
                                self.journal.request_show(0);
                                self.build_left_page(self.selected_animal);
                                self.select_animal(self.selected_animal);
                                self.right_pilot.force_select(self.home_field);
                            })
                            .start();
                    }
                });

                if is_dungeon_room(room()) {
                    self.home_field.lock();
                }
            }

            var birthday = localize_date(self.selected_animal.birthday, false);
            self.birthday_field = self.fields.new_field(spr_ui_generic_birthday_icon, birthday, CommonLutIndex.Standard);

            self.sex_field = self.fields.new_field(
                self.selected_animal.sex == Sex.Female
                    ? spr_ui_generic_female_icon
                    : spr_ui_generic_male_icon,
                local_get(format("misc_local/{Sex}", self.selected_animal.sex)),
                CommonLutIndex.Standard,
            );
        }

        self.right_pilot.force_select(self.name_field);
        ANCHOR.set_active_pilot(self.right_pilot);
    }

    function spawn_animal_cosmetic_popup() {
        var popup = popup_creator("misc_local/select_cosmetic");
        popup.backplate.set_size(180, 48);

        var options = ListFromArray(self.selected_animal.prototype.cosmetics.keys());

        if options.is_empty() {
            options.push(I32_MAX, 0);
        } else {
            options.insert(I32_MAX, 0);
        }

        var layout = new GridLayout(options, popup.pilot);

        var container_size = layout.container_size();
        var container = ANCHOR.positional(popup.backplate)
            .set_size(container_size)
            .set_align(Align.Center, Align.Middle)
            .set_y(9)

        popup.backplate.add_height(container_size.y);

        while layout.has_next() {
            var next = layout.next(container);

            if next.asset != undefined {
                var unlocked = ARI.animal_cosmetic_unlocks[self.selected_animal.kind].contains(next.asset);
                var cosmetic_to_set = undefined;
                if next.asset != I32_MAX {
                    cosmetic_to_set = next.asset;
                    var cosmetic = self.selected_animal.prototype.cosmetics.get(next.asset);
                    if unlocked {
                        next.icon.set_sprite(cosmetic.ui_icon);
                        if next.asset == self.selected_animal.cosmetic {
                            popup.pilot.force_select(next.square);
                        }
                    } else {
                        next.icon.set_sprite(spr_ui_generic_lock_icon);
                        next.square.listen_for_taps();
                        next.square.set_tap_sound("SoundEffects/UI/UIUnableToInteract");
                    }
                } else {
                    next.icon.set_sprites_from_key("spr_ui_journal_customization_slot_icon_none");
                }

                if unlocked || cosmetic_to_set == undefined {
                    next.square.set_tap_callback(function(popup, cosmetic_to_set) {
                        self.selected_animal.cosmetic = cosmetic_to_set;
                        self.select_animal(self.selected_animal);
                        self.right_pilot.force_select(self.cosmetic_button);
                        popup.close();

                        var idx = self.selected_animal.idx;

                        if ARI.mount_mirroring_animal == idx {
                            ARI.mount.cosmetic = self.selected_animal.cosmetic;
                        }

                        with obj_player_animal {
                            if self.me.idx == idx {
                                self.set_sprites(self.me.animation);
                            }
                        }
                    }, [popup, cosmetic_to_set]);
                }
            }
        }

        popup.spawn();
    }

    function spawn_pet_cosmetic_popup() {
        var popup = popup_creator("misc_local/select_cosmetic");
        popup.backplate.set_size(180, 48);

        var options = pet_cosmetics(PET.pet_kind());

        if array_is_empty(options) {
            array_push(options, I32_MAX);
        } else {
            array_insert(options, 0, I32_MAX);
        }

        var layout = new GridLayout(ListFromArray(options), popup.pilot);

        var container_size = layout.container_size();
        var container = ANCHOR.positional(popup.backplate)
            .set_size(container_size)
            .set_align(Align.Center, Align.Middle)
            .set_y(9)

        popup.backplate.add_height(container_size.y);

        while layout.has_next() {
            var next = layout.next(container);

            if next.asset != undefined {
                var unlocked = true;
                var cosmetic_to_set = undefined;
                if next.asset != I32_MAX {
                    var cosmetic = PET_PROTOTYPE.cosmetics.get(next.asset);
                    var set = PET_PROTOTYPE.cosmetic_sets.get(cosmetic.cosmetic_set);
                    unlocked = array_contains(ARI.pet_cosmetic_sets_unlocked, cosmetic.cosmetic_set);
                    cosmetic_to_set = next.asset;
                    if unlocked {
                        next.icon.set_sprite(set.ui_icon);
                        if next.asset == PET.cosmetic {
                            popup.pilot.force_select(next.square);
                        }
                    } else {
                        next.icon.set_sprite(spr_ui_generic_lock_icon);
                        next.square.listen_for_taps();
                        next.square.set_tap_sound("SoundEffects/UI/UIUnableToInteract");
                    }
                } else {
                    next.icon.set_sprites_from_key("spr_ui_journal_customization_slot_icon_none");
                }

                if unlocked || cosmetic_to_set == undefined {
                    next.square.set_tap_callback(function(popup, cosmetic_to_set) {
                        PET.cosmetic = cosmetic_to_set;
                        self.select_animal(PET);
                        self.right_pilot.force_select(self.cosmetic_button);
                        popup.close();
                        if instance_exists(obj_pet) {
                            obj_pet.on_alteration();
                        }
                    }, [popup, cosmetic_to_set]);
                }
            }
        }

        popup.spawn();
    }

    function spawn_steed_appearance_popup() {
        var popup = scrolling_popup("misc_local/select_an_appearance");

        var animals = get_all_animals(true)
            .retain(function(a) {
                return a.prototype.mounting.is_mount
                    && !a.is_baby()
                    && points_to_animal_heart_level(a.heart_points) >= 5
                    && ARI.perk_active(Perk.NiceRide);
            });

        if ARI.animal_variant_unlocks[AnimalKind.Horse].contains("giant_chicken_gold") {
            var chicken_gold = create_default_mount("giant_chicken_gold");
            if animals.is_empty() {
                animals.push(chicken_gold);
            } else {
                animals.insert(chicken_gold, 0);
            }
        }
        if ARI.animal_variant_unlocks[AnimalKind.Horse].contains("giant_chicken_white") {
            var chicken_white = create_default_mount("giant_chicken_white");
            if animals.is_empty() {
                animals.push(chicken_white);
            } else {
                animals.insert(chicken_white, 0);
            }
        }

        var mistmare = create_default_mount("mistmare");
        if animals.is_empty() {
            animals.push(mistmare);
        } else {
            animals.insert(mistmare, 0);
        }

        for (var i = 0; i < animals.count(); i++) {

            var animal = animals.get(i);
            var element = popup.scroller.new_element()
                .add_text_label(ANCHOR.wrap_for_local(animal.name))
                .set_tap_callback(function(popup, animal) {
                    popup.close();
                    ARI.mount.prototype = animal.prototype;
                    ARI.mount.kind = animal.kind;
                    ARI.mount.variant = animal.variant;
                    ARI.mount.sex = animal.sex;
                    ARI.mount.cosmetic = animal.cosmetic;
                    ARI.mount_mirroring_animal = animal.idx;
                    ANCHOR.free_children(self.animal_backplate);
                    render_animal_in_ui(ARI.mount, self.animal_backplate);

                    if instance_exists(obj_ari) {
                        obj_ari.change_mount_while_mounted();
                    }
                }, [popup, animal])

            element.add_to_pilot(popup.pilot, true);
            element.text_label
                .set_x(23)
                .set_align(Align.LeftIn, Align.Middle)

            var icon_data = get_animal_icon_data(
                animal.kind,
                animal.variant,
                animal.sex,
                !animal.is_baby(),
            );

            element.animal_icon = ANCHOR.sprite(element.text_label)
                .set_sprite(icon_data.sprite)
                .set_x(-3)
                .set_align(Align.LeftOut, Align.Middle)

            if icon_data.lut != undefined {
                element.animal_icon.set_lut(icon_data.lut, icon_data.lut_index);
            }
        }

        popup.spawn();
    }

    self.scroller = undefined;

    self.left_pilot = self.new_pilot()
        .allow_vertical_wrapping()

    self.right_pilot = self.new_pilot()

    self.title = title_for_journal("misc_local/animals", self.journal.left_header, spr_ui_journal_animal_header_icon)
        .set_think_callback(function() {
            var directional_in_page =
                ANCHOR.get_active_pilot() != self.left_pilot
                && ANCHOR.in_directional_control();
            self.scroller.canvas.set_alpha(!directional_in_page ? 1 : 0.5);
            if directional_in_page {
                GLYPH_GUIDE.set_input(InputId.MenuBack, "misc_local/back");
                if INPUT.take_press(InputId.MenuBack) {
                    self.reset_right_page();
                }
            }
        })

    self.field_zone = ANCHOR.positional(self.journal.right_full_body)
        .set_size(178, 76)
        .set_align(Align.Center, Align.BottomIn)

    self.selected_animal = undefined;

    self.build_left_page();
    self.build_right_page();

    ANCHOR.set_active_pilot(self.left_pilot);
}

//
//
function populate_scroller_with_farm_buildings(scroller, pilot, size_restriction, element_height=40, blacklist) {
    var output = List();

    var buildings = get_buildings()
        .sort_with(function(a, b) {
            return string_alphanumeric_comparison(a.name, b.name);
        })
        .retain(function(v, size_restriction) {
            if v.prototype.player_building_kind != PlayerBuildingKind.Stable
                || (size_restriction != undefined && v.prototype.permitted_animal_size != size_restriction)
            {
                return false;
            }
            return !v.stable.animals().is_empty();
        }, size_restriction);

    for (var i = 0; i < buildings.count(); i++) {
        var building = buildings.get(i);

        var header = scroller.new_header(building_icon(building), ANCHOR.wrap_for_local(building.name));
        var ocarina = DYNAMIC_GRIDS.get(building.dyn_index).ocarina;
        if ocarina != undefined {
            ANCHOR.sprite(header.icon_node)
                .set_sprite(ocarina.essence_supply > 0 ? spr_ui_generic_music_icon_on : spr_ui_generic_music_icon_off)
                .set_align(Align.RightIn, Align.BottomIn)
                .set_xy(1, 1)
        }

        var animals = building
            .stable
            .animals()
            .sort_with(function(a, b) {
                return string_alphanumeric_comparison(a.name, b.name);
            });

        if blacklist != undefined {
            animals.retain(function(v, blacklist) {
                return !array_contains(blacklist, v.idx);
            }, blacklist)
        }

        for (var j = 0; j < animals.count(); j++) {

            var animal = animals.get(j);
            var entry = new AnimalEntry(animal, scroller, pilot, element_height)
                .add_sex_icon()

            output.push(entry);
        }
    }

    if scroller.iterator == 0 {
        scroller_none_option(scroller);
        return output;
    }

    return output;
}


function spawn_pet_appearance_popup() {
    var popup = popup_creator("misc_local/select_an_appearance");
    popup.backplate.set_size(256, 48);

    var order = fiddle_get("ui/misc/pet_variant_order");
    var layout = new GridLayout(ListFromArray(order), popup.pilot, 10);

    var container_size = layout.container_size();
    var container = ANCHOR.positional(popup.backplate)
        .set_size(container_size)
        .set_align(Align.Center, Align.Middle)
        .set_y(9)

    popup.backplate.add_height(container_size.y);

    while layout.has_next() {
        var next = layout.next(container);

        if next.asset != undefined {
            var variant = PET_PROTOTYPE.variants.get(next.asset);
            var unlocked = variant.unlock_key == undefined
                || array_contains(ARI.pet_skin_unlocks, variant.unlock_key);
            next.icon.set_sprite(variant.ui_icon);

            if unlocked {
                if variant.lut != undefined {
                    next.icon.set_lut(variant.lut, variant.lut_index);
                }
                if next.asset == PET.variant {
                    popup.pilot.force_select(next.square);
                }

                next.square.set_tap_callback(function(popup, key) {
                    popup.close();
                    var previous_variant = PET_PROTOTYPE.variants.get(PET.variant);
                    PET.variant = key;
                    if PET.pet_kind() != previous_variant.pet_kind {
                        PET.cosmetic = undefined;
                    }
                    if instance_exists(obj_pet) {
                        obj_pet.on_alteration();
                    } else if PET_PROTOTYPE.variants.get(PET.variant).sprites.contains_key(PET.animation) == false {
                        PET.animation = "idle";
                    }

                    //
                    var menu = ANCHOR.get_menu(Menu.Animal);
                    if menu != undefined {
                        menu.type_field.set_key(format("misc_local/{PetKind}", PET.pet_kind()));
                        ANCHOR.free_children(menu.animal_backplate);
                        var dir = PET_PROTOTYPE.variants.get(PET.variant).preview_direction;
                        render_animal_in_ui(PET, menu.animal_backplate, dir);
                    }
                }, [popup, next.asset]);
            } else {
                next.icon.set_sprite(spr_ui_generic_lock_icon);
                next.square.listen_for_taps();
                next.square.set_tap_sound("SoundEffects/UI/UIUnableToInteract");
            }
        }
    }

    popup.spawn();
}

function run_pet_acquiring_sequence() {
    //
    if STORY_EXECUTOR_RUNNING {
        MIST.blackboard.insert("pet_done", true);
        return;
    }
    spawn_pet_appearance_popup();
    await_popup(function() {
        var popup = create_animal_naming_popup(PET);
        popup.listen_for_exit(false);
        popup.manual_exit_listening = false;
        popup.backplate.set_height(164);
        popup.backplate.set_think_callback(function(popup) {
            GLYPH_GUIDE.set_input(InputId.MenuBack, "misc_local/back");
            if INPUT.take_press(InputId.MenuBack) {
                popup.close();
                await_popup(run_pet_acquiring_sequence);
            }
        }, [popup]);
        popup.add_sex_buttons();
        popup.create_button("misc_local/confirm", function(popup) {
            PET.sex = popup.sex_current;
            PET.name = popup.name_input.get_text();
            MIST.blackboard.insert("pet_done", true);
        }, [popup], undefined, InputId.Interact);

        popup.spawn();
    })
}

function AnimalEntry(animal, scroller, pilot, element_height=40) constructor {
    self.animal = animal;
    self.scroller = scroller;

    self.root = self.scroller.new_element(element_height)
        .add_text_label(ANCHOR.wrap_for_local(animal.name))
        .board_set("animal", animal);

    if pilot != undefined {
        self.root.add_to_pilot(pilot, true);
    }

    self.root.text_label
        .set_think_callback(function() {
            self.root.text_label.set_text(self.animal.name);
        })
        .set_x(23)
        .set_align(Align.LeftIn, Align.Middle)

    self.animal_icon = ANCHOR.sprite(self.root.text_label)
        .set_x(-3)
        .set_align(Align.LeftOut, Align.Middle)

    if self.animal == PET {
        var prototype = PET_PROTOTYPE.variants.get(PET.variant);
        self.animal_icon.set_sprite(prototype.ui_icon);
        if prototype.lut != undefined {
            self.animal_icon.set_lut(prototype.lut, prototype.lut_index)
        }
    } else {
        var icon_data = get_animal_icon_data(
            self.animal.kind,
            self.animal.variant,
            self.animal.sex,
            !self.animal.is_baby(),
        );

        self.animal_icon.set_sprite(icon_data.sprite);
        if icon_data.lut != undefined {
            self.animal_icon.set_lut(icon_data.lut, icon_data.lut_index);
        }
    }

    function shift_basic_details_up() {
        self.root.text_label.set_xy(23, 4);
        self.root.text_label.set_align(Align.LeftIn, Align.TopIn);
        return self;
    }

    function add_sex_icon() {
        self.sex_icon = ANCHOR.sprite(self.animal_icon)
            .set_sprite(animal.sex == Sex.Female ? spr_ui_generic_female_icon : spr_ui_generic_male_icon)
            .set_xy(2, 2)
            .set_align(Align.RightIn, Align.BottomIn)
            .set_sprite(self.animal.sex == Sex.Female ? spr_ui_generic_female_icon : spr_ui_generic_male_icon)

        return self;
    }

    function add_heart_details() {
        self.hearts = ANCHOR.sprite(self.root)
            .set_sprite(spr_ui_journal_animal_heart_level)
            .set_align(Align.RightIn, Align.TopIn)
            .set_xy(-14, 7)

        self.bar = ANCHOR.sprite(self.hearts)
            .set_align(Align.Center, Align.BottomOut)
            .set_xy(-1, 4)
            .set_sprite(spr_ui_journal_relationship_heart_progress_bar)

        self.hearts.set_index(points_to_animal_heart_level(self.animal.heart_points))
        if points_at_max_animal_heart_level(self.animal.heart_points) {
            self.bar.set_index(self.bar.frame_count - 1);
        } else {
            var level = points_to_animal_heart_level(animal.heart_points);
            var current_points = animal_heart_level_to_points(level);
            var target_points = animal_heart_level_to_points(level + 1);
            var distance = target_points - current_points;
            var measure = animal.heart_points - current_points;
            var progress = measure / distance;
            self.bar.set_index(floor(progress * sprite_get_number(spr_ui_journal_relationship_heart_progress_bar)));
        }

        return self;
    }

    function add_petting_details() {
        self.shift_basic_details_up();

        self.pet_icon = ANCHOR.sprite(self.root.text_label)
            .set_sprite(spr_ui_journal_animal_pet_icon)
            .set_align(Align.LeftIn, Align.BottomOut)
            .set_xy(self.animal == PET ? 0 : 27, 4)

        self.pet_check = ANCHOR.sprite(self.pet_icon)
            .set_align(Align.RightOut, Align.Middle)
            .set_x(2)
            .set_sprite(self.animal.has_been_pat ? spr_ui_generic_checkbox_on : spr_ui_generic_checkbox_off)

        return self;
    }

    function add_food_details() {
        self.shift_basic_details_up();

        self.food_icon = ANCHOR.sprite(self.root.text_label)
            .set_sprite(spr_ui_journal_animal_food_icon)
            .set_align(Align.LeftIn, Align.BottomOut)
            .set_y(4)

        self.food_check = ANCHOR.sprite(self.food_icon)
            .set_align(Align.RightOut, Align.Middle)
            .set_x(2)
            .set_sprite(self.animal.has_eaten ? spr_ui_generic_checkbox_on : spr_ui_generic_checkbox_off)

        return self;
    }

    function add_pregnancy_details() {
        self.shift_basic_details_up();

        if self.animal.is_incubating {
            var stork_icon = ANCHOR.sprite(self.root.text_label)
                .set_sprite(spr_ui_journal_animal_stork_icon)
                .set_align(Align.LeftIn, Align.BottomOut)
                .set_xy(52, 5)

            //
            ANCHOR.sprite(stork_icon)
                .set_sprite(spr_ui_generic_checkbox_on)
                .set_align(Align.RightOut, Align.Middle)
                .set_xy(2, -1);
        }
        return self;
    }

    function add_currency_details(value) {
        self.currency_icon = ANCHOR.sprite(self.root)
            .set_align(Align.RightIn, Align.BottomIn)
            .set_xy(-4, -4)
            .set_sprite(spr_ui_journal_inventory_currency_icon)

        self.currency_text = ANCHOR.text(self.currency_icon)
            .set_x(-2)
            .set_sprite_font("currency")
            .set_text(value)
            .set_align(Align.LeftOut, Align.Middle)
            .set_lut(spr_ui_hud_font_currency_lut, 4)

        return self;
    }

    function add_occupancy_details() {
        self.occupancy_icon = ANCHOR.sprite(self.root)
            .set_align(Align.RightIn, Align.BottomIn)
            .set_xy(-4, -4)
            .set_sprite(spr_ui_hud_info_building_icon)

        var availability = availability_for_animal(self.animal.kind);

        self.occupancy_text = ANCHOR.text(self.occupancy_icon)
            .set_x(-2)
            .set_sprite_font("currency")
            .set_text(format("{}/{}", availability.total - availability.empty, availability.total))
            .set_align(Align.LeftOut, Align.Middle)
            .set_lut(spr_ui_hud_font_currency_lut, availability.empty != 0 ? 4 : 5)


        return self;
    }
}
