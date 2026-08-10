
enum FishSchoolState {
    Idle,
    BobberAttracted,
    Disperse,
    LEN
}

function FishSchoolFsm() {
    self.fish_in_school = undefined;
    image_index = irandom_range(0, sprite_get_number(sprite_index));

    function initialise(fish_loot) {
        self.fish_in_school = fish_loot;
        FISHING.subscribe(self.id);
    }

    //
    //
    //
    var builder = StateMachineBuilder(FishSchoolState.LEN)
        .add_state(StateBuilder(FishSchoolState.Idle)
            .start(function() {
            })
            .step(function() {
                if instance_exists(obj_bobber)
                    && point_distance(self.owner.x, self.owner.y, obj_bobber.x, obj_bobber.y) <= 15
                    && FISHING.interested_fish == undefined && obj_bobber.fsm.current_state_id() == BobberState.InWater
                {
                    FISHING.set_fish(self.owner.fish_in_school.get(0));
                    self.fsm.change_state(FishSchoolState.BobberAttracted);
                }

                var fishing_data = FISHING.get_subscriber(self.owner.id);

                if fishing_data.kind == FishingEvent.Caught && fishing_data.value == self.owner.fish_in_school.get(0) {
                    self.owner.fish_in_school.remove(0);
                    if self.owner.fish_in_school.count() == 0 {
                        self.fsm.change_state_instant(FishSchoolState.Disperse);
                        TANGO.play("SoundEffects/Animals/ManyFishRun", self.owner.x, self.owner.y);
                    } else {
                        self.fsm.change_state(FishSchoolState.Idle);
                    }
                    fishing_data.value = FishingEvent.None;
                }
            })
            .draw(function() {
                with self.owner {
                    draw_self();
                }
            })
            .spawn()
        )
        .add_state(StateBuilder(FishSchoolState.BobberAttracted)
            .create(function() {
                function reset_timer() {
                    self.timer = 0;
                    self.timer_max = random_range(60, 180);
                }
                self.bobber_force = Vec2();
            })
            .start(function() {
                self.reset_timer();
            })
            //
            .step(function() {
                if self.owner.fish_in_school.count() == 0 {
                    self.fsm.change_state(FishSchoolState.Disperse);
                    return;
                }
                var bite_data = FISHING.get_subscriber(self.owner.id);
                if bite_data.kind == FishingEvent.Missed && bite_data.value == self.owner.fish_in_school.get(0) {
                    self.fsm.change_state(FishSchoolState.Disperse);
                    bite_data.kind = FishingEvent.None;
                }

                if !instance_exists(obj_bobber) {
                    if self.owner.fish_in_school.count() == 0 {
                        self.fsm.change_state(FishSchoolState.Disperse);
                    } else {
                        self.fsm.change_state(FishSchoolState.Idle);
                    }
                    return;
                }
                //
                self.bobber_force.set_val(
                    lerp(obj_bobber.x, self.owner.x, 0.05) - obj_bobber.x,
                    lerp(obj_bobber.y, self.owner.y, 0.05) - obj_bobber.y
                );
                obj_bobber.fsm.blackboard.set("force", self.bobber_force);

                //
                self.timer++;
                if(self.timer > self.timer_max) {
                    self.reset_timer();
                    FISHING.try_bite();
                    var bite_status = FISHING.get_subscriber(self.owner.id);
                    switch bite_status.kind {
                        case FishingEvent.Bite:
                            if bite_status.value == self.owner.fish_in_school.get(0) {
                                TANGO.play("SoundEffects/Tools/FishingBiteAlert", obj_bobber.x, obj_bobber.y);
                                FISHING.bite_timer = self.owner.fish_in_school.get(0).get_bite_time(ARI.held_item().prototype.quality);
                            }
                            bite_status.kind = FishingEvent.None;
                            break;
                        case FishingEvent.Nibble:
                            if bite_status.value == self.owner.fish_in_school.get(0) {
                                self.fsm.change_state(FishSchoolState.BobberAttracted);
                                TANGO.play("SoundEffects/Tools/FishingSmallBite", obj_bobber.x, obj_bobber.y);
                            }
                            bite_status.kind = FishingEvent.None;
                            break;
                    }
                }
            })
            .draw(function() {
                with self.owner {
                    draw_self();
                }
            })
            .spawn()
        )
        .add_state(StateBuilder(FishSchoolState.Disperse)
            .start(function() {
                self.countdown = 0;
                self.ripples = self.owner.fish_in_school.count();
                TANGO.play("SoundEffects/Animals/ManyFishRun", obj_ari.x, obj_ari.y);
            })
            .step(function() {
                self.countdown--;
                if(self.countdown < 0 && self.ripples > 0) {
                    self.countdown = 5;
                    self.ripples -= 1;
                    create_animation_effect(
                        irandom_range(self.owner.bbox_left, self.owner.bbox_right),
                        irandom_range(self.owner.bbox_top, self.owner.bbox_bottom),
                        self.owner.depth - 1,
                        spr_fx_lure_nibble_med
                    );
                }

                //
                self.owner.image_alpha -= 0.025;
                if(self.owner.image_alpha <= 0) {
                    instance_destroy(self.owner);
                }
            })
            .draw(function() {
                with self.owner {
                    draw_self();
                }
            })
            .spawn()
        )

    self.fsm = builder.spawn(
        FishSchoolState.Idle,
        self,
        MapWrap({})
    );

    return builder;
}
