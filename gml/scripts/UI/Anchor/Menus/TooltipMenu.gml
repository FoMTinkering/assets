enum TooltipDepth {
    GoldText,
    GoldIcon,
    SeasonIconTwo,
    SeasonIconOne,
    SeasonText,
    GrowthTimeText,
    GrowthTimeIcon,
    TypeIcon,
    NameText,
    DescriptionText,
    Backplate
}

//
//
//
function create_tooltip(item, source_node, left_side=false, use_store_price=false, price_markup=1) {
    if !is_struct(item) {
        item = new LiveItem(item);
    }

    var popup = popup_creator("misc_local/placeholder", "misc_local/placeholder")
        .play_sound(false)
        .mute_input(false)
        .use_pilot(false)
        .return_to_previous_pilot(false)
        .include_background(false)

    popup.is_tooltip = true;
    popup.manual_exit_listening = false;

    popup.add_height = method(popup, function(amount) {
        self.backplate.add_height(amount);
        return self;
    });

    popup.stars = undefined;
    popup.title_overflow_applied = 0;
    popup.refresh_title_height = method(popup, function() {
        //
        //
        var overflow = self.stars == undefined ? 0 : self.title_overflow();
        var delta = overflow - self.title_overflow_applied;
        if delta != 0 {
            self.title_overflow_applied = overflow;
            self.header.add_height(delta);
            self.body.add_y(delta);
            self.backplate.add_height(delta);
        }
        return self;
    });

    //
    popup.backplate
        .set_sprite(spr_ui_tooltip_box)
        .set_size(183, 0)
        .set_think_callback(function(node, popup) {
            if node != undefined && node.freed {
                popup.close();
            }
        }, [source_node, popup])
    popup.header
        .set_xy(0, 0)
        .set_sprite(spr_ui_tooltip_header_box)
        .set_size(popup.backplate.get_width(), 35)

    popup.gold_icon = undefined;
    popup.gold_text = undefined;
    if item.prototype.soulbind == undefined || use_store_price {
        popup.gold_icon = ANCHOR.sprite(popup.header)
            .set_sprite(spr_ui_hud_info_currency_icon)
            .set_align(Align.RightIn, Align.BottomIn)
            .set_xy(-5, -3)
            .set_lut(spr_ui_hud_font_currency_lut, 2)
        popup.gold_text = ANCHOR.text(popup.gold_icon)
            .set_sprite_font("currency")
            .set_align(Align.LeftOut, Align.Middle)
            .set_x(-2)
            .set_text(round((use_store_price ? item.store_value() : item.bin_value()) * price_markup))
            .set_lut(spr_ui_hud_font_currency_lut, 2)
    }

    popup.title
        .set_lut(COMMON_LUT, CommonLutIndex.Header)
        .set_xy(25, 6)
        .set_align(Align.LeftIn, Align.TopIn)
        .set_ghost_key(item.prototype.name_key)
        .set_text_align(TextAlign.Left)
        .set_max_height(font_line_height(popup.title.get_font()) * 2);

    popup.title.set_max_width(popup.backplate.get_width() - popup.title.get_x() - 3);
    popup.title.set_text(item.get_display_name())

    popup.icon = item_node(popup.title, item)
        .set_align(Align.LeftOut, Align.Middle)
        .set_x(-2)

    popup.body
        .set_width(popup.backplate.get_width())
        .set_y(popup.header.get_height())
        .set_align(Align.LeftIn, Align.TopIn)
        .set_sprite(spr_nothing_nineslice)

    popup.body_text
        .set_lut(COMMON_LUT)
        .set_xy(7, -3)
        .set_align(Align.LeftIn, Align.Middle)
        .set_ghost_key(item.prototype.description_key)
        .set_text(item.get_display_description())

    popup.body.set_height(popup.body_text.measure().y + 12);
    popup.backplate.set_height(popup.body.get_height() + popup.header.get_height());

    var stat_detail = undefined;
    var regrow_days = undefined;

    //
    if item.prototype.tags.contains("sword") {
        stat_detail = TooltipStatDetail.Damage;

    //
    } else if item.prototype.tags.contains("armor") {
        stat_detail = TooltipStatDetail.Defense;

    //
    } else if item.prototype.use == ItemUse.PlantSeed && item.item_id != ItemId.SeedMysteryBag {
        var node_obj_id = item.prototype.crop_object;
        var node_prototype = NODE_PROTOTYPES[node_obj_id];
        stat_detail = TooltipStatDetail.GrowTime;
        regrow_days = node_prototype.post_harvest_day_to_stage != undefined
            ? node_prototype.post_harvest_day_to_stage.count() - 1
            : undefined;

    //
    } else if item.prototype.use == ItemUse.PlantSapling {
        var node_obj_id = item.prototype.sapling;
        var node_prototype = NODE_PROTOTYPES[node_obj_id];
        stat_detail = TooltipStatDetail.GrowTime;
        if node_prototype.fruit_data != undefined {
            regrow_days = node_prototype.fruit_data.regrow_days;
        }

    //
    } else if item.item_id == ItemId.CraftingScroll {
        stat_detail = TooltipStatDetail.Furniture;

    //
    } else if item.item_id == ItemId.RecipeScroll || item.prototype.use == ItemUse.Consume {
        stat_detail = TooltipStatDetail.Recovery;

    //
    } else if item.prototype.tags.contains("essence_stone") {
        stat_detail = TooltipStatDetail.EssenceGem;
    }

    if MUSEUM_DATA.museum_items[item.item_id] {
        //
        if popup.gold_text != undefined {
            var museum_node = ANCHOR.sprite(popup.gold_text)
                .set_x(-3)
                .set_align(Align.LeftOut, Align.Middle)

        } else {
            var museum_node = ANCHOR.sprite(popup.header)
                .set_align(Align.RightIn, Align.BottomIn)
                .set_xy(-5, -4)
        }

        museum_node
            .set_sprite(
                MUSEUM_PROGRESS[item.item_id]
                    ? spr_ui_generic_icon_museum_on
                    : spr_ui_generic_icon_museum_off
            );
    }

    popup.stat_root = undefined;
    if stat_detail != undefined {
        popup.backplate.add_height(14);
        popup.stat_root = ANCHOR.positional(popup.backplate)
            .set_align(Align.LeftIn, Align.BottomIn)
            .set_xy(7, -10)
            .set_size(1, 1)

        switch stat_detail {
            case TooltipStatDetail.Damage:
            case TooltipStatDetail.Defense:
                var icon = stat_detail == TooltipStatDetail.Damage ? spr_ui_tooltip_attack_icon : spr_ui_tooltip_defense_icon;
                var num = stat_detail == TooltipStatDetail.Damage ? item.prototype.damage : item.prototype.defense;
                popup.stat_icon = ANCHOR.sprite(popup.stat_root)
                    .set_sprite(icon)
                    .set_align(Align.LeftIn, Align.Middle)
                popup.stat_number = ANCHOR.text(popup.stat_icon)
                    .set_lut(COMMON_LUT)
                    .set_align(Align.RightOut, Align.Middle)
                    .set_x(2)
                    .set_text(num)
                    .set_sprite_font("player_level")
                break;
            case TooltipStatDetail.EssenceGem:
                popup.stat_icon = ANCHOR.sprite(popup.stat_root)
                    .set_sprite(spr_ui_tooltip_essence_stone_icon)
                    .set_align(Align.LeftIn, Align.Middle)
                popup.stat_number = ANCHOR.text(popup.stat_icon)
                    .set_lut(COMMON_LUT)
                    .set_align(Align.RightOut, Align.Middle)
                    .set_x(2)
                    .set_text(fmt("{}d", string(item.prototype.essence_charge)))
                break;
            case TooltipStatDetail.Recovery:
                var food_proto;
                var next_parent;
                var xx = 0;
                var yy = 0;
                if item.item_id == ItemId.RecipeScroll {
                    food_proto = ITEM_PROTOTYPES[item.inner_item];

                    popup.food_icon = ANCHOR.sprite(popup.stat_root)
                        .set_sprite(food_proto.icon_sprite)
                        .set_align(Align.LeftIn, Align.Middle)
                        .set_y(-2)

                    next_parent = popup.food_icon;
                    xx = 4;
                    yy = 0;
                } else {
                    food_proto = item.prototype;
                    next_parent = popup.stat_root;
                }

                if food_proto.stars != undefined {
                    popup.stars = ANCHOR.sprite(popup.header)
                        .set_sprite(string_to_asset(format(
                            "spr_ui_cooking_quality_star_level_{}",
                            food_proto.stars,
                        )))
                        .set_align(Align.LeftIn, Align.BottomIn)
                        .set_xy(6, -1)
                }

                if food_proto.health_modifier != 0 {
                    popup.health_icon = ANCHOR.sprite(next_parent)
                        .set_sprite(spr_ui_hud_health_health_bar_icon_normal_health)
                        .set_align(Align.RightOut, Align.Middle)
                        .set_xy(xx, yy)
                    popup.health_text = ANCHOR.text(popup.health_icon)
                        .set_lut(COMMON_LUT, CommonLutIndex.Green)
                        .set_align(Align.RightOut, Align.Middle)
                        .set_x(2)
                        .set_text(format("+{}", food_proto.health_modifier))

                    next_parent = popup.health_text;
                    xx = 4;
                }

                if food_proto.stamina_modifier != 0 {
                    popup.stamina_icon = ANCHOR.sprite(next_parent)
                        .set_sprite(spr_ui_hud_health_stamina_bar_icon_good)
                        .set_align(Align.RightOut, Align.Middle)
                        .set_x(xx)
                    popup.stamina_text = ANCHOR.text(popup.stamina_icon)
                        .set_lut(COMMON_LUT, CommonLutIndex.Green)
                        .set_align(Align.RightOut, Align.Middle)
                        .set_x(2)
                        .set_text(format("+{}", food_proto.stamina_modifier))
                    next_parent = popup.stamina_text;
                }

                if item.item_id == ItemId.RecipeScroll {
                    popup.kitchen_level = render_kitchen_tier(popup.backplate, food_proto.kitchen_tier_requirement)
                        .set_align(Align.RightIn, Align.BottomIn)
                        .set_xy(-6, -5)


                    popup.cooking_level = ANCHOR.text(popup.backplate)
                        .set_align(Align.RightIn, Align.BottomIn)
                        .set_xy(-44, -7)
                        .set_sprite_font("player_level")
                        .set_text(food_proto.crafting_level_requirement)
                        .set_lut(
                            COMMON_LUT,
                            ARI.level(Skill.Cooking) >= food_proto.crafting_level_requirement
                                ? CommonLutIndex.Green
                                : CommonLutIndex.Red
                        )

                    popup.cooking_icon = ANCHOR.sprite(popup.cooking_level)
                        .set_align(Align.LeftOut, Align.Middle)
                        .set_xy(-3, -1)
                        .set_sprite(spr_ui_skill_icon_cooking)
                }
                break;
            case TooltipStatDetail.Furniture:
                var matching_items = List();
                var key_to_find = ITEM_PROTOTYPES[item.inner_item].recipe_key;
                for (var i = 0; i < ItemId.LEN; i++) {
                    var proto = ITEM_PROTOTYPES[i];
                    if proto.recipe_key == key_to_find {
                        matching_items.push(proto);
                    }
                }

                var xx = -1;
                for (var i = 0; i < matching_items.count(); i++) {
                    var proto = matching_items.get(i);
                    var furniture_spr = ANCHOR.sprite(popup.stat_root)
                        .set_sprite(proto.icon_sprite)
                        .set_align(Align.LeftIn, Align.Middle)
                        .set_xy(xx, -2)
                    xx += 20;
                    if i == 5 {
                        var remaining = matching_items.count() - (i + 1);
                        if remaining > 0 {
                            ANCHOR.text(furniture_spr)
                                .set_text("+" + string(remaining))
                                .set_sprite_font("currency")
                                .set_align(Align.RightOut, Align.Middle)
                                .set_xy(2, 1)
                                .set_lut(spr_ui_hud_font_currency_lut, 4)
                        }
                        break;
                    }
                }

                var furniture_proto = ITEM_PROTOTYPES[item.inner_item];
                if furniture_proto.crafting_level_requirement != undefined {
                    popup.crafting_level = ANCHOR.text(popup.backplate)
                        .set_align(Align.RightIn, Align.BottomIn)
                        .set_xy(-8, -7)
                        .set_sprite_font("player_level")
                        .set_text(furniture_proto.crafting_level_requirement)
                        .set_lut(
                            COMMON_LUT,
                            ARI.level(Skill.Woodcrafting) >= furniture_proto.crafting_level_requirement
                                ? CommonLutIndex.Green
                                : CommonLutIndex.Red
                        )

                    popup.crafting_icon = ANCHOR.sprite(popup.crafting_level)
                        .set_align(Align.LeftOut, Align.Middle)
                        .set_xy(-3, -1)
                        .set_sprite(spr_ui_skill_icon_woodcrafting)
                }
                break;
            case TooltipStatDetail.GrowTime:
                popup.stat_icon = ANCHOR.sprite(popup.stat_root)
                    .set_sprite(spr_ui_generic_icon_itemgrowthduration)
                    .set_align(Align.LeftIn, Align.Middle)

                popup.stat_number = ANCHOR.text(popup.stat_icon)
                    .set_lut(COMMON_LUT)
                    .set_align(Align.RightOut, Align.Middle)
                    .set_x(2)

                var crop_item = undefined;
                switch node_prototype.category_id {
                    case ObjectCategory.Tree:
                        if node_prototype.fruit_data != undefined {
                            crop_item = new LiveItem(node_prototype.fruit_data.harvest);
                        }
                        break;
                    case ObjectCategory.Crop:
                        crop_item = new LiveItem(node_prototype.harvest);
                        break;
                    default: impossible("unexpected category for harvestable item = {ObjectCategory}", node_prototype.category_id);
                }
                popup.stat_number.set_text(fmt("{}d", string(node_prototype.day_to_stage.count() - 1)));

                if regrow_days != undefined {
                    popup.regrow_icon = ANCHOR.sprite(popup.stat_number)
                        .set_sprite(spr_ui_generic_icon_item_regrowth)
                        .set_align(Align.RightOut, Align.Middle)
                        .set_xy(6, -1)
                    popup.regrow_number = ANCHOR.text(popup.regrow_icon)
                        .set_lut(COMMON_LUT)
                        .set_align(Align.RightOut, Align.Middle)
                        .set_x(2)
                        .set_text(format("{}d", regrow_days))
                }

                var parent = regrow_days != undefined ? popup.regrow_number : popup.stat_number;
                if crop_item != undefined && !crop_item.soulbound() {
                    popup.crop_icon = ANCHOR.sprite(parent)
                        .set_sprite(item.prototype.mini_sprite)
                        .set_align(Align.RightOut, Align.Middle)
                        .set_xy(6, -1)

                    popup.crop_gold_text = ANCHOR.text(popup.crop_icon)
                        .set_sprite_font("currency")
                        .set_align(Align.RightOut, Align.Middle)
                        .set_xy(2, 1)
                        .set_text(crop_item.bin_value())
                        .set_lut(spr_ui_hud_font_currency_lut, 4)

                    popup.crop_gold_icon = ANCHOR.sprite(popup.crop_gold_text)
                        .set_sprite(spr_ui_hud_info_currency_icon)
                        .set_align(Align.RightOut, Align.Middle)
                        .set_x(2)
                        .set_lut(spr_ui_hud_font_currency_lut, 4)
                }
                break;
            default: impossible("Unexpected TooltipStatDetail: {}", stat_detail);
        }

        if item.infusion != undefined {
            ANCHOR.sprite(popup.backplate)
                .set_align(Align.RightIn, Align.BottomIn)
                .set_xy(-5, -4)
                .set_sprite(INFUSIONS.get(item.infusion).tooltip_icon)
        }
    }

    //
    popup.refresh_title_height();

    popup.item = item;

    popup.source_node = source_node;
    if source_node != undefined {
        var node_pos = ANCHOR.get_screen_position(source_node);
        var s = popup.backplate.get_size();
        popup.backplate
            .set_align(Align.LeftIn, Align.TopIn)
            .set_xy(
                left_side ? node_pos.x + source_node.get_width() - 2 : node_pos.x - s.x + 2,
                node_pos.y - s.y + 2,
            );
        while popup.backplate.get_x() < 4 {
            popup.backplate.add_x(1);
        }
        while popup.backplate.get_y() < 4 {
            popup.backplate.add_y(1);
        }
    }

    popup.spawn();
    return popup;
}

