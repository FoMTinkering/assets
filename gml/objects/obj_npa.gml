object_create(
    "obj_npa",
    object_reserve("par_animal"),
    {
        sprite_index: undefined,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.mask_index = self.me.prototype.core.size == AnimalSize.Large ? spr_large_animal_mask : spr_small_animal_mask;

            function on_pet() {
                if SETTINGS.get("sound_animals") {
                    var sounds = self.me.sounds();
                    TANGO.play(sounds.positive_react, self.x, self.y);
                }
            }

            self.register_interaction(
                InputId.Interact,
                "misc_local/pet",
                self.pet_animal_interaction,
                function() {
                    return ARI.held_animal_id == undefined
                        && SCREEN_FADER.is_in() //
                        && !obj_ari.is_mounted()
                },
            );
            self.me.set_cardinality(irandom(Cardinal.LEN - 1));

            self.fsm = StateMachineBuilder(NpaState.LEN)
                .add_state(StateBuilder(NpaState.Idle)
                    .start(function() {
                        animal_idle_start(self);
                    })
                    .step(function() {
                        if self.fsm.state_frame >= self.timer_max {
                            if choose(true, false) {
                                self.fsm.change_state(NpaState.Wander);
                            } else {
                                var animation = select_random_animation_for_animal(owner);
                                if animation != undefined {
                                    self.blackboard.set("animation", animation);
                                    self.fsm.change_state(NpaState.Animate);
                                }
                            }
                        }
                    })
                    .spawn()
                )
                .add_state(StateBuilder(NpaState.Wander)
                    .start(function() {
                        animal_wander_start(self);
                    })
                    .step(function() {
                        if animal_wander_step(self) {
                            if self.owner.ignore_collision {
                                self.fsm.change_state(AnimalState.Wander);
                            } else {
                                self.fsm.change_state(AnimalState.Idle);
                            }
                            self.owner.ignore_collision = false;
                        }
                    })
                    .stop(function() {
                        animal_wander_stop(self);
                    })
                    .spawn()
                )
                .add_state(StateBuilder(NpaState.Animate)
                    .start(function() {
                        animal_animate_start(self);
                    })
                    .step(function() {
                        if animal_animate_step(self) {
                            self.fsm.change_state(NpaState.Idle);
                        }
                    })
                    .stop(function() {
                        animal_animate_stop(self);
                    })
                    .spawn()
                )
                .spawn(NpaState.Idle, self, Map());

            self.image_speed_backup = undefined;
        },
        step: function() {
            if non_cutscene_pause() {
                if self.image_speed_backup == undefined {
                    self.image_speed_backup = self.image_speed;
                }
                self.image_speed = 0;
                return;
            }

            event_inherit(ObjectEvent.Step);

            //
            if self.image_speed_backup != undefined {
                self.image_speed = self.image_speed_backup;
                self.image_speed_backup = undefined;
            }
        },
    }
);
