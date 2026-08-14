#macro ITEM_PROTOTYPES global.__item_data
global.__item_data = undefined;

function create_item_prototypes() {
    static PARSE_ITEM = function(item_id, fiddle_data, collection) {
        var value = fiddle_data[$ "value"] ?? {};
        if is_nullish(value[$ "bin"]) {
            if is_nullish(value[$ "store"]) {
                value.bin = 0;
            } else {
                value.bin = "self.store * 0.5";
            }
        }
        if is_nullish(value[$ "store"]) {
            value.store = "self.bin * 2";
        }
        if is_nullish(value[$ "renown"]) {
            value.renown = undefined;
        }

        var prototype = {
            item_id: item_id,
            value: value,
            use: undefined,
            hold_over_head: true,
            max_stack: 999,
            icon_sprite: opt_and_then(fiddle_data[$ "icon_sprite"], string_to_asset),
            icon_sprite_outline: undefined,
            mini_sprite: opt_and_then(fiddle_data[$ "mini_sprite"], string_to_asset),
            sow_sprite: opt_and_then(fiddle_data[$ "sow_sprite"], string_to_asset),
            crafting_preview_sprite: opt_and_then(fiddle_data[$ "crafting_preview_sprite"], string_to_asset),
            name_key: fiddle_data[$ "name"] ?? "misc_local/missing",
            description_key: fiddle_data[$ "description"] ?? "misc_local/missing",
            tags: ListFromArray(fiddle_data[$ "tags"] ?? []),
            soulbind: undefined,
            recipe: undefined,
            damage: fiddle_data[$ "damage"] ?? 0,
            defense: fiddle_data[$ "defense"] ?? 0,
            stamina_modifier: fiddle_data[$ "stamina_modifier"] ?? fiddle_data[$ "restore"],
            max_stamina_modifier: fiddle_data[$ "max_stamina_modifier"] ?? 0,
            health_modifier: fiddle_data[$ "health_modifier"] ?? fiddle_data[$ "restore"],
            max_health_modifier: fiddle_data[$ "max_health_modifier"] ?? 0,
            mana_modifier: fiddle_data[$ "mana_modifier"],
            crafting_level_requirement: fiddle_data[$ "crafting_level_requirement"],
            kitchen_tier_requirement: fiddle_data[$ "kitchen_tier_requirement"],
            stars: fiddle_data[$ "stars"],
            edible: false,
            giftable: true,
            tool_type: fiddle_data[$ "tool_type"] != undefined ? string_to_tool_type(fiddle_data.tool_type) : undefined,
            quality: fiddle_data[$ "quality"] != undefined ? string_to_quality_id(fiddle_data.quality) : QualityId.Tier1,
            object: fiddle_data[$ "object"] != undefined ? string_to_object_id(fiddle_data.object) : undefined,
            essence_charge: fiddle_data[$ "essence_charge"],
            blueprint: opt_and_then(fiddle_data[$ "blueprint"], function(v) {
                return {
                    blueprint: string_to_blueprint(v.blueprint),
                    preview_sprite: string_to_asset(v.preview_sprite),
                    variant: v.variant,
                }
            }),
            attract: opt_and_then(fiddle_data[$ "attract"], function(v) {
                var o = {
                    bug: v.bug,
                };

                if v.bug {
                    o.sprinkle = string_to_asset(v.sprinkle);

                    o.min_rarity = v.min_rarity;
                    o.max_rarity = v.max_rarity;
                    if is_string(o.min_rarity) {
                        o.min_rarity = fiddle_get(format("bug_rates/{}", o.min_rarity));
                    }
                    if is_string(o.max_rarity) {
                        o.max_rarity = fiddle_get(format("bug_rates/{}", o.max_rarity));
                    }
                } else {
                    o.min_rarity = v.min_rarity;
                    o.max_rarity = v.max_rarity;
                    if is_string(o.min_rarity) {
                        o.min_rarity = fiddle_get(format("fishing/votes/{}", o.min_rarity));
                    }
                    if is_string(o.max_rarity) {
                        o.max_rarity = fiddle_get(format("fishing/votes/{}", o.max_rarity));
                    }
                    o.hold_sprite = string_to_asset(v.hold_sprite);
                    o.spin_sprite = string_to_asset(v.spin_sprite);
                    o.land_sprite = string_to_asset(v.land_sprite);
                }

                return o;
            }),
            crop_object: opt_and_then(fiddle_data[$ "crop_object"], string_to_object_id),
            sapling: opt_and_then(fiddle_data[$ "sapling"], string_to_object_id),
            size: fiddle_data[$ "size"] != undefined ? string_to_fish_size(fiddle_data.size) : undefined,
            range: fiddle_data[$ "range"] ?? 1,
            new_inventory_size: fiddle_data[$ "new_inventory_size"],
            tile_placement: opt_and_then(fiddle_data[$ "tile_placement"], function(value) {
                return {
                    index: string_to_main_exterior_tile_indexes(value.index),
                    ground_kind: string_to_ground_kind(value.ground_kind),
                }
            }),
            wallpaper: fiddle_data[$ "wallpaper"],
            door_mold: try_string_to_asset(fiddle_data[$ "door_mold"]),
            flooring: fiddle_data[$ "flooring"],
            recipe_key: fiddle_data[$ "recipe_key"] ?? item_id_to_string(item_id),
            set_unlock: fiddle_data[$ "set_unlock"],
            cosmetic_to_unlock: fiddle_data[$ "cosmetic_to_unlock"],
            pet_skin_unlock: fiddle_data[$ "pet_skin_unlock"],
            purchased_once_per_year: fiddle_data[$ "purchased_once_per_year"] ?? false,
            default_infusion: opt_and_then(fiddle_data[$ "default_infusion"], string_to_infusion),
            animal_feed: opt_and_then(fiddle_data[$ "animal_feed"], function(v) {
                return {
                    tier: string_to_animal_feed_tier(v.tier),
                    animal_size: string_to_animal_size(v.animal_size),
                    sprite: string_to_asset(v.sprite),
                    pet_can_eat: v.pet_can_eat,
                }
            }),
            pet_treat: opt_and_then(fiddle_data[$ "pet_treat"], function(v) {
                return {
                    tier: string_to_animal_feed_tier(v.tier),
                    pet_kinds: deserialize_array_bool(v.pet_kinds, try_string_to_pet_kind, PetKind.LEN),
                }
            }),
            plant_grass: opt_and_then(fiddle_data[$ "plant_grass"], string_to_object_id),
            bomb: fiddle_data[$ "bomb"],
            stamina_cost: fiddle_data[$ "stamina_cost"] ?? -1,
            catch_size: fiddle_data[$ "catch_size"] ?? 0,
            date_unlock: opt_and_then(fiddle_data[$ "date_unlock"], string_to_date),
            song: fiddle_data[$ "song"],
        };

        //
        prototype.edible = fiddle_data[$ "edible"]
            ?? (prototype.health_modifier != undefined || prototype.stamina_modifier != undefined);

        //
        if fiddle_data[$ "recipe"] != undefined {

            var components = [];
            for (var j = 0; j < array_length(fiddle_data.recipe); j++) {
                var component = fiddle_data.recipe[j];
                if component[$ "item"] != undefined {
                    array_push(components, RecipeComponent.Item(
                        string_to_item_id(component.item),
                        component[$ "count"] ?? 1,
                    ));
                } else if component[$ "tag"] != undefined {
                    array_push(components, RecipeComponent.Tag(
                        component.tag,
                        component[$ "count"] ?? 1,
                    ));
                } else if component[$ "hours"] != undefined {
                    array_push(components, RecipeComponent.Duration(
                        hours(component.hours) + minutes(component.minutes),
                    ));
                } else if component[$ "gold"] != undefined {
                    array_push(components, RecipeComponent.Gold(component.gold));
                } else if component[$ "skill"] != undefined {
                    array_push(components, RecipeComponent.SkillReq(
                        string_to_skill_id(component.skill),
                        component.level,
                    ));
                } else if component[$ "essence"] != undefined {
                    array_push(components, RecipeComponent.Essence(
                        component[$ "essence"]
                    ));
                } else {
                    crash("unexpected recipe component in {ItemId} (recipe component number {})", item_id, j);
                }
            }

            //
            var infusions = [];
            for (var j = 0; j < Infusion.LEN; j++) {
                var tags = ListFromArray(INFUSIONS.get(j).supported_tags);
                if tags.contains_any_value_from(prototype.tags) {
                    array_push(infusions, j);
                }
            }

            //
            prototype.recipe = new Recipe(prototype.item_id, infusions, components, fiddle_data[$ "recipe_is_default"] ?? false);
        }

        //
        if prototype.edible {
            prototype.use = ItemUse.Consume;
        } else if prototype.crop_object != undefined {
            prototype.use = ItemUse.PlantSeed;
            prototype.mini_bag_sprite = string_to_asset(string_replace(fiddle_data.icon_sprite, "_icon", "_mini"));
            prototype.stamina_modifier = -1;

            assert(
                array_length(NODE_PROTOTYPES[prototype.crop_object].sprites) > 1,
                "{ItemId}'s crop_object is {ObjectId}, but that Crop has only one stage, and so can't be grown normally from a seed",
                item_id,
                prototype.crop_object,
            );
        } else if prototype.attract != undefined {
            prototype.use = ItemUse.Bait;
        } else if prototype.blueprint != undefined {
            prototype.use = ItemUse.Blueprint;
        } else if prototype.object != undefined {
            assert_eq(
                object_id_to_object_category(prototype.object),
                ObjectCategory.Furniture,
                "{ObjectId}'s Object is {ObjectCategory}, but only Furniture is allowed",
                prototype.object,
                object_id_to_object_category(prototype.object),
            );
            prototype.use = ItemUse.PlaceObject;
        } else if prototype.tool_type != undefined {
            prototype.use = ItemUse.UseTool;
        } else if prototype.plant_grass != undefined {
            prototype.use = ItemUse.PlantGrass;
        } else if prototype.damage != 0 {
            prototype.use = ItemUse.Attack;
        } else if prototype.tile_placement != undefined {
            prototype.use = ItemUse.PlaceTile;
        } else if prototype.wallpaper != undefined {
            prototype.use = ItemUse.Wallpaper;
        } else if prototype.flooring != undefined {
            prototype.use = ItemUse.Flooring;
        } else if prototype.sapling != undefined {
            prototype.use = ItemUse.PlantSapling;
            prototype.stamina_modifier = -1;
            assert_eq(
                object_id_to_object_category(prototype.sapling),
                ObjectCategory.Tree,
                "{ObjectId}'s Object is {ObjectCategory}, but only Trees can be Saplings",
                prototype.sapling,
                object_id_to_object_category(prototype.sapling),
            );
        } else if prototype.date_unlock != undefined {
            prototype.use = ItemUse.UnlockDate;
        } else if prototype.tags.contains("identify_item") {
            prototype.use = ItemUse.IdentifyItem;
        }  else if prototype.tags.contains("purse") {
            prototype.use = ItemUse.GainGold;
        } else if prototype.tags.contains("mob_coin") {
            prototype.use = ItemUse.GainGoldInstant;
        } else if prototype.tags.contains("scroll") {
            prototype.use = ItemUse.LearnRecipe;
        } else if prototype.song != undefined {
            prototype.use = ItemUse.UnlockSong;
        } else if prototype.item_id == ItemId.BigEgg {
            prototype.use = ItemUse.CrackEgg;
        } else if prototype.item_id == ItemId.AnimalCosmetic {
            prototype.use = ItemUse.UnlockAnimalCosmetic;
        } else if prototype.item_id == ItemId.PetCosmetic {
            prototype.use = ItemUse.UnlockPetCosmetic;
        } else if prototype.item_id == ItemId.Cosmetic {
            prototype.use = ItemUse.UnlockCosmetic;
        } else if prototype.new_inventory_size != undefined {
            prototype.use = ItemUse.ExpandInventory;
        } else if matches(prototype.item_id, ItemId.TreasureBoxWood, ItemId.TreasureBoxCopper, ItemId.TreasureBoxSilver, ItemId.TreasureBoxGold, ItemId.AbyssalChest) {
            prototype.use = ItemUse.OpenChest;
        } else if prototype.pet_skin_unlock != undefined {
            prototype.use = ItemUse.UnlockPetSkin;
        } else if prototype.essence_charge != undefined {
            prototype.use = ItemUse.CrackEssenceStone;

            if DEBUG_ASSERTIONS {
                var found = false;
                for (var i = 0; prototype.recipe.components.count(); i++) {
                    var component = prototype.recipe.components.get(i);
                    if component.type == RecipeComponentType.Essence {
                        found = true;
                        break;
                    }
                }

                assert(found, "{ItemId} has an essence_charge but its recipe doesn't cost essence! it must!", item_id);
            }
        } else if prototype.bomb != undefined {
            prototype.use = ItemUse.Bomb;
        } else if fiddle_data[$ "apply_oil"] {
            prototype.use = ItemUse.ApplyOil;
        } else if fiddle_data[$ "item_bundle"] != undefined {
            prototype.use = ItemUse.UnpackBundle;
            prototype.item_bundle = apply_func(clone_value(fiddle_data.item_bundle), function(v) {
                var key = struct_get_names(v)[0];
                return [string_to_item_id(key), v[$ key]];
            })
        }

        if fiddle_data[$ "soulbind"] != undefined {
            if fiddle_data.soulbind == "forever" {
                prototype.soulbind = { type: Soulbind.Forever };
            } else {
                prototype.soulbind = {
                    type: Soulbind.Requirements,
                    requirements: parse_requirements(fiddle_data.soulbind),
                }
            }
        }

        //
        prototype.giftable = prototype.soulbind == undefined && !matches(prototype.use, ItemUse.PlaceObject, ItemUse.UseTool, ItemUse.Attack, ItemUse.IdentifyItem, ItemUse.OpenChest, ItemUse.PlantSeed, ItemUse.PlantSapling, ItemUse.PlantGrass);
        prototype.hold_over_head = !matches(
            prototype.use,
            ItemUse.UseTool,
            ItemUse.Attack,
            ItemUse.PlantSeed,
            ItemUse.PlantSapling,
            ItemUse.PlantGrass,
            ItemUse.Bait
        );

        if matches(prototype.use, ItemUse.UseTool, ItemUse.Attack, ItemUse.IdentifyItem, ItemUse.OpenChest) || prototype.tags.contains("armor") {
            prototype.max_stack = 1;
        }

        //
        if prototype.tags.contains("fishable") {
            var prefix = fiddle_data.icon_sprite;
            var basic_sprite = try_string_to_asset(prefix + "_basic");
            var special_sprite = try_string_to_asset(prefix + "_special");

            //
            basic_sprite = basic_sprite == undefined ? special_sprite : basic_sprite;

            //
            basic_sprite = basic_sprite == undefined ? try_string_to_asset(prefix + "_legendary") : basic_sprite;

            //
            basic_sprite = basic_sprite == undefined ? prototype.icon_sprite : basic_sprite;

            prototype.icon_sprite = basic_sprite;
        }

        //
        if prototype.crafting_level_requirement == undefined
            && (prototype.tags.contains("blacksmithing") || prototype.tags.contains("furniture"))
        {
            prototype.crafting_level_requirement = 1;
        }

        assert_neq(prototype.icon_sprite, -1, "icon sprite `{}` does not exist", prototype.icon_sprite);

        if prototype.icon_sprite != undefined {
            prototype.icon_sprite_outline = OUTLINE_DICTIONARY[$ prototype.icon_sprite];
            if prototype.icon_sprite_outline == undefined {
                error("No outline for `{GmSprite}` (used in item {ItemId})", prototype.icon_sprite, item_id);
                prototype.icon_sprite_outline = spr_nothing;
            }

        }

        //
        collection[item_id] = prototype;
    }

    static RECURSE = function(struct, collection, recurse, parse_item) {
        var names = struct_get_names(struct);
        for (var i = 0; i < array_length(names); i++) {
            var entry = struct[$ names[i]];

            //
            var item_id = try_string_to_item_id(names[i]) ;
            if item_id == undefined {
                recurse(entry, collection, recurse, parse_item);
            } else {
                parse_item(item_id, entry, collection);
            }
        }
    }

    var collection = array_create(ItemId.LEN, undefined);

    RECURSE(fiddle_get_directory("items"), collection, RECURSE, PARSE_ITEM);

    //
    for (var i = 0; i < ItemId.LEN; i++) {
        var item = collection[i];

        if item.use == ItemUse.Consume {
            if item.recipe != undefined && !item.tags.contains("milling") {
                assert_neq(
                    item.crafting_level_requirement,
                    undefined,
                    "{ItemId} needs a cooking level requirement!",
                    item.item_id,
                );
                assert_neq(
                    item.kitchen_tier_requirement,
                    undefined,
                    "{ItemId} needs a kitchen tier requirement!",
                    item.item_id,
                );
            }
            item.health_modifier = query_item_restore(item, "health_modifier", collection);
            item.stamina_modifier = query_item_restore(item, "stamina_modifier", collection);

            if item.stars != undefined {
                static STARS = fiddle_get("restoration/stars");
                var star = STARS[item.stars - 1];
                item.value.bin = star.value_expr;
            }

            if !is_real(item.value.store) {
                item.value.store = "self.bin * 1.3";
            }
        }

        item.value.bin = query_item_price(item.value.bin, item.item_id, collection);
        item.value.store = query_item_price(item.value.store, item.item_id, collection);

        assert(is_real(item.value.bin), "{ItemId} doesn't have a valid bin value!", item.item_id);
        assert(is_real(item.value.store), "{ItemId} doesn't have a valid store value!", item.item_id);
    }

    return collection;
}

