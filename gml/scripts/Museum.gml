global.__museum_data = undefined;
#macro MUSEUM_DATA global.__museum_data

global.__museum_progress_data = undefined;
#macro MUSEUM_PROGRESS global.__museum_progress_data

enum MuseumWing {
    Archaeology,
    Fish,
    Flora,
    Insect,
    LEN
}

function museum_parse_sets() {
    var museum_fiddle = fiddle_get_directory("museum_wings");
    var museum_db = array_create(MuseumWing.LEN, undefined);
    var museum_items = array_bool(ItemId.LEN);

    for (var i = 0; i < MuseumWing.LEN; i++) {
        var wing_name = museum_wing_to_string(i);
        var f_wing = museum_fiddle[$ wing_name];

        var sets = Map();
        var reward_len = array_length(f_wing.rewards);
        var set_keys = struct_get_names(f_wing.sets);
        var set_len = array_length(set_keys);
        assert_eq(
            reward_len,
            set_len,
            "Wing '{}' has {} rewards but needs {}!",
            wing_name,
            reward_len,
            set_len,
        );

        for (var j = 0; j < set_len; j++) {
            var set_key = set_keys[j];
            var f_v = f_wing.sets[$ set_key];

            var set = {
                name: set_key,
                display_name: f_v.name,
                description: f_v.description,
                items: array_map(f_v.items, string_to_item_id),
            };

            for (var k = 0; k < array_length(set.items); k++) {
                museum_items[set.items[k]] = true;
            }

            sets.insert(set_key, set);
        }

        museum_db[i] = {
            name: f_wing.name,
            rewards: ListFromArray(f_wing.rewards).map_to(function(reward) {
                    return {
                        preview_sprite: string_to_asset(reward.preview_sprite),
                        entries: ListFromArray(reward.entries).map_to(parse_reward),
                    };
                }),
            sets: sets,
        };
    }

    return new MuseumData(museum_db, museum_items);
}

function MuseumData(data, museum_items) constructor {
    //
    self.data = data;

    //
    self.museum_items = museum_items;

    //
    //
    function get_collection(wing, set_name) {
        var sets = self.data[wing].sets;
        return sets.get(set_name);
    }

    //
    function is_museum_item(item) {
        return self.museum_items[item];
    }
}

//
function museum_set_progress(wing, set) {
    var items = MUSEUM_DATA.data[wing].sets.get(set).items;
    var total = 0;
    for (var i = 0; i < array_length(items); i++) {
        total += MUSEUM_PROGRESS[items[i]];
    }
    return total;
}

//
function museum_set_size(wing, set) {
    return array_length(MUSEUM_DATA.data[wing].sets.get(set).items);
}

//
function register_item_to_museum(item_id) {
    MUSEUM_PROGRESS[item_id] = true;
    T2R.write(format("museum_donated_{ItemId}", item_id), true);
}

//
function donate_item_to_museum(item_id) {
    register_item_to_museum(item_id);
    ARI.pending_renown_entries.push(RenownEntry.MuseumDonation(item_id));

    //
    for (var i = 0; i < MuseumWing.LEN; i++) {
        var wing = MUSEUM_DATA.data[i];
        var set_keys = wing.sets.keys();
        for (var j = 0; j < array_length(set_keys); j++) {
            var set_key = set_keys[j];
            var set = wing.sets.get(set_key);

            //
            if array_contains(set.items, item_id) {
                //
                var progress = museum_set_progress(i, set_key);
                var set_size = museum_set_size(i, set_key);
                if progress == set_size {

                    //
                    //
                    var sets_completed = 0;
                    for (var k = 0; k < array_length(set_keys); k++) {
                        var set_key = set_keys[k];
                        //
                        var this_set_size = museum_set_size(i, set_key);
                        if this_set_size == 0 {
                            continue;
                        }

                        sets_completed += museum_set_progress(i, set_key) == this_set_size;
                    }

                    return {
                        type: DonationResult.CompletedSet,
                        set: set,
                        wing: i,
                        rewards: wing.rewards.get(sets_completed - 1).entries,
                        item_donated: item_id,
                    };
                } else {
                    return {
                        type: DonationResult.ProgressMade,
                        set: set,
                        wing: i,
                        item_donated: item_id,
                    };
                }
            }
        }
    }

    return {
        type: DonationResult.None,
    };
}

enum DonationResult {
    None,
    ProgressMade,
    CompletedSet,
}
