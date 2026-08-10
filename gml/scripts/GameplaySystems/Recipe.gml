enum RecipeComponentType {
    Item,
    Essence,
    Duration,
    Gold,
    Tag,
    SkillReq,
    LEN,
}

enum RecipeContext {
    Blacksmithing,
    Woodcrafting,
    Cooking,
    Milling,
    Refining,
    LEN
}

//
function Recipe(item_id, potential_infusions, components, is_default) constructor {
    self.item_id = item_id;
    self.potential_infusions = potential_infusions;
    self.components = ListFromArray(components);
    self.is_default = is_default;

    //
    //

    function generate_infusions() {
        var infusions = List();
        if ITEM_PROTOTYPES[self.item_id].default_infusion != undefined {
            return infusions;
        }

        for (var i = 0, c = array_length(self.potential_infusions); i < c; i++) {
            var infusion = self.potential_infusions[i];

            var valid = true;
            var infusion_data = INFUSIONS.get(infusion);

            if infusion == Infusion.Magical || infusion == Infusion.Fairy {
                valid &= ITEM_PROTOTYPES[self.item_id].stars > 3;
            }

            if infusion_data.required_perk != undefined {
                valid &= ARI.perk_active(infusion_data.required_perk);
            }

            valid &= infusion_data.craftable;

            if valid {
                infusions.push({
                    infusion,
                    perk: infusion_data.required_perk,
                });
            }
        }

        return infusions;
    }

    function craft_into(list) {
        var quantity = 1;

        repeat quantity {
            //
            var live_item = new LiveItem(self.item_id);

            //
            var infusions = self.generate_infusions();

            //
            var bonus_infusion_chance = 0;

            if ARI.perk_active(Perk.Empowered) {
                bonus_infusion_chance += 5;
                GAME_STATS.perks[$ perk_to_string(Perk.Empowered)] += 1;
            }

            if ARI.perk_active(Perk.EmpoweredTwo) {
                bonus_infusion_chance += 5;
                GAME_STATS.perks[$ perk_to_string(Perk.EmpoweredTwo)] += 1;
            }

            if !infusions.is_empty() && chance_percent(15 + bonus_infusion_chance) {
                var selection = infusions.choose_random();
                if selection.perk != undefined {
                    GAME_STATS.perks[$ perk_to_string(selection.perk)] += 1;
                }
                live_item.infusion = selection.infusion;
            }

            //
            list.push(live_item);
        }
    }

    //
    function context() {
        var prototype = ITEM_PROTOTYPES[self.item_id];
        if prototype.tags.contains("food") || prototype.tags.contains("drink") {
            return RecipeContext.Cooking;
        } else if prototype.tags.contains("blacksmithing") {
            return RecipeContext.Blacksmithing;
        } else if prototype.tags.contains("furniture") {
            return RecipeContext.Woodcrafting;
        } else if prototype.tags.contains("milling") {
            return RecipeContext.Milling;
        }
        return undefined;
    }
}

