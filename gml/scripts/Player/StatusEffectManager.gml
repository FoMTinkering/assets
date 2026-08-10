function StatusEffectManager() constructor {
    self.effects = Map();

    function register(type, amount, start, finish, can_stack=false, show_hud=true) {
        var effect = {
            type: type,
            amount: amount,
            start: start,
            finish: finish,
            stacks: 1,
            last_update: CALENDAR.unified_time(),
        };

        if can_stack {
            var effect_check = self.effects.get(type);
            if effect_check != undefined {
                effect_check.start = start;
                effect_check.finish = finish;
                effect_check.stacks += 1;
            } else {
                self.effects.insert(type, effect);
            }
        } else {
            //
            self.cancel(type);
            self.effects.insert(type, effect);
        }

        if show_hud {
            ANCHOR.get_menu(Menu.Vitals).register_status(effect);
        }
    }

    //
    function cancel(type, show_vitals=true) {
        var e = self.effects.get(type);
        if e == undefined {
            return;
        }
        self.effects.remove(type);

        if show_vitals {
            var menu = ANCHOR.get_menu(Menu.Vitals);
            for (var j = 0; j < menu.status_states.count(); j++) {
                var state = menu.status_states.get(j);
                if state.status.type == e.type {
                    menu.status_states.remove(j);
                    break;
                }
            }
            menu.refresh_statuses();
        }
    }

    function update() {
        var now = CALENDAR.unified_time();
        for (var i = 0; i < StatusEffectId.LEN; i++) {
            var effect = self.effects.get(i);
            if effect == undefined {
                continue;
            }

            if now >= effect.finish {
                self.effects.remove(i);
                continue;
            }

            if now - effect.last_update > minutes(10) {
                effect.last_update = now;

                //
                //
                switch effect.type {
                    case StatusEffectId.Restorative:
                        ARI.modify_health(5);
                        if ARI.get_stamina() < ARI.get_max_stamina() {
                            ARI.modify_stamina(5);
                        }
                        break;

                    case StatusEffectId.ShrineBoon:
                        ARI.modify_health(5);
                        if ARI.get_stamina() < ARI.get_max_stamina() {
                            ARI.modify_stamina(5);
                        }
                        break;
                }
            }
        }
    }

    function get_effect_value(type, default_value=1) {
        var effect = self.effects.get(type);
        return effect != undefined ? (effect.amount * effect.stacks) : default_value;
    }

    function serialize() {
        var o = [];
        for (var i = 0; i < StatusEffectId.LEN; i++) {
            array_push(o, opt_and_then(self.effects.get(i), function(e) {
                e = clone_value(e);
                e.type = status_effect_id_to_string(e.type);
                return e;
            }));
        }
        return o;
    }

    function deserialize(effects) {
        for (var i = 0; i < array_length(effects); i++) {
            var effect = effects[i];
            if effect == pointer_null {
                effect = undefined;
            }
            self.effects.set(i, opt_and_then(effect, function(e) {
                e.type = string_to_status_effect_id(e.type);
                return e;
            }));
        }
    }
}
