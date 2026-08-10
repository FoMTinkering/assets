object_create(
    "obj_dungeon_ladder_down",
    object_reserve("par_ladder"),
    {
        sprite_index: spr_main_dungeon_prototype_instance_door_ladder_down,
        state: LadderState.Spawned,
        create: function() {
            event_inherit(ObjectEvent.Create);
            self.xstart = self.x;
            self.ystart = self.y;
        },
        step: function() {
            //
            if self.want_to_spawn_collision {
                var ox = self.xstart div 8;
                var oy = self.ystart div 8;

                if collision_rectangle(ox * 8, oy * 8, ox * 8 + 16, oy * 8 + 16, obj_ari) == undefined {
                    var jumpable = self.object_index != obj_dungeon_ladder_up;
                    set_collision_on_node_region(GRID, ox, oy, ox + 1, oy + 1, jumpable);

                    self.want_to_spawn_collision = false;
                }
            }
        },
        draw_end: function() {
            self.bouncer.status = InteractBounceStatus.None;

            if MIST.running {
                return;
            }

            self.bouncer.status = InteractBounceStatus.Distant;
            self.bouncer.alpha = approach(self.bouncer.alpha, BARK_MIN_ALPHA, BARK_FADE_SPEED);

            var is_being_selected = self.bouncer.update();

            var offset_x = 0;
            var offset_y = -11;

            if is_being_selected {
                draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_ladder, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            } else {
                draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_ladder_small, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            }
        },
    }
);
