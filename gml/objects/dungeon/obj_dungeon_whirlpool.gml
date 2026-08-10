object_create(
    "obj_dungeon_whirlpool",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_main_dungeon_prototype_instance_door_whirlpool,
        pool_id: 0,
        pool_sister: 1,
        create: function() {
            event_inherit(ObjectEvent.Create);

            register_interaction(
                InputId.Interact,
                "misc_local/enter_whirlpool",
                function() {
                    obj_ari.dive(self, DiveBehavior.Whirlpool);
                    GS_MINES_FLOOR.whirlpool_uses += 1;
                },
                function() {
                    return obj_ari.fsm.current_state_id() == PlayerState.Swim;
                }
            );

            function dungeon_init() {
                self.x += 8;
                self.y += 8;
                depth = get_instance_depth(y, 16);

                self.sprite_index = spr_fx_water_whirlpool_inactive;

                var found = undefined;
                with obj_dungeon_whirlpool {
                    if self.id == other.id {
                        continue;
                    }
                    if self.pool_id == other.pool_sister {
                        found = self.id;
                        break;
                    }
                }
                assert_neq(found, undefined, "Failed to find an obj_dungeon_whirpool with a pool_id of {}", self.pool_sister);
                self.pool_sister = found;
            }
        },
        draw: function() {
            if sprite_index != undefined && sprite_index != -1 {
                if highlighter.update(x, y) && MIST.running == false {
                    image_alpha = approach(image_alpha, 1.0, 0.1);
                } else {
                    image_alpha = approach(image_alpha, 0.0, 0.1);
                }

                draw_sprite_ext(spr_fx_water_whirlpool_inactive, image_index, x, y, 1, 1, 0, image_blend, 1.0);
                draw_sprite_ext(spr_fx_water_whirlpool_active, image_index, x, y, 1, 1, 0, image_blend, image_alpha);
            }
        },
    }
);
