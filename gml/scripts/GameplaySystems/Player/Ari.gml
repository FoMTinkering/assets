#macro ARI global.__ari
global.__ari = undefined;

#macro DEFAULT_ARI_BIRTHDAY seasons(Season.Spring) + days(21)

function Ari() constructor {
    function on_new_day() {
        self.ate_perpetual_soup_today = false;
        self.times_bathhouse_used_today = 0;
        self.festival_date_partner = undefined;
        self.invulnerable_hits = ARI.perk_value(Perk.GuardiansShield);

        for (var i = 0; i < StatusEffectId.LEN; i++) {
            self.status_effects.cancel(i);
        }
        var menu = ANCHOR.get_menu(Menu.Vitals);
        if menu != undefined {
            menu.refresh_statuses();
        }
        self.has_seen_treasure_level_today = false;
        self.has_seen_ritual_level_today = false;
        self.has_seen_arena_level_today = false;
        self.has_gossiped_today = false;
        self.used_object_today = array_bool(ObjectId.LEN);

        //
        self.pending_renown_entries.drain(function(e) {
            self.modify_renown(renown_entry_value(e));
            return true;
        });

        //
        if renown_to_level(self.renown) >= 40 {
            if self.crown_cooldown == undefined {
                self.crown_cooldown = 3;
            }

            if self.crown_cooldown > 0 {
                self.crown_cooldown -= 1;
            }
        }

        self.morning_recipe_unlocks = array_create_ext(ItemId.LEN, ari_has_recipe_anywhere);
    }

    //
    //
    //
    function get_equipment_bonus_from(infusion, key) {
        var value = 0;

        //
        for (var i = 0; i < self.armor.size(); i++) {
            var item = self.armor.slot(i).item;
            if item != undefined {
                value += item.get_infusion_modifier(infusion, key);
            }
        }

        //
        var item = self.held_item();
        if item != undefined && item.infusion == infusion && matches(item.prototype.use, ItemUse.Attack, ItemUse.UseTool) {
            value += item.get_infusion_modifier(infusion, key);
            if ARI.perk_active(Perk.PerfectPrefix) && item.prototype.use == ItemUse.Attack {
                value *= 2;
            }
        }
        return value;
    }

    //
    function get_damage_mitigation() {
        var total_defense = 0;
        for (var i = 0; i < self.armor.size(); i++) {
            var item = self.armor.slot(i).item;
            if item != undefined {
                total_defense += item.prototype.defense;
            }
        }

        return total_defense;
    }

    //
    function get_essence() {
        return essence;
    }

    //
    function get_essence_overflow() {
        return essence_overflow;
    }

    //
    function set_essence(val) {
        var delta = val - self.essence;
        if sign(delta) == 1 {
            GAME_STATS.gross_essence += delta;
        }

        var new_essence = val;
        assert(essence >= 0);

        if new_essence > self.essence && self.end_of_day_sequence == false {
            var f = fiddle_get("misc/perk_vfx/essence_flash");
            play_heal_vfx(make_color_rgb(f[0], f[1], f[2]), spr_fx_heal_purple);
        }
        self.essence = new_essence;

        var menu = ANCHOR.get_menu(Menu.InfoHud)
        if menu != undefined {
            menu.update_essence();
        }

        refresh_achievements([Requirement.ReachedEssence]);
    }

    //
    function modify_essence(amount_to_add) {
        self.set_essence(self.essence + amount_to_add);
    }

    //
    //
    //
    function gain_essence(amount_to_add, _x, _y, _distance=2, wait=60) {
        if !requirements_pass(Requirement.CollectEssence) {
            return;
        }

        self.essence_overflow += amount_to_add;
        //
        self.essence_update_x = _x;
        self.essence_update_y = _y;
        self.essence_update_dist = _distance;
        //
        if (self.essence_overflow >= ESSENCE_MORSEL_SMALL) && !self.initiate_essence_update {
            if wait == 0 {
                self.essence_overflow = round(
                    create_essence_morsels(
                        self.essence_update_x,
                        self.essence_update_y,
                        self.essence_update_dist,
                        self.essence_overflow,
                    )
                );
            } else {
                self.initiate_essence_update = true;
                new_chain()
                    .join(LinkId.Timer, 60)
                    .append(LinkId.Function, function() {
                        //
                        self.initiate_essence_update = false;
                        self.essence_overflow = round(
                            create_essence_morsels(
                                self.essence_update_x,
                                self.essence_update_y,
                                self.essence_update_dist,
                                self.essence_overflow,
                            )
                        );
                    });
            }
        }
    }

    //
    function get_stamina() {
        return self.stamina_current;
    }

    //
    function get_max_stamina() {
        return self.base_stamina + get_equipment_bonus_from(Infusion.Tireless, "amount");
    }

    //
    function set_stamina(val, allow_spillover=false, instant=false) {

        //
        //
        var is_decrease = val <= self.stamina_current;
        var clamp_maximum = is_decrease || allow_spillover ? I32_MAX : self.get_max_stamina();
        var new_stamina = round(clamp(val, 0, clamp_maximum));

        if !is_decrease && self.end_of_day_sequence == false {
            var f = fiddle_get("misc/perk_vfx/stamina_flash");
            play_heal_vfx(make_color_rgb(f[0], f[1], f[2]), spr_fx_heal_green);
        }
        self.stamina_current = new_stamina;

        var menu = ANCHOR.get_menu(Menu.Vitals);
        if menu != undefined {
            menu.set_stamina(stamina_current, self.get_max_stamina(), instant);
        }
    }

    //
    function modify_stamina(amount_to_add) {
        var o = self.get_stamina();
        self.set_stamina(o + (amount_to_add * self.stamina_costs_modifier));
    }

    //
    function get_health() {
        return self.health_current;
    }

    //
    function get_max_health() {
        var hp = self.base_health + get_equipment_bonus_from(Infusion.Fortified, "amount");
        return hp;
    }

    //
    function set_health(val, play_sound=true, instant=false) {
        var max_health = self.get_max_health();
        var new_health = round(clamp(val, 0, max_health));

        if self.end_of_day_sequence == false {
            var play_vfx = false;
            switch cmp(new_health, self.health_current) {
                case Ordering.LessThan:
                    if play_sound && new_health > 0 && new_health <= (max_health * 0.20) {
                        TANGO.play("SoundEffects/Ari/LowHealthWarning");
                    }
                    break;
                case Ordering.GreaterThan:
                    play_vfx = true;
                    break;
                case Ordering.Equal:
                    play_vfx = new_health == self.health_current && new_health == max_health;
                    break;
            }
            if play_vfx {
                play_heal_vfx(make_color_rgb(138, 241, 247), spr_fx_heal_blue);

                if play_sound {
                    var heal_amount = (new_health - self.health_current) / max_health;
                    if heal_amount > 0.40 {
                        TANGO.play("SoundEffects/Ari/Heal");
                    } else if heal_amount > 0.20 {
                        TANGO.play("SoundEffects/Ari/HealMedium");
                    } else if heal_amount > 0 {
                        TANGO.play("SoundEffects/Ari/HealSmall");
                    }
                }
            }
        }

        self.health_current = new_health;

        //
        var menu = ANCHOR.get_menu(Menu.Vitals);
        if menu != undefined {
            menu.set_health(health_current, max_health, instant);
        }

        return new_health <= 0;
    }

    //
    function modify_health(amount_to_add, play_sound) {
        //
        if amount_to_add == 0 {
            return;
        }
        var o = self.get_health();
        return self.set_health(o + amount_to_add, play_sound);
    }

    //
    function max_health_can_add(amount_to_add) {
        var o = self.get_health();
        var m = self.get_max_health();

        return min(m - o, amount_to_add);
    }

    //
    function max_stamina_can_add(amount_to_add) {
        var o = self.get_stamina();
        var m = self.get_max_stamina();

        return min(m - o, amount_to_add);
    }

    //
    function get_move_speed(on_mount=false) {
        var spd;
        if ARI.run_toggle {
            if on_mount {
                spd = ARI.perk_active(Perk.Horsepower) ? MOUNT_HORSEPOWER_RUN_SPEED : MOUNT_RUN_SPEED;
            } else {
                spd = HUMAN_RUN_SPEED;
                spd *= 1 + get_equipment_bonus_from(Infusion.Hasty, "percentage");
                spd *= self.status_effects.get_effect_value(StatusEffectId.Speedy);
                spd *= 1 + self.status_effects.get_effect_value(StatusEffectId.StackingSpeed, 0);
            }
        } else {
            spd = on_mount ? MOUNT_WALK_SPEED : HUMAN_WALK_SPEED;
        }

        spd *= self.status_effects.get_effect_value(StatusEffectId.MineTime);
        spd *= self.status_effects.get_effect_value(StatusEffectId.SlimeDash);
        spd *= self.status_effects.get_effect_value(StatusEffectId.KillHaste);
        return spd;
    }

    function get_swim_speed() {
        var spd;
        if ARI.run_toggle {
            spd = HUMAN_SWIM_FAST;
            spd *= 1 + get_equipment_bonus_from(Infusion.Hasty, "percentage");
            spd *= self.status_effects.get_effect_value(StatusEffectId.Speedy);
        } else {
            spd = HUMAN_SWIM_SLOW;
        }

        return spd;
    }

    //
    function get_mana() {
        return self.mana_current;
    }

    //
    function set_mana(val) {
        mana_current = clamp(val, 0, mana_max);
        var menu = ANCHOR.get_menu(Menu.Vitals);
        if menu != undefined {
            menu.set_mana(mana_current, mana_max);
        }
    }

    //
    function modify_mana(amount_to_add) {
        var o = get_mana();
        set_mana(o + amount_to_add);
    }

    //
    function get_gold() {
        return gold;
    }

    //
    function set_gold(val) {
        val = max(floor(val), 0);

        self.gold = val;
        var menu = ANCHOR.get_menu(Menu.InfoHud)
        if menu != undefined {
            menu.gold_animator.set_gold(gold);
        }

        refresh_achievements([Requirement.EarnedGold]);
    }

    //
    function modify_gold(amount_to_add) {
        self.set_gold(self.gold + amount_to_add);
    }

    //
    function set_renown(val) {
        static MAX_VALUE = renown_level_total_cost(MAX_RENOWN_LEVEL);

        var level = renown_to_level(self.renown);

        val = clamp(floor(val), 0, MAX_VALUE);
        self.renown = val;

        var new_level = renown_to_level(self.renown);
        var new_levels = new_level - level;

        if sign(new_levels) != 1 {
            return;
        }

        var rewards_len = RENOWN.rewards.count();
        repeat new_levels {
            //
            if level >= rewards_len {
                break;
            }

            array_push(GAME_STATS.renown_level_ups, {
                level: level + 1,
                day: total_days(),
            });

            var items = consume_reward(RENOWN.rewards.get(level));
            items.transfer(items.fold(List(), function(a, item) {
                if item.prototype.tags.contains("furniture") && !ari_has_recipe_anywhere(item.item_id) {
                    ARI.recipes_created[item.item_id] = true;
                    a.push(new LiveItem(ItemId.CraftingScroll, item.item_id));
                }
                return a;
            }));

            items.for_each(function(item) {
                if RENOWN_REWARD_INVENTORY.can_add(item) {
                    RENOWN_REWARD_INVENTORY.add(item);
                } else {
                    GRIDS[LocationId.Town].lost_items.push({
                        x: 1347,
                        y: 1732,
                        items: List(item),
                    });
                }
            });

            level += 1;

            var next_quest = renown_level_to_quest(level);
            var last_quest = renown_level_to_quest(level - 10);
            if next_quest != undefined {
                QUEST_LOG.start(next_quest);
            }
            if last_quest != undefined && !QUEST_LOG.completed.contains(last_quest) {
                var active_quest = QUEST_LOG.active.get(last_quest);
                if active_quest == undefined {
                    warn("Couldn't find an active quest for '{}'! Starting it so it can complete.", last_quest);
                    QUEST_LOG.start(last_quest);
                    active_quest = QUEST_LOG.active.get(last_quest);
                }
                var status = active_quest.progress();
                assert_eq(status, ProgressOutput.Complete);
                QUEST_LOG.complete(last_quest);
            }
        }
    }

    //
    function modify_renown(amount_to_add) {
        self.set_renown(self.renown + amount_to_add);
    }

    //
    function ready_for_crown_quest() {
        return self.crown_cooldown != undefined && self.crown_cooldown <= 0;
    }

    //
    function held_item() {
        return self.inventory.slot(self.held_item_index).item;
    }

    function set_pinned_spell(spell) {
        var menu = ANCHOR.get_menu(Menu.InfoHud);
        if menu != undefined {
            if spell == undefined {
                menu.spell_pin.disable();
            } else {
                menu.spell_pin.set_sprites_from_key(SPELLS[spell].icon_key);
                menu.spell_pin.enable();
            }
        }
        ARI.pinned_spell = spell;
    }

    //
    //
    function give_item(item, count=1, show_toast=true, show_new_popup=true, play_sound=true) {
        item = is_struct(item) ? item : new LiveItem(item);

        if item.item_id == ItemId.RecipeScroll || item.item_id == ItemId.CraftingScroll {
            ARI.recipes_created[item.inner_item] = true;
        }

        //
        var can_fit = self.inventory.room_for_item(item);

        //
        var should_drop = max(count - can_fit, 0);
        if should_drop > 0 {
            var item_list = ListFromArray(array_map(array_create(should_drop, item), function(v) {
                return is_struct(v) ? v.clone() : new LiveItem(v);
            }));
            if instance_exists(obj_ari) {
                drop_item_stack(obj_ari.x, obj_ari.y, item_list);
            } else {
                var safe_pos = player_home_safe_position(LocationId.PlayerHome);
                GRIDS[LocationId.PlayerHome]
                    .lost_items
                    .push({
                        x: safe_pos.x,
                        y: safe_pos.y,
                        items: item_list,
                    });
            }
        }

        //
        var amount_to_give = min(count, can_fit);
        if amount_to_give > 0 {
            ARI.inventory.add(item, amount_to_give);

            if play_sound {
                TANGO.play("SoundEffects/Inventory/ItemPickup");
            }

            if show_toast {
                var menu = ANCHOR.get_menu(Menu.ItemToasts);
                if menu != undefined {
                    menu.create_pickup(item, amount_to_give);
                }
            }

            if ARI.items_acquired[item.item_id] == false && !STORY_EXECUTOR_RUNNING {
                if show_new_popup && !item.prototype.tags.contains("blacklist_popup") {
                    new_chain().append(LinkId.Await, function(item) {
                        if ANCHOR.get_menu(Menu.Textbox) == undefined {
                            await_popup(new_item_popup, [item]);
                            return true;
                        }
                        return false;
                    }, [item])
                }

                if !ARI.tutorials_seen[Tutorial.Fishing]
                    && item.prototype.tool_type == ToolType.FishingRod
                {
                    var chain = new_chain().append(LinkId.Await, function() {
                        //
                        return ANCHOR.get_menu(Menu.Crafting) == undefined;
                    });
                    await_popup(function() {
                        if !ARI.tutorials_seen[Tutorial.Fishing] {
                            spawn_tutorial(Tutorial.Fishing);
                        }
                    }, [], chain);
                }

                if !ARI.tutorials_seen[Tutorial.WaterSpriteStatue]
                    && item.item_id == ItemId.WaterSpriteStatueV1
                {
                    await_popup(spawn_tutorial, [Tutorial.WaterSpriteStatue]);
                }

                if !ARI.tutorials_seen[Tutorial.AnimalSpriteStatue]
                    && item.item_id == ItemId.OcarinaSpriteStatue
                {
                    await_popup(spawn_tutorial, [Tutorial.AnimalSpriteStatue]);
                }

                mark_item_as_acquired(item.item_id);
            }
        }

    }

    function mark_item_as_acquired(item) {
        item = is_struct(item) ? item : new LiveItem(item);
        var recipe_key = item.prototype.recipe_key;
        for (var i = 0; i < ItemId.LEN; i++) {
            if ITEM_PROTOTYPES[i].recipe_key == recipe_key {
                ARI.items_acquired[i] = true;
                ARI.almanac_items_remaining.remove(string(i));
            }
        }
    }

    function update() {
        self.status_effects.update();

        //
        var updates = self.inventory_subscriber.pull();
        updates.for_each(function(slot) {
            //
            with obj_item {
                self.update_can_chase();
            }

            if slot.item == undefined {
                return;
            }

            //
            //
            //
            mark_item_as_acquired(slot.item.item_id);
        });

        if !updates.is_empty() {
            refresh_achievements([Requirement.CompletedAlmanac]);
        }

        //
        self.armor_subscriber.pull().for_each(function(_) {
            var max_health = self.get_max_health();
            var max_stamina = self.get_max_stamina();
            var menu = ANCHOR.get_menu(Menu.Vitals);
            menu.set_max_health(max_health);
            menu.set_health(health_current, max_health, true);
            menu.set_max_stamina(max_stamina);
            menu.set_stamina(stamina_current, max_stamina, true);
        })
    }

    function serialize_stats() {
        return {
            gold: self.gold,
            essence: self.essence,
            renown: self.renown,
            mana_current: self.mana_current,
            mana_max: self.mana_max,
            status_effects: self.status_effects.serialize(),
            health_current: self.health_current,
            base_health: self.base_health,
            stamina_current: self.stamina_current,
            base_stamina: self.base_stamina,
            free_baths: self.free_baths,
            invulnerable_hits: self.invulnerable_hits,
            end_of_day_status: opt_and_then(self.end_of_day_status, end_of_day_status_to_string),
            ancient_inspiration_time: self.ancient_inspiration_time,
            ate_perpetual_soup_today: self.ate_perpetual_soup_today,
            perks_active: array_to_struct(self.perks_active, perk_to_string),
        }
    }
    function deserialize_stats(_struct) {
        self.gold = _struct.gold;
        self.essence = _struct.essence;
        self.renown = _struct.renown;
        self.mana_current = int64(_struct.mana_current);
        self.mana_max = int64(_struct.mana_max);
        self.status_effects.deserialize(_struct.status_effects);
        self.health_current = _struct.health_current;
        self.base_health = _struct.base_health;
        self.stamina_current = _struct.stamina_current;
        self.base_stamina = _struct.base_stamina;
        self.free_baths = _struct.free_baths;
        self.invulnerable_hits = _struct.invulnerable_hits;
        self.end_of_day_status = opt_and_then(_struct[$ "end_of_day_status"], try_string_to_end_of_day_status);
        self.ancient_inspiration_time = _struct.ancient_inspiration_time;
        self.ate_perpetual_soup_today = _struct[$ "ate_perpetual_soup_today"] ?? false;

        //
        //
        if _struct[$ "perks_active"] != undefined {
            var keys = struct_get_names(_struct.perks_active);
            for (var i = 0; i < array_length(keys); i++) {
                var perk = try_string_to_perk(keys[i]);
                if perk != undefined {
                    self.perks_active[perk] = _struct.perks_active[keys[i]];
                }
            }
        };
    }

    function is_birthday() {
        return CALENDAR.day() == get_days(self.birthday)
            && CALENDAR.season() == get_seasons(self.birthday);
    }

    function get_bathhouse_cost() {
        var cost = fiddle_get("misc/bathhouse/cost");
        var usage_multip = fiddle_get("misc/bathhouse/usage_multiplier");
        return cost + (cost * usage_multip * ARI.times_bathhouse_used_today);
    }

    function unlock_recipe(item_id, alert=true) {
        var found_one = false;
        var key_to_find = ITEM_PROTOTYPES[item_id].recipe_key;
        for (var i = 0; i < ItemId.LEN; i++) {
            var proto = ITEM_PROTOTYPES[i];
            if proto.recipe_key == key_to_find {
                self.recipe_unlocks[i] = true;
                self.recipes_created[i] = false;
                found_one = true;
            }
        }

        if found_one && alert {
            await_popup(function(item_id) {
                new_item_popup(item_id, true)
            }, [item_id])
        }
    }

    function monsters_killed(category) {
        var count = 0;
        var to_check = array_concat(GAME_STATS.mines_data, game_stats_mines_floor_available()
            ? [GS_MINES_RUN, { floor_data: [GS_MINES_FLOOR] }]
            : [],
        );
        for (var j = 0; j < array_length(to_check); j++) {
            var run = to_check[j];
            for (var k = 0; k < array_length(run.floor_data); k++) {
                for (var h = 0; h < MonsterId.LEN; h++) {
                    if MONSTER_PROTOTYPES[h].monster_category == category {
                        var key = monster_id_to_string(h);
                        count += run.floor_data[k].enemy_kill[key] ?? 0;
                    }
                }
            }
        }
        return count;
    }

    function animation_assets() {
        return self.presets.get(self.preset_index_selected);
    }
    player_dir_game_start = undefined;

    function set_held_item_index(index) {
        static BANNED_STATES = [
            PlayerState.Diving,
            PlayerState.Hurt,
            PlayerState.Electrocute,
            PlayerState.Knockback,
            PlayerState.ThrowItem,
            PlayerState.Tool,
            PlayerState.Fishing,
            PlayerState.Sword,
        ];

        if array_has(BANNED_STATES, obj_ari.fsm.current_state_id()) {
            return false;
        }

        if obj_ari.fsm.next_state != undefined && array_has(BANNED_STATES, obj_ari.fsm.next_state.state_id) {
            return false;
        }

        if self.held_item_index == index {
            return false;
        }

        self.held_item_index = index;
        ANCHOR.get_menu(Menu.Toolbar).set_cursor_to_index(index);
        return true;
    }

    function level(skill) {
        return skill_xp_to_level(skill, self.skill_xp[skill]);
    }

    function gain_xp(skill, xp, silent=false) {
        var old_skill_level = ARI.level(skill);

        self.skill_xp[skill] = min(
            self.skill_xp[skill] + xp,
            MAX_SKILL_LEVEL_COSTS[skill],
        );

        if !silent && old_skill_level != ARI.level(skill) {
            TANGO.play("SoundEffects/Ari/LevelUp");
            ANCHOR.get_menu(Menu.Dingaling).create_skill_dingaling(skill, old_skill_level);
            refresh_achievements([Requirement.ReachedSkillLevel]);
        }
    }

    function perk_value(perk, key) {
        key = key == undefined ? "value" : key;

        //
        if self.perks[perk] == false || self.perks_active[perk] == false {
            return 0;
        }

        var value = fiddle_get(format("perks/{Perk}/{}", perk, key));

        if TEST_SUITE {
            static BANNED_TS_PERKS = [
                Perk.WesternRuinsScholar,
                Perk.EasternRoadScholar,
                Perk.FormerFarmers,
                Perk.WelcomeHome,
                Perk.WelcomeHomeTwo
            ];

            if array_contains(BANNED_TS_PERKS, perk) == false {
                value = 100;
            }
        }

        return value;
    }

    function perk_active(perk) {
        return self.perks[perk] && self.perks_active[perk];
    }

    function acquire_perk(perk) {
        self.perks[perk] = true;
        self.perks_active[perk] = true;

        //
        switch perk {
            case Perk.GuardiansShield:
                ARI.invulnerable_hits += 1;
                break;
            case Perk.AncientInspiration:
                self.ancient_inspiration_time = 0;
                break;
        }

        array_push(GAME_STATS.perk_acquirements, {
            perk: perk_to_string(perk),
            day: total_days(),
        });

        refresh_achievements([Requirement.HasAtLeastOneTierFivePerkPerCategory]);
    }

    function check_for_held_items(ari_instance) {
        //
        if ARI.end_of_day_status != undefined || self.fire_breath_time > 0 {
            return;
        }
        if self.held_animal_id != self.held_animal_last_frame {
            self.held_animal_last_frame = self.held_animal_id;

            //
            //
            ari_instance.par.remove_held_sprite();
            ari_instance.par.unset_modifier(AnimationName.Pickup);

            //
            if self.held_animal_id == undefined {
                self.held_item_last_frame = undefined;
            } else {
                var animal = find_animal(ARI.held_animal_id);
                if animal == undefined {
                    self.held_animal_last_frame = undefined;
                    return;
                } else {
                    var held_offsets = animal.held_offset();

                    ari_instance.par.set_held_sprite(
                        spr_nothing,  //
                        0, //
                        held_offsets.x,
                        held_offsets.y,
                        held_offsets.x,
                    );
                    ari_instance.set_animation(AnimationName.Pickup);
                }
            }
        }

        if self.held_animal_id == undefined {
            var held_item = self.held_item();
            var both_defined = held_item != undefined && self.held_item_last_frame != undefined;
            var needs_swap = both_defined
                ? !held_item.partial_eq(self.held_item_last_frame)
                : held_item != self.held_item_last_frame;
            if needs_swap {
                //
                //
                ari_instance.par.remove_held_sprite();
                ari_instance.par.unset_modifier(AnimationName.Pickup);

                if held_item != undefined && held_item.prototype.hold_over_head {
                    self.held_item_last_frame = held_item;
                    var spr = self.held_item().get_ui_icon();

                    ari_instance.par.set_held_sprite(spr);
                    ari_instance.set_animation(AnimationName.Pickup, SetAnimationOverride.OverrideAnyway);
                } else {
                    self.held_item_last_frame = undefined;
                }
            }
        }

        //
        if self.skip_pickup_animation {
            ari_instance.par.modifier_to_frame(AnimationName.Pickup, undefined);
            self.skip_pickup_animation = false;
        }
    }

    function times_item_tag_sold(tag) {
        var count = 0;
        for (var i = 0; i < ItemId.LEN; i++) {
            if self.items_sold[i] > 0 && ITEM_PROTOTYPES[i].tags.contains(tag) {
                count += self.items_sold[i];
            }
        }
        return count;
    }

    function learn_spell(spell) {
        if !array_contains(self.spells_learned, true) {
            ARI.set_pinned_spell(spell);
        }
        self.spells_learned[spell] = true;

        if spell == Spell.FireBreath && !ARI.tutorials_seen[Tutorial.DragonsBreathSpell] {
            var chain = new_chain().append(LinkId.Await, function() {
                return !MIST.is_running();
            });
            await_popup(spawn_tutorial, [Tutorial.DragonsBreathSpell], chain);
        }
    }

    function ensure_quest_artifact(key) {
        if !self.quest_artifacts.contains_key(key) {
            self.quest_artifacts.insert(key, {
                last_tier: 0,
                last_score: 0,
                max_score: 0,
            });
        }
        return self.quest_artifacts.get(key);
    }

    function spouse() {
        for (var i = 0; i < NpcId.LEN; i++) {
            if NPCS[i].is_spouse() {
                return i;
            }
        }
        return undefined;
    }

    function fiance() {
        for (var i = 0; i < NpcId.LEN; i++) {
            if NPCS[i].is_fiance() {
                return i;
            }
        }
        return undefined;
    }

    function has_spouse() {
        return self.spouse() != undefined;
    }

    function has_fiance() {
        return self.fiance() != undefined;
    }

    function held_child() {
        if MIST.blackboard.get("no_held_child") == true {
            return undefined;
        }

        var child = undefined;
        for (var i = 0; i < array_length(self.children); i++) {
            if self.children[i].location == ChildLocation.WithAri {
                assert_neq(child, "Ari cannot hold more than one child!");
                child = self.children[i];
            }
        }

        return child;
    }

    function build_almanac_items_remaining() {
        self.almanac_items_remaining.clear();
        var categories = fiddle_get("ui/menus/sub_menus/almanac/categories");
        for (var i = 0; i < array_length(categories); i++) {
            var key = categories[i].key;
            var tags = categories[i].tags;
            for (var j = 0; j < array_length(tags); j++) {
                for (var k = 0; k < ItemId.LEN; k++) {
                    if !self.items_acquired[i] && ITEM_PROTOTYPES[k].tags.contains(tags[j]) {
                        self.almanac_items_remaining.insert(string(k));
                    }
                }
            }
        }
    }

    function unlocked_all_chicken_tiers() {
        var chickens = ARI.animal_variant_unlocks[AnimalKind.Chicken].keys();
        var tiers = array_create(7, false);
        for (var i = 0; i < array_length(chickens); i++) {
            var variant = ANIMAL_PROTOTYPES[AnimalKind.Chicken].variants.get(chickens[i]);
            tiers[ANIMAL_PROTOTYPES[AnimalKind.Chicken].variants.get(chickens[i]).tier] = true;
        }

        //
        for (var i = 1; i < array_length(tiers); i++) {
            if tiers[i] == false {
                return false;
            }
        }

        return true;
    }

    invulnerable_hits = 0;
    end_of_day_sequence = false;

    name = undefined;
    farm_name = undefined;
    pronouns = default_pronouns();
    presets = List(create_default_player_animation_assets());
    preset_index_selected = 0;
    birthday = DEFAULT_ARI_BIRTHDAY;

    quest_artifacts = Map();
    festival_date_partner = undefined;

    held_item_index = 0;
    held_animal_last_frame = undefined;
    held_item_last_frame = undefined;
    skip_pickup_animation = false;

    mana_max = fiddle_get("misc/ari_stats/base_mana");
    base_stamina = fiddle_get("misc/ari_stats/base_stamina");
    base_health = fiddle_get("misc/ari_stats/base_health");

    used_elevator = false;

    essence = fiddle_get("misc/ari_stats/starting_essence");
    gold = 0;
    renown = 0;
    essence_overflow = 0;
    initiate_essence_update = false;

    essence_update_x = 0;
    essence_update_y = 0;
    essence_update_dist = 0;
    run_toggle = true;
    times_bathhouse_used_today = 0;
    free_baths = 0;
    meddler = undefined;
    held_animal_id = undefined;

    skill_xp = array_create(Skill.LEN, 0);
    perks = array_create(Perk.LEN, false);
    perks_active = array_create(Perk.LEN, true);
    pinned_spell = undefined;

    inventory = Inventory(10);
    items_acquired = array_bool(ItemId.LEN);
    items_sold = array_create(ItemId.LEN, 0);
    spells_learned = array_bool(Spell.LEN);
    legendary_fish_caught = array_bool(Season.LEN);
    recipe_unlocks = array_bool(ItemId.LEN);
    recipes_created = array_bool(ItemId.LEN);
    morning_recipe_unlocks = array_bool(ItemId.LEN);
    tutorials_seen = array_bool(Tutorial.LEN);
    cosmetic_unlocks = HashSet();
    seen_cosmetics = HashSet();
    annual_item_purchase_bans = array_bool(ItemId.LEN);
    inventory_subscriber = new InventorySubscriber(self.inventory);
    inbox = new Inbox();
    status_effects = new StatusEffectManager();
    animal_variant_unlocks = array_create_ext(AnimalKind.LEN, EmptyMap);
    animal_cosmetic_unlocks = array_create_ext(AnimalKind.LEN, HashSet);
    pet_cosmetic_sets_unlocked = [];
    pet_skin_unlocks = [];
    armor = Inventory(ArmorSlot.LEN);
    armor.slot(0).required_tags.push("head");
    armor.slot(1).required_tags.push("chest");
    armor.slot(2).required_tags.push("legs");
    armor.slot(3).required_tags.push("boots");
    armor.slot(4).required_tags.push("accessory");
    armor_subscriber = new InventorySubscriber(self.armor);
    stamina_costs_modifier = 1;
    stamina_current = get_max_stamina();
    health_current = get_max_health();
    mana_current = fiddle_get("misc/ari_stats/base_mana");
    ancient_inspiration_time = undefined;
    crown_cooldown = undefined;
    active_pursuit = false;
    has_seen_treasure_level_today = false;
    has_seen_ritual_level_today = false;
    has_seen_arena_level_today = false;
    has_gossiped_today = false;
    used_object_today = array_bool(ObjectId.LEN);
    date_unlocks = array_bool(Date.LEN);
    date_history = [];
    transparency_list = ds_list_create();
    song_unlocks = [];
    song_overrides = array_create(LocationId.LEN, undefined);
    dyn_song_overrides = {};
    bell_sound = "default";

    end_of_day_status = undefined;
    mount = undefined;
    mount_mirroring_animal = undefined;

    pending_renown_entries = List();
    fire_breath_time = 0;
    fire_body_alpha = 0;

    has_left_house_today = false;
    ate_perpetual_soup_today = false;

    last_bed_used = undefined;
    save_position = undefined;

    pending_child = undefined;
    children = [];

    proposal_date = undefined;
    wedding_date = undefined;

    has_protection_scroll = false;

    disable_break_ups = false;
    disable_break_up_letters = false;

    //
    //
    //
    almanac_items_remaining = HashSet();
    self.build_almanac_items_remaining();
}