function query_item_price_expr(expr, ident, wip_items) {
    static STACK = HashSet();

    //
    var lhs = expr;
    var rhs = "bin";
    if string_pos(".", expr) != 0 {
        var split = string_split(expr, ".");
        assert_eq(array_length(split), 2, "Unexpected split length on input '{}'", expr);
        lhs = split[0];
        rhs = split[1];
    }

    if lhs == "self" {
        lhs = wip_items[ident];
    } else {
        lhs = wip_items[string_to_item_id(lhs)];
    }

    if STACK.contains(lhs.item_id) {
        crash(
            "Infinite recursion found in prices with '{ItemId}' encountered while querying `{ItemId}`",
            lhs.item_id,
            ident,
        );
    }
    STACK.insert(lhs.item_id);

    //
    var output = undefined;
    switch rhs {
        case "bin":
            output = lhs.value[$ "bin"];
            break;
        case "store":
            output = lhs.value[$ "store"];
            break;
        case "health_modifier":
            output = lhs[$ "health_modifier"];
            break;
        case "stamina_modifier":
            output = lhs[$ "stamina_modifier"];
            break;
        case "recipe":
            assert_neq(
                lhs.recipe,
                undefined,
                "Tried to calculate a value based on {ItemId}'s recipe, but it has none!",
                lhs.item_id,
            );

            //
            output = 0;
            for (var i = 0; i < lhs.recipe.components.count(); i++) {
                var component = lhs.recipe.components.get(i);
                if component.type == RecipeComponentType.Item {

                    //
                    var value = wip_items[component.item_id].value.bin;
                    if is_string(value) {
                        value = query_item_price(value, component.item_id, wip_items);
                    }

                    output += value * component.count;
                }
            }
            break;
    }

    //
    if is_string(output) {
        output = query_item_price(output, ident, wip_items);
    }

    //
    assert_neq(
        output,
        undefined,
        "Expected '{}' on {ItemId} to be a number, but it was `{}`!",
        rhs,
        lhs.item_id,
        output,
    );

    STACK.remove(lhs.item_id);

    return output;
}

