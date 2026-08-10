object_create(
    "obj_monster_mite_secondary",
    object_reserve("par_monster"),
    {
        sprite_index: undefined,
        create: function() {
            //
            setup_friction();
            setup_white_vfx();
            setup_push();
            setup_move_and_collide();

            self.allow_shoving = false;
        },
        step_begin: function() {
            //
        },
        step: function() {
            //
        },
        step_end: function() {
            //
        },
        draw: function() {
            //
            //
            draw_self();
        },
        destroy: function() {
            //
        },
        animation_end: function() {
            //
        },
        cleanup: function() {
            //
        }
    }
);
