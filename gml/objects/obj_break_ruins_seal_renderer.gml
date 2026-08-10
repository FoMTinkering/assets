object_create(
    "obj_break_ruins_seal_renderer",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            self.flash_alpha = 0;
            self.seridia_fire = false;
            self.lagged_dir = 0;
            self.purple_ari_alpha = undefined;
            self.dark_mode_alpha = 1.0;
            obj_seridia.fire_breath_effects = [];
            self.left_laser = undefined;
            self.right_laser = undefined;
        },
        draw: function() {
            if !MIST.is_running() {
                with obj_ari {
                    self.par.blend = undefined;
                }
                instance_destroy();
                if CURRENT_LOCATION_ID == LocationId.RuinsSeal {
                    with obj_seal_tablet {
                        self.sprite_index = spr_ruins_seal_tablet_spring;
                    }
                    with obj_seal_altar {
                        self.sprite_index = spr_ruins_seal_altar_spring;
                    }

                }
                return;
            }

            var command = MIST.blackboard.try_take("command");

            switch command {
                case "start_seridia_spell":
                    self.seridia_fire = true;
                    self.lagged_dir = 270;
                    break;
                case "flash":
                    var length = MIST.blackboard.try_take("flash_length", 20);
                    new_world_chain(self, LocationId.RuinsSeal)
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 60), function(_, a) {
                            self.flash_alpha = a;
                        })
                        .append(LinkId.Function, function() {
                            MIST.blackboard.set("flash_in", true);
                        })
                        .append(LinkId.Timer, length)
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 120), function(_, a) {
                            self.flash_alpha = a;
                        })
                        .append(LinkId.Function, function() {
                            MIST.blackboard.set("flash_done", true);
                        })
                    break;
                case "glow_ari":
                    new_world_chain(self, LocationId.RuinsSeal)
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 0.5, 25), function(_, a) {
                            self.purple_ari_alpha = a;
                        })
                        .append(LinkId.Timer, 30)
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0.5, 0, 25), function(_, a) {
                            self.purple_ari_alpha = a;
                        })
                        .append(LinkId.Function, function() {
                            self.purple_ari_alpha = undefined;
                        })
                    break;
                case "fade_dark_mode":
                    var time = MIST.blackboard.get("dark_mode_fade_out");
                    new_world_chain(self, LocationId.RuinsSeal)
                        .append(LinkId.Ease, new Ease(EaseId.Linear, 1, 0, time * 60), function(_, a) {
                            self.dark_mode_alpha = a;
                        })
                        .append(LinkId.Function, function() {
                            self.dark_mode = false;
                        })
                    break;
                case "lasers":
                    self.left_laser = instance_create_depth(80, 252, FIRE_SEAL_BLACK_OVERLAY_DEPTH - 1, obj_animation_effect);
                    self.left_laser.sprite_index = spr_fx_ruins_seal_lasers_left_main;

                    self.right_laser = instance_create_depth(312, 252, FIRE_SEAL_BLACK_OVERLAY_DEPTH - 1, obj_animation_effect);
                    self.right_laser.sprite_index = spr_fx_ruins_seal_lasers_right_main;
                    break;
                case "void_ari_explode":
                    self.explosion = instance_create_depth(201, 191, FIRE_SEAL_BLACK_OVERLAY_DEPTH - 1, obj_animation_effect);
                    self.explosion.sprite_index = spr_cutscene_fx_void_ari_explosion;
                    break;
            }

            if self.seridia_fire {
                var player_data = fiddle_get("player");

                if ARI.fire_breath_time > 0 {
                    var dir = cardinal_to_angle(obj_seridia.me.cardinality);
                    self.lagged_dir += min(abs(angle_difference(dir, self.lagged_dir)),5) * sign(angle_difference(dir, self.lagged_dir));
                    self.lagged_dir %= 360;

                    if (array_length(obj_seridia.fire_breath_effects) - 1) < player_data.fire_effect_count
                        && (ARI.fire_breath_time % player_data.fire_effect_fire_rate) == 0
                    {
                        var offset = ARI.fire_breath_time % 2 == 0 ? -5 : 5; //
                        var x_offset = lengthdir_x(player_data.fire_effect_offset, self.lagged_dir + offset);
                        var y_offset = lengthdir_y(player_data.fire_effect_offset, self.lagged_dir + offset) - 12;

                        var fire_breath_id = instance_create_layer(
                            obj_seridia.x + x_offset,
                            obj_seridia.y + y_offset,
                            "Instances",
                            obj_fire_breath,
                            {
                                move_x: lengthdir_x(player_data.fire_effect_speed, self.lagged_dir + offset),
                                move_y: lengthdir_y(player_data.fire_effect_speed, self.lagged_dir + offset),
                                 x_offset,
                                 y_offset,
                                fire_breath_damage: player_data.fire_breath_damage,
                                is_last_poof: ARI.fire_breath_time == player_data.fire_effect_fire_rate,
                                make_poof_sound: (ARI.fire_breath_time % (player_data.fire_effect_fire_rate * player_data.fire_effect_vfx_ratio)) == 0,
                                owner: obj_seridia,
                                sprite_index: spr_fx_dragons_breath_pink,
                            }
                        );
                        array_push(obj_seridia.fire_breath_effects, fire_breath_id.id);
                    }
                }
            }


        },
        draw_end: function() {

            if self.seridia_fire {
                with obj_seridia {
                    var player_data = fiddle_get("player");
                    gpu_set_blendmode_ext_sepalpha(bm_src_alpha, bm_one, bm_zero, bm_one);
                    self.image_blend = make_color_rgb(player_data.fire_effect_body[0], player_data.fire_effect_body[1], player_data.fire_effect_body[2]);

                    self.image_alpha = ARI.fire_body_alpha / 2; //

                    draw_self();

                    self.image_alpha = 1;
                    self.image_blend = c_white;
                    gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);
                }
            }
            var color = magic_glow_color();
            gpu_set_extra(UberShaderKind.Flat);
            draw_sprite_ext(spr_pixel, 0, -room_width(), -room_height(), room_width() * 4, room_height() * 4, 0, color, self.flash_alpha);
            gpu_reset_extra();

            if MIST.blackboard.get("dark_mode") == true {
                draw_sprite_ext(spr_pixel, 0, -1000, -1000, room_width() * 10, room_height() * 10, 0, c_black, self.dark_mode_alpha);
                with obj_ari {
                    var ratio = DISPLAY.asset_resize();
                    var draw_x = floor((x + self.par_offset.x) * ratio) / ratio;
                    var draw_y = floor((y + self.par_offset.y) * ratio) / ratio;
                    self.par.draw(draw_x, draw_y);
                }
                with obj_seridia {
                    draw_self();
                }
                with obj_assetobject {
                    if self.sprite_index == spr_prop_inverted_void_sight_icon {
                        draw_self();
                    }
                }
            }

            if self.purple_ari_alpha != undefined {
                with obj_ari {
                    var blend = blend_rgb32([255, 255, 255], [253, 216, 245], blend_amount);
                    self.par.blend = {
                        src_mode: bm_src_alpha,
                        dest_mode: bm_one,
                        color: blend,
                        alpha: self.purple_ari_alpha,
                    };
                    draw_self();
                    self.par.blend = undefined;
                }
            }

            if self.right_laser != undefined && instance_exists(self.right_laser) {
                with obj_seal_altar {
                    draw_sprite(self.icon_sprite, 0, x + 5, y - 21 + self.sin_offset);
                }
            }
        },
    }
);
