object_create(
    "obj_western_ruins_control",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            self.collision_area = Vec4(173, 73, 181, 77);
            var grid = GRIDS[LocationId.WesternRuins];
            var on = world_mod_enabled(WorldMod.WesternRuins);
            for (var i = self.collision_area.x1; i < self.collision_area.x2; i++) {
                for (var j = self.collision_area.y1; j < self.collision_area.y2; j++) {
                    var ni = grid.node_index_for_cell(i, j);
                    var cache = grid.node_is_room_editor_collision[ni];
                    grid.node_is_room_editor_collision[ni] = RoomEditorCollision.None;
                    if on {
                        remove_collision_on_node(grid, i, j);
                    } else {
                        set_collision_on_node(grid, i, j);
                    }
                    grid.node_is_room_editor_collision[ni] = cache;
                }
            }
        },
    }
);
