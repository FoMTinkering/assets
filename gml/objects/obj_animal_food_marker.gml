object_create(
    "obj_animal_food_marker",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            animal_claimed = false;
            processed = false;

            original_x = x;
            original_y = y;
        },
    }
);
