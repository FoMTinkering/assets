object_create(
    "obj_light_star_festival_lantern",
    object_reserve("par_light"),
    {
        sprite_index: spr_town_shooting_star_lantern_light_inner,
        festival: "shooting_star",
        inherent_light: "star_festival_lantern",
        visible: false,
    }
);
