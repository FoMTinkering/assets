object_create(
    "obj_pq_door",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_priestess_quarters_doorway_main_sealed,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.register_interaction(
                InputId.Interact,
                "misc_local/unlock_door",
                function() {
                    ARI.inventory.remove(ItemId.MagicKey);
                    MIST.run_scene("priestess_quarters_pt_2");
                    self.sprite_index = spr_priestess_quarters_doorway_main_opening;
                },
                function() {
                    return ARI.inventory.item_id_quantity(ItemId.MagicKey) > 0;
                }
            );

            self.depth = get_instance_depth(self.y);

            self.sprite_index = world_mod_enabled(WorldMod.PriestessQuartersMainDoor)
                ? spr_priestess_quarters_doorway_main_open
                : spr_priestess_quarters_doorway_main_sealed;

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });
        },
        animation_end: function() {
            if self.sprite_index == spr_priestess_quarters_doorway_main_opening {
                self.sprite_index = spr_priestess_quarters_doorway_main_open;
            }
        },
    }
);
