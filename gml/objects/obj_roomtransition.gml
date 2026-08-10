object_create(
    "obj_roomtransition",
    undefined,
    {
        sprite_index: spr_transition,
        ari_can_use: true,
        destination_id: "farm",
        freeze_player: false,
        home_upgrade_key: HomeUpgrade.Small,
        no_door_shadow: false,
        override_depth: "",
        play_stairs_sound: false,
        player_direction: DirectionAngle.Up,
        spd_multiplier: 1.0,
        specific_key: "",
        visible: false,
        create: function() {
            self.dyn_index = undefined;
            self.tileset = undefined;
            self.destination_id = string_to_location_id(self.destination_id);

            function transition() {
                if !TAXI.is_traveling() {

                    if self.destination_id == LocationId.VoidSeal {
                         TANGO.play("SoundEffects/Entrances/VoidPortalEnter");
                    }

                    var itin;
                    if is_dungeon_room(room()) && !matches(self.destination_id, LocationId.VoidSeal, LocationId.RuinsSeal) {
                        if self.player_direction == DirectionAngle.Down {
                            var pos = trellis_point("mines_entry/dungeon entry");
                            goto_location_id(LocationId.MinesEntry).set_exact_position(pos.x, pos.y);
                        } else {
                            DUNGEON_RUNNER.proceed("descended");
                        }
                        return;
                    } else if self.destination_id == LocationId.RuinsSeal && CURRENT_LOCATION_ID == LocationId.VoidSeal {
                        var pos = trellis_point("ruins_seal/rs1_void");
                        itin = goto_location_id(LocationId.RuinsSeal).set_exact_position(pos.x, pos.y);
                    } else if self.dyn_index != undefined {
                        itin = goto_dynamic_location(self.dyn_index);
                    } else {
                        itin = goto_location_id(self.destination_id);
                    }

                    if self.specific_key != "" {
                        itin.set_specific_location_tag(self.specific_key);
                    }

                    //
                    if self.destination_id == LocationId.PlayerHome && room() == rm_farm {
                        itin.set_specific_location_tag(DECOR.player_home_room_transition());
                    }

                    //
                    if self.destination_id == LocationId.Farm && room() == rm_farmhouse {
                        itin.set_specific_location_tag("house");
                    }

                    if string_length(self.override_depth) != 0 && instance_exists(obj_ari) {
                        obj_ari.fsm.blackboard.insert(
                            "override_depth",
                            room_data_layer_depth(room(), self.override_depth)
                        );
                    }

                    var door_here = instance_exists(obj_door) && distance_to_object(obj_door) < 32;

                    itin.set_arrival_callback(function(play_door_noise, play_stairs_sound, should_be_mounted, destination_id, tileset) {
                        //
                        //
                        if play_door_noise == false {
                            with obj_ari {
                                var external_door = instance_exists(obj_door) && distance_to_object(obj_door) < 32;

                                if external_door {
                                    var door = instance_nearest(x, y, obj_door);

                                    //
                                    door.state = OpenStateId.Open;
                                    door.requests = 0;
                                }
                            }
                        }

                        if play_door_noise {
                            var snd = LOCATIONS[CURRENT_LOCATION_ID].outdoor ? "SoundEffects/Entrances/DoorWoodOutdoorClose" : "SoundEffects/Entrances/DoorWoodIndoorClose";
                            TANGO.play(snd, obj_ari.x, obj_ari.y);
                        }

                        if play_stairs_sound {
                            TANGO.play("SoundEffects/Entrances/StairsTransition", obj_ari.x, obj_ari.y);
                        }

                        if should_be_mounted {
                            obj_ari.fsm.change_state(PlayerState.MountDefault);
                        }

                        if destination_id == LocationId.SmallGreenhouse || destination_id == LocationId.LargeGreenhouse {
                            tilemap_tileset(strict_layer_tilemap_get_id("Level_0_Walls"), tileset);
                            tilemap_tileset(strict_layer_tilemap_get_id("Level_1_Ceiling"), tileset);
                            tilemap_tileset(strict_layer_tilemap_get_id("Level_0_Floor_A"), tileset);
                        }

                        if TAXI.location_last == LocationId.VoidSeal && CURRENT_LOCATION_ID == LocationId.RuinsSeal {
                            //
                            obj_ari.face_dir(cardinal_to_angle(Cardinal.South));
                        }
                    }, [door_here, self.play_stairs_sound, obj_ari.is_mounted(), self.destination_id, self.tileset])

                    return true;
                }
                return false;
            }

            function get_center_pos() {
                return Vec2(
                    self.x + (sprite_get_width(self.sprite_index) * self.image_xscale) / 2,
                    self.y + (sprite_get_height(self.sprite_index) * self.image_yscale) / 2,
                );
            }
        },
    }
);
