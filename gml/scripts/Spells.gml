#macro GROWTH_SPELL_DING_LENGTH 27
#macro SPELLS global.__spells
SPELLS = undefined;

function load_spells() {
    var output = array_create(Spell.LEN, undefined);
    var f_spells = fiddle_get("spells");
    var spell_default = f_spells[$ "default"];

    for (var i = 0; i < Spell.LEN; i++) {
        var prototype = patch_object(f_spells[$ spell_to_string(i)], clone_value(spell_default));
        filter_toml_nulls(prototype);

        prototype.icon_key = prototype.icon_key;
        prototype.upper_icon = string_to_asset(prototype.upper_icon);
        prototype.ribbon = string_to_asset(prototype.ribbon);

        output[i] = prototype;
    }

    return output;
}

function can_cast_spell(spell) {
    if !instance_exists(obj_ari)
        || obj_ari.is_mounted()
        || ARI.get_mana() < SPELLS[spell].cost
        || ARI.held_animal_id != undefined
    {
        return false;
    }
    switch spell {
        case Spell.FullRestore: return ARI.get_health() < ARI.get_max_health() || ARI.get_stamina() < ARI.get_max_stamina();
        case Spell.SummonRain: return (CURRENT_LOCATION_ID == LocationId.Farm && !WEATHER.is_inclement())
            || is_rain_spell_target(CURRENT_LOCATION_ID);
        case Spell.Growth: return LOCATIONS[CURRENT_LOCATION_ID].outdoor || LOCATIONS[CURRENT_LOCATION_ID].farm;
        case Spell.FireBreath: return ARI.fire_breath_time == 0;
        case Spell.SacredLight: return in_dark_mines() && ARI.status_effects.effects.get(StatusEffectId.SacredLight) == undefined;
        default: impossible("Unexpected Spell: {Spell}", spell);
    }
}

function cast_spell(spell) {
    switch spell {
        case Spell.FullRestore:
            ARI.set_health(ARI.get_max_health());
            if ARI.get_stamina() < ARI.get_max_stamina() {
                ARI.set_stamina(ARI.get_max_stamina());
            }
            break;
        case Spell.SummonRain:
            //
            with obj_monster_cat {
                watered = true;
            }

            WEATHER.under_spell = true;
            if LOCATIONS[CURRENT_LOCATION_ID].outdoor == false && is_rain_spell_target(CURRENT_LOCATION_ID) {
                WEATHER.spell_timer = fiddle_get("spells/summon_rain").indoor_duration;
            }
            WEATHER.set_weather(Weather.HeavyInclement, Atmosphere.Storm);
            break;
        case Spell.Growth:
            //
            var x_pos = ((obj_ari.x div 16) * 16) div 8;
            var y_pos = ((obj_ari.y div 16) * 16) div 8;
            var cast_id = irandom(I32_MAX);

            var max_ding_count = 0;
            var ignore_season = GRID.location_id == LocationId.SmallGreenhouse
                || GRID.location_id == LocationId.LargeGreenhouse;

            for (var xx = x_pos - 2; xx < (x_pos + 4); xx++) {
                for (var yy = y_pos - 2; yy < (y_pos + 4); yy++) {
                    var ni = GRID.try_node_index_for_cell(xx, yy);
                    if ni == undefined {
                        return;
                    }

                    var cat = object_id_to_object_category(GRID.node_object_id[ni]);
                    if cat == undefined || GRID.node_parent[ni].last_update == cast_id {
                        continue;
                    }

                    switch cat {
                        case ObjectCategory.Crop:
                            GRID.node_parent[ni].last_update = cast_id;
                            //
                            if ignore_season == false && GRID.node_parent[ni].prototype.seasons[CALENDAR.season()] == false {
                                break;
                            }
                            var this_ding = level_up_crop(GRID.node_parent[ni], false);
                            max_ding_count = max(this_ding, max_ding_count);
                            break;
                        case ObjectCategory.Grass:
                            GRID.node_parent[ni].last_update = cast_id;
                            var this_ding = level_up_grass(GRID.node_parent[ni]);
                            max_ding_count = max(this_ding, max_ding_count);
                            break;
                        case ObjectCategory.Tree:
                            //
                            //
                            var center_stump_x = GRID.node_top_left_x[ni] + 3;
                            var center_stump_y = GRID.node_top_left_y[ni] + 3;
                            if xx == center_stump_x && yy == center_stump_y {
                                GRID.node_parent[ni].last_update = cast_id;
                                level_up_tree(GRID.node_parent[ni], ignore_season);
                            }
                            break;
                        case ObjectCategory.Bush:
                            GRID.node_parent[ni].last_update = cast_id;
                            if ignore_season == false && GRID.node_parent[ni].prototype.seasons[CALENDAR.season()] == false {
                                break;
                            }
                            level_up_bush(GRID.node_parent[ni]);
                            break;
                        default:
                            //
                            break;
                    }
                }
            }

            if max_ding_count > 0 {
                var c = new_chain();
                max_ding_count = min(max_ding_count, 4);

                for (var i = 5 - max_ding_count; i < 5; i++) {
                    var asset_name = format("SoundEffects/Ari/GrowthSpellStage{}", i);
                    c
                        .append(LinkId.Function, function(asset_name) {
                            TANGO.play(asset_name);
                        }, [asset_name])
                        .append(LinkId.Timer, GROWTH_SPELL_DING_LENGTH);
                }
            }
            break;

        case Spell.FireBreath:
            ARI.fire_breath_time = fiddle_get("player").fire_breath_time_cap;
            ARI.fire_body_alpha = 0;
            obj_ari.dir = 270;
            obj_ari.lagged_dir = 270;
            if MIST.is_running() {
                obj_ari.breathe_fire_in_other_states = true;
            }

            var time = CALENDAR.unified_time();
            ARI.status_effects.register(
                StatusEffectId.FlameBreath,
                0,
                time,
                time + ARI.fire_breath_time * GAME_SECONDS_PER_FRAME,
            );

            TANGO.play("SoundEffects/Ari/DragonBreathStart", obj_ari.x, obj_ari.y);
            break;
        case Spell.SacredLight:
            var time = CALENDAR.unified_time();
            ARI.status_effects.register(
                StatusEffectId.SacredLight,
                0,
                time,
                time + fiddle_get("misc/sacred_light_duration") * 60,
            )
            break;

        default: impossible("Unexpected Spell: {Spell}", spell);

    }
}
