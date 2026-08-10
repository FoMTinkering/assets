enum FarmBuildingSelectionState {
    Start,
    Select,
    End,
}

function FarmBuildingSelectionMenu() : AnchorMenu(Menu.FarmBuildingSelection) constructor {
    function start() {
        self.canvas.set_alpha(0);
        var buildings = get_buildings();
        for (var i = 0; i < buildings.count(); i++) {
            var building = buildings.get(i);
            if building.prototype.player_building_kind == PlayerBuildingKind.Stable
                && (self.size_restriction == undefined || building.prototype.permitted_animal_size == self.size_restriction)
            {
                self.buildings.push(building);
            }
        }
        self.player_start_pos = new LocationPosition(
            CURRENT_LOCATION_ID,
            Vec2(obj_ari.x, obj_ari.y),
            CURRENT_DYN_INDEX,
        );

        var itin = goto_location_id(LocationId.Farm);
        itin.no_player();
    }

    function select_index(index, instant) {
        if instant == undefined {
            instant = false;
        }
        self.index = index;
        var building = self.buildings.get(self.index);
        self.name.set_text(building.name);
        var xx = building.top_left_x * 8 + building.prototype.offset.x;
        var yy = building.top_left_y * 8 + (building.prototype.offset.y / 2);
        if instant {
            CAMERA.follow_point_instant(xx, yy);
        } else {
            CAMERA.pan(xx, yy, 60, EaseId.QuadOut);
        }
        var occupancy_count = building.stable.occupancy();
        self.animals_count_text.set_text(fmt(
            "{}/{}",
            occupancy_count,
            building.prototype.max_occupants,
        ));
        self.refresh_scroller();
        var occupants = building.stable.animals();

        for (var i = 0; i < occupants.count(); i++) {
            var animal = occupants.get(i);
            var element = self.animals_scroller.new_element(27);
            var icon_data = get_animal_icon_data(
                animal.kind,
                animal.variant,
                animal.sex,
                !animal.is_baby(),
            );
            var animal_icon = ANCHOR.sprite(element)
                .set_x(5)
                .set_align(Align.LeftIn, Align.Middle)
                .set_sprite(icon_data.sprite);

            if icon_data.lut != undefined {
                animal_icon.set_lut(icon_data.lut, icon_data.lut_index);
            }

            ANCHOR.sprite(animal_icon)
                .set_sprite(animal.sex == Sex.Female ? spr_ui_generic_female_icon : spr_ui_generic_male_icon)
                .set_xy(2, 2)
                .set_align(Align.RightIn, Align.BottomIn)

            ANCHOR.text(animal_icon)
                .set_x(5)
                .set_align(Align.RightOut, Align.Middle)
                .set_text(animal.name)
                .set_lut(COMMON_LUT)
        }
        if occupancy_count >= building.prototype.max_occupants {
            self.select_button.lock()
        } else {
            self.select_button.unlock()
        }
    }

    function refresh_scroller() {
        if self.animals_scroller != undefined {
            self.animals_scroller.free();
        }
        self.animals_scroller = create_scroller(
            self.animal_box_body,
            Vec2(2, 36),
            Vec2(111, 104),
        );
    }

    function return_player() {
        if self.player_start_pos.dyn_index != undefined {
            var itin = goto_dynamic_location(self.player_start_pos.dyn_index);
        } else {
            var itin = goto_location_id(self.player_start_pos.location_id);
        }
        itin.set_exact_position(self.player_start_pos.pos.x, self.player_start_pos.pos.y);
    }

    function restrict_to_animal_size(animal_size) {
        self.size_restriction = animal_size;
        return self;
    }

    function set_title(key) {
        self.title.set_key(key);
        return self;
    }

    function set_arrival_callback(callback, args) {
        self.arrival_callback = callback;
        self.arrival_callback_args = args ?? [];
        return self;
    }

    function set_end_callback(callback, args) {
        self.end_callback = callback;
        self.end_callback_args = args ?? [];
        return self;
    }

    self.state = FarmBuildingSelectionState.Start;
    self.player_start_pos = undefined;
    self.index = 0;
    self.output_building_idx = undefined;
    self.buildings = List();
    self.size_restriction = undefined;
    self.arrival_callback = undefined;
    self.arrival_callback_args = undefined;
    self.end_callback = undefined;
    self.end_callback_args = undefined;

    self.canvas.set_room_start_callback(function() {
        switch self.state {
            case FarmBuildingSelectionState.Start:
                self.canvas.set_alpha(1);
                self.select_index(0, true);
                self.state = FarmBuildingSelectionState.Select;
                function_execute_alt(self.arrival_callback, self.arrival_callback_args);
                break;
            case FarmBuildingSelectionState.End:
                var args = [self.output_building_idx];
                for (var i = 0; i < array_length(self.end_callback_args); i++) {
                    array_push(args, self.end_callback_args[i]);
                }
                function_execute_alt(self.end_callback, args);
                self.close();
                break;
        }
    })
    .set_think_callback(function() {
        GLYPH_GUIDE.set_input(InputId.MenuBack, "misc_local/back");
        if self.state == FarmBuildingSelectionState.Select {
            if INPUT.take_press(InputId.MenuBack) {
                self.return_player();
                self.state = FarmBuildingSelectionState.End;
                return;
            }

            var imod = 0;
            if INPUT.pressed(InputId.Right) {
                imod += 1;
            }
            if INPUT.pressed(InputId.Left) {
                imod -= 1;
            }
            if imod != 0 {
                var index = wrap(
                    self.index + imod,
                    self.buildings.count()
                );
                self.select_index(index);
            }
        }
    })

    self.nameplate = ANCHOR.nine_slice(self.canvas)
        .set_size(184, 32)
        .set_sprite(spr_ui_popup_box_large)
        .set_align(Align.Center, Align.BottomIn)
        .set_y(-4)

    self.name = ANCHOR.text(self.nameplate)
        .set_align(Align.Center, Align.Middle)
        .set_lut(COMMON_LUT)

    self.left_arrow = ANCHOR.sprite(self.nameplate)
        .set_sprites_from_key("spr_ui_scroller_arrow_left")
        .set_align(Align.LeftIn, Align.Middle)
        .set_x(8)
        .set_bbox_offset(-6, -6, 12, 16)
        .set_tap_callback(function() {
            var index = wrap(
                self.index - 1,
                self.buildings.count()
            );
            self.select_index(index);
        })

    self.right_arrow = ANCHOR.sprite(self.nameplate)
        .set_sprites_from_key("spr_ui_scroller_arrow_right")
        .set_align(Align.RightIn, Align.Middle)
        .set_x(-8)
        .set_bbox_offset(-6, -6, 12, 16)
        .set_tap_callback(function() {
            var index = wrap(
                self.index + 1,
                self.buildings.count()
            );
            self.select_index(index);
        })

    self.titleplate = ANCHOR.nine_slice(self.canvas)
        .set_size(260, 32)
        .set_sprite(spr_ui_popup_box_large)
        .set_align(Align.Center, Align.TopIn)
        .set_y(4)

    self.title = ANCHOR.text(self.titleplate)
        .set_align(Align.Center, Align.Middle)
        .set_lut(COMMON_LUT)
        .set_key("misc_local/farm_building_select_title")

    self.animal_box_body = ANCHOR.nine_slice(self.canvas)
        .set_sprite(spr_ui_tooltip_box)
        .set_align(Align.RightIn, Align.Middle)
        .set_size(135, 145)
        .set_x(-4)

    self.animal_box_header = ANCHOR.nine_slice(self.animal_box_body)
        .set_sprite(spr_ui_tooltip_header_box)
        .set_align(Align.Center, Align.TopIn)
        .set_size(135, 37)

    self.animals_label = ANCHOR.text(self.animal_box_header)
        .set_key("misc_local/animals")
        .set_lut(COMMON_LUT, CommonLutIndex.Header)
        .set_align(Align.Center, Align.Middle)
        .set_y(-4)

    self.animals_count_text = ANCHOR.text(self.animal_box_header)
        .set_sprite_font("player_level")
        .set_lut(COMMON_LUT, CommonLutIndex.Header)
        .set_align(Align.Center, Align.Middle)
        .set_y(8)

    self.select_button = ANCHOR.nine_slice(self.animal_box_body)
        .set_align(Align.Center, Align.BottomOut)
        .set_y(15)
        .set_size(64, 28)
        .set_sprites_from_key("spr_ui_button_chunky")
        .add_glyph(InputId.Interact)
        .add_text_label("misc_local/select", COMMON_LUT, CommonLutIndex.Dark)
        .set_tap_callback(function() {
            if self.state == FarmBuildingSelectionState.Select {
                self.output_building_idx = self.buildings.get(self.index).dyn_index;
                self.return_player();
                self.state = FarmBuildingSelectionState.End;
            }
        })

    self.animals_scroller = undefined;
}
