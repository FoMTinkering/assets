object_create(
    "obj_summit_background",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            function get_daytime() {
                var daytime = undefined;

                if CLOCK.hour() >= fiddle_get("summit/night_start") || CLOCK.hour() < fiddle_get("summit/day_start") {
                    daytime = Daytime.Night;
                } else if CLOCK.hour() >= fiddle_get("summit/dusk_start") {
                    daytime = Daytime.Dusk;
                } else if CLOCK.hour() >= fiddle_get("summit/day_start") {
                    daytime = Daytime.Day;
                }

                if WEATHER.is_inclement() {
                    daytime = Daytime.Weather;
                }

                return daytime;
            }

            function get_daytime_sprite(sprite, daytime) {
                var sprite_name = format("{}_", string_replace(asset_to_string(sprite), "_day", ""));

                if daytime == Daytime.Weather {
                    sprite_name += CALENDAR.season() == Season.Winter ? "snow" : "rain";
                } else {
                    sprite_name += daytime_to_string(daytime);
                }

                return string_to_asset(sprite_name);
            }

            function draw_summit_background(alpha, daytime, daytime_two) {
                var room_center_x = room_width() / 2;
                var camera_center_x = CAMERA.internal_cam_pos.x + CAMERA.view_width / 2;

                var room_center_y = room_height() / 2;
                var camera_center_y = CAMERA.internal_cam_pos.y + CAMERA.view_height / 2 - 100;

                for (var i = 0, c = array_length(self.layers); i < c; i++;) {
                    //
                    for (var j = 0; j < 2; j++) {
                        var temp_alpha = alpha;
                        var temp_daytime = daytime;

                        if j == 0 {
                            temp_alpha = 1;
                            temp_daytime = daytime_two;
                        }

                        var layer_name = self.layers[i];
                        var layer_id = strict_layer_get_id(layer_name);

                        layer_set_visible(layer_name, false);

                        var layer_parallax_x = self.layer_parallax[$ layer_name] == undefined ? 0: self.layer_parallax[$ layer_name].x;
                        var layer_parallax_y = self.layer_parallax[$ layer_name] == undefined ? 0: self.layer_parallax[$ layer_name].y;
                        var parallax_x = (((camera_center_x) + (camera_center_x - room_center_x) * -layer_parallax_x - room_width() / 2) * -1) / 10;
                        var parallax_y = (camera_center_y) + (camera_center_y - room_center_y) * -layer_parallax_y - room_height() / 2;

                        var elements = layer_get_all_assets(layer_id);

                        if !matches(layer_name,"BG_7_WoodsDecals", "BG_6_Woods", "BG_5_Mountains") {
                            var element = elements[0];
                            var sprite = layer_asset_get(element, LayerAssetProperty.Sprite);
                            sprite = get_daytime_sprite(sprite, temp_daytime);
                            var x_offset = 0;
                            if matches(layer_name, "BG_3_HorizonClouds_Back", "BG_4_HorizonClouds_Front") {
                                x_offset = self.cloud_x;
                            }

                            if layer_asset_get(element, LayerAssetProperty.HTiled) {
                                draw_sprite_part(
                                    sprite,
                                    0,
                                    0,
                                    0,
                                    room_width(),
                                    sprite_get_height(sprite),
                                    parallax_x + x_offset,
                                    layer_asset_get(element, LayerAssetProperty.YPos) + parallax_y,
                                    c_white,
                                    temp_alpha,
                                );
                            } else {
                                draw_sprite(
                                    sprite,
                                    0,
                                    layer_asset_get(element, LayerAssetProperty.XPos) + parallax_x,
                                    layer_asset_get(element, LayerAssetProperty.YPos) + parallax_y
                                );
                            }
                        } else {
                            tilemap_tileset(
                                strict_layer_tilemap_get_id(layer_id),
                                string_to_asset(format("tile_summit_landscape_{Season}_{Daytime}", CALENDAR.season(), temp_daytime))
                            );

                            var logical_pixel_parallax_x = floor(parallax_x * DISPLAY.asset_resize()) / DISPLAY.asset_resize();
                            var logical_pixel_parallax_y = floor(parallax_y * DISPLAY.asset_resize()) / DISPLAY.asset_resize();

                            var tilemap_id = strict_layer_tilemap_get_id(layer_id);
                            draw_tilemap(tilemap_id, logical_pixel_parallax_x, logical_pixel_parallax_y, c_white, temp_alpha);
                        }

                        for (var n = 1; n < array_length(elements); n++) {
                            var element = elements[n];
                            var element_sprite = layer_asset_get(element, LayerAssetProperty.Sprite);

                            draw_sprite(
                                get_daytime_sprite(element_sprite, temp_daytime),
                                0,
                                layer_asset_get(element, LayerAssetProperty.XPos) + parallax_x,
                                layer_asset_get(element, LayerAssetProperty.YPos) + parallax_y
                            );
                        }
                    }
                }
            }

            self.layers = fiddle_get("summit/layers");
            self.cloud_speed = 0.025;
            self.cloud_x = 0;
            self.layer_parallax = {};
            self.initial_daytime = get_daytime();
            self.daytime_alpha_swap = 0;
            self.transition_speed = fiddle_get(format("summit/transition_speed_{Daytime}", self.initial_daytime));

            for (var i = 0; i < array_length(self.layers); i++) {
                var layer_name = self.layers[i];
                if matches(layer_name, "Background") {
                    continue;
                }

                self.layer_parallax[$ layer_name] = {
                    x: fiddle_get(format("summit/{}_parallax", string_lower(layer_name))),
                    y: fiddle_get(format("summit/{}_vertical_parallax", string_lower(layer_name)))
                }

                if matches(layer_name,"BG_7_WoodsDecals", "BG_6_Woods", "BG_5_Mountains") {
                    tilemap_tileset(
                        layer_name,
                        string_to_asset(format("tile_summit_landscape_{Season}_{Daytime}", CALENDAR.season(), self.initial_daytime))
                    );
                }
            }

            //
            depth = room_height() * 5;
        },
        draw: function() {
            if !instance_exists(Game) {
                return;
            }

            var daytime = get_daytime();

            if !game_paused() {
                //
                self.cloud_x = (self.cloud_x + self.cloud_speed * 4) % sprite_get_width(spr_summit_clouds_back_day);
            }

            if daytime != self.initial_daytime {
                self.daytime_alpha_swap += self.transition_speed;
                draw_summit_background(self.daytime_alpha_swap, daytime, self.initial_daytime);

                if self.daytime_alpha_swap >= 1 {
                    self.initial_daytime = daytime;
                    self.daytime_alpha_swap = 0;
                }
            } else {
                draw_summit_background(1, daytime, daytime);
            }
        },
    }
);