function query_item_price(input, item_id, wip_items) {
    //
    if is_real(input) {
        return input;
    }

    var stripped = string_replace_all(input, " ", "");
    var op = undefined;
    if string_pos("*", stripped) != 0 {
        op = "*";
    } else if string_pos("+", stripped) != 0 {
        op = "+";
    } else {
        //
        return query_item_price_expr(stripped, item_id, wip_items);
    }

    var split = string_split(stripped, op);
    assert_eq(array_length(split), 2, "Unexpected split length on input '{}'", input);

    var lhs = query_item_price_expr(split[0], item_id, wip_items);
    var rhs = real(split[1]);

    var output = 0;
    switch op {
        case "*":
            output = round(lhs * rhs);
            break;
        case "+":
            output = lhs + rhs;
            break;
        default: impossible("Unknown op: '{}'", op);
    }

    //
    if output > 200 {
        return output - (output mod 10);
    } else if output > 25 {
        return output - (output mod 5);
    } else {
        return output;
    }
}

function query_item_restore(prototype, key, wip_items) {
    static RESTORATION = fiddle_get("restoration");

    var input = prototype[$ key];

    if input == undefined {
        return 0;
    }

    if is_real(input) {
        return input;
    }

    var var_value = RESTORATION.vars[$ input];
    if var_value != undefined {
        return var_value;
    }

    assert_eq(input, "dish", "Unexpected restoration value: {}", input);

    assert_neq(
        prototype.recipe,
        undefined,
        "Tried to calculate a value based on {ItemId}'s recipe, but it has none!",
        prototype.item_id,
    );

    //
    var output = 0;
    for (var i = 0; i < prototype.recipe.components.count(); i++) {
        var component = prototype.recipe.components.get(i);
        if component.type == RecipeComponentType.Item {
            var value = wip_items[component.item_id][$ key];

            //
            var value = wip_items[component.item_id][$ key];
            if is_string(value) {
                value = query_item_restore(wip_items[component.item_id], key, wip_items);
            }

            if value == undefined {
                crash("{ItemId} is being used as a cooking ingredient but has no restore value!", component.item_id);
            }

            output += value;
        }
    }

    //
    var star = RESTORATION.stars[prototype.stars - 1];
    output = round(output * star.restoration_multiplier);

    //
    if output mod 2 == 1 {
        output += 1;
    }

    return output;
}

