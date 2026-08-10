//
function BarkEmitter(owner, x_offset=0, y_offset=0) constructor {
    self.owner = owner;
    self.x_offset = x_offset;
    self.y_offset = y_offset;
    self.active_bark = undefined;

    //
    self.bark_type = BarkType.Thought;
    self.bubble_index = 0;
    self.bubble_index_counter = 0;
    self.icon_index = 0;
    self.icon_index_counter = 0;

    self.state = BarkState.In;
    self.bubble_sprite = spr_ui_bark_bubble_think_opening;
    self.timer = 0;

    self.modifier = undefined;

    //
    function emit(bark_id, bark_type=BarkType.Thought, play_sound) {
        if self.modifier != undefined {
            bark_id = self.modifier(bark_id);
        }

        play_sound = play_sound == undefined ? MIST.running && bark_type != BarkType.Thought : play_sound;
        self.state = BarkState.In;
        self.active_bark = BARK_PROTOTYPES[bark_id];
        self.bark_type = bark_type;
        self.bubble_sprite = self.bark_type == BarkType.Thought
            ? spr_ui_bark_bubble_think_opening
            : spr_ui_bark_bubble_speak_opening;

        self.bubble_index = 0;
        self.bubble_index_counter = 0;

        var mist_override = MIST.blackboard.try_take("next_bark_sfx");

        if ((play_sound && self.active_bark.sound != undefined) || mist_override != undefined)
            && MIST.blackboard.get("mute_barks") != true
        {
            var sfx = mist_override ?? self.active_bark.sound;
            TANGO.play(sfx, self.owner.x, self.owner.y);
        }
    }

    //
    function is_barking() {
        return self.active_bark != undefined;
    }

    function on_draw(animate_speed=1) {
        if !self.is_barking() {
            return;
        }

        //
        var bubble_frame_times = BARK_OPENING_INFO[self.bark_type];
        self.bubble_index_counter += animate_speed;
        if self.bubble_index_counter >= bubble_frame_times[self.bubble_index] {
            self.bubble_index += animate_speed;
            self.bubble_index_counter = 0;

            if self.bubble_index >= array_length(bubble_frame_times) {
                self.bubble_index = 0;

                switch self.state {
                    case BarkState.In:
                        self.bubble_sprite = self.bark_type == BarkType.Thought
                            ? spr_ui_bark_bubble_think_open
                            : spr_ui_bark_bubble_speak_open;
                        self.state = BarkState.Sit;
                        self.icon_index = 0;
                        self.icon_index_counter = 0;
                        self.timer = BARK_TIMER;
                        break;
                    case BarkState.Sit:
                        //
                        break;
                    case BarkState.Out:
                        //
                        self.active_bark = undefined;
                        return;
                }
            }
        }

        if self.state == BarkState.Sit {
            self.icon_index_counter += animate_speed;
            if self.icon_index_counter >= self.active_bark.frames[self.icon_index] {
                self.icon_index = min(self.icon_index + 1, array_length(self.active_bark.frames) - 1);
                self.icon_index_counter = 0;
            }

            self.timer -= animate_speed;
            if self.timer <= 0 {
                self.bubble_sprite = self.bark_type == BarkType.Thought
                    ? spr_ui_bark_bubble_think_closing
                    : spr_ui_bark_bubble_speak_closing;
                self.state = BarkState.Out;
            }
        }

        var xx = self.owner.x + self.x_offset;
        var yy = self.owner.y + self.y_offset;
        draw_sprite_ext(self.bubble_sprite, self.bubble_index, xx, yy, abs(self.owner.image_xscale), self.owner.image_yscale, 0, c_white, 1);

        if self.state == BarkState.Sit {
            gpu_set_srgb_blending(false);
            gpu_set_extra(UberShaderKind.NoSrgb);
            draw_sprite_ext(self.active_bark.icon, self.icon_index, xx, yy, abs(self.owner.image_xscale), self.owner.image_yscale, 0, c_white, self.active_bark.opacity);
            gpu_reset_extra();
            gpu_set_srgb_blending(true);
        }
    }
}