enum TooltipStatDetail {
    Damage,
    Defense,
    GrowTime,
    Furniture,
    Recovery,
    EssenceGem,
}

function new_item_popup(item, recipe_display=false) {
    item = is_struct(item) ? item : new LiveItem(item);

    //
    //
    //
    var big_chicken_display = item.item_id == ItemId.BigEgg && recipe_display;
    if big_chicken_display {
        recipe_display = false;
    }

    var ribbon_key = recipe_display ? "misc_local/learned_recipe" : "misc_local/new_exclamation";

    var popup = popup_creator("misc_local/placeholder", "misc_local/placeholder");

    popup.backplate.set_size(202, 112);

    popup.header
        .set_xy(0, 0)
        .set_sprite(spr_ui_tooltip_header_box)
        .set_size(popup.backplate.get_width(), 36)

    popup.title
        .set_align(Align.Center, Align.Middle)
        .set_ghost_key(item.prototype.name_key)
        .set_text(item.get_display_name())

    popup.body
        .set_size(popup.backplate.get_width(), 42)
        .set_align(Align.Center, Align.BottomIn)
        .set_sprite(spr_ui_tooltip_new_item_description_box)

    popup.body_text
        .set_align(Align.Center, Align.TopIn)
        .set_y(7)
        .set_text_align(TextAlign.Center)
        .set_ghost_key(item.prototype.description_key)
        .set_text(item.get_display_description())

    //
    var extra_title_height = popup.title_overflow();
    popup.header.add_height(extra_title_height);
    popup.backplate.add_height(extra_title_height);

    var belong_in_a_museum = MUSEUM_DATA.museum_items[item.item_id];
    if item.prototype.soulbind == undefined || belong_in_a_museum {
        popup.title.set_y(-4);

        var detail_root = ANCHOR.positional(popup.header)
            .set_align(Align.Center, Align.Middle)
            .set_y(9)

        detail_root.add_y(floor(extra_title_height / 2));

        //
        if belong_in_a_museum {
            popup.title.set_y(-4);

            var museum_icon = ANCHOR.sprite(detail_root)
                .set_align(Align.LeftIn, Align.Middle)
                .set_sprite(
                    MUSEUM_PROGRESS[item.item_id]
                        ? spr_ui_generic_icon_museum_on
                        : spr_ui_generic_icon_museum_off
                );

            if item.prototype.soulbind == undefined {
                var value = ANCHOR.text(museum_icon)
                    .set_text(item.bin_value())
                    .set_sprite_font("currency")
                    .set_x(2)
                    .set_lut(spr_ui_hud_font_currency_lut, 2)
                    .set_align(Align.RightOut, Align.Middle)

                var coin = ANCHOR.sprite(value)
                    .set_x(2)
                    .set_sprite(spr_ui_hud_info_currency_icon)
                    .set_align(Align.RightOut, Align.Middle)
                    .set_lut(spr_ui_hud_font_currency_lut, 2)

                detail_root.set_width_for_nodes([museum_icon, value, coin]);
            } else {
                detail_root.set_width_for_nodes([museum_icon]);
            }

        } else if item.prototype.soulbind == undefined {
            var value = ANCHOR.text(detail_root)
                .set_text(item.bin_value())
                .set_sprite_font("currency")
                .set_x(-4)
                .set_lut(spr_ui_hud_font_currency_lut, 2)
                .set_align(Align.Center, Align.Middle)

            ANCHOR.sprite(value)
                .set_x(2)
                .set_sprite(spr_ui_generic_icon_currency)
                .set_align(Align.RightOut, Align.Middle);
        }
    }

    var assets = List();

    //
    if item.prototype.set_unlock != undefined {
        ribbon_key = "misc_local/learned_recipe";
        for (var i = 0; i < ItemId.LEN; i++) {
            var proto = ITEM_PROTOTYPES[i];
            if proto.tags.contains(item.prototype.set_unlock) {
                assets.push({
                    sprite: ITEM_PROTOTYPES[i].icon_sprite,
                });
            }
        }
        popup.body_text.set_key(assets.count() == 1
            ? "misc_local/item_now_craftable"
            : "misc_local/items_now_craftable"
        );

    //
    } else if item.prototype.tags.contains("furniture") {
        if !recipe_display {
            assets.push({
                sprite: item.get_ui_icon(),
            })
        } else {
            for (var i = 0; i < ItemId.LEN; i++) {
                if ITEM_PROTOTYPES[i].recipe_key == item.prototype.recipe_key {
                    assets.push({
                        sprite: ITEM_PROTOTYPES[i].icon_sprite,
                    });
                }
            }
        }

    //
    } else if item.item_id == ItemId.Cosmetic {
        ribbon_key = "misc_local/new_unlock";

        //
        //
        static SERIDIA_ARMOR = fiddle_get("misc/seridia_armor");
        static WEDDING_ASSETS = fiddle_get("misc/wedding_assets");
        var collection = undefined;
        if array_has(WEDDING_ASSETS, item.cosmetic) {
            collection = WEDDING_ASSETS;
        } else if array_has(SERIDIA_ARMOR, item.cosmetic) {
            collection = SERIDIA_ARMOR;
        }
        if collection != undefined {
            popup.title.set_key("misc_local/multi_cosmetics_available_title");
            popup.body_text.set_key("misc_local/new_cosmetics_available");
            for (var i = 1; i < array_length(collection); i++) {
                var asset_data = PLAYER_ANIMATION_DATABASE.player_assets.get(collection[i]);
                assets.push({
                    sprite: asset_data.ui_asset_icon,
                    lower_sprite: asset_data.ui_body_icon,
                    lut_index: 0,
                    lut: asset_data.lut_sprite,
                });
            }
        } else {
            popup.body_text.set_key("misc_local/new_cosmetic_available");
            var asset_data = PLAYER_ANIMATION_DATABASE.player_assets.get(item.cosmetic);
            var color_count = sprite_get_width(asset_data.lut_sprite);
            for (var i = 1; i < color_count; i++) {
                assets.push({
                    sprite: asset_data.ui_asset_icon,
                    lower_sprite: asset_data.ui_body_icon,
                    lut_index: i,
                    lut: asset_data.lut_sprite,
                });
            }
        }
    } else if item.item_id == ItemId.AnimalCosmetic {
        ribbon_key = "misc_local/new_unlock";
        popup.body_text.set_key("misc_local/new_animal_cosmetic_available");
    } else if big_chicken_display {
        ribbon_key = "misc_local/big_chicken_exclamation";
        popup.body_text.set_key("misc_local/big_chicken_unlock_description");
    } else if item.item_id == ItemId.PetCosmetic {
        ribbon_key = "misc_local/new_unlock";
        popup.body_text.set_key("misc_local/new_pet_cosmetic_available");
    } else if item.prototype.pet_skin_unlock != undefined {
        ribbon_key = "misc_local/new_pet_skin";
        popup.body_text.set_key("misc_local/new_pet_skin_available");
        var variant_keys = PET_PROTOTYPE.variants.keys();
        for (var i = 0; i < array_length(variant_keys); i++) {
            var variant = PET_PROTOTYPE.variants.get(variant_keys[i]);
            if variant.unlock_key == item.prototype.pet_skin_unlock {
                assets.push({
                    sprite: variant.ui_icon,
                    lut: variant.lut,
                    lut_index: variant["lut_index"],
                });
            }
        }
    } else if item.prototype.song != undefined {
        ribbon_key = "misc_local/new_song";
        popup.body_text.set_key("misc_local/new_song_description");
    }

    var body_text_height = popup.body_text.measure().y;
    popup.backplate.add_height(body_text_height);
    popup.body.add_height(body_text_height);

    var container = ANCHOR.positional(popup.header)
        .set_align(Align.Center, Align.BottomOut)
        .set_size(24, 24)

    if !assets.is_empty() {
        var columns = min(assets.count(), 8);

        //
        //
        if assets.count() > 49 {
            columns = 11;

        }

        var layout = new GridLayout(assets, undefined, columns);

        var container_size = layout.container_size();
        container.set_size(container_size);
        container.set_y(4);

        if container_size.x > popup.backplate.get_width() {
            popup.backplate.set_width(container_size.x + 16);
            popup.body.set_width(popup.backplate.get_width());
            popup.header.set_width(popup.backplate.get_width());
        }

        //
        popup.backplate.add_height(max(0, container_size.y - 24));

        while layout.has_next() {
            var next = layout.next(container);
            if next.asset != undefined {
                next.icon.set_sprite(next.asset.sprite);

                if next.asset[$ "lut"] != undefined {
                    next.icon.set_lut(next.asset.lut, next.asset.lut_index);
                }

                if next.asset[$ "lower_sprite"] != undefined {
                    ANCHOR.sprite(next.square)
                        .set_align(Align.Center, Align.Middle)
                        .set_z(next.icon.get_z() + 1)
                        .set_sprite(next.asset.lower_sprite)
                        .set_lut(spr_player_base_lut, ARI.presets.get(ARI.preset_index_selected).skin_tone)
                }
            }
        }
     } else if item.item_id == ItemId.AnimalCosmetic {
        var dummy_animal = new NonPlayerAnimal(
            item.animal_cosmetic.animal,
            ANIMAL_PROTOTYPES[item.animal_cosmetic.animal].core.default_icon_variant,
            Sex.Female,
        );
        dummy_animal.days_old = I32_MAX;
        dummy_animal.cosmetic = item.animal_cosmetic.cosmetic;

        var backplate = ANCHOR.nine_slice(popup.backplate)
            .set_align(Align.Center, Align.Middle)
            .set_size(68, 68)
            .set_y(-16)
            .set_sprite(spr_ui_journal_animal_preview_box)

        popup.backplate.add_height(backplate.get_height() - 20);

        render_animal_in_ui(dummy_animal, backplate);
    } else if big_chicken_display {
        var dummy_animal = new NonPlayerAnimal(
            AnimalKind.Horse,
            "giant_chicken_white",
            Sex.Female,
        );
        dummy_animal.days_old = I32_MAX;

        var backplate = ANCHOR.nine_slice(popup.backplate)
            .set_align(Align.Center, Align.Middle)
            .set_size(68, 68)
            .set_y(-8)
            .set_sprite(spr_ui_journal_animal_preview_box)

        popup.backplate.add_height(backplate.get_height() - 20);
        render_animal_in_ui(dummy_animal, backplate);

        var variants = ANIMAL_PROTOTYPES[AnimalKind.Chicken].variants.keys();
        repeat 50 {
            var variant = undefined;
            while true {
                variant = variants[irandom(array_length(variants) - 1)];
                if ANIMAL_PROTOTYPES[AnimalKind.Chicken].variants.get(variant).acquirable {
                    break;
                }
            }
            var dummy_animal = new NonPlayerAnimal(
                AnimalKind.Chicken,
                variant,
                choose(Sex.Female, Sex.Male),
            );
            dummy_animal.days_old = I32_MAX;
            var animal = render_animal_in_ui(dummy_animal, backplate, Cardinal.East, "flap");
            animal.animal_base.set_layer(AnchorLayer.Debug);
            animal.animal_base.add_xy(irandom_range(-250, 250), irandom_range(-250, 250));
            animal.animal_base.set_speed(1);

            var dir = irandom(360);
            animal.animal_base.vx = lengthdir_x(2, dir);
            animal.animal_base.vy = lengthdir_y(2, dir);
            animal.animal_base.set_think_callback(function(chicken) {
                var sp = ANCHOR.get_screen_position(chicken);
                var canvas_size = ANCHOR.get_true_size();

                if sp.x < 0 {
                    chicken.vx = abs(chicken.vx);
                } else if sp.x + chicken.get_width() > canvas_size.x {
                    chicken.vx = -abs(chicken.vx);
                }

                if sp.y < 0 {
                    chicken.vy = abs(chicken.vy);
                } else if sp.y + chicken.get_height() - 8 > canvas_size.y {
                    chicken.vy = -abs(chicken.vy);
                }

                if sign(chicken.vx) == -1 {
                    chicken.scale_x = -1;
                } else {
                    chicken.scale_x = 1;
                }

                chicken.add_xy(chicken.vx, chicken.vy);
            }, [animal.animal_base])
        }
    } else if item.item_id == ItemId.PetCosmetic {
        container.set_y(5);
        var square = common_slice(container)
            .set_align(Align.Center, Align.Middle)
        item_node(square, item);
    } else {
        container.set_y(5);
        var square = common_slice(container)
            .set_align(Align.Center, Align.Middle);

        item_node(square, item);
    }

    if recipe_display {
        popup.backplate.add_height(26);
        container.set_y(6);

        if item.prototype.kitchen_tier_requirement != undefined {
            popup.backplate.add_height(12);
            container.set_y(20);

            render_kitchen_tier(popup.header, item.prototype.kitchen_tier_requirement)
                .set_align(Align.Center, Align.BottomOut)
                .set_y(4)

        }

        var comps = item.prototype.recipe.components
            .clone()
            .filter_map(function(comp) {
                switch comp.type {
                    case RecipeComponentType.Item: return [comp.item_id, comp.count];
                    case RecipeComponentType.Essence: return [ItemId.FakeEssence, comp.count];
                    default: return undefined;
                }
            });

        var positions = centered_positions(comps.count(), 18, 2);
        var width = array_last(positions) + abs(positions[0]);

        var backing = ANCHOR.nine_slice(container)
            .set_sprite(spr_ui_eod_summary_rounded_text_box)
            .set_align(Align.Center, Align.Middle)
            .set_size(width + 22, 21)
            .set_y(26)

        for (var i = 0; i < array_length(positions); i++) {
            var comp = comps.get(i);
            item_node(backing, comp[0], comp[1])
                .set_align(Align.Center, Align.Middle)
                .set_x(positions[i])
                .set_alpha(0.85)
        }
    }

    popup.create_button("misc_local/close");

    var ribbon = ANCHOR.nine_slice(popup.header)
        .set_sprite(spr_ui_tooltip_new_item_ribbon_box)
        .set_size(30, 20)
        .set_y(-14)

    ANCHOR.sprite(ribbon)
        .set_sprite(spr_ui_tooltip_new_item_ribbon_left)
        .set_align(Align.LeftOut, Align.Middle)

    var new_text = wavy_text(ribbon, ribbon_key, COMMON_LUT, CommonLutIndex.BlackOnYellow, 1)
        .set_align(Align.LeftIn, Align.Middle)

    ribbon.set_width(new_text.get_width() + 4)

    TANGO.play("SoundEffects/NPCs/DialogSparkle");

    return popup.spawn();
}
