object_create(
    "obj_falling_tree",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            //
            self.prototype = undefined;
            self.variant_idx = 0;
            self.stage = 0;

            //
            self.falling_direction = sign(obj_ari.x - x);
            //
            if(self.falling_direction == 0) {
                self.falling_direction = 1;
            }

            self.falling_counter = 0;
            self.falling_angle = 0;
            self.bounced = false;
        },
        step: function() {
            //
            self.falling_counter += 1 / 110;

            //
            if self.falling_counter >= 1 {
                ARI.gain_essence(5, obj_ari.x, obj_ari.y);
                instance_destroy();
                return;
            }

            //
            var p = 0.3;
            if self.falling_counter >= p {
                image_alpha = 1 - (((self.falling_counter - p) / (1 - p)) *2);
            }

            //
            self.falling_angle = ease_out_bounce(self.falling_counter, 0, 90, 1);
            image_angle = self.falling_angle * self.falling_direction;

            //
            x -= self.falling_direction * (1 - self.falling_counter) * 0.25;

            //
            //
            //
            if !self.bounced && self.falling_angle >= 89.5 {
                self.bounced = true;
                CAMERA.add_trauma(0.4);

                var _leaf_dis;
                var _leaf_dis_x_rand;

                switch(self.stage) {
                    case 0:
                    case 1:
                        //
                        impossible("Trees of growth stage less than 1 should not fall! Current tree stage: {}", self.stage);
                        break;
                    case 2:
                        _leaf_dis = 13;
                        _leaf_dis_x_rand = 6;
                        break;
                    case 3:
                    case 4:
                        _leaf_dis = 29;
                        _leaf_dis_x_rand = 14
                        break;
                }

                if self.stage < self.prototype.wood_items.count() {
                    drop_item(self.prototype.wood_items.get(self.stage).choose_drop().to_array(), x, y);

                    if chance_percent(ARI.perk_value(Perk.Forager)) {
                        var forageable = FORAGEABLES.roll_forageable_at_location(GRID, self.x div 8, self.y div 8);
                        if forageable != undefined {
                            item_from_critical_poof(x, y, NODE_PROTOTYPES[forageable].harvest);
                            GAME_STATS.perks[$ perk_to_string(Perk.Forager)] += 1;
                        }
                    }

                    if chance_percent(ARI.perk_value(Perk.Natural)) {
                        item_from_critical_poof(x, y, ItemId.HardWood);
                        GAME_STATS.perks[$ perk_to_string(Perk.Natural)] += 1;
                    }

                    if ARI.perk_active(Perk.LumberjackTwo) {
                        item_from_critical_poof(self.x, self.y, self.prototype.wood_items.get(self.stage).choose_drop().to_array()[0]);
                        GAME_STATS.perks[$ perk_to_string(Perk.LumberjackTwo)] += 1;
                    }
                }

                create_tree_debris_raw(self.prototype, self.variant_idx, self.stage, x, y, depth)
            }
        },
        draw: function() {
            draw_sprite_ext(
                sprite_index,
                image_index,
                x,
                y,
                image_xscale,
                image_yscale,
                image_angle,
                image_blend,
                image_alpha
            );
        },
    }
);
