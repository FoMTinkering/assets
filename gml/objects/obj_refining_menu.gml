object_create(
    "obj_refining_menu",
    object_reserve("par_crafting_table"),
    {
        sprite_index: spr_narrows_mines_entry_stone_refinery_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.shadow_sprite = SHADOW_DICTIONARY.get(self.sprite_index);

            self.fiddle_name = "interaction/refining_offset";
            self.large_icon = spr_ui_bark_icon_refine;
            self.small_icon = spr_ui_bark_icon_refine_small;

            self.menu = Menu.Crafting;

            self.can_use = function() {
                return true;
            }

            self.register_interaction(
                InputId.Interact,
                "misc_local/use",
                function() {
                    var menu = spawn_crafting_menu(REFINING_UI_DATA, 536, 140);
                    menu.object_coordinates.x = obj_ari.x;
                    menu.object_coordinates.y = obj_ari.y;
                },
                function() {
                    return !TAXI.is_traveling()
                        && self.can_use()
                        && obj_ari.is_mounted() == false
                        && ARI.held_animal_id == undefined;
                }
            );
            depth = get_instance_depth(y);
        },
    }
);