function play_heal_vfx(color, sprite) {
    if instance_exists(obj_ari) == false {
        return;
    }
    create_animation_effect(obj_ari.x, obj_ari.y, obj_ari.depth - 100, sprite);

    if obj_ari.par.blend == undefined {
        obj_ari.par.blend = {
            src_mode: bm_src_alpha,
            dest_mode: bm_one,
            color: color,
            alpha: 0
        };

        new_chain()
            .append(LinkId.Ease, new Ease(EaseId.SineOut, 0, 0.2, 10), function(delta) {
                if instance_exists(obj_ari) == false {
                    return;
                }

                if obj_ari.par.blend != undefined {
                    obj_ari.par.blend.alpha += delta;
                }
            })
            .append(LinkId.Ease, new Ease(EaseId.SineIn, 0.2, 0, 5), function(delta) {
                if instance_exists(obj_ari) == false {
                    return;
                }

                if obj_ari.par.blend != undefined {
                    obj_ari.par.blend.alpha += delta;
                }
            })
            .append(LinkId.Function, function() {
                if instance_exists(obj_ari) == false {
                    return;
                }

                obj_ari.par.blend = undefined;
            });
    }
}

//
function shipping_bins() {
    return STORAGE_NODES.clone().retain(function(node) {
        return node.prototype.interaction_chest != undefined && node.prototype.interaction_chest.shipping_bin;
    });
}

