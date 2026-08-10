function MinesMenu() : AnchorMenu(Menu.Mines) constructor {
    self.backplate = ANCHOR.sprite(self.canvas)
        .set_sprite(spr_ui_dungeon_backplate)
        .set_room_start_callback(function() {
            if is_dungeon_room(room()) {
                self.backplate.enable();

                if DUNGEON_RUNNER.current_level()[$ "is_side_room"] == true {
                    self.number_one.set_text("?");
                    self.number_two.set_text("?");
                    self.number_three.set_text("?");
                    return;
                }

                var level_string = string(DUNGEON_FLOOR + 1);
                switch string_length(level_string) {
                    case 1:
                        self.number_one.set_text("0");
                        self.number_two.set_text("0");
                        self.number_three.set_text(level_string);
                        break;
                    case 2:
                        self.number_one.set_text("0");
                        self.number_two.set_text(string_char_at(level_string, 1));
                        self.number_three.set_text(string_char_at(level_string, 2));
                        break;
                    case 3:
                        self.number_one.set_text(string_char_at(level_string, 1));
                        self.number_two.set_text(string_char_at(level_string, 2));
                        self.number_three.set_text(string_char_at(level_string, 3));
                        break;
                }
                switch DUNGEON_IMPL {
                    case DungeonImpl.Enemy:
                        self.icon.set_index(5);
                        break;
                    case DungeonImpl.Fountain:
                        self.icon.set_index(4);
                        break;
                    case DungeonImpl.Interact:
                        self.icon.set_index(1);
                        break;
                    case DungeonImpl.LadderChoice:
                        self.icon.set_index(3);
                        break;
                    case DungeonImpl.Offering:
                        self.icon.set_index(2);
                        break;
                    case DungeonImpl.Standard:
                        self.icon.set_index(0);
                        break;
                    case DungeonImpl.Treasure:
                        self.icon.set_index(6);
                        break;
                    case DungeonImpl.Ritual:
                        self.icon.set_index(7);
                        break;
                    default: impossible("Unexpected DungeonImpl: {}", DUNGEON_IMPL);
                }
            } else {
                self.backplate.disable();
            }
        })
        .set_align(Align.Center, Align.TopIn)
        .set_y(6)

    self.icon = ANCHOR.sprite(self.backplate)
        .set_sprite(spr_ui_dungeon_type_floor)
        .set_xy(12, 5)

    self.root_one = ANCHOR.positional(self.backplate)
        .set_size(9, 14)
        .set_xy(28, 3)
    self.number_one = ANCHOR.text(self.root_one)
        .set_text("0")
        .set_align(Align.Center, Align.Middle)
        .set_sprite_font("player_level")
        .set_lut(spr_ui_dungeon_backplate_font_lut)

    self.root_two = ANCHOR.positional(self.backplate)
        .set_size(9, 14)
        .set_xy(38, 3)
    self.number_two = ANCHOR.text(self.root_two)
        .set_text("0")
        .set_align(Align.Center, Align.Middle)
        .set_sprite_font("player_level")
        .set_lut(spr_ui_dungeon_backplate_font_lut)

    self.root_three = ANCHOR.positional(self.backplate)
        .set_size(9, 14)
        .set_xy(48, 3)
    self.number_three = ANCHOR.text(self.root_three)
        .set_text("1")
        .set_align(Align.Center, Align.Middle)
        .set_sprite_font("player_level")
        .set_lut(spr_ui_dungeon_backplate_font_lut)


    self.backplate.disable();
}
