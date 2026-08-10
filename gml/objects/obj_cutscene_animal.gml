object_create(
    "obj_cutscene_animal",
    object_reserve("par_animal"),
    {
        sprite_index: undefined,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.me.set_cardinality(irandom(Cardinal.LEN - 1));

            self.fsm = StateMachineBuilder(CutsceneAnimalState.LEN)
                .add_state(StateBuilder(CutsceneAnimalState.Idle)
                    .start(function() {
                        self.owner.set_sprites("idle");
                    })
                    .spawn()
                )
                .add_state(StateBuilder(CutsceneAnimalState.Animate)
                    .start(function() {
                        var animation = self.blackboard.take("animation");
                        self.owner.set_sprites(animation);
                        self.animation = self.owner.me.active_animation();
                    })
                    .step(function() {
                        if instance_at_animation_end(self.owner) {
                            self.fsm.change_state(CutsceneAnimalState.Idle);
                        }
                    })
                    .spawn()
                )
                .spawn(CutsceneAnimalState.Idle, self, Map());
        },
    }
);
