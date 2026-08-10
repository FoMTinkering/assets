enum PlayerMenuDepth {
    Inventory = 100,
    Ari,
    AriLevelText,
    AriLevelSprite,
    AriName,
    AriBackground,
    AriFrame,
    RightPageBackground,
    LeftPageBackground,
}

function PlayerMenu() : AnchorMenu(Menu.Player) constructor {
    self.journal = ANCHOR.get_menu(Menu.Journal);

    self.journal.left_page.set_sprite(spr_ui_journal_book_page_layout_inventory_left)
    self.journal.right_page.set_sprite(spr_ui_journal_book_page_layout_inventory_right)

    function build_info_section() {
        var field = function(yy, icon, text, lut_index=1) {
            var icon_node = ANCHOR.sprite(self.info_section)
                .set_xy(2, yy)
                .set_sprite(icon)
                .set_speed(1)

            var text_node = ANCHOR.text(icon_node)
                .set_align(Align.RightOut, Align.Middle)
                .set_x(3)
                .set_lut(COMMON_LUT, lut_index)
                .set_text(text)

            return {
                icon: icon_node,
                text: text_node,
            };
        }

        var width = self.journal.left_body.get_width();

        //
        title_for_journal(
            "misc_local/info",
            self.journal.left_header,
            spr_ui_journal_inventory_info_icon,
        );

        self.info_section = ANCHOR.positional(self.journal.left_body)
            .set_size(width, 42)

        static INC = 14;
        var yy = 2;

        //
        field(
            yy,
            string_to_asset(format("spr_ui_journal_inventory_season_{Season}_icon", CALENDAR.season())),
            format("{Local} {}", "misc_local/" + season_to_string(CALENDAR.season()), CALENDAR.day() + 1),
        );

        //
        yy += INC;
        field(yy, spr_ui_journal_inventory_calendar_icon, format("{Local} {}", "misc_local/year", CALENDAR.year() + 1));

        //
        yy += INC;
        field(
            yy,
            spr_ui_journal_inventory_renown_icon,
            format("Lvl {}", renown_to_level(ARI.renown)),
            3,
        );

        //
        var rank = renown_level_to_rank(renown_to_level(ARI.renown));
        self.renown_backplate = common_slice(self.info_section, self.info_section.get_width() + 2, 19)
            .set_align(Align.Center, Align.BottomOut)
            .set_enabled_sprite(spr_nothing_nineslice)
            .add_to_pilot(self.left_pilot, true)
            .set_tap_callback(function() {
                var popup = popup_creator("misc_local/town_rank_guide")
                popup.backplate.set_size(232, 236);

                var grid = ANCHOR.sprite(popup.backplate)
                    .set_xy(33, 30)
                    .set_sprite(spr_ui_renown_chart_grid)

                var icon_pos = Vec2(3, 5);
                var renown_icon_pos = Vec2(94, 6);
                for (var i = 100; i >= 0; i -= 10;) {
                    var a_target = 1;
                    if renown_to_level(ARI.renown) < i {
                        a_target = 0.50;
                        ANCHOR.sprite(grid)
                            .set_xy(-2, renown_icon_pos.y - 5)
                            .set_sprite(spr_ui_blacksmithing_lock_icon)
                            .set_align(Align.RightIn, Align.TopIn)
                            .set_alpha(0.4)
                    }
                    var rank = renown_level_to_rank(i);
                    var icon = ANCHOR.sprite(grid)
                        .set_sprite(rank.small_sprite)
                        .set_xy(icon_pos)
                        .set_alpha(a_target)
                    var name = ANCHOR.text(icon)
                        .set_align(Align.RightOut, Align.Middle)
                        .set_x(4)
                        .set_lut(COMMON_LUT)
                        .set_key(rank.name)

                    var renown_icon = ANCHOR.sprite(grid)
                        .set_xy(renown_icon_pos)
                        .set_sprite(spr_ui_journal_inventory_renown_icon)
                        .set_alpha(a_target)

                    var level_text = ANCHOR.text(renown_icon)
                        .set_x(4)
                        .set_align(Align.RightOut, Align.Middle)
                        .set_lut(COMMON_LUT)
                        .set_text(format("{Local} {}", "misc_local/renown_lvl_insert", i))


                    var inc = 18;
                    icon_pos.y += inc;
                    renown_icon_pos.y += inc;
                }

                popup.spawn();
            })

        var icon_node = ANCHOR.sprite(self.renown_backplate)
            .set_x(3)
            .set_sprite(rank.small_sprite)
            .set_speed(1)
            .set_align(Align.LeftIn, Align.Middle)

        var text_node = ANCHOR.text(icon_node)
            .set_align(Align.RightOut, Align.Middle)
            .set_x(3)
            .set_lut(COMMON_LUT)
            .set_text(format("{Local}: ", "misc_local/town_rank"))

        ANCHOR.text(text_node)
            .set_x(2)
            .set_align(Align.RightOut, Align.Middle)
            .set_key(rank.name)
            .set_lut(COMMON_LUT, CommonLutIndex.Green)

        //
        var time_widget = new TimeWidget(self.info_section, -6, 6, Align.RightIn, Align.TopIn);
        time_widget.time_am_pm.set_lut(spr_ui_journal_inventory_currency_font_lut);
        time_widget.time_text_minutes.set_lut(spr_ui_journal_inventory_currency_font_lut);
        time_widget.time_colon.set_lut(spr_ui_journal_inventory_currency_font_lut);
        time_widget.time_text_hours.set_lut(spr_ui_journal_inventory_currency_font_lut);

        //
        var gold_icon = ANCHOR.sprite(self.info_section)
            .set_sprite(spr_ui_journal_inventory_currency_icon)
            .set_align(Align.RightIn, Align.TopIn)
            .set_xy(-5, 21)

        ANCHOR.text(gold_icon)
            .set_x(-1)
            .set_sprite_font("currency")
            .set_align(Align.LeftOut, Align.Middle)
            .set_text(ARI.gold)
            .set_lut(spr_ui_journal_inventory_currency_font_lut)

        var essence_icon = ANCHOR.sprite(self.info_section)
            .set_sprite(spr_ui_journal_inventory_essence_icon)
            .set_align(Align.RightIn, Align.TopIn)
            .set_xy(-5, 31)

        ANCHOR.text(essence_icon)
            .set_x(-1)
            .set_sprite_font("currency")
            .set_align(Align.LeftOut, Align.Middle)
            .set_text(ARI.essence)
            .set_lut(spr_ui_journal_inventory_currency_font_lut)
    }

    function build_equipment_section() {
        var width = self.journal.left_body.get_width();

        self.equipment_header = ANCHOR.positional(self.info_section)
            .set_y(18)
            .set_size(width, 21)
            .set_vert_align(Align.BottomOut)

        self.equipment_title = title_for_journal(
            "misc_local/equipment",
            self.equipment_header,
            spr_ui_journal_inventory_equipment_icon,
        );

        self.equipment_section = ANCHOR.positional(self.equipment_header)
            .set_size(width, 34)
            .set_vert_align(Align.BottomOut)

        self.armor = new InventoryMenu(5, ARI.armor, self.left_pilot);
        self.armor.build(
            -20,
            0,
            self.equipment_section,
            Align.Center,
            Align.Middle
        );
        self.armor.transfer_only(false);
        self.armor_subscriber = new InventorySubscriber(ARI.armor);

        var defense = ANCHOR.text(self.equipment_section)
            .set_text(ARI.get_damage_mitigation())
            .set_align(Align.RightIn, Align.Middle)
            .set_x(-3)
            .set_lut(COMMON_LUT, CommonLutIndex.Green)
            .set_sprite_font("player_level");

        defense.set_think_callback(function(defense) {
            defense.set_text(ARI.get_damage_mitigation());
        }, [defense])

        ANCHOR.sprite(defense)
            .set_align(Align.LeftOut, Align.Middle)
            .set_x(-2)
            .set_sprite(spr_ui_journal_inventory_defense_icon)

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
    }

    function build_skill_section() {
        var width = self.journal.left_body.get_width();

        self.skill_header = ANCHOR.positional(self.equipment_section)
            .set_size(width, 21)
            .set_vert_align(Align.BottomOut)

        self.skill_title = title_for_journal(
            "misc_local/skills",
            self.skill_header,
            spr_ui_journal_inventory_skills_icon,
        );

        self.skill_section = common_slice(self.skill_header)
            .set_size(width + 2, 44)
            .set_xy(-1, -1)
            .set_vert_align(Align.BottomOut)
            .set_enabled_sprite(spr_nothing_nineslice)
            .add_to_pilot(self.left_pilot, true)
            .set_tap_callback(function() {
                var popup = popup_creator("misc_local/skill_levels")
                popup.backplate.set_size(216, 237);
                popup.sub_plate = ANCHOR.nine_slice(popup.backplate)
                    .set_size(150, 178)
                    .set_align(Align.Center, Align.Middle)
                    .set_sprite(spr_ui_generic_box_main)

                static ORDER = [
                    Skill.Farming,
                    Skill.Fishing,
                    Skill.Ranching,
                    Skill.Mining,
                    Skill.Combat,
                    Skill.Archaeology,
                    Skill.Cooking,
                    Skill.Blacksmithing,
                    Skill.Woodcrafting,
                ];
                var yy = 5;
                for (var i = 0; i < array_length(ORDER); i++) {
                    var skill = ORDER[i];
                    var backplate = ANCHOR.sprite(popup.sub_plate)
                        .set_sprite(spr_ui_journal_inventory_skills_rect)
                        .set_xy(7, yy)
                        .set_align(Align.LeftIn, Align.TopIn)

                    render_skill_level(backplate, skill);

                    var plate_sprite = undefined;
                    switch skill {
                        case Skill.Farming:
                        case Skill.Fishing:
                        case Skill.Ranching:
                            plate_sprite = spr_ui_journal_skill_progress_bar_green;
                            break;
                        case Skill.Mining:
                        case Skill.Combat:
                        case Skill.Archaeology:
                            plate_sprite = spr_ui_journal_skill_progress_bar_blue;
                            break;
                        case Skill.Cooking:
                        case Skill.Blacksmithing:
                        case Skill.Woodcrafting:
                            plate_sprite = spr_ui_journal_skill_progress_bar_pink;
                            break;
                        default: impossible("Unexpected Skill: {Skill}", skill);
                    }

                    var bar = ANCHOR.sprite(backplate)
                        .set_align(Align.RightOut, Align.Middle)
                        .set_x(7)
                        .set_sprite(plate_sprite)

                    var current_level = ARI.level(skill);
                    if current_level == MAX_SKILL_LEVEL {
                        bar.set_index(bar.frame_count - 1);
                    } else {
                        var current_points = skill_level_cost(skill, current_level);
                        var target_points = skill_level_cost(skill, current_level+ 1);
                        var distance = target_points - current_points;
                        var measure = ARI.skill_xp[skill] - current_points;
                        var progress = measure / distance;
                        bar.set_index(floor(progress * sprite_get_number(spr_ui_journal_skill_progress_bar_pink)));
                    }

                    yy += 19;
                }

                var button = popup.create_button("misc_local/close");
                button.add_y(4);
                popup.spawn();
            })

        static PADDING = 3;
        static ICON_WIDTH = sprite_get_width(spr_ui_journal_inventory_skills_rect);
        static Y_POSITIONS = [-10, 10];
        static ORDER = fiddle_get("ui/misc/player_menu_skill_category_order");
        for (var i = 0; i < array_length(ORDER); i++) {
            var row = ORDER[i];
            var size = array_length(row);
            var positions = centered_positions(size, ICON_WIDTH, PADDING);
            for (var j = 0; j < size; j++) {
                var skill_id = string_to_skill(row[j]);
                var backplate = ANCHOR.sprite(self.skill_section)
                    .set_sprite(spr_ui_journal_inventory_skills_rect)
                    .set_xy(positions[j], Y_POSITIONS[i])
                    .set_align(Align.Center, Align.Middle)

                render_skill_level(backplate, skill_id);
            }
        }
    }

    function on_think() {
        self.armor_subscriber.pull().for_each(function(slot) {
            var item = slot.item;
            if item != undefined
                && item.prototype.cosmetic_to_unlock != undefined
                && !ARI.cosmetic_unlocks.contains(item.prototype.cosmetic_to_unlock)
            {
                ARI.cosmetic_unlocks.insert(item.prototype.cosmetic_to_unlock);
                var dummy_item = new LiveItem(ItemId.Cosmetic);
                dummy_item.cosmetic = item.prototype.cosmetic_to_unlock;
                await_popup(new_item_popup, [dummy_item]);

                self.journal.check_for_cosmetic_alert();
            }

            //
            //
            if instance_exists(obj_ari) {
                obj_ari.refresh_light();
            }
        })
    }

    function on_close() {
        //
        //
        if self.inventory.hand_node != undefined {
            ANCHOR.free_node(self.inventory.hand_node);
        }
    }

    self.left_pilot = self.new_pilot();

    self.build_info_section();

    self.build_equipment_section();

    self.build_skill_section();

    self.inventory_title = title_for_journal(
        "misc_local/inventory",
        self.journal.right_header,
        spr_ui_journal_inventory_header_icon,
    );

    var width = self.journal.left_body.get_width();

    self.inventory_section = ANCHOR.positional(self.journal.right_body)
        .set_size(width, 157)

    self.inventory_pilot = self.new_pilot();
    self.inventory = new InventoryMenu(5, ARI.inventory, self.inventory_pilot);
    self.inventory.build(
        -12,
        0,
        self.journal.right_page,
        Align.Center,
        Align.Middle
    );
    self.inventory.transfer_only(false);

    self.inventory_pilot.set_neighbor(self.left_pilot, Cardinal.West);
    self.left_pilot.set_neighbor(self.inventory_pilot, Cardinal.East);

    self.armor.pair_with(self.inventory);

    self.button_section = ANCHOR.positional(self.inventory_section)
        .set_size(width, 22)
        .set_vert_align(Align.BottomOut)

    self.trash_icon = ANCHOR.sprite(self.button_section)
        .set_x(-15)
        .set_align(Align.RightIn, Align.Middle)
        .set_tap_sound("SoundEffects/UI/UITrashItem")
        .set_sprites_from_key("spr_ui_journal_inventory_trash_button")
        .lock()
        .add_glyph(InputId.Throw)
        .set_tap_callback(function() {
            if keyboard_check(vk_shift) {
                self.inventory.hand.slot(0).drain();
            } else {
                self.inventory.hand.slot(0).pop();
            }
            self.trash_icon.add_y(-4);
            new_chain()
                .join(LinkId.Ease, new Ease(EaseId.ElasticOut, 0, 4, 30), function(delta) {
                    self.trash_icon.add_y(delta);
                })
                .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0.5, 1, 30), function(_, a) {
                    self.trash_icon.set_alpha(a);
                });
        })
        .set_think_callback(function() {
            var item = self.inventory.hand.slot(0).item;
            self.trash_icon.set_unlocked(item != undefined && !item_is_soulbound(item.item_id));
        })

    self.sort_icon = ANCHOR.sprite(self.button_section)
        .set_x(-45)
        .set_align(Align.RightIn, Align.Middle)
        .set_sprites_from_key("spr_ui_journal_inventory_sort_button")
        .add_glyph(InputId.SecondaryInteract)
        .set_tap_callback(function() {
            ARI.inventory.sort();
        })

    //
    if ON_GAMEPAD {
        self.sort_icon.glyph_node.add_x(4);
    }

    var insert = local_language() == "rus" ? "_ru" : "";

    self.a_tab = ANCHOR.sprite(self.inventory.canvas)
        .set_align(Align.RightOut, Align.TopIn)
        .set_sprite(string_to_asset(format("spr_ui_journal_inventory_section_a{}", insert)))
        .set_xy(-8, 10)

    self.b_tab = ANCHOR.sprite(self.a_tab)
        .set_align(Align.LeftIn, Align.BottomOut)
        .set_sprite(string_to_asset(format("spr_ui_journal_inventory_section_b{}", insert)))
        .set_enabled(ARI.inventory.size() > 10)
        .set_y(2)

    self.c_tab = ANCHOR.sprite(self.b_tab)
        .set_align(Align.LeftIn, Align.BottomOut)
        .set_sprite(string_to_asset(format("spr_ui_journal_inventory_section_c{}", insert)))
        .set_enabled(ARI.inventory.size() > 20)
        .set_y(2)

    ANCHOR.set_active_pilot(self.inventory_pilot);
}
