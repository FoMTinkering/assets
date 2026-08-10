object_create(
    "obj_maple_drawing",
    undefined,
    {
        sprite_index: spr_inn_reina_maples_drawing,
        create: function() {
            if !MIST.scene_history.contains("reina_eight_hearts") {
                instance_destroy();
                return;
            }
            self.depth = get_instance_depth(self.y, -10);
        },
    }
);
