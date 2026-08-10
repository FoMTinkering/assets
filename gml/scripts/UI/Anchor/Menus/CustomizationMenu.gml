#macro ARI_NAME_MAX_WIDTH 143
#macro FARM_NAME_MAX_WIDTH 143

function CustomizationMenu(journal_nodes, ari, preset_override, creation_behavior=false) : AnchorMenu(Menu.Customization) constructor {

    function slot_has_new_cosmetics(par_ui_slot) {
        if is_menu_room(room()) {
            return false;
        }

        var sub_categories = CUSTOMIZATION_UI_DATA.get(par_ui_slot);
        return sub_categories.any(function(cat) {
            return cat.assets.any(function(asset) {
                return
                    asset.type == CustomizationAsset.Cosmetic
                    && self.ari.cosmetic_unlocks.contains(asset.key)
                    && !self.ari.seen_cosmetics.contains(asset.key);
            })
        })
    }

    function setup_left_page(preset_index) {
        ANCHOR.free_children(self.player_slot_root);
        self.left_pilot.reset();

        var create_slot = function(par_ui_slot, xx, yy) {
            static SLOT_ICON_KEY = function(slot) {
                switch slot {
                    case ParUiSlot.Skin: return "spr_ui_journal_customization_slot_icon_skin_color"
                    case ParUiSlot.Eyes: return "spr_ui_journal_customization_slot_icon_eye_style"
                    case ParUiSlot.Hair: return "spr_ui_journal_customization_slot_icon_hairstyle"
                    case ParUiSlot.FacialHair: return "spr_ui_journal_customization_slot_icon_facial_hair"
                    case ParUiSlot.FaceGear: return "spr_ui_journal_customization_slot_icon_face_accessory"
                    case ParUiSlot.HeadGear: return "spr_ui_journal_customization_slot_icon_head_accessory"
                    case ParUiSlot.Top: return "spr_ui_journal_customization_slot_icon_top"
                    case ParUiSlot.Back: return "spr_ui_journal_customization_slot_icon_back"
                    case ParUiSlot.Bottom: return "spr_ui_journal_customization_slot_icon_bottom"
                    case ParUiSlot.Feet: return "spr_ui_journal_customization_slot_icon_shoe"
                    default: impossible("Unexpected ParUiSlot: {}", slot);
                }
            }

            var slot = common_slice(self.player_slot_root);
            slot
                .set_xy(xx, yy)
                .add_to_pilot(self.left_pilot)
                .board_set("can_open", true)
                .set_label(format("{ParUiSlot}_slot", par_ui_slot))
                .set_tap_callback(function(par_ui_slot) {
                    self.setup_right_page(par_ui_slot);
                    ANCHOR.set_active_pilot(self.right_pilot);
                }, [par_ui_slot])
                .set_selected_getter(function(par_ui_slot) {
                    return par_ui_slot == self.selected_slot;
                }, [par_ui_slot]);

            slot.body = ANCHOR.sprite(slot)
                .set_align(Align.Center, Align.Middle)
                .set_lut(spr_player_base_lut, self.active_preset.skin_tone);

            slot.asset_icon = ANCHOR.sprite(slot, slot.body.get_z() - 1)
                .set_align(Align.Center, Align.Middle)

            slot.empty_icon = ANCHOR.sprite(slot, slot.body.get_z() - 1)
                .set_align(Align.Center, Align.Middle)
                .set_sprites_from_key(SLOT_ICON_KEY(par_ui_slot))
                .set_key_sprite_target(slot)

            slot.alert = ANCHOR.sprite(slot, slot.asset_icon.get_z() - 1)
                .set_sprite(spr_ui_journal_customization_new_unlock_icon)
                .set_align(Align.RightIn, Align.TopIn)
                .disable()

            return slot;
        }

        self.right_scroller = undefined;
        self.active_index = self.preset_override != undefined ? undefined : preset_index;
        self.active_preset = self.preset_override ?? self.ari.presets.get(preset_index);

        self.override_music = false;

        self.slots = [];
        var slot_inc = 25;
        var right_side_x = 123;
        self.slots[ParUiSlot.HeadGear] = create_slot(ParUiSlot.HeadGear, 0, 0);
        self.slots[ParUiSlot.FaceGear] = create_slot(ParUiSlot.FaceGear, slot_inc, 0);
        self.slots[ParUiSlot.Top] = create_slot(ParUiSlot.Top, right_side_x, 0);
        self.slots[ParUiSlot.Back] = create_slot(ParUiSlot.Back, right_side_x + slot_inc, 0);
        self.left_pilot.request_newline();
        self.slots[ParUiSlot.Hair] = create_slot(ParUiSlot.Hair, 0, slot_inc);
        self.slots[ParUiSlot.Eyes] = create_slot(ParUiSlot.Eyes, slot_inc, slot_inc);
        self.slots[ParUiSlot.Bottom] = create_slot(ParUiSlot.Bottom, right_side_x, slot_inc);
        self.slots[ParUiSlot.Feet] = create_slot(ParUiSlot.Feet, right_side_x + slot_inc, slot_inc);
        self.left_pilot.request_newline();
        self.slots[ParUiSlot.FacialHair] = create_slot(ParUiSlot.FacialHair, 0, slot_inc * 2);
        self.slots[ParUiSlot.Skin] = create_slot(ParUiSlot.Skin, slot_inc, slot_inc * 2);


        var arrow_left_button = ANCHOR.nine_slice(self.player_slot_root)
            .set_sprites_from_key("spr_ui_calendar_button_spring")
            .set_size(16)
            .set_tap_sound("SoundEffects/UI/UIJournalTabSwitch")
            .set_xy(slot_inc * 2, slot_inc * 2 + 6)
            .add_hover_outline()
            .add_to_pilot(self.left_pilot)
            .set_tap_callback(function() {
                self.active_par.set_cardinal(wrap(self.active_par.cardinal - 1, Cardinal.LEN));
            })

        var arrow_left_icon = ANCHOR.sprite(arrow_left_button)
            .set_align(Align.Center, Align.Middle)
            .set_sprites_from_key("spr_ui_calendar_left_arrow_spring")
            .set_key_sprite_target(arrow_left_button)

        var arrow_right_button = ANCHOR.nine_slice(self.player_slot_root)
            .set_sprites_from_key("spr_ui_calendar_button_spring")
            .set_size(16)
            .set_tap_sound("SoundEffects/UI/UIJournalTabSwitch")
            .set_xy(right_side_x - slot_inc + 6, slot_inc * 2 + 6)
            .add_hover_outline()
            .add_to_pilot(self.left_pilot)
            .set_tap_callback(function() {
                self.active_par.set_cardinal(wrap(self.active_par.cardinal + 1, Cardinal.LEN));
            })

        var arrow_right_icon = ANCHOR.sprite(arrow_right_button)
            .set_align(Align.Center, Align.Middle)
            .set_sprites_from_key("spr_ui_calendar_right_arrow_spring")
            .set_key_sprite_target(arrow_right_button)


        self.preset_button = ANCHOR.nine_slice(self.player_slot_root)
            .set_xy(right_side_x, slot_inc * 2)
            .set_sprites_from_key("spr_ui_button")
            .set_size(47, 22)
            .set_label("preset_button")
            .add_to_pilot(self.left_pilot, true)
            .add_hover_outline()

        if self.preset_override == undefined {
            self.preset_button.set_tap_callback(function() {
                self.reset_right_page();
                self.preset_popup = popup_creator("misc_local/select_a_preset");
                self.preset_popup.backplate.set_size(230, 164 + self.preset_popup.title_overflow());
                self.preset_popup.slot_base = ANCHOR.positional(self.preset_popup.backplate)
                    .set_size(self.preset_popup.backplate.get_size())
                self.generate_preset_popup_body();
                self.preset_popup.spawn();
            });
        } else {
            self.preset_button.set_soft_locked();
        }

        ANCHOR.sprite(preset_button)
            .set_align(Align.Center, Align.Middle)
            .set_sprites_from_key("spr_ui_journal_customization_outfit_button_icon")
            .set_key_sprite_target(preset_button)

        self.update_slots(self.active_preset);

        var ari = ANCHOR.create_ari_node(self.player_slot_root, self.active_preset, 45, 18, 2);
        self.active_par = ari.board_get("__par__");
        self.active_par.set_cardinal(Cardinal.South);

        self.set_up_fields();
    }

    function set_up_fields() {
        if self.field_zone != undefined {
            ANCHOR.free_node(self.field_zone);
        }

        self.field_zone = ANCHOR.positional(self.journal.left_body)
            .set_align(Align.Center, Align.BottomIn)
            .set_size(self.journal.left_body.get_width() + 2, 95)

        self.fields = new JournalFields(self.field_zone, self.left_pilot);

        self.name_field = self.fields.new_field(spr_ui_generic_my_name_icon, self.ari.name, CommonLutIndex.Blue);
        self.name_field.set_tap_callback(function() {
            text_input_popup("misc_local/enter_new_name", self.ari.name, ARI_NAME_MAX_WIDTH, function(txt) {
                self.ari.name = txt;
                self.name_field.text_node.set_text(txt);
            });
        });
        self.name_field.set_label("name_field");

        self.pronoun_field = self.fields.new_field(
            spr_ui_generic_gender_icon,
            PRONOUNS[$ local_language()][$ self.ari.pronouns[$ local_language()]].display,
            CommonLutIndex.Blue,
        );
        self.pronoun_field.set_tap_callback(function() {
            var choices = ListFromArray(local_get_info(LocalInfoRequest.PronounDisplayOrder));
            create_options_popup(
                "misc_local/select_your_pronouns",
                choices,
                function(e) {
                    return PRONOUNS[$ local_language()][$ e].display;
                },
                function(e) {
                    self.ari.pronouns[$ local_language()] = e;
                    self.pronoun_field.text_node.set_text(PRONOUNS[$ local_language()][$ e].display);
                    local_set_pronouns(self.ari.pronouns);
                },
                self.new_pilot(),
            );
        });
        self.pronoun_field.set_label("pronoun_field");

        self.birthday_field = self.fields.new_field(
            spr_ui_generic_birthday_icon,
            localize_date(self.ari.birthday, false),
            self.creation_behavior ? CommonLutIndex.Blue : CommonLutIndex.Green,
        );
        if self.creation_behavior {
            self.birthday_field.set_tap_callback(function() {
                var ui = spawn_calendar_ui(self.ari.birthday);

                ui.canvas.set_layer(AnchorLayer.Popup);
                ui.background.background.set_layer(AnchorLayer.AboveFader);

                ui
                    .show_events(false)
                    .show_year(false)
                    .with_banner("misc_local/select_your_birthday")
                    .enable_selection(function(ui) {
                        self.ari.birthday = ui.time;
                        self.birthday_field.text_node.set_text(localize_date(self.ari.birthday, false));
                        ui.close();
                    })
                    .build();

                self.lock();

                //
                ui.on_close = method(ui, function() {
                    if self.pilot_cache != undefined {
                        ANCHOR.set_active_pilot(self.pilot_cache);
                    }
                    ANCHOR.get_menu(Menu.Customization).unlock();
                });
            });
        }

        self.farm_field = self.fields.new_field(spr_ui_generic_my_farm_icon, self.ari.farm_name, CommonLutIndex.Blue);
        self.farm_field.set_tap_callback(function() {
            text_input_popup("misc_local/enter_new_name", self.ari.farm_name, FARM_NAME_MAX_WIDTH, function(txt) {
                self.ari.farm_name = txt;
                self.farm_field.text_node.set_text(txt);
            });
        });
        self.farm_field.set_label("farm_field");

        if !self.creation_behavior {
            var dating = array_any(NPCS, function(v) {
                return v.is_dating()
            });
            var label = undefined;
            if ARI.has_spouse() {
                label = "misc_local/married";
            } else if ARI.has_fiance() {
                label = "misc_local/engaged";
            } else if dating {
                label = "misc_local/dating";
            } else {
                label = "misc_local/single";
            }
            self.relationship_field = self.fields.new_field(
                spr_ui_generic_relationship_icon,
                local_get(label),
                CommonLutIndex.Green,
            );
        }
    }

    function update_slots() {
        //
        for (var i = 0; i < ParUiSlot.LEN; i++) {
            var slot = self.slots[i];

            //
            if i == ParUiSlot.Skin {
                slot.empty_icon.disable();
                slot.asset_icon
                    .set_sprite(spr_ui_item_wearable_skin)
                    .set_index(1)
                    .set_lut(spr_player_base_lut, self.active_preset.skin_tone);
                continue;
            }

            //
            var entry = self.active_preset.assets.find_value(function(data, slot) {
                return slot == PLAYER_ANIMATION_DATABASE.player_assets.get(data.name).ui_slot;
            }, i);

            if entry == undefined {
                slot.empty_icon.enable();
                slot.body.set_sprite(spr_nothing);
                slot.asset_icon.disable();
            } else {
                var asset = PLAYER_ANIMATION_DATABASE.player_assets.get(entry.name);
                slot.empty_icon.disable();
                slot.body.set_sprite(asset.ui_body_icon);
                slot.body.set_alpha(1);
                slot.body.set_lut_index(self.active_preset.skin_tone)
                slot.asset_icon
                    .set_sprite(asset.ui_asset_icon)
                    .set_lut(asset.lut_sprite, entry.lut_index)
                    .enable()
            }

            //
            slot.alert.set_enabled(self.slot_has_new_cosmetics(i));
        }

        //
        for (var i = 0; i < self.active_preset.assets.count(); i++) {
            var data = self.active_preset.assets.get(i);
            var asset = PLAYER_ANIMATION_DATABASE.player_assets.get(data.name);

            //
            var locks = get_slot_locks_for_asset(data.name);
            for (var j = 0; j < array_length(locks); j++) {
                var lock = locks[j];
                if lock == asset.ui_slot {
                    continue;
                }
                var slot = self.slots[lock];
                slot.body.set_sprite(asset.ui_body_icon);
                slot.body.set_alpha(0.5);
                slot.empty_icon.disable();
                slot.asset_icon
                    .set_sprite(asset.ui_asset_icon)
                    .set_lut(asset.lut_sprite, data.lut_index)
                    .enable()
            }
        }

        //
        var child = ARI.held_child();
        if child != undefined {
            var slot = self.slots[ParUiSlot.Back];
            slot.empty_icon.disable();
            slot.body.set_alpha(0.5);
            slot.asset_icon
                .set_sprite(child.get_icon())
                .disable_lut()
                .enable()
        }
    }

    function reset_right_page() {
        self.selected_slot = undefined;
        self.right_pilot.reset();
        self.selected_slot = undefined;
        if self.right_scroller != undefined {
            self.right_scroller.free();
        }
    }

    function setup_right_page(par_ui_slot) {
        self.reset_right_page();

        self.selected_slot = par_ui_slot;

        self.right_scroller = create_scroller(self.journal.right_full_body)
            .subscribe_to_pilot(self.right_pilot)
            .set_pilot_padding(32, 32)
            .alternate_colors(false)

        var sub_categories = CUSTOMIZATION_UI_DATA.get(par_ui_slot);
        for (var i = 0; i < sub_categories.count(); i++) {
            var sub_category = sub_categories.get(i);

            //
            if sub_category.key != "back" {
                var any_unlocked = sub_category.assets.any(function(e) {
                    switch e.type {
                        case CustomizationAsset.Removal: return false;
                        case CustomizationAsset.SkinTone: return true;
                        case CustomizationAsset.Cosmetic: return self.ari.cosmetic_unlocks.contains(e.key);
                    }
                });

                if !any_unlocked {
                    continue;
                }
            }

            var element = self.right_scroller.new_element(20);

            var icon = ANCHOR.sprite(element)
                .set_sprite(sub_category.icon)
                .set_xy(10, 4)
            ANCHOR.text(icon)
                .set_x(4)
                .set_align(Align.RightOut, Align.Middle)
                .set_key(sub_category.name)
                .set_lut(COMMON_LUT)

            //
            var assets = sub_category.assets.clone();
            assets.sort_with(function(e1, e2) {
                //
                var e1_type = e1.type;
                var e2_type = e2.type;
                if e1_type == CustomizationAsset.SkinTone {
                    return e1.index - e2.index;
                } else if e1_type != e2_type {
                    return e1_type - e2_type;
                }

                //
                var e1_unlocked = self.ari.cosmetic_unlocks.contains(e1.key);
                var e2_unlocked = self.ari.cosmetic_unlocks.contains(e2.key);
                var e1_asset = PLAYER_ANIMATION_DATABASE.player_assets.get(e1.key);
                var e2_asset = PLAYER_ANIMATION_DATABASE.player_assets.get(e2.key);
                if e1_unlocked && e2_unlocked {
                    return string_alphanumeric_comparison(local_get(e1_asset.name), local_get(e2_asset.name));
                } else if e1_unlocked {
                    return -1;
                } else {
                    return 1;
                }
            });

            var layout = new GridLayout(assets, self.right_pilot);

            var container_size = layout.container_size();
            var container = ANCHOR.positional(element)
                .set_size(container_size)
                .set_align(Align.Center, Align.TopIn)
                .set_y(element.get_height())

            //
            self.right_scroller.add_height_to_element(
                element,
                container_size.y + 9,
            );

            //
            while layout.has_next() {
                var next = layout.next(container);

                if next.asset != undefined {
                    var square = next.square;
                    var icon = next.icon;
                    var asset = next.asset;
                    switch asset.type {
                        case CustomizationAsset.Removal:
                            square.set_label(format("removal_square"));
                            icon.set_sprites_from_key("spr_ui_journal_customization_slot_icon_none");
                            icon.set_key_sprite_target(square);
                            square.set_tap_callback(function() {
                                self.remove_cosmetic(self.selected_slot);
                            });
                            break;
                        case CustomizationAsset.SkinTone:
                            square.set_label(format("tone_{}", asset.index));
                            icon.set_sprite(spr_ui_item_wearable_skin);
                            icon.set_lut(spr_player_base_lut, asset.index);
                            square.set_tap_callback(function(asset) {
                                self.change_skin_tone(asset.index);
                            }, [asset]);
                            break;
                        case CustomizationAsset.Cosmetic:
                            square.set_label(asset.key);
                            var body = ANCHOR.sprite(square)
                                .set_align(Align.Center, Align.Middle)
                                .set_z(icon.get_z() + 1)
                                .set_lut(spr_player_base_lut, self.active_preset.skin_tone)

                            if !self.ari.cosmetic_unlocks.contains(asset.key) {
                                icon.set_sprite(spr_ui_journal_customization_lock_icon);
                                square.listen_for_taps();
                                square.set_soft_locked(true);
                            } else {
                                var asset_data = PLAYER_ANIMATION_DATABASE.player_assets.get(asset.key);
                                icon.set_sprite(asset_data.ui_asset_icon);
                                body.set_sprite(asset_data.ui_body_icon);
                                square.set_soft_locked(false);
                                square.set_tap_callback(function(asset) {
                                    self.create_color_popup(self.selected_slot, asset.key);
                                }, [asset]);

                                if !self.ari.seen_cosmetics.contains(asset.key) && !is_menu_room(room()) {
                                    var alert = ANCHOR.sprite(square)
                                        .set_sprite(spr_ui_journal_customization_new_unlock_icon)
                                        .set_align(Align.RightIn, Align.TopIn)
                                        .set_z(square.get_z() - 500)

                                    alert.set_think_callback(function(square, alert, key) {
                                        if square.is_hovered() {
                                            alert.disable();
                                            self.ari.seen_cosmetics.insert(key);
                                            self.update_slots();
                                        }
                                    }, [square, alert, asset.key])
                                }
                            }
                            break;
                    }
                }
            }
        }
    }

    function create_color_popup(par_ui_slot, asset_key) {
        var asset_data = PLAYER_ANIMATION_DATABASE.player_assets.get(asset_key);

        var color_count = sprite_get_width(asset_data.lut_sprite);
        var colors = List();
        for (var i = 1; i < color_count; i++) {
            colors.push(i);
        }

        if colors.count() == 1 {
            //
            self.equip_cosmetic(asset_key, 1);
            return;
        }

        var popup = popup_creator(asset_data.name);
        popup.backplate.set_width(colors.count() >= 50 ? 256 : 180);
        popup.backplate.add_height(-27);
        var columns = colors.count() >= 50 ? 10 : 6;
        var layout = new GridLayout(colors, popup.pilot, columns);

        var container_size = layout.container_size();
        var container = ANCHOR.positional(popup.backplate)
            .set_size(container_size)
            .set_align(Align.Center, Align.BottomIn)
            .set_y(-13)

        popup.backplate.add_height(container_size.y);

        while layout.has_next() {
            var next = layout.next(container);

            if next.asset != undefined {
                var body = ANCHOR.sprite(next.square)
                    .set_align(Align.Center, Align.Middle)
                    .set_z(next.icon.get_z() + 1)
                    .set_sprite(asset_data.ui_body_icon)
                    .set_lut(spr_player_base_lut, self.active_preset.skin_tone)

                next.icon.set_sprite(asset_data.ui_asset_icon)
                next.icon.set_lut(asset_data.lut_sprite, next.asset);

                next.square.set_label(format("color_square_{}", next.asset));
                next.square.set_tap_callback(function(key, color, popup) {
                    self.equip_cosmetic(key, color);
                    popup.close();
                }, [asset_key, next.asset, popup])

                //
                if par_ui_slot == ParUiSlot.Eyes {
                    ANCHOR.sprite(next.square)
                        .set_sprite(spr_ui_item_wearable_color_swatch)
                        .set_z(body.get_z() + 1)
                        .set_xy(3, 3)
                        .set_lut(asset_data.lut_sprite, next.asset)

                }
            }
        }

        popup.spawn();
    }

    function change_skin_tone(index) {
        var update_obj_ari = instance_exists(obj_ari) && self.active_index == self.ari.preset_index_selected;
        self.active_preset.skin_tone = index;
        self.active_par.set_skin_tone(index);
        if update_obj_ari {
            obj_ari.par.set_skin_tone(index);
            self.handle_void_ari();
        }
        self.update_slots();
    }

    function clear_ari() {
        var update_obj_ari = instance_exists(obj_ari) && self.active_index == self.ari.preset_index_selected;
        self.active_preset.assets.for_each(function(asset, update_obj_ari) {
            self.active_par.remove_asset(asset.name);
            if update_obj_ari {
                obj_ari.par.remove_asset(asset.name);
                self.handle_void_ari();
            }
        }, [update_obj_ari]);

        handle_child_on_par(self.active_par);
    }

    function rebuild_ari() {
        self.active_preset.apply_to_par(self.active_par);
        handle_child_on_par(self.active_par);
        if instance_exists(obj_ari) && self.active_index == self.ari.preset_index_selected {
            build_obj_ari_par_from(self.active_preset);
        }
        self.handle_void_ari();
    }

    function remove_cosmetic(par_ui_slot) {
        self.clear_ari();
        self.clear_slot(par_ui_slot);
        self.rebuild_ari();
        self.ensure_modesty();
        self.update_slots();
    }

    function clear_slot(par_ui_slot) {
        self.active_preset.assets.drain(function(asset, slot) {
            var locks = get_slot_locks_for_asset(asset.name);
            return array_has(locks, slot);
        }, par_ui_slot);
    }

    function equip_cosmetic(asset_key, lut_index) {
        self.clear_ari();

        //
        var locks = get_slot_locks_for_asset(asset_key);
        for (var i = 0; i < array_length(locks); i++) {
            self.clear_slot(locks[i]);
        }

        if GAME_STATS != undefined {
            GAME_STATS.cosmetic_worn[$ asset_key] = true;
        }

        self.active_preset.assets.push({
            name: asset_key,
            lut_index: lut_index ?? 1,
        });

        self.rebuild_ari();
        self.ensure_modesty();
        self.update_slots();
    }

    function ensure_modesty() {
        var xxx_content =
            self.active_par.slots[AnimationSlot.Legs].asset == undefined
            && self.active_par.slots[AnimationSlot.LegsTop].asset == undefined
            && self.active_par.slots[AnimationSlot.Waist].asset == undefined;
        if xxx_content {
            self.equip_cosmetic("underwear_shorts");
        }
    }

    function generate_preset_popup_body() {
        ANCHOR.free_children(self.preset_popup.slot_base);
        self.preset_popup.pilot.reset();

        static FRAME_WIDTH = 46;
        static FRAME_HEIGHT = 47; //
        static HORZ_LAYOUT = centered_positions(4, FRAME_WIDTH, 4);
        static VERT_LAYOUT = centered_positions(2, FRAME_HEIGHT, 4);
        var iter = 0;
        var created_new_button = false;
        for (var j = 0; j < array_length(VERT_LAYOUT); j++) {
            for (var i = 0; i < array_length(HORZ_LAYOUT); i++) {
                var xx = HORZ_LAYOUT[i];
                var yy = VERT_LAYOUT[j];
                var frame = common_slice(self.preset_popup.slot_base, FRAME_WIDTH, FRAME_HEIGHT)
                    .set_align(Align.Center, Align.Middle)
                    .set_xy(xx, yy)
                    .add_to_pilot(self.preset_popup.pilot)
                    .set_depress_children(false)
                    .set_label(format("body_frame_{}", iter))
                    .set_selected_getter(function(index) {
                        return self.ari.preset_index_selected == index;
                    }, [iter])

                var preset = self.ari.presets.try_get(iter);
                if preset == undefined {
                    if created_new_button {
                        frame.lock();
                    } else {
                        ANCHOR.sprite(frame)
                            .set_sprite(spr_ui_journal_customization_plus_icon)
                            .set_align(Align.Center, Align.Middle)

                        frame.set_tap_callback(function(i, j) {
                            var preset = self.ari.presets.get(self.ari.preset_index_selected);
                            self.ari.presets.push(preset.clone());
                            self.generate_preset_popup_body();
                            var new_square = self.preset_popup.pilot.map[j][i];
                            self.preset_popup.pilot.force_select(new_square);
                        }, [i, j])

                        created_new_button = true;
                    }
                } else {
                    frame.board_set("index", iter);
                    frame.board_set("deletable", self.ari.presets.count() > 1);
                    frame.set_tap_callback(function(index) {
                        if self.ari.preset_index_selected != index {
                            if instance_exists(obj_ari) {
                                obj_ari.change_preset(index);
                                self.handle_void_ari();
                            } else {
                                self.ari.preset_index_selected = index;
                            }
                        }
                        self.exit_preset_popup(index);
                        //
                    }, [iter])

                    ANCHOR.create_ari_node(frame, preset, FRAME_WIDTH / 2, (FRAME_HEIGHT / 2) + 12, 1);
                }

                iter += 1;
            }
            self.preset_popup.pilot.request_newline();
        }

        var trash_icon = ANCHOR.sprite(self.preset_popup.backplate);
        trash_icon
            .set_xy(-10, -6)
            .set_align(Align.RightIn, Align.BottomIn)
            .set_sprites_from_key("spr_ui_journal_inventory_trash_button")
            .add_glyph(InputId.Throw)
            .set_label("trash")
            .set_tap_callback(function() {
                var pilot_position = self.preset_popup.pilot.get_position();
                var index = ANCHOR.current_hovered_node.board_get("index");
                var needs_change = self.ari.preset_index_selected >= index;
                if needs_change {
                    if instance_exists(obj_ari) {
                        var current_preset = ARI.animation_assets();
                        for (var i = 0; i < current_preset.assets.count(); i++) {
                            obj_ari.par.remove_asset(current_preset.assets.get(i).name);
                            self.handle_void_ari();
                        }
                    }
                    self.ari.preset_index_selected = max(self.ari.preset_index_selected - 1, 0);
                }
                self.ari.presets.remove(index);
                if needs_change {
                    if instance_exists(obj_ari) {
                        obj_ari.change_preset(self.ari.preset_index_selected);
                        self.handle_void_ari();
                    }
                    self.setup_left_page(self.ari.preset_index_selected);
                }
                self.generate_preset_popup_body();
                var new_square = self.preset_popup.pilot.map[pilot_position.y][pilot_position.x];
                self.preset_popup.pilot.force_select(new_square);
            })
            .set_think_callback(function(trash_icon) {
                trash_icon.set_unlocked(
                    ANCHOR.current_hovered_node != undefined
                    && ANCHOR.current_hovered_node.board_get("deletable")
                );
            }, [trash_icon])
    }

    function exit_preset_popup(preset_index) {
        self.setup_left_page(preset_index);
        ANCHOR.set_active_pilot(self.left_pilot);
        self.left_pilot.force_select(self.preset_button);
        self.preset_popup.close();
    }

    function handle_void_ari() {
        with obj_void_ari {
            self.create_par();
        }
    }

    self.journal = journal_nodes ?? ANCHOR.get_menu(Menu.Journal);
    self.journal.left_page.set_sprite(spr_ui_journal_book_page_layout_customization_left);
    self.journal.right_page.set_sprite(spr_ui_journal_book_page_layout_customization_right);
    self.ari = ari;
    self.preset_override = preset_override;
    self.creation_behavior = creation_behavior;
    self.selected_slot = undefined;

    self.left_pilot = self.new_pilot()
    self.right_pilot = self.new_pilot()
        .allow_horizontal_wrapping()
        .allow_vertical_wrapping()
    self.preset_pilot = self.new_pilot();
    self.field_zone = undefined;

    self.customization_label = title_for_journal(
            "misc_local/character_customization",
            self.journal.left_header,
            spr_ui_journal_customization_header_icon,
        )
        .set_think_callback(function() {
            var directional_in_page =
                ANCHOR.get_active_pilot() != self.left_pilot
                && ANCHOR.in_directional_control();
            //
            if directional_in_page {
                GLYPH_GUIDE.set_input(InputId.MenuBack, "misc_local/back");
                if ANCHOR.get_menu(Menu.Calendar) == undefined && INPUT.take_press(InputId.MenuBack) {
                    self.reset_right_page();
                    ANCHOR.set_active_pilot(self.left_pilot);
                }
            }
        })

    self.customization_label.set_max_width(158);

    self.player_slot_root = ANCHOR.positional(self.journal.left_body)
        .set_xy(3, 5);

    self.setup_left_page(self.ari.preset_index_selected);
    ANCHOR.set_active_pilot(self.left_pilot);
}