//
function all_item_slots() {
    return STORAGE_NODES
        .fold(List(), function(l, node) {
            l.copy_from(node.inventory.slots);
            return l;
        })
        .copy_from(ARI.inventory.slots)
        .copy_from(ARI.armor.slots)
        .copy_from(LOST_AND_FOUND.slots)
        .copy_from(RENOWN_REWARD_INVENTORY.slots);
}

//
//
//
//
function any_item_matches(item) {
    item = is_struct(item) ? item : new LiveItem(item);
    var ari_has = all_item_slots().any(function(slot, item) {
        return slot.item != undefined && item.partial_eq(slot.item)
    }, item);

    if ari_has {
        return true;
    }

    var grid_has = all_lost_items().any(function(this_item, item) {
        return item.partial_eq(this_item);
    }, item);

    if grid_has {
        return true;
    }

    var first_item;
    with obj_item {
        first_item = self.items.first();
        if first_item == undefined {
            continue;
        }
        if first_item.partial_eq(item) {
            return true;
        }
    }

    return false;
}

//
//
function ari_has_cosmetic_anywhere(cosmetic) {
    var check_item = new LiveItem(ItemId.Cosmetic);
    check_item.cosmetic = cosmetic;

    return ARI.cosmetic_unlocks.contains(cosmetic) || any_item_matches(check_item);
}

