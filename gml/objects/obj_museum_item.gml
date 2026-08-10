object_create(
    "obj_museum_item",
    undefined,
    {
        sprite_index: spr_nothing,
        key: "",
        create: function() {
            var split = string_split(self.key, "/");
            var wing = string_to_museum_wing(split[0]);
            var set = split[1];
            var numeral = real(split[2]);
            var items = MUSEUM_DATA.data[wing].sets.get(set).items;

            if numeral >= array_length(items) {
                instance_destroy();
                return;
            }

            var item = items[numeral];

            if !MUSEUM_PROGRESS[item] {
                instance_destroy();
                return;
            }
            self.sprite_index = ITEM_PROTOTYPES[item].icon_sprite;
            self.depth = -self.y - 12;
            self.x += 8;
            self.y += 8;

            if wing == MuseumWing.Fish && set == "legendary" {
                self.x += 10;
            }
        }
    }
);
