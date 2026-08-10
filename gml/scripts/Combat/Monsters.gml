global.__monster_prototypes = undefined;
#macro MONSTER_PROTOTYPES global.__monster_prototypes

enum MonsterCategory {
    Shroom,
    Clod,
    Sap,
    Enchantern,
    Mite,
    Bat,
    Mimic,
    Spirit,
    Cat,
    RockStack,
    Statue,
    Tome,

    LEN
}

function create_monster_prototypes() {
    var monster_prototypes = array_create(MonsterId.LEN, undefined);

    for (var monster_category = 0; monster_category < MonsterCategory.LEN; monster_category++) {
        var f_monster_category = fiddle_get(format("monsters/{MonsterCategory}", monster_category));
        var f_monster_default = f_monster_category[$ "default"];

        for (var monster_id = 0; monster_id < MonsterId.LEN; monster_id++) {
            var f_monster = f_monster_category[$ monster_id_to_string(monster_id)];
            if f_monster == undefined {
                continue;
            }

            var obj = clone_value(f_monster_default);
            patch_object(f_monster, obj);

            var c = 0;
            var name_functor = undefined;

            switch monster_category {
                case MonsterCategory.Shroom:
                    c = MushroomState.LEN;
                    name_functor = mushroom_state_to_string;
                    break;
                case MonsterCategory.Clod:
                    c = RockclodState.LEN;
                    name_functor = rockclod_state_to_string;
                    break;
                case MonsterCategory.Sap:
                    c = SaplingState.LEN;
                    name_functor = sapling_state_to_string;
                    break;
                case MonsterCategory.Enchantern:
                    c = EnchanternState.LEN;
                    name_functor = enchantern_state_to_string;
                    break;
                case MonsterCategory.Mite:
                    c = MiteState.LEN;
                    name_functor = mite_state_to_string;
                    break;
                case MonsterCategory.Bat:
                    c = BatState.LEN;
                    name_functor = bat_state_to_string;
                    break;
                case MonsterCategory.Mimic:
                    c = MimicState.LEN;
                    name_functor = mimic_state_to_string;
                    break;
                case MonsterCategory.Spirit:
                    c = SpiritState.LEN;
                    name_functor = spirit_state_to_string;
                    break;
                case MonsterCategory.Cat:
                    c = CatState.LEN;
                    name_functor = cat_state_to_string;
                    break;
                case MonsterCategory.RockStack:
                    c = RockStackState.LEN;
                    name_functor = rock_stack_state_to_string;
                    break;
                case MonsterCategory.Statue:
                    c = StatueState.LEN;
                    name_functor = statue_state_to_string;
                    break;
                case MonsterCategory.Tome:
                    c = TomeState.LEN;
                    name_functor = tome_state_to_string;
                    break;
                default: impossible();
            }

            if array_length(struct_get_names(obj.sprites)) > (c + 1) {
                warn("{MonsterId} has more sprites than necessary!", monster_id);
            }

            var sprite_catalogue = array_create(c, undefined);
            for (var i = 0; i < c; i++) {
                var name = name_functor(i);
                var value = obj.sprites[$ name];

                assert_neq(
                    value,
                    undefined,
                    "sprite.{} was undefined in {MonsterId}, but we need it for {MonsterCategory}!",
                    name,
                    monster_id,
                    monster_category,
                );

                //
                if is_string(value) {
                    var asset = string_to_asset(value);
                    sprite_catalogue[i] = [asset, asset, asset, asset];
                } else {
                    sprite_catalogue[i] = [
                        opt_and_then(value[$ "east"], string_to_asset),
                        string_to_asset(value.north),
                        opt_and_then(value[$ "east"], string_to_asset),
                        string_to_asset(value.south),
                    ];
                }
            }

            obj.misc_sprites = {};
            if obj.sprites[$ "misc"] != undefined {
                var names = struct_get_names(obj.sprites.misc);
                for (var j = 0; j < array_length(names); j++) {
                    obj.misc_sprites[$ names[j]] = string_to_asset(obj.sprites.misc[$ names[j]]);
                };
            }

            obj.sprites = undefined;
            obj.sprite_catalogue = sprite_catalogue;

            var tango_catalogue = array_create(c, undefined);
            for (var i = 0; i < c; i++) {
                tango_catalogue[i] = opt_and_then(obj.tango[$ name_functor(i)], audio_asset_assert_exists);
            }
            obj.misc_tango = {};
            if obj.tango[$ "misc"] != undefined {
                var names = struct_get_names(obj.tango.misc);
                for (var j = 0; j < array_length(names); j++) {
                    obj.misc_tango[$ names[j]] = audio_asset_assert_exists(obj.tango.misc[$ names[j]]);
                };
            }
            obj.coin_count = opt_and_then(obj[$ "coin_count"], fiddle_deserialize_vec2) ?? [0, 0];
            obj.tango_catalogue = tango_catalogue;
            obj.tango = undefined;

            //
            obj.monster_category = monster_category;
            obj.monster_id = monster_id;
            obj.gm_object = object(obj.gm_object);
            obj.hurtbox = opt_and_then(obj[$ "hurtbox"], string_to_asset);
            obj.hitbox = opt_and_then(obj[$ "hitbox"], string_to_asset);

            //
            {
                var drop_bundle_data = List();
                for (var j = 0; j < array_length(obj.drops); j++) {
                    var drop_data = obj.drops[j];

                    var chance_pct = drop_data[$ "chance"] ?? 100;
                    assert(is_real(chance_pct));
                    var count_range = drop_data[$ "count_range"] ?? [1, 1];
                    assert(is_array(count_range));
                    var exclusive = bool(drop_data[$ "exclusive"] ?? true);
                    var perfect_pick_chance = drop_data[$ "perfect_pick_chance"] == undefined ? 0 : drop_data.perfect_pick_chance;
                    drop_bundle_data.push(new ItemDrop(chance_pct, exclusive, parse_reward(drop_data), count_range, perfect_pick_chance));
                }
                obj.drops = new ItemDropBundle(drop_bundle_data, function(v) {
                    var reward_list = consume_reward(v);
                    return reward_list.first();
                });
            }

            //
            switch monster_category {
                case MonsterCategory.Shroom:
                    break;
                case MonsterCategory.Clod:
                    obj.bomb_sprite = opt_and_then(obj[$ "bomb_sprite"], string_to_asset);
                    obj.bomb_sprite_fx = opt_and_then(obj[$ "bomb_sprite_fx"], string_to_asset);
                    obj.collision_default = opt_and_then(obj[$ "collision_default"], string_to_asset);
                    obj.collision_jump = opt_and_then(obj[$ "collision_jump"], string_to_asset);
                    break;
                case MonsterCategory.Sap:
                    obj.death_bits = opt_and_then(obj[$ "death_bits"], string_to_asset);
                    obj.collision_box_jump = opt_and_then(obj[$ "collision_box_jump"], string_to_asset);
                    obj.collision_box_default = opt_and_then(obj[$ "collision_box_default"], string_to_asset);
                    break;
                case MonsterCategory.Enchantern:
                    obj.electrocute_kind = string_to_electrocute_kind(obj.electrocute_kind);
                    break;
                case MonsterCategory.Mite:
                    if obj.secondary_spikes == false {
                        obj.secondary_spikes = undefined;
                    }
                    break;
                case MonsterCategory.Bat:
                case MonsterCategory.Mimic:
                case MonsterCategory.Tome:
                    break;
                case MonsterCategory.RockStack:
                    var drop_bundle_data = List();
                    obj.lut = opt_and_then(obj.lut, string_to_asset);
                    obj.landing_vfx = opt_and_then(obj.landing_vfx, string_to_asset);
                    for (var j = 0; j < array_length(obj.super_drops); j++) {
                        var drop_data = obj.super_drops[j];

                        var chance_pct = drop_data[$ "chance"] ?? 100;
                        assert(is_real(chance_pct));
                        var count_range = drop_data[$ "count_range"] ?? [1, 1];
                        assert(is_array(count_range));
                        var exclusive = bool(drop_data[$ "exclusive"] ?? true);
                        var perfect_pick_chance = drop_data[$ "perfect_pick_chance"] == undefined ? 0 : drop_data.perfect_pick_chance;
                        drop_bundle_data.push(new ItemDrop(chance_pct, exclusive, parse_reward(drop_data), count_range, perfect_pick_chance));
                    }
                    obj.super_drops = new ItemDropBundle(drop_bundle_data, function(v) {
                        var reward_list = consume_reward(v);
                        return reward_list.first();
                    });
                    break;
                case MonsterCategory.Cat:
                    if obj.light_hater == false {
                        obj.light_hater = undefined;
                    }
                    break;
            }

            assert_eq(monster_prototypes[monster_id], undefined, "monster {Monster} defined twice somehow!", monster_id);
            monster_prototypes[monster_id] = obj;
        }
    }

    return monster_prototypes;
}

function spawn_monster(xx, yy, monster_id) {
    var config = MONSTER_PROTOTYPES[monster_id];
    return instance_create_depth(xx, yy, 0, config.gm_object, { config, monster_id });
}
