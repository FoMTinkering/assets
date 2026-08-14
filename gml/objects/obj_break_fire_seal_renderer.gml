object_create(
    "obj_break_fire_seal_renderer",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            #macro FIRE_SEAL_BLACK_OVERLAY_DEPTH (-room_height() - 1000)

            self.black_alpha = 0;
            self.flash_alpha = 0;
            self.caldarus_alpha = 0;
            self.caldarus_overlay_alpha = 0;
            self.dragon_overlay_alpha = 0;
            self.caldarus_index = 0;
            self.scroll = undefined;
            self.circle = undefined;
            self.caldarus_sprite = spr_npc_caldarus_dragon_full_body_main_idle;
            self.fire_breath_effect = undefined;
            self.hurt_timer = undefined;
            self.caldarus_purple = false;
            self.loop_chain = undefined;

            function start_magic_loop() {
                self.loop_chain = new_world_chain(self, LocationId.FireSeal)
                    .append(LinkId.Function, function() {
                        TANGO.play("SoundEffects/SpecialEvents/MagicCirclePulse");
                    })
                    .append(LinkId.Timer, 66)
                    .append(LinkId.Function, function() {
                        self.start_magic_loop();
                    })
            }
        },
        step_end: function() {
            if !instance_exists(self) {
                return;
            }
            
            if self.black_alpha != 0 {
                with obj_caldarus {
                    if MIST.blackboard.get("draw_cal_over_black") == true {
                        self.depth = FIRE_SEAL_BLACK_OVERLAY_DEPTH - 3;
                    }
                }
                with obj_ari {
                    self.depth = FIRE_SEAL_BLACK_OVERLAY_DEPTH - 4;
                }
            }
        },
        draw: function() {
            if !instance_exists(self) {
                return;
            }

            if !MIST.is_running() {
                if self.scroll != undefined && instance_exists(self.scroll) {
                    instance_destroy(self.scroll);
                }
                if self.circle != undefined && instance_exists(self.circle) {
                    instance_destroy(self.circle);
                }
                obj_ari.par.blend = undefined;
                instance_destroy();
                return;
            }

            var command = MIST.blackboard.try_take("command");

            switch command {
                case "raise_scroll":
                    var altar = undefined;
                    with obj_seal_altar {
                        if self.item_id == ItemId.SealingScroll {
                            altar = self;
                            break;
                        }
                    }

                    self.scroll = instance_create_depth(altar.x + 4, altar.y + altar.sin_offset - 22, altar.depth - 1, obj_animation_effect);
                    self.scroll.sprite_index = spr_cutscene_fire_seal_scroll_float_start;
                    self.scroll.live_on_anim_end = true;
                    self.scroll.image_idx = sprite_get_number(self.scroll.sprite_index);
                    altar.icon_sprite = undefined;

                    self.scroll.image_idx_func = function() {
                        self.scroll.sprite_index = spr_cutscene_fire_seal_scroll_float_loop;
                    };
                    break;
                case "unfurl_scroll":
                    self.scroll.sprite_index = spr_cutscene_fire_seal_scroll_unfurl_start;
                    self.scroll.image_idx = sprite_get_number(self.scroll.sprite_index);
                    self.scroll.image_idx_func = function() {
                        self.scroll.sprite_index = spr_cutscene_fire_seal_scroll_unfurl_loop;
                    };
                    break;
                case "destroy_scroll":
                    self.scroll.sprite_index = spr_cutscene_fire_seal_scroll_destroy;
                    self.scroll.image_idx = sprite_get_number(self.scroll.sprite_index);
                    self.scroll.image_idx_func = function() {
                        instance_destroy(self.scroll);
                    };
                    break;
                case "ari_paralysis":
                    self.circle = instance_create_depth(obj_ari.x, obj_ari.y, FIRE_SEAL_BLACK_OVERLAY_DEPTH - 1, obj_animation_effect);
                    self.circle.sprite_index = spr_cutscene_fire_seal_magic_circle_start;
                    self.circle.live_on_anim_end = true;
                    self.circle.image_idx = sprite_get_number(self.circle.sprite_index);

                    self.circle.image_idx_func = function() {
                        self.circle.sprite_index = spr_cutscene_fire_seal_magic_circle_loop;
                    };

                    obj_ari.par.blend = {
                        src_mode: bm_src_alpha,
                        dest_mode: bm_one,
                        color: $d33750,
                        alpha: 1.0
                    };
                    break;
                case "make_ari_blue":
                    obj_ari.par.blend = {
                        src_mode: bm_src_alpha,
                        dest_mode: bm_one,
                        color: $d33750,
                        alpha: 1.0
                    };
                    break;
                case "fake_hurt_ari":
                    obj_ari.par.blend = {
                        src_mode: bm_src_alpha,
                        dest_mode: bm_one,
                        color: obj_ari.hurt_colors[0],
                        alpha: 1.0
                    };
                    create_animation_effect(
                        x + obj_ari.par_offset.x,
                        y + obj_ari.par_offset.y,
                        obj_ari.depth - 1,
                        obj_ari.vfx_sprites[obj_ari.cardinal]
                    );
                    self.hurt_timer = 0;
                    break;
                case "caldarus_purple":
                    self.caldarus_purple = true;
                    break;
                case "no_caldarus_purple":
                    self.caldarus_purple = false;
                    break;
                case "free_ari":
                    new_world_chain(self, LocationId.FireSeal)
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 180), function(_, a) {
                            self.circle.image_alpha = a;
                            obj_ari.par.blend.alpha = a;

                        })
                        .append(LinkId.Function, function() {
                            instance_destroy(self.circle);
                            obj_ari.par.blend = undefined;
                        })
                    break;
                case "bring_in_black":
                    new_world_chain(self, LocationId.FireSeal).append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 180), function(_, a) {
                        self.black_alpha = a;
                    });
                    break;
                case "bring_in_caldarus":
                    new_world_chain(self, LocationId.FireSeal).append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 480), function(_, a) {
                        self.caldarus_alpha = a;
                    });
                    break;
                case "pulse_dragon":
                    self.caldarus_sprite = spr_npc_caldarus_dragon_full_body_main_flashing;
                    break;
                case "flash":
                    new_world_chain(self, LocationId.FireSeal)
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 5), function(_, a) {
                            self.dragon_overlay_alpha = a;
                        })
                        .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 25), function(_, a) {
                            self.flash_alpha = a;
                        })
                        .append(LinkId.Timer, 20)
                        .append(LinkId.Function, function() {
                            self.caldarus_sprite = undefined;
                            MIST.blackboard.set("flash_in", true);
                        })
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 120), function(_, a) {
                            self.flash_alpha = a;
                        })
                        .append(LinkId.Function, function() {
                            MIST.blackboard.set("flash_done", true);
                        })

                    break;
                case "remove_black":
                    new_world_chain(self, LocationId.FireSeal).append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 180), function(_, a) {
                        self.black_alpha = a;
                    });
                    break;
                case "overlay_caldarus":
                    new_world_chain(self, LocationId.FireSeal).append(LinkId.Ease, new Ease(EaseId.QuartIn, 1, 0, 320), function(_, a) {
                        self.caldarus_overlay_alpha = a;
                    });
                    break;
                case "start_caldarus_spell":
                    obj_caldarus.fire_body_alpha = 0;
                    self.fire_breath_effect = 250;
                    break;
                case "start_magic_loop":
                    self.start_magic_loop();
                    break;
                case "stop_magic_loop":
                    CHAINS.cancel_chain(self.loop_chain);
                    break;
            }


            draw_sprite_ext(spr_pixel, 0, 0, 0, room_width(), room_height(), 0, c_black, self.black_alpha);

            if self.hurt_timer != undefined {
                self.hurt_timer += 0.2;

                if floor(self.hurt_timer >= array_length(obj_ari.hurt_colors)) {
                    MIST.blackboard.insert("hurt_done", true);
                    self.hurt_timer = undefined;
                } else {
                    obj_ari.par.blend.color = obj_ari.hurt_colors[floor(self.hurt_timer)];
                }
            }
        },
        draw_end: function() {
            //
            if !instance_exists(self) {
                return;
            }


            if self.caldarus_sprite != undefined {
                self.caldarus_index = wrap(self.caldarus_index + 0.1, sprite_get_number(self.caldarus_sprite));

                draw_sprite_ext(
                    self.caldarus_sprite,
                    self.caldarus_index,
                    obj_ari.x - (sprite_get_width(self.caldarus_sprite) / 2) - 8,
                    obj_ari.y - (sprite_get_height(self.caldarus_sprite)) - 50,
                    1,
                    1,
                    0,
                    c_white,
                    self.caldarus_alpha
                );

                if self.dragon_overlay_alpha != 0 {
                    gpu_set_extra(UberShaderKind.Flat);

                    draw_sprite_ext(
                        self.caldarus_sprite,
                        self.caldarus_index,
                        obj_ari.x - (sprite_get_width(self.caldarus_sprite) / 2) - 8,
                        obj_ari.y - (sprite_get_height(self.caldarus_sprite)) - 50,
                        1,
                        1,
                        0,
                        c_white,
                        self.dragon_overlay_alpha
                    );

                    gpu_reset_extra();
                }
            }


            if self.caldarus_overlay_alpha != 0 {
                var blend_amount = abs(sin(current_time() / 150));
                var blend = blend_rgb32([255, 255, 255], [253, 216, 245], blend_amount);

                gpu_set_extra(UberShaderKind.Flat);
                draw_sprite_ext(
                    obj_caldarus.sprite_index,
                    0,
                    obj_caldarus.x,
                    obj_caldarus.y,
                    1,
                    1,
                    0,
                    make_color_rgb(blend[0], blend[1], blend[2]),
                    self.caldarus_overlay_alpha,
                );
                gpu_reset_extra();
            }

            if self.caldarus_purple {
                with obj_caldarus {
                    gpu_set_blendmode_ext_sepalpha(bm_src_alpha, bm_one, bm_zero, bm_one);
                    self.image_blend = make_color_rgb(165, 134, 255);

                    draw_self();

                    self.image_blend = c_white;
                    gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);
                }
            }

            draw_sprite_ext(spr_pixel, 0, -1000, -1000, room_width() * 10, room_height() * 10, 0, c_white, self.flash_alpha);

            if self.fire_breath_effect != undefined {
                with obj_caldarus {
                    var player_data = fiddle_get("player");
                    gpu_set_blendmode_ext_sepalpha(bm_src_alpha, bm_one, bm_zero, bm_one);
                    self.image_blend = make_color_rgb(player_data.fire_effect_body[0], player_data.fire_effect_body[1], player_data.fire_effect_body[2]);

                    self.fire_body_alpha = mist_glow_effect_calculation(self, self.fire_body_alpha);

                    draw_self();

                    self.image_alpha = 1;
                    self.image_blend = c_white;
                    gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);
                }

                self.fire_breath_effect -= 1;
                if self.fire_breath_effect == 0 {
                    self.fire_breath_effect = undefined;
                }
            }

            with obj_assetobject {
                if self.sprite_index == spr_ui_journal_magic_fire_spell_icon_main {
                    draw_self();
                }
            }
        },
    }
);
