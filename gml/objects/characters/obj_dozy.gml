object_create(
    "obj_dozy",
    object_reserve("par_NPC"),
    {
        sprite_index: spr_npc_mask,
        step: function() {
            event_inherit(ObjectEvent.Step);

            //
            shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));
        },
    }
);