enum ItemUse {
    Attack,
    UseTool,
    Blueprint,
    PlantSeed,
    PlantSapling,
    PlantGrass,
    PlaceObject,
    Wallpaper,
    Flooring,
    Consume,
    ApplyOil,
    PlaceTile,
    UnlockCosmetic,
    LearnRecipe,
    IdentifyItem,
    OpenChest,
    GainGold,
    GainGoldInstant,
    ExpandInventory,
    UnlockAnimalCosmetic,
    CrackEgg,
    UnlockPetCosmetic,
    CrackEssenceStone,
    Bomb,
    UnlockDate,
    UnpackBundle,
    UnlockPetSkin,
    Bait,
    UnlockSong,
    LEN,
}

enum QualityId {
    Tier1,
    Tier2,
    Tier3,
    Tier4,
    Tier5,
    Tier6,
    LEN,
}

enum AnimalFeedTier {
    Normal,
    Quality,
    Deluxe,
    Ultimate,
    LEN,
}

enum ToolType {
    Hoe,
    Axe,
    PickAxe,
    FishingRod,
    WateringCan,
    Shovel,
    Net,
    LEN
}

enum Soulbind {
    Forever,
    Requirements,
    LEN,
}

//
function item_string_functions() {
    for (var i = 0; i < ItemId.LEN; i++) {
        var name = item_id_to_string(i);
        assert_eq(i, string_to_item_id(name));
    }
}

