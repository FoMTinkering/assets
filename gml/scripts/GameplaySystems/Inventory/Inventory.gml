function Inventory(size) {
    var inv = new __Inventory();
    if size != undefined {
        inv.resize(size);
    }

    return inv;
}


function InventoryFromArray(array) {
    var inv = new __Inventory();
    for (var i = 0; i < array_length(array); i++) {
        if !inv.can_add(array[i]) {
            inv.resize(inv.size() + 1);
        }
        inv.add(array[i]);
    }
    return inv;
}

//
//
//
function __Inventory() constructor {
    self.slots = List();
    self.maximum_item_counts = array_create(ItemId.LEN, undefined);

    //
    static size = function() {
        return self.slots.count();
    }

    //
    static total_items = function() {
        return self.slots.sum_with(function(slot) {
            return slot.count;
        });
    }

    //
    static is_empty = function() {
        return !self.slots.any(function(a) {
            return a.count > 0;
        });
    }

    //
    static resize = function(new_size) {
        while self.size() > new_size {
            self.slots.pop();
        }

        while self.size() < new_size {
            self.slots.push(new InventorySlot(self.size(), self));
        }
    }

    //
    static slot = function(index) {
        return self.slots.get(index);
    }

    //
    static add = function(item, count=1) {
        var proto = is_struct(item) ? item.prototype : ITEM_PROTOTYPES[item];
        var remaining = count;
        while remaining > 0 {
            var slot = self.slot_for_item(item);
            var to_add = slot.one_slot ? 1 : min(remaining, proto.max_stack - slot.count);
            remaining -= to_add;
            slot.add(item, to_add);
        }
    }

    //
    static remove = function(item, count=1) {
        var remaining = count;
        var size = self.size();
        for (var i = 0; i < size; i++) {
            var slot = self.slot(i);
            if slot.item != undefined && slot.item.item_id == item {
                var amount_to_remove = min(slot.count, remaining);
                slot.remove(amount_to_remove);
                remaining -= amount_to_remove;
                if remaining == 0 {
                    break;
                }
            }
        }
    }

    //
    static can_add = function(item, count=1) {
        return self.room_for_item(item) >= count;
    }

    //
    static room_for_item = function(item) {
        var count = 0;
        for (var i = 0; i < self.size(); i++) {
            var slot = self.slot(i);
            count += slot.room_for_item(item);
        }

        var item_id = is_struct(item) ? item.item_id : item;
        var limit = self.maximum_item_counts[item_id];
        if limit != undefined {
            var currently_held = self.item_id_quantity(item_id);
            count = min(count, limit - currently_held);
        }

        return count;
    }

    //
    //
    static slot_for_item = function(item, count=1) {
        var size = self.size();
        var backup_slot = undefined;
        for (var i = 0; i < size; i++) {
            var slot = self.slot(i);
            if slot.room_for_item(item) >= count {
                //
                //
                //
                if slot.count != 0 {
                    return slot;
                } else {
                    backup_slot = backup_slot == undefined ? slot : backup_slot;
                }
            }
        }

        //
        //
        return backup_slot;
    }

    //
    static item_id_quantity = function(item_id) {
        var count = 0;
        var len = self.size();
        for (var i = 0; i < len; i++) {
            var slot = self.slots.get(i);
            count += slot.item != undefined && slot.item.item_id == item_id ? slot.count : 0;
        }
        return count;
    }

    //
    static item_tag_quantity = function(tag) {
        return self
            .slots_with_item_tag(tag)
            .sum_with(function(slot) {
                return slot.count;
            });
    }

    //
    static slots_with_item_tag = function(tag) {
        return self.slots
            .clone()
            .retain(function(slot, tag) {
                return slot.item != undefined && slot.item.prototype.tags.contains(tag);
            }, tag)
    }

    //
    static remove_items_with_tag = function(tag, amount) {
        var slots = self.slots_with_item_tag(tag);
        var left_to_remove = amount;
        for (var i = 0; i < slots.count(); i++) {
            var slot = slots.get(i);
            var amount_to_remove = min(slot.count, left_to_remove);
            slot.remove(amount_to_remove);
            left_to_remove -= amount_to_remove;
            if left_to_remove == 0 {
                break;
            }
        }
    }

    //
    static drain = function() {
        var list = List();
        self.slots.fold(list, function(list, slot) {
            list.transfer(slot.drain());
            return list;
        });
        return list;
    }

    //
    static serialize = function() {
        //
        return self.slots
            .map_to(function(slot) {
                return {
                    required_tags: slot.required_tags.to_array(),
                    item: slot.item == undefined ? undefined : slot.item.serialize(),
                    count: slot.count,
                }
            })
            .to_array();
    }

    //
    static deserialize = function(array) {
        self.resize(array_length(array));
        for (var i = 0; i < self.size(); i++) {
            var slot = self.slot(i)
            var slot_data = array[i];
            slot.required_tags = ListFromArray(slot_data.required_tags);
            if slot_data[$ "members"] != undefined {
                slot.item = array_is_empty(slot_data.members)
                    ? undefined
                    : deserialize_live_item(slot_data.members[0]);
                slot.count = array_length(slot_data.members);
            } else {
                slot.item = opt_and_then(slot_data.item, deserialize_live_item);
                if slot.item != undefined {
                    slot.count = slot_data.count;
                }
            }
        }
    }

    //
    static sort = function() {

        //
        //
        self.drain().for_each(function(e) {
            self.add(e);
        });

        //
        self.slots
            .map_to(function(v) {
                return [v.item, v.count];
            })
            .sort_with(function(a, b) {
                var a_item = a[0];
                var b_item = b[0];
                if a_item == undefined {
                    return 1;
                } else if b_item == undefined {
                    return -1;
                } else {
                    var a_value = a_item.prototype.use ?? I32_MAX;
                    var b_value = b_item.prototype.use ?? I32_MAX;

                    if a_value == b_value {
                        var a_name = a_item.get_display_name();
                        var b_name = b_item.get_display_name();
                        if a_name == b_name {
                            return a[1] < b[1] ? -1 : 1;
                        } else {
                            return string_alphanumeric_comparison(a_name, b_name);
                        }
                    } else {
                        return sign(a_value - b_value);
                    }
                }
            })
            .enumerate()
            .for_each(function(e) {
                var slot = self.slots.get(e[0]);
                slot.item = e[1][0];
                slot.count = e[1][1];
                slot.updates += 1;
            })
    }

    toString = function() {
        return format("Inventory[{}]", self.slots
            .clone()
            .retain(function(v) {
                return v.count != 0;
            })
            .join(", ")
        );
    }
}

