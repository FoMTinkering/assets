object_create(
    "obj_tower_ladder_up",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_bell_tower_f1_ladder_main,
        create: function() {
            event_inherit(ObjectEvent.Create);

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });
            
            depth = get_instance_depth(y);

            self.register_interaction(
                InputId.Interact,
                "misc_local/use",
                function() {
                    var point = trellis_point("bell_tower_f2/Bell Tower F1");
                    goto_location_id(LocationId.BellTowerF2)
                        .set_exact_position(point.x, point.y);
                    if instance_exists(obj_ari) {
                        obj_ari.fsm.change_state(PlayerState.Dummy);
                    }
                },
                function() {
                    return TAXI.is_traveling() == false;
                }
            );
        },
    }
);
