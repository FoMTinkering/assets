#macro POST_PROCESS global.__post_process
global.__post_process = undefined;

#macro POST_PROCESS_TIME_OVERRIDE global.__post_process_time_override
global.__post_process_time_override = undefined;

#macro INTERIOR_WINDOW_TIME_OVERRIDE global.__interior_window_time_override
INTERIOR_WINDOW_TIME_OVERRIDE = undefined;

function PostProcessor(post_process_track) constructor {
    multiply_color = undefined;

    vivid_color = undefined;
    levels = undefined;

    light_strength = undefined;
    shadow_multiply_color = post_process_track.init.shadow;

    self.multiply_tween = post_process_track.init.shading.multiply;
    self.vivid_tween = post_process_track.init.shading.vivid;
    self.levels_tween = post_process_track.init.shading.levels;
    self.shadow_multiply_tween = post_process_track.init.shadow;
    self.light_tween = post_process_track.init.light;

    self.multiply_color = post_process_track.init.shading.multiply.value;
    self.vivid_color = post_process_track.init.shading.vivid.value;
    self.levels = post_process_track.init.shading.levels.value;
    self.light_strength = post_process_track.init.light.value;
    self.shadow_multiply_color = post_process_track.init.shadow.value;

    self.last_multiply_color = self.multiply_color;
    self.last_vivid_color = self.vivid_color;
    self.last_levels = self.levels;
    self.last_light_strength = self.light_strength;
    self.last_shadow_color = self.shadow_multiply_color;

    initializer = post_process_track.init;
    frames = post_process_track.frames;
    should_post_process = false;
    multiply_by_light_count = post_process_track.multiply_by_light_count;
    min_multiply_level = post_process_track.min_multiply_level;

    function update(time) {
        time = max(min(time, hours(26)), hours(6));

        //
        self.multiply_color = move_tween_frame(self.multiply_tween, time, self.last_multiply_color);
        self.vivid_color = move_tween_frame(self.vivid_tween, time, self.last_vivid_color);
        self.shadow_multiply_color = move_tween_frame(self.shadow_multiply_tween, time, self.last_shadow_color);
        self.light_strength = move_tween_frame(self.light_tween, time, self.last_light_strength);
        self.levels = move_levels_tween_frame(self.levels_tween, time, self.last_levels);

        //
        for (var i = 0, c = self.frames.count(); i < c; i++) {
            var frame = self.frames.get(i);

            //
            if frame.time > time {
                break;
            }

            if frame.shading != undefined && frame.time > self.multiply_tween.start_time {
                //
                self.multiply_color = self.multiply_tween.value;
                self.vivid_color = self.vivid_tween.value;
                self.levels = self.levels_tween.value;

                self.last_multiply_color = self.multiply_color;
                self.last_vivid_color = self.vivid_color;
                self.last_levels = self.levels;

                self.multiply_tween = frame.shading.multiply;
                self.vivid_tween = frame.shading.vivid;
                self.levels_tween = frame.shading.levels;
            }

            if frame.shadow != undefined && frame.time > self.shadow_multiply_tween.start_time {
                self.shadow_multiply_color = self.shadow_multiply_tween.value;
                self.last_shadow_color = self.shadow_multiply_color;

                self.shadow_multiply_tween = frame.shadow;
            }

            if frame.light != undefined && frame.time > self.light_tween.start_time {
                self.light_strength = self.light_tween.value;
                self.last_light_strength = self.light_strength;

                self.light_tween = frame.light;
            }
        }

        self.should_post_process = !(self.multiply_color[0] == 1
            && self.multiply_color[1] == 1
            && self.multiply_color[2] == 1
            && self.vivid_color[0] == 0
            && self.vivid_color[1] == 0
            && self.vivid_color[2] == 0
            && self.vivid_color[3] == 0
            && self.levels[0] == 0
            && self.levels[1] == 1
            && self.levels[2] == 1);
    }

    function move_tween_frame(tween, time, last_color) {
        var step_pct = inverse_lerp(real(time), real(tween.stop_time), real(tween.start_time));
        step_pct = clamp(step_pct, 0.0, 1.0);

        switch tween.kind {
            case CurveType.Constant:
                return tween.value;
            case CurveType.Linear:
                return blend_rgba32(last_color, tween.value, step_pct);
        }
    }

    function move_levels_tween_frame(tween, time, last_color) {
        var step_pct = inverse_lerp(real(time), real(tween.stop_time), real(tween.start_time));
        step_pct = clamp(step_pct, 0.0, 1.0);

        switch (tween.kind) {
            case CurveType.Constant:
                return tween.value;
            case CurveType.Linear:
                //
                return blend_rgb32(last_color, tween.value, step_pct);
        }
    }

    //
    function draw() {
        gpu_disable_blending();

        if self.should_post_process {
            gpu_set_srgb_blending(false);
            gpu_set_extra(UberShaderKind.DayNight);
                //
                shader_set_uniform_f_array("u_VividColor", self.vivid_color);

                //
                shader_set_uniform_f_array("u_Levels", self.levels);

                draw_world_surface(0.0, 0.0, 1.0, 1.0, c_white, 1.0);
            gpu_reset_extra();
            gpu_set_srgb_blending(true);
        } else {
            surface_blit(SurfaceDirection.WorldToScreen, true);
        }

        gpu_enable_blending();
    }
}

function post_process_by_location() {
    //
    if LOCATIONS[CURRENT_LOCATION_ID].outdoor {
        return new PostProcessor(POST_PROCESS_DATABASE.world);
    } else if is_dungeon_room(room()) {
        if in_dark_mines() {
            return new PostProcessor(POST_PROCESS_DATABASE.dark_mines);
        } else {
            return new PostProcessor(POST_PROCESS_DATABASE.mines);
        }
    } else if room() == rm_mines_entry
        || room() == rm_seridias_chamber
        || room() == rm_abandoned_mines
    {
        return new PostProcessor(POST_PROCESS_DATABASE.mines);
    } else if WEATHER.is_inclement() {
        return new PostProcessor(POST_PROCESS_DATABASE.in_room_inclement);
    } else {
        return new PostProcessor(POST_PROCESS_DATABASE.in_room);
    }
}

enum CurveType {
    Constant,
    Linear,
}

function __CurveFactory() constructor {
    static Constant = function(_value) {
        return {
            value: _value,
            type: CurveType.Constant,
        }
    }

    static Linear = function(_lhs, _rhs) {
        return {
            lhs: _lhs,
            rhs: _rhs,
            type: CurveType.Linear,
        }
    }
}

global.__curve_factory = new __CurveFactory();
#macro Curve global.__curve_factory
