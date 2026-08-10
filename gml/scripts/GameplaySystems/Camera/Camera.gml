#macro CAMERA global.__camera
global.__camera = undefined;

enum CameraTarget {
    Instance,
    Point,
    Pan,
    LEN
}

#macro DEFAULT_CAMERA_MAX_OFFSET Vec2(0, 20)

function Camera(_view_x, _view_y) constructor {
    var cam_info = fiddle_get("camera");
    asymptotic_strength = cam_info.asymptotic_strength;
    x_buffer = cam_info.x_buffer;
    y_buffer = cam_info.y_buffer;
    clamping = cam_info.clamping;

    my_x_ease = undefined;
    my_y_ease = undefined;

    cam_pos = Vec2();
    internal_cam_pos = Vec2();

    //
    trauma = Vec2Zero();
    max_offset = DEFAULT_CAMERA_MAX_OFFSET;
    trauma_loss_gate = false;

    //
    camera_stop = 0;

    view_width = _view_x;
    view_height = _view_y;

    cull_offset_x = 0;
    cull_offset_y = 0;
    cull_width = _view_x;
    cull_height = _view_y;

    room_view_bound_width = room_width();
    room_view_bound_height = room_height();
    process_culls_this_room = true;

    asymptote = SETTINGS.get("asymptote");

    target = Vec2Zero();
    fsm = create_camera_fsm(self.target);

    //
    //
    //
    //
    //
    function add_trauma(_trauma, _maximum) {
        var mx = _maximum == undefined ? _trauma : _maximum;
        self.trauma.x = min(self.trauma.x + _trauma, mx);
        self.trauma.y = min(self.trauma.y + _trauma, mx);
    }

    //
    //
    //
    function add_trauma_sep(_x_trauma, _y_trauma, _x_max, _y_max) {
        var mx = _x_max == undefined ? _x_trauma : _x_max;
        self.trauma.x = min(self.trauma.x + _x_trauma, mx);

        var my = _y_max == undefined ? _y_trauma : _y_max;
        self.trauma.y = min(self.trauma.y + _y_trauma, my);
    }

    function get_state() {
        return self.fsm.current_state_id();
    }

    function update() {
        self.fsm.new_tick();
        self.fsm.step();

        var ratio = DISPLAY.asset_resize();

        var _new_x;
        var _new_y;

        if self.asymptote == false {
            switch self.fsm.current_state_id() {
                case CameraTarget.Instance:
                    //
                    //
                    var x_dist = cam_pos.x - (self.target.x - view_width * 0.5);
                    var y_dist = cam_pos.y - (self.target.y - view_height * 0.5);

                    if (x_dist * x_dist + y_dist * y_dist) > 6.0 {
                        _new_x = approach(cam_pos.x, self.target.x - view_width * 0.5, 6.0);
                        _new_y = approach(cam_pos.y, self.target.y - view_height * 0.5, 6.0);
                    } else {
                        _new_x = self.target.x - view_width * 0.5;
                        _new_y = self.target.y - view_height * 0.5;
                    }
                    break;
                case CameraTarget.Point:
                case CameraTarget.Pan:
                    _new_x = approach(cam_pos.x, self.target.x - view_width * 0.5, 1.0);
                    _new_y = approach(cam_pos.y, self.target.y - view_height * 0.5, 1.0);
                    break;
            }
        } else {
            _new_x = asymptotic_motion(cam_pos.x, self.target.x - view_width * 0.5, self.asymptotic_strength);
            _new_y = asymptotic_motion(cam_pos.y, self.target.y - view_height * 0.5, self.asymptotic_strength);
        }

        if camera_stop > 0 {
            _new_x = cam_pos.x;
            _new_y = cam_pos.y;

            camera_stop -= 1;
        }

        if has_flag(PAUSE_STATUS, PauseStatus.WINDOW) {
            _new_x = cam_pos.x;
            _new_y = cam_pos.y;
        }

        //
        //
        if clamping {
            //
            if view_width > room_view_bound_width {
                _new_x = x_buffer;
            } else {
                _new_x = clamp(_new_x, x_buffer, room_view_bound_width - view_width - x_buffer);
            }

            //
            if view_height > room_view_bound_height {
                _new_y = y_buffer;
            } else {
                _new_y = clamp(_new_y, y_buffer, room_view_bound_height - view_height - y_buffer);
            }
        }

        self.cam_pos.x = _new_x;
        self.cam_pos.y = _new_y;

        //
        if SETTINGS.get("screenshake") {
            _new_x += self.max_offset.x * self.trauma.x * self.trauma.x * perlin_noise_get(0) * sign(perlin_noise_get(50) * 2.0 - 1.0);
            _new_y += self.max_offset.y * self.trauma.y * self.trauma.y * perlin_noise_get(1) * sign(perlin_noise_get(100) * 2.0 - 1.0);
        }

        //
        self.trauma.x = max(0.0, self.trauma.x - (!trauma_loss_gate) * FRAME_TIME);
        self.trauma.y = max(0.0, self.trauma.y - (!trauma_loss_gate) * FRAME_TIME);

        self.internal_cam_pos.x = floor(_new_x * ratio) / ratio;
        self.internal_cam_pos.y = floor(_new_y * ratio) / ratio;

        camera_set_view_pos(self.internal_cam_pos.x, self.internal_cam_pos.y);

        process_culls();
    }

    function follow_point(_x, _y) {
        self.fsm.change_state(CameraTarget.Point);
        self.fsm.blackboard.set("tracking_point_x", _x);
        self.fsm.blackboard.set("tracking_point_y", _y);
    }

    //
    function follow_point_instant(_x, _y) {
        self.fsm.blackboard.set("update_tracking_point_inst", true);
        self.fsm.blackboard.set("tracking_point_x", _x);
        self.fsm.blackboard.set("tracking_point_y", _y);
        self.cam_pos.x = _x - self.view_width / 2;
        self.cam_pos.y = _y - self.view_height / 2;
        CAMERA.process_culls();
        self.fsm.change_state_instant(CameraTarget.Point);
    }

    function follow_instance(_inst, _offset_x, _offset_y) {
        self.fsm.blackboard.set("tracking_instance", _inst);
        self.fsm.blackboard.set("offset_x", _offset_x);
        self.fsm.blackboard.set("offset_y", _offset_y);
        self.fsm.change_state(CameraTarget.Instance);
    }

    function follow_instance_instant(_inst, _offset_x, _offset_y) {
        self.follow_instance(_inst, _offset_x, _offset_y);

        self.target.x = _inst.x;
        self.target.y = _inst.y;
        self.cam_pos.x = _inst.x - self.view_width / 2;
        self.cam_pos.y = _inst.y - self.view_height / 2;

        CAMERA.process_culls();
    }

    function pan(_x_target, _y_target, _duration, _formula) {
        if _formula == undefined {
            _formula = EaseId.QuadOut;
        }
        self.fsm.blackboard.set("tracking_point_x", _x_target);
        self.fsm.blackboard.set("tracking_point_y", _y_target);
        self.fsm.blackboard.set("pan_duration", _duration);
        self.fsm.blackboard.set("formula", _formula);
        self.fsm.change_state_instant(CameraTarget.Pan);
    }

    function adjust_offset(_offset_x, _offset_y) {
        assert_eq(self.fsm.current_state_id(), CameraTarget.Instance);
        self.fsm.state.offset.x = _offset_x;
        self.fsm.state.offset.y = _offset_y;
    }

    function on_room_start() {
        self.process_culls_this_room = true;

        if is_world_room(room()) && instance_exists(obj_ari) {
            self.follow_instance(obj_ari);
            //
            self.cam_pos.x = obj_ari.x - self.view_width / 2;
            self.cam_pos.y = obj_ari.y - self.view_height / 2;

            self.target.x = self.cam_pos.x;
            self.target.y = self.cam_pos.y;

            //
            clamping = LOCATIONS[CURRENT_LOCATION_ID].outdoor;
            self.process_culls_this_room = clamping;
        } else {
            self.follow_point_instant(self.view_width / 2, self.view_height / 2);
            //
            //
            clamping = false;
            self.process_culls_this_room = false;
        }

        self.internal_cam_pos.set(self.cam_pos);

        //
        room_view_bound_width = room_width();
        room_view_bound_height = room_height();

        if room() == rm_farm {
            room_view_bound_width = FARM_EXPANDED ? room_width() : 1504;
            room_view_bound_height = 1136;
        }
    }

    //
    function left() {
        return self.cam_pos.x;
    }

    //
    function top() {
        return self.cam_pos.y;
    }

    //
    //
    function right() {
        return self.cam_pos.x + self.view_width;
    }

    //
    function bottom() {
        return self.cam_pos.y + self.view_height;
    }

    //
    function set_view_size(_width, _height) {
        var old_view_width = self.view_width;
        var old_view_height = self.view_height;

        self.view_width = _width;
        self.view_height = _height;

        self.cull_width = self.view_width;
        self.cull_height = self.view_height;

        self.cam_pos.x += (old_view_width - view_width) / 2;
        self.cam_pos.y += (old_view_height - view_height) / 2;

        camera_set_view_size(_width, _height);
    }

    //
    //
    function get_cull_region() {
        return [
            self.cam_pos.x + self.cull_offset_x - 8,
            self.cam_pos.y + self.cull_offset_y - 8,
            //
            //
            self.cull_width + 16,
            self.cull_height + 16
        ];
    }

    function process_culls() {
        if self.process_culls_this_room == false {
            return;
        }
        instance_deactivate_object(obj_node_renderer);
        instance_deactivate_object(obj_assetobject);
        instance_deactivate_object(obj_grass_backing);

        var region = get_cull_region();

        //
        instance_activate_region(
            region[0],
            region[1],
            region[2],
            region[3],
        );
    }

    self.set_view_size(_view_x, _view_y);
}

