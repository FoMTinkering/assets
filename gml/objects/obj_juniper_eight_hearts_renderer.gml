object_create(
    "obj_juniper_eight_hearts_renderer",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            self.juni_glow_alpha = undefined;
            self.ari_glow_alpha = undefined;
            self.overlay_alpha = false;
            self.ari_surface = undefined;
            self.loop_chain = undefined;

            with obj_assetobject {
                switch self.sprite_index {
                    case spr_bathhouse_bath_pool_spring:
                        self.sprite_index = spr_bathhouse_bath_pool_pink_spring;
                        break;
                    case spr_bathhouse_bath_pool_spring_ground:
                        self.sprite_index = spr_bathhouse_bath_pool_pink_spring_ground;
                        break;
                    default: break;
                }
            }

            function start_animation_loop() {
                self.loop_chain = new_world_chain(self, LocationId.BathhouseBath)
                    .append(LinkId.Function, function() {
                        TANGO.play("SoundEffects/SpecialEvents/JuniperSpellSparkleRight");
                        create_animation_effect(obj_ari.x, obj_ari.y + 12, -1000, spr_fx_essence_rise);
                    })
                    .append(LinkId.Timer, 45)
                    .append(LinkId.Function, function() {
                        TANGO.play("SoundEffects/SpecialEvents/JuniperSpellSparkleLeft");
                        create_animation_effect(obj_juniper.x, obj_juniper.y + 12, -1000, spr_fx_essence_fall);
                    })
                    .append(LinkId.Timer, 45)
                    .append(LinkId.Function, self.start_animation_loop)
            }
        },
        draw: function() {
            //
            //
            //
            //
        },
        draw_end: function() {
            if !MIST.is_running() {
                instance_destroy();
                return;
            }

            var command = MIST.blackboard.try_take("command");

            switch command {
                case "juniper_glow":
                    new_chain().append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 0.6, 360), function(_, a) {
                        self.juni_glow_alpha = a;
                    });
                    break;
                case "ari_glow":
                    new_chain().append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 0.6, 360), function(_, a) {
                        obj_ari.par.blend = {
                            src_mode: bm_src_alpha,
                            dest_mode: bm_one,
                            color: magic_glow_color(),
                            alpha: a
                        };
                    });
                    break;
                case "start_overlay":
                    obj_juniper.depth = FIRE_SEAL_BLACK_OVERLAY_DEPTH - 1;
                    obj_ari.depth = FIRE_SEAL_BLACK_OVERLAY_DEPTH - 1;
                    obj_ari.can_set_depth_in_pause = false;
                    new_world_chain(self, LocationId.BathhouseBath).append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 0.15, 360), function(_, a) {
                        self.overlay_alpha = a;
                    });
                    break;
                case "amplify_overlay":
                    new_world_chain(self, LocationId.BathhouseBath).append(LinkId.Ease, new Ease(EaseId.QuartOut, 0.15, 1, 30), function(_, a) {
                        self.overlay_alpha = a;
                    });
                    break;
                case "kill_effects":
                    obj_ari.par.blend = undefined;
                    self.juniper_glow_alpha = 0;
                    new_world_chain(self, LocationId.BathhouseBath).append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 360), function(_, a) {
                        self.overlay_alpha = a;
                    });
                    break;
                case "start_animation_loop":
                    self.start_animation_loop();
                    break;
                case "end_animation_loop":
                    CHAINS.cancel_chain(self.loop_chain);
                    break;

            }

            obj_ari.par.slots[AnimationSlot.BaseEffect].asset = spr_player_pink_bath_water_effect_base_effect;

            var color = magic_glow_color();

            if self.juni_glow_alpha != undefined {
                with obj_juniper {
                    gpu_set_extra(UberShaderKind.Flat);
                    self.image_alpha = other.juni_glow_alpha;
                    self.image_blend = color;
                    draw_self();
                    self.image_alpha = 1;
                    self.image_blend = c_white;
                    gpu_reset_extra();
                }
            }

            if obj_ari.par.blend != undefined {
                obj_ari.par.blend.color = color;
            }

            var color = magic_glow_color();
            gpu_set_extra(UberShaderKind.Flat);
            draw_sprite_ext(spr_pixel, 0, -1000, -1000, 2000, 2000, 0, color, self.overlay_alpha);
            gpu_reset_extra();
        },
    }
);
