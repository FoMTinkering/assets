object_create(
    "obj_star_brooch",
    undefined,
    {
        sprite_index: spr_star_brooch,
        npc_name: "",
        z: 0.0,
        create: function() {
            self.depth = get_instance_depth(self.y, self.z);

            if !T2R.read(format("has_been_to_shooting_star_festival_with_{}", self.npc_name)) {
                instance_destroy();
            }
        },
    }
);
