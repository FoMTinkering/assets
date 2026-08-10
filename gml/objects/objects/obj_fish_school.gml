object_create(
    "obj_fish_school",
    undefined,
    {
        sprite_index: spr_fishschool_silhouette,
        create: function() {
            self.depth = get_water_depth();
            self.fish_id = undefined;
            self.crashed = false;
            FishSchoolFsm();
        },
        step: function() {
            if game_paused() {
                return;
            }

            if self.image_alpha < 1 && self.fsm.current_state_id() != FishSchoolState.Disperse {
                self.image_alpha += 0.025;
            }

            self.fsm.step();
        },
        step_begin: function() {
            if game_paused() {
                return;
            }
            self.fsm.new_tick();
        },
        draw: function() {
            //
            //
            //
            self.fsm.draw();

            if DEBUG_TOOLS && FISH_SHOULD_DRAW_NAME {
                draw_set_font(ANCHOR.get_text_font());
                draw_set_halign(HorizontalOffset.Middle);
                var output = "";

                for (var i = 0; i < self.fish_in_school.count(); i++) {
                    var fish = self.fish_in_school.get(i);
                    output = format("{}\n{}", output, format("{FishId}", fish.prototype.id));
                }

                draw_text(x, y, output);
            }
        },
    }
);
