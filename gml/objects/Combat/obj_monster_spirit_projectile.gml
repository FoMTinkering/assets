object_create(
    "obj_monster_spirit_projectile",
    undefined,
    {
        sprite_index: spr_monster_flame_spirit_projectile_main,
        target_enemy: false,
        create: function() {
            //
            setup_move_and_collide(0.0);
            self.check_collision = function(xx, yy) {
                var ni = GRID.try_node_index_for_room_position(xx, yy);

                if ni == undefined {
                    return true;
                }

                //
                if GRID.node_terrain_kind[ni] != TerrainKind.Ground {
                    return false;
                }

                //
                if GRID.node_collideable[ni] && GRID.node_can_jump_over[ni] == false {
                    return true;
                }

                return false;
            }
            self.loop_id = TANGO.play("SoundEffects/Enemies/FlameSprite/ProjectileLoop", self.x, self.y);
            shadow_caster = SHADOW_GRID.caster_create(x, y);
            shadow_caster_set_sprite(shadow_caster, SHADOW_DICTIONARY.get(sprite_index));

            if self[$ "oscillate_in_air"] == undefined {
                self.oscillate_in_air = false;
            }

            self.life_time_ticks = 0;

            var t = CombatTarget.Player;
            if self.target_enemy {
                t = CombatTarget.Enemy;
            } else {
                self.target_enemy = false;
            }
            self.target = t;

            self.light = instance_create_depth(
                self.x,
                self.y - 5,
                self.depth,
                par_light
            );

            self.light.tiered_light = Light.CircleTwentyFour;
            self.light.sprite_index = LIGHTS[Light.CircleTwentyFour][0];
            self.image_index = irandom(sprite_get_number(self.light.sprite_index));

            var bbox_dims = shape_get_dimensions(spr_monster_clod_projectile_hitbox);
            self.tarball = TarballBuilder(x, y, bbox_dims[0], bbox_dims[1], self.damage, t)
                .set_offset(-sprite_get_xoffset(spr_monster_clod_projectile_hitbox), -sprite_get_yoffset(spr_monster_clod_projectile_hitbox) - 4)
                .set_parent(self)
                .notify(self)
                .set_persists()
                .set_can_destroy_grid_objects(false)
                .gen();

            self.receiver = create_receiver(x, y, spr_monster_clod_projectile_hitbox, self, {
                target: t == CombatTarget.Player ? CombatTarget.Enemy : CombatTarget.Player,
                offset: Vec2(0, -4),
            });

            function on_hit() {
                if self.receiver.current_iframes > 0 {
                    return;
                }

                instance_destroy(self);
            }

            self.alpha_value = 0;
        },
        step: function() {
            if game_paused() {
                self.image_speed = 0;
                TANGO.request_stop(self.loop_id);
                return;
            } else if TANGO.instance_alive(self.loop_id) == false {
                self.loop_id = TANGO.play("SoundEffects/Enemies/FlameSprite/ProjectileLoop", self.x, self.y);
            }

            if self.image_alpha < 1 {
                self.alpha_value = approach(self.alpha_value, 1, self.fade_in_rate);
                self.image_alpha = floor(self.alpha_value * self.fade_in_clamp) / self.fade_in_clamp;

                if self.alpha_value >= 1.0 {
                    self.image_alpha = 1;
                }
            }

            self.image_speed = 1;
            self.life_time_ticks += 1;

            var dir = point_direction(x, y, obj_ari.x, obj_ari.y);
            self.goal_dir += (min(abs(angle_difference(dir, self.goal_dir)),5) * sign(angle_difference(dir, self.goal_dir))) * self.turn_rate;

            self.move.x = lengthdir_x(self.spd, self.goal_dir);
            self.move.y = lengthdir_y(self.spd, self.goal_dir);

            var collision = movement_and_collide();

            if self.light != undefined && instance_exists(self.light) {
                self.light.x = self.x;
                self.light.y = self.y - 5;
            }

            depth = get_instance_depth(y);
            shadow_caster_set_position(self.shadow_caster, x, y + 2);

            if self.life_time_ticks >= self.life_time || collision {
                instance_destroy();
            }
        },
        step_end: function() {
            if game_paused() {
                self.image_speed = 0;
                return;
            }
            self.image_speed = 1;
        },
        draw: function() {
            var y_offset = 0;
            if self.oscillate_in_air {
                y_offset = self.is_shield ? sin(current_time() / 500) * 2 : 0;
            }
            draw_sprite_ext(
                self.sprite_index,
                self.image_index,
                self.x,
                self.y - 4 + y_offset,
                self.image_xscale,
                self.image_yscale,
                self.image_angle,
                self.image_blend,
                self.image_alpha
            );
        },
        destroy: function() {
            CAMERA.add_trauma(0.3);
            create_animation_effect(self.x, self.y - 5, self.depth - 1, self.projectile_fx);

            TANGO.play("SoundEffects/Enemies/FlameSprite/ProjectileBurnOut", self.x, self.y);
            if self.light != undefined && instance_exists(self.light) {
                instance_destroy(self.light);
                self.light = undefined;
            }

            if self.tarball != undefined && instance_exists(self.tarball) {
                instance_destroy(self.tarball);
            }

            instance_destroy(self.receiver);
        },
        cleanup: function() {
            SHADOW_GRID.caster_remove(self.shadow_caster);

            if loop_id != undefined {
                TANGO.request_stop(loop_id);
            }
        },
    }
);
