object_create(
    "obj_renderer",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            self.draw_call = function () {};
            self.args = [];
        },
        draw: function() {
            if sprite_index != undefined {
                draw_self();
            }

            if self.draw_call != undefined {
                function_execute_alt(self.draw_call, self.args);
            }
        },
    }
);
