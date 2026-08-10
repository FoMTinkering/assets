object_create(
    "obj_wishing_well_head",
    undefined,
    {
        sprite_index: spr_easternroad_dragon_head_spring_off,
        create: function() {
            //
            event_inherit(ObjectEvent.Create);

            //
            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            self.mask_index = self.sprite_index;
            self.image_speed = 0;

            depth = get_instance_depth(y);
        },
        animation_end: function() {
            self.sprite_index = spr_easternroad_dragon_head_spring_off;
            self.image_speed = 0;
            //
            if obj_wishing_well.prize != undefined {
                drop_item_stack(obj_wishing_well.x, obj_wishing_well.y, obj_wishing_well.prize);
                obj_wishing_well.prize = undefined;
            };
        },
    }
);
