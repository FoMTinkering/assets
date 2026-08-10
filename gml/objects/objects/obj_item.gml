object_create(
    "obj_item",
    undefined,
    {
        sprite_index: spr_ui_item_doughlad,
        mask_index: string_to_asset("spr_item_obj_mask"),
        create: function() {
            event_inherit(ObjectEvent.Create);

            function update_can_chase() {
                if self.item.use == ItemUse.GainGoldInstant {
                    self.can_chase = true;
                } else {
                    self.can_chase = ARI.inventory.can_add(self.items.first(), self.items.count());
                }
            }

            mist_id = undefined;
            can_chase = false;
            item_id = undefined;
            items = List();
            y_offset = 0;
            z = 0;
            v = 0;
            start_z = 0;
            draw_z_offset = 0;

            v_counter = 0;
            arc = false;
            lerp_amnt = 0.12;

            kill_timer = -1;
            kill_target = undefined;
            thrown_by_ari = false;

            lerping_to_player = false;

            final_collision = false;
            move_x = true;
            move_y = true;
            move_z = false;
            move_draw_z = false;
            rebound = false;
            pickupable = false;

            final_x = x;
            final_y = y;
            final_z = z;
            final_draw_z_offset = 0;

            wait_time = -50;
            chase_player_counter = 0;

            start_small = true;

            picked_up = false;

            image_speed = 1;
            ignore_collision = false;

            function setup(item_list) {
                var initial_item = item_list.first();
                items = item_list;
                item_id = initial_item.item_id;
                if item_id == ItemId.RecipeScroll || item_id == ItemId.CraftingScroll {
                    ARI.recipes_created[initial_item.inner_item] = true;
                }
                assert(
                    items.every(function(e) {
                        return e.item_id == self.item_id;
                    }),
                    "An obj_item was initialized with more than one ItemId in its list (expected only {ItemId})",
                    self.item_id,
                );

                item = ITEM_PROTOTYPES[item_id];
                sprite_index = initial_item.get_ui_icon();
                icon_width = sprite_get_width(sprite_index);
                y_offset = sprite_get_yoffset(sprite_index);
                depth = get_instance_depth(y, z);

                assert(final_x != undefined && final_y != undefined);
                final_x = floor(final_x);
                final_y = floor(final_y);
                final_z = floor(final_z);

                var ni = GRID.try_node_index_for_room_position(x, y);
                self.started_in_collision = ni == undefined || GRID.node_collideable[ni];
                self.ignore_this_object = undefined;
                if self.started_in_collision {
                    self.ignore_this_cell = Vec2(x div 8, y div 8);
                    if ni != undefined && GRID.node_object_id[ni] != undefined {
                        self.ignore_this_object = GRID.node_parent[ni];
                    }
                }

                if start_small {
                    image_xscale = 0;
                    image_yscale = image_xscale;
                    new_world_chain(self)
                        .join(LinkId.Ease, new Ease(EaseId.QuadOut, 0, 1, FADE_SPEED), function(delta) {
                            image_xscale += delta;
                            image_yscale = image_xscale;
                        })
                }

                if arc {
                    v_counter = 11;
                }

                self.update_can_chase();

                if item.use == ItemUse.GainGoldInstant {
                    shadow_caster_set_sprite(shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));
                }
            }

            function chase_player() {
                lerping_to_player = true;
                chase_player_counter++;
                v = max(-(chase_player_counter/2), -5);
                image_xscale = max((30-chase_player_counter)/30, 0.1);
                image_yscale = image_xscale;
                move_x = true;
                move_y = true;
                final_x = obj_ari.x;
                final_y = obj_ari.y;

                //
                if point_distance(x, y, final_x, final_y) < 12
                    && kill_timer == -1
                {
                    kill_timer = 5;
                    kill_target = obj_ari;
                }
            }

            function collision_checker(grid, ni) {
                return ni != undefined && grid.node_collideable[ni];
            }

            shadow_caster = SHADOW_GRID.caster_create(x, y);
            shadow_caster_set_sprite(shadow_caster, spr_npc_shadow);
        },
        step: function() {
            if self.thrown_by_ari && self.kill_timer == -1 {
                //
                var obj = collision_rectangle(x - 8, y - 8, x + 8, y + 8, [obj_node_renderer, obj_monster_mimic]);
                if obj != undefined {
                    if obj.object_index == obj_node_renderer
                        && object_id_to_object_category(obj.node.object_id) == ObjectCategory.Furniture
                        && obj.node.object_id != ObjectId.TurnInBox
                        && obj.node.prototype.interaction_chest != undefined
                        && obj.node.inventory.can_add(item_id, items.count())
                    {
                        kill_timer = 5;
                        kill_target = obj;
                        final_x = obj.x
                        final_y = obj.y
                    }
    
                    //
                    if obj.object_index == obj_monster_mimic {
                        kill_timer = 5;
                        kill_target = obj;
                        final_x = obj.x;
                        final_y = obj.y;
    
                        //
                        TANGO.play("SoundEffects/Enemies/MimicChest/MimicChestEat", final_x, final_y);
                    }
                }
            }

            wait_time++;
            pickupable = wait_time >= 0;

            //
            var _lerp = lerp_amnt;
            //
            if self.lerping_to_player {
                //
                _lerp = chase_player_counter / 30;
            } else if self.ignore_collision == false {
                var ni = GRID.try_node_index_for_room_position(x, y);
                if self.started_in_collision {
                    if (self.x div 8 != self.ignore_this_cell.x || self.y div 8 != self.ignore_this_cell.y)
                        && (ni == undefined || GRID.node_parent[ni] != self.ignore_this_object)
                    {
                        self.started_in_collision = false;
                        self.ignore_this_cell = undefined;
                        self.ignore_this_object = undefined;
                    }
                } else if (move_x || move_y) && self.collision_checker(GRID, ni) {
                    if rebound {
                        move_x = false;
                        move_y = false;
                    } else {
                        final_x = 2 * x - final_x;
                        final_y = 2 * y - final_y;
                    }

                    rebound = true;
                }
            }

            //
            if move_x {
                x = lerp(x, final_x, _lerp);
                if abs(x - final_x) < 0.1 {
                    x = final_x;
                    move_x = false;
                }
            }
            if move_y {
                y = lerp(y, final_y, _lerp);
                if abs(y - final_y) < 0.1 {
                    y = final_y;
                    move_y = false;
                }
            }
            if move_z {
                z = lerp(z, final_z, _lerp);

                if abs(z - final_z) < 0.1 {
                    z = final_z;
                    move_z = false;
                }
            }
            if self.move_draw_z {
                self.draw_z_offset = lerp(self.draw_z_offset, self.final_draw_z_offset, _lerp);

                if abs(self.draw_z_offset - self.final_draw_z_offset) < 0.1 {
                    self.draw_z_offset = self.final_draw_z_offset;
                    self.move_draw_z = false;
                }
            }

            //
            if !self.lerping_to_player {
                chase_player_counter = 0;
            }
            self.lerping_to_player = false;

            //
            if v_counter < 60 {
                v_counter++;
                if(v_counter <= 10) {
                    v = -18*sin(degrees_to_radians(360*(v_counter/30)));
                    if (start_z == 0) {
                        start_z = -18*sin(degrees_to_radians(360*(10/30)));
                    }
                } else if (v_counter > 10) {
                    v = start_z + ease_out_bounce(v_counter-10, 0, -start_z, 50);
                    //
                    if arc {
                        v *= -2;
                    }
                }
            }

            if kill_timer != -1 {
                image_xscale = lerp(image_xscale, 0, 0.5);
                image_yscale = image_xscale;
                kill_timer -= 1;

                //
                if !instance_exists(self.kill_target) {
                    kill_timer = -1;
                }

                if kill_timer == 0 {
                    //
                    if kill_target.object_index == obj_ari {
                        var _destroy = true;
                        var play_sound = false;

                        for (var i = 0; i < items.count(); i++) {
                            var item = items.get(i);
                            if item.auto_use {
                                use_item_fast(item);
                            } else if ARI.inventory.can_add(item) {
                                set_rumble_additive(RumbleKind.ItemCollect, 3);
                                ARI.give_item(item, 1, true, true, false);
                                play_sound = true;
                            } else {
                                self.kill_timer = -1;
                                self.lerping_to_player = false;
                                _destroy = false;
                                v = 0;
                                break;
                            }
                        }
                        if play_sound {
                            TANGO.play("SoundEffects/Inventory/ItemPickup", x, y);
                        }

                        if _destroy {
                            self.picked_up = true;
                            instance_destroy();
                            return;
                        }
                    } else if kill_target.object_index == obj_node_renderer
                        && kill_target.node.inventory.can_add(items.first(), items.count())
                    {
                        furniture_chest_add_items(items, kill_target.node);
                        self.picked_up = true;
                        instance_destroy();
                        return;
                    } else if kill_target.object_index == obj_monster_mimic {
                        self.picked_up = true;
                        kill_target.gobble(self.items);
                        instance_destroy();
                        return;
                    }
                }
            } else {
                image_xscale = 1;
                image_yscale = image_xscale;
            }

            depth = get_instance_depth(y, z + draw_z_offset);
        },
        step_end: function() {
            shadow_caster_set_position(self.shadow_caster, self.x, self.y);
        },
        draw: function() {
            var draw_y = y - y_offset + v - (sin((current_time() + (x * 10)) / 650) * 2) + self.draw_z_offset;
            var draw_x = x;

            var item_data = self.items.first();
            var outline_c = c_white;
            if item_data.infusion != undefined {
                var data = INFUSIONS.get(item_data.infusion).color;
                outline_c = make_color_rgb(
                    data[0],
                    data[1],
                    data[2],
                );
            }
            draw_sprite_ext(
                item_data.prototype.icon_sprite_outline,
                image_index,
                draw_x,
                draw_y,
                image_xscale,
                image_yscale,
                image_angle,
                outline_c,
                image_alpha
            );
            draw_sprite_ext(
                sprite_index,
                image_index,
                draw_x,
                draw_y,
                image_xscale,
                image_yscale,
                image_angle,
                image_blend,
                image_alpha
            );

            if items.count() > 1 {
                var xx = draw_x + 4;
                if items.count() < 100 {
                    xx -= 4;
                }
                if items.count() < 10 {
                    xx -= 4;
                }
                draw_sprite_ext(
                    spr_ui_hud_item_count_baked_text,
                    items.count(),
                    xx,
                    draw_y + 4,
                    self.image_xscale,
                    self.image_yscale,
                    self.image_angle,
                    self.image_blend,
                    self.image_alpha,
                );
            }
        },
        cleanup: function() {
            SHADOW_GRID.caster_remove(self.shadow_caster);
        },
    }
);
