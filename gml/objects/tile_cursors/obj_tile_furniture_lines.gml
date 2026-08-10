object_create(
    "obj_tile_furniture_lines",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            valid = false;
            cursor_data = undefined;
            splotch_data = undefined;
            line_alpha = 1.0
            render_arrow = undefined;
        },
        step_begin: function() {
            self.splotch_data = undefined;
            self.cursor_data = undefined;
            self.render_arrow = undefined;
        },
        draw: function() {
            if self.splotch_data != undefined {
                draw_test_placement_furniture_splotches(
                    self.valid,
                    self.splotch_data,
                    x,
                    y,
                );
            }

            if self.cursor_data != undefined {
                draw_test_placement_furniture_lines(
                    self.valid,
                    self.cursor_data,
                    x,
                    y,
                    self.line_alpha,
                );
            }

            if self.render_arrow != undefined {
                var render_points = furniture_arrow_offset(
                    self.render_arrow,
                    self.top_left_x,
                    self.top_left_y,
                    self.bot_right_x,
                    self.bot_right_y,
                );
                draw_sprite_ext(render_points[0], 0, render_points[1], render_points[2], 1, 1, 0, c_white, 1.0);
            }
        },
    }
);
