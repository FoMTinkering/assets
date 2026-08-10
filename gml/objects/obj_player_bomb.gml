object_create(
    "obj_player_bomb",
    undefined,
    {
        sprite_index: spr_player_bomb_main,
        mask_index: string_to_asset("spr_monster_rockclod_projectile_main"),
        create: function() {
            function setup(item_list) {
                var first_item = item_list.first();
                self.item_prototype = first_item.prototype;
            }

            item_prototype = undefined;
            z = 0;
            v_counter = 0;
            v = 0;
            arc = false;

            final_collision = false;
            move_x = true;
            move_y = true;
            move_z = false;
            move_draw_z = false;
            rebound = false;

            timer = 0;
            shadow_caster = SHADOW_GRID.caster_create(x, y);
            //
            shadow_caster_set_sprite(shadow_caster, spr_npc_shadow);

            function collision_checker(grid, ni) {
                return ni != undefined && grid.node_collideable[ni];
            }
        },
        step: function() {
            //
            if game_paused() {
                return;
            }


            //
            if v_counter < 60 {
                v_counter += 1;

                if v_counter <= 10 {
                    self.v = -18 * sin(degrees_to_radians(360 * (self.v_counter / 30)));
                } else if self.v_counter > 10 {
                    self.v = self.start_z + ease_out_bounce(self.v_counter - 10, 0, -start_z, 50);
                    self.v *= -2;
                }
            }

            var ni = GRID.try_node_index_for_room_position(self.x, self.y);
            if (self.move_x || self.move_y) && self.collision_checker(GRID, ni) {
                if self.rebound {
                    self.move_x = false;
                    self.move_y = false;
                } else {
                    self.final_x = 2 * self.x - self.final_x;
                    self.final_y = 2 * self.y - self.final_y;
                }

                self.rebound = true;
            }

            //
            if self.move_x {
                self.x = lerp(self.x, self.final_x, 0.12);
                if abs(self.x - self.final_x) < 0.1 {
                    self.x = self.final_x;
                    self.move_x = false;
                }
            }
            if self.move_y {
                self.y = lerp(self.y, self.final_y, 0.12);
                if abs(self.y - self.final_y) < 0.1 {
                    self.y = self.final_y;
                    self.move_y = false;
                }
            }
            if self.move_z {
                self.z = lerp(self.z, self.final_z, 0.12);

                if abs(self.z - self.final_z) < 0.1 {
                    self.z = self.final_z;
                    self.move_z = false;
                }
            }
            if self.move_draw_z {
                self.draw_z_offset = lerp(self.draw_z_offset, self.final_draw_z_offset, 0.12);

                if abs(self.draw_z_offset - self.final_draw_z_offset) < 0.1 {
                    self.draw_z_offset = self.final_draw_z_offset;
                    self.move_draw_z = false;
                }
            }

            depth = get_instance_depth(y, z);
            shadow_caster_set_position(self.shadow_caster, x, y);

            if self.timer != undefined {
                self.timer += 1;

                if self.timer > 120 {
                    TarballBuilder(
                        self.x - 64 / 2,
                        self.y - 64 / 2,
                        64,
                        64,
                        self.item_prototype.bomb.damage,
                        CombatTarget.Enemy,
                    )
                    .set_can_pick_grid_objects(true)
                    .set_can_chop_grid_objects(true)
                    .set_can_destroy_grid_objects(true)
                    .set_in_air()
                    .set_timer(3)
                    .gen();

                    CAMERA.add_trauma(0.3);
                    create_animation_effect(
                        x,
                        y,
                        depth - 15,
                        spr_fx_monster_rockclod_bomb_explosion
                    );

                    instance_destroy(self);
                }
            }
        },
        draw: function() {
            var draw_x = x;
            var draw_y = y + self.v + self.draw_z_offset;

            draw_sprite(self.sprite_index, image_index, draw_x, draw_y);
        },
        destroy: function() {
            TANGO.play("SoundEffects/Objects/Explosion", x, y);
        },
        cleanup: function() {
            SHADOW_GRID.caster_remove(self.shadow_caster);
        },
    }
);
