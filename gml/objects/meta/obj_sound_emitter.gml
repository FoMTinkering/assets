object_create(
    "obj_sound_emitter",
    undefined,
    {
        sprite_index: spr_depthstairs,
        sound_asset: "",
        visible: false,
        create: function() {
            self.instance = undefined;

            function apply_bbox(left, top, right, bottom) {
                self.x = left;
                self.y = top;
                var scale_mod = sprite_get_width(self.sprite_index);
                self.image_xscale = (right - left) / scale_mod;
                self.image_yscale = (bottom - top) / scale_mod;
            }

            self.instance = new SoundInstanceController(TANGO.play(self.sound_asset, x, y));
            self.instance.update_instance_position(
                -1000,
                -1000,
            );


            //
            if false && TEST_SUITE {
                for (var i = 0; i < array_length(self.instance.ids); i++) {
                    var idx = self.instance.ids[i];

                    //
                    if idx == undefined {
                        continue;
                    }
                    var index = TANGO.find_instance_index(idx);
                    assert_neq(index, undefined, "an instance in `{}` emitter didn't exist!", self.sound_asset);
                    assert_neq(TANGO.instances[index].emitter, undefined, "{} is in an emitter, but emitters need 3d sounds!", self.sound_asset);
                }
            }
        },
        step: function() {
            self.instance.update_instance_position(
                clamp(AUDIO_LISTENER_X, bbox_left, bbox_right),
                clamp(AUDIO_LISTENER_Y, bbox_top, bbox_bottom)
            );
        },
        cleanup: function() {
            if self.instance != undefined {
                self.instance.force_stop();
            }
        },
    }
);