//
//
//
function InventorySlot(index, inventory) constructor {
    self.index = index;
    self.inventory = inventory;
    self.item = undefined;
    self.count = 0;
    self.required_tags = List();
    self.allow_soulbound = true;
    self.updates = 0;
    self.one_slot = false;

    //
    function add(item, count=1) {
        if self.item == undefined {
            self.item = is_struct(item) ? item : new LiveItem(item);
        }
        //
        self.count += count;
        self.updates += 1;
    }

    //
    function swap(slot) {
        var our_item = self.item;
        var our_count = self.count;
        self.item = slot.item;
        self.count = slot.count;
        slot.item = our_item;
        slot.count = our_count;
        self.updates += 1;
        slot.updates += 1;
    }

    //
    function pop() {
        var item = self.item;
        self.remove(1);
        return item;
    }

    //
    function remove(amount) {
        self.updates += 1;
        self.count -= amount;
        if self.count <= 0 {
            self.count = 0;
            self.item = undefined;
        }
    }

    //
    //
    function drain(list) {
        list = list == undefined ? List() : undefined;
        repeat self.count {
            list.push(self.item);
        }
        self.remove(self.count);
        return list;
    }

    //
    //
    //
    function room_for_item(item) {
        item = is_struct(item) ? item : new LiveItem(item);

        if !self.valid_for(item) || (self.count != 0 && !self.item.partial_eq(item)) {
            return 0;
        }

        if self.one_slot {
            return self.count == 0 ? 1 : 0;
        }

        var maximum = item.prototype.max_stack - self.count;
        var limit = self.inventory.maximum_item_counts[item.item_id];
        if limit != undefined {
            limit -= self.inventory.item_id_quantity(item.item_id);
            maximum = min(maximum, limit);
        }

        return maximum;
    }

    //
    //
    //
    function valid_for(item) {
        var item_id = is_struct(item) ? item.item_id : item;
        return
            (!item_is_soulbound(item_id) || self.allow_soulbound)
            && ITEM_PROTOTYPES[item_id].tags.satisfies(self.required_tags);
    }

    toString = function() {
        return self.count == 0
            ? "<empty slot>"
            : format("{}x{}", self.item.get_display_name(), self.count);
    }
}

