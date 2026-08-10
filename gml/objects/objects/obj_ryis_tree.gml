object_create(
    "obj_ryis_tree",
    undefined,
    {
        sprite_index: spr_easternroad_ruins_sapling_spring,
        create: function() {
            self.boy = undefined;
            self.seq = undefined;
            self.shadow_caster = undefined;

            function refresh_sprite() {
                var stump_removed = requirements_pass(Requirement.RyisStumpRemoved);
                var planted = requirements_pass(Requirement.RyisTreePlanted);
                var grown = requirements_pass(Requirement.RyisTreeGrown);
                var intermediate_stage = requirements_pass(Requirement.RyisTreeIntermediate);

                //
                var grid = GRIDS[LocationId.EasternRoad]; //
                grid.node_can_jump_over[grid.node_index_for_cell(114, 140)] = false;
                grid.node_can_jump_over[grid.node_index_for_cell(114, 140)] = false;
                grid.node_can_jump_over[grid.node_index_for_cell(115, 140)] = false;
                grid.node_can_jump_over[grid.node_index_for_cell(114, 141)] = false;
                grid.node_can_jump_over[grid.node_index_for_cell(115, 141)] = false;

                if grown {
                    self.sprite_index = string_to_asset(format("spr_easternroad_hawthorn_tree_{Season}_birdhouse", CALENDAR.season()));
                } else if intermediate_stage {
                    switch CALENDAR.season() {
                        case Season.Spring:
                            self.sprite_index = spr_easternroad_hawthorn_tree_intermediate_spring;
                            break;
                        case Season.Summer:
                            self.sprite_index = spr_easternroad_hawthorn_tree_intermediate_summer;
                            break;
                        case Season.Fall:
                            self.sprite_index = spr_easternroad_hawthorn_tree_intermediate_fall;
                            break;
                        case Season.Winter:
                            self.sprite_index = spr_easternroad_hawthorn_tree_intermediate_winter;
                            break;
                    }
                } else if planted {
                    switch CALENDAR.season() {
                        case Season.Spring:
                            self.sprite_index = spr_easternroad_ruins_sapling_spring;
                            break;
                        case Season.Summer:
                            self.sprite_index = spr_easternroad_ruins_sapling_summer;
                            break;
                        case Season.Fall:
                            self.sprite_index = spr_easternroad_ruins_sapling_autumn;
                            break;
                        case Season.Winter:
                            self.sprite_index = spr_easternroad_ruins_sapling_winter;
                            break;
                    }
                } else if !stump_removed {
                    self.sprite_index = try_string_to_asset(format("spr_easternroad_ruins_stump_{Season}", CALENDAR.season()))
                        ?? spr_easternroad_ruins_stump_spring;
                }

                if self.shadow_caster == undefined {
                    self.shadow_caster = SHADOW_GRID.caster_create(x, y);
                }

                if stump_removed || planted || grown || intermediate_stage {
                    SHADOW_WAIT_LIST.push({
                        x,
                        y,
                        sprite: SHADOW_DICTIONARY.get(self.sprite_index),
                    });
                }
            }

            //
            var inst = instance_create_depth(
                self.x - 28,
                self.y - 30,
                0,
                obj_transparency_detector,
                {
                    image_xscale: 56,
                    image_yscale: 28,
                }
            );
            inst.asset_object_target = self;

            //
            var inst = instance_create_depth(
                self.x - 16,
                self.y - 47,
                0,
                obj_transparency_detector,
                {
                    image_xscale: 32,
                    image_yscale: 17,
                }
            );

            inst.asset_object_target = self;
            refresh_sprite();
        },
        draw: function() {
            self.depth = get_instance_depth(self.y);

            if MIST.blackboard.try_take("refresh_tree_sprite", false) {
                self.refresh_sprite();
            }

            if !requirements_pass(Requirement.RyisTreeGrown) {
                self.image_alpha = 1.0;
            }
            draw_self();

            if MIST.is_running() && MIST.active_cutscene.id == "ryis_eight_hearts" {
                var command = MIST.blackboard.try_take("command");
                switch command {
                    case "girl_appear":
                        self.seq = instance_create_depth(self.x, self.y, self.depth - 1, obj_animation_effect);
                        self.seq.sprite_index = spr_mistrian_bluebird_sequence_emerge;
                        self.seq.live_on_anim_end = true;
                        self.seq.image_idx = sprite_get_number(self.seq.sprite_index);
                        self.seq.freeze_on_anim_end = true;
                        self.seq.image_speed = 1;

                        self.seq.image_idx_func = function() {
                            self.seq.sprite_index = spr_mistrian_bluebird_sequence_idle_1;
                        };
                        break;
                    case "girl_chirp":
                        self.seq.sprite_index = spr_mistrian_bluebird_sequence_sing_1;
                        self.seq.image_idx = undefined;
                        self.seq.image_idx_func = undefined;
                        self.seq.image_speed = 1;
                        break;
                    case "girl_idle":
                        self.seq.sprite_index = spr_mistrian_bluebird_sequence_idle_1;
                        break;
                    case "fly_boy":
                        self.boy = instance_create_depth(self.x + 250, self.y - 175, self.depth - 1, obj_animation_effect);
                        self.boy.sprite_index = spr_mistrian_bluebird_male_fly_east;
                        self.boy.image_xscale = -1;
                        self.boy.live_on_anim_end = true;
                        self.boy.image_speed = 1;

                        new_world_chain(self, LocationId.EasternRoad)
                            .append(LinkId.Ease, new Ease(EaseId.Linear, 0, 1, 30), function(_, a) {
                                self.boy.image_alpha = a;
                            })
                            .join(LinkId.Await, function() {
                                if !MIST.is_running() {
                                    return true;
                                }

                                var point_dir = point_direction(self.boy.x, self.boy.y, self.x, self.y - 34);
                                self.boy.x += lengthdir_x(1.3, point_dir);
                                self.boy.y += lengthdir_y(1.3, point_dir);

                                var dist_to_point = point_distance(self.boy.x, self.boy.y, self.x, self.y - 34);
                                //

                                if dist_to_point < 1.3 {
                                    instance_destroy(self.boy);
                                    self.seq.sprite_index = spr_mistrian_bluebird_sequence_idle_2;
                                    self.seq.image_speed = 1;
                                    return true;
                                }

                                return false;
                            })
                        break;
                    case "both_chirp":
                        self.seq.sprite_index = spr_mistrian_bluebird_sequence_sing_2;
                        self.seq.image_idx = undefined;
                        self.seq.image_idx_func = undefined;
                        self.seq.image_speed = 1;
                        self.seq.freeze_on_anim_end = false;
                        break;
                    case "both_idle":
                        self.seq.sprite_index = spr_mistrian_bluebird_sequence_idle_2;
                        break;
                }
            } else {
                if self.boy != undefined {
                    if instance_exists(self.boy) {
                        instance_destroy(self.boy);
                    }
                    self.boy = undefined;
                }
                if self.seq != undefined {
                    if instance_exists(self.seq) {
                        instance_destroy(self.seq);
                    }
                    self.seq = undefined;
                }
            }
        }
    }
);
