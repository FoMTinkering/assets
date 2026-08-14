#macro LETTERS global.__letters
global.__letters = undefined;

function load_letters() {
    var collection = Map();
    var letters = fiddle_get("letters");
    var letter_default = struct_take(letters, "default");
    var valid_keys = struct_get_names(letter_default);
    var keys = struct_get_names(letters);
    for (var i = 0; i < array_length(keys); i++) {
        var letter = letters[$ keys[i]];

        if DEBUG_ASSERTIONS {
            var invalid_field = find_invalid_field(letter, valid_keys);
            if invalid_field != undefined {
                crash("Invalid letter field in {}: {}", keys[i], invalid_field);
            }
        }

        var items = List();
        if letter[$ "items"] != undefined {
            for (var j = 0; j < array_length(letter.items); j++) {
                var letter_content = letter.items[j];
                if letter_content[$ "recipe_scroll"] != undefined {
                    items.push({
                        recipe: string_to_item_id(letter_content.recipe_scroll),
                        listing: Listing.Item(
                            new LiveItem(ItemId.RecipeScroll, string_to_item_id(letter_content.recipe_scroll)),
                        ),
                     });
                } else if letter_content[$ "purse"] != undefined {
                    var purse = new LiveItem(ItemId.Purse);
                    purse.gold_to_gain = letter_content.purse;
                    items.push({
                        item: purse,
                        count: 1,
                        listing: Listing.Item(purse),
                    })
                } else {
                    items.push({
                        item: string_to_item_id(letter_content.item_name),
                        count: letter_content[$ "count"] ?? 1,
                        listing: Listing.Item(
                            string_to_item_id(letter_content.item_name),
                            undefined,
                            letter_content[$ "count"] ?? 1,
                        ),
                    });
                }
            }
        }
        collection.insert(
            keys[i],
            {
                name: keys[i],
                subject: letter.subject_line,
                body_key: letter.local,
                npc_key: letter.npc,
                npc: try_string_to_npc_id(letter.npc),
                can_repeat: letter[$ "can_repeat"] ?? false,
                items: items,
                quest_to_start: letter[$ "quest_to_start"] == undefined ? undefined : CONTENT_REGISTRY.validate_quest(letter[$ "quest_to_start"]),
                quest_to_progress: letter[$ "quest_to_progress"] == undefined ? undefined : CONTENT_REGISTRY.validate_quest(letter[$ "quest_to_progress"]),
                requirements: parse_requirements(letter[$ "requirements"] ?? {}),
            }
        );
    }

    return collection;
}

function Inbox() constructor {
    self.contents = List();

    //
    function contains(name) {
        return self.contents.any(function(e, name) {
            return e.name == name;
        }, name);
    }

    function push_mail(name, items_taken=false, read=false) {
        self.contents.push({
            name: name,
            items_taken,
            read,
        });
    }

    //
    function has_unread_mail() {
        return self.contents.any(function(e) {
            return e.read == false;
        });
    }

    function on_new_day() {
        var keys = LETTERS.keys();

        for (var i = 0; i < array_length(keys); i++) {
            var letter = LETTERS.get(keys[i]);
            if (!self.contains(letter.name) || letter.can_repeat)
                && requirements_pass(letter.requirements)
            {
                self.push_mail(keys[i]);
            }
        }
    }

    serialize = function() {
        var array = [];
        for (var i = 0; i < self.contents.count(); i++) {
            var letter = self.contents.get(i);
            array_push(array, {
                path: letter.name,
                read: letter.read,
                items_taken: letter.items_taken,
            });
        }
        return array;
    }

    deserialize = function(array) {
        for (var i = 0; i < array_length(array); i++) {
            var letter = array[i];
            if LETTERS.contains_key(letter.path) == false {
                if DEBUG_ASSERTIONS {
                    crash("missing letter `{}`", letter.path);
                } else {
                    error("missing letter `{}`", letter.path);
                }
                continue;
            }
            self.push_mail(letter.path, letter.items_taken, letter.read);
        }
    }
}
