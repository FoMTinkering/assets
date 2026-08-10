#macro WEATHER_PROTOTYPES global.__weather_prototypes
WEATHER_PROTOTYPES = undefined;

#macro WEATHER_COUNTS global.__weather_counts
WEATHER_COUNTS = undefined;

function load_weather() {
    var collection = array_create(Weather.LEN, undefined);
    var weather_data = fiddle_get("weather");
    var weather_default = weather_data[$ "default"];
    for (var i = 0; i < Weather.LEN; i++) {
        var weather = clone_value(weather_default);
        patch_object(weather_data[$ weather_to_string(i)], weather);
        filter_toml_nulls(weather);

        var music = array_create(Season.LEN, undefined);
        if weather.music != undefined {
            var default_track = is_string(weather.music) ? weather.music : undefined;
            music[Season.Spring] = weather.music[$ "spring"] ?? default_track;
            music[Season.Summer] = weather.music[$ "summer"] ?? default_track;
            music[Season.Fall] = weather.music[$ "fall"] ?? default_track;
            music[Season.Winter] = weather.music[$ "winter"] ?? default_track;
        }
        weather.music = music;

        collection[i] = weather;
    }
    return collection;
}

function load_weather_counts() {
    var output = array_create_ext(Season.LEN, function() {
        return array_create(ForecastGroup.LEN, undefined);
    });

    for (var season = 0; season < Season.LEN; season++) {
        output[season][ForecastGroup.Inclement] = fiddle_deserialize_vec2(fiddle_get(format("weather/seasonal_counts/{Season}/inclement", season)));
        output[season][ForecastGroup.Special] = fiddle_deserialize_vec2(fiddle_get(format("weather/seasonal_counts/{Season}/special", season)));
    }

    return output;
}

#macro WEATHER global.__weather
WEATHER = undefined;

