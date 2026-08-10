object_create(
    "obj_damage_tarball",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            //
            target = CombatTarget.Player;

            //
            damage = 0;

            //
            collision_mode = TarballCollision.RectInRect;
            dimensions = Vec2();

            //
            parent_id = undefined;

            destruction_timer = undefined;
            can_hit_count = undefined;

            collision_list = ds_list_create();
            can_hurt = true;
            callback_per_frame = undefined;

            in_air = false;
            heavy = false;
            instant_kill = false;

            already_hit_array = [];

            persists = false;

            //
            function parent_object() {
                return self.parent_id == undefined ? undefined : self.parent_id.object_index;
            }

            provenance = undefined;
            stats_entry = undefined;

            //
            function succesful_hit(rcvr) {
                if self.notifee != undefined && (is_struct(self.notifee) || instance_exists(self.notifee)) {
                    self.notifee.on_hit(rcvr);
                }

                if self.can_hit_count != undefined {
                    self.can_hit_count--;

                    if self.can_hit_count <= 0 {
                        instance_destroy(self);
                    }
                }
            }

            //
            function blocked() {
                if (self.can_hit_count != undefined) {
                    self.can_hit_count--;

                    if (self.can_hit_count <= 0) {
                        instance_destroy(self);
                    }
                }
            }

            function calculate_knockback(target_x, target_y, move) {
                if self.knockback == false {
                    return false;
                }

                var x_raw_dist = target_x - self.parent_id.x;
                var y_raw_dist = target_y - self.parent_id.y;

                var x_norm = sign(x_raw_dist) * max(1.0 - abs(x_raw_dist) / self.knockback_radius, 0.8);
                var y_norm = sign(y_raw_dist) * max(1.0 - abs(y_raw_dist) / self.knockback_radius, 0.8);

                move.x = random_range(self.knockback_force.x, self.knockback_force.y) * self.push_force_mask.x * x_norm;
                move.y = random_range(self.knockback_force.x, self.knockback_force.y) * self.push_force_mask.y * y_norm;
            }

            function damage_flag() {
                var o = DamageFlag.NONE;

                if self.heavy {
                    o = set_flag(o, DamageFlag.HEAVY);
                }

                if self.critical || self.instant_kill {
                    o = set_flag(o, DamageFlag.CRITICAL);
                }

                return o;
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

            if self.callback_per_frame != undefined
                && self.callback_per_frame() == false
            {
                return;
            }

            if self.can_hurt {
                var col_count = 0;

                var grid_left;
                var grid_right;
                var grid_top;
                var grid_bot;

                //
                switch self.collision_mode {
                    case TarballCollision.BuiltIn:
                        col_count = overlap_instance_list(x, y, obj_damage_receiver, self.collision_list);

                        //
                        grid_left = bbox_left div 8;
                        grid_right = bbox_right div 8;

                        grid_top = bbox_top div 8;
                        grid_bot = bbox_bottom div 8;
                        break;

                    case TarballCollision.RectInRect:
                        col_count = collision_rectangle_list(x, y, x + dimensions.x, y + dimensions.y, obj_damage_receiver, self.collision_list);

                        grid_left = x div 8;
                        grid_right = (x + dimensions.x) div 8;

                        grid_top = y div 8;
                        grid_bot = (y + dimensions.y) div 8;
                        break;

                    case TarballCollision.Circle:
                        grid_left = x div 8;
                        grid_right = (x + dimensions.x) div 8;

                        grid_top = y div 8;
                        grid_bot = (y + dimensions.y) div 8;

                        col_count = collision_circle_list(
                            x + dimensions.x * 0.5,
                            y + dimensions.x * 0.5,
                            dimensions.x * 0.5,
                            obj_damage_receiver,
                            self.collision_list
                        );
                        break;
                }

                if self.can_pick_grid_objects {
                    var pick_prototype = ITEM_PROTOTYPES[ItemId.PickAxeMistril];
                    var doppel = new TangoDoppel();

                    for (var xx = grid_left; xx <= grid_right; xx++) {
                        for (var yy = grid_top; yy <= grid_bot; yy++) {
                            var inst_index = GRID.try_node_index_for_cell(xx, yy);
                            if inst_index != undefined
                                && can_pick_node(GRID, inst_index, pick_prototype.quality)
                            {
                                var pick_node_result = pick_node(GRID, xx, yy, pick_prototype, 0, undefined, doppel, has_flag(self.flags, CombatFlag.Fire));
                                if has_flag(self.flags, CombatFlag.Fire) {
                                    switch pick_node_result {
                                        case PickResult.Nothing:
                                            //
                                            break;
                                        case PickResult.Rock:
                                            TANGO.play("SoundEffects/Objects/Incinerate", xx * 8, yy * 8);
                                            TANGO.play("SoundEffects/Objects/RockBreakNeutral", xx * 8, yy * 8);
                                            break;
                                        default:
                                            TANGO.play("SoundEffects/Objects/Incinerate", xx * 8, yy * 8);
                                            doppel.resolve();
                                            break;
                                    }
                                } else {
                                    if pick_node_result != PickResult.Nothing
                                        && self.notify_on_pick_grid_objects
                                        && self.pick_object_notifee != undefined
                                        && instance_exists(self.pick_object_notifee)
                                    {
                                        self.pick_object_notifee.on_pick_object();
                                    }
                                    //
                                    doppel.resolve();
                                }
                            }
                        }
                    }
                }

                if self.can_chop_grid_objects {
                    var axe_prototype = ITEM_PROTOTYPES[ItemId.AxeMistril];
                    var doppel = new TangoDoppel();
                    for (var xx = grid_left; xx <= grid_right; xx++) {
                        for (var yy = grid_top; yy <= grid_bot; yy++) {
                            var ni = GRID.try_node_index_for_cell(xx, yy);
                            if ni != undefined {
                                var category = object_id_to_object_category(GRID.node_object_id[ni]);
                                if category == ObjectCategory.Tree || category == ObjectCategory.Stump {
                                    var success = chop_node(GRID, xx, yy, axe_prototype, 5, doppel, true);
                                    if success && has_flag(self.flags, CombatFlag.Fire) {
                                        TANGO.play("SoundEffects/Objects/Incinerate", xx * 8, yy * 8);
                                    }
                                    doppel.resolve();
                                }
                            }
                        }
                    }
                }

                //
                //
                if self.can_destroy_grid_objects {
                    for (var xx = grid_left; xx <= grid_right; xx++) {
                        for (var yy = grid_top; yy <= grid_bot; yy++) {
                            var inst_index = GRID.try_node_index_for_cell(xx, yy);
                            if inst_index != undefined
                                && GRID.node_object_id[inst_index] != undefined
                                && array_contains(self.already_hit_array, GRID.node_parent[inst_index].renderer.id) == false
                            {
                                array_push(self.already_hit_array, GRID.node_parent[inst_index].renderer.id);
                                var success = slash_node(GRID, xx, yy, self.parent_object());
                                if success && self.notify_on_destroy_grid_objects && self.grid_object_notifee != undefined && instance_exists(self.grid_object_notifee) {
                                    self.grid_object_notifee.on_object_destroy();
                                }
                                if success && has_flag(self.flags, CombatFlag.Fire) {
                                    TANGO.play("SoundEffects/Objects/Incinerate", xx * 8, yy * 8);
                                }
                            }
                        }
                    }
                }

                //
                for (var i = 0; i < col_count; i++) {
                    var dmg_rcvr = self.collision_list[| i];
                    //
                    if array_contains(self.already_hit_array, dmg_rcvr.id) == false
                        && dmg_rcvr.damage(self)
                        && self.persists == false
                    {
                        array_push(self.already_hit_array, dmg_rcvr.id);
                    }

                }

                ds_list_clear(self.collision_list);
            }

            if self.destruction_timer != undefined {
                self.destruction_timer -= 1;

                if self.destruction_timer <= 0 {
                    instance_destroy(self);
                }
            }
        },
    }
);
