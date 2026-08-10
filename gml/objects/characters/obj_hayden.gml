object_create(
    "obj_hayden",
    object_reserve("par_NPC"),
    {
        sprite_index: spr_npc_mask,
        step: function() {
            event_inherit(ObjectEvent.Step);

            //
            if MIST.is_running() && MIST.active_cutscene.id == "farm_introduction" {
                shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));
            }
        },
    }
);