function WeatherManager() constructor {
    self.forecast = undefined;
    self.weather = undefined;
    self.atmosphere = undefined;
    self.under_spell = false;
    self.spell_timer = undefined;

    function on_new_day() {
        self.under_spell = false;
        self.spell_timer = undefined;
        self.set_weather(self.forecast[CALENDAR.day()]);
    }

    function is_inclement() {
        return matches(self.weather, Weather.Inclement, Weather.HeavyInclement);
    }

    function stop_atmosphere_sounds() {
        if self.atmosphere != undefined && self.atmosphere[$ "sound_instances"] != undefined {
            apply_func(self.atmosphere.sound_instances, function(v) {
                v.force_stop();
            });
        }
    }

    function set_atmosphere(atmosphere_id) {
        self.stop_atmosphere_sounds();

        if atmosphere_id == undefined {
            self.atmosphere = undefined;
            return;
        }
        var func = atmosphere_function(atmosphere_id);
        self.atmosphere = func();
    }

	function set_weather(weather, override_atmosphere) {
        self.weather = weather;
		var atmosphere = override_atmosphere == undefined
            ? weather_to_atmosphere(weather, CALENDAR.time)
            : override_atmosphere;

        if matches(weather, Weather.Inclement, Weather.HeavyInclement) {
            if !self.under_spell {
                water_all(GRIDS[LocationId.Farm]);
            } else {
                water_all(GRID);
            }
        }

        self.set_atmosphere(atmosphere);
	}

	function on_room_start() {
		if self.under_spell {
            self.under_spell = false;
            self.spell_timer = undefined;
            self.set_weather(self.forecast[CALENDAR.day()]);
		}

        if self.atmosphere != undefined && self.atmosphere[$ "on_room_start"] != undefined {
            self.atmosphere.on_room_start();
        }
	}

    function on_draw() {
        if self.under_spell && self.spell_timer != undefined && self.spell_timer <= 0 {
            self.under_spell = false;
            self.spell_timer = undefined;
            self.set_weather(self.forecast[CALENDAR.day()]);
        }

        var location_can_draw = LOCATIONS[CURRENT_LOCATION_ID].outdoor
            || (self.under_spell && is_rain_spell_target(CURRENT_LOCATION_ID))

        if self.atmosphere == undefined || location_can_draw == false {
            return;
        }

        if matches(self.atmosphere.id, Atmosphere.Rain, Atmosphere.Storm) {
            gpu_set_srgb_blending(false);
            var modifier = 1;
            if self.spell_timer != undefined {
                modifier = min(self.spell_timer / fiddle_get("spells/summon_rain/indoor_fade_length"), 1);
                self.spell_timer -= 1;
            }
            var xx = CAMERA.internal_cam_pos.x;
            var yy = CAMERA.internal_cam_pos.y;

            gpu_set_extra(UberShaderKind.Light);
            draw_sprite_ext(spr_pixel, 0, xx, yy, CAMERA.view_width, CAMERA.view_height, 0, make_color_rgb(12, 100, 85), 0.40 * modifier);
            gpu_reset_extra();

            gpu_set_blendmode_ext(bm_src_alpha, bm_one);
            draw_atmosphere_particles(self.atmosphere, modifier, make_color_rgb(69, 144, 142));
            gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);

            var droplets_needed = floor((array_length(self.atmosphere.particles) / 12) * modifier);
            if SETTINGS.get("weather_strength") == "low" || MIST.is_running() {
                droplets_needed /= 2;
            }
            if CURRENT_LOCATION_ID == LocationId.Summit {
                droplets_needed = 0;
            }

            while instance_number(obj_rain_droplet) < droplets_needed {
                instance_create_depth(0, 0, 0, obj_rain_droplet);
            }
            while instance_number(obj_rain_droplet) > droplets_needed {
                var inst = instance_find(obj_rain_droplet, irandom(instance_number(obj_rain_droplet) - 1));
                instance_destroy(inst);
            }

            if self.atmosphere.lightning != undefined && !MIST.running && !is_dungeon_room(room()) {
                self.atmosphere.lightning.timer -= 1;
                if self.atmosphere.lightning.timer <= 0 {
                    if !LOCATIONS[CURRENT_LOCATION_ID].outdoor {
                        TANGO.play("Ambience/IndoorThunder");
                    } else if irandom(1) == 0 {
                        TANGO.play("Ambience/OutdoorThunderFar");
                    } else {
                        TANGO.play("Ambience/OutdoorThunderClose");
                        self.atmosphere.lightning.current = 30;
                        self.atmosphere.lightning.power = random_range(0.75, 1.0);

                        var xx = irandom_range(CAMERA.cam_pos.x - 100, CAMERA.right() + 100);
                        var yy = irandom_range(CAMERA.cam_pos.y - 100, CAMERA.bottom());
                        instance_create_depth(xx, yy, floor(-yy), obj_lightning);
                    }

                    self.atmosphere.lightning.timer = irandom_range(
                        self.atmosphere.lightning.timer_min,
                        self.atmosphere.lightning.timer_max,
                    );
                }

                if self.atmosphere.lightning.current > 0 {
                    var alpha = SETTINGS.get("screen_flash")
                        ? (min(self.atmosphere.lightning.current, 20) / 30) * self.atmosphere.lightning.power
                        : 0;

                    gpu_set_blendmode_ext(bm_src_alpha, bm_one);
                    draw_sprite_ext(spr_pixel, 0, xx, yy, CAMERA.view_width, CAMERA.view_height, 0, c_white, alpha);
                    gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);

                    self.atmosphere.lightning.current -= 1;
                }
            }

            gpu_set_srgb_blending(true);
        } else if self.atmosphere.id != Atmosphere.HighClouds {
            draw_atmosphere_particles(self.atmosphere);
        }
    }

    function on_draw_gui() {
        if self.atmosphere == undefined
            || !matches(self.atmosphere.id, Atmosphere.HighClouds, Atmosphere.Petals, Atmosphere.Leaves, Atmosphere.Rain, Atmosphere.Storm)
            || LOCATIONS[CURRENT_LOCATION_ID].outdoor == false
            || CURRENT_LOCATION_ID == LocationId.Summit
        {
            return;
        }

        if self.atmosphere.id == Atmosphere.HighClouds
            || self.atmosphere.id == Atmosphere.Petals
            || self.atmosphere.id == Atmosphere.Leaves
        {
            if CURRENT_LOCATION_ID == LocationId.DeepWoods {
                return;
            }

            var fade_in_start = fiddle_get("weather/high_cloud/fade_in_start");
            fade_in_start = hours(fade_in_start[0]) + minutes(fade_in_start[1]);

            var fade_in_end = fiddle_get("weather/high_cloud/fade_in_end");
            fade_in_end = hours(fade_in_end[0]) + minutes(fade_in_end[1]);

            var fade_out_start = fiddle_get("weather/high_cloud/fade_out_start");
            fade_out_start = hours(fade_out_start[0]) + minutes(fade_out_start[1]);

            var fade_out_end = fiddle_get("weather/high_cloud/fade_out_end");
            fade_out_end = hours(fade_out_end[0]) + minutes(fade_out_end[1]);

            var scalar = 1;
            if CLOCK.time < fade_in_end {
                scalar = inverse_lerp(CLOCK.time, fade_in_end, fade_in_start);
            } else if CLOCK.time >= fade_out_start {
                scalar = 1.0 - inverse_lerp(CLOCK.time, fade_out_end, fade_out_start);
            }
            var opacity = fiddle_get("weather/high_cloud/opacity") * clamp(scalar, 0, 1);
            if opacity < 0.001 {
                return;
            }

            gpu_set_stencil_operation(StencilOperation.Replace);
            gpu_set_stencil_test(cmpfunc_greater, stencil_increment());

            var shadow_color = make_color_rgb(
                round(255 * POST_PROCESS.shadow_multiply_color[0] * opacity),
                round(255 * POST_PROCESS.shadow_multiply_color[1] * opacity),
                round(255 * POST_PROCESS.shadow_multiply_color[2] * opacity),
            );
            var scale = DISPLAY.asset_resize();

            for (var i = 0; i < array_length(self.atmosphere.clouds); i++) {
                var part = self.atmosphere.clouds[i];
                part.x += lengthdir_x(part.speed, part.angle);
                part.y += lengthdir_y(part.speed, part.angle);

                var draw_x = wrap(part.x, room_width() * (1.0 / dcos(part.angle)), -150) - CAMERA.left();
                var draw_y = wrap(part.y, room_height() * (1.0 / dsin(part.angle)), -100) - CAMERA.top();

                draw_sprite_ext(
                    part.sprite,
                    part.index,
                    draw_x * scale,
                    draw_y * scale,
                    scale,
                    scale,
                    0,
                    shadow_color,
                    opacity,
                );
            }

            gpu_disable_stencil();

            return;
        }

        gpu_set_stencil_operation(StencilOperation.Replace);
        gpu_set_stencil_test(cmpfunc_greater, stencil_increment());
        
        gpu_set_color_write(false);
        for (var i = 0; i < array_length(self.atmosphere.clouds); i++) {
            var part = self.atmosphere.clouds[i];

            var scale = DISPLAY.asset_resize();

            part.x += lengthdir_x(part.speed, part.angle);
            part.y += lengthdir_y(part.speed, part.angle);

            var draw_x = part.x - CAMERA.left();
            var draw_y = part.y - CAMERA.top();

            draw_sprite_ext(
                part.sprite,
                part.index,
                draw_x * scale,
                draw_y * scale,
                scale,
                scale,
                0,
                c_white,
                1,
            );
        }
        gpu_set_color_write(true);
        
        gpu_set_srgb_blending(false);
        var output_size = window_get_output_dimensions();
        draw_sprite_ext(
            spr_pixel,
            0,
            0,
            0,
            output_size[0],
            output_size[1],
            0,
			make_color_rgb(12, 30, 30),
			0.1,
        );
        gpu_set_srgb_blending(true);
        gpu_disable_stencil();
    }

    function serialize() {
        return {
            forecast: array_map(self.forecast, weather_to_string),
        }
    }

    function deserialize(struct) {
        self.forecast = array_map(struct.forecast, string_to_weather);
    }

}

