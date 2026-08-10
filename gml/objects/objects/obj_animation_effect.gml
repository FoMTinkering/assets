object_create(
    "obj_animation_effect",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            self.following_object = undefined;
            self.relative_depth = 0;
            self.y_offset = 0;
            self.lifetime_frames = undefined;
            self.live_on_anim_end = false;
            self.freeze_on_anim_end = false;
            self.alpha_tween_amount = 0;

            //
            //
            self.image_idx = undefined;
            self.image_idx_func = undefined;

            function release_object() {
                self.following_object = undefined;
            }
        },
        step: function() {
            if self.following_object != undefined && instance_exists(self.following_object) {
                x = self.following_object.x + self.x_offset;
                y = self.following_object.y + self.y_offset;
                depth = self.following_object.depth + self.relative_depth;
            }

            if self.image_idx_func != undefined && (self.image_index + self.image_speed) >= self.image_idx {
                self.image_idx_func();
                if !instance_exists(self) {
                    return;
                }
                self.image_idx = undefined;
                self.image_idx_func = undefined;
            }

            self.image_alpha -= self.alpha_tween_amount;

            if self.lifetime_frames != undefined {
                self.lifetime_frames -= 1;
                if (self.lifetime_frames <= 0) {
                    instance_destroy();
                }
            }
        },
        animation_end: function() {
            if self.lifetime_frames == undefined && !self.live_on_anim_end {
                instance_destroy();
            }

            if self.freeze_on_anim_end {
                self.image_speed = 0;
                self.image_index = self.image_number - 1;
            }
        },
    }
);
