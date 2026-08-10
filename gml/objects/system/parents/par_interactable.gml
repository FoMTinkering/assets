object_create(
    "par_interactable",
    undefined,
    {
        sprite_index: undefined,
        selection_priority: 0,
        create: function() {
            self.highlighter = new Highlighter();
            self.bouncer = new InteractBouncer();
            self.interactions = List();
            self.override_mask = undefined;

            //
            if self.object_index != obj_node_renderer {
                register_interactable(self);
            }

            self.interactable_mode = InteractableMode.Bbox;
            self.circle_size = 0;
            self.offset_with_cardinal = false;
            self.allowed_in_fire_spell = false;

            function register_interaction(input_id, local_key, callback, can_interact_callback, take_press=true) {
                self.interactions.push({
                    input_id: input_id,
                    local_key: local_key,
                    callback: callback,
                    can_interact_callback: can_interact_callback != undefined ? can_interact_callback : function() { return true },
                    take_press,
                });
                return self;
            }

            function attempt_interact(force_press=false) {
                //
                if ARI.fire_breath_time > 0 && self.allowed_in_fire_spell == false {
                    return undefined;
                }

                var output = undefined;

                //
                //
                //
                for (var i = 0, c = self.interactions.count(); i < c; i++) {
                    var interaction = self.interactions.get(i);

                    if interaction.can_interact_callback() == false {
                        continue;
                    }

                    GLYPH_GUIDE.set_input(interaction.input_id, interaction.local_key);

                    self.highlighter.request_highlight_mode = true;
                    self.bouncer.request_bounce = true;

                    var pressed = interaction.take_press
                        ? INPUT.take_press(interaction.input_id)
                        : INPUT.pressed(interaction.input_id);

                    if pressed || force_press {
                        //
                        if instance_exists(obj_ari) {
                            obj_ari.buffered_player_cmp_and_take(interaction.input_id);
                        }
                        output = interaction.callback;
                        force_press = false;
                    }
                }

                return output;
            }

            //
            //
            function has_potential_interactions() {
                for (var i = 0, c = self.interactions.count(); i < c; i++) {
                    var interaction = self.interactions.get(i);
                    if interaction.can_interact_callback() {
                        return true;
                    }
                }
                return false;
            }
        },
        draw: function() {
            if sprite_index != undefined && sprite_index != -1 {
                if highlighter.update(x, y) && MIST.running == false {
                    gpu_set_extra(UberShaderKind.Overlay);
                    draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, 0, self.highlighter.color, self.highlighter.strength);
                    gpu_reset_extra();
                } else {
                    draw_self();
                }
            }
        },
        destroy: function() {
            var pos = INTERACTABLES.find_lazy(self.id);
            if pos != undefined {
                INTERACTABLES.set(pos, undefined);
            }
        },
    }
);
