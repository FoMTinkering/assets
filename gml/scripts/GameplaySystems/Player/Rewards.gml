enum RewardType {
    Item,
    Quest,
    Purse,
    RecipeScroll,
    CraftingScroll,
    Cosmetic,
    AnimalCosmetic,
    PetCosmetic,
    PetSkin,
    LEN,
}

//
function parse_reward(reward) {
    for (var i = 0; i < RewardType.LEN; i++) {
        if reward[$ reward_type_to_string(i)] == undefined {
            continue;
        }

        reward.type = i;

        switch i {
            case RewardType.Item:
                reward.item = string_to_item_id(reward.item);
                if is_nullish(reward[$ "count"]) {
                    reward.count = 1;
                }
                break;
            case RewardType.Purse:
                break;
            case RewardType.Quest:
                assert(QUESTS.contains_key(
                    reward.quest,
                    "Quest '{}' does not exist!",
                    reward.quest,
                ));
                break;
            case RewardType.RecipeScroll:
                reward.item = string_to_item_id(reward.recipe_scroll);
                break;
            case RewardType.CraftingScroll:
                reward.item = string_to_item_id(reward.crafting_scroll);
                break;
            case RewardType.Cosmetic:
                validate_cosmetic(reward.cosmetic);
                break;
            case RewardType.AnimalCosmetic:
                var animal = string_to_animal_kind(reward.animal);
                assert(
                    ANIMAL_PROTOTYPES[animal].cosmetics.contains_key(reward.animal_cosmetic),
                    "Animal cosmetic '{}' does not exist", reward.animal_cosmetic
                );
                reward.animal = animal;
                break;
            case RewardType.PetCosmetic:
                reward.pet_cosmetic = reward.pet_cosmetic;
                assert(
                    PET_PROTOTYPE.cosmetic_sets.contains_key(reward.pet_cosmetic),
                    "Pet cosmetic `{}` does not exist", reward.pet_cosmetic
                )
                break;
            default: impossible("Unexpected RewardType: {}", i);
        }
    }

    return reward;
}

//
function consume_reward(reward) {
    var count = reward.type == RewardType.Item ? reward.count : 1;
    var output = List();

    var item = reward_to_live_item(reward);
    if item != undefined {
        repeat count {
            output.push(item.clone());
        }
    }

    return output;
}

//
function reward_to_icon(reward) {
    switch reward.type {
        case RewardType.Item: return ITEM_PROTOTYPES[reward.item].icon_sprite;
        case RewardType.Purse: return ITEM_PROTOTYPES[ItemId.Purse].icon_sprite;
        case RewardType.RecipeScroll: return ITEM_PROTOTYPES[ItemId.RecipeScroll].icon_sprite;
        case RewardType.CraftingScroll: return ITEM_PROTOTYPES[ItemId.CraftingScroll].icon_sprite;
        case RewardType.Cosmetic:
            return PLAYER_ANIMATION_DATABASE.player_assets.get(reward.cosmetic).ui_asset_icon;
        case RewardType.Quest:
            var quest = QUESTS.get(reward.quest);
            return get_npc_icon(quest.npc_for_icon);
        default: impossible("Unexpected RewardType: {}", reward.type);
    }
}

//
function reward_to_live_item(reward) {
    switch reward.type {
        case RewardType.Item: return new LiveItem(reward.item);
        case RewardType.Purse:
            var item = new LiveItem(ItemId.Purse);
            item.gold_to_gain = reward.purse;
            return item;
        case RewardType.Quest: return undefined;
        case RewardType.RecipeScroll: return new LiveItem(ItemId.RecipeScroll, reward.item);
        case RewardType.CraftingScroll: return  new LiveItem(ItemId.CraftingScroll, reward.item);
        case RewardType.Cosmetic:
            var item = new LiveItem(ItemId.Cosmetic,);
            item.cosmetic = reward.cosmetic;
            return item;
        case RewardType.AnimalCosmetic:
            var item = new LiveItem(ItemId.AnimalCosmetic);
            item.animal_cosmetic = {
                animal: reward.animal,
                cosmetic: reward.animal_cosmetic,
            };
            return item;
        case RewardType.PetCosmetic:
            var item = new LiveItem(ItemId.PetCosmetic);
            item.pet_cosmetic_set_name = reward.pet_cosmetic;
            return item;
        default: impossible("Unexpected RewardType: {}", reward.type);
    }
}