//
//
//
function get_modified_component_count(component, context, item_id) {

    switch component.type {
        case RecipeComponentType.Item:
            var count = component.count;
            if ARI.perk_active(Perk.CopperExpert) && item_id == ItemId.CopperIngot {
                GAME_STATS.perks[$ perk_to_string(Perk.CopperExpert)] += 1;
                return max(component.count - 1, 0);
            } else if ARI.perk_active(Perk.IronExpert) && item_id == ItemId.IronIngot {
                GAME_STATS.perks[$ perk_to_string(Perk.IronExpert)] += 1;
                return max(component.count - 1, 0);
            } else if ARI.perk_active(Perk.SilverExpert) && item_id == ItemId.SilverIngot {
                GAME_STATS.perks[$ perk_to_string(Perk.SilverExpert)] += 1;
                return max(component.count - 1, 0);
            } else if ARI.perk_active(Perk.GoldExpert) && item_id == ItemId.GoldIngot {
                GAME_STATS.perks[$ perk_to_string(Perk.GoldExpert)] += 1;
                return max(component.count - 1, 0);
            } else if ARI.perk_active(Perk.MistrilExpert) && item_id == ItemId.MistrilIngot {
                GAME_STATS.perks[$ perk_to_string(Perk.MistrilExpert)] += 1;
                return max(component.count - 1, 0);
            } else {
                return count;
            }
            break;

        case RecipeComponentType.Duration:
            var temp_duration = component.duration;

            switch context {
                case RecipeContext.Cooking:
                    if ARI.perk_active(Perk.TimeToEat) {
                        temp_duration = clamp(temp_duration - minutes(10), 0, I32_MAX);
                        GAME_STATS.perks[$ perk_to_string(Perk.TimeToEat)] += 1;
                    }
                    if ARI.perk_active(Perk.TimeToEatTwo) {
                        temp_duration = clamp(temp_duration - minutes(10), 0, I32_MAX);
                        GAME_STATS.perks[$ perk_to_string(Perk.TimeToEatTwo)] += 1;
                    }
                    if ARI.perk_active(Perk.TimeToEatThree) {
                        temp_duration = clamp(temp_duration - minutes(10), 0, I32_MAX);
                        GAME_STATS.perks[$ perk_to_string(Perk.TimeToEatThree)] += 1;
                    }
                    break;

                case RecipeContext.Woodcrafting:
                    if ARI.perk_active(Perk.HammerTiming) {
                        temp_duration = clamp(temp_duration - minutes(10), 0, I32_MAX);
                        GAME_STATS.perks[$ perk_to_string(Perk.HammerTiming)] += 1;
                    }
                    if ARI.perk_active(Perk.HammerTimingTwo) {
                        temp_duration = clamp(temp_duration - minutes(10), 0, I32_MAX);
                        GAME_STATS.perks[$ perk_to_string(Perk.HammerTimingTwo)] += 1;
                    }
                    if ARI.perk_active(Perk.HammerTimingThree) {
                        temp_duration = clamp(temp_duration - minutes(10), 0, I32_MAX);
                        GAME_STATS.perks[$ perk_to_string(Perk.HammerTimingThree)] += 1;
                    }
                    if ARI.perk_active(Perk.HammerTimingFour) {
                        temp_duration = clamp(temp_duration - minutes(10), 0, I32_MAX);
                        GAME_STATS.perks[$ perk_to_string(Perk.HammerTimingFour)] += 1;
                    }
                    break;

                case RecipeContext.Blacksmithing:
                    if ARI.perk_active(Perk.TimeSensitive) {
                        temp_duration = clamp(temp_duration - minutes(10), 0, I32_MAX);
                        GAME_STATS.perks[$ perk_to_string(Perk.TimeSensitive)] += 1;
                    }
                    if ARI.perk_active(Perk.TimeSensitiveTwo) {
                        temp_duration = clamp(temp_duration - minutes(10), 0, I32_MAX);
                        GAME_STATS.perks[$ perk_to_string(Perk.TimeSensitiveTwo)] += 1;
                    }
                    if ARI.perk_active(Perk.TimeSensitiveThree) {
                        temp_duration = clamp(temp_duration - minutes(10), 0, I32_MAX);
                        GAME_STATS.perks[$ perk_to_string(Perk.TimeSensitiveThree)] += 1;
                    }
                    if ARI.perk_active(Perk.TimeSensitiveFour) {
                        temp_duration = clamp(temp_duration - minutes(10), 0, I32_MAX);
                        GAME_STATS.perks[$ perk_to_string(Perk.TimeSensitiveFour)] += 1;
                    }
                    break;
                case RecipeContext.Milling:
                    if ARI.perk_active(Perk.FeedPrepper) && ITEM_PROTOTYPES[item_id].tags.contains("animal_feed") {
                        temp_duration = clamp(temp_duration - minutes(10), 0, I32_MAX);
                        GAME_STATS.perks[$ perk_to_string(Perk.FeedPrepper)] += 1;
                    }
                    if ARI.perk_active(Perk.WindDown) {
                        temp_duration = clamp(temp_duration - minutes(10), 0, I32_MAX);
                        GAME_STATS.perks[$ perk_to_string(Perk.WindDown)] += 1;
                    }
                    if CURRENT_LOCATION_ID != LocationId.Mill {
                        temp_duration = 0;
                    }
                    break;
                case RecipeContext.Refining:
                    if ARI.perk_active(Perk.RefinedRockery) {
                        temp_duration = clamp(temp_duration - minutes(10), 0, I32_MAX);
                        GAME_STATS.perks[$ perk_to_string(Perk.RefinedRockery)] += 1;
                    }
                    break;
                default: impossible("unexpected context: {}", context);
            }

            return temp_duration;

        case RecipeComponentType.Essence:
        case RecipeComponentType.Gold:
        case RecipeComponentType.Tag:
        case RecipeComponentType.SkillReq:
            return component.count;

        default: impossible("Unexpected RecipeComponentType: {}", component.type);
    }
}