#macro ATMOS_PADDING 50

function atmosphere_function(atmosphere) {
    switch atmosphere {
        case Atmosphere.HighClouds: return high_clouds;
        case Atmosphere.Rain: return rain;
        case Atmosphere.Storm: return function() {
            return rain(true);
        };
        case Atmosphere.Petals: return petals;
        case Atmosphere.Leaves: return leaves;
        case Atmosphere.Snow: return snow;
        case Atmosphere.Blizzard: return function() {
            return snow(true);
        };
        default: impossible("Unexpected Atmosphere: {Atmosphere}", atmosphere);
    }
}

function rain(is_storm=false) {
    var range = Vec2(20, 40);
    if SETTINGS.get("weather_strength") == "none" {
        return undefined;
    } else if SETTINGS.get("weather_strength") == "low" || MIST.is_running() {
        range = Vec2(50, 80);
    }
    var points = poisson_points(
        CAMERA.view_width + ATMOS_PADDING * 2,
        CAMERA.view_height + ATMOS_PADDING * 2,
        is_storm ? range.x : range.y,
    );

    var particles = apply_func(
        points,
        function(v) {
            return {
                x: v[0],
                y: v[1],
                angle: random_range(300, 320),
                speed: irandom_range(3, 6),
                anim_speed: 0,
                index: irandom(sprite_get_number(spr_rain_drop) - 1),
                sprite: spr_rain_drop,
            };
        }
    );

    var atmos =  {
        id: is_storm ? Atmosphere.Storm : Atmosphere.Rain,
        particles,
        start_offset: CAMERA.cam_pos.clone(),
        sound_instances: [],
        lightning: !is_storm ? undefined : {
            current: 0,
            power: 0,
            timer: irandom_range(600, 1200),
            timer_max: 60 * 20,
            timer_min: 60 * 10,
        },
    };

    atmos.on_room_start = method(atmos, function() {
        for (var i = 0; i < array_length(self.sound_instances); i++) {
            self.sound_instances[i].force_stop();
        }
        self.sound_instances = [];
        var is_outdoor = LOCATIONS[CURRENT_LOCATION_ID].outdoor;
        if is_outdoor || WEATHER.under_spell {
            array_push(self.sound_instances, new SoundInstanceController(TANGO.play("Ambience/MildRain")));
            if self.id == Atmosphere.Storm {
                array_push(self.sound_instances, new SoundInstanceController(TANGO.play("Ambience/HardRainBase")));
            }
        } else if !is_dungeon_room(room()) && CURRENT_LOCATION_ID != LocationId.MinesEntry {
            array_push(self.sound_instances, new SoundInstanceController(TANGO.play("Ambience/IndoorRain")));
        }

        var points = poisson_points(
            room_width(),
            room_height(),
            200,
        );

        self.clouds = apply_func(
            points,
            function(v) {
                return {
                    x: v[0],
                    y: v[1],
                    angle: 0,
                    speed: 0.05,
                    anim_speed: 0,
                    index: irandom(sprite_get_number(spr_sky_holes) - 1),
                    sprite: spr_sky_holes,
                }
            }
        );
    });

    atmos.on_room_start();

    return atmos;
}

