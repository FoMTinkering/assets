object_create(
    "obj_farm_plate",
    object_reserve("par_interactable"),
    {
        sprite_index: undefined,
        create: function() {
            event_inherit(ObjectEvent.Create);
            depth = get_instance_depth(y);

            self.register_interaction(
                InputId.Interact,
                "misc_local/name_plate",
                function() {
                    //
                    //

                    var wrapper = new MultipleChoicePopup(
                        ANCHOR.wrap_for_local(self.node.name),
                        ITEM_PROTOTYPES[self.node.prototype.blueprints[self.node.variant]].icon_sprite,
                    );

                    wrapper.option("misc_local/rename_building", function(wrapper) {
                        var popup = text_input_popup("misc_local/enter_new_name", self.node.name, BUILDING_NAME_MAX_WIDTH, function(txt) {
                            self.node.name = txt;
                        });

                        popup.background.in_now();
                        wrapper.popup.background.out_now();
                    }, [wrapper]);

                    wrapper.option("misc_local/remove_building", function(wrapper) {
                        if self.node.prototype.player_building_kind == PlayerBuildingKind.Stable && !self.node.stable.animals().is_empty() {
                            var popup = popup_creator("misc_local/building_occupied", "misc_local/building_occupied_description");

                            popup.create_button("misc_local/close");

                            popup.spawn();

                            new_chain().append(LinkId.Await, function(popup) {
                                if popup.close_requested {
                                    return true;
                                }
                                return false;
                            }, [popup]);

                            popup.background.in_now();
                            wrapper.popup.background.out_now();
                            return;
                        }

                        var tl_x = self.node.top_left_x;
                        var tl_y = self.node.top_left_y;

                        for (var xx = 0; xx < self.node.prototype.size.x; xx += 2) {
                            for (var yy = 0; yy < self.node.prototype.size.y; yy += 2) {
                                if random(1) > 0.5 {
                                    create_animation_effect(
                                        (tl_x + xx) * 8,
                                        (tl_y + yy) * 8,
                                        -1000,
                                        spr_fx_poof1_dirt_once
                                    );
                                }
                            }
                        }

                        var item_x = (tl_x + self.node.prototype.size.x / 2) * 8;
                        var item_y = (tl_y + self.node.prototype.size.y / 2) * 8;
                        var bp_item_spawner = self.node.prototype.blueprints[self.node.variant];
                        var bp = BLUEPRINT_PROTOTYPES[ITEM_PROTOTYPES[bp_item_spawner].blueprint.blueprint];

                        var keys = struct_get_names(bp.turn_in_box_recipe);
                        for (var i = 0; i < array_length(keys); i++) {
                            var item_id = real(keys[i]);
                            var list = List();
                            repeat bp.turn_in_box_recipe[$ keys[i]] {
                                list.push(new LiveItem(item_id));
                            }

                            drop_item_stack(
                                item_x + irandom_range(-8, 8),
                                item_y + irandom_range(-8, 8),
                                list,
                            );
                        }
                        drop_item(bp_item_spawner, item_x, item_y);

                        var node_tick = irandom(I32_MAX);
                        var d_grid = DYNAMIC_GRIDS.get(self.node.dyn_index);

                        switch self.node.prototype.player_building_kind {
                            case PlayerBuildingKind.Stable:
                                for (var xx = 0; xx < d_grid.dims.x; xx++) {
                                    for (var yy = 0; yy < d_grid.dims.y; yy++) {
                                        var node_check = d_grid.node_index_for_cell(xx, yy);

                                        //
                                        if object_id_to_object_category(d_grid.node_object_id[node_check]) == ObjectCategory.Furniture
                                            && d_grid.node_parent[node_check].prototype.interaction_chest != undefined
                                            && d_grid.node_parent[node_check].last_update != node_tick
                                        {
                                            for (var j = 0; j < d_grid.node_parent[node_check].inventory.size(); j++) {
                                                var slot = d_grid.node_parent[node_check].inventory.slot(j);
                                                if slot.item != undefined {
                                                    var items = slot.drain();
                                                    drop_item_stack(item_x, item_y, items);
                                                }
                                            }
                                            d_grid.node_parent[node_check].last_update = node_tick;

                                            continue;
                                        }

                                        //
                                        if d_grid.node_parent[node_check] != undefined
                                            && d_grid.node_parent[node_check].object_id == ObjectId.OcarinaSpriteStatueBase
                                            && d_grid.node_parent[node_check].last_update != node_tick
                                        {
                                            var s_grid = d_grid.node_parent[node_check].child_grid;
                                            for (var xxs = 0; xxs < s_grid.dims.x; xxs++) {
                                                for (var yys = 0; yys < s_grid.dims.y; yys++) {
                                                    var sni = s_grid.node_index_for_cell(xxs, yys);
                                                    if s_grid.node_object_id[sni] == ObjectId.OcarinaSpriteStatue
                                                        && s_grid.node_parent[sni].last_update != node_tick
                                                    {
                                                            d_grid.node_parent[node_check].last_update = node_tick;
                                                            s_grid.node_parent[sni].last_update = node_tick;
                                                            drop_item(ItemId.OcarinaSpriteStatue, item_x + irandom_range(-8, 8), item_y + irandom_range(-8, 8));
                                                            drop_item(essence_get_change(s_grid.node_parent[sni]), item_x + irandom_range(-8, 8), item_y + irandom_range(-8, 8));
                                                            break;
                                                    }
                                                }
                                            }

                                            continue;
                                        }
                                    }
                                }

                                //
                                if d_grid.auto_feeder != undefined {
                                    for (var j = 0; j < d_grid.auto_feeder.inventory.size(); j++) {
                                        var slot = d_grid.auto_feeder.inventory.slot(j);
                                        if slot.item != undefined {
                                            var items = slot.drain();
                                            drop_item_stack(item_x, item_y, items);
                                        }
                                    }
                                    drop_item(ItemId.AutoFeeder, item_x + irandom_range(-8, 8), item_y + irandom_range(-8, 8));
                                }
                                break;
                            case PlayerBuildingKind.Greenhouse:
                            case PlayerBuildingKind.MiniMuseum:
                                var lost_items = List();
                                poof_furniture_to_items(
                                    lost_items,
                                    item_x,
                                    item_y,
                                    d_grid,
                                    0,
                                    0,
                                    d_grid.dims.x,
                                    d_grid.dims.y,
                                );
                                restore_lost_items(lost_items);
                                break;
                        }

                        //
                        for (var i = 0; i < d_grid.lost_items.count(); i++) {
                            var lost_item = d_grid.lost_items.get(i);
                            lost_item.x = item_x + irandom_range(-8, 8);
                            lost_item.y = item_y + irandom_range(-8, 8);
                        }
                        restore_lost_items(d_grid.lost_items);
                        d_grid.lost_items.clear();

                        erase_object_node_by_parent(GRID, self.node);
                    }, [wrapper]);


                    wrapper.option("misc_local/close", function() {});
                },
            );
        },
    }
);
