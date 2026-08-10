object_create(
    "obj_shooting_star_generator",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            timer_range = fiddle_deserialize_vec2(fiddle_get("shooting_star").generator_time);
            current_timer = irandom_range(timer_range.x, timer_range.y);
        },
        step: function() {
            self.current_timer -= 1;

            if self.current_timer <= 0 {
                var new_star = instance_create_depth(
                    x + irandom_range(-8, 8),
                    y,
                    -1000,
                    obj_shooting_star,
                );

                self.current_timer = new_star.time + irandom_range(timer_range.x, timer_range.y);
            }
        },
    }
);