//
//
function maximum_fulfillment_for_component(component, use_chests=true) {
    switch component.type {
        case RecipeComponentType.Item:
            var count = ARI.inventory.item_id_quantity(component.item_id);
            if use_chests {
                var len = STORAGE_NODES.count();
                for (var i = 0; i < len; i++) {
                    var node = STORAGE_NODES.get(i);
                    if node.use_in_crafting {
                        count += node.inventory.item_id_quantity(component.item_id);
                    }
                }
            }
            return count;
        case RecipeComponentType.Essence: return ARI.get_essence();
        case RecipeComponentType.Duration: return max(0, hours(24) - CLOCK.time);
        case RecipeComponentType.Gold: return ARI.get_gold();
        case RecipeComponentType.SkillReq: return ARI.level(component.skill);
        case RecipeComponentType.Tag: return ARI.inventory
            .slots_with_item_tag(component.tag)
            .sum_with(function(x) {
                return x.count();
            });
    }
}

//
function can_fulfill_component(component, item_id, quantity=1, context, use_chests=true) {
    var count = get_modified_component_count(component, context, item_id) * quantity;
    var max_fulfillment = maximum_fulfillment_for_component(component, use_chests);
    return max_fulfillment >= count;
}

//
function pay_component_costs(components, item_id, quantity=1, context) {
    for (var i = 0; i < components.count(); i++) {
        var component = components.get(i);
        var count = get_modified_component_count(component, context, item_id) * quantity;
        switch component.type {
            case RecipeComponentType.Item:
                //
                var amount_to_remove = min(count, ARI.inventory.item_id_quantity(component.item_id));
                ARI.inventory.remove(component.item_id, amount_to_remove);
                count -= amount_to_remove;

                //
                if count != 0 {
                    for (var j = 0; j < STORAGE_NODES.count(); j++) {
                        var node = STORAGE_NODES.get(j);
                        if !node.use_in_crafting {
                            continue;
                        }
                        var inventory = node.inventory;
                        var amount_to_remove = min(count, inventory.item_id_quantity(component.item_id));
                        inventory.remove(component.item_id, amount_to_remove);
                        count -= amount_to_remove;

                        if count == 0 {
                            break;
                        }
                    }
                }

                assert_eq(count, 0, "Failed to fulfill item component costs!");
                break;
            case RecipeComponentType.Essence:
                ARI.modify_essence(-count);
                break;
            case RecipeComponentType.Duration:
                if count > 0 {
                    CLOCK.jump(CLOCK.time + count);
                }
                break
            case RecipeComponentType.Gold:
                ARI.modify_gold(-count);
                break;
            case RecipeComponentType.Tag:
                var slots = ARI.inventory.slots_with_item_tag(component.tag);
                var left_to_remove = component.count;
                for (var j = 0; j < slots.count(); j++) {
                    var slot = slots.get(j);
                    var amount_to_remove = min(slot.count(), left_to_remove);
                    slot.remove(amount_to_remove);
                    left_to_remove -= amount_to_remove;
                    if left_to_remove == 0 {
                        break;
                    }
                }
                break;
            case RecipeComponentType.SkillReq: break;
            default: impossible("Unexpected RecipeComponentType: {}", component.type);
        }
    }
}

//
function can_fulfill_costs(components, item_id, quantity=1, context, use_chests=true) {
    for (var i = 0; i < components.count(); i++) {
        if !can_fulfill_component(components.get(i), item_id, quantity, context, use_chests) {
            return false;
        }
    }
    return true;
}

function RecipeComponentFactory() constructor {
    static Item = function(item_id, count) {
        return {
            type: RecipeComponentType.Item,
            item_id: item_id,
            count: count,
        }
    }
    static Essence = function(count) {
        return {
            type: RecipeComponentType.Essence,
            count: count,
        }
    }
    static Duration = function(duration) {
        return {
            type: RecipeComponentType.Duration,
            duration: duration,
        }
    }
    static Gold = function(count) {
        return {
            type: RecipeComponentType.Gold,
            count: count,
        }
    }
    static Tag = function(tag, count) {
        return {
            type: RecipeComponentType.Tag,
            tag: tag,
            count: count,
        }
    }
    static SkillReq = function(skill, level) {
        return {
            type: RecipeComponentType.SkillReq,
            skill: skill,
            level: level,
        }
    }
}

