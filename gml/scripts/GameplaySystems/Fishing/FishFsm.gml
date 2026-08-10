
#macro FISH_MOVE_SPD_MAX 0.3

enum FishState {
    Moving,
    Bite,
    Flee,
    MoveToBobber,
    BackAwayFromBobber,
    LEN
}

enum FishSize {
    Small,
    Medium,
    Large,
    Giant,
    LEN
}
enum FishChallenge {
    Easy,
    Medium,
    Hard,
    VeryHard,
    LEN
}
enum WaterDepth {
    None,
    Shallow,
    Average,
    Deep
}

function FishFsm() {
    //
    self.move = Vec2();
    //
    self.dir = irandom_range(0, 360);
    //
    //
    self.facing_dir = self.dir;

    //
    //
    self.current_tile = 0;
    self.water_current_dir = 0;
    self.water_depth = WaterDepth.None;
    self.sparkle_sprite = spr_part_sparkle_anglers_eye;
    self.sparkle = false;
    function fish_refresh_mask(rod_quality) {
        if rod_quality != undefined {
            switch rod_quality {
                case QualityId.Tier1:
                    switch self.fish_loot.size {
                        case FishSize.Small:
                            self.mask_index = spr_fish_silhouette_small_m
                            break;
                        case FishSize.Medium:
                            self.mask_index = spr_fish_silhouette_medium_m;
                            break;
                        case FishSize.Large:
                            self.mask_index = spr_fish_silhouette_large_h;
                            break;
                        case FishSize.Giant:
                            self.mask_index = spr_fish_silhouette_large_0_idle;
                            break;
                    }
                    break;

                case QualityId.Tier2:
                    switch self.fish_loot.size {
                        case FishSize.Small:
                            self.mask_index = spr_fish_silhouette_small_e
                            break;
                        case FishSize.Medium:
                            self.mask_index = spr_fish_silhouette_medium_m;
                            break;
                        case FishSize.Large:
                            self.mask_index = spr_fish_silhouette_large_m;
                            break;
                        case FishSize.Giant:
                            self.mask_index = spr_fish_silhouette_large_0_idle;
                            break;
                    }
                    break;

                case QualityId.Tier3:
                    switch self.fish_loot.size {
                        case FishSize.Small:
                            self.mask_index = spr_fish_silhouette_medium_e
                            break;
                        case FishSize.Medium:
                            self.mask_index = spr_fish_silhouette_small_e;
                            break;
                        case FishSize.Large:
                            self.mask_index = spr_fish_silhouette_large_e;
                            break;
                        case FishSize.Giant:
                            self.mask_index = spr_fish_silhouette_large_0_idle;
                            break;
                    }
                    break;

                case QualityId.Tier4:
                    switch self.fish_loot.size {
                        case FishSize.Small:
                            self.mask_index = spr_fish_silhouette_small_e
                            break;
                        case FishSize.Medium:
                            self.mask_index = spr_fish_silhouette_medium_e;
                            break;
                        case FishSize.Large:
                            self.mask_index = spr_fish_silhouette_large_e;
                            break;
                        case FishSize.Giant:
                            self.mask_index = spr_fish_silhouette_giant_vh;
                            break;
                    }
                    break;

                case QualityId.Tier5:
                    switch self.fish_loot.size {
                        case FishSize.Small:
                            self.mask_index = spr_fish_silhouette_small_e
                            break;
                        case FishSize.Medium:
                            self.mask_index = spr_fish_silhouette_medium_e;
                            break;
                        case FishSize.Large:
                            self.mask_index = spr_fish_silhouette_large_e;
                            break;
                        case FishSize.Giant:
                            self.mask_index = spr_fish_silhouette_giant_h;
                            break;
                    }
                    break;

                case QualityId.Tier6:
                    switch self.fish_loot.size {
                        case FishSize.Small:
                            self.mask_index = spr_fish_silhouette_small_e
                            break;
                        case FishSize.Medium:
                            self.mask_index = spr_fish_silhouette_medium_e;
                            break;
                        case FishSize.Large:
                            self.mask_index = spr_fish_silhouette_large_e;
                            break;
                        case FishSize.Giant:
                            self.mask_index = spr_fish_silhouette_giant_m;
                            break;
                    }
                    break;
                default: impossible("Tier of fishing rod prototype was not a valid value {QualityId}", self.live_item.prototype.quality);
            }
        } else {
            //
            switch self.fish_loot.size {
                case FishSize.Small:
                    self.mask_index = spr_fish_silhouette_small_m
                    break;
                case FishSize.Medium:
                    self.mask_index = spr_fish_silhouette_medium_m;
                    break;
                case FishSize.Large:
                    self.mask_index = spr_fish_silhouette_large_h;
                    break;
                case FishSize.Giant:
                    self.mask_index = spr_fish_silhouette_large_0_idle;
                    break;
            }
        }
    }
    function initialise(_fish_loot) {
        self.fish_loot = _fish_loot;
        self.fish_refresh_mask();
        //
        switch(self.fish_loot.size) {
            case FishSize.Small:
                self.move_sprites = [
                    spr_fish_silhouette_small_0_swim,
                    undefined,
                    undefined,
                    undefined,
                    spr_fish_silhouette_small_22_swim,
                    undefined,
                    undefined,
                    undefined,
                    spr_fish_silhouette_small_45_swim,
                ];
                self.idle_sprites = [
                    spr_fish_silhouette_small_0_idle,
                    spr_fish_silhouette_small_6_idle,
                    spr_fish_silhouette_small_11_idle,
                    spr_fish_silhouette_small_17_idle,
                    spr_fish_silhouette_small_22_idle,
                    spr_fish_silhouette_small_28_idle,
                    spr_fish_silhouette_small_33_idle,
                    spr_fish_silhouette_small_39_idle,
                    spr_fish_silhouette_small_45_idle,
                ];
                self.preferred_depth = WaterDepth.Shallow;
                break;

            case FishSize.Medium:
                self.move_sprites = [
                    spr_fish_silhouette_medium_0_swim,
                    undefined,
                    undefined,
                    undefined,
                    spr_fish_silhouette_medium_22_swim,
                    undefined,
                    undefined,
                    undefined,
                    spr_fish_silhouette_medium_45_swim,
                ];
                self.idle_sprites = [
                    spr_fish_silhouette_medium_0_idle,
                    spr_fish_silhouette_medium_6_idle,
                    spr_fish_silhouette_medium_11_idle,
                    spr_fish_silhouette_medium_17_idle,
                    spr_fish_silhouette_medium_22_idle,
                    spr_fish_silhouette_medium_28_idle,
                    spr_fish_silhouette_medium_33_idle,
                    spr_fish_silhouette_medium_39_idle,
                    spr_fish_silhouette_medium_45_idle,
                ];
                self.preferred_depth = WaterDepth.Average;
                break;

            case FishSize.Large:
                self.move_sprites = [
                    spr_fish_silhouette_large_0_swim,
                    undefined, //
                    undefined, //
                    undefined, //
                    spr_fish_silhouette_large_22_swim,
                    undefined, //
                    undefined, //
                    undefined, //
                    spr_fish_silhouette_large_45_swim,
                ];
                self.idle_sprites = [
                    spr_fish_silhouette_large_0_idle,
                    spr_fish_silhouette_large_6_idle,
                    spr_fish_silhouette_large_11_idle,
                    spr_fish_silhouette_large_17_idle,
                    spr_fish_silhouette_large_22_idle,
                    spr_fish_silhouette_large_28_idle,
                    spr_fish_silhouette_large_33_idle,
                    spr_fish_silhouette_large_39_idle,
                    spr_fish_silhouette_large_45_idle,
                ];
                self.preferred_depth = WaterDepth.Deep;
                break;

            case FishSize.Giant:
                self.move_sprites = [
                    spr_fish_silhouette_giant_0_swim,
                    undefined, //
                    undefined, //
                    undefined, //
                    spr_fish_silhouette_giant_22_swim,
                    undefined, //
                    undefined, //
                    undefined, //
                    spr_fish_silhouette_giant_45_swim,
                ];
                self.idle_sprites = [
                    spr_fish_silhouette_giant_0_idle,
                    spr_fish_silhouette_giant_6_idle,
                    spr_fish_silhouette_giant_11_idle,
                    spr_fish_silhouette_giant_17_idle,
                    spr_fish_silhouette_giant_22_idle,
                    spr_fish_silhouette_giant_28_idle,
                    spr_fish_silhouette_giant_33_idle,
                    spr_fish_silhouette_giant_39_idle,
                    spr_fish_silhouette_giant_45_idle,
                ];
                self.preferred_depth = WaterDepth.Deep;
                break;

            default:
                impossible("Unexpected fish size: {}", self.fish_loot.size);
        }
    }
    function try_apply_movement() {
        if(self.can_move_to(self.x + self.move.x, self.y + self.move.y)) || (self.fsm.current_state_id() != FishState.Moving && self.fsm.current_state_id() != FishState.BackAwayFromBobber) {
            //
            var _force = GRID.node_force[GRID.node_index_for_room_position(x + self.move.x, y + self.move.y)];
            if _force != undefined {
                self.current_tile = _force;
            }
            //
            self.water_current_dir = tile_forces_to_dir(self.current_tile);
            self.water_depth = tile_forces_to_level(self.current_tile);
            x += self.move.x;
            y += self.move.y;
            return true;
        } else {
            return false;
        }
    }

    function can_move_to(_x, _y) {
        var ni = GRID.try_node_index_for_room_position(_x, _y);
        if ni == undefined {
            return false;
        }

        var force = GRID.node_force[ni];

        //
        //
        if force != undefined && self.water_depth != WaterDepth.None && tile_forces_to_level(force) == WaterDepth.None {
            return false;
        }

        return GRID.node_terrain_kind[ni] == TerrainKind.Water;
    }

    function update_sprite(_moving, _image_speed = 1) {
        image_speed = _image_speed;

        //
        var _wrapped_dir = wrap(self.facing_dir, 45, 0)
        var _index = (_wrapped_dir / 45) * 8;
        if(wrap(self.facing_dir, 90, 0) >= 45) {
            _index = 8 - _index;
        }
        _index = round(_index);

        //
        var _sprites;
        if(!_moving || self.facing_dir != self.dir) {
            _sprites = self.idle_sprites;
        } else {
            _sprites = self.move_sprites;

            //
            //
            switch(_index) {
                case 0:
                case 1:
                case 2:
                    _index = 0;
                    break;
                case 3:
                case 4:
                case 5:
                    _index = 4;
                    break;
                case 6:
                case 7:
                case 8:
                    _index = 8;
                    break;
            }
        }

        //
        switch(self.facing_dir div 45) {
            case 0:
                image_angle = 0;
                image_xscale = 1;
                image_yscale = 1;
                break;

            case 1:
                image_angle = 90;
                image_xscale = 1;
                image_yscale = -1;
                break;

            case 2:
                image_angle = 90;
                image_xscale = 1;
                image_yscale = 1;
                break;

            case 3:
                image_angle = 0;
                image_xscale = -1;
                image_yscale = 1;
                break;

            case 4:
                image_angle = 180;
                image_xscale = 1;
                image_yscale = 1;
                break;

            case 5:
                image_angle = 270;
                image_xscale = 1;
                image_yscale = -1;
                break;

            case 6:
                image_angle = 270;
                image_xscale = 1;
                image_yscale = 1;
                break;

            case 7:
                image_angle = 180;
                image_xscale = -1;
                image_yscale = 1;
                break;
        }

        sprite_index = _sprites[_index];
    }
    function update_facing_dir() {
        //
        if(self.facing_dir != self.dir) {
            var _goal_dir = self.dir;
            if(abs(self.facing_dir - self.dir) > 180) {
                if(self.facing_dir - self.dir > 0) {
                    _goal_dir += 360;
                } else {
                    _goal_dir -= 360;
                }
            }

            self.facing_dir = lerp(self.facing_dir, _goal_dir, 0.06);
            self.facing_dir = wrap(self.facing_dir, 360, 0);

            if(abs(self.facing_dir - self.dir) < 2) {
                self.facing_dir = self.dir;
            }
        }
    }
    function flow_downstream() {
        if self.water_current_dir != 0 {
            self.move.x += lengthdir_x(WATER_FLOW_SPEED, self.water_current_dir);
            self.move.y += lengthdir_y(WATER_FLOW_SPEED, self.water_current_dir);
        }
    }
    //
    //
    function trigger_escape(_fish_was_chasing_bobber, _dir) {
        if(!self.fsm.check_state_inclusive(FishState.Flee)) {
            self.fsm.blackboard.set("fish_was_chasing_bobber", _fish_was_chasing_bobber);
            self.fsm.change_state(FishState.Flee);
            self.move.set_val(0, 0);

            //
            self.dir = _dir == undefined ? self.dir - 180 : _dir;
        }
    }

    //
    var builder = StateMachineBuilder(FishState.LEN)
        .add_state(StateBuilder(FishState.Moving)
            .create(function() {
                function change_direction() {
                    var _new_dir;
                    var _votes = new SlowVotes();
                    _votes = _votes
                        .add_candidate("same_dir", 4)
                        .add_candidate("random", 4);

                    //
                    if self.owner.water_current_dir != 0 {
                        _votes.add_candidate("upstream", 4);
                    }

                    var i = 0; while(true) {
                        switch(_votes.get_candidate()) {
                            case "same_dir":
                                _new_dir = random_range(self.owner.dir - 45, self.owner.dir + 45);
                                break;
                            case "random":
                                _new_dir = random(360);
                                break;
                            case "upstream":
                                _new_dir = random_range(self.owner.water_current_dir - 135, self.owner.water_current_dir - 225);
                                break;
                        }

                        //
                        var _x_dist = lengthdir_x(8, _new_dir);
                        var _y_dist = lengthdir_y(8, _new_dir);
                        if(self.owner.can_move_to(
                            self.owner.x + _x_dist,
                            self.owner.y + _y_dist
                        )) {
                            var _break = self.owner.water_depth == WaterDepth.None;
                            if !_break {
                                //
                                var xx = self.owner.x;
                                var yy = self.owner.y;

                                repeat 32 {
                                    xx += _x_dist;
                                    yy += _y_dist;
                                    var ni = GRID.try_node_index_for_room_position(xx, yy);

                                    if ni != undefined && GRID.node_force[ni] != undefined && tile_forces_to_level(GRID.node_force[ni]) == self.owner.preferred_depth {
                                        //
                                        _break = true;
                                        break;
                                    }
                                }
                            }
                            if _break {
                                break;
                            }
                        }

                        i++;
                        if(i > 10) {
                            //
                            _new_dir = self.owner.dir - 180;
                            if(!self.owner.can_move_to(
                                self.owner.x + lengthdir_x(self.spd, _new_dir),
                                self.owner.y + lengthdir_y(self.spd, _new_dir)
                            )) {
                                //
                                self.owner.trigger_escape(false);
                            }
                            break;
                        }
                    }
                    self.owner.dir = _new_dir;
                }

                function reset_countdown() {
                    self.change_dir_countdown = random_range(2, 7) * room_speed;
                    self.travel_time = random_range(2, 8) * room_speed;
                    self.counter = 0;
                }
            })
            .start(function() {
                self.counter = 0;
                self.travel_time = 0;
                self.change_dir_countdown = 0;
                self.max_spd = 0.15;
                self.spd = 0;
            })
            .step(function() {
                //
                self.change_dir_countdown--;
                if(self.change_dir_countdown <= 0) {
                    self.reset_countdown();
                    self.change_direction();
                }

                //
                self.owner.move.set_val(0, 0);
                if(self.counter <= self.travel_time) {
                    self.owner.update_sprite(true);
                    self.spd = lerp(self.spd, self.max_spd, 0.03);
                    self.counter++;
                } else {
                    self.owner.update_sprite(false);
                    self.spd = max(lerp(self.spd, -0.22, 0.005), 0);
                }
                self.owner.move.set_val(
                    lengthdir_x(self.spd, self.owner.dir),
                    lengthdir_y(self.spd, self.owner.dir)
                );
                self.owner.flow_downstream();

                //
                if(!self.owner.try_apply_movement()) {
                    //
                    var _can_move_horizontally = self.owner.can_move_to(self.owner.x + self.owner.move.x, self.owner.y);
                    if(_can_move_horizontally || self.owner.can_move_to(self.owner.x, self.owner.y + self.owner.move.y)) {
                        self.owner.dir = get_bounce_dir(self.owner.move.x, self.owner.move.y, 45, _can_move_horizontally);
                    } else {
                        //
                        self.change_direction();
                    }

                    self.reset_countdown();
                }

                //
                self.owner.update_facing_dir();

                if instance_exists(obj_bobber)
                    && obj_ari.fsm.current_state_id() == PlayerState.Fishing
                    && FISHING.interested_fish == undefined
                    && obj_bobber.fsm.current_state_id() == BobberState.InWater
                    && overlap_instance_any(owner.x, owner.y, obj_bobber, self.owner)
                {
                    //
                    FISHING.set_fish(self.owner.fish_loot);
                    self.fsm.change_state(FishState.BackAwayFromBobber);
                }

            })
            .draw(function() {
                with self.owner {
                    draw_self();
                }
            })
            .spawn()
        )
        .add_state(StateBuilder(FishState.Bite)
            .start(function() {
                self.owner.update_sprite(true);
            })
            .step(function() {
                self.owner.move.set_val(0, 0);
                self.owner.flow_downstream();

                //
                self.owner.update_facing_dir();

                //
                //
                //
                self.owner.try_apply_movement();

                var bite_data = FISHING.get_subscriber(self.owner.id);

                if bite_data.kind == FishingEvent.Missed && bite_data.value == self.owner.fish_loot {
                    self.owner.trigger_escape();
                }

                if bite_data.kind == FishingEvent.Caught && bite_data.value == self.owner.fish_loot {
                    if chance_percent(ARI.perk_value(Perk.WhatACatch)) {
                        var gold_amount = ITEM_PROTOTYPES[self.owner.fish_loot.prototype.item].value.bin * fiddle_get(format("perks/{Perk}/gold_percent", Perk.WhatACatch));
                        for (var i = 0; i < gold_amount; i++) {
                            var li = new LiveItem(ItemId.MobCoin);
                            li.auto_use = true;
                            li.gold_to_gain = 1;
                            item_from_critical_poof(obj_ari.x, obj_ari.y, li);
                        }
                        GAME_STATS.perks[$ perk_to_string(Perk.WhatACatch)] += 1;
                    }

                    if chance_percent(ARI.perk_value(Perk.Frenzy)) {
                        var instance = instance_nearest(self.owner.x, self.owner.y, obj_fish_spawner);
                        if instance != undefined {
                            var school_instance = spawn_fish_school(instance);
                            //
                            if school_instance != undefined {
                                school_instance.x = self.owner.x;
                                school_instance.y = self.owner.y;
                                school_instance.image_alpha = 0;
                                GAME_STATS.perks[$ perk_to_string(Perk.Frenzy)] += 1;
                            }
                        }
                    }

                    instance_destroy(owner);
                    bite_data.kind = FishingEvent.None;
                }

            })
            .draw(function() {
                with self.owner {
                    draw_self();
                }
            })
            .spawn()
        )
        .add_state(StateBuilder(FishState.Flee)
            .start(function() {
                self.owner.update_sprite(true);
                self.flee_spd = 0.4;
                if(self.fsm.blackboard.try_take("fish_was_chasing_bobber", false)) {
                    TANGO.play("SoundEffects/Tools/FishingFishEscape", self.owner.x, self.owner.y);
                } else {
                    TANGO.play("SoundEffects/Animals/SingleFishRun", self.owner.x, self.owner.y);
                }
            })
            .step(function() {
                self.owner.update_sprite(true);

                //
                self.owner.x += lengthdir_x(self.flee_spd, self.owner.dir);
                self.owner.y += lengthdir_y(self.flee_spd, self.owner.dir);

                //
                self.owner.update_facing_dir();

                //
                self.owner.image_alpha -= .02;
                if(self.owner.image_alpha <= 0) {
                    instance_destroy(self.owner);
                }
            })
            .draw(function() {
                with self.owner {
                    draw_self();
                }
            })
            .spawn()
        )
        .add_state(StateBuilder(FishState.MoveToBobber)
            .start(function() {
                if !instance_exists(obj_bobber) {
                    self.owner.trigger_escape();
                    return;
                }
                self.counter = 0;
                self.start_bobber_dist = point_distance(self.owner.x, self.owner.y, obj_bobber.x, obj_bobber.y);
                self.bite_dist = 3;
            })
            .step(function() {
                if !instance_exists(obj_bobber) {
                    self.owner.trigger_escape();
                    return;
                }
                var current_dist = point_distance(self.owner.x, self.owner.y, obj_bobber.x, obj_bobber.y);
                //
                if current_dist <= self.bite_dist {
                    FISHING.try_bite();
                } else {
                    //
                    self.owner.update_sprite(true);
                    self.owner.dir = point_direction(self.owner.x, self.owner.y, obj_bobber.x, obj_bobber.y);

                    //
                    //
                    //
                    //
                    var ratio = current_dist / self.start_bobber_dist;
                    //
                    var beat_current = WATER_FLOW_SPEED + 0.05;
                    var amnt = lerp(beat_current, beat_current + 0.5, sin(ratio * pi));
                    //
                    var spd = min(current_dist, amnt);

                    //
                    self.owner.move.set_val(
                        lengthdir_x(spd, self.owner.dir),
                        lengthdir_y(spd, self.owner.dir)
                    );
                }
                var bite_data = FISHING.get_subscriber(self.owner.id);
                switch bite_data.kind {
                    case FishingEvent.Bite:
                        if bite_data.value == self.owner.fish_loot {
                            self.fsm.change_state(FishState.Bite);
                            TANGO.play("SoundEffects/Tools/FishingBiteAlert", obj_bobber.x, obj_bobber.y);
                            FISHING.bite_timer = self.owner.fish_loot.get_bite_time(ARI.held_item().prototype.quality);
                            bite_data.kind = FishingEvent.None;
                        }
                        break;

                    case FishingEvent.Nibble:
                        if bite_data.value == self.owner.fish_loot {
                            self.fsm.change_state(FishState.BackAwayFromBobber);
                            TANGO.play("SoundEffects/Tools/FishingSmallBite", obj_bobber.x, obj_bobber.y);
                            bite_data.kind = FishingEvent.None;
                        }
                        break;

                    case FishingEvent.Missed:
                        if bite_data.value == self.owner.fish_loot {
                            self.owner.trigger_escape();
                            bite_data.kind = FishingEvent.None;
                        }
                    break;

                }

                //
                self.owner.update_facing_dir();
                self.owner.try_apply_movement();
            })
            .draw(function() {
                with self.owner {
                    draw_self();
                }
            })
            .spawn()
        )
        .add_state(StateBuilder(FishState.BackAwayFromBobber)
            .start(function() {
                self.counter = random_range(60, 180);
                self.spd = 0.15;
                self.reverse_dir = -1 * self.owner.dir;
            })
            .step(function() {
                if !instance_exists(obj_bobber) {
                    self.owner.trigger_escape();
                    return;
                }
                self.owner.move.set_val(0, 0);
                self.owner.update_sprite(true, 0.2);

                //
                self.owner.dir = point_direction(self.owner.x, self.owner.y, obj_bobber.x, obj_bobber.y);

                var bite_data = FISHING.get_subscriber(self.owner.id);

                if bite_data.kind == FishingEvent.Missed && bite_data.value == self.owner.fish_loot {
                    self.owner.trigger_escape();
                    self.owner.dir = reverse_dir;
                    return;
                }

                //
                self.owner.move.set_val(
                    lengthdir_x(self.spd, reverse_dir),
                    lengthdir_y(self.spd, reverse_dir)
                );
                self.owner.flow_downstream();

                //
                self.counter--;
                if self.counter <= 0 {
                    self.fsm.change_state(FishState.MoveToBobber);
                }

                //
                self.owner.update_facing_dir();

                //
                //
                self.owner.try_apply_movement();
            })
            .draw(function() {
                with self.owner {
                    draw_self();
                }
            })
            .spawn()
        )

    self.fsm = builder.spawn(
        FishState.Moving,
        self,
        MapWrap({})
    );

    return builder;
}

//
//
//
//
//
//
//
//
function get_bounce_dir(_x, _y, _angle_range_to_bounce, _colliding_vertically) {
    if(_colliding_vertically) {
        //
        var _perpendicular = point_direction(0, 0, _x, 0);
        //
        //
        var _normal_sign = - sign(_y);
        //
        var _sign = _normal_sign * - sign(_x);
    } else {
        //
        var _perpendicular = point_direction(0, 0, 0, _y);
        //
        //
        var _normal_sign = - sign(_x);
        var _sign = _normal_sign * sign(_y);
    }
    //
    //
    //
    return random_range(_perpendicular, wrap(_perpendicular + (_angle_range_to_bounce * _sign), 360));
}
