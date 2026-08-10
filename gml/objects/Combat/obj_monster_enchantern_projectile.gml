object_create(
    "obj_monster_enchantern_projectile",
    undefined,
    {
        sprite_index: spr_monster_enchantern_floor_ball_main_start,
        create: function() {
            //
            state = EnchanternProjectileState.Start;

            setup_move_and_collide(0.0);

            //
            mask_index = self.sprite_database.mask_index;
            var bbox_dims = shape_get_dimensions(mask_index);
            var bbox_offset = shape_get_offset(mask_index);

            self.tarball = TarballBuilder(x, y, bbox_dims[0], bbox_dims[1], self.dmg)
                .set_offset(bbox_offset[0], bbox_offset[1])
                .set_parent(self)
                .notify(self)
                .set_in_air()
                .set_electric(self.electrocute_kind)
                .set_provenance(self.monster_id, self.stats_entry)
                .gen();

            //
            self.receiver = create_receiver(x, y, mask_index, self, {
                iframes: 1,
            });
            self.receiver.damage_back_tarball = self.tarball;
            self.receiver.on_damage_back = function() {
                //
                ds_list_add(obj_ari.receiver.damaged, self.tarball);

                self.on_hit();

                return true;
            };
            self.receiver.status = set_flag(self.receiver.status, ReceiverStatus.DamageOnAttack);

            self.fizzle = true;
            self.light = instance_create_depth(
                x,
                y,
                depth,
                par_light,
                {
                    image_index: self.image_index,
                }
            );
            self.light.tiered_light = Light.EnchanternProjectileStart;
            self.light.sprite_index = LIGHTS[Light.EnchanternProjectileStart][0];
            self.light.image_index = self.image_index;

            self.sprite_index = self.sprite_database.main_start;

            function set_fizzle() {
                self.state = EnchanternProjectileState.Fizzle;
                self.sprite_index = self.sprite_database.main_fizzle;
                self.image_index = 0;
                self.light.tiered_light = Light.EnchanternProjectileFizzle;
                self.light.sprite_index = LIGHTS[Light.EnchanternProjectileFizzle][0];
                self.light.image_index = 0;
            }

            function on_hit() {
                self.set_fizzle();
            }

            death_calls = false;
        },
        step: function() {
            if game_paused() {
                self.image_speed = 0;
                return;
            }
            self.image_speed = 1;

            if self.state == EnchanternProjectileState.Fizzle || self.state == EnchanternProjectileState.Impact {
                return;
            }

            //
            var collision = movement_and_collide();
            depth = get_instance_depth(y);

            //
            self.light.x = x;
            self.light.y = y;

            if collision != MovementCollisionDirection.NONE || self.death_calls {
                self.state = EnchanternProjectileState.Impact;
            }

            //
            self.timer -= 1;
            if self.timer <= 0 {
                self.set_fizzle();
            }
        },
        animation_end: function() {
            switch self.state {
                case EnchanternProjectileState.Start:
                    self.sprite_index = self.sprite_database.main_loop;
                    self.light.tiered_light = Light.EnchanternProjectileLoop;
                    self.light.sprite_index = LIGHTS[Light.EnchanternProjectileLoop][0];
                    break;
                case EnchanternProjectileState.Main:
                    //
                    break;
                case EnchanternProjectileState.Fizzle:
                case EnchanternProjectileState.Impact:
                    instance_destroy(self);
                    break;
            }
        },
        destroy: function() {
            if self.tarball != undefined && instance_exists(self.tarball) {
                instance_destroy(self.tarball);
            }

            instance_destroy(self.light);
            instance_destroy(self.receiver);
        },
    }
);
