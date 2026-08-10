object_create(
    "obj_incubator",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_coop_incubator_empty_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);
            parent_data = undefined;

            self.register_interaction(
                InputId.Interact,
                "misc_local/check_egg",
                function() {
                    //
                    var mother = find_animal(self.parent_data.mother, true);
                    var father = find_animal(self.parent_data.father, true);

                    //
                    assert(!mother.is_pet);
                    assert(!father.is_pet);

                    BREEDING_ANIMAL_CTX.animal_name = mother.name;
                    BREEDING_ANIMAL_CTX.breeding_partner = father.name;
                    var convo = self.parent_data.almost_done ? GpTriggeredConversation.IncubationShort : GpTriggeredConversation.IncubationLong;
                    play_conversation_from_path(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[convo], function() {
                        BREEDING_ANIMAL_CTX.animal_name = undefined;
                        BREEDING_ANIMAL_CTX.breeding_partner = undefined;
                    });
                },
                function() {
                    return self.parent_data != undefined;
                },
            );

            depth = get_instance_depth(y);
        },
    }
);
