object_create(
    "obj_void_teleport",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_transition,
        visible: false,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.register_interaction(
                InputId.Interact,
                "misc_local/teleport",
                function() {
                    var point = trellis_point("void_seal/ari_spawn");
                    ari_teleport_to_room(LocationId.VoidSeal, point.x, point.y);
                }
            );

            self.depth = get_instance_depth(self.y);
        },
    }
);