function store_loose_items_as_lost() {
    //
    with obj_item {
        GRID.lost_items.push({
            x: self.x,
            y: self.y,
            items: self.items,
        })
    }
}

function restore_lost_items(lost_items) {
    for (var i = 0; i < lost_items.count(); i++) {
        var item_data = lost_items.get(i);
        var inst = instance_create_layer(item_data.x, item_data.y, "Instances", obj_item)
        inst.setup(item_data.items);
        inst.final_x = item_data.x;
        inst.final_y = item_data.y;
        inst.v_counter = 60; //
    }

    lost_items.clear();
}

function serialize_lost_items(input_list) {
    var lost_items = List();

    for (var i = 0; i < input_list.count(); i++) {
        var item_data = input_list.get(i);

        lost_items.push({
            x: item_data.x,
            y: item_data.y,
            items: item_data.items
                .map_to(function(item) {
                    return item.serialize();
                })
                .to_array()
        });
    }

    return lost_items.to_array();
}

function deserialize_lost_items(input) {
    var output = List();

    for (var i = 0; i < array_length(input); i++) {
        var lost_item_data = input[i];

        var items = List();

        for (var j = 0; j < array_length(lost_item_data.items); j++) {
            var serialized_item = lost_item_data.items[j];
            items.push(deserialize_live_item(serialized_item));
        }

        output.push({
            x: lost_item_data.x,
            y: lost_item_data.y,
            items: items,
        })
    }

    return output;
}

