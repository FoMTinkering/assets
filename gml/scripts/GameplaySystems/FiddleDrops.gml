function create_fiddle_drops(drops) {
    static DEFAULT_COUNT = [1, 1]
    var drop_bundle_data = List();
    for (var j = 0; j < array_length(drops); j++) {
        var drop_data = drops[j];

        var chance_pct = drop_data[$ "chance"] ?? 100;
        assert(is_real(chance_pct));
        var count_range = drop_data[$ "count_range"] ?? DEFAULT_COUNT;
        assert(is_array(count_range));
        var exclusive = bool(drop_data[$ "exclusive"] ?? true);
        var perfect_pick_chance = drop_data[$ "perfect_pick_chance"] == undefined ? 0 : drop_data.perfect_pick_chance;
        drop_bundle_data.push(new ItemDrop(chance_pct, exclusive, string_to_item_id(drop_data.item), count_range, perfect_pick_chance));
    }
    return new ItemDropBundle(drop_bundle_data);
}
