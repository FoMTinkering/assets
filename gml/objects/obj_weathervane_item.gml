object_create(
    "obj_weathervane_item",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_haydens_farm_barn_weathervane_spring,
        create: function() {
            var on_grid = false;

            var g = GRIDS[LocationId.Narrows];
            for (var i = 0, ic = g.lost_items.count(); i < ic; i++) {
                if g.lost_items.get(i).items.first().item_id == ItemId.HaydensWeathervane {
                    on_grid = true;
                    break;
                }
            }

            if !QUEST_LOG.active.contains_key("find_the_weathervane")
                || ARI.items_acquired[ItemId.HaydensWeathervane] == true
                || on_grid
            {
                instance_destroy();
                return;
            }

            event_inherit(ObjectEvent.Create);

            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    drop_item(ItemId.HaydensWeathervane, self.x, self.y);
                    instance_destroy();
                }
            );

            self.depth = get_instance_depth(self.y);
        },
    }
);
