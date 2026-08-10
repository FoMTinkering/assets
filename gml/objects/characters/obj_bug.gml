object_create(
    "obj_bug",
    undefined,
    {
        sprite_index: spr_insect_ladybug_entity_idle,
        mask_index: string_to_asset("spr_nothing"),
        create: function() {
            #macro CANOPY_BUG_SPAWN_HEIGHT_OFFSET 32 //
            #macro CANOPY_SPAWN_TIME 0.5 //

            self.item_id = undefined;
            self.dir = irandom(360);
            self.state = BugStateId.Idle;
            self.z = 0;
            self.randomise_spd = true;
            self.light = undefined;
            self.pause_frame = 0;
            self.shadow_caster = SHADOW_GRID.caster_create(x, y);

            function setup(_item_id, _canopy_spawn = false) {
                var _bug_data = BUGS.get(_item_id);
                self.item_id = _item_id;
                self.idle_sprite = _bug_data.idle_sprite;
                sprite_index = _bug_data.move_sprite;
                mask_index = _bug_data.move_sprite;
                self.move_sprite = sprite_index;
                self.idle_shadow = string_to_asset(string_replace(asset_to_string(idle_sprite),"entity","shadow"));
                self.move_shadow = string_to_asset(string_replace(asset_to_string(move_sprite),"entity","shadow"));
                self.idle_range = Vec2(_bug_data.idle_range[0], _bug_data.idle_range[1]);
                self.move_range = Vec2(_bug_data.move_range[0], _bug_data.move_range[1]);
                self.move_timer = 0;
                self.acceptable_terrain = _bug_data.acceptable_terrain;
                self.movement_type = _bug_data.type;
                self.attraction = _bug_data.attraction;
                if (self.movement_type == BugMovementType.Jump) {
                    //
                    self.move_bug = bug_jump;
                    self.randomise_spd = false;
                } else {
                    self.spd_range = Vec2(_bug_data.speed_range[0], _bug_data.speed_range[1]);
                    self.spd = self.spd_range.x;
                    self.spdX = self.spd_range.x;
                    self.spdY = self.spd_range.x;
                    self.new_spd = self.spd;
                    if (self.movement_type == BugMovementType.Crawl) {
                        //
                        self.move_bug = bug_crawl;
                    } else {
                        //
                        self.z = -13;
                        self.start_z = self.z;
                        self.move_bug = self.movement_type == BugMovementType.Fly ? bug_fly : bug_fly_wave;
                    }
                }
                if _bug_data.has_light {
                    self.light = instance_create_depth(self.x, self.y, self.depth, par_light);
                    self.light.tiered_light = Light.Insect;
                    self.light.sprite_index = LIGHTS[Light.Insect][0];
                }
                if !is_acceptable_terrain(x,y, self.movement_type == BugMovementType.Fly) {
                    instance_destroy();
                    return;
                }
                if _canopy_spawn {
                    self.state = BugStateId.CanopySpawn;
                    bug_choose_new_spd_dir();
                    self.spawn_z = self.z;
                    self.spawn_timer = 0;
                    self.z = - CANOPY_BUG_SPAWN_HEIGHT_OFFSET;
                } else {
                    bug_to_idle();
                }

                if MIST.is_running() {
                    self.cutscene_started();
                }
            }

            function cutscene_started() {
                self.image_alpha = 0.0;
                if self.light != undefined {
                    light.show = false;
                }
                shadow_caster_set_alpha(self.shadow_caster, 0.0);
            }


            function cutscene_ended() {
                self.image_alpha = 1.0;
                if self.light != undefined {
                    light.show = true;
                }
                shadow_caster_set_alpha(self.shadow_caster, 1.0);
            }

            function bug_to_idle() {
                sprite_index = idle_sprite;
                image_xscale = (self.dir > 90 && self.dir <= 270) ? 1 : -1;
                image_speed = 1;
                shadow_sprite = self.idle_shadow;
                shadow_caster_set_sprite(self.shadow_caster, shadow_sprite);
                self.idle_timer = random_range(idle_range.x,idle_range.y)*room_speed;
                state = BugStateId.Idle;
                spd = 0;
            }

            function is_acceptable_terrain(xx, yy, is_flying=false, allow_collisions=false) {
                var ni = GRID.try_node_index_for_room_position(xx, yy);

                if ni == undefined {
                    return false;
                }

                if allow_collisions == false && (GRID.node_collideable[ni] && !(is_flying && GRID.node_can_jump_over[ni])) {
                    return false;
                }

                if self.acceptable_terrain == undefined {
                    return true;
                } else {
                    return self.acceptable_terrain == GRID.node_terrain_kind[ni];
                }
            }

            function bug_choose_new_spd_dir() {
                if self.randomise_spd {
                    new_spd = random_range(self.spd_range.x,self.spd_range.y);
                }
                self.takeoff = true;

                self.dir = irandom(360);
                switch self.attraction {
                    case BugAttraction.Light:
                        if instance_exists(par_light) {
                            var inst = instance_nearest(self.x, self.y, par_light);
                            if inst != undefined {
                                self.dir = point_direction(self.x, self.y, inst.x, inst.y);
                            }
                        }
                        break;
                    case BugAttraction.Copper:
                        var nearest_copper_node = nearest_node_renderer(function(object_id) {
                            return object_id == ObjectId.RockCopper || object_id == ObjectId.NodeCopper;
                        });
                        if nearest_copper_node != undefined {
                            self.dir = point_direction(self.x, self.y, nearest_copper_node.x, nearest_copper_node.y);
                        }
                        break;
                    case BugAttraction.CrystalBerries:
                        var nearest_crystal_berries = nearest_node_renderer(function(object_id) {
                            return object_id == ObjectId.CrystalBerries;
                        });
                        if nearest_crystal_berries != undefined {
                            self.dir = point_direction(self.x, self.y, nearest_crystal_berries.x, nearest_crystal_berries.y);
                        }
                        break;
                    default:
                        break;
                }

                move_timer = random_range(move_range.x, move_range.y)*room_speed;
                image_xscale = (self.dir > 90 && self.dir <= 270) ? 1 : -1;
                sprite_index = move_sprite;
                shadow_sprite = self.move_shadow;
                shadow_caster_set_sprite(self.shadow_caster, shadow_sprite);
            }

            function bug_jump() {
                if takeoff {
                    jump_time = move_timer;
                    jump_height = 15;
                    landX = lengthdir_x(jump_time, self.dir);
                    landY = lengthdir_y(jump_time, self.dir);
                    if (is_acceptable_terrain(x+landX, y+landY)){
                        takeoff = false;
                        startX = x;
                        startY = y;
                    } else {
                        bug_choose_new_spd_dir(false);
                        return;
                    }
                }
                if (move_timer <= 1) {
                    z = 0;
                    bug_to_idle();
                    return;
                }
                x = lerp(startX,startX+landX,(jump_time-move_timer)/jump_time);
                y = lerp(startY,startY+landY,(jump_time-move_timer)/jump_time);
                //
                //
                //
                z = - sin(move_timer * (pi/jump_time)) * jump_height;
            }

            function bug_fly() {
                spd = lerp(spd, new_spd, 0.02);
                image_speed = 1+(spd);
                spdX = lengthdir_x(spd,self.dir);
                spdY = lengthdir_y(spd,self.dir);
                if (is_acceptable_terrain(x+spdX, y+spdY, true)) {
                    x += spdX;
                    y += spdY;
                }
            }

            function bug_fly_wave() {
                if takeoff {
                    total_time = move_timer;
                    //
                    //
                    //
                    //
                    var cycles = max(total_time div 60, 1);
                    B = (2*pi*cycles)/total_time;
                    takeoff = false;
                }
                spd = lerp(spd, new_spd, 0.02);
                image_speed = 1+(spd);
                spdX = lengthdir_x(spd,self.dir);
                spdY = lengthdir_y(spd,self.dir);
                z = start_z - (2*sin(B*(total_time - self.move_timer)));
                if (is_acceptable_terrain(x+spdX, y+spdY, true)) {
                    x += spdX;
                    y += spdY;
                }
            }

            function bug_crawl() {
                spd = lerp(spd, new_spd, 0.1);
                if (spd > new_spd && spd <= 0.05) {
                    //
                    bug_to_idle();
                }
                spdX = lengthdir_x(spd, self.dir);
                spdY = lengthdir_y(spd, self.dir);

                //
                var already_on_collision = false;
                var n = GRID.try_node_index_for_room_position(x, y);
                if n != undefined && GRID.node_collideable[n] {
                    already_on_collision = true;
                }
                if is_acceptable_terrain(x+spdX, y+spdY, false, already_on_collision) {
                    x += spdX;
                    y += spdY;
                } else {
                    bug_choose_new_spd_dir();
                }
            }
        },
        step: function() {
            if game_paused() && ANCHOR.get_menu(Menu.Eod) == undefined {
                return;
            }

            pause_frame = image_index;
            switch(state) {
                case BugStateId.CanopySpawn:
                    if (dir < 180 || !is_acceptable_terrain(x + lengthdir_x(1, dir), y + lengthdir_y(1, dir))) {
                        //
                        dir = irandom_range(180, 360);
                        return;
                    }
                    spawn_timer++;
                    z = -cos(spawn_timer*(pi/(CANOPY_SPAWN_TIME*room_speed))) * CANOPY_BUG_SPAWN_HEIGHT_OFFSET;
                    x += lengthdir_x(1, dir);
                    y += lengthdir_y(1, dir);
                    if z >= spawn_z {
                        z = spawn_z;
                        bug_to_idle();
                    }
                    break;
                case BugStateId.Idle:
                    idle_timer--;
                    if idle_timer < 0 {
                        state = BugStateId.Move;
                        bug_choose_new_spd_dir();
                    }
                    break;
                case BugStateId.Move:
                    move_timer--;
                    if move_timer < 0 {
                        if choose(0,1) {
                            bug_to_idle();
                            return;
                        }
                        bug_choose_new_spd_dir();
                    }
                    move_bug();
                    break;
                case BugStateId.Flee:
                    image_alpha -= 0.02;
                    if self.light != undefined {
                        light.image_alpha -= 0.02;
                    }
                    if image_alpha <= 0 {
                        instance_destroy();
                    }
                    break;
            }

            if state != BugStateId.Flee && self.image_alpha < 1 {
                self.image_alpha += 0.05;
            }

            if (self.light != undefined) {
                light.x = self.x;
                light.y = self.y + self.z;
                light.z = self.z;
            }

            depth = get_instance_depth(y, z);
        },
        step_end: function() {
            //
            shadow_caster_set_position(self.shadow_caster, x, y);
        },
        draw: function() {
            var idx = game_paused() ? self.pause_frame : image_index;

            draw_sprite_ext(
                sprite_index,
                idx,
                x,
                y + z,
                image_xscale,
                image_yscale,
                image_angle,
                image_blend,
                image_alpha
            );
        },
        destroy: function() {
            if self.light != undefined {
                instance_destroy(self.light);
                self.light = undefined;
            }
        },
        cleanup: function() {
            SHADOW_GRID.caster_remove(self.shadow_caster);
        },
    }
);
