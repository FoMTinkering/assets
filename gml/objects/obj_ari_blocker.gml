object_create(
    "obj_ari_blocker",
    undefined,
    {
        sprite_index: spr_transition,
        gameplay_conversation: "",
        trellis_point: "",
        visible: false,
        create: function() {
            self.popup = undefined;
            self.gameplay_conversation = string_to_gp_triggered_conversation(self.gameplay_conversation);
        },
        step_end: function() {
            if game_paused() {
                return;
            }

            var player_state = obj_ari.fsm.current_state_id();

            if self.popup != undefined && ANCHOR.get_menu(Menu.Popup) == undefined && !TAXI.is_traveling() {
                var tp_key = format("{LocationId}/{}", CURRENT_LOCATION_ID, self.trellis_point);
                var target_pos = trellis_point(tp_key);
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
                play_conversation_from_path(
                    NpcId.Caldarus,
                    GAMEPLAY_CONVERSATIONS[self.gameplay_conversation],
                    function() {
                        send_ari_back(format("{LocationId}/{}", CURRENT_LOCATION_ID, self.trellis_point));
                });
            }
        },
    }
);
