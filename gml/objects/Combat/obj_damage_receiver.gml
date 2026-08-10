object_create(
    "obj_damage_receiver",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            //
            target = undefined;

            //
            parent_id = undefined;

            //
            //
            offset = undefined;

            //
            damaged = ds_list_create();

            //
            status = ReceiverStatus.Normal;

            //
            current_iframes = 0;
            iframes = 0;

            in_air = false;

            damage_back_tarball = undefined;
            on_damage_back = undefined;

            //
            function parent_object() {
                return self.parent_id == undefined ? undefined : self.parent_id.object_index;
            }

            //
            //
            //
            function damage(tarball) {
                var output_bit_pattern = self.target & tarball.target;

                if output_bit_pattern == 0 || self.current_iframes > 0 {
                    return false;
                }

                if self.status == ReceiverStatus.DamageOnAttack && self.on_damage_back(tarball) {
                    return true;
                }
                if tarball.hit_notify_only == false {
                    ds_list_add(self.damaged, tarball);
                }

                return true;
            }

            //
            function drop_damage() {
                ds_list_clear(self.damaged);
            }

            //
            //
            function try_take_damage() {
                while ds_list_size(self.damaged) != 0 {
                    //
                    var tarball = self.damaged[| 0];
                    ds_list_delete(self.damaged, 0);

                    //
                    if instance_exists(tarball) == false {
                        continue;
                    }

                    if self.current_iframes > 0 && has_flag(tarball.flags, CombatFlag.Acid) == false {
                        var my_pos = array_get_index(tarball.already_hit_array, self.id);
                        if my_pos != -1 {
                            array_delete(tarball.already_hit_array, my_pos, 1);
                        }

                        continue;
                    }

                    if self.parent_object() != obj_monster_rock_stack && has_flag(tarball.flags, CombatFlag.Rockstack) {
                        continue;
                    }

                    //
                    var cont = false;
                    switch self.status {
                        case ReceiverStatus.Normal:
                        case ReceiverStatus.DamageOnAttack:
                            //
                            self.current_iframes = self.iframes;
                            tarball.succesful_hit(self);
                            break;
                        case ReceiverStatus.Blocking:
                            //
                            tarball.blocked();
                            self.current_iframes = self.iframes;
                            break;
                        //
                        case ReceiverStatus.UntimedInvulnerable:
                            cont = true;
                            var my_pos = array_get_index(tarball.already_hit_array, self.id);
                            if my_pos != -1 {
                                array_delete(tarball.already_hit_array, my_pos, 1);
                            }
                            break;
                        case ReceiverStatus.Aerial:
                            //
                            if has_flag(tarball.flags, CombatFlag.InAir) {
                                tarball.succesful_hit(self);
                                self.current_iframes = self.iframes;
                            } else {
                                cont = true;
                            }
                            break;
                        default: impossible("unexpected receiver_status: {}", self.status);
                    }

                    if cont == false {
                        return {
                            status: self.status,
                            tarball: tarball,
                        }
                    }
                }

                //
                return undefined;
            }
        },
        step: function() {
            if game_paused() {
                return;
            }

            //
            if self.parent_id != undefined && instance_exists(parent_id) {
                x = self.parent_id.x;
                y = self.parent_id.y;

                if self.offset != undefined {
                    x += self.offset.x;
                    y += self.offset.y;
                }
            }

            //
            if self.current_iframes > 0 {
                self.current_iframes -= 1;
            }
        },
    }
);
