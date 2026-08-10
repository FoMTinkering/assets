object_create(
    "obj_mist_spot",
    object_reserve("par_interactable"),
    {
        sprite_index: undefined,
        create: function() {
            event_inherit(ObjectEvent.Create);

            function spawn_item() {
                repeat (array_length(MIST_SIGHT) * 2) {
                    var item = MIST_SIGHT[irandom_range(0, array_length(MIST_SIGHT) - 1)];
                    if item.item_id == ItemId.Cosmetic && !ari_has_cosmetic_anywhere(item.inner_data) {
                        var lv = new LiveItem(item.item_id);
                        lv.cosmetic = item.inner_data;
                        item_from_critical_poof(self.x, self.y - 10, lv);
                        GAME_STATS.perks[$ perk_to_string(Perk.MistSight)] += 1;
                        break;
                    } else if item.item_id == ItemId.RecipeScroll && !ari_has_recipe_anywhere(item.inner_data) {
                        item_from_critical_poof(self.x, self.y - 10, new LiveItem(item.item_id, item.inner_data));
                        GAME_STATS.perks[$ perk_to_string(Perk.MistSight)] += 1;
                        break;
                    } else if item.item_id == ItemId.UnidentifiedArtifact {
                        if ARI.items_acquired[item.inner_data] == false {
                            item_from_critical_poof(self.x, self.y - 10, new LiveItem(ItemId.UnidentifiedArtifact, item.inner_data));
                            GAME_STATS.perks[$ perk_to_string(Perk.MistSight)] += 1;
                            break;
                        } else {
                            item_from_critical_poof(self.x, self.y - 10, new LiveItem(item.inner_data));
                            GAME_STATS.perks[$ perk_to_string(Perk.MistSight)] += 1;
                            break;
                        }
                    } else if item.item_id != ItemId.Cosmetic && item.item_id != ItemId.RecipeScroll && item.item_id != ItemId.UnidentifiedArtifact {
                        item_from_critical_poof(self.x, self.y - 10, new LiveItem(item.item_id));
                        GAME_STATS.perks[$ perk_to_string(Perk.MistSight)] += 1;
                        break;
                    }
                }
            }

            set_close = undefined;
            in_idle = true;
            destruction_sequence = false;
            timer_and_event = undefined;

            sprite_index = spr_misty_spot_main_closed_idle;
            shadow_caster = SHADOW_GRID.caster_create(x, y);
            depth = get_instance_depth(y);
            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    obj_ari.set_cardinal(sign(obj_ari.x - self.x) == 1 ? Cardinal.West : Cardinal.East);
                    obj_ari.fsm.change_state(PlayerState.AnimateAndThen);
                    obj_ari.fsm.blackboard.set("animation", AnimationName.Action);
                    obj_ari.fsm.blackboard.set("hold_animation_forever", false);
                    obj_ari.fsm.blackboard.set("only_south", false);
                    self.in_idle = false;
                    ARI.modify_essence(-10);

                    self.timer_and_event = [30, function() {
                        sprite_index = spr_misty_spot_main_closing;
                        image_index = 0;
                        image_speed = 1;
                        shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));

                        self.timer_and_event = [25, function() {
                            TANGO.play("SoundEffects/Objects/MistySpotDisappear", self.x, self.y);
                            CAMERA.add_trauma(0.5);
                            spawn_item();
                        }];
                    }];

                    GAME_STATS.perks[$ perk_to_string(Perk.MistSight)] += 1;
                    TANGO.play("SoundEffects/Objects/MistySpotInteract", self.x, self.y);
                    MIST_SIGHT_ACTIVE_INDEX = undefined;
                },
                function() {
                    return ARI.get_essence() >= 10 && set_close == undefined;
                }
            );
            shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));
        },
        step: function() {
            depth = get_instance_depth(y);

            if self.in_idle {
                if image_speed == -1 && image_index <= 0.25 {
                    sprite_index = spr_misty_spot_main_closed_idle;
                    image_speed = 1;
                    shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));
                }

                //
                if sprite_index != spr_misty_spot_main_opening
                    && sprite_index != spr_misty_spot_main_open_idle
                    && self.highlighter.highlight_mode
                {
                    TANGO.play("SoundEffects/Objects/MistySpotOpen", self.x, self.y);
                    sprite_index = spr_misty_spot_main_opening;
                    image_index = 0;
                    image_speed = 1;
                    shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));
                }

                //
                if self.highlighter.highlight_mode == false
                    && image_speed != -1
                    && sprite_index != spr_misty_spot_main_closed_idle
                {
                    sprite_index = spr_misty_spot_main_opening;
                    image_index = image_number - 1;
                    image_speed = -1;
                    shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));
                }
            }

            if self.timer_and_event != undefined {
                self.timer_and_event[0] -= 1;

                if self.timer_and_event[0] <= 0 {
                    //
                    var ev = self.timer_and_event[1];
                    self.timer_and_event = undefined;
                    ev();
                }
            }

            shadow_caster_set_image(self.shadow_caster, self.image_index);
        },
        draw: function() {
            var y_pos = self.y;
            if self.in_idle {
                y_pos += sin(current_time() / 1000) * 2;
            }

            if (highlighter.update(x, y) || self.in_idle == false) && MIST.running == false {
                gpu_set_extra(UberShaderKind.Overlay);
                draw_sprite_ext(sprite_index, image_index, x, y_pos, image_xscale, image_yscale, 0, self.highlighter.color, self.highlighter.strength);
                gpu_reset_extra();
            } else {
                draw_sprite(self.sprite_index, self.image_index, self.x, y_pos);
            }
        },
        room_end: function() {

        },
        animation_end: function() {
            if sprite_index == spr_misty_spot_main_opening {
                sprite_index = spr_misty_spot_main_open_idle;
                shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));
            }

            if sprite_index == spr_misty_spot_main_closing {
                instance_destroy();
            }
        },
        cleanup: function() {
            SHADOW_GRID.caster_remove(self.shadow_caster);
        },
    }
);
