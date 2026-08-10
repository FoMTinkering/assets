object_create(
    "obj_eiland_statue",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_museum_entryhall_armor_stand_spring_stage0,
        create: function() {
            event_inherit(ObjectEvent.Create);
            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: spr_museum_entryhall_armor_stand_shadow,
            });

            if requirements_pass(Requirement.HasDragonswornArmor) {
                self.register_interaction(
                    InputId.Interact,
                    "misc_local/inspect",
                    function() {
                        play_conversation_from_path(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.ReplicaStatue]);
                    }
                );
            }
        },
        step: function() {
            if requirements_pass(Requirement.HasDragonswornArmor) {
                sprite_index = spr_museum_entryhall_armor_stand_spring_stage4;
            } else if requirements_pass(Requirement.EilandArmorFour) {
                sprite_index = spr_museum_entryhall_armor_stand_spring_stage4;
            } else if requirements_pass(Requirement.EilandArmorThree) {
                sprite_index = spr_museum_entryhall_armor_stand_spring_stage3;
            } else if requirements_pass(Requirement.EilandArmorTwo) {
                sprite_index = spr_museum_entryhall_armor_stand_spring_stage2;
            } else if requirements_pass(Requirement.EilandArmorOne) {
                sprite_index = spr_museum_entryhall_armor_stand_spring_stage1;
            }
        },
        draw: function() {
            draw_self();
            depth = get_instance_depth(y);
        },
    }
);
