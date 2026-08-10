#macro BARK_FADE_SPEED global.__bark_fade_speed
global.__bark_fade_speed = 0.10;

#macro BARK_MIN_ALPHA global.__bark_min_alpha
global.__bark_min_alpha = 0.80

//
//
#macro STANDARD_INTERACTION_DISTANCE global.__standard_interaction_distance
global.__standard_interaction_distance = 32;

//
function interactable_fiddle_update() {
    var f = fiddle_get("interaction");
    STANDARD_INTERACTION_DISTANCE = f.standard_interaction_distance;
    BARK_FADE_SPEED = f.standard_bark_fade_speed;
}

//
//
function distance_to_ari_interactable() {
    if instance_exists(obj_ari) == false {
        return infinity;
    }

    var ari_x = obj_ari.x;
    var ari_y = obj_ari.y;

    //
    switch obj_ari.cardinal {
        case Cardinal.East:
            ari_x += obj_ari.interact_nudge_distance;
            break;
        case Cardinal.West:
            ari_x -= obj_ari.interact_nudge_distance;
            break;
        case Cardinal.South:
            ari_y += obj_ari.interact_nudge_distance;
            break;
        case Cardinal.North:
            ari_y -= obj_ari.interact_nudge_distance;
            break;
        default: impossible("unexpected cardinal {}", obj_ari.cardinal);
    }

    return distance_to_point(ari_x, ari_y);
}

function Highlighter(strength=1.0) constructor {
    request_highlight_mode = false;
    highlight_mode = false;
    highlight_this_frame = false;

    timer = 0;
    interact_strength = strength;
    override_strength = undefined;
    override_strength_decrease = undefined;

    var f = fiddle_get("interaction/highlight");
    color = make_color_rgb(f.default_color[0], f.default_color[1], f.default_color[2]);;
    self.strength = 0.0;
    play_sound_time = f.play_sound_time;
    hold_amplitude = f.hold_amplitude;
    hold_period = f.hold_period;
    hold_transform = f.hold_transform;

    function update() {
        self.highlight_this_frame = false;

        //
        if self.request_highlight_mode {
            self.highlight_mode = true;
        } else if self.highlight_mode == true {
            self.highlight_mode = false;
            self.timer = 0;
        }
        self.request_highlight_mode = false;

        //
        if self.highlight_mode == false {
            if self.override_strength != undefined {
                self.strength = self.override_strength;
                if self.override_strength_decrease != undefined {
                    self.override_strength = approach(self.override_strength, 0, 0.01);
                    if self.override_strength == 0 {
                        self.override_strength = undefined;
                        self.override_strength_decrease = undefined;
                    }
                } else {
                    self.override_strength = undefined;
                }

                return true;
            } else {
                return false;
            }
        }

        self.highlight_this_frame = true;

        if self.highlight_mode {
            self.strength = self.hold_amplitude * self.interact_strength
                * sin(self.timer * pi / self.hold_period)
                + self.hold_transform * self.interact_strength;
            self.timer += !game_paused();
        }

        return true;
    }
}

enum InteractBounceStatus {
    None,
    Distant,
    Main,
}

function InteractBouncer() constructor {
    timer = 0;
    request_bounce = false;
    status = InteractBounceStatus.None;

    offset = 0;
    alpha = 0;
    alpha_refresh_rate = 1;
    override_request_bounce = 0;
    period = fiddle_get("interaction/bounce_period");

    function update() {
        if self.request_bounce || self.override_request_bounce > 0 {
            self.override_request_bounce -= 1;

            //
            self.alpha = approach(self.alpha, 1, self.alpha_refresh_rate);
            self.status = InteractBounceStatus.Main;

            if self.timer < 6 {
                self.offset = 0;
            } else if self.timer >= 6 && self.timer < 12 {
                self.offset = -1;
            } else {
                self.offset = sin((self.timer - 12) * pi / self.period) * 0.5 - 0.5;
            }

            self.timer += game_paused();
            self.request_bounce = false;

            return true;
        } else {
            self.timer = 0;

            if game_paused() {
                return false;
            }

            //
            self.offset = sin(TICK * pi / self.period) * 0.5 - 0.5;

            return false;
        }
    }
}
