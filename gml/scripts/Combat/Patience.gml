#macro PATIENCE_STANDARD 120
#macro PATIENCE_DAMAGED 240

function Patience(xx, yy, size=192, use_circle=false) constructor {
    self.shared_box = true;
    self.use_circle = false;

    if use_circle {
        self.use_circle = true;
        self.diameter = size;
        self.pos = Vec2(xx, yy);
    } else {
        self.aggro_box = instance_create_depth(xx, yy, -1000, par_aggro_box);
        self.shared_box = false;

        //
        self.aggro_box.x -= size / 2;
        self.aggro_box.y -= size / 2;
        self.aggro_box.image_xscale = size;
        self.aggro_box.image_yscale = size;
    }
    self.value = -1;

    function aggro() {
        var do_it;
        if self.use_circle {
            do_it = collision_circle(
                self.pos.x,
                self.pos.y,
                self.diameter * 0.5,
                obj_ari,
            );
        } else {
            do_it = overlap_point(obj_ari.x, obj_ari.y, self.aggro_box);
        }

        if do_it != undefined {
            //
            self.value = PATIENCE_STANDARD;

            return true;
        }

        return self.value >= 0;
    }

    function tick() {
        self.value -= 1;
    }

    function destroy() {
        if self.shared_box == false {
            instance_destroy(self.aggro_box);
        }
    }
}