//
//
function InventorySubscriber(inventory) constructor {
    self.inventory = inventory;
    self.timestamps = Map();
    for (var i = 0; i < self.inventory.size(); i++) {
        self.timestamps.insert(i, self.inventory.slot(i).updates);
    }

    //
    function pull() {
        static EMPTY_LIST = List(); //
        var output = undefined;
        for (var i = 0; i < self.inventory.slots.count(); i++) {
            var slot = self.inventory.slots.get(i);
            var last_read = self.timestamps.get_or_insert(slot.index, -1);
            if last_read != slot.updates {
                self.timestamps.set(slot.index, slot.updates);
                output = output == undefined ? List() : output;
                output.push(slot);
            }
        }
        return output ?? EMPTY_LIST;
    }
}

function inventory_satisfies_recipe(recipe, basket) {
    var totals = array_create(ItemId.LEN, 0);
    var components = struct_get_names(recipe);

    for (var i = 0, c = basket.size(); i < c; i++) {
        var inventory_slot = basket.slot(i);
        var item_in_basket = inventory_slot.item;

        if item_in_basket == undefined {
            continue;
        }

        for (var j = 0, k = array_length(components); j < k; j++) {
            if item_in_basket.item_id == real(components[j]) {
                totals[item_in_basket.item_id] += inventory_slot.count;
            }
        }
    }

    for (var i = 0, c = array_length(components); i < c; i++) {
        if totals[real(components[i])] < recipe[$ components[i]] {
            return false;
        }
    }

    return true;
}

function inventory_drain_ingredients(recipe, basket) {
    var components = struct_get_names(recipe);
    var remaining_cost = {};

    for (var i = 0, c = array_length(components); i < c; i++) {
        remaining_cost[$ components[i]] = recipe[$ components[i]];
    }

    for (var i = 0, c = basket.size(); i < c; i++) {
        var inventory_slot = basket.slot(i);
        var item_in_basket = inventory_slot.item;

        if item_in_basket == undefined {
            continue;
        }

        for (var j = 0, k = array_length(components); j < k; j++) {
            if remaining_cost[$ components[j]] != 0  && item_in_basket.item_id == real(components[j]) {
                if remaining_cost[$ components[j]] - inventory_slot.count >= 0 {
                    remaining_cost[$ components[j]] -= inventory_slot.count;
                    inventory_slot.remove(inventory_slot.count);
                } else {
                    inventory_slot.remove(remaining_cost[$ components[j]]);
                    continue;
                }
            }
        }
    }
}

//
function inventory_unit_test() {
    //
    var inventory = Inventory(5);

    //
    inventory.slot(0).add(ItemId.Salmon);

    //
    assert_eq(
        inventory.slot(0).pop().item_id,
        ItemId.Salmon,
    );

    //
    inventory.add(ItemId.Acorn);
    assert_eq(
        inventory.slot(0).item.item_id,
        ItemId.Acorn,
    );

    //
    inventory.remove(ItemId.Acorn);
    assert_eq(inventory.slot(0).count, 0);

    //
    inventory.slot(1).add(ItemId.Acorn);

    //
    //
    inventory.add(ItemId.Acorn);
    assert_eq(inventory.slot(0).count, 0);
    assert_eq(inventory.slot(1).count, 2);
    inventory.remove(ItemId.Acorn, 2);

    //
    inventory.add(ItemId.Potato, 3);

    //
    var potatoes = inventory.slot(0).drain();
    assert_eq(potatoes.count(), 3);
    assert(!potatoes.any(function(e) {
        return e.item_id != ItemId.Potato;
    }));

    //
    inventory.resize(1);

    //
    var salmon = new LiveItem(ItemId.Salmon);
    salmon.infusion = Infusion.Restorative;
    inventory.add(salmon);
    assert(inventory.slot(0).item.partial_eq(salmon));

    //
    assert(!inventory.can_add(ItemId.Salmon));
    assert_eq(inventory.slot(0).room_for_item(ItemId.Salmon), 0);
    assert_eq(inventory.room_for_item(ItemId.Salmon), 0);

    //
    assert(inventory.can_add(salmon.clone()));

    //
    var subscriber = new InventorySubscriber(inventory);
    inventory.slot(0).pop();
    inventory.slot(0).add(ItemId.Turnip);
    var updates = subscriber.pull();
    assert_eq(updates.count(), 1);
    assert_eq(updates.first().item.item_id, ItemId.Turnip);

    //
    var serde = inventory.serialize();
    var deserde_inv = Inventory();
    deserde_inv.deserialize(serde);
    assert_eq(deserde_inv.slot(0).item.item_id, ItemId.Turnip);
}