function create_camera_fsm(target) {
    return StateMachineBuilder(CameraTarget.LEN)
        .add_state(StateBuilder(CameraTarget.Instance)
            .create(function() {
                tracking_instance = undefined;
                offset = Vec2();
            })
            .start(function() {
                self.tracking_instance = self.blackboard.take("tracking_instance");

                //
                self.offset.x = self.blackboard.try_take("offset_x", 0);
                self.offset.y = self.blackboard.try_take("offset_y", 0);
            })
            .step(function () {
                if self.tracking_instance == undefined || instance_exists(self.tracking_instance) == false {
                    self.fsm.change_state(CameraTarget.Point);
                    //
                    self.blackboard.set("tracking_point_x", owner.x);
                    self.blackboard.set("tracking_point_y", owner.y);
                    return;
                }

                owner.x = self.tracking_instance.x + self.offset.x;
                owner.y = self.tracking_instance.y + self.offset.y;
                set_listener_position(owner.x, owner.y, 0);
            })
            .spawn()
        )
        .add_state(StateBuilder(CameraTarget.Point)
            .start(function() {
                owner.x = self.blackboard.get("tracking_point_x");
                owner.y = self.blackboard.get("tracking_point_y");
                set_listener_position(owner.x, owner.y, 0);
            })
            .step(function() {
                if (self.blackboard.get("update_tracking_point_inst")) {
                    owner.x = self.blackboard.get("tracking_point_x");
                    owner.y = self.blackboard.get("tracking_point_y");
                    set_listener_position(owner.x, owner.y, 0);
                    self.blackboard.set("update_tracking_point_inst", false);
                }
            })
            .spawn()
        )
        .add_state(StateBuilder(CameraTarget.Pan)
            .create(function() {
                self.timer = 0;
                self.tracking_point_x = 0;
                self.tracking_point_y = 0;
                self.pan_duration = 0;
                self.formula = 0;
                self.ease_x = undefined;
                self.ease_y = undefined;
            })
            .start(function() {
                self.timer = 0;
                self.tracking_point_x = self.blackboard.take("tracking_point_x");
                self.tracking_point_y = self.blackboard.take("tracking_point_y");
                self.pan_duration = self.blackboard.take("pan_duration");
                self.formula = self.blackboard.take("formula");
                self.ease_x = new Ease(self.formula, self.owner.x, self.tracking_point_x, self.pan_duration);
                self.ease_y = new Ease(self.formula, self.owner.y, self.tracking_point_y, self.pan_duration);

            })
            .step(function() {
                self.timer += 1;
                if self.timer == self.pan_duration {
                    self.blackboard.set("tracking_point_x", self.owner.x);
                    self.blackboard.set("tracking_point_y", self.owner.y);
                    self.fsm.change_state(CameraTarget.Point);
                    return;
                }
                self.owner.x = self.ease_x.calculate_value(self.timer);
                self.owner.y = self.ease_y.calculate_value(self.timer);
                set_listener_position(owner.x, owner.y, 0);
            })
            .spawn()
        )
        .spawn(
            CameraTarget.Point,
            target,
            MapWrap({
                offset_x: undefined,
                offset_y: undefined,
                tracking_instance: undefined,
                tracking_point_x: 0,
                tracking_point_y: 0,
                pan_duration: undefined,
                update_tracking_point_inst: undefined,
                formula: undefined,
            })
        );
}
