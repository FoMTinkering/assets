object_create(
    "obj_door",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_farm_playerhouse_1_door_spring_closed,
        door_hides_on_open: true,
        mask_index: string_to_asset("spr_door_mask"),
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.closed_sprite = spr_farm_playerhouse_1_door_spring_closed;
            self.swing_sprite = spr_farm_playerhouse_1_door_spring_swing;
            self.state = OpenStateId.Closed;
            self.dist = 12;
            self.fade = true;
            self.requests = 0;
            self.light_bottom_offset = Vec2(0, -44);
            self.light_top_offset = Vec2(0, -1);

            //
            self.highlighter.interact_strength = fiddle_get("interaction/highlight/door_strength");

            //
            self.tile_collision_box = Vec4Zero();
            self.closed_sprite = sprite_index;
            self.swing_sprite = string_to_asset(string_replace(asset_to_string(sprite_index), "_closed", "_swing"));
            depth = get_instance_depth(y);

            var padding = sprite_get_width(self.closed_sprite) > 32 ? 12 : 4;
            self.tile_collision_box = Vec4(
                (x - padding) div OBJECT_CELL_SIZE,
                (y - 32) div OBJECT_CELL_SIZE,
                (x + padding) div OBJECT_CELL_SIZE,
                (y - 1) div OBJECT_CELL_SIZE,
            );

            self.sprite_index = self.closed_sprite;
            self.mask_index = spr_mask_door;
            self.floor_sprite = undefined;
            self.doorway_light_bottom = undefined;
            self.doorway_light_top = undefined;
            self.time_alive = 0;
            self.from_room_service = false;

            function clean_assets() {
                if self.floor_sprite != undefined {
                    instance_destroy(self.floor_sprite);
                }

                if self.doorway_light_bottom != undefined {
                    instance_destroy(self.doorway_light_bottom);
                }

                if self.doorway_light_top != undefined {
                    instance_destroy(self.doorway_light_top);
                }
            }

            function setup_floor_shadow(doorway_override) {
                self.clean_assets();

                if distance_to_object(obj_roomtransition) < 32 {
                    var nearest_room_transition_obj = instance_nearest(x, y, obj_roomtransition);

                    if nearest_room_transition_obj.no_door_shadow {
                        return;
                    }
                }

                self.doorway_light_bottom = instance_create_depth(
                    self.x + self.light_bottom_offset.x,
                    self.y + self.light_bottom_offset.y,
                    get_shadow_depth(),
                    obj_assetobject,
                    {
                        image_blend: c_black,
                        image_alpha: 0.5,
                        sprite_index: spr_doorway_light_bottom,
                        do_not_set_depth: true,
                    }
                );

                var light_top_spr = spr_doorway_light_top;
                if matches(self.sprite_index, spr_westernruins_seridia_door_spring_closed, spr_deep_woods_caldarus_door_spring_closed) {
                    light_top_spr = spr_doorway_light_top_short;
                }
                self.doorway_light_top = instance_create_depth(
                    self.x + self.light_top_offset.x,
                    self.y + self.light_top_offset.y,
                    0,
                    obj_assetobject,
                    {
                        image_blend: c_black,
                        image_alpha: 0.5,
                        sprite_index: light_top_spr,
                    }
                );

                if LOCATIONS[CURRENT_LOCATION_ID].outdoor {
                    var doorway_floor;
                    if doorway_override == undefined {
                        var orig_name = asset_to_string(sprite_index);
                        var name = orig_name;
                        name = string_replace(name, "_closed", "");
                        name += "_doorwayfloor_closed";
                        var doorway_floor = try_string_to_asset(name);
                        if doorway_floor == undefined {
                            name = string_replace(name, "_doorwayfloor_closed", "_doorway_floor_closed");
                            doorway_floor = try_string_to_asset(name);
                            if doorway_floor == undefined {
                                warn("Could not find a sprite named {} based on {}. Returning spr_nothing...", name, orig_name);
                                doorway_floor = spr_nothing;
                            }
                        }
                    } else {
                        doorway_floor = doorway_override;
                    }
                    self.floor_sprite = instance_create_layer(x, y, "Instances", obj_assetobject, {
                        sprite_index: doorway_floor,
                        on_floor: true,
                    });
                    self.floor_sprite.sprite_index = doorway_floor;
                }
            }

            function get_wait_time() {
                return self.state == OpenStateId.Open ? 0 : 17;
            }

            function set_collision() {
                for (var i = self.tile_collision_box.x1; i <= self.tile_collision_box.x2; i++) {
                    for (var j = self.tile_collision_box.y1; j <= self.tile_collision_box.y2; j++) {
                        //
                        //
                        //
                        //
                        //
                        var ni = GRID.node_index_for_cell(i, j);
                        var cache = GRID.node_is_room_editor_collision[ni];
                        GRID.node_is_room_editor_collision[ni] = RoomEditorCollision.None;
                        set_collision_on_node(GRID, i, j);
                        GRID.node_is_room_editor_collision[ni] = cache;
                    }
                }
            }

            function remove_collision() {
                for (var i = self.tile_collision_box.x1; i <= self.tile_collision_box.x2; i++) {
                    for (var j = self.tile_collision_box.y1; j <= self.tile_collision_box.y2; j++) {
                        //
                        var ni = GRID.node_index_for_cell(i, j);
                        var cache = GRID.node_is_room_editor_collision[ni];
                        GRID.node_is_room_editor_collision[ni] = RoomEditorCollision.None;
                        remove_collision_on_node(GRID, i, j);
                        GRID.node_is_room_editor_collision[ni] = cache;
                    }
                }
            }

            function request_open(how_long=120) {
                var already_some = self.requests != 0;
                self.requests += 1;
                if !already_some {
                    TANGO.play("SoundEffects/Entrances/DoorWoodOutdoorOpen", x, y);
                    self.state = OpenStateId.Opening;
                    self.sprite_index = self.swing_sprite;
                    self.image_speed = 1;
                    self.image_index = 0;
                }
                new_world_chain(self, CURRENT_LOCATION_ID)
                    .join(LinkId.Timer, how_long)
                    .append(LinkId.Function, function() {
                        self.requests = max(self.requests - 1, 0);
                    })
            }

            register_interaction(
                InputId.Interact,
                "misc_local/use_door",
                function() {
                    self.request_open();
                },
                function() {
                    return self.state == OpenStateId.Closed;
                }
            );
            set_collision();
        },
        step: function() {
            if self.state == OpenStateId.Open
                && self.requests <= 0
                && self.time_alive > 2
                && !non_cutscene_pause()
                && collision_rectangle(
                    self.tile_collision_box.x1 * 8,
                    self.tile_collision_box.y1 * 8,
                    self.tile_collision_box.x2 * 8,
                    self.tile_collision_box.y2 * 8,
                    obj_ari,
                ) == undefined
            {
                var snd = LOCATIONS[CURRENT_LOCATION_ID].outdoor ? "SoundEffects/Entrances/DoorWoodOutdoorClose" : "SoundEffects/Entrances/DoorWoodIndoorClose";
                TANGO.play(snd, x, y);
                self.state = OpenStateId.Closing;
                self.sprite_index = self.swing_sprite;
                self.image_speed = -1;
                self.image_index = sprite_get_number(self.swing_sprite) - 0.01;
            }

            self.time_alive += 1;
        },
        draw: function() {
            var fill_color = make_color_rgb(
                POST_PROCESS.shadow_multiply_color[0],
                POST_PROCESS.shadow_multiply_color[1],
                POST_PROCESS.shadow_multiply_color[2],
            );
            if self.doorway_light_bottom != undefined {
                self.doorway_light_bottom.image_blend = fill_color;
            }
            if self.doorway_light_top != undefined {
                self.doorway_light_top.image_blend = fill_color;
            }
            if self.fade && self.sprite_index == swing_sprite {
                self.image_blend = lerp_color(
                    c_white,
                    fill_color,
                    self.image_index / self.image_number
                );
            }

            event_inherit(ObjectEvent.Draw);
        },
        room_end: function() {
            //
            //
            //
            if instance_exists(Game) {
                set_collision();
            }
        },
        animation_end: function() {
            if sprite_index == swing_sprite {
                if state == OpenStateId.Opening {
                    state = OpenStateId.Open;
                    remove_collision();
                    if door_hides_on_open {
                        sprite_index = undefined;
                    } else {
                        image_speed = 0;
                        image_index = image_number - 1;
                    }
                } else if state == OpenStateId.Closing {
                    state = OpenStateId.Closed;
                    set_collision();
                    sprite_index = closed_sprite;
                }
            }
        },
        destroy: function() {
            self.clean_assets();
        },
    }
);