//
//
function ari_has_animal_cosmetic_anywhere(animal, cosmetic) {
    var check_item = new LiveItem(ItemId.AnimalCosmetic);
    check_item.animal_cosmetic = { animal, cosmetic };

    return ARI.animal_cosmetic_unlocks[animal].contains(cosmetic) || any_item_matches(check_item);
}

//
//
function ari_has_pet_cosmetic_anywhere(cosmetic_set_name) {
    //
    if array_contains(ARI.pet_cosmetic_sets_unlocked, cosmetic_set_name) {
        return true;
    }

    var check_item = new LiveItem(ItemId.PetCosmetic);
    check_item.pet_cosmetic_set_name = cosmetic_set_name;

    return any_item_matches(check_item);
}

//
//
function ari_has_pet_skin_anywhere(skin_name) {
    if array_contains(ARI.pet_skin_unlocks, skin_name) {
        return true;
    }

    for (var i = 0; i < ItemId.LEN; i++) {
        var proto = ITEM_PROTOTYPES[i];
        if proto.pet_skin_unlock == skin_name && any_item_matches(i) {
            return true;
        }
    }

    return false;
}

//
//
function ari_has_recipe_anywhere(item_id) {
    return ARI.recipe_unlocks[item_id] || ARI.recipes_created[item_id];
}