enum ParUiSlot {
    Skin,
    Eyes,
    Hair,
    FacialHair,
    FaceGear,
    HeadGear,
    Top,
    Back,
    Bottom,
    Feet,
    LEN
}

enum CustomizationAsset {
    Removal,
    Cosmetic,
    SkinTone,
    LEN,
}

function get_slot_locks_for_asset(asset_key) {
    var asset = PLAYER_ANIMATION_DATABASE.player_assets.get(asset_key);

    var output = [];
    for (var i = 0; i < AnimationSlot.LEN; i++) {
        var ui_slot_to_lock = undefined;
        var slot = asset.slots[i];
        if slot != undefined {
            switch i {
                case AnimationSlot.Torso:
                case AnimationSlot.SleeveRight:
                case AnimationSlot.SleeveLeft:
                    ui_slot_to_lock = ParUiSlot.Top;
                    break;
                case AnimationSlot.HairFront:
                case AnimationSlot.HairMid:
                case AnimationSlot.HairBack:
                    ui_slot_to_lock = ParUiSlot.Hair;
                    break;
                case AnimationSlot.Eyes:
                    ui_slot_to_lock = ParUiSlot.Eyes;
                    break;
                case AnimationSlot.Feet:
                    ui_slot_to_lock = ParUiSlot.Feet;
                    break;
                case AnimationSlot.Legs:
                case AnimationSlot.Waist:
                case AnimationSlot.LegsTop:
                    ui_slot_to_lock = ParUiSlot.Bottom;
                    break;
                case AnimationSlot.FaceGear:
                case AnimationSlot.Face:
                    ui_slot_to_lock = ParUiSlot.FaceGear;
                    break;
                case AnimationSlot.FacialHair:
                    ui_slot_to_lock = ParUiSlot.FacialHair;
                    break;
                case AnimationSlot.HeadGear:
                case AnimationSlot.HeadGearBack:
                    ui_slot_to_lock = ParUiSlot.HeadGear;
                    break;
                case AnimationSlot.BackGear:
                    ui_slot_to_lock = ParUiSlot.Back;
                    break;
                default: break;
            }
        }
        if ui_slot_to_lock != undefined && !array_has(output, ui_slot_to_lock) {
            array_push(output, ui_slot_to_lock);
        }
    }
    return output;
}

