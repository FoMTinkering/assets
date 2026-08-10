object_create(
    "obj_egg",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            me = undefined;

            function initialize(me) {
                self.me = me;
                switch me.variant {
                    case ChickenVariant.White:
                        sprite_index = spr_ui_item_egg_tier_1_white_small;
                        break;
                    case ChickenVariant.Brown:
                        sprite_index = spr_ui_item_egg_tier_1_brown_small;
                        break;
                    case ChickenVariant.Spotted:
                        sprite_index = spr_ui_item_egg_tier_1_spotted_small;
                        break;
                    case ChickenVariant.Red:
                        sprite_index = spr_ui_item_egg_tier_2_red_small;
                        break;
                    case ChickenVariant.Yellow:
                        sprite_index = spr_ui_item_egg_tier_2_yellow_small;
                        break;
                    case ChickenVariant.Gray:
                        sprite_index = spr_ui_item_egg_tier_2_grey_small;
                        break;
                    case ChickenVariant.Blue:
                        sprite_index = spr_ui_item_egg_tier_3_blue_small;
                        break;
                    case ChickenVariant.Purple:
                        sprite_index = spr_ui_item_egg_tier_3_purple_small;
                        break;
                    case ChickenVariant.Pink:
                        sprite_index = spr_ui_item_egg_tier_3_pink_small;
                        break;
                    case ChickenVariant.Silver:
                        sprite_index = spr_ui_item_egg_tier_4_silver_small;
                        break;
                    case ChickenVariant.Gold:
                        sprite_index = spr_ui_item_egg_tier_5_gold_small;
                        break;
                    case ChickenVariant.Flower:
                        sprite_index = spr_ui_item_egg_seasonal_flower_small;
                        break;
                    case ChickenVariant.Beach:
                        sprite_index = spr_ui_item_egg_seasonal_beach_small;
                        break;
                    case ChickenVariant.Spooky:
                        sprite_index = spr_ui_item_egg_seasonal_spooky_small;
                        break;
                    case ChickenVariant.Gift:
                        sprite_index = spr_ui_item_egg_seasonal_giftgiving_small;
                        break;
                    default: impossible("Unexpected chicken variant: {}", me.variant);
                }
            }

            depth = get_instance_depth(y, -6);
        },
        draw: function() {
            draw_sprite(self.sprite_index, image_index, self.x - 8, self.y - 8);
        },
    }
);
