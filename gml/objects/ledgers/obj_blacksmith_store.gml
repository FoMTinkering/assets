object_create(
    "obj_blacksmith_store",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_blacksmith_ledger_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.darkness_sprite = spr_blacksmith_ledger_darkness;
            self.name = "blacksmith_store";
            self.menu = Menu.Store;

            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    ANCHOR.spawn_menu(Menu.Store, Store.Blacksmith);
                },
            );

            depth = get_instance_depth(y, -10);

            var stock = create_store_stock(Store.Blacksmith);

            for (var i = 0; i < stock.count(); i++) {
                var list = stock.get(i).items;
                for (var j = 0; j < list.count(); j++) {
                    var item = list.get(j);
                    if item.prototype.use != ItemUse.UseTool {
                        continue;
                    }

                    var pos = trellis_point(format("blacksmith_store/item_display_{ToolType}", item.prototype.tool_type));
                    if (MAXIMUM_REACHED_DUNGEON_LEVEL < 20) {
                        if !matches(item.item_id, ItemId.AxeCopper, ItemId.FishingRodCopper, ItemId.HoeCopper, ItemId.NetCopper, ItemId.PickAxeCopper, ItemId.ShovelCopper, ItemId.WateringCanCopper) {
                            continue;
                        }
                    } else if MAXIMUM_REACHED_DUNGEON_LEVEL < 40 {
                        if !matches(item.item_id, ItemId.AxeIron, ItemId.FishingRodIron, ItemId.HoeIron, ItemId.NetIron, ItemId.PickAxeIron, ItemId.ShovelIron, ItemId.WateringCanIron) {
                            continue;
                        }
                    } else if MAXIMUM_REACHED_DUNGEON_LEVEL < 60 {
                        if !matches(item.item_id, ItemId.AxeSilver, ItemId.FishingRodSilver, ItemId.HoeSilver, ItemId.NetSilver, ItemId.PickAxeSilver, ItemId.ShovelSilver, ItemId.WateringCanSilver) {
                            continue;
                        }
                    } else if !matches(item.item_id, ItemId.AxeGold, ItemId.FishingRodGold, ItemId.HoeGold, ItemId.NetGold, ItemId.PickAxeGold, ItemId.ShovelGold, ItemId.WateringCanGold) {
                        continue;
                    }

                    instance_create_depth(pos.x, pos.y, pos.y, obj_assetobject, { sprite_index: item.prototype.icon_sprite, z: -16 });
                }

            }
        },
    }
);