function all_lost_items() {
    var items = List();
    for (var i = 0; i < LocationId.LEN; i++) {
        var grid = GRIDS[i];
        if grid != undefined {
            for (var j = 0; j < grid.lost_items.count(); j++) {
                items.copy_from(grid.lost_items.get(j).items);
            }
        }
    }
    for (var i = 0; i < DYNAMIC_GRIDS.count(); i++) {
        var grid = DYNAMIC_GRIDS.get(i);
        if grid != undefined {
            for (var j = 0; j < grid.lost_items.count(); j++) {
                items.copy_from(grid.lost_items.get(j).items);
            }
        }
    }

    return items;
}

function item_is_soulbound(item_id) {
    var proto = ITEM_PROTOTYPES[item_id];
    if proto.soulbind == undefined {
        return false;
    }
    switch proto.soulbind.type {
        case Soulbind.Forever: return true;
        case Soulbind.Requirements: return requirements_pass(proto.soulbind.requirements);
        default: impossible("Unexpected Soulbind: {Soulbind}", proto.soulbind.type)
    }
}

enum AnnoyingItem {
    Cosmetic,
    RecipeScroll,
    CraftingScroll,
}

//
//
//
//
//
//
function string_to_item_id_or_unknown(str) {
    var item_id;
    if DEBUG_ASSERTIONS {
        item_id = string_to_item_id(str);
    } else {
        item_id = try_string_to_item_id(str);
        if item_id == undefined {
            error("Deserializing unexpected item_id: `{}`. replacing with unknown item...", str);
            item_id = ItemId.UnknownItem;
        }
    }
    return item_id;
}

//
function test_item_price_parsing() {
    var old_items = ITEM_PROTOTYPES;
    ITEM_PROTOTYPES = create_item_prototypes();

    var acorn = ITEM_PROTOTYPES[ItemId.Acorn];
    var salmon = ITEM_PROTOTYPES[ItemId.Salmon];
    //
    //

    acorn.value = {
        bin: 1,
        store: 2,
        renown: 0,
    };
    acorn.health_modifier = 5;
    acorn.stamina_modifier = 10;

    salmon.recipe = new Recipe(
        salmon.item_id,
        List(),
        [
            RecipeComponent.Item(
                acorn.item_id,
                5,
            )
        ],
        false,
    );

    assert_eq(query_item_price("acorn.bin", ItemId.Acorn, ITEM_PROTOTYPES), 1);
    assert_eq(query_item_price("acorn.store", ItemId.Acorn, ITEM_PROTOTYPES), 2);
    assert_eq(query_item_price("acorn.health_modifier", ItemId.Acorn, ITEM_PROTOTYPES), 5);
    assert_eq(query_item_price("acorn.stamina_modifier", ItemId.Acorn, ITEM_PROTOTYPES), 10);
    assert_eq(query_item_price("acorn", ItemId.Acorn, ITEM_PROTOTYPES), 1);
    assert_eq(query_item_price("self", ItemId.Acorn, ITEM_PROTOTYPES), 1);
    assert_eq(query_item_price("salmon.recipe", ItemId.Acorn, ITEM_PROTOTYPES), 5);
    assert_eq(query_item_price("salmon.recipe * 3", ItemId.Acorn, ITEM_PROTOTYPES), 15);
    assert_eq(query_item_price("self.recipe * 3", ItemId.Salmon, ITEM_PROTOTYPES), 15);

    ITEM_PROTOTYPES = old_items;
}

