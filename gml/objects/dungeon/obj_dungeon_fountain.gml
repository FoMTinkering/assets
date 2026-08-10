object_create(
    "obj_dungeon_fountain",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_main_dungeon_prototype_instance_fountain,
        create: function() {
            event_inherit(ObjectEvent.Create);

            function dungeon_init() {
                self.x += 0;
                self.y += 8;

                self.timer = 0;
                self.high_flag = false;

                self.state = InteractState.Deactivated;
                depth = get_instance_depth(y);

                self.deactivated_sprite = spr_dungeon_mines_fountain_spring_on;
                self.activated_sprite = spr_dungeon_mines_fountain_spring_off;
                self.sprite_index = self.deactivated_sprite;
                self.mask_index = spr_mask_fountain;
                var x1 = bbox_left div 8;
                var x2 = bbox_right div 8;
                var y1 = bbox_top div 8;
                var y2 = bbox_bottom div 8;
                set_collision_on_node_region(GRID, x1 + 1, y1, x2 - 1, y2, false);

                self.shadow_caster = SHADOW_GRID.caster_create(x, y);
                shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));

                self.register_interaction(
                    InputId.Interact,
                    "misc_local/activate",
                    function() {
                        self.highlighter.interact_strength = 1.5;
                        self.state = InteractState.Transition;
                        self.sprite_index = self.activated_sprite;

                        use_item_fast(ItemId.DungeonFountainHealth);
                    },
                    function() {
                        return state == InteractState.Deactivated;
                    },
                );
            }
        },
        step: function() {
            if self.state == InteractState.Transition
                && obj_ari.fsm.current_state_id() == PlayerState.Default
                && obj_ari.fsm.next_state == undefined
            {
                self.state = InteractState.Activated;
            }

            if self.state == InteractState.Deactivated {
                self.timer -= 1;

                if self.timer <= 0 {
                    var muller = self.high_flag ? 1.0 : -1.0;

                    create_animation_effect(
                        x + 4 * muller,
                        y - 2,
                        self.depth - 100000,
                        spr_part_sparkle_anglers_eye
                    );

                    self.timer = 90;
                    self.high_flag = !self.high_flag;
                }
            }
        },
        draw: function() {
            switch self.state {
                case InteractState.Deactivated:
                    if self.highlighter.update(x, y) {
                        gpu_set_extra(UberShaderKind.Overlay);
                        draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, 0, self.highlighter.color, self.highlighter.strength);
                        gpu_reset_extra();
                    } else {
                        draw_self();
                    }
                    break;
                case InteractState.Activated:
                    if self.highlighter.strength <= 0.0 {
                        draw_self();
                        return;
                    }

                    self.highlighter.strength = approach(self.highlighter.strength, 0.0, 0.1);
                    gpu_set_extra(UberShaderKind.Overlay);
                    draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, 0, self.highlighter.color, self.highlighter.strength);
                    gpu_reset_extra();
                    break;
                case InteractState.Transition:
                    self.highlighter.strength = approach(self.highlighter.strength, 0.5, 0.1);
                    gpu_set_extra(UberShaderKind.Overlay);
                    draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, 0, self.highlighter.color, self.highlighter.strength);
                    gpu_reset_extra();
                    break;
            }
        },
    }
);
