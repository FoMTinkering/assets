#macro STORES global.__stores
STORES = undefined;

function load_stores() {
    var stores = array_create(Store.LEN, undefined);
    var f_stores = clone_value(fiddle_get("stores"));
    var store_keys = struct_get_names(f_stores);
    for (var i = 0; i < array_length(store_keys); i++) {
        var key = store_keys[i];
        var store = f_stores[$ key];
        store.recipe_target = store[$ "recipe_target"] ?? undefined;

        var recipes_generated = HashSet();
        for (var j = 0; j < array_length(store.categories); j++) {
            var cat = store.categories[j];
            cat.icon = string_to_asset(cat.icon);
            cat.accept_recipes = cat[$ "accept_recipes"] ?? false;
            cat.target_selections = cat[$ "target_selections"] ?? 0;
            cat.tag = cat[$ "tag"];

            static PROCESS_STOCK = function(stock, recipes_generated) {
                for (var i = 0; i < array_length(stock); i++) {
                    var entry = stock[i];
                    if is_string(entry) {
                        entry = { item: entry };
                    }

                    var item = parse_store_item(entry);

                    stock[i] = {
                        item,
                        requirements: parse_requirements(entry[$ "requirements"] ?? {}),
                        attached_recipe: undefined,
                    };

                    if entry[$ "include_recipe"]
                        && item.prototype.recipe != undefined
                        && !recipes_generated.contains(item.prototype.recipe_key)
                    {
                        if item.prototype.tags.contains("furniture") {
                            stock[i].attached_recipe = new LiveItem(ItemId.CraftingScroll, item.item_id);
                        } else if item.prototype.use == ItemUse.Consume {
                            stock[i].attached_recipe = new LiveItem(ItemId.RecipeScroll, item.item_id);
                        }
                        recipes_generated.insert(item.prototype.recipe_key);
                    }
                }
            }

            cat.random_stock = cat[$ "random_stock"] ?? [];
            PROCESS_STOCK(cat.random_stock, recipes_generated);

            cat.constant_stock = cat[$ "constant_stock"] ?? [];
            PROCESS_STOCK(cat.constant_stock, recipes_generated);

            var season_input = cat[$ "seasonal"] ?? {};
            cat.seasonal = array_create(Season.LEN, undefined);
            for (var k = 0; k < Season.LEN; k++) {
                cat.seasonal[k] = season_input[$ season_to_string(k)] ?? [];
                PROCESS_STOCK(cat.seasonal[k], recipes_generated);
            }
        }

        store.id = string_to_store(key);

        stores[store.id] = store;
    }

    return stores;
}

function parse_store_item(entry) {
    if is_string(entry) {
        entry = { item: entry };
    }

    var item = undefined;

    if entry[$ "item"] != undefined {
        item = new LiveItem(string_to_item_id(entry.item));
    }

    if entry[$ "recipe_scroll"] != undefined {
        item = new LiveItem(ItemId.RecipeScroll, string_to_item_id(entry.recipe_scroll));
    }

    if entry[$ "crafting_scroll"] != undefined {
        item = new LiveItem(ItemId.CraftingScroll, string_to_item_id(entry.crafting_scroll));
    }

    if entry[$ "cosmetic"] != undefined {
        assert(
            PLAYER_ANIMATION_DATABASE.player_assets.contains_key(entry.cosmetic),
            "Cosmetic '{}' does not exist", entry.cosmetic
        );

        item = new LiveItem(ItemId.Cosmetic);
        item.cosmetic = entry.cosmetic;
    }

    if entry[$ "animal_cosmetic"] != undefined {
        var animal = string_to_animal_kind(entry.animal);
        assert(
            ANIMAL_PROTOTYPES[animal].cosmetics.contains_key(entry.animal_cosmetic),
            "Animal cosmetic '{}' does not exist", entry.animal_cosmetic
        );

        item = new LiveItem(ItemId.AnimalCosmetic);
        item.animal_cosmetic = { animal: animal, cosmetic: entry.animal_cosmetic };
    }

    assert_neq(item, undefined, "Failed to parse an item out of '{}'", entry);

    return item;
}

function check_store_entry_unlocked(entry) {
    if !requirements_pass(entry.requirements) {
        return false;
    }

    //
    //
    if !entry.item.purchasable() && !item_was_purchased_today(entry.item) {
        return false;
    }

    return true;
}