function high_clouds() {
    if SETTINGS.get("weather_strength") == "none" {
        return undefined;
    }

    var atmos =  {
        id: Atmosphere.HighClouds,
        start_offset: CAMERA.cam_pos.clone(),
    };

    atmos.on_room_start = method(atmos, function() {
        random_set_seed(CALENDAR.time);

        var range = fiddle_get("weather/high_cloud/range");

        if SETTINGS.get("weather_strength") == "low" {
            range[0] = round(range[0] * 0.5);
            range[1] = round(range[1] * 0.5);
        }

        var angle_range = fiddle_get("weather/high_cloud/angle");
        var speed_range = fiddle_get("weather/high_cloud/speed");

        var wrapper = {
            my_angle: irandom_range(angle_range[0], angle_range[1]),
            my_speed: random_range(speed_range[0], speed_range[1]),
        }

        var points = poisson_points(
            room_width() * 2,
            room_height() * 2,
            irandom_range(range[0], range[1])
        );

        self.clouds = apply_func(
            points,
            method(wrapper, function(v) {
                return {
                    x: v[0],
                    y: v[1],
                    angle: self.my_angle,
                    speed: self.my_speed,
                    anim_speed: 0,
                    index: irandom(sprite_get_number(spr_cloud_silhouette) - 1),
                    sprite: spr_cloud_silhouette,
                }
            }),
        );

        randomize();
    });
    atmos.on_room_start();

    return atmos;
}

function petals() {
    var r = 100;
    if SETTINGS.get("weather_strength") == "none" {
        return undefined;
    } else if SETTINGS.get("weather_strength") == "low" || MIST.is_running() {
        r = 200;
    }
    var points = poisson_points(
        CAMERA.view_width + ATMOS_PADDING * 2,
        CAMERA.view_height + ATMOS_PADDING * 2,
        r,
    );

    var particles = apply_func(
        points,
        function(v) {
            return {
                x: v[0],
                y: v[1],
                angle: random_range(300, 320),
                speed: 0.3,
                index: irandom(sprite_get_number(spr_part_petal) - 1),
                anim_speed: 0.16,
                sprite: spr_part_petal,
            };
        }
    );

    var cloud_atmos = high_clouds();

    var output = {
        id: Atmosphere.Petals,
        clouds: cloud_atmos.clouds,
        particles,
        start_offset: CAMERA.cam_pos.clone(),
    };
    output.on_room_start = method(output, cloud_atmos.on_room_start);

    return output;
}

