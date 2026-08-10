//
#macro VITAL_ELEMENT_SPACING 2

//
enum VitalsElement {
    Health,
    Stamina,
    SpellSlots,
    StatusEffects,
}

//
enum VitalsDepth {
    SpellSlotOrb,
    SpellSlotIcon,
    StaminaText,
    StaminaPrimary,
    StaminaSecondary,
    StaminaBackplate,
    StaminaIcon,
    HealthPrimaryFlash,
    HealthText,
    HealthPrimary,
    HealthSecondaryFlash,
    HealthSecondary,
    HealthBackplate,
    HealthIcon,
    Bracket,
}

function VitalsMenu(): AnchorMenu(Menu.Vitals) constructor {
    //
    self.stamina_modify_chain = undefined;
    self.health_modify_chain = undefined;
    self.health_flash_chain = undefined;
    self.blink_chain = undefined;
    self.health_hide_chain = undefined;
    self.health_text_chain = undefined;
    self.stamina_text_chain = undefined;

    //
    self.always_show_numbers = false;

    //
    self.element_visibility = [true, true, true, true];

    //
    self.element_heights = [13, 13, 9, 16];

    //
    self.occupied_space = [
        self.element_visibility[0] ? self.element_heights[0] : 0,
        self.element_visibility[1] ? self.element_heights[1] : 0,
        self.element_visibility[2] ? self.element_heights[2] : 0,
        self.element_visibility[3] ? self.element_heights[3] : 0,
    ];

    //
    function set_stamina(value, max_stamina, instant=false) {
        var current_width = self.stamina_bar_meter_secondary.get_width();
        var max_width = self.stamina_bar_backplate.get_width() - 6;
        var new_width = clamp(value / 2, 0, max_width);

        //
        self.stamina_bar_text.set_text(string(floor(value)) + "/" + string(floor(max_stamina)));

        if new_width == current_width {
            return;
        }

        //
        self.stamina_bar_meter_primary.set_alpha(new_width == 0 ? 0 : 1);

        if instant {
            self.stamina_bar_meter_primary.set_width(new_width)
            self.stamina_bar_meter_secondary.set_width(new_width);
        } else {
            //
            if new_width < current_width {

                //
                self.stamina_bar_meter_primary.set_width(new_width)
                //

                //
                if self.stamina_modify_chain != undefined {
                    CHAINS.cancel_chain(self.stamina_modify_chain);
                }
                self.stamina_modify_chain = new_chain()
                    .join(
                        LinkId.Ease,
                        new Ease(EaseId.QuartOut, current_width, new_width, 120),
                        function (_, abs_val) {
                            self.stamina_bar_meter_secondary.set_width(abs_val);
                        }
                    )
                    .append(LinkId.Function, function() {
                        self.stamina_modify_chain = undefined;
                    });

                //
                //
                //
                //
                //
                //
                //
                //
                //
                //
                //
                //
                //
            } else {

                //
                self.stamina_bar_meter_secondary.set_width(new_width);

                //
                if self.stamina_modify_chain != undefined {
                    CHAINS.cancel_chain(self.stamina_modify_chain);
                }
                self.stamina_modify_chain = new_chain()
                    .join(
                        LinkId.Ease,
                        new Ease(EaseId.QuartOut, current_width, new_width, 75),
                        function (_, abs_val) {
                            self.stamina_bar_meter_primary.set_width(abs_val);
                        }
                    )
                    .append(LinkId.Function, function() {
                        self.stamina_modify_chain = undefined;
                    });
            }
        }

        //
        if value > max_stamina * 0.5 {
            self.stamina_icon
                .set_sprite(spr_ui_hud_health_stamina_bar_icon_good)
        } else if value <= max_stamina * 0.5 && value > max_stamina * 0.2 {
            self.stamina_icon
                .set_sprite(spr_ui_hud_health_stamina_bar_icon_tired)
        } else if value <= max_stamina * 0.2 {
            self.stamina_icon
                .set_sprite(spr_ui_hud_health_stamina_bar_icon_sleepy)
        }
    }

    //
    function set_health(value, max_health, instant=false) {
        var current_width = self.health_bar_meter_secondary.get_width();
        var max_width = self.health_bar_backplate.get_width() - 6;
        var new_width = clamp(value / 2, 0, max_width);

        //
        self.health_bar_text.set_text(string(floor(value)) + "/" + string(floor(max_health)));

        //
        self.health_bar_meter_primary.set_alpha(new_width == 0 ? 0 : 1);

        //
        if new_width != current_width && self.element_visibility[VitalsElement.Health] == false {
            self.show_element(VitalsElement.Health, instant);
        }

        if instant {
            self.health_bar_meter_primary.set_width(new_width);
            self.health_bar_meter_secondary.set_width(new_width);
        } else {
            //
            if new_width < current_width {

                //
                self.health_bar_meter_primary.set_width(new_width)
                self.health_bar_meter_primary_flash.set_width(new_width)
                self.health_bar_meter_primary_flash.set_alpha(new_width == 0 ? 0 : 1);

                //
                if self.health_modify_chain != undefined {
                    CHAINS.cancel_chain(self.health_modify_chain);
                }
                self.health_modify_chain = new_chain()
                    .join(
                        LinkId.Ease,
                        new Ease(EaseId.QuartOut, current_width, new_width, 120),
                        function (_, abs_val) {
                            self.health_bar_meter_secondary.set_width(abs_val);
                        }
                    )
                    .append(LinkId.Function, function() {
                        self.health_modify_chain = undefined;
                    });

                //
                if self.health_flash_chain != undefined {
                    CHAINS.cancel_chain(self.health_flash_chain);
                }
                self.health_flash_chain = new_chain()
                    .append(LinkId.Function, function() {
                        self.health_bar_meter_primary_flash.set_alpha(1);
                    })
                    .append(LinkId.Timer, 8)
                    .append(LinkId.Function, function() {
                        self.health_bar_meter_primary_flash.set_alpha(0);
                        self.health_flash_chain = undefined;
                    })
            } else {

                //
                self.health_bar_meter_secondary.set_width(new_width);
                //

                //
                if self.health_modify_chain != undefined {
                    CHAINS.cancel_chain(self.health_modify_chain);
                }
                self.health_modify_chain = new_chain()
                    .join(
                        LinkId.Ease,
                        new Ease(EaseId.QuartOut, current_width, new_width, 75),
                        function (_, abs_val) {
                            self.health_bar_meter_primary.set_width(abs_val);
                        }
                    )
                    .append(LinkId.Function, function() {
                        self.health_modify_chain = undefined;
                    });
            }
        }

        //
        if value <= max_health * 0.25 {
            self.health_icon
                .set_sprite(spr_ui_hud_health_health_bar_icon_low_health)
                .set_speed(1)
        } else {
            self.health_icon
                .set_sprite(spr_ui_hud_health_health_bar_icon_normal_health)
                .set_speed(0)
        }

        //
        if new_width == max_width && !is_dungeon_room(room()) && self.element_visibility[VitalsElement.Health] {
            if self.health_hide_chain != undefined {
                CHAINS.cancel_chain(self.health_hide_chain);
            }
            if instant {
                self.hide_element(VitalsElement.Health, instant);
            } else {
                self.health_hide_chain = new_chain()
                    .join(LinkId.Timer, 180)
                    .append(LinkId.Function, function() {
                        self.health_hide_chain = undefined;

                        //
                        //
                        if self.element_visibility[VitalsElement.Health] {
                            self.hide_element(VitalsElement.Health);
                        }
                    });
            }
        }
    }

    //
    function set_mana(value, max_slots) {
        self.set_max_mana(max_slots);
        if max_slots > 0 {
            if self.element_visibility[VitalsElement.SpellSlots] == false {
                self.show_element(VitalsElement.SpellSlots);
            }
            var orbs = [self.orb_one, self.orb_two, self.orb_three, self.orb_four];
            for (var i = 0; i < array_length(orbs); i++) {
                var base_mana = i * 4;
                var sprite;
                if value <= base_mana {
                    sprite = spr_ui_hud_health_mana_ball_off;
                } else if value == base_mana + 1 {
                    sprite = spr_ui_hud_health_mana_ball_threethirds;
                } else if value == base_mana + 2 {
                    sprite = spr_ui_hud_health_mana_ball_half;
                } else if value == base_mana + 3 {
                    sprite = spr_ui_hud_health_mana_ball_onequarter;
                } else if value >= base_mana + 4 {
                    sprite = spr_ui_hud_health_mana_ball_on;
                }
                orbs[i].set_sprite(sprite);
            }
        } else if self.element_visibility[VitalsElement.SpellSlots] == true {
            self.hide_element(VitalsElement.SpellSlots);
        }
    }

    //
    function set_max_health(value) {
        var width = floor(value / 2);
        self.health_bar_backplate.set_width(width + 6);
        //
        //
        //
        //
    }

    //
    function set_max_stamina(value) {
        var width = floor(value / 2);
        self.stamina_bar_backplate.set_width(width + 6);
        //
        //
    }

    //
    function set_max_mana(value) {
        self.orb_one.set_enabled(value > 0);
        self.orb_two.set_enabled(value > 4);
        self.orb_three.set_enabled(value > 8);
        self.orb_four.set_enabled(value > 12);
    }

    //
    function get_root_node_for_element(element) {
        switch element {
            case VitalsElement.Health: return self.health_icon;
            case VitalsElement.Stamina: return self.stamina_icon;
            case VitalsElement.SpellSlots: return self.mana_icon;
            case VitalsElement.StatusEffects: return self.status_effect_root;
            default: impossible("Unexpected VitalsElement: {}", element);
        }
    }

    //
    function show_element(element, instant) {
        assert_eq(self.element_visibility[element], false);
        self.element_visibility[element] = true;
        var node = self.get_root_node_for_element(element);
        node.enable();
        if instant == true {
            node.set_alpha(1);
            self.occupied_space[element] = self.element_heights[element];
            return;
        }
        new_chain()
            .join(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, 0, 1, FADE_SPEED),
                function(delta, _a, node) {
                    node.add_alpha(delta);
                },
                [node]
            )
            .join(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, 0, self.element_heights[element], FADE_SPEED),
                function(delta, _a, element) {
                    self.occupied_space[element] += delta;
                },
                [element]
            )
    }

    //
    function hide_element(element, instant) {
        assert_eq(self.element_visibility[element], true);
        self.element_visibility[element] = false;
        var node = self.get_root_node_for_element(element);
        if instant == true {
            node.set_alpha(0);
            node.disable();
            self.occupied_space[element] = 0;
            return;
        }
        new_chain()
            .join(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, 1, 0, FADE_SPEED),
                function(delta, _a, node) {
                    node.add_alpha(delta);
                },
                [node]
            )
            .join(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, self.element_heights[element], 0, FADE_SPEED),
                function(delta, _a, element) {
                    self.occupied_space[element] += delta;
                },
                [element]
            )
            .append(LinkId.Function, function(node) {
                node.disable();
            }, [node])
    }

    //
    //
    function get_y_for_element(element) {
        //
        var yy = 0;
        for (var i = 0; i < element; i++) {
            yy += self.occupied_space[i];
            yy += VITAL_ELEMENT_SPACING;
        }
        return yy;
    }

    //
    function set_number_visibility(vis) {
        if vis {
            self.always_show_numbers = true;
            if self.health_text_chain != undefined {
                CHAINS.cancel_chain(self.health_text_chain);
            }
            if self.stamina_text_chain != undefined {
                CHAINS.cancel_chain(self.health_text_chain);
            }
            self.health_bar_text.set_alpha(1);
            self.stamina_bar_text.set_alpha(1);
        } else {
            self.always_show_numbers = false;
        }
    }

    //
    //
    //
    //
    //
    //
    //
    function register_status(status_effect) {
        var state = {
            status: status_effect,
            pulse_sign: 1,
            timer: 20,
            ease: undefined,
        }
        self.status_states.push(state);
        self.refresh_statuses();
    }

    //
    //
    function refresh_statuses() {
        ANCHOR.free_children(self.status_effect_root);
        var xx = 0;
        var yy = 0;
        var effects = []
        for (var i = 0; i < self.status_states.count(); i++) {
            var state = self.status_states.get(i);
            if state.status.finish < CALENDAR.unified_time() {
                self.status_states.remove(i);
                i -= 1;
                continue;
            }

            if array_contains(effects, state.status.type) {
                continue;
            }

            var icon_sprite;
            var color = make_color_rgb(240, 141, 46);
            switch state.status.type {
                case StatusEffectId.GuardiansShield:
                    icon_sprite = spr_ui_statuseffect_icon_shield_idle;
                    break;
                case StatusEffectId.MineTime:
                    icon_sprite = spr_ui_statuseffect_icon_mine_time;
                    break;
                case StatusEffectId.SlimeDash:
                    icon_sprite = spr_ui_statuseffect_icon_quickfooted;
                    break;
                case StatusEffectId.KillHaste:
                    icon_sprite = spr_ui_statuseffect_icon_quickfooted;
                    break;
                case StatusEffectId.ShrineBoon:
                    icon_sprite = spr_ui_statuseffect_icon_shrine_savant;
                    break;
                case StatusEffectId.FlameBreath:
                    icon_sprite = spr_ui_statuseffect_icon_dragons_breath;
                    break;
                case StatusEffectId.SacredLight:
                    icon_sprite = spr_ui_statuseffect_icon_sacred_light;
                    break;

                default:
                    var demons = string_to_infusion(status_effect_id_to_string(state.status.type));
                    var infusion_data = INFUSIONS.get(demons);
                    icon_sprite = infusion_data.tooltip_icon;
                    color = make_color_rgb(
                        infusion_data.color[0],
                        infusion_data.color[1],
                        infusion_data.color[2],
                    );
                    break;
                }

            var icon = ANCHOR.sprite(self.status_effect_root);
            icon
                .set_xy(xx, yy)
                .set_sprite(icon_sprite)
                .set_think_callback(function(icon, state) {
                    //
                    var pulse_time = (state.status.finish - state.status.start) * 0.10;
                    var near_completion = state.status.finish - CALENDAR.unified_time() <= pulse_time;
                    if near_completion {
                        if state.timer >= 20 {
                            state.timer = 0;
                            var min_a = 0.6;
                            var max_a = 0.8;
                            if state.pulse_sign == 1 {
                                state.pulse_sign = -1;
                                state.ease = new Ease(EaseId.Linear, max_a, min_a, state.timer);
                            } else {
                                state.pulse_sign = 1;
                                state.ease = new Ease(EaseId.Linear, min_a, max_a, state.timer);
                            }
                        }
                        icon.set_alpha(state.ease.calculate_value(state.timer));
                        state.timer += 1;
                    }

                    //
                    if state.status.finish < CALENDAR.unified_time() {
                        self.refresh_statuses();
                    }
                }, [icon, state]);

            if state.status.finish == I32_MAX {
                xx += icon.get_width() + 2;
                continue;
            }

            var lower_bar = ANCHOR.nine_slice(icon)
                .set_align(Align.LeftIn, Align.BottomOut)
                .set_sprite(spr_ui_statuseffect_bar_back)
                .set_color(c_black)
                .set_y(1)
                .set_size(18, 6)

            //
            //
            var bar_count = lower_bar.get_height() - 2; //
            var full_width = lower_bar.get_width() - 2; //
            for (var j = 0; j < bar_count; j++) {
                var bar = ANCHOR.nine_slice(lower_bar);
                bar
                    .set_sprite(spr_ui_statuseffect_bar_front)
                    .set_xy(1, 1 + j)
                    .set_size(full_width, 1)
                    .set_color(color)
                    .set_think_callback(function(bar, state, index, full_width, bar_count) {
                        //
                        //
                        //
                        var total_expressable_units = full_width * bar_count;

                        //
                        var total_length = state.status.finish - state.status.start;

                        //
                        var length_of_one_unit = total_length / total_expressable_units;

                        //
                        var time_left = state.status.finish - CALENDAR.unified_time();

                        //
                        //
                        //
                        time_left -= length_of_one_unit * index;

                        //
                        var percent = time_left / total_length;

                        //
                        var width = ceil(full_width * percent);

                        //
                        bar.set_width(width);
                    }, [bar, state, j, full_width, bar_count])
            }

            xx += 20;

            array_push(effects, state.status.type);
        }

    }

    function on_think() {
        self.health_icon.set_y(self.get_y_for_element(VitalsElement.Health));
        self.stamina_icon.set_y(self.get_y_for_element(VitalsElement.Stamina));
        self.mana_icon.set_y(self.get_y_for_element(VitalsElement.SpellSlots));
        self.status_effect_root.set_y(self.get_y_for_element(VitalsElement.StatusEffects) + 3);

        if self.always_show_numbers {
            return;
        }

        var target = ANCHOR.point_in_node(self.health_bar_backplate, MOUSE_GUI_X, MOUSE_GUI_Y);
        var alpha = lerp(self.health_bar_text.get_alpha(), target, 0.25);
        self.health_bar_text.set_alpha(alpha);

        var target = ANCHOR.point_in_node(self.stamina_bar_backplate, MOUSE_GUI_X, MOUSE_GUI_Y);
        var alpha = lerp(self.stamina_bar_text.get_alpha(), target, 0.25);
        self.stamina_bar_text.set_alpha(alpha);
    }

    self.root = ANCHOR.positional(self.canvas, VitalsDepth.Bracket)
        .set_xy(3, 6)
        .set_room_start_callback(function() {
            //
            if is_dungeon_room(room()) && self.element_visibility[VitalsElement.Health] == false {
                self.show_element(VitalsElement.Health, true);
            }
        })

    self.health_icon = ANCHOR.sprite(self.root, VitalsDepth.HealthIcon)
        .set_sprite(spr_ui_hud_health_health_bar_icon_normal_health)


    self.health_bar_backplate = ANCHOR.nine_slice(self.health_icon, VitalsDepth.HealthBackplate)
        .set_xy(13, 0)
        .set_sprite(spr_ui_hud_health_health_bar_backplate)
        .set_align(Align.LeftIn, Align.Middle)
        .set_size(56, self.element_heights[VitalsElement.Health])

    self.health_bar_meter_secondary = ANCHOR.nine_slice(self.health_bar_backplate, VitalsDepth.HealthSecondary)
        .set_xy(3, 2)
        .set_sprite(spr_ui_hud_health_bar_white)
        .set_size(50, 9)
        .set_color(make_color_rgb(111, 23, 49))

    self.health_bar_meter_secondary_flash = ANCHOR.nine_slice(self.health_bar_backplate, VitalsDepth.HealthSecondaryFlash)
        .set_xy(3, 2)
        .set_sprite(spr_ui_hud_health_bar_white)
        .set_size(50, 9)
        .set_alpha(0)
        .set_color(make_color_rgb(255, 175, 209))

    self.health_bar_meter_primary = ANCHOR.nine_slice(self.health_bar_backplate, VitalsDepth.HealthPrimary)
        .set_xy(3, 2)
        .set_sprite(spr_ui_hud_health_health_bar)
        .set_size(50, 9)

    self.health_bar_text = ANCHOR.text(self.health_bar_backplate, VitalsDepth.HealthText)
        .set_align(Align.Center, Align.Middle)
        .set_sprite_font("vitals_label")
        .set_alpha(0)

    self.health_bar_meter_primary_flash = ANCHOR.nine_slice(self.health_bar_backplate, VitalsDepth.HealthPrimaryFlash)
        .set_xy(3, 2)
        .set_sprite(spr_ui_hud_health_bar_damage)
        .set_size(50, 9)
        .set_alpha(0)
        .set_color(make_color_rgb(255, 175, 209))

    self.stamina_icon = ANCHOR.sprite(self.root, VitalsDepth.StaminaIcon)
        .set_sprite(spr_ui_hud_health_stamina_bar_icon_good)

    self.stamina_bar_backplate = ANCHOR.nine_slice(self.stamina_icon, VitalsDepth.StaminaBackplate)
        .set_xy(13, 0)
        .set_sprite(spr_ui_hud_health_stamina_bar_backplate)
        .set_align(Align.LeftIn, Align.Middle)
        .set_size(56, self.element_heights[VitalsElement.Stamina])

    self.stamina_bar_meter_secondary = ANCHOR.nine_slice(self.stamina_bar_backplate, VitalsDepth.StaminaSecondary)
        .set_xy(3, 2)
        .set_sprite(spr_ui_hud_health_bar_white)
        .set_size(50, 9)
        .set_color(make_color_rgb(20, 92, 60))

    self.stamina_bar_meter_primary = ANCHOR.nine_slice(self.stamina_bar_backplate, VitalsDepth.StaminaPrimary)
        .set_xy(3, 2)
        .set_sprite(spr_ui_hud_health_stamina_bar)
        .set_size(50, 9)

    self.stamina_bar_text = ANCHOR.text(self.stamina_bar_backplate, VitalsDepth.StaminaText)
        .set_align(Align.Center, Align.Middle)
        .set_sprite_font("vitals_label")
        .set_alpha(0)

    self.mana_icon = ANCHOR.sprite(self.root, VitalsDepth.SpellSlotIcon)
        .set_sprite(spr_ui_hud_health_mana_bar_icon)

    self.orb_one = ANCHOR.sprite(self.mana_icon, VitalsDepth.SpellSlotOrb)
        .set_xy(13, 0)
        .set_sprite(spr_ui_hud_health_mana_ball_on)
        .set_align(Align.LeftIn, Align.Middle)

    self.orb_two = ANCHOR.sprite(self.mana_icon, VitalsDepth.SpellSlotOrb)
        .set_xy(23, 0)
        .set_sprite(spr_ui_hud_health_mana_ball_on)
        .set_align(Align.LeftIn, Align.Middle)

    self.orb_three = ANCHOR.sprite(self.mana_icon, VitalsDepth.SpellSlotOrb)
        .set_xy(33, 0)
        .set_sprite(spr_ui_hud_health_mana_ball_on)
        .set_align(Align.LeftIn, Align.Middle)

    self.orb_four = ANCHOR.sprite(self.mana_icon, VitalsDepth.SpellSlotOrb)
        .set_xy(43, 0)
        .set_sprite(spr_ui_hud_health_mana_ball_on)
        .set_align(Align.LeftIn, Align.Middle)

    self.status_states = List();
    self.status_effect_root = ANCHOR.positional(self.root)
        .set_x(1)

    //
    self.set_max_health(ARI.get_max_health());
    self.set_health(ARI.get_health(), ARI.get_max_health(), true);
    self.set_max_stamina(ARI.get_max_stamina());
    self.set_stamina(ARI.get_stamina(), ARI.get_max_stamina(), true);
    self.set_mana(ARI.get_mana(), ARI.mana_max);
    self.set_number_visibility(SETTINGS.get("show_hud_numbers"));
    var values = ARI.status_effects.effects.values();
    for(var i = 0; i < array_length(values); i++) {
        var value = values[i];
        if value != undefined {
            self.register_status(value);
        }
    }
}