//
//
//
function remove_item_from_world(item_id) {
    all_item_slots().for_each(function(slot, item_id) {
        if slot.item != undefined && slot.item.item_id == item_id {
            slot.drain();
        }
    }, [item_id]);

    for (var i = 0; i < array_length(GRIDS); i++) {
        var grid = GRIDS[i];
        if grid != undefined {
            grid.lost_items.retain(function(e, item_id) {
                return e.items.first().item_id != item_id;
            }, item_id);
        }
    }

    for (var i = 0; i < DYNAMIC_GRIDS.count(); i++) {
        var grid = DYNAMIC_GRIDS.get(i);
        if grid != undefined {
            grid.lost_items.retain(function(e, item_id) {
                return e.items.first().item_id != item_id;
            }, item_id)
        }
    }

    with obj_item {
        if self.item_id == item_id {
            instance_destroy();
        }
    }
}

//
function total_item_count(item_id) {
    var count = all_item_slots().sum_with(function(slot, item_id) {
        if slot.item != undefined && slot.item.item_id == item_id {
            return slot.count;
        }
        return 0;
    }, [item_id]);

    for (var i = 0; i < array_length(GRIDS); i++) {
        var grid = GRIDS[i];
        if grid != undefined {
            count += grid.lost_items.sum_with(function(e, item_id) {
                if e.items.first().item_id == item_id {
                    return e.items.count();
                } else {
                    return 0;
                }
            }, [item_id]);
        }
    }

    for (var i = 0; i < DYNAMIC_GRIDS.count(); i++) {
        var grid = DYNAMIC_GRIDS.get(i);
        if grid != undefined {
            count += grid.lost_items.sum_with(function(e, item_id) {
                if e.items.first().item_id == item_id {
                    return e.items.count();
                } else {
                    return 0;
                }
            }, [item_id]);
        }
    }

    with obj_item {
        if self.item_id == item_id {
            count += self.items.count();
        }
    }

    return count;
}

function xp_to_level(xp_amount) {
    var raw_calc = (xp_amount + 30) / 60;
    return min(1 + floor(raw_calc), 99)
}
