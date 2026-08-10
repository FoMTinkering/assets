object_create(
    "obj_dragon_tablet_renderer",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            self.lay = undefined;
            self.flash_alpha = 0;
            self.seridia_sprite = undefined;
            self.seridia_overlay_alpha = 0;
            self.seridia_x = 0;
            self.seridia_y = 0;
            self.dragon_overlay_alpha = 0;
            self.seridia_index = 0;
            self.spell_flash_alpha = 0;
            self.raising_priestess = false;
            self.void = undefined;
            self.circle = undefined;
            self.cool_seridia_overlay = 0;
            self.sound_controller = undefined;
            self.shake_chain = undefined;
            self.layer_vel = Vec2Zero();
            self.layer_pos = Vec2Zero();

            function transform_name() {
                var menu = ANCHOR.get_menu(Menu.Textbox);

                if menu == undefined {
                    return; //
                }

                var original_width = menu.namebox_front.get_width();
                var target_width = menu.width_for_namebox(NPC_PROTOTYPES[NpcId.Seridia].name);

                TANGO.play("SoundEffects/SpecialEvents/NameTransformation");

                new_world_chain(self, LocationId.Town)
                    .append(LinkId.Function, function(menu) {
                        menu.namebox_heart.set_sprite(spr_cutscene_dialogue_circle_green_crack);
                        menu.namebox_heart.set_speed(1);
                    }, [menu])
                    .append(LinkId.Await, function(menu) {
                        return menu.namebox_heart.get_index() == 1;
                    }, [menu])
                    .append(LinkId.Function, function(menu) {
                        var poof = ANCHOR.sprite(menu.namebox_heart_backplate, menu.namebox_heart.get_z() - 1);
                        poof
                            .set_sprite(spr_cutscene_dialogue_poof)
                            .set_xy(menu.namebox_heart.get_x(), menu.namebox_heart.get_y())
                            .set_align(menu.namebox_heart.get_align().x, menu.namebox_heart.get_align().y)
                            .set_speed(1)
                            .set_animation_end_callback(function(poof) {
                                ANCHOR.free_node(poof);
                            }, [poof])

                        menu.namebox_heart_backplate
                            .set_sprite(spr_cutscene_dialogue_silhouette)
                            .set_speed(1)
                            .add_x(-1)
                            .set_animation_end_callback(function(menu) {
                                menu.namebox_heart_backplate.set_sprite(spr_ui_dialogue_namebar_heartinsert);
                                menu.namebox_heart_backplate.set_speed(0);
                                menu.namebox_heart_backplate.add_x(1);
                                menu.namebox_heart.add_x(-1);
                            }, [menu])

                        menu.namebox_heart.add_x(1);

                    }, [menu])
                    .join(LinkId.Ease, new Ease(EaseId.QuartOut, 1.0, 0.0, 15), function(_, a, menu) {
                        menu.namebox_heart.set_max_alpha(a);
                    }, [menu])
                    .append(LinkId.Await, function(menu) {
                        return menu.namebox_heart_backplate.get_index() == 16;
                    }, [menu])
                    .append(LinkId.Function, function(menu) {
                        menu.namebox_heart.set_sprite(spr_ui_dialogue_heart_yellow);
                    }, [menu])
                    .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0.0, 1.0, 15), function(_, a, menu) {
                        menu.namebox_heart.set_max_alpha(a);
                        menu.namebox_heart.set_alpha(a);
                    }, [menu])
                    .append(LinkId.Function, function(menu) {
                        var shine = ANCHOR.sprite(menu.namebox_heart);
                        shine
                            .set_sprite(spr_cutscene_dialogue_heart_shine)
                            .set_speed(1)
                            .set_animation_end_callback(function(shine) {
                                ANCHOR.free_node(shine);
                            }, [shine])
                    }, [menu])

                new_world_chain(self, LocationId.Town)
                    .append(LinkId.Await, function(menu) {
                        return menu.namebox_heart.get_sprite() == spr_cutscene_dialogue_circle_green_crack
                            && menu.namebox_heart.get_index() == 4;
                    }, [menu])
                    .append(LinkId.Function, function(menu) {
                        menu.namebox_text.set_alpha(0);
                    }, [menu])
                    .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1.0, 0.0, 25), function(_, a, menu) {
                        menu.namebox_text.set_alpha(a);
                    }, [menu])
                    .append(LinkId.Timer, 25)
                    .append(LinkId.Ease, new Ease(EaseId.QuartOut, original_width, target_width, 25), function(_, a, menu) {
                        menu.namebox_front.set_width(a);
                        menu.namebox_back.set_width(a + TEXTBOX_NAMEBOX_BACK_PADDING);
                    }, [menu])
                    .append(LinkId.Function, function(menu) {
                        menu.namebox_text.set_key(NPC_PROTOTYPES[NpcId.Seridia].name);
                    }, [menu])
                    .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 25), function(_, a, menu) {
                        menu.namebox_text.set_alpha(a);
                    }, [menu])
            }

            function start_world_shake() {
                if self.shake_chain != undefined {
                    CHAINS.cancel_chain(self.shake_chain);
                }
                self.shake_chain = new_world_chain(self, LocationId.Town)
                    .append(LinkId.Function, function() {
                        var amount = 0.1 + random(0.3);
                        if random(1.0) < 0.02 {
                            amount = 1.0 + random(0.2);
                            TANGO.play(choose(
                                "SoundEffects/SpecialEvents/EarthShake1",
                                "SoundEffects/SpecialEvents/EarthShake2",
                                "SoundEffects/SpecialEvents/EarthShakeLong",
                            ));
                        }
                        CAMERA.add_trauma(amount);
                    })
                    .append(LinkId.Await, function() {
                        if max(CAMERA.trauma.x, CAMERA.trauma.y) < 0.1 {
                            self.start_world_shake();
                            return true;
                        }
                        return false;
                    })
            }

            function start_void_shake() {
                if self.shake_chain != undefined {
                    CHAINS.cancel_chain(self.shake_chain);
                }
                var delay = floor(0.5 + random(2.5));
                self.shake_chain = new_world_chain(self, LocationId.Town)
                    .append(LinkId.Function, function() {
                        var amount = MIST.blackboard.try_take("big_shake") == true
                            ? 1.2
                            : 0.3 + random(0.4);
                        TANGO.play("SoundEffects/SpecialEvents/CosmicShake");
                        CAMERA.add_trauma(amount);
                    })
                    .append(LinkId.Timer, delay * 60)
                    .append(LinkId.Function, function() {
                        self.start_void_shake();
                    })
            }
        },
        step_end: function() {
            if self.lay != undefined || self.void != undefined {
                with obj_seridia {
                    self.depth = FIRE_SEAL_BLACK_OVERLAY_DEPTH - 4;
                }
                with obj_caldarus {
                    self.depth = FIRE_SEAL_BLACK_OVERLAY_DEPTH - 6;
                }
                with obj_ari {
                    self.depth = FIRE_SEAL_BLACK_OVERLAY_DEPTH - 7;
                }
            }

            var should_float = MIST.blackboard.get("float_spellcasters") == true;
            if instance_exists(obj_caldarus) {
                if should_float || abs(obj_caldarus.y_offset > 0.01) {
                    obj_caldarus.y_offset = -sin(pi + TICK * pi / 40);
                } else {
                    obj_caldarus.y_offset = 0;
                }
            }
            if !self.raising_priestess && instance_exists(obj_seridia) {
                if should_float || abs(obj_seridia.y_offset) > 0.01 {
                    obj_seridia.y_offset = -sin(pi + TICK * pi / 40);
                } else {
                    obj_seridia.y_offset = 0;
                }
            }
            if instance_exists(obj_ari) {
                if should_float || abs(obj_ari.z) > 0.01 {
                    obj_ari.z = -sin(pi + TICK * pi / 40);
                } else {
                    obj_ari.z = 0;
                }
            }

        },
        draw: function() {
            if !MIST.is_running() {
                if instance_exists(obj_ari) {
                    obj_ari.par.blend = undefined;
                }
                if self.void != undefined {
                    instance_destroy(self.void);
                }
                if self.lay != undefined {
                    layer_destroy(self.lay);
                }
                if self.circle != undefined {
                    instance_destroy(self.circle);
                }
                if self.sound_controller != undefined {
                    self.sound_controller.force_stop();
                }
                instance_destroy();
                return;
            }

            var command = MIST.blackboard.try_take("command");

            switch command {
                case "make_ari_purple":
                    self.sound_controller = new SoundInstanceController(TANGO.play("SoundEffects/SpecialEvents/ArmorGlowLoop", obj_ari.x, obj_ari.y));
                    obj_ari.par.blend = {
                        src_mode: bm_src_alpha,
                        dest_mode: bm_one,
                        color: make_color_rgb(165, 134, 255),
                        alpha: 0.0
                    };
                    new_world_chain(self, LocationId.EilandsOffice)
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 0.85, 180), function(_, a) {
                            obj_ari.par.blend.alpha = a;
                        })
                    break;
                case "remove_ari_blend":
                    self.sound_controller.request_stop();
                    new_world_chain(self, LocationId.FireSeal)
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0.5, 0, 180), function(_, a) {
                            obj_ari.par.blend.alpha = a;
                        })
                        .append(LinkId.Function, function() {
                            obj_ari.par.blend = undefined;
                        })
                    break;
                case "dark_rise":
                    self.sound_controller = new SoundInstanceController(TANGO.play("SoundEffects/SpecialEvents/DarkRiseLoop"));
                    break;
                case "earthquake_loop":
                    self.sound_controller = new SoundInstanceController(TANGO.play("SoundEffects/SpecialEvents/TownEarthquakeLoop"));
                    break;
                case "create_dark_bkg":
                    self.lay = layer_create(FIRE_SEAL_BLACK_OVERLAY_DEPTH + 1, "BlackBackground");
                    self.back_asset = layer_asset_create_tiled(self.lay, -1000, -1000, mwe_white_pixel, room_width() + 2000, room_height() + 2000);
                    layer_asset_set_blend(self.back_asset, c_black, 1.0);
                    break;
                case "create_void_bkg":
                    if self.lay != undefined {
                        layer_destroy(self.lay);
                        self.lay = undefined;
                    }
                    if self.void != undefined {
                        instance_destroy(self.void);
                        self.void = undefined;
                    }
                    self.lay = layer_create(FIRE_SEAL_BLACK_OVERLAY_DEPTH + 2, "BlackBackground");
                    self.back_asset = layer_asset_create_tiled(self.lay, -1000, -1000, mwe_white_pixel, room_width() + 2000, room_height() + 2000);
                    layer_asset_set_blend(self.back_asset, c_black, 1.0);
                    self.void = instance_create_depth(0, 0, FIRE_SEAL_BLACK_OVERLAY_DEPTH + 1, obj_void_background);
                    break;
                case "create_void_bkg_fast":
                    if self.sound_controller != undefined {
                        self.sound_controller.request_stop();
                    }
                    if self.lay != undefined {
                        layer_destroy(self.lay);
                        self.lay = undefined;
                    }
                    if self.void != undefined {
                        instance_destroy(self.void);
                        self.void = undefined;
                    }
                    self.lay = layer_create(FIRE_SEAL_BLACK_OVERLAY_DEPTH + 2, "BlackBackground");
                    self.back_asset = layer_asset_create_tiled(self.lay, -1000, -1000, mwe_white_pixel, room_width() + 2000, room_height() + 2000);
                    layer_asset_set_blend(self.back_asset, c_black, 1.0);
                    self.void = instance_create_depth(0, 0, FIRE_SEAL_BLACK_OVERLAY_DEPTH + 1, obj_void_background);
                    self.void.vel = Vec2(0.0, -16.0);
                    break;
                case "destroy_bkg":
                    if self.lay != undefined {
                        layer_destroy(self.lay);
                        self.lay = undefined;
                    }
                    instance_destroy(self.void);
                    self.void = undefined;
                    break;
                case "first_bkg_snap":
                    if SETTINGS.get("scrolling_backgrounds") && instance_exists(obj_void_background) {
                        obj_void_background.offset.x = MIST.blackboard.get("x_offset");
                        obj_void_background.offset.y = MIST.blackboard.get("y_offset");
                    }
                    break;
                case "fade_out_circle":
                    new_world_chain(self, LocationId.Town)
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 180), function(_, a) {
                            self.circle.image_alpha = a;
                        })
                        .append(LinkId.Function, function() {
                            instance_destroy(self.circle);
                            self.circle = undefined;
                        })
                    break;
                case "fade_bkg_to_half":
                    var yy = obj_ari.y + (obj_caldarus.y - obj_ari.y) / 2;
                    self.circle = create_sprite_renderer(obj_ari.x, yy, 0, spr_cutscene_final_seal_magic_circle);
                    self.circle.depth = FIRE_SEAL_BLACK_OVERLAY_DEPTH - 1;
                    new_world_chain(self, LocationId.Town)
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0.85, 180), function(_, a) {
                            layer_asset_set_blend(self.back_asset, c_black, a);
                            for (var i = 0; i < array_length(obj_void_background.stars); i++) {
                                layer_asset_set_blend(obj_void_background.stars[i], c_white, a);
                            }
                        })
                        .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 180), function(_, a) {
                            self.circle.image_alpha = a;
                        })
                    break;
                case "tri_loop":
                    self.sound_controller = new SoundInstanceController(TANGO.play("SoundEffects/SpecialEvents/TricastLoop", obj_ari.x, obj_ari.y));
                    break;
                case "fade_back_bkg":
                    new_world_chain(self, LocationId.Town)
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0.85, 1.0, 180), function(_, a) {
                            layer_asset_set_blend(self.back_asset, c_black, a);
                            for (var i = 0; i < array_length(obj_void_background.stars); i++) {
                                layer_asset_set_blend(obj_void_background.stars[i], c_white, a);
                            }
                        })
                        .append(LinkId.Function, function() {
                            MIST.blackboard.set("bkg_is_back", true);
                        })


                    new_world_chain()
                        .append(LinkId.Ease, new Ease(EaseId.Linear, self.void.vel.x, -0.2, 270), function(_, a) {
                            self.void.vel.x = a;
                        })
                        .join(LinkId.Ease, new Ease(EaseId.Linear, self.void.vel.y, 0.4, 270), function(_, a) {
                            self.void.vel.y = a;
                        })
                    break;
                case "flash":
                    self.sound_controller.request_stop();
                    new_world_chain(self, LocationId.Town)
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 5), function(_, a) {
                            self.seridia_overlay_alpha = a;
                        })
                        .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 25), function(_, a) {
                            self.flash_alpha = a;
                        })
                        .append(LinkId.Function, function() {
                            MIST.blackboard.set("flash_in", true);
                            self.seridia_sprite = spr_npc_seridia_dragon_full_body_idle;
                            self.seridia_overlay_alpha = 0;
                            self.seridia_x = obj_ari.x - (sprite_get_width(self.seridia_sprite) / 2) - 8;
                            self.seridia_y = obj_ari.y - (sprite_get_height(self.seridia_sprite)) - 45;
                        })
                        .append(LinkId.Timer, 20)
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 120), function(_, a) {
                            self.flash_alpha = a;
                        })
                        .append(LinkId.Function, function() {
                            MIST.blackboard.set("flash_done", true);
                        })
                        break;
                    case "flash_2":
                        new_world_chain(self, LocationId.Town)
                            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 5), function(_, a) {
                                self.dragon_overlay_alpha = a;
                            })
                            .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 25), function(_, a) {
                                self.flash_alpha = a;
                            })
                            .append(LinkId.Timer, 20)
                            .append(LinkId.Function, function() {
                                MIST.blackboard.set("flash_in", true);
                                self.seridia_sprite = undefined;
                                self.dragon_overlay_alpha = 0;
                            })
                            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 120), function(_, a) {
                                self.flash_alpha = a;
                            })
                            .append(LinkId.Function, function() {
                                MIST.blackboard.set("flash_done", true);
                            })
                        break;
                    case "pulse_dragon":
                        self.seridia_sprite = spr_npc_seridia_dragon_full_body_flashing;
                        break;
                    case "speed_up_bkg":
                        self.void.vel = Vec2(0.0, -16.0);
                        self.sound_controller = new SoundInstanceController(TANGO.play("SoundEffects/SpecialEvents/CosmicEventLoop"));
                        break;
                    case "stop_cosmic_loop":
                        self.sound_controller.request_stop();
                        self.sound_controller = undefined;
                        break;
                    case "snap_bkg_position":
                        if SETTINGS.get("scrolling_backgrounds") && instance_exists(obj_void_background) {
                            obj_void_background.offset.x = 0;
                            obj_void_background.offset.y = 0;
                        }
                        break;
                    case "slow_down_bkg":
                        new_world_chain(self, LocationId.Town).append(LinkId.Ease, new Ease(EaseId.QuartOut, self.void.vel.y, 0.0, 270), function(_, a) {
                            self.void.vel.y = a;
                        })
                        break;
                    case "spell_flash":
                        new_world_chain(self, LocationId.Town)
                            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 25), function(_, a) {
                                self.spell_flash_alpha = a;
                            })
                            .append(LinkId.Timer, 60)
                            .append(LinkId.Function, function() {
                                MIST.blackboard.set("spell_flash_in", true);
                            })
                            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 180), function(_, a) {
                                self.spell_flash_alpha = a;
                            })
                            .append(LinkId.Function, function() {
                                MIST.blackboard.set("spell_flash_done", true);
                            })
                        break;
                    case "transform_name":
                        self.transform_name();
                        break;
                    case "agahnim_priestess":
                        var start_position = trellis_point("seridias_chamber/crystal");
                        var inst = create_sprite_renderer(
                            start_position.x,
                            start_position.y,
                            -start_position.y,
                            spr_npc_seridia_priestess_idle_south,
                        );
                        inst.spawn_timer = 0;
                        inst.spawn_count = 0;
                        new_world_chain(self, LocationId.SeridiasChamber)
                            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1.0, 0.0, 120), function(_, a, inst) {
                                if instance_exists(inst) {
                                    inst.image_alpha = a;
                                }
                            }, [inst])
                            .join(LinkId.Await, function(inst) {
                                inst.y -= 1.75;
                                inst.depth = -inst.y;
                                inst.spawn_timer -= 1;

                                if inst.spawn_timer <= 0 {
                                    inst.spawn_timer = 8;
                                    inst.spawn_count += 1;

                                    var ghost = create_sprite_renderer(
                                        inst.x,
                                        inst.y,
                                        -inst.y,
                                        spr_npc_seridia_priestess_idle_south,
                                    );
                                    ghost.image_alpha = inst.image_alpha;
                                    new_world_chain(self, LocationId.SeridiasChamber)
                                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, inst.image_alpha, 0.0, 45), function(_, a, ghost) {
                                            ghost.image_alpha = a;
                                        }, [ghost])
                                        .append(LinkId.Function, function(ghost) {
                                            instance_destroy(ghost);
                                        }, [ghost])
                                }

                                if inst.spawn_count >= 8 {
                                    instance_destroy(inst);
                                    return true;
                                } else {
                                    return false;
                                }
                            }, [inst])
                        break;
                    case "raise_priestess":
                        self.raising_priestess = true;
                        new_world_chain(self, LocationId.Town)
                            .append(LinkId.Ease, new Ease(EaseId.Linear, 0, -20, 180), function(_, a) {
                                if instance_exists(obj_seridia) {
                                    obj_seridia.y_offset = a;
                                }
                            })
                            .append(LinkId.Function, function() {
                                self.raising_priestess = false;
                            })
                            break;
                    case "cool_seridia_overlay":
                        new_world_chain(self, LocationId.Town).append(LinkId.Ease, new Ease(EaseId.QuartIn, 1, 0, 320), function(_, a) {
                            self.cool_seridia_overlay = a;
                        });
                        break;
                    case "end_tricast":
                        self.sound_controller.request_stop();
                        self.sound_controller = undefined;
                        TANGO.play("SoundEffects/SpecialEvents/TricastStop", obj_ari.x, obj_ari.y);
                        MUSIC_PLAYER.stop();
                        break;
                    case "start_world_shake":
                        self.start_world_shake();
                        break;
                    case "start_void_shake":
                        self.start_void_shake();
                        break;
                    case "stop_shake":
                        CHAINS.cancel_chain(self.shake_chain);
                        break;
            }

            if self.seridia_sprite != undefined {
                self.seridia_index = wrap(self.seridia_index + 0.1, sprite_get_number(self.seridia_sprite));

                draw_sprite(self.seridia_sprite, self.seridia_index, self.seridia_x, self.seridia_y);

                if self.dragon_overlay_alpha != 0 {
                    gpu_set_extra(UberShaderKind.Flat);

                    draw_sprite_ext(
                        self.seridia_sprite,
                        self.seridia_index,
                        self.seridia_x,
                        self.seridia_y,
                        1,
                        1,
                        0,
                        c_white,
                        self.dragon_overlay_alpha
                    );

                    gpu_reset_extra();
                }
            }

        },
        draw_end: function() {
            with obj_seridia {

                if other.seridia_overlay_alpha != 0 {
                    gpu_set_extra(UberShaderKind.Flat);
                    self.image_alpha = other.seridia_overlay_alpha;
                    self.fsm.draw();
                    self.image_alpha = 1;
                    gpu_reset_extra();
                }


                if other.cool_seridia_overlay != 0  {
                    var blend_amount = abs(sin(current_time() / 150));
                    var blend = blend_rgb32([255, 255, 255], [253, 216, 245], blend_amount);

                    gpu_set_extra(UberShaderKind.Flat);
                    draw_sprite_ext(
                        obj_seridia.sprite_index,
                        0,
                        obj_seridia.x,
                        obj_seridia.y,
                        1,
                        1,
                        0,
                        make_color_rgb(blend[0], blend[1], blend[2]),
                        other.cool_seridia_overlay,
                    );
                    gpu_reset_extra();
                }

            }

            draw_sprite_ext(spr_pixel, 0, -1000, -1000, room_width() * 10, room_height() * 10, 0, c_white, self.flash_alpha);

            var color = magic_glow_color();
            gpu_set_extra(UberShaderKind.Flat);
            draw_sprite_ext(spr_pixel, 0, -room_width(), -room_height(), room_width() * 2, room_height() * 2, 0, color, self.spell_flash_alpha);
            gpu_reset_extra();
        },
    }
);
