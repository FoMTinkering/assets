object_create(
    "obj_dungeon_elevator",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_main_dungeon_prototype_instance_door_elevator,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.xstart = self.x;
            self.ystart = self.y;

            function dungeon_init() {
                depth = get_instance_depth(y);
                self.x += 8;
                self.trolley_x = x;
                self.trolley_y = y - 8;

                //
                var x1 = (self.xstart div 8) - 1;
                var y1 = (self.ystart div 8) - 2;
                var x2 = x1 + 3;
                var y2 = y1 + 3;
                set_collision_on_node_region(GRID, x1, y1, x2, y2, true);

                var biome;
                switch room() {
                    case rm_mines_entry:
                        biome = 0;
                        break;
                    default:
                        biome = DUNGEON_BIOME;
                        break;
                }
                var floor_spr = string_to_asset(format("spr_dungeon_mines_elevator_ground_biome_{}_off", biome + 1));

                self.floor_renderer = create_renderer_at_depth(get_floor_depth(), function(spr) {
                    draw_sprite(spr, 0, self.trolley_x, self.trolley_y + 8);
                }, [floor_spr]);

                //
                new_world_chain(self.floor_renderer)
                    .append(LinkId.Timer, 1)
                    .append(LinkId.Function, function() {
                        self.floor_renderer.depth = get_floor_depth() - 1;
                    })
            }

            mask_index = spr_pulleyelevator;
            self.register_interaction(
                InputId.Interact,
                "misc_local/use",
                function() {
                    ANCHOR.spawn_menu(Menu.Elevator);
                },
                function() {
                    //
                    return ARI.held_animal_id == undefined
                        && SCREEN_FADER.is_in();
                }
            );
            depth = get_instance_depth(y);
        },
        draw: function() {
            if highlighter.update(x, y) && MIST.running == false {
                gpu_set_extra(UberShaderKind.Overlay);
                draw_sprite_ext(
                    spr_pulleyelevator_base,
                    image_index,
                    x,
                    y,
                    1,
                    1,
                    0,
                    self.highlighter.color,
                    self.highlighter.strength
                );
                draw_sprite_ext(
                    spr_pulleyelevator,
                    1,
                    trolley_x,
                    trolley_y,
                    1,
                    1,
                    0,
                    self.highlighter.color,
                    self.highlighter.strength
                );
                draw_sprite_ext(
                    spr_pulleyelevator,
                    0,
                    trolley_x,
                    trolley_y,
                    1,
                    1,
                    0,
                    self.highlighter.color,
                    self.highlighter.strength
                );
                gpu_reset_extra();
            } else {
                draw_sprite(spr_pulleyelevator_base, image_index, x, y);
                draw_sprite(spr_pulleyelevator, 1, trolley_x, trolley_y);
                draw_sprite(spr_pulleyelevator, 0, trolley_x, trolley_y);
            }
        },
    }
);
