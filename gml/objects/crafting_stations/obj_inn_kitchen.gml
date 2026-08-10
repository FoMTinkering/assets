object_create(
    "obj_inn_kitchen",
    object_reserve("par_crafting_table"),
    {
        sprite_index: spr_inn_kitchen_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            if !world_mod_enabled(WorldMod.InnInterior) {
                self.sprite_index = spr_inn_kitchen_spring_broken;
            }
            self.shadow_sprite = SHADOW_DICTIONARY.get(self.sprite_index);

            self.fiddle_name = "interaction/inn_kitchen_offset";
            self.large_icon = spr_ui_bark_icon_cooking;
            self.small_icon = spr_ui_bark_icon_cooking_small;

            self.menu = Menu.Crafting;

            self.can_use = function() {
                return true;
            }

            self.register_interaction(
                InputId.Interact,
                "misc_local/use",
                function() {
                var kitchen = REQ_CHECK[Requirement.RepairedInn]() ? ObjectId.AdeptKitchen : ObjectId.BeginnerKitchen;
                    var menu = spawn_crafting_menu(COOKING_UI_DATA, obj_ari.x, obj_ari.y, kitchen);
                    menu.object_coordinates.x = x;
                    menu.object_coordinates.y = y;
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
