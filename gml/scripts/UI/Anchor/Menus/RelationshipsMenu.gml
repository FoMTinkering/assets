function RelationshipsMenu() : AnchorMenu(Menu.Relationships) constructor {
    function set_to_npc_id(npc_id) {
        self.active_npc = NPCS[npc_id];
        var proto = NPC_PROTOTYPES[npc_id];
        self.npc_id_current = npc_id;

        self.npc_field.icon.set_sprite(get_small_npc_icon(npc_id));
        self.npc_field.text.set_key(proto.name);
        self.birthday_field.text.set_text(format(
            "{Local} {}",
            "misc_local/" + season_to_string(proto.birthday.season),
            proto.birthday.day,
        ));

        var relationship_key = "misc_local/single";
        if self.active_npc.is_spouse() {
            relationship_key = "misc_local/spouse";
        } else if self.active_npc.is_fiance() {
            //
            relationship_key = self.active_npc.prototype.can_carry_child
                ? "misc_local/fiancee"
                : "misc_local/fiance";
        } else if self.active_npc.is_dating() {
            relationship_key = "misc_local/dating";
        } else if self.active_npc.is_best_friend() {
            relationship_key = "misc_local/best_friend";
        }
        self.relationship_field.text.set_key(relationship_key);
        self.job_field.text.set_key(proto.job);
        self.relationship_field.icon.set_enabled(proto.dateable);

        self.polaroid.background.enable();
        self.polaroid.set_to_npc(npc_id);

        if proto.dateable {
            var sprites = fiddle_get("ui/textbox/dateable_heart_sprites");
            var sprite = string_to_asset(sprites[NPCS[npc_id].heart_level()]);
            self.portrait_heart.enable();
            self.portrait_heart.set_sprite(sprite);
        } else {
            self.portrait_heart.disable();
        }

        self.gift_nodes.set_to_npc(npc_id);
    }

    self.journal = ANCHOR.get_menu(Menu.Journal);
    self.journal.left_page.set_sprite(spr_ui_journal_book_page_layout_relationships_left);
    self.journal.right_page.set_sprite(spr_ui_journal_book_page_layout_relationships_right);

    var alt = matches(local_language(), "fra", "spa", "rus");
    self.polaroid = npc_polaroid_ui(self.journal.right_page, alt);
    self.polaroid.background.disable();

    self.portrait_heart = ANCHOR.sprite(self.polaroid.frame)
        .set_xy(-1, -1)

    self.detail_zone = ANCHOR.positional(self.journal.right_full_body)
        .set_size(94, 117)
        .set_align(Align.RightIn, Align.TopIn)

    if alt {
        self.detail_zone.add_width(4);
    }

    self.gift_nodes = gift_preferences_ui(self.detail_zone);

    self.field_zone = ANCHOR.positional(self.journal.right_full_body)
        .set_size(self.journal.right_full_body.get_width(), 61)
        .set_align(Align.Center, Align.BottomIn)

    var field = function(yy, icon, lut_index=1) {
        var icon_node = ANCHOR.sprite(self.field_zone)
            .set_xy(2, yy)
            .set_sprite(icon)
            .set_speed(1)

        var text_node = ANCHOR.text(icon_node)
            .set_align(Align.RightOut, Align.Middle)
            .set_x(3)
            .allow_line_breaks()
            .set_max_width(156)
            .set_line_height(11)
            .set_lut(COMMON_LUT, lut_index)

        return {
            icon: icon_node,
            text: text_node,
        };
    }

    var yy = 3;
    self.npc_field = field(yy, spr_illegal_8);
    yy += 14;
    self.birthday_field = field(yy, spr_ui_generic_birthday_icon);
    yy += 14;
    self.job_field = field(yy, spr_ui_generic_job_icon);
    yy += 14;
    self.relationship_field = field(yy, spr_ui_generic_relationship_icon, CommonLutIndex.Green);

    self.pilot = self.new_pilot()
        .allow_vertical_wrapping()

    self.npc_scroller = create_scroller(self.journal.left_body);
    self.npc_scroller.subscribe_to_pilot(self.pilot);

    self.title = title_for_journal("misc_local/villagers", self.journal.left_header, spr_ui_journal_relationship_header_icon);

    self.npc_id_current = undefined;

    //
    var alpha_ordered_npcs = ListFromArray(array_create_ext(NpcId.LEN, identity));

    //
    if matches(local_language(), "spa", "fra") {
        alpha_ordered_npcs.sort_with(function(a, b) {
            return string_alphanumeric_comparison(
                local_get(NPC_PROTOTYPES[a].name),
                local_get(NPC_PROTOTYPES[b].name),
            );
        })
    }
    for (var i = 0; i < NpcId.LEN; i++) {
        var npc_id = alpha_ordered_npcs.get(i);
        var npc_data = NPCS[npc_id];

        if !npc_is_unlocked(npc_id) {
            continue;
        }

        //
        if array_contains(npc_data.prototype.tags, "vendor") && !npc_data.has_met() {
            continue;
        }

        //
        //
        //
        if array_contains(npc_data.prototype.tags, "animal")
            && !npc_data.has_met()
            && !QUEST_LOG.completed.contains("greet_the_townsfolk")
        {
            continue;
        }

        var element = self.npc_scroller.new_element(40)
            .add_to_pilot(self.pilot, true)
            .set_alpha(npc_data.has_met() ? 1 : UI_FADE_ALPHA)
            .board_set("npc_id", npc_id)
        element
            .add_text_label(
                npc_data.has_met() ? npc_data.prototype.name : ANCHOR.wrap_for_local("???"),
                COMMON_LUT,
            )
            .set_selected_getter(function(npc_id) {
                return self.npc_id_current == npc_id;
            }, [npc_id])

        if npc_data.has_met() {
            element.set_tap_callback(function(npc_id) {
                self.set_to_npc_id(npc_id);
            }, [npc_id])
        }


        element.text_label
            .set_xy(35, 4)
            .set_align(Align.LeftIn, Align.TopIn)

        var pack = npc_data
            .wardrobe
            .outfit_current
            .cycles
            .get("idle");

        if pack == undefined {
            pack = npc_data
                .wardrobe
                .outfits
                .get(npc_data.prototype.fallback_outfit)
                .cycles
                .get("idle");
        }

        var npc = ANCHOR.sprite(element)
            .set_sprite(pack.south_pack.sprite)
            .set_xy(-23, -21)
            .set_color(npc_data.has_met() ? c_white : c_black);

        var data = fiddle_get(format("npcs/{NpcId}",npc_id));
        if data[$ "journal_person_offset"] != undefined {
            npc.add_x(data.journal_person_offset[0]);
            npc.add_y(data.journal_person_offset[1]);
        }

        var hearts = ANCHOR.sprite(element)
            .set_sprite(spr_ui_journal_relationship_heart_level)
            .set_index(npc_data.heart_level())
            .set_align(Align.RightIn, Align.TopIn)
            .set_xy(-14, 7)

        var bar = ANCHOR.sprite(hearts)
            .set_align(Align.Center, Align.BottomOut)
            .set_xy(-1, 4)
            .set_sprite(spr_ui_journal_relationship_heart_progress_bar)

        if npc_data.heart_level() == 10 {
            bar.set_index(bar.frame_count - 1);
        } else {
            var current_points = npc_heart_level_to_points(npc_data.heart_level());
            var target_points = npc_heart_level_to_points(npc_data.heart_level() + 1);
            var distance = target_points - current_points;
            var measure = npc_data.heart_points - current_points;
            var progress = measure / distance;
            bar.set_index(floor(progress * sprite_get_number(spr_ui_journal_relationship_heart_progress_bar)));
        }

        var talk_icon = ANCHOR.sprite(element.text_label)
            .set_sprite(spr_ui_journal_relationship_talk_icon)
            .set_align(Align.LeftIn, Align.BottomOut)
            .set_y(4)

        var talk_check = ANCHOR.sprite(talk_icon)
            .set_sprite(npc_data.times_spoken_today > 0 ? spr_ui_generic_checkbox_on : spr_ui_generic_checkbox_off)
            .set_align(Align.RightOut, Align.Middle)
            .set_x(2)

        var gift_icon = ANCHOR.sprite(talk_check)
            .set_sprite(spr_ui_journal_relationship_gift_icon)
            .set_align(Align.RightOut, Align.Middle)
            .set_x(4)

        ANCHOR.sprite(gift_icon)
            .set_sprite(!npc_data.gift_flag ? spr_ui_generic_checkbox_on : spr_ui_generic_checkbox_off)
            .set_align(Align.RightOut, Align.Middle)
            .set_x(2)

        //
    }

    ANCHOR.set_active_pilot(self.pilot);

    self.set_to_npc_id(NpcId.Adeline);
}