function create_store_stock(store) {
    random_set_seed(Game.unique_identifier + get_days(CALENDAR.time));

    var data = STORES[store];
    var selected_entries = [];
    var leftover_random_entries = [];
    var output = List();

    //
    var recipe_category = undefined;
    var recipe_target = undefined;
    for (var i = 0; i <  array_length(data.categories); i++) {
        var cat = data.categories[i];
        var entry = {
            icon: cat.icon,
            items: List(),
        }
        if cat.accept_recipes {
            recipe_category = cat;
            recipe_target = entry;
        }

        output.push(entry);
    }

    for (var i = 0; i < array_length(data.categories); i++) {
        var cat = data.categories[i];
        var item_list = output.get(i).items;

        //
        //
        var base_entries = array_concat(cat.constant_stock, cat.seasonal[CALENDAR.season()]);
        for (var j = 0; j < array_length(base_entries); j++) {
            var entry = base_entries[j];
            if check_store_entry_unlocked(entry) {
                item_list.push(entry.item);
                array_push(selected_entries, entry);
            }
        }

        //
        var shuffled = array_shuffle(cat.random_stock);
        var target = cat.target_selections;
        while target > 0 {
            var entry = array_pop(shuffled);
            if entry == undefined {
                break;
            }

            if check_store_entry_unlocked(entry) {
                item_list.push(entry.item);
                array_push(selected_entries, entry);
                target -= 1;
            }
        }

        leftover_random_entries = array_concat(leftover_random_entries, shuffled);
    }

    //
    switch store {
        case Store.Carpenter:
            var cat;
            for (var i = 0; i < array_length(data.categories); i++) {
                if data.categories[i].tag == "objects" {
                    cat = output.get(i);
                    break;
                }
            }
            var player_level = ARI.level(Skill.Cooking);
            var cozy_level = fiddle_get("misc/kitchen_level_requirements/two");
            var adept_level = fiddle_get("misc/kitchen_level_requirements/three");
            if player_level >= cozy_level {
                cat.items.push(new LiveItem(ItemId.CozyKitchen));
            }
            if player_level >= adept_level {
                cat.items.push(new LiveItem(ItemId.AdeptKitchen));
            }
            break;
        case Store.MapleSpringFestival:
        case Store.NoraSouvenirStall:
        case Store.ElsieSpringFestival:
            cat = output.first();
            var festival = todays_festival() ?? FestivalId.Spring; //
            var festival_proto = FESTIVALS[festival].prototype;
            var input = festival_proto.stocks[$ store_to_string(store)];
            var last_tier = 0;
            if !array_is_empty(festival_proto.challenges) {
                var artifact = ARI.quest_artifacts.get(festival_proto.challenges[0].artifact_key);
                last_tier = artifact == undefined ? 0 : artifact.last_tier;
            }
            for (var i = 0; i < array_length(input); i++) {
                var e = input[i];
                if last_tier >= e.tier_required && check_store_entry_unlocked(e) {
                    cat.items.push(e.item);
                }
            }
            break;
        default: break;
    }

    //
    if recipe_category != undefined {
        leftover_random_entries = array_shuffle(leftover_random_entries);
        while recipe_target.items.count() < recipe_category.target_selections {

            var entry = undefined;
            if !array_is_empty(selected_entries) {
                entry = array_pop(selected_entries);
            } else {
                entry = array_pop(leftover_random_entries);
            }

            //
            if entry == undefined {
                break;
            }

            if
                entry.attached_recipe != undefined
                && !ARI.morning_recipe_unlocks[entry.attached_recipe.inner_item]
            {
                recipe_target.items.push(entry.attached_recipe)             ;
            }
        }
    }

    //
    for (var i = 0; i < output.count(); i++) {
        output.get(i).items.retain(function(item) {
            return item.purchasable();
        });
    }

    //
    var all_are_empty = output.every(function(v) {
        return v.items.is_empty();
    });
    if all_are_empty {
        output = List(output.first());
    } else {
        output.retain(function(v) {
            return !v.items.is_empty();
        });
    }

    randomize();

    return output;
}

global.__inn_stock = undefined;
#macro INN_STOCK global.__inn_stock

function inn_stock_needs_plate(item_id) {
    return matches(
        item_id,
        ItemId.BreadedCatfish,
        ItemId.LoadedBakedPotato,
        ItemId.Riceball,
        ItemId.RedSnapperSushi,
    );
}

//
function test_inn_plates() {

    static GATHER = function(stock, list) {
        for (var i = 0; i < array_length(stock); i++) {
            list.push(stock[i].item);
        }
    }

    var items = List();
    var inn = STORES[Store.Inn];
    for (var i = 0; i < array_length(inn.categories); i++) {
        GATHER(inn.categories[i].random_stock, items);
        GATHER(inn.categories[i].constant_stock, items);
        GATHER(inn.categories[i].seasonal[Season.Spring], items);
        GATHER(inn.categories[i].seasonal[Season.Summer], items);
        GATHER(inn.categories[i].seasonal[Season.Fall], items);
        GATHER(inn.categories[i].seasonal[Season.Winter], items);
    }

    items.filter_map(function(item) {
        var is_food = item.prototype.stars != undefined;
        var valid = item.prototype.tags.contains("inn_plate")
            || item.prototype.tags.contains("no_inn_plate");
        if is_food && !valid {
            return item.pretty_print();
        } else {
            return undefined;
        }
    });

    if !items.is_empty() {
        crash(
            "The following food items appear in the Inn but do not specify if they should render with a plate or not: \n{}",
            items.join("\n")
        );
    }
}
