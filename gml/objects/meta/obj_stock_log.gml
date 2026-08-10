object_create(
    "obj_stock_log",
    object_reserve("par_interactable"),
    {
        sprite_index: undefined,
        create: function() {
            event_inherit(ObjectEvent.Create);

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(spr_generic_coop_livestocktable_spring),
            });

            self.register_interaction(
                InputId.Interact,
                "misc_local/input_interact",
                function() {
                    warn("This menu is gone now! Objects will be removed shortly!")
                },
            );
            depth = get_instance_depth(y);
        },
        draw: function() {
            draw_sprite(spr_generic_coop_livestocktable_spring, 0, x, y);

            //
            event_inherit(ObjectEvent.Draw);

        },
    }
);
