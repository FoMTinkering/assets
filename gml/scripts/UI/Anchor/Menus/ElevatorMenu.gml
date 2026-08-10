function ElevatorMenu() : AnchorMenu(Menu.Elevator) constructor {
    self.backplate = ANCHOR.sprite(self.canvas)
        .set_align(Align.Center, Align.Middle)
        .set_sprite(spr_ui_dungeon_elevator_backplate)

    self.pilot = self.new_pilot()
        .allow_horizontal_wrapping()
        .allow_vertical_wrapping()

    var xx = 12;
    var yy = 12;
    var max_level = MAXIMUM_REACHED_DUNGEON_LEVEL + 1;
    var current_floor = is_dungeon_room(room()) ? DUNGEON_FLOOR + 1 : 0;
    var flr = 0;
    for (var i = 0; i < 7; i++) {
        for (var j = 0; j < 3; j++) {
            var button = ANCHOR.sprite(self.backplate)
                .set_xy(xx, yy)
                .set_unlocked(max_level >= flr)
                .add_to_pilot(self.pilot)
                .set_tap_callback(function(flr, current_floor) {
                    if flr == current_floor {
                        return;
                    }
                    TANGO.play("SoundEffects/Entrances/ElevatorUse");
                    ARI.used_elevator = true;

                    self.close();
                    if room() != rm_mines_entry {
                        game_stats_end_mines_floor("elevator");
                    }
                    if flr == 0 {
                        var pos = trellis_point("mines_entry/elevator");
                        goto_location_id(LocationId.MinesEntry)
                            .set_exact_position(pos.x, pos.y);
                    } else {
                        enter_dungeon(flr - 1);
                    }
                }, [flr, current_floor]);

            var flr_insert = flr == 0 ? "g" : string(flr);
            if flr == current_floor {
                button.set_sprites_from_key(format("spr_ui_dungeon_elevator_button_gold_{}", flr_insert));
            } else {
                button.set_sprites_from_key(format("spr_ui_dungeon_elevator_button_grey_{}", flr_insert));
            }

            xx += 23;
            flr += 5;
        }
        self.pilot.request_newline();
        xx = 12;
        yy += 23;
    }

    ANCHOR.set_active_pilot(self.pilot);
}
