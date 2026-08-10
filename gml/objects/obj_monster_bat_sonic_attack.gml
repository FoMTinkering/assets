object_create(
    "obj_monster_bat_sonic_attack",
    undefined,
    {
        sprite_index: spr_fx_monster_essence_bat_sonic_attack,
        create: function() {
            //
            self.ready = true;

            self.x_move = lengthdir_x(8, self.dir);
            self.y_move = lengthdir_y(8, self.dir);

            self.display_number = 1;
            self.image_speed = 1.5;

            self.tarball = TarballBuilder(self.x, self.y, 1, 1, self.damage, CombatTarget.Player)
                .set_mask_index(mask_index)
                .set_parent(self)
                .set_can_destroy_grid_objects(false)
                .notify(self)
                .set_provenance(self.monster_id, self.stats_entry)
                .gen();
            self.tarball.image_angle = self.dir;

            self.receiver = create_receiver(x, y, sprite_index, self, {
                target: CombatTarget.Enemy,
            });

            self.tango_handle = TANGO.play(self.tango_asset, self.x, self.y);

            function on_hit() {
                self.display_number = 100;
            }
        },
        step: function() {
            if game_paused() {
                return;
            }

            if self.ready && self.image_index >= 2 && self.display_number <= 10 {
                self.ready = false;

                //
                self.x += self.x_move;
                self.y += self.y_move;

                self.display_number += 1;
                self.image_index = 0;
                self.ready = true;
            }

            if ARI.perk_active(Perk.SonicBoom) {
                var next_dmg = self.receiver.try_take_damage();
                if next_dmg != undefined {
                    CAMERA.add_trauma(0.4, 0.4);

                    instance_create_depth(
                        self.x,
                        self.y,
                        -1000,
                        obj_monster_bat_sonic_boom,
                        {
                            damage: floor(self.damage / 2),
                        }
                    );

                    instance_destroy(self);
                    TANGO.request_stop(self.tango_handle);
                }
            }
        },
        draw: function() {
            for (var i = 0; i < min(self.display_number, 3); i++) {
                var image_idx = self.image_index + 2 * i;
                if image_idx >= sprite_get_number(sprite_index) {
                    continue;
                }

                draw_sprite_ext(
                    sprite_index,
                    image_idx,
                    self.x - self.x_move * i,
                    self.y - self.y_move * i,
                    1,
                    1,
                    self.dir - self.dir_offset,
                    c_white,
                    1.0
                );
            }
        },
        animation_end: function() {
            if self.display_number >= 10 {
                instance_destroy(self);
            }
        },
        destroy: function() {
            instance_destroy(self.tarball);
        },
    }
);
