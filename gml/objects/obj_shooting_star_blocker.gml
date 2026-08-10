object_create(
    "obj_shooting_star_blocker",
    undefined,
    {
        sprite_index: spr_transition,
        visible: false,
        create: function() {
            self.popup = undefined;

            if !FESTIVALS[FestivalId.ShootingStar].is_today() {
                instance_destroy();
            }
        },
        step_end: function() {
            if game_paused() {
                return;
            }

            var player_state = obj_ari.fsm.current_state_id();

            if self.popup != undefined && ANCHOR.get_menu(Menu.Popup) == undefined && !TAXI.is_traveling() {
                var target_pos = trellis_point("narrows/shooting_star_reset");
                if !try_path_ari_to(target_pos) {
                    obj_ari.x = target_pos.x;
                    obj_ari.y = target_pos.y;
                }
                self.popup = undefined;
                return;
            }

            if overlap_instance_any(self.x, self.y, obj_ari)
                && (player_state == PlayerState.Default || player_state == PlayerState.MountDefault)
                && !TAXI.is_traveling()
            {
                if CLOCK.time < NIGHT_TIME {
                    play_conversation_from_path(
                        NpcId.Caldarus,
                        GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.ShootingStarNotYet],
                        function() {
                            var target_pos = trellis_point("narrows/shooting_star_reset");
                            if !try_path_ari_to(target_pos) {
                                obj_ari.x = target_pos.x;
                                obj_ari.y = target_pos.y;
                            }
                        }
                    );
                } else {
                    self.popup = popup_creator("misc_local/go_to_festival", "misc_local/go_to_shooting_star_confirmation");
                    self.popup.create_button("misc_local/not_yet");
                    self.popup.create_button("misc_local/yes", function() {
                        instance_nearest(self.x, self.y, obj_roomtransition).transition();
                    });
                    self.popup.spawn();
                }
            }
        },
    }
);
