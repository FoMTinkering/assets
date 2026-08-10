object_create(
    "obj_kitchen_ingredient",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            self.counter = 0;
            self.lifetime = 45;
            self.throw_height = -1 * random_range(1, 2);
        },
        step: function() {

            y += cos(pi * (self.counter / self.lifetime)) * self.throw_height;
            x += self.dir * sin(pi * (self.counter / self.lifetime)) * 0.05;

            if(self.lifetime - self.counter < 10) {
                image_alpha -= 0.1;
            }

            self.counter++;
        },
    }
);
