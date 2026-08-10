object_create(
    "obj_world_fountain",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_easternroad_fountain_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.timer = 0;
            self.high_flag = false;

            depth = get_instance_depth(y);

            if instance_exists(Game) && CALENDAR.season() == Season.Winter {
                self.deactivated_sprite = spr_easternroad_fountain_winter_on;
                self.activated_sprite = spr_easternroad_fountain_winter_off;
            } else {
                self.deactivated_sprite = spr_easternroad_fountain_spring_on;
                self.activated_sprite = spr_easternroad_fountain_spring_off;
            }

            if WORLD_FOUNTAINS[gm_room_to_location_id(room())] {
                self.sprite_index = self.activated_sprite;
                self.state = InteractState.Activated;
            } else {
                self.sprite_index = self.deactivated_sprite;
                self.state = InteractState.Deactivated;
            }

            self.mask_index = spr_mask_fountain;

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            self.register_interaction(
                InputId.Interact,
                "misc_local/activate",
                function() {
                    callback = function(driver) {
                        if driver.prompt_index_selected == 0 {
                            self.highlighter.interact_strength = 1.5;
                            self.state = InteractState.Transition;
                            self.sprite_index = self.activated_sprite;
                            WORLD_FOUNTAINS[gm_room_to_location_id(room())] = true;
                            use_item_fast(ItemId.WorldFountain);
                        }
                    };

                    args = [];
                    play_conversation_from_path(NpcId.Hemlock, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.EasternRoadFountain], callback, args);
                },
                function() {
                    return state == InteractState.Deactivated;
                },
            );
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