global.recipe_component_factory = new RecipeComponentFactory();
#macro RecipeComponent global.recipe_component_factory

//
//
function duration_to_alternative_essence_cost(duration) {
    var hours = duration / hours(1);
    return max(round(hours * 1), 1);
}

//
function crafting_test() {
    static CRAFT_QUANTITY = 25;

    for (var i = 0; i < ItemId.LEN; i++) {
        var recipe = ITEM_PROTOTYPES[i].recipe;
        if recipe == undefined {
            continue;
        }

        var components = List();

        //
        for (var j = 0; j < recipe.components.count(); j++) {
            var component = recipe.components.get(j);
            if component.type != RecipeComponentType.Duration {
                components.push(clone_value(component));
            }
        }

        recipe = new Recipe(
            recipe.item_id,
            recipe.potential_infusions,
            components.to_array(),
        );

        //
        for (var j = 0; j < recipe.components.count(); j++) {
            var component = recipe.components.get(j);
            var count = get_modified_component_count(component, recipe.context(), recipe.item_id) * CRAFT_QUANTITY;
            switch component.type {
                case RecipeComponentType.Item:
                    ARI.give_item(component.item_id, count, false, false, false);
                    break;
                case RecipeComponentType.Essence:
                    ARI.modify_essence(count);
                    break;
                case RecipeComponentType.Duration:
                    //
                    component.duration = seconds(1);
                    break
                case RecipeComponentType.Gold:
                    ARI.modify_gold(count);
                    break;
                case RecipeComponentType.Tag:
                    for (var k = 0; k < item_ids.count(); k++) {
                        if ITEM_PROTOTYPES[k].tags.contains(component.tag) {
                            ARI.give_item(k, count, false, false, false);
                            break;
                        }
                    }
                    break;
                case RecipeComponentType.SkillReq: break;
                default: impossible("Unexpected RecipeComponentType: {}", component.type);
            }
        }

        //
        assert(can_fulfill_costs(recipe.components, CRAFT_QUANTITY, 1, recipe.context()));

        //
        pay_component_costs(recipe.components, recipe.item_id, CRAFT_QUANTITY, recipe.context());
        recipe.craft_into(List());
    }
}

//
function test_recipes_are_set_up() {
    //
    var items_in_menu = List();
    var ui_data = [WOODCRAFTING_UI_DATA, COOKING_UI_DATA, BLACKSMITHING_UI_DATA, DRAGON_FORGING_UI_DATA, MILLING_UI_DATA];
    for (var i = 0; i < array_length(ui_data); i++) {
        var data = ui_data[i];
        for (var j = 0; j < data.get("categories").count(); j++) {
            var cat = data.get("categories").get(j);
            for (var k = 0; k < cat.sub_categories.count(); k++) {
                var sub_cat = cat.sub_categories.get(k);
                items_in_menu.copy_from(sub_cat.items.map_to(function(v) {
                    return v.item_id;
                }));
            }
        }
    }

    var hanging_items = List();
    var missing_recipes = List();
    var crafting_tags = List("furniture", "food", "blacksmithing");
    for (var i = 0; i < ItemId.LEN; i++) {
        var proto = ITEM_PROTOTYPES[i];
        var has_recipe = proto.recipe != undefined;
        var is_in_category = proto.tags.contains_any_value_from(crafting_tags);
        var in_menu = items_in_menu.contains(i);

        if is_in_category && has_recipe && !in_menu {
            hanging_items.push(i);
        }

        if is_in_category && in_menu && !has_recipe {
            missing_recipes.push(i);
        }
    }

    var pass = true;
    if !hanging_items.is_empty() {
        pass = false;
        crash(
            "Items intended for crafting do not appear in any menu:\n{}",
            hanging_items
                .map(item_id_to_string)
                .join("\n")
        );
    }

    if !missing_recipes.is_empty() {
        pass = false;
        crash(
            "Items intended for crafting do not have a recipe:\n{}",
            missing_recipes
                .map(item_id_to_string)
                .join("\n")
        );
    }
}