//
function test_description_seasonal_validity() {
    static FIND_CROP_SEASONS = function(item_id) {
        static ALL_SEASONS = [Season.Spring, Season.Summer, Season.Fall, Season.Winter];
        for (var i = 0; i < ObjectId.LEN; i++) {
            var proto = NODE_PROTOTYPES[i];
            if proto[$ "harvest"] == item_id {
                var seasons = [];
                for (var j = 0; j < Season.LEN; j++) {
                    if proto.seasons[j] {
                        array_push(seasons, j);
                    }
                }
                return seasons;
            }
            if proto[$ "shake_item"] == item_id {
                return ALL_SEASONS;
            }
            if proto[$ "fruit_data"] != undefined && proto.fruit_data.harvest == item_id {
                return array_map(proto.fruit_data.seasons.keys(), real)
            }
        }

        //

        //
        //
        //
        //
        return ALL_SEASONS;
    }

    static FIND_FISH_SEASONS = function(fish_id) {
        var proto = fiddle_get(format("fish/{FishId}", fish_id));
        if proto[$ "seasons"] == undefined {
            return [Season.Spring, Season.Summer, Season.Fall, Season.Winter];
        }
        return array_map(clone_value(proto.seasons), string_to_season);
    }

    static FIND_BUG_SEASONS = function(item_id) {
        var proto = fiddle_get(format("bugs/{ItemId}", item_id));
        if proto[$ "seasons"] == undefined {
            return [Season.Spring, Season.Summer, Season.Fall, Season.Winter];
        }
        return array_map(clone_value(proto.seasons), string_to_season);
    }

    //
    //
    var old = local_language();
    local_set_language("eng");

    var submissions = List();
    for (var i = 0; i < ItemId.LEN; i++) {
        var proto = ITEM_PROTOTYPES[i];
        if proto.tags.contains("forageable") || proto.tags.contains("crop") {
            submissions.push({
                item: i,
                description: local_get(proto.description_key),
                seasons: FIND_CROP_SEASONS(i)
            })
        }
    }

    for (var i = 0; i < FishId.LEN; i++) {
        var proto = FISH[i];
        submissions.push({
            item: proto.item,
            description: local_get(ITEM_PROTOTYPES[proto.item].description_key),
            seasons: FIND_FISH_SEASONS(i),
        })
    }

    var keys = BUGS.keys();
    for (var i = 0; i < array_length(keys); i++) {
        var proto = ITEM_PROTOTYPES[real(keys[i])];
        submissions.push({
            item: proto.item_id,
            description: local_get(proto.description_key),
            seasons: FIND_BUG_SEASONS(proto.item_id),
        })
    }

    var error_list = submissions.retain(function(submission) {
        //
        //
        var lower_desc = string_lower(submission.description);
        for (var i = 0; i < Season.LEN; i++) {
            if string_pos(season_to_string(i), lower_desc)
                && !array_contains(submission.seasons, i)
                && !string_pos(format("but {Season}", i), lower_desc)
            {
                submission.error_season = i;
                return true;
            }
        }
        return false;
    });

    local_set_language(old);

    if error_list.is_empty() {
        return;
    }

    error(
        "The following items have an incorrect season mentioned in their description:\n\n{}",
        error_list
            .map(function(v) {
                return format(
                    "{ItemId} mentions {Season} but only exists in {}\ndescription: '{}'\n",
                    v.item,
                    v.error_season,
                    array_map(v.seasons, season_to_string),
                    v.description,
                );
            })
            .join("\n")
    );

    crash();
}

//
function test_description_seed_validity() {
    var old = local_language();
    local_set_language("eng");
    var submissions = List();
    for (var i = 0; i < ItemId.LEN; i++) {
        var proto = ITEM_PROTOTYPES[i];
        if proto.use == ItemUse.PlantSeed {
            var regrow_stages = NODE_PROTOTYPES[proto.crop_object].post_harvest_day_to_stage;
            if regrow_stages == undefined {
                continue;
            }
            submissions.push({
                item: i,
                description: local_get(proto.description_key),
                regrow_days: regrow_stages.count() - 1,
            })
        }
    }

    var error_list = submissions.retain(function(submission) {
        var lower_desc = string_lower(submission.description);
        if !string_pos(format("{} day", submission.regrow_days), lower_desc) {
            return true;
        }

        return false;
    });

    local_set_language(old);

    if error_list.is_empty() {
        return;
    }

    error(
        "The following items have the incorrect number of regrow days in their description:\n\n{}",
        error_list
            .map(function(v) {
                return format(
                    "{ItemId} does not correctly report the number of days it takes to regrow ({})\ndescription: '{}'\n",
                    v.item,
                    v.regrow_days,
                    v.description,
                );
            })
            .join("\n")
    );

    crash();
}

