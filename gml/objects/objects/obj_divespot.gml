object_create(
    "obj_divespot",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_fx_water_dive_spot_inactive,
        create: function() {
            depth = get_water_depth();
            fish_id = undefined;
            event_inherit(ObjectEvent.Create);

            self.interactable_mode = InteractableMode.Circle;
            self.circle_size = 1;

            register_interaction(
                InputId.Interact,
                "misc_local/dive",
                function() {
                    obj_ari.dive(self, DiveBehavior.Divespot);
                },
                function() {
                    return obj_ari.fsm.current_state_id() == PlayerState.Swim;
                }
            );
            function initialise(_dive_loot) {
                self.dive_loot = _dive_loot;
            }

            function get_celebration_data() {
                return self.dive_loot.get_celebration_data();
            }

            var other_inst = overlap_instance(x, y, obj_divespot);
            if other_inst != undefined && other_inst != self {
                instance_destroy(self.id);
            }
        },
        draw: function() {
            if sprite_index != undefined && sprite_index != -1 {
                if highlighter.update(x, y) && MIST.running == false {
                    draw_sprite(spr_fx_water_dive_spot_active, image_index, x, y);
                } else {
                    draw_self();
                }
            }

            if DEBUG_TOOLS && FISH_SHOULD_DRAW_NAME {
                draw_set_font(ANCHOR.get_text_font());
                draw_set_halign(HorizontalOffset.Middle);
                draw_text(x, y, self.dive_loot.item.pretty_print());
            }
        },
    }
);
