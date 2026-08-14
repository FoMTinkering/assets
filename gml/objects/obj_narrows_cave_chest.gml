object_create(
    "obj_narrows_cave_chest",
    undefined,
    {
        sprite_index: undefined,
        room_start: function() {
            var chest = GRID.write_node(
                self.x div 8,
                self.y div 8,
                ObjectId.TreasureChestSecret,
            );

            if chest == undefined {
                chest = GRID.node_parent[GRID.node_index_for_cell(self.x div 8, self.y div 8)];
            }

            if chest != undefined {
                if CURRENT_LOCATION_ID == LocationId.BeachSecret {
                    chest.items = [
                        new LiveItem(ItemId.WaterSpriteStatueV1),
                        new LiveItem(ItemId.CraftingScroll, ItemId.WaterSpriteStatueV1),
                        new LiveItem(ItemId.EssenceStoneSmall),
                    ];
                    array_delete(chest.items, 0, SECRET_BEACH);
                } else if CURRENT_LOCATION_ID == LocationId.NarrowsSecret {
                    chest.items = [
                        new LiveItem(ItemId.OcarinaSpriteStatue),
                        new LiveItem(ItemId.CraftingScroll, ItemId.OcarinaSpriteStatue),
                        new LiveItem(ItemId.EssenceStoneSmall),
                    ];
                    array_delete(chest.items, 0, SECRET_NARROWS);
                } else {
                    chest.items = [
                        new LiveItem(ItemId.SongCrystalAnotherTower),
                    ]
                    array_delete(chest.items, 0, SECRET_TOWER);
                }

                if instance_exists(chest.renderer) {
                    if array_length(chest.items) > 0 {
                        if chest.is_open {
                            chest.is_open = false; //
                            chest.renderer.set_sprite(chest.prototype.chest.closed_sprite);
                            chest.renderer.image_speed = 1;
                        }
    
                        chest.renderer.interact("misc_local/input_interact", chest.prototype.interact_mask);
                        chest.renderer.give_animation_end_callback(function() {
                            if self.sprite_index == self.node.prototype.chest.opening_sprite {
                                self.node.is_open = true;
                                self.set_sprite(self.node.prototype.chest.open_sprite);
                                self.image_speed = 0;
    
                                var drop_chain = new_world_chain(self, CURRENT_LOCATION_ID)
                                    .append(LinkId.Timer, 40);
    
                                for (var i = 0; i < array_length(self.node.items); i++) {
                                    drop_chain
                                        .append(LinkId.Function, function(item, xx, yy, off) {
                                            if CURRENT_LOCATION_ID == LocationId.BeachSecret {
                                                SECRET_BEACH += 1;
                                            } else if CURRENT_LOCATION_ID == LocationId.NarrowsSecret {
                                                SECRET_NARROWS += 1;
                                            } else {
                                                SECRET_TOWER += 1;
                                            }
    
                                            drop_item(item, xx, yy, off);
                                        }, [self.node.items[i], node.renderer.x, node.renderer.y, -4])
                                        .append(LinkId.Timer, 10);
                                }
                            }
                        });
                    } else {
                        chest.renderer.set_sprite(chest.prototype.chest.open_sprite);
                        chest.renderer.image_speed = 0;
                    }
                }
            }
        },
    }
);
