object_create(
    "obj_shooting_star",
    undefined,
    {
        sprite_index: spr_summit_shooting_star_main_start,
        create: function() {
            var f = fiddle_get("shooting_star");

            self.dir = random_range(f.angle_range[0], f.angle_range[1]);
            self.perp_dir = dir + 90;
            self.time = irandom_range(f.time[0], f.time[1]);

            var spd = random_range(f.spd[0], f.spd[1]);
            self.x_move = lengthdir_x(spd, self.dir);
            self.y_move = lengthdir_y(spd, self.dir);

            self.spawn_modulo = f.spawn_modulo;
            self.particle_fall_speed = f.particle_fall_speed;
            self.double_light_reset = f.double_light_reset;

            self.double_light_timer = irandom(self.double_light_reset);

            //
            if chance_percent(f.small_chance) {
                self.sprites = [
                    { sprite: spr_summit_shooting_star_small_main_start, light: Light.ShootingStarStart },
                    { sprite: spr_summit_shooting_star_small_main_loop, light: Light.ShootingStarLoop },
                    { sprite: spr_summit_shooting_star_small_main_end, light: Light.ShootingStarEnd },
                ];
            } else {
                self.sprites = [
                    { sprite: spr_summit_shooting_star_main_start, light: Light.ShootingStarStart },
                    { sprite: spr_summit_shooting_star_main_loop, light: Light.ShootingStarLoop },
                    { sprite: spr_summit_shooting_star_main_end, light: Light.ShootingStarEnd },
                ];
            }

            self.sprite_index = self.sprites[ShootingStarState.Start].sprite;

            self.light = instance_create_layer(
                self.x,
                self.y,
                "Lighting",
                par_light
            );
            self.light.tiered_light = self.sprites[ShootingStarState.Start].light;
            self.light.sprite_index = LIGHTS[self.light.tiered_light][0];

            self.state = ShootingStarState.Start;

            var has_played = MIST.blackboard.get("has_played_one_star");
            if chance_percent(30) || has_played != true {
                MIST.blackboard.set("has_played_one_star", true);

                var sound = MIST.blackboard.get("quiet_stars") != true
                    ? "SoundEffects/SpecialEvents/ShootingStarsLoud"
                      : "SoundEffects/SpecialEvents/ShootingStarsQuiet";
                var tango_play = TANGO.play(sound);

                //
                if tango_play != undefined {
                    //
                    //
                    MIST.sound_requests.push(tango_play);
                }

            }
        },
        step: function() {
            self.light.image_index = self.image_index;

            self.x += self.x_move;
            self.y += self.y_move;

            self.light.x = self.x;
            self.light.y = self.y;

            //
            self.time -= 1;

            if (self.state == ShootingStarState.Loop
                || self.state == ShootingStarState.End)
                && abs(self.time) % self.spawn_modulo == 0
            {
                var xx = x + lengthdir_x(random_range(-2, 2), self.perp_dir);
                var yy = y + lengthdir_y(random_range(-2, 2), self.perp_dir);

                var spr;
                var light_spr;
                if self.double_light_timer <= 0 {
                    spr = spr_summit_shooting_star_particle_double_main;
                    light_spr = spr_summit_shooting_star_particle_double_light_inner;

                    self.double_light_timer = self.double_light_reset;
                } else {
                    spr = spr_summit_shooting_star_particle_main;
                    light_spr = spr_summit_shooting_star_particle_light_inner;

                    self.double_light_timer -= 1;
                }

                instance_create_depth(
                    xx - (self.x_move * 2),
                    yy - (self.y_move * 2),
                    depth + 1,
                    obj_shooting_star_particle,
                    {
                        sprite_index: spr,
                        light_sprite: light_spr,
                        fall_speed: self.particle_fall_speed,
                    }
                );
            }

            //
            if self.state == ShootingStarState.Loop
                && self.time <= 0
            {
                self.state = ShootingStarState.End;
                var data = self.sprites[self.state]

                self.light.tiered_light = data.light;
                self.light.sprite_index = LIGHTS[self.light.tiered_light][0];
                self.light.image_index = 0;

                self.sprite_index = data.sprite;
                self.image_index = 0;
            }
        },
        animation_end: function() {
            switch self.state {
                case ShootingStarState.Start:
                    self.state = ShootingStarState.Loop;
                    var data = self.sprites[self.state]
                    self.sprite_index = data.sprite;
                    self.image_index = 0;
                    self.light.tiered_light = data.light;
                    self.light.sprite_index = LIGHTS[self.light.tiered_light][0];
                    self.light.image_index = 0;

                    break;
                case ShootingStarState.Loop:
                    break;
                case ShootingStarState.End:
                    instance_destroy(self.light);
                    instance_destroy(self);
                    break;
            }
        },
    }
);
