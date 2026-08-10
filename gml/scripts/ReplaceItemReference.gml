//
function replace_item_reference(old_key, loader, saver, replacement) {

    var player_file = loader.load_file("player");
    patch_item_reference_in_array(player_file.items_acquired, old_key, replacement);
    patch_item_reference_in_array(player_file.recipe_unlocks, old_key, replacement);
    patch_item_reference_in_struct(player_file.items_sold, old_key, replacement);
    patch_item_reference_in_array(player_file.annual_item_purchase_bans, old_key, replacement);
    patch_item_reference_in_inventory(player_file.inventory, old_key, replacement);
    patch_item_reference_in_inventory(player_file.armor, old_key, replacement);
    patch_item_reference_in_inventory(player_file.renown_reward_inventory, old_key, replacement);

    if player_file[$ "recipes_created"] != undefined {
        patch_item_reference_in_array(player_file.recipes_created, old_key, replacement);
    }

    if player_file[$ "morning_recipe_unlocks"] != undefined {
        patch_item_reference_in_array(player_file.morning_recipe_unlocks, old_key, replacement);
    }

    if player_file[$ "lost_and_found"] != undefined {
        patch_item_reference_in_inventory(player_file.lost_and_found, old_key, replacement);
    }

    saver.save_file("player", player_file);

    var game_data = loader.load_file("gamedata");
    for (var i = 0; i < Seal.LEN; i++) {
        var inventory = game_data.seals[$ seal_to_string(i)];
        if inventory != undefined {
            patch_item_reference_in_inventory(inventory, old_key, replacement);
        }
    }

    patch_item_reference_in_array(game_data.museum_progress, old_key, replacement);

    var grid_count = game_data.dynamic_grid_count;
    var grid_names = ListFromArray(array_create_ext(LocationId.LEN, location_id_to_string));
    grid_names.copy_from(ListFromArray(array_create_ext(grid_count, create_dynamic_grid_file_name)));
    for (var i = 0, ic = grid_names.count(); i < ic; i++) {
        var name = grid_names.get(i);
        if loader.has_file(name) {
            var file_data = loader.load_file(name);
            patch_item_reference_in_grid(file_data, old_key, replacement);
            saver.save_file(name, file_data);
        }
    }

    var lost_items = game_data.lost_items;
    for (var i = 0; i < LocationId.LEN; i++) {
        var these_items = lost_items[$ location_id_to_string(i)];
        if is_nullish(these_items) {
            continue;
        }

        patch_item_reference_in_lost_items(these_items, old_key, replacement);
    }
    for (var i = 0, ic = array_length(lost_items.dynamic_lost_items); i < ic; i++) {
        var these_items = lost_items.dynamic_lost_items[i];
        if is_nullish(these_items) {
            continue;
        }

        patch_item_reference_in_lost_items(these_items, old_key, replacement);
    }
    saver.save_file("gamedata", game_data);

    var npcs = loader.load_file("npcs");
    var keys = struct_get_names(npcs);
    for (var i = 0, ic = array_length(keys); i < ic; i++) {
        patch_item_reference_in_array(npcs[$ keys[i]].gifts_given, old_key, replacement);
        var gift_prefs = npcs[$ keys[i]][$ "known_gift_preferences"];
        if gift_prefs != undefined {
            patch_item_reference_in_array(gift_prefs, old_key, replacement);
        }
    }
    saver.save_file("npcs", npcs);
}

function patch_item_reference_in_array(array, old_key, replacement) {
    while true {
        var index = array_index(array, old_key);
        if index == undefined {
            break;
        }
        if replacement == undefined {
            array_delete(array, index, 1);
        } else {
            array[index] = replacement;
        }
    }
}

function patch_item_reference_in_struct(struct, old_key, replacement) {
    if struct[$ old_key] != undefined {
        if replacement != undefined {
            struct[$ replacement] = struct[$ old_key];
        }
        struct_remove(struct, old_key);
    }
}

function patch_item_reference_in_grid(grid, old_key, replacement) {
    var inventories = grid[$ "inventories"];
    if inventories != undefined {
        for (var j = 0, jc = array_length(inventories); j < jc; j++) {
            var inventory = inventories[j];
            patch_item_reference_in_inventory(inventory, old_key, replacement);
        }
    }
    var objects = grid[$ "object_list"];
    if objects != undefined {
        for (var i = 0, ic = array_length(objects); i < ic; i++) {
            var object = objects[i];
            if object[$ "sub_grid_blob"] != undefined {
                patch_item_reference_in_grid(object.sub_grid_blob, old_key, replacement);
            }

            if object[$ "stable"] != undefined {
                var inventory_targets = [
                    object.stable[$ "left_inventory"],
                    object.stable[$ "right_inventory"],
                    object.stable[$ "inventory"],
                ];

                for (var j = 0, jc = array_length(inventory_targets); j < jc; j++) {
                    var target = inventory_targets[j];
                    if target == undefined {
                        continue;
                    }

                    //
                    for (var k = array_length(target) - 1; k >= 0; k--) {
                        var maybe_item = target[k];
                        if maybe_item == undefined {
                            continue;
                        }

                        if maybe_item.item_id == old_key {
                            if replacement == undefined {
                                array_delete(target, k, 1);
                            } else {
                                member.item_id = replacement;
                            }
                        }
                    }
                }
            }
        }
    }
}

function patch_item_reference_in_inventory(inventory, old_key, replacement) {
    for (var i = 0, ic = array_length(inventory); i < ic; i++) {
        var slot = inventory[i];
        if slot[$ "members"] != undefined {
            for (var j = 0, jc = array_length(slot.members); j < jc; j++) {
                var member = slot.members[j];
                var replace = false;
                if member.item_id == old_key {
                    if replacement == undefined {
                        replace = true;
                    } else {
                        member.item_id = replacement;
                    }
                }
                if member.inner_item == old_key {
                    if replacement == undefined {
                        replace = true;
                    } else {
                        member.inner_item = replacement;
                    }
                }

                if replace {
                    array_delete(slot.members, j, 1);
                    j -= 1;
                    jc -= 1;
                }
            }
        } else if slot.item != undefined {
            if slot.item.item_id == old_key {
                if replacement == undefined {
                    slot.item = undefined;
                } else {
                    slot.item.item_id = replacement;
                }
            }

            if slot.item != undefined && slot.item.inner_item == old_key {
                slot.item.inner_item = replacement;
            }
        }
    }
}

function patch_item_reference_in_lost_items(lost_items, old_key, replacement) {
    for (var i = 0, ic = array_length(lost_items); i < ic; i++) {
        var lost_item_data = lost_items[i];
        for (var j = 0, jc = array_length(lost_item_data.items); j < jc; j++) {
            var member = lost_item_data.items[j];
            var replace = false;
            if member.item_id == old_key {
                if replacement == undefined {
                    replace = true;
                } else {
                    member.item_id = replacement;
                }
            }
            if member.inner_item == old_key {
                if replacement == undefined {
                    replace = true;
                } else {
                    member.inner_item = replacement;
                }
            }

            if replace {
                array_delete(lost_item_data.items, j, 1);
                j -= 1;
                jc -= 1;
            }
        }
        if array_is_empty(lost_item_data.items) {
            array_delete(lost_items, i, 1);
            i -= 1;
            ic -= 1;
        }
    }
}