function leaves() {
    var r = 100;
    if SETTINGS.get("weather_strength") == "none" {
        return undefined;
    } else if SETTINGS.get("weather_strength") == "low" || MIST.is_running() {
        r = 200;
    }
    var points = poisson_points(
        CAMERA.view_width + ATMOS_PADDING * 2,
        CAMERA.view_height + ATMOS_PADDING * 2,
        r,
    );

    var particles = apply_func(
        points,
        function(v) {
            return {
                x: v[0],
                y: v[1],
                angle: random_range(300, 320),
                index: irandom(sprite_get_number(spr_part_leaffall_multi_spin_v1) - 1),
                speed: 0.3,
                anim_speed: 0.16,
                sprite: string_to_asset(format("spr_part_leaffall_multi_spin_v{}", irandom_range(1, 6))),
            };
        }
    );

    var cloud_atmos = high_clouds();

    var output = {
        id: Atmosphere.Leaves,
        clouds: cloud_atmos.clouds,
        particles,
        start_offset: CAMERA.cam_pos.clone(),
    };
    output.on_room_start = method(output, cloud_atmos.on_room_start);

    return output;
}

function snow(is_blizzard=false) {
    var range = Vec2(20, 40);
    if SETTINGS.get("weather_strength") == "none" {
        return undefined;
    } else if SETTINGS.get("weather_strength") == "low" || MIST.is_running() {
        range = Vec2(50, 80);
    }
    var points = poisson_points(
        CAMERA.view_width + ATMOS_PADDING * 2,
        CAMERA.view_height + ATMOS_PADDING * 2,
        is_blizzard ? range.x : range.y,
    );

    var particles = [];
    for (var i = 0; i < array_length(points); i++) {
        var p = points[i];
        array_push(particles, {
            x: p[0],
            y: p[1],
            angle: random_range(300, 320),
            speed: is_blizzard ? random_range(0.5, 2) : random_range(0.1, 0.3),
            index: irandom(sprite_get_number(spr_part_snow) - 1),
            anim_speed: 0,
            sprite: spr_part_snow,
        });
    }

    return {
        id: is_blizzard ? Atmosphere.Blizzard : Atmosphere.Snow,
        particles,
        start_offset: CAMERA.cam_pos.clone(),
    };
}

function draw_atmosphere_particles(atmos, alpha=1, color=c_white) {
    for (var i = 0; i < array_length(atmos.particles); i++) {
        var part = atmos.particles[i];

        part.x += lengthdir_x(part.speed, part.angle);
        part.y += lengthdir_y(part.speed, part.angle);
        part.index += part.anim_speed;

        var draw_x = part.x + atmos.start_offset.x;
        var draw_y = part.y + atmos.start_offset.y;
        draw_x = wrap(draw_x, CAMERA.right() + ATMOS_PADDING, CAMERA.left() - ATMOS_PADDING);
        draw_y = wrap(draw_y, CAMERA.bottom() + ATMOS_PADDING, CAMERA.top() - ATMOS_PADDING);
        draw_sprite_ext(part.sprite, part.index, draw_x, draw_y, 1, 1, 0, color, alpha);
    }
}

//
enum ForecastGroup {
    Calm,
    Inclement,
    Special,
    LEN
}

//
//
enum Weather {
    Calm,
    Inclement,
    HeavyInclement,
    Special,
    LEN,
}

//
enum Atmosphere {
    HighClouds,
    Rain,
    Storm,
    Petals,
    Leaves,
    Snow,
    Blizzard
}

//
function weather_tomorrow() {
    var next_day = CALENDAR.day() + 1;
    if next_day >= array_length(WEATHER.forecast) {
        return Weather.Calm;
    } else {
        return WEATHER.forecast[next_day];
    }
}

function weather_to_forecast_group(weather) {
    switch weather {
        case Weather.Calm:
            return ForecastGroup.Calm;
        case Weather.Inclement:
        case Weather.HeavyInclement:
            return ForecastGroup.Inclement;
        case Weather.Special:
            return ForecastGroup.Special;
        default: impossible();
    }
}

