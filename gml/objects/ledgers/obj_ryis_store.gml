object_create(
    "obj_ryis_store",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_generalstore_store_ledger_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.darkness_sprite = spr_generalstore_store_ledger_darkness;
            self.name = "ryis_store";

            function spawn_menu() {
                self.mcp = new MultipleChoicePopup("stores/carpenter/name", spr_ui_generic_icon_npc_ryis);
                self.mcp.option("misc_local/shop", function() {
                    var shop = ANCHOR.spawn_menu(Menu.Store, Store.Carpenter);
                    shop.background.in_now();
                    self.mcp.popup.background.out_now();

                    shop.on_free = function() {
                        var menu = ANCHOR.get_menu(Menu.Store);
                        if menu.tooltip != undefined {
                            menu.tooltip.close();
                        }
                        self.spawn_menu();
                    }
                });

                if DECOR.upper_floor == false {
                    var all_home_upgrades = DECOR.size_upgrade == HomeUpgrade.LargeWestEast;
                    var can_buy_floor_two = QUEST_LOG.completed.contains("upgrade_the_carpenters_shop")
                        && DECOR.upper_floor == false && DECOR.size_upgrade == HomeUpgrade.LargeWestEast;

                    self.mcp.option("misc_local/home_upgrade", function(can_buy_floor_two) {
                        var popup_text = undefined;
                        if can_buy_floor_two {
                            popup_text = "misc_local/home_upgrade_four";
                        } else {
                            var next_upgrade = DECOR.size_upgrade + 1;
                            switch next_upgrade {
                                case HomeUpgrade.Large:
                                    popup_text = "misc_local/home_upgrade_one";
                                    break;
                                case HomeUpgrade.LargeWest:
                                    popup_text = "misc_local/home_upgrade_two";
                                    break;
                                case HomeUpgrade.LargeWestEast:
                                    popup_text = "misc_local/home_upgrade_three";
                                    break;
                                default: impossible("Not set up for {HomeUpgrade}", next_upgrade);
                            }
                        }

                        var next_upgrade = DECOR.size_upgrade + 1;

                        var popup = popup_creator(popup_text, "misc_local/ok");

                        popup.body_text.disable(); //
                        popup.body.set_align(Align.Center, Align.BottomIn)
                            .set_y(-32)

                        var sprite = string_to_asset(format("spr_ui_player_house_{}_preview", DECOR.size_upgrade + 2));
                        ANCHOR.sprite(popup.header)
                            .set_sprite(sprite)
                            .set_align(Align.Center, Align.BottomOut)
                            .set_y(4)

                        var upgrade_data = can_buy_floor_two ? DECOR.upper_floor_sell_data : DECOR.sell_data[next_upgrade];
                        var listings = List(Listing.Gold(upgrade_data.gold_cost));

                        for (var i = 0, c = upgrade_data.requirements.count(); i < c; i++) {
                            var data = upgrade_data.requirements.get(i);
                            var listing = Listing.Item(data.item_id, ARI.inventory, data.quantity);

                            listings.push(listing);
                        }

                        var yy = 0;
                        var max_width = 113;
                        for (var i = 0; i < listings.count(); i++) {
                            var listing = listings.get(i);
                            var root = ANCHOR.positional(popup.body)
                                .set_width(161)
                                .set_y(yy)

                            var root_height = render_quest_requirement(listing, root, max_width).name.measure().y + 8;
                            root.set_height(root_height);
                            yy += root_height;
                        }

                        popup.body.set_height(yy);
                        popup.refresh_backplate_height();
                        popup.backplate.add_height(can_buy_floor_two ? 76 : 64);


                        var can_fulfill = true;
                        for (var i = 0; i < listings.count(); i++) {
                            var listing = listings.get(i);
                            if !can_fulfill_listing(listing) {
                                can_fulfill = false;
                            }
                        }

                        popup.create_button("misc_local/cancel", function() {
                            await_popup(function() {
                                self.spawn_menu();
                            })
                        });

                        var button = popup.create_button("misc_local/buy", function(can_buy_floor_two) {
                            var next_upgrade = DECOR.size_upgrade + 1;
                            var upgrade_data = can_buy_floor_two
                                ? DECOR.upper_floor_sell_data
                                : DECOR.sell_data[next_upgrade];

                            if !can_buy_floor_two {
                                DECOR.apply_house_upgrade(GRIDS[LocationId.PlayerHome], next_upgrade);
                            } else {
                                DECOR.upper_floor = true;
                            }

                            for (var i = 0, c = upgrade_data.requirements.count(); i < c; i++) {
                                var data = upgrade_data.requirements.get(i);
                                ARI.inventory.remove(data.item_id, data.quantity);
                            }

                            ARI.modify_gold(-upgrade_data.gold_cost);

                            array_push(GAME_STATS.home_upgrades, {
                                upgrade: can_buy_floor_two ? "upper_floor" : home_upgrade_to_string(next_upgrade),
                                day: total_days(),
                            });

                            refresh_achievements([Requirement.HasHomeUpgrade, Requirement.HasUpperFloor]);

                            await_popup(function() {
                                var pop = popup_creator("misc_local/house_upgraded", "misc_local/house_upgraded_description");
                                pop.create_button("misc_local/close");
                                pop.spawn();

                                await_popup(function() {
                                    self.spawn_menu();
                                })

                            })

                        }, [can_buy_floor_two]);

                        button.set_unlocked(can_fulfill);

                        popup.spawn();
                    }, [can_buy_floor_two]);
                    self.mcp.buttons.last().set_unlocked(!all_home_upgrades || can_buy_floor_two);
                } else {
                    self.mcp.option("misc_local/customize_home", function(can_buy_floor_two) {
                        var cost = fiddle_get("misc/home_variant_cost");

                        var popup = popup_creator("misc_local/customize_home", "misc_local/ok");
                        popup.body_text.disable(); //
                        popup.body.set_align(Align.Center, Align.BottomIn)
                            .set_y(-32)

                        popup.set_to = method(popup, function(variant) {
                            var cost = fiddle_get("misc/home_variant_cost");
                            var can_fulfill = ARI.get_gold() >= cost;
                            self.current_variant = variant;
                            self.buttons.get(1).set_soft_locked(!can_fulfill || DECOR.variant == variant);
                            var sprite = home_variant_preview_sprite(variant);
                            self.name.set_key(format("misc_local/{HomeVariant}", variant));
                            self.preview.set_sprite(sprite);
                        });

                        var listing = Listing.Gold(cost);
                        var max_width = 113;
                        var root = ANCHOR.positional(popup.body)
                            .set_width(161)

                        var root_height = render_quest_requirement(listing, root, max_width).name.measure().y + 8;
                        root.set_height(root_height);

                        popup.body.set_height(root_height);

                        popup.preview = ANCHOR.sprite(popup.header)
                            .set_align(Align.Center, Align.BottomOut)
                            .set_y(4)

                        var name_backplate = ANCHOR.nine_slice(popup.body)
                            .set_sprite(spr_ui_journal_magic_rounded_text_box)
                            .set_size(117, 16)
                            .set_align(Align.Center, Align.TopOut)
                            .set_y(-9)

                        popup.name = ANCHOR.text(name_backplate)
                            .set_lut(COMMON_LUT)
                            .set_align(Align.Center, Align.Middle)

                        var arrow_left_button = ANCHOR.nine_slice(name_backplate)
                            .set_sprites_from_key("spr_ui_calendar_button_spring") //
                            .set_size(16)
                            .set_align(Align.LeftOut, Align.Middle)
                            .add_glyph(InputId.MenuTabLeft, undefined, true)
                            .set_tap_sound("SoundEffects/UI/UIJournalTabSwitch")
                            .set_x(-4)
                            .set_tap_callback(function(popup) {
                                popup.set_to(wrap(popup.current_variant - 1, HomeVariant.LEN))
                            }, [popup])

                        var arrow_left_icon = ANCHOR.sprite(arrow_left_button)
                            .set_align(Align.Center, Align.Middle)
                            .set_sprites_from_key("spr_ui_calendar_left_arrow_spring")
                            .set_key_sprite_target(arrow_left_button)

                        var arrow_right_button = ANCHOR.nine_slice(name_backplate)
                            .set_sprites_from_key("spr_ui_calendar_button_spring")
                            .set_size(16)
                            .set_align(Align.RightOut, Align.Middle)
                            .add_glyph(InputId.MenuTabRight, undefined, true)
                            .set_tap_sound("SoundEffects/UI/UIJournalTabSwitch")
                            .set_x(4)
                            .set_tap_callback(function(popup) {
                                popup.set_to(wrap(popup.current_variant + 1, HomeVariant.LEN))
                            }, [popup])

                        var arrow_right_icon = ANCHOR.sprite(arrow_right_button)
                            .set_align(Align.Center, Align.Middle)
                            .set_sprites_from_key("spr_ui_calendar_right_arrow_spring")
                            .set_key_sprite_target(arrow_right_button)

                        popup.refresh_backplate_height();
                        popup.backplate.add_height(104);

                        popup.create_button("misc_local/cancel", function() {
                            await_popup(function() {
                                self.spawn_menu();
                            })
                        });

                        var button = popup.create_button("misc_local/buy", function(popup, cost) {
                            DECOR.variant = popup.current_variant;
                            ARI.modify_gold(-cost);
                            await_popup(function() {
                                self.spawn_menu();
                            })
                        }, [popup, cost]);

                        popup.spawn();

                        popup.set_to(HomeVariant.StoneCottage);
                    });
                }

                self.mcp.option("misc_local/farm_expansion", function() {
                    var popup = popup_creator("misc_local/farm_expansion", "misc_local/ok");
                    popup.body_text.disable();
                    popup.body.set_align(Align.Center, Align.BottomIn)
                        .set_y(-32)

                    ANCHOR.sprite(popup.header)
                        .set_sprite(EXPANSION_COST.preview)
                        .set_align(Align.Center, Align.BottomOut)
                        .set_y(4)

                    var yy = 0;

                    var listings = List(Listing.Gold(EXPANSION_COST.gold));

                    for (var i = 0, ic = EXPANSION_COST.items.count(); i < ic; i++) {
                        var item = EXPANSION_COST.items.get(i);
                        listings.push(Listing.Item(item.item_id, ARI.inventory, item.count))
                    }

                    var max_width = 113;
                    for (var i = 0, ic = listings.count(); i < ic; i++) {
                        var listing = listings.get(i);
                        var root = ANCHOR.positional(popup.body)
                            .set_width(161)
                            .set_y(yy)

                        var root_height = render_quest_requirement(listing, root, max_width).name.measure().y + 8;
                        root.set_height(root_height);
                        yy += root_height;
                    }

                    popup.body.set_height(yy);
                    popup.refresh_backplate_height();
                    popup.backplate.add_height(64);

                    var can_fulfill = true;
                    for (var i = 0, ic = listings.count(); i < ic; i++) {
                        var listing = listings.get(i);
                        if !can_fulfill_listing(listing) {
                            can_fulfill = false;
                        }
                    }

                    popup.create_button("misc_local/cancel", function() {
                        await_popup(function() {
                            self.spawn_menu();
                        })
                    });

                    var button = popup.create_button("misc_local/buy", function() {
                        expand_farm();

                        for (var i = 0, c = EXPANSION_COST.items.count(); i < c; i++) {
                            var data = EXPANSION_COST.items.get(i);
                            ARI.inventory.remove(data.item_id, data.count);
                        }

                        ARI.modify_gold(-EXPANSION_COST.gold);

                        await_popup(function() {
                            var pop = popup_creator("misc_local/farm_expanded", "misc_local/farm_expanded_description");
                            pop.create_button("misc_local/close");
                            pop.spawn();

                            await_popup(function() {
                                self.spawn_menu();
                            });

                        })
                    });

                    button.set_unlocked(can_fulfill);

                    popup.spawn();
                });

                self.mcp.buttons.last().set_unlocked(!FARM_EXPANDED);

                self.mcp.popup.close_callback = function() {
                    if FARM_EXPANDED && !ari_has_recipe_anywhere(ItemId.FarmBridge) {
                        item_from_critical_poof(self.x + 4, self.y, new LiveItem(ItemId.CraftingScroll, ItemId.FarmBridge), 135, 225);
                        item_from_critical_poof(self.x + 4, self.y, new LiveItem(ItemId.FarmBridge), 135, 225);
                    }

                    if DECOR.upper_floor && !ari_has_recipe_anywhere(ItemId.Stairs) {
                        item_from_critical_poof(self.x + 4, self.y, new LiveItem(ItemId.CraftingScroll, ItemId.Stairs), 135, 225);
                        item_from_critical_poof(self.x + 4, self.y, new LiveItem(ItemId.Stairs), 135, 225);
                    }
                }
            }

            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    self.spawn_menu();
                },
            );

            depth = get_instance_depth(y);
        },
    }
);
