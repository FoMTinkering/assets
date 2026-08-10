object_create(
    "obj_debris",
    undefined,
    {
        sprite_index: spr_debris,
        create: function() {
            follow_obj = undefined;
            sway = false;
            angle_lock = undefined;
            start_alpha_fadeout = 4/5;
            init_alpha = 1;
            image_speed = 1;

            var spd_scale = random_range(0.5, 1);
            lifetime = room_speed * 0.9 * spd_scale;
            spd = 2 * spd_scale;
            grav = 0.08;
            grav_inc = 0.066 * spd_scale;
            spd_inc = -0.02 * spd_scale;
            angle_inc = 0;
            dir = random_range(60, 120);
            ydir = 270;

            size_inc = -0.00;
            counter = 0;

            kill_on_end = false;

            follow_object_xprevious = 0;
            follow_object_yprevious = 0;
        },
        step: function() {
            counter++;

            if(counter/lifetime > start_alpha_fadeout) {
                image_alpha = lerp(
                    init_alpha, 0,
                    (counter - (lifetime * start_alpha_fadeout)) / (lifetime * (1 - start_alpha_fadeout))
                );
            }

            if(sway) {
                spd += sin(dir)*spd_inc;
                grav += grav_inc;
                dir += 10;
                x += sin(lengthdir_x(spd*2, dir));
                y += lengthdir_y(spd, ydir) + grav;
            } else {
                grav += grav_inc;
                spd += spd_inc;
                x += lengthdir_x(spd, dir);
                y += lengthdir_y(spd, dir) + grav;
            }

            if (angle_inc != 0){
                image_angle += angle_inc;
            }
            image_xscale += size_inc;
            image_yscale = image_xscale;

            if(counter > lifetime) {
                instance_destroy();
            }

            var _angle = image_angle;
            if(angle_lock != undefined) {
                _angle = (image_angle div angle_lock) * angle_lock;
            }
        },
        step_end: function() {
            if follow_obj != undefined && instance_exists(follow_obj) {
                x += self.follow_object_xprevious - follow_obj.x;
                y += follow_obj.y - self.follow_object_yprevious;
                self.follow_object_xprevious = follow_obj.x;
                self.follow_object_yprevious = follow_obj.y;
            }
        },
    }
);