//
function ui_icon_for_weather(weather, season) {
    switch weather {
        case Weather.Calm: return spr_ui_hud_info_backplate_weather_icon_sunny;
        case Weather.Special: return season == Season.Spring
            ? spr_ui_hud_info_backplate_weather_icon_petals
            : spr_ui_hud_info_backplate_weather_icon_leaves;
        case Weather.Inclement: return season == Season.Winter
            ? spr_ui_hud_info_backplate_weather_icon_snow
            : spr_ui_hud_info_backplate_weather_icon_rain;
        case Weather.HeavyInclement: return season == Season.Winter
            ? spr_ui_hud_info_backplate_weather_icon_blizzard
            : spr_ui_hud_info_backplate_weather_icon_storm;
        default: impossible("Unexpected Weather: {}", weather);
    }
}


function weather_to_atmosphere(weather, time) {
    var is_winter = get_seasons(time) == Season.Winter;
    var is_fall = get_seasons(time) == Season.Fall;
    switch weather {
        case Weather.Calm: return Atmosphere.HighClouds;
        case Weather.Inclement: return is_winter ? Atmosphere.Snow : Atmosphere.Rain;
        case Weather.HeavyInclement: return is_winter ? Atmosphere.Blizzard : Atmosphere.Storm;
        case Weather.Special: return is_fall ? Atmosphere.Leaves : Atmosphere.Petals;
        default: impossible("Unexpected Weather: {Weather}", weather);
    }
}

function generate_forecast(season) {
    var forecast = array_create(28, Weather.Calm);
    var taken = array_create(28, false);
    var already_given = array_create(ForecastGroup.LEN, false);

    //
    taken[0] = true;

    //
    if CALENDAR.year() == 0 && season == Season.Spring {
        var first_week_of_weather = fiddle_get("misc/first_week_of_weather");

        for (var i = 0; i < 7; i++) {
            forecast[i] = string_to_weather(first_week_of_weather[i]);
            taken[i] = true;
            already_given[weather_to_forecast_group(forecast[i])] += 1;
        }
    }

    //
    for (var i = 0; i < FestivalId.LEN; i++) {
        var f = FESTIVALS[i];
        if f.prototype.date.season == season {
            forecast[f.prototype.date.day - 1] = f.prototype.forced_weather;
            taken[f.prototype.date.day - 1] = true;
            already_given[weather_to_forecast_group(forecast[f.prototype.date.day - 1])] += 1;
        }
    }

    //
    for (var i = 1; i < ForecastGroup.LEN; i++) {
        var amt = irandom_range(WEATHER_COUNTS[season][i].x, WEATHER_COUNTS[season][i].y) - already_given[i];
        if amt <= 0 {
            continue;
        }

        //
        repeat amt {
            //
            //
            //
            var offset = irandom_range(0, 27);
            var success = false;
            var signum = choose(-1, 1);
            for (var base_day = 0; base_day < 28; base_day++) {
                var j = abs((offset + signum * base_day) % 28);

                //
                //
                if taken[j]
                    || (i != ForecastGroup.Special && matches(j % Day.LEN, Day.Friday, Day.Saturday))
                {
                    continue;
                }

                var forecast_output;
                switch i {
                    case ForecastGroup.Inclement:
                        var below = try_index_array(forecast, j - 1);
                        var above = try_index_array(forecast, j + 1);

                        if below == Weather.HeavyInclement
                            || below == Weather.Inclement
                            || above == Weather.HeavyInclement
                            || above == Weather.Inclement
                        {
                            continue;
                        }

                        if chance_percent(60) {
                            forecast_output = Weather.HeavyInclement;
                        } else {
                            forecast_output = Weather.Inclement;
                        }
                        break;
                    case ForecastGroup.Special:
                        forecast_output = Weather.Special;

                        if try_index_array(forecast, j - 1) == Weather.Special
                            || try_index_array(forecast, j + 1) == Weather.Special
                        {
                            continue;
                        }

                        break;
                    default: impossible();
                }

                forecast[j] = forecast_output;
                taken[j] = true;
                success = true;
                break;
            }

            if success == false {
                error("we couldn't make as many `{ForecastGroup}` as we wanted to ({})", i, amt);
            }
        }
    }

    return forecast;
}

//
//
function is_rain_spell_target(location_id) {
    switch location_id {
        case LocationId.Dungeon:
        case LocationId.SmallGreenhouse:
        case LocationId.LargeGreenhouse:
            return true;
        default: return LOCATIONS[location_id].outdoor;
    }
}

//
function forecast_generation_test() {
    var _wm = new WeatherManager();
    for (var i = 0; i < Season.LEN; i++) {
        repeat 100 {
            generate_forecast(i);
        }
    }
}
