object_create(
    "obj_mill_menu",
    object_reserve("par_crafting_table"),
    {
        sprite_index: spr_mill_interactable_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.shadow_sprite = SHADOW_DICTIONARY.get(self.sprite_index);

            self.fiddle_name = "interaction/milling_offset";
            self.large_icon = spr_ui_bark_icon_mill;
            self.small_icon = spr_ui_bark_icon_mill_small;

            self.menu = Menu.Crafting;

            self.can_use = function() {
                return true;
            }


            self.register_interaction(
                InputId.Interact,
                "misc_local/use",
                function() {
                    var menu = spawn_crafting_menu(MILLING_UI_DATA);
                    menu.object_coordinates.x = obj_ari.x;
                    menu.object_coordinates.y = obj_ari.y;
                },
                function() {
                    //
                    //
                    return self.can_use()
                        && obj_ari.is_mounted() == false
                        && ARI.held_animal_id == undefined;
                },
            );
            depth = get_instance_depth(y);
        },
    }
);