//
function test_description_punctuation() {
    var old = local_language();
    local_set_language("eng");
    var error_list = List();
    for (var i = 0; i < ItemId.LEN; i++) {
        //
        if ITEM_PROTOTYPES[i].description_key == "misc_local/missing" {
            continue;
        }
        var description = local_get(ITEM_PROTOTYPES[i].description_key);
        var ends_with_punctuation = string_ends_with(description, ".")
            || string_ends_with(description, "!")
            || string_ends_with(description, "?");

        if ends_with_punctuation == false {
            error_list.push(i);
        }
    }

    local_set_language(old);

    if error_list.is_empty() {
        return;
    }

    error(
        "The following items need punctuation in their description:\n\n{}",
        error_list
            .map(function(v) {
                return format("{ItemId}", v);
            })
            .join("\n")
    );

    crash();
}

//
function test_description_rarity() {
    static FIND_FISH_RARITY = function(fish_id) {
        return FISH[fish_id].rarity;
    }

    static FIND_BUG_RARITY = function(item_id) {
        var proto = fiddle_get(format("bugs/{ItemId}", item_id));
        return proto[$ "rarity"] ?? "common";
    }

    //
    //
    var old = local_language();
    local_set_language("eng");

    var submissions = List();
    for (var i = 0; i < FishId.LEN; i++) {
        var proto = FISH[i];

        submissions.push({
            item: proto.item,
            description: local_get(ITEM_PROTOTYPES[proto.item].description_key),
            rarity: FIND_FISH_RARITY(i),
        })
    }

    var keys = BUGS.keys();
    for (var i = 0; i < array_length(keys); i++) {
        var proto = ITEM_PROTOTYPES[real(keys[i])];
        submissions.push({
            item: proto.item_id,
            description: local_get(proto.description_key),
            rarity: FIND_BUG_RARITY(proto.item_id),
        })
    }

    var error_list = submissions.retain(function(submission) {
        //
        //
        var lower_desc = string_lower(submission.description);

        //
        //
        //
        static ITERS = [
            { rarity: HashSetFromArray(["common", "very_common", "very_very_common", "ultra_common"]), sub_str: " common" },
            { rarity: HashSetFromArray(["uncommon"]), sub_str: "uncommon" },
            { rarity: HashSetFromArray(["kinda_rare"]), sub_str: "kinda rare" },
            { rarity: HashSetFromArray(["very_rare"]), sub_str: "very rare" },
            { rarity: HashSetFromArray(["rare"]), sub_str: "rare" },
        ];

        for (var i = 0; i < array_length(ITERS); i++) {
            var entry = ITERS[i];

            if string_pos(entry.sub_str, lower_desc) {
                if entry.rarity.contains(submission.rarity) || string_pos("chest", submission.rarity) {
                    return false;
                }

                submission.error_rarity = entry.rarity;
                return true;
            }
        }
        return false;
    });

    local_set_language(old);

    if error_list.is_empty() {
        return;
    }

    error(
        "The following items have an incorrect rarity mentioned in their description:\n\n{}",
        error_list
            .map(function(v) {
                return format(
                    "{ItemId} mentions '{}' but is '{}'\ndescription: '{}'\n",
                    v.item,
                    v.error_rarity,
                    v.rarity,
                    v.description,
                );
            })
            .join("\n")
    );

    crash();
}

//
function test_description_fish_size() {
    static FIND_FISH_RARITY = function(fish_id) {
        return FISH[fish_id].rarity;
    }

    static FIND_BUG_RARITY = function(item_id) {
        var proto = fiddle_get(format("bugs/{ItemId}", item_id));
        return proto[$ "rarity"] ?? "common";
    }

    //
    //
    var old = local_language();
    local_set_language("eng");

    var submissions = List();
    for (var i = 0; i < FishId.LEN; i++) {
        var proto = FISH[i];

        //
        //
        //
        if proto.item == ItemId.Clay {
            continue;
        }
        submissions.push({
            item: proto.item,
            description: local_get(ITEM_PROTOTYPES[proto.item].description_key),
            size: proto.size,
        })
    }

    var error_list = submissions.retain(function(submission) {
        //
        //
        var lower_desc = string_lower(submission.description);

        for (var i = 0; i < FishSize.LEN; i++) {
            var entry = fish_size_to_string(i);
            if string_pos(entry, lower_desc) && submission.size != i {
                submission.error_size = i;
                return true;
            }
        }
        return false;
    });

    local_set_language(old);

    if error_list.is_empty() {
        return;
    }

    error(
        "The following items have an incorrect fish size mentioned in their description:\n\n{}",
        error_list
            .map(function(v) {
                return format(
                    "{ItemId} mentions '{FishSize}' but is '{FishSize}'\ndescription: '{}'\n",
                    v.item,
                    v.error_size,
                    v.size,
                    v.description,
                );
            })
            .join("\n")
    );

    crash();
}
