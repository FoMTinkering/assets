function SpellcastingMenu() : AnchorMenu(Menu.Spellcasting) constructor {
    function close_and_cast(spell) {
        self.journal.close();
        new_chain().append(LinkId.Await, function(spell) {
            if ANCHOR.get_menu(Menu.Spellcasting) == undefined {
                obj_ari.fsm.blackboard.set("spell", spell);
                obj_ari.fsm.change_state(PlayerState.Spell);
                return true;
            }
            return false;
        }, [spell])
    }

    function reset_right_page() {
        self.selected_spell = undefined;
        self.name_field.set_text("");
        self.type_field.set_text("");
        self.description.set_text("");
        self.upper_spell_icon.disable();
        self.lower_spell_icon.disable();
        self.pin_button.disable();
        self.card.set_sprite(spr_ui_journal_magic_card_backplate_empty);
        self.ribbon.disable();
        ANCHOR.free_children(self.cost_zone);
    }

    function select_spell(spell) {
        self.reset_right_page();

        self.selected_spell = spell;
        self.spell_data = SPELLS[spell];
        self.card.set_sprite(spr_ui_journal_magic_card_backplate);
        self.name_field.set_key(self.spell_data.name);
        self.type_field.set_key(self.spell_data.type);
        self.description.set_key(self.spell_data.description);
        var cost = self.spell_data.cost div 4;
        var cost_icon = spr_ui_hud_health_mana_ball_on;
        var positions = centered_positions(cost, sprite_get_width(cost_icon), 2);
        for (var i = 0; i < array_length(positions); i++) {
            var pos = positions[i];
            ANCHOR.sprite(self.cost_zone)
                .set_sprite(cost_icon)
                .set_x(pos)
                .set_align(Align.Center, Align.Middle)
        }

        self.upper_spell_icon.set_sprite(self.spell_data.upper_icon);
        self.upper_spell_icon.enable();
        self.lower_spell_icon.set_sprites_from_key(self.spell_data.icon_key);
        self.lower_spell_icon.enable();
        self.ribbon.set_sprite(self.spell_data.ribbon);
        self.ribbon.enable();
        self.pin_button.enable();

        ANCHOR.set_active_pilot(self.right_pilot);

    }

    self.journal = ANCHOR.get_menu(Menu.Journal);
    self.journal.left_page.set_sprite(spr_ui_journal_book_page_layout_magic_left);
    self.journal.right_page.set_sprite(spr_ui_journal_book_page_layout_magic_right);

    self.title = title_for_journal("misc_local/magic_spells", self.journal.left_header, spr_ui_journal_magic_header_icon)
        .set_think_callback(function() {
            var directional_in_page = self.selected_spell != undefined && ANCHOR.in_directional_control();
            self.scroller.canvas.set_alpha(!directional_in_page ? 1 : UI_FADE_ALPHA);
            if directional_in_page {
                GLYPH_GUIDE.set_input(InputId.MenuBack, "misc_local/back");
                if INPUT.take_press(InputId.MenuBack) {
                    self.reset_right_page();
                    ANCHOR.set_active_pilot(self.left_pilot);
                }
            }
        }, [])

    self.selected_spell = undefined;
    self.spell_data = undefined;

    self.left_pilot = self.new_pilot()
        .allow_vertical_wrapping();

    self.scroller = create_scroller(self.journal.left_body)
        .subscribe_to_pilot(self.left_pilot)

    if !array_contains(ARI.spells_learned, true) {
        scroller_none_option(self.scroller, 40);
    } else {
        for (var i = 0; i < Spell.LEN; i++) {
            if ARI.spells_learned[i] == false {
                continue;
            }

            var element = self.scroller.new_element(40)
                .add_to_pilot(self.left_pilot, true)
                .set_selected_getter(function(i) {
                    return self.selected_spell == i;
                }, [i])
                .set_tap_callback(function(i) {
                    self.select_spell(i);
                }, [i])

            var icon = ANCHOR.sprite(element)
                .set_x(9)
                .set_align(Align.LeftIn, Align.Middle)
                .set_sprites_from_key(SPELLS[i].icon_key)

            var label = ANCHOR.text(icon)
                .set_x(4)
                .set_max_width(101)
                .set_key(SPELLS[i].name)
                .set_align(Align.RightOut, Align.Middle)
                .set_lut(COMMON_LUT)

            var checkbox = ANCHOR.sprite(element);
            checkbox
                .set_think_callback(function(checkbox, i) {
                    checkbox.set_sprite(ARI.pinned_spell == i ? spr_ui_generic_checkbox_on : spr_ui_generic_checkbox_off);
                }, [checkbox, i])
                .set_align(Align.RightIn, Align.Middle)
                .set_x(-9)

            var pin = ANCHOR.sprite(checkbox)
                .set_align(Align.LeftOut, Align.Middle)
                .set_xy(-2, 2)
                .set_sprite(spr_ui_journal_magic_pin_icon)
        }
    }

    self.card = ANCHOR.sprite(self.journal.right_full_body)
        .set_sprite(spr_ui_journal_magic_card_backplate_empty)
        .set_xy(3, 7)

    self.ribbon = ANCHOR.sprite(self.card)
        .set_align(Align.Center, Align.BottomIn)
        .set_y(-4)

    self.upper_spell_icon = ANCHOR.sprite(self.card)
        .set_align(Align.Center, Align.TopIn)
        .set_y(24)

    self.detail_zone = ANCHOR.positional(self.journal.right_full_body)
        .set_size(103, 108)
        .set_align(Align.RightIn, Align.TopIn)

    var yy = 4;
    self.name_label = ANCHOR.text(self.detail_zone)
        .set_align(Align.Center, Align.TopIn)
        .set_y(yy)
        .set_key("misc_local/spell_name")
        .set_lut(COMMON_LUT)

    self.name_backplate = ANCHOR.nine_slice(self.name_label)
        .set_sprite(spr_ui_journal_magic_rounded_text_box)
        .set_size(99, 16)
        .set_align(Align.Center, Align.BottomOut)
        .set_y(2)

    self.name_field = ANCHOR.text(self.name_backplate)
        .set_align(Align.Center, Align.Middle)
        .set_lut(COMMON_LUT)

    yy += 36;
    self.type_label = ANCHOR.text(self.detail_zone)
        .set_align(Align.Center, Align.TopIn)
        .set_y(yy)
        .set_key("misc_local/spell_type")
        .set_lut(COMMON_LUT)

    self.type_backplate = ANCHOR.nine_slice(self.type_label)
        .set_sprite(spr_ui_journal_magic_rounded_text_box)
        .set_size(99, 16)
        .set_align(Align.Center, Align.BottomOut)
        .set_y(2)

    self.type_field = ANCHOR.text(self.type_backplate)
        .set_align(Align.Center, Align.Middle)
        .set_lut(COMMON_LUT)

    yy += 36;
    self.cost_label = ANCHOR.text(self.detail_zone)
        .set_align(Align.Center, Align.TopIn)
        .set_key("misc_local/spell_cost")
        .set_y(yy)
        .set_lut(COMMON_LUT)

    self.cost_zone = ANCHOR.positional(self.cost_label)
        .set_align(Align.Center, Align.BottomOut)
        .set_y(4)

    self.bottom_zone = ANCHOR.positional(self.journal.right_body)
        .set_size(178, 84)
        .set_align(Align.Center, Align.BottomIn)

    self.description = ANCHOR.text(self.bottom_zone)
        .set_lut(COMMON_LUT)
        .allow_line_breaks()
        //
        .set_xy(4, 4)

    self.lower_spell_icon = ANCHOR.sprite(self.bottom_zone)
        .set_xy(42, -7)
        .set_align(Align.LeftIn, Align.BottomIn)
        .disable()

    self.right_pilot = self.new_pilot()

    self.pin_button = ANCHOR.nine_slice(self.bottom_zone)
        .set_size(74, 17)
        .set_align(Align.LeftIn, Align.BottomIn)
        .set_xy(64, -7)
        .set_sprites_from_key("spr_ui_button")
        .add_hover_outline()
        .add_to_pilot(self.right_pilot)
        .disable()
        .set_tap_callback(function() {
            if ARI.pinned_spell == self.selected_spell {
                ARI.set_pinned_spell(undefined);
            } else {
                ARI.set_pinned_spell(self.selected_spell);
            }
        })

    var pin_root = ANCHOR.positional(self.pin_button)
        .set_align(Align.Center, Align.Middle)
        .set_height(1)
    var pin = ANCHOR.sprite(pin_root)
        .set_sprite(spr_ui_journal_magic_pin_icon)
        .set_align(Align.LeftIn, Align.Middle)
        .set_y(1)
    var label = ANCHOR.text(pin)
        .set_key("misc_local/pin_spell")
        .set_lut(COMMON_LUT, CommonLutIndex.Dark)
        .set_align(Align.RightOut, Align.Middle)
        .set_xy(4, -1)

    pin_root.set_width_for_nodes([pin, label]);

    ANCHOR.set_active_pilot(self.left_pilot);
}
