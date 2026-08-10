object_create(
    "obj_tower_resonator",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_bell_tower_f1_crystal_resonator_main,
        create: function() {
            event_inherit(ObjectEvent.Create);

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            function spawn_menu() {
                self.mcp = new MultipleChoicePopup("misc_local/bell_tower_resonator");

                self.mcp.option("misc_local/select_town_song", function() {
                    var popup = song_selection_ui(function(song) {
                        ARI.song_overrides[LocationId.Town] = song;
                        MUSIC_PLAYER.refresh();
                    });

                    popup.close_callback = self.spawn_menu;
                });
                self.mcp.buttons.last().add_width(40);

                self.mcp.option("misc_local/select_bell_sound", function() {
                    var pop = bell_sound_selection_ui(function(bell_sound) {
                        ARI.bell_sound = bell_sound;
                    });
                    pop.close_callback = self.spawn_menu;
                });
                self.mcp.buttons.last().add_width(40);

                self.mcp.option("misc_local/close", function() {});
                self.mcp.buttons.last().add_width(40);
            }

            self.register_interaction(
                InputId.Interact,
                "misc_local/use",
                function() {
                    self.spawn_menu();
                }
            );

            var fiddle_data = fiddle_get("interaction/tower_resonator_offset");
            depth = get_instance_depth(y);

            self.bounce_x_offset = fiddle_data[0];
            self.bounce_y_offset = fiddle_data[1];
        },
        draw_end: function() {
            self.bouncer.status = InteractBounceStatus.Distant;

            if game_paused() {
                return;
            }

            self.bouncer.alpha = BARK_MIN_ALPHA;

            var is_being_selected = self.bouncer.update();

            if is_being_selected {
                draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_music, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
            } else {
                draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_music_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
            }
        },
    }
);