//
//
function reward_popup(title, description, rainbow_label, rewards, background_layer, background_z) {
    var popup = ANCHOR.spawn_menu(Menu.Popup);

    var button = popup.create_button("misc_local/close");
    button
        .set_sprites_from_key("spr_ui_renown_level_up_button")
        .add_y(-6)
    button.text_label.set_lut(spr_ui_renown_level_up_button_font_lut, 2);
    button.text_label.enabled_lut = 3;
    button.text_label.hovered_lut = 3;
    button.text_label.pressed_lut = 4;

    static BACKPLATE_WIDTH = 186;
    static DESCRIPTION_BOX_WIDTH = BACKPLATE_WIDTH - 26;
    static HEADER_HEIGHT = 37;
    static REWARD_ZONE_HEIGHT = 28;
    static BUTTON_HEIGHT_ADDITION = 37;

    static MIN_TEXT_HEIGHT = 36;
    static TEXT_OFFSET = 4;

    popup.backplate
        .set_width(BACKPLATE_WIDTH)
        .set_sprite(spr_ui_renown_level_up_backplate);

    popup.title = ANCHOR.text(popup.backplate)
        .set_align(Align.Center, Align.TopIn)
        .set_y(18)
        .set_key(title)
        .set_lut(spr_ui_renown_level_up_font_lut, 2)

    ANCHOR.sprite(popup.title)
        .set_align(Align.LeftOut, Align.Middle)
        .set_x(-5)
        .set_sprite(spr_ui_renown_level_up_sparkle)
        .set_index(2)
        .set_speed(1)

    ANCHOR.sprite(popup.title)
        .set_align(Align.RightOut, Align.Middle)
        .set_x(5)
        .set_sprite(spr_ui_renown_level_up_sparkle)
        .set_index(4)
        .set_speed(1)

    popup.description_box = ANCHOR.positional(popup.backplate)
        .set_width(DESCRIPTION_BOX_WIDTH)
        .set_align(Align.Center, Align.TopIn)
        .set_y(HEADER_HEIGHT)

    popup.text = ANCHOR.text(popup.description_box)
        .set_align(Align.Center, Align.Middle)
        .set_y(TEXT_OFFSET)
        .set_lut(spr_ui_renown_level_up_font_lut)
        .set_text_align(TextAlign.Center)
        .allow_line_breaks()
        .prevent_spillover()
        .set_key(description)

    var text_height = min(popup.text.get_height(), MIN_TEXT_HEIGHT) + (TEXT_OFFSET * 2);
    var total_height = HEADER_HEIGHT
        + text_height
        + (!rewards.is_empty() ? REWARD_ZONE_HEIGHT : 0)
        + BUTTON_HEIGHT_ADDITION;

    popup.backplate.set_height(total_height);
    popup.description_box.set_height(text_height);

    if !rewards.is_empty() {

        var box_width = sprite_get_width(spr_ui_renown_level_up_reward_backing);
        var layout = centered_positions(rewards.count(), box_width, 2);
        for (var i = 0; i < rewards.count(); i++) {
            var reward = rewards.get(i);
            var xx = layout[i];

            var item_box = ANCHOR.sprite(popup.backplate)
                .set_align(Align.Center, Align.TopIn)
                .set_xy(xx, HEADER_HEIGHT + text_height + 4)
                .set_sprite(spr_ui_renown_level_up_reward_backing)

            ANCHOR.sprite(item_box)
                .set_align(Align.Center, Align.Middle)
                .set_sprite(reward_to_icon(reward))
        }
    }
    popup.background_layer = background_layer;
    popup.background_z = background_z;

    popup.spawn();

    popup.rainbow_root = rainbow_text(popup.backplate, rainbow_label)
        .set_y(-20)
        .set_align(Align.Center, Align.TopOut)

    return popup;
}
