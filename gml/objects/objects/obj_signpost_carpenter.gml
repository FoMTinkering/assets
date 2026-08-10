object_create(
    "obj_signpost_carpenter",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_easternroad_carpenter_sign_spring,
        dialogue_name: "",
        create: function() {
            //
            event_inherit(ObjectEvent.Create);

            //
            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            self.full_name = format("Conversations/signposts/{}", self.dialogue_name);

            var output = T2R.fuzzy_search_conversation(NpcId.Caldarus, full_name, ConversationKind.GameplayTriggered);
            assert_eq(output, self.full_name);

            self.register_interaction(
                InputId.Interact,
                "misc_local/read",
                function() {
                    //
                    obj_ari.face_dir(point_direction(obj_ari.x, obj_ari.y, self.x, self.y));
                    obj_ari.set_idle_simple();

                    play_conversation(NpcId.Caldarus, self.full_name);
                },
                function() {
                    return true;
                }
            );

            depth = get_instance_depth(y);

            if instance_exists(Game) && CALENDAR.season() == Season.Winter {
                self.sprite_index = spr_easternroad_carpenter_sign_winter;
            }
        },
    }
);
