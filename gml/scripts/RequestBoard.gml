#macro REQUEST_BOARD_ENTRIES global.__request_board_entries
REQUEST_BOARD_ENTRIES = undefined;

#macro REQUEST_BOARD global.__request_board
REQUEST_BOARD = undefined;

#macro REQUEST_BOARD_READ_ENTRIES global.__request_board_read_entries
REQUEST_BOARD_READ_ENTRIES = undefined;

#macro MANUAL_QUEST_UNLOCKS global.__manual_quest_unlocks
MANUAL_QUEST_UNLOCKS = undefined;

//
function load_request_board_entries() {
    var requests = clone_value(fiddle_get("quests/request_board"));
    var default_entry = struct_take(requests, "default");

    var keys = struct_get_names(requests);
    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];
        CONTENT_REGISTRY.validate_quest(key);

        var entry = patch_object(filter_toml_nulls(requests[$ key]), clone_value(default_entry));

        var requirements = parse_requirements(entry.requirements);

        requests[$ key] = {
            randomly_selected: entry[$ "randomly_selected"],
            requirements,
        };
    }

    return Map(requests);
}

//
function create_request_board() {
    random_set_seed(Game.unique_identifier + get_days(CALENDAR.time));
    var requests = List();

    //
    if ARI.ready_for_crown_quest() {

        //
        var last_index = undefined;
        for (var i = array_length(CROWN_QUESTS) - 1; i >= 0; i--) {
            var req = CROWN_QUESTS[i];
            if QUEST_LOG.completed.contains(req.quest) || QUEST_LOG.active.contains_key(req.quest) {
                last_index = i;
                break;
            }
        }

        //
        //
        var offer = undefined;
        if last_index == undefined {
            offer = CROWN_QUESTS[0];
        } else if (last_index + 1) < array_length(CROWN_QUESTS) {
            offer = CROWN_QUESTS[last_index + 1];
        }

        //
        if offer != undefined
            && !QUEST_LOG.active.contains_key(offer.quest)
            && (offer.requirements == undefined || requirements_pass(offer.requirements))
        {
            requests.push(offer.quest);
        }
    }

    //
    var keys = REQUEST_BOARD_ENTRIES.keys();
    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];

        var entry = REQUEST_BOARD_ENTRIES.get(key);

        if !entry.randomly_selected && requirements_pass(entry.requirements) {
            requests.push(key);
        }
    }

    //
    if CALENDAR.time >= days(1) {
        var quantity = fiddle_get("misc/fetch_quests_per_day");
        var keys = ListFromArray(REQUEST_BOARD_ENTRIES.keys());
        keys.shuffle();

        for (var i = 0; i < keys.count(); i++) {
            var key = keys.get(i);
            var entry = REQUEST_BOARD_ENTRIES.get(key);

            //
            //
            if entry.randomly_selected
                && !QUEST_LOG.completed.contains(key)
                && !QUEST_LOG.active.contains_key(key)
                && requirements_pass(entry.requirements)
            {
                requests.push(key);

                if requests.count() >= quantity {
                    break;
                }
            }
        }
    }

    //
    requests.retain(function(v) {
        return !QUEST_LOG.completed.contains(v) && !QUEST_LOG.active.contains_key(v);
    });

    randomize();
    return requests;
}
