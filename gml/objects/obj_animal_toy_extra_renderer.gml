object_create(
    "obj_animal_toy_extra_renderer",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            pause_frame = undefined;
        },
        draw: function() {
            if game_paused() {
                if self.pause_frame == undefined {
                    self.pause_frame = self.image_index;
                }
                self.image_index = self.pause_frame;
            } else if self.pause_frame != undefined {
                self.pause_frame = undefined;
            }

            var spr = self.node.prototype.animal_toy.extra_renderer.inactive;
            if self.node.animal_count > 0 {
                spr = self.node.prototype.animal_toy.extra_renderer.active;
            }
            draw_sprite(spr, self.node.renderer.image_index, self.node.renderer.x, self.node.renderer.y);

            shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(spr));
            shadow_caster_set_image(self.shadow_caster, self.node.renderer.image_index);
        },
        destroy: function() {
            SHADOW_GRID.caster_remove(self.shadow_caster);
        },
    }
);
