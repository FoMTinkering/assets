object_create(
    "obj_bird",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            //

            z = 0;
            bird_kind = irandom_range(0, Bird.LEN - 1);
            config = BIRD_CATALOGUE[self.bird_kind];
            shadow_caster = SHADOW_GRID.caster_create(x, y);
            image_speed_backup = undefined;
            dir = 0;
            shadow_sprite_backup = undefined;
            shadow_sprite_index_backup = undefined;

            shadow_offset = 55;

            self.bird_actions = new SlowVotes();
            for (var i = 0; i < BirdAction.LEN; i++) {
                self.bird_actions
                    .add_candidate(i, config.votes[i]);
            }

            //
            assert_neq(self.target, undefined, "birds must start with a target!");
            next_x = target.x;
            next_y = target.y;
            next_distance = point_distance(self.next_x, self.next_y, self.x, self.x);
            old_shadow_offset = self.shadow_offset;

            function set_sprite(new_sprite) {
                self.sprite_config = new_sprite;

                var cardinal = angle_to_cardinal(self.dir);
                self.sprite_index = new_sprite[cardinal];
                self.image_index = 0;
                shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index), 0);
            }

            function move_to_point(spd_multiplier=1) {
                var point_dir = point_direction(x, y, self.next_x, self.next_y);
                if point_dir >= 90 && point_dir < 270 {
                    image_xscale = -1;
                } else {
                    image_xscale = 1
                }

                self.dir = point_dir;

                x += lengthdir_x(self.config.fly_speed * spd_multiplier, point_dir);
                y += lengthdir_y(self.config.fly_speed * spd_multiplier, point_dir);
            }

            function process_next_action() {
                var action = self.bird_actions.get_candidate();
                if action == BirdAction.Fly {
                    self.start_flight();
                } else {
                    self.fsm.blackboard.insert("bird_action", action);
                    self.fsm.change_state(BirdState.Animate);
                }
            }

            function start_flight() {
                if chance_percent(self.config.go_to_heaven) {
                    //
                    self.next_x = choose(-1000, CAMERA.room_view_bound_width + 1000);
                    self.next_y = choose(-1000, CAMERA.room_view_bound_height + 1000);

                    //
                    self.target = undefined;
                } else {
                    var new_entry = find_nearest_bird_landing_position(self.x, self.y, irandom(self.config.ignore_counter));
                    if new_entry == undefined {
                        return;
                    }

                    //
                    if self.target != undefined && instance_exists(self.target) {
                        self.target.occupied = undefined;
                    }

                    //
                    self.target = new_entry;
                    new_entry.occupied = self;
                    new_entry.spook_bird = false;
                    self.next_x = new_entry.x;
                    self.next_y = new_entry.y;
                }

                //
                self.next_distance = point_distance(self.next_x, self.next_y, self.x, self.x);
                self.old_shadow_offset = self.shadow_offset;
                self.fsm.change_state(BirdState.Fly);
            }

            function check_for_spook() {
                if self.target != undefined
                    && (instance_exists(self.target) == false || self.target.spook_bird)
                {
                    if instance_exists(self.target) {
                        self.target.spook_bird = false;
                    }

                    return true;
                }

                //
                if self.shadow_offset < 32 {
                    if instance_exists(obj_ari)
                        && point_distance(self.x, self.y, obj_ari.x, obj_ari.y) < 48
                    {
                        return true;
                    }

                    var nearest_npc = instance_nearest(self.x, self.y, par_NPC);
                    if nearest_npc != undefined && point_distance(self.x, self.y, nearest_npc.x, nearest_npc.y) < 48 {
                        return true;
                    }
                }

                return false;
            }

            fsm = StateMachineBuilder(BirdState.LEN)
                .add_state(
                    StateBuilder(BirdState.Idle)
                        .start(function() {
                            owner.dir = (owner.dir + choose(0, 180)) % 360;
                            owner.set_sprite(owner.config.sprites.idle);

                            timer = irandom_range(owner.config.idle_time.x, owner.config.idle_time.y) * 60;

                            //
                            if owner.target != undefined && instance_exists(owner.target) {
                                owner.x = owner.target.x;
                                owner.y = owner.target.y;
                            }
                        })
                        .step(function() {
                            if fsm.state_frame >= self.timer {
                                owner.process_next_action();
                            }

                            //
                            if owner.check_for_spook() {
                                owner.start_flight();
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(BirdState.Fly)
                        .start(function() {
                            owner.set_sprite(owner.config.sprites.fly);

                            glide = false;
                            flip_glide_flap = irandom_range(90, 180);

                            straight_to_heaven = owner.target == undefined;
                            death_timer = 0;
                        })
                        .step(function() {
                            self.flip_glide_flap -= 1;

                            if self.glide {
                                owner.image_index = 0;

                                //
                                if self.flip_glide_flap <= 0 {
                                    self.glide = false;
                                    self.flip_glide_flap = irandom_range(90, 180);
                                }
                            }

                            owner.move_to_point();

                            if self.straight_to_heaven {
                                //
                                owner.shadow_offset = approach(owner.shadow_offset, 60, 0.2);

                                if !point_in_rectangle(
                                        owner.x,
                                        owner.y,
                                        0,
                                        0,
                                        CAMERA.room_view_bound_width,
                                        CAMERA.room_view_bound_height,
                                    )
                                {
                                    owner.image_alpha -= 0.02;
                                }

                                if owner.image_alpha <= 0
                                    || !point_in_rectangle(
                                        owner.x,
                                        owner.y,
                                        CAMERA.left(),
                                        CAMERA.top(),
                                        CAMERA.right(),
                                        CAMERA.bottom(),
                                    )
                                {
                                    instance_destroy(owner);
                                    return;
                                }
                            } else {
                                //
                                if owner.target == undefined || instance_exists(owner.target) == false {
                                    owner.start_flight();
                                    return;
                                }

                                var dist_to_point = point_distance(owner.x, owner.y, owner.next_x, owner.next_y);
                                owner.shadow_offset = lerp(owner.old_shadow_offset, owner.target.shadow_offset, (owner.next_distance - dist_to_point) / owner.next_distance);

                                if dist_to_point < owner.config.fly_speed {
                                    owner.fsm.change_state(BirdState.Idle);
                                }
                            }
                        })
                        .anim_end(function() {
                            if self.glide == false && self.flip_glide_flap <= 0 {
                                self.glide = true;
                                self.flip_glide_flap = irandom_range(30, 90);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(BirdState.Animate)
                        .start(function() {
                            var bird_action = self.blackboard.take("bird_action");

                            switch bird_action {
                                case BirdAction.Look:
                                    self.action_count = irandom_range(owner.config.look_number.x, owner.config.look_number.y);
                                    owner.set_sprite(owner.config.sprites.look);
                                    break;
                                case BirdAction.Sleep:
                                    self.action_count = irandom_range(owner.config.sleep_number.x, owner.config.sleep_number.y);
                                    owner.set_sprite(owner.config.sprites.sleep);
                                    break;
                                default: impossible("unexpected bird_action `{}`", bird_action);
                            }
                        })
                        .step(function() {
                            //
                            if owner.check_for_spook() {
                                owner.start_flight();
                            }
                        })
                        .anim_end(function() {
                            self.action_count -= 1;
                            if self.action_count <= 0 {
                                owner.process_next_action();
                            }
                        })
                        .spawn()
                )
                .spawn(
                    BirdState.Fly,
                    self,
                    Map(),
                );
        },
        step: function() {
            if game_paused() {
                if self.image_speed_backup == undefined {
                    self.image_speed_backup = self.image_speed;
                }
                self.image_speed = 0;
            } else {
                if self.image_speed_backup != undefined {
                    self.image_speed = self.image_speed_backup;
                    self.image_speed_backup = undefined;
                }

                fsm.step();

                //
                if instance_exists(self) == false {
                    return;
                }

                depth = -room_height();

                //
                var cardinal = angle_to_cardinal(self.dir);
                var new_sprite = self.sprite_config[cardinal];
                if new_sprite != self.sprite_index {
                    self.sprite_index = new_sprite;
                    shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index), self.image_index);
                }

                shadow_caster_set_position(self.shadow_caster, x, y + self.shadow_offset);
                shadow_caster_set_image(self.shadow_caster, self.image_index);
            }
        },
        step_begin: function() {
            if game_paused() {
                return;
            }

            fsm.new_tick();
        },
        step_end: function() {
            if game_paused() {
                return;
            }

            fsm.end_step();
        },
        animation_end: function() {
            fsm.anim_end();
        },
        cleanup: function() {
            SHADOW_GRID.caster_remove(self.shadow_caster);
        },
    }
);
