object_create(
    "obj_fishy",
    undefined,
    {
        sprite_index: spr_fish_silhouette_small_0_idle,
        create: function() {
            depth = get_water_depth() - 1;

            FishFsm();
            FISHING.subscribe(id);
        },
        step: function() {
            if game_paused() {
                return;
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

            if self.fsm.current_state_id() != FishState.Flee && self.image_alpha < 1 {
                self.image_alpha += 0.1;
            }

            //
            if self.sparkle {
                var w = (bbox_right - bbox_left) /2 ;
                draw_sprite_ext(
                    self.sparkle_sprite,
                    ((current_time() / 1000) * 60) * FRAME_TIME,
                    x + lengthdir_x(w, self.dir + 180),
                    y + lengthdir_y(w, self.dir + 180),
                    1,
                    1,
                    0,
                    c_white,
                    1
                );
            }

            if DEBUG_TOOLS && FISH_SHOULD_DRAW_NAME {
                draw_set_font(ANCHOR.get_text_font());
                draw_set_halign(HorizontalOffset.Middle);
                draw_text(x, y, format("{FishId}", self.fish_loot.prototype.id));
            }
        },
    }
);
