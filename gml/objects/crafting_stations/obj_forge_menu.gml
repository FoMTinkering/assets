object_create(
    "obj_forge_menu",
    object_reserve("par_crafting_table"),
    {
        sprite_index: spr_blacksmith_anvil_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.shadow_sprite = SHADOW_DICTIONARY.get(self.sprite_index);

            self.fiddle_name = "interaction/forge_offset";
            self.large_icon = spr_ui_bark_icon_crafting;
            self.small_icon = spr_ui_bark_icon_crafting_small;

            self.menu = Menu.Crafting;

            self.can_use = function() {
                return true;
            }

            self.register_interaction(
                InputId.Interact,
                "misc_local/use",
                function() {
                    var tp = trellis_point("town/anvil");
                    spawn_crafting_menu(BLACKSMITHING_UI_DATA, tp.x, tp.y);
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
