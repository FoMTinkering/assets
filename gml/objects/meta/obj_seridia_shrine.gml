object_create(
    "obj_seridia_shrine",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_dungeon_mines_dragonstatue_biome_1_broken_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);
            depth = get_instance_depth(y);

            self.register_interaction(
                InputId.SecondaryInteract,
                "misc_local/use_shrine",
                function() {
                    ANCHOR.spawn_menu(Menu.DragonShrine, ShrineMenuVariant.Seridia);
                },
            );

            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    //
                    obj_ari.face_dir(point_direction(obj_ari.x, obj_ari.y, self.x, self.y));
                    obj_ari.set_idle_simple();

                    play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectSeridiaStatue]);
                },
                function() {
                    //
                    return SCREEN_FADER.is_in();
                }
            );


            mask_index = spr_farm_dragonstatue_broken_spring;

            var fiddle_data = fiddle_get("interaction/dragon_shrine_offset");
            self.offset_x = fiddle_data[0];
            self.offset_y = fiddle_data[1];

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });
        },
        draw_end: function() {
            self.bouncer.status = InteractBounceStatus.Distant;

            //
            if has_flag(PAUSE_STATUS, PauseStatus.MENU)
                || has_flag(PAUSE_STATUS, PauseStatus.CUTSCENE)
            {
                return;
            }

            self.bouncer.alpha = approach(self.bouncer.alpha, BARK_MIN_ALPHA, BARK_FADE_SPEED);
            var is_being_selected = self.bouncer.update();

            if is_being_selected {
                draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_essence, 0, x + offset_x, y + offset_y + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            } else {
                draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_essence_small, 0, x + offset_x, y + offset_y + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
            }
        },
    }
);
