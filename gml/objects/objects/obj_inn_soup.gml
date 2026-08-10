object_create(
    "obj_inn_soup",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_inn_fireplacefire_spring_on,
        create: function() {
            event_inherit(ObjectEvent.Create);
            if !world_mod_enabled(WorldMod.InnInterior) {
                self.sprite_index = spr_inn_fireplacefire_spring_broken_on;
                self.soup_item = ItemId.SoupOfTheDay;
            } else {
                self.soup_item = ItemId.SoupOfTheDayGold;
            }

            self.register_interaction(
                InputId.Interact,
                "misc_local/interact",
                function() {
                    //
                    //
                    callback = function(driver) {
                        //
                        if driver.prompt_index_selected == 0 {
                            ATE_SOUP = true;
                            use_item_fast(self.soup_item);
                        }
                    };
                    args = [];


                    //
                    obj_ari.face_dir(90);
                    obj_ari.set_idle_simple();

                    //
                    play_conversation_from_path(NpcId.Hemlock, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InnSoup], callback, args);
                },
                function() {
                    return !ATE_SOUP;
                },
            );
            depth = get_instance_depth(y, -11);
        },
    }
);
