object_create(
    "obj_festival_post",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_town_flag_post_default_spring,
        create: function() {
            //
            event_inherit(ObjectEvent.Create);

            if instance_exists(Game) {
                var festival_day = false;
                for (var i = 0; i < FestivalId.LEN; i++) {
                    var f = FESTIVALS[i];
                    if f.is_today() && f.prototype.implemented {
                        self.sprite_index = f.prototype.festival_post_sprite;
                        self.full_name = GAMEPLAY_CONVERSATIONS[f.prototype.festival_post_line];
                        festival_day = true;
                        break;
                    }
                }

                if festival_day == false {
                    if CALENDAR.day_type() == Day.Saturday && requirements_pass(Requirement.SaturdayMarketUnlocked) {
                        self.sprite_index = CALENDAR.season() == Season.Winter ? spr_town_flag_post_saturday_market_winter : spr_town_flag_post_saturday_market_spring;
                        self.full_name = GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.SaturdayMarketFestivalPost];
                    } else {
                        self.sprite_index = CALENDAR.season() == Season.Winter ? spr_town_flag_post_default_winter : spr_town_flag_post_default_spring;
                        self.full_name = GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.NothingFestivalPost];
                    }
                }
            } else {
                self.sprite_index = spr_town_flag_post_default_spring;
                //
                self.full_name = undefined;
            }

            //
            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

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
        },
    }
);