#macro CUSTOMIZATION_UI_DATA global.__customization_ui_data
CUSTOMIZATION_UI_DATA = undefined;

function load_customization_ui_data() {
    var data = fiddle_get("ui/character_customization");
    var output = Map();
    for (var i = 0; i < ParUiSlot.LEN; i++) {
        var key = par_ui_slot_to_string(i);
        var f_category = clone_value(data[$ key]);
        var category = List();
        for (var j = 0; j < array_length(f_category); j++) {
            var sub_cat = f_category[j];
            sub_cat.icon = string_to_asset(sub_cat.icon);
            sub_cat.assets = List();
            if !matches(i, ParUiSlot.Eyes, ParUiSlot.Skin) {
                sub_cat.assets.push({
                    type: CustomizationAsset.Removal,
                });
            }
            category.push(sub_cat);
        }
        output.insert(i, category);
    }

    //
    var par_keys = PLAYER_ANIMATION_DATABASE.player_assets.keys();
    for (var i = 0; i < array_length(par_keys); i++) {
        var asset = PLAYER_ANIMATION_DATABASE.player_assets.get(par_keys[i]);
        if asset[$ "ui_sub_category"] == undefined {
            continue;
        }

        var sub_category = output.get(asset.ui_slot).find_value(function(val, sub) {
            return val.key == sub;
        }, asset.ui_sub_category);

        sub_category.assets.push({
            type: CustomizationAsset.Cosmetic,
            key: par_keys[i],
        });
    }

    //
    var skin = output.get(ParUiSlot.Skin).first();
    var len = sprite_get_width(spr_player_base_lut) - 1;
    for (var i = 0; i < len; i++) {
        skin.assets.push({
            type: CustomizationAsset.SkinTone,
            index: i + 1,
        });
    }

    return output;
}
