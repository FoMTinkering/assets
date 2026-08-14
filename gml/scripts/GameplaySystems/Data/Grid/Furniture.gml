#macro STORAGE_NODES global.__STORAGE_NODES
STORAGE_NODES = List();

#macro ESSENCE_STONES global.__essence_stones
ESSENCE_STONES = [ItemId.EssenceStoneLarge, ItemId.EssenceStoneMedium, ItemId.EssenceStoneSmall, ItemId.EssenceStoneTiny];

#macro IN_HOUSE_STAIR_SEGMENT global.__in_house_stair_segment
IN_HOUSE_STAIR_SEGMENT = false

#macro STAIR_COUNT global.__stair_count
STAIR_COUNT = 0

//
function create_furniture_prototype(object_id, fiddle_obj) {
    static CARDINAL_PARSE_ENTRY = function(obj, fiddle_object, read_name, func) {
        for (var i = 0; i < array_length(obj.cardinals); i++) {
            var cardinal = obj.cardinals[i];

            var is_mirror_case = obj.mirror_west && cardinal == Cardinal.West;

            //
            if is_mirror_case {
                cardinal = Cardinal.East;
            }

            var cardinal_string = cardinal_to_string(cardinal);
            var parsed_val = func(fiddle_object[$ cardinal_string][$ read_name]);

            //
            if is_mirror_case {
                cardinal = Cardinal.West;
            }

            //
            obj.cardinal_data[cardinal][$ read_name] = parsed_val;
        }
    }

    var o = {
        object_id: object_id,
        size: fiddle_deserialize_vec2(fiddle_obj[$ "size"]),
        destructable: fiddle_obj[$ "destructable"],
        depth_offset: fiddle_obj[$ "depth_offset"],
        interact_mask: undefined,
        can_overlap_collision: fiddle_obj[$ "can_overlap_collision"] ?? false,
        mirror_west: false,
        depth_to_floor: fiddle_obj.depth_to_floor,
        is_journal: fiddle_obj.is_journal,
        bed_kind: fiddle_obj[$ "bed_kind"] != false
            ? opt_and_then(fiddle_obj[$ "bed_kind"], string_to_bed_kind)
            : undefined,
        rug: fiddle_obj.rug,
        fence: fiddle_obj.fence,
        bird_perch: fiddle_deserialize_vec2(is_array(fiddle_obj.bird_perch) ? fiddle_obj.bird_perch : undefined),
        footstep: is_string(fiddle_obj.footstep)
            ? string_to_footstep_kind(fiddle_obj.footstep)
            : (is_array(fiddle_obj.footstep)
                ? array_map(fiddle_obj.footstep, string_to_footstep_kind)
                : undefined),
        pet_bed: fiddle_obj.pet_bed,
        pet_dish: opt_and_then(fiddle_obj[$ "pet_dish"], function(pet_dish_data) {
            //
            if pet_dish_data == false {
                return undefined;
            }

            return {
                offset: fiddle_deserialize_vec2(pet_dish_data.offset)
            }
        }),
        forecaster: opt_and_then(fiddle_obj[$ "forecaster"], function(forecaster) {
            return fiddle_deserialize_season(forecaster, function(seasonal_data) {
                var output = array_create(Weather.LEN, undefined);

                for (var i = 0; i < Weather.LEN; i++) {
                    output[i] = string_to_asset(seasonal_data[$ weather_to_string(i)]);
                }

                return output;
            });
        }),
        sprinkler: fiddle_obj[$ "sprinkler"],
        essence_machine: opt_and_then(fiddle_obj[$ "essence_machine"], function(v) {
            assert(fiddle_contains(v.interaction_fiddle_path));

            return {
                interaction_fiddle_path: v.interaction_fiddle_path,
                stone_offset: fiddle_deserialize_vec2(v.stone_offset),
            }
        }),
        placeable_locations: array_map(fiddle_obj.placeable_locations, string_to_location_id),
        on_twos_only: fiddle_obj.on_twos_only,
        check_pick: fiddle_obj.check_pick,
        can_be_child: fiddle_obj.can_be_child,
        is_date_photo: fiddle_obj.is_date_photo,
        activities: opt_and_then(fiddle_obj[$ "activities"], function(a) {
            return apply_func(a, function(v) {
                v.positions = apply_func(v.positions, function(v) {
                    var offsets = undefined;
                    if is_array(v) {
                        offsets = array_create(Cardinal.LEN, array_to_vec2(v));
                    } else {
                        offsets = array_create(Cardinal.LEN);
                        apply_struct_to_array(offsets, v, string_to_cardinal, array_to_vec2);
                    }

                    //
                    //
                    if offsets[Cardinal.West] == undefined && offsets[Cardinal.East] != undefined {
                        offsets[Cardinal.West] = offsets[Cardinal.East].clone();
                        offsets[Cardinal.West].x *= -1;
                    }

                    return offsets;
                });
                v.direction = opt_and_then(v[$ "direction"], string_to_cardinal);
                return v;
            });
        }),
        house_stairs: opt_and_then(fiddle_obj[$ "house_stairs"], function(v) {
            var drop_off_offset = array_create(Cardinal.LEN);
            apply_struct_to_array(
                drop_off_offset,
                v.drop_off_offset,
                string_to_cardinal,
                fiddle_deserialize_vec2,
            );

            var disappearance_animation = array_create(Cardinal.LEN);
            if v[$ "disappearance_animation"] != undefined {
                apply_struct_to_array(
                    disappearance_animation,
                    v.disappearance_animation,
                    string_to_cardinal,
                    string_to_asset,
                );
            }

            var appearance_animation = array_create(Cardinal.LEN);
            if v[$ "appearance_animation"] != undefined {
                apply_struct_to_array(
                    appearance_animation,
                    v.appearance_animation,
                    string_to_cardinal,
                    string_to_asset,
                );
            }

            return {
                paired_object: string_to_object_id(v.paired_object),
                drop_off_offset,
                pathfind_first: opt_and_then(v[$ "pathfind_first"], fiddle_deserialize_vec2),
                disappearance_animation,
                appearance_animation,
            };
        }),
        interact_menu: opt_and_then(fiddle_obj[$ "interact_menu"], function(v) {
            return {
                ari_offset: array_to_vec2(v.ari_offset),
                menu: v.menu,
                kitchen_level: v[$ "kitchen_level"] ?? -1,
                bubble_big: string_to_asset(v.bubble_big),
                bubble_small: string_to_asset(v.bubble_small),
                offset: v.offset,
            }
        }),
        soup_pot: opt_and_then(fiddle_obj[$ "soup_pot"], function(v) {
            return {
                item: string_to_item_id(v.item),
                light: string_to_light(v.light),
                light_offset: fiddle_deserialize_vec2(v.light_offset),
            }
        }),
        continual_sound: opt_and_then(fiddle_obj[$ "continual_sound"], audio_asset_assert_exists),
        restoration: opt_and_then(
            fiddle_obj[$ "restoration"] != false ? fiddle_obj.restoration : undefined,
            function(v) {
                v.convo = string_to_gp_triggered_conversation(v.convo);
                return v;
            },
        ),
        is_crystal_resonator: fiddle_obj.is_crystal_resonator,
        write_flag: fiddle_obj["write_flag"] == false ? undefined : fiddle_obj["write_flag"],
    };

    //
    o.cardinals = [];
    o.cardinal_data = array_create(Cardinal.LEN, undefined);
    for (var i = 0; i < Cardinal.LEN; i ++) {
        var f_cardinal = (Cardinal.South + i) % Cardinal.LEN;
        var f = fiddle_obj[$ cardinal_to_string(f_cardinal)];

        if f == undefined {
            //
            if f_cardinal == Cardinal.West
                && fiddle_obj.mirror_west
                && o.cardinal_data[Cardinal.East] != undefined
            {
                array_push(o.cardinals, f_cardinal);
                o.cardinal_data[f_cardinal] = {
                    cardinal_offset: i
                };
                o.mirror_west = true;
            }

            continue;
        }

        array_push(o.cardinals, f_cardinal);
        o.cardinal_data[f_cardinal] = {
            cardinal_offset: i
        };
    }

    //
    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "sprite", string_to_asset);
    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "animation", function(v) {
        return opt_and_then(v, string_to_asset);
    });

    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "offset", function(v) {
        var output = fiddle_deserialize_vec2(v);
        if output == undefined {
            output = Vec2();
        }

        return output;
    });
    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "top_sprite", function(value) {
        return opt_and_then(value, string_to_asset);
    });
    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "winter_top_sprite", function(value) {
        return opt_and_then(value, string_to_asset);
    });
    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "top_sprite_depth_offset", function(value) {
        return value ?? 0;
    });
    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "floor_sprite", function(value) {
        return opt_and_then(value, string_to_asset);
    });
    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "winter_floor_sprite", function(value) {
        return opt_and_then(value, string_to_asset);
    });
    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "on_sprite", function(value) {
        return opt_and_then(value, string_to_asset);
    });
    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "winter_sprite", function(value) {
        return opt_and_then(value, string_to_asset);
    });
    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "summer_sprite", function(value) {
        return opt_and_then(value, string_to_asset);
    });
    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "fall_sprite", function(value) {
        return opt_and_then(value, string_to_asset);
    });
    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "flipper", function(data) {
        return data ?? 1;
    });
    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "interact_mask", function(data) {
        return opt_and_then(data, string_to_asset);
    });
    CARDINAL_PARSE_ENTRY(o, fiddle_obj, "secondary_sprite", function(data) {
        return opt_and_then(data, string_to_asset);
    });

    //
    if is_struct(fiddle_obj.interaction_turn_on) {
        o.interaction_turn_on = {
            turn_on_sound: opt_and_then(fiddle_obj.interaction_turn_on[$ "turn_on_sound"], audio_asset_assert_exists),
            turn_off_sound: opt_and_then(fiddle_obj.interaction_turn_on[$ "turn_off_sound"], audio_asset_assert_exists),
            continual_on_sound: opt_and_then(fiddle_obj.interaction_turn_on[$ "continual_on_sound"], audio_asset_assert_exists),
            light: opt_and_then(fiddle_obj.interaction_turn_on[$ "light"], string_to_light),
            light_offset: opt_and_then(fiddle_obj.interaction_turn_on[$ "light_offset"], fiddle_deserialize_vec2) ?? Vec2(),
            pause_when_off: fiddle_obj[$ "pause_when_off"] ?? false,
            interact_local: opt_and_then(fiddle_obj.interaction_turn_on[$ "interact_local"], function(v) {
                assert(fiddle_contains(format("{}", v)), "interact_local {} is not in misc_local.toml", v);
                return v;
            }),
            interact_local_off: opt_and_then(fiddle_obj.interaction_turn_on[$ "interact_local_off"], function(v) {
                assert(fiddle_contains(format("{}", v)), "interact_local_off {} is not in misc_local.toml", v);
                return v;
            })
        };
    } else {
        o.interaction_turn_on = undefined;
    }

    //
    if is_struct(fiddle_obj.interaction_chest) {
        o.interaction_chest = {
            open_sprite: string_to_asset(fiddle_obj.interaction_chest.open_sprite),
            opening_sprite: string_to_asset(fiddle_obj.interaction_chest.opening_sprite),
            bounce_sprite: string_to_asset(fiddle_obj.interaction_chest.bounce_sprite),

            inventory_size: fiddle_obj.interaction_chest.inventory_size,
            allow_soulbound: fiddle_obj.interaction_chest[$ "allow_soulbound"] ?? true,
            shipping_bin: fiddle_obj.interaction_chest[$ "shipping_bin"] ?? false,
            belongs_to_ari: fiddle_obj.interaction_chest[$ "belongs_to_ari"] ?? true,
            bark_offset: fiddle_obj.interaction_chest[$ "bark_offset"] ?? fiddle_get("interaction/storage_offset"),
            open_sfx: fiddle_obj.interaction_chest[$ "open_sfx"] ?? "SoundEffects/Objects/OpenStorageChest",
            close_sfx: fiddle_obj.interaction_chest[$ "close_sfx"] ?? "SoundEffects/Objects/CloseStorageChest"
        };
    } else {
        o.interaction_chest = undefined;
    }

    if fiddle_obj[$ "factory"] != undefined {
        var request_data = array_map(fiddle_obj.factory.requests, function(request) {
            return {
                item_id: string_to_item_id(request.item),
                requirements: parse_requirements(request.requirements)
            }
        });

        o.factory = {
            full_sprite : string_to_asset(fiddle_obj.factory.full_sprite),
            bounce_sprite : string_to_asset(fiddle_obj.factory.bounce_sprite),
            bark_icon: string_to_asset(fiddle_obj.factory.bark_icon),
            bark_icon_small: string_to_asset(fiddle_obj.factory.bark_icon_small),
            request_data,
            days_to_produce: fiddle_obj.factory.days_to_produce,
            legal_tags: fiddle_obj.factory.legal_tags,
            illegal_tags: fiddle_obj.factory.illegal_tags,
            full_sounds: fiddle_obj.factory.full_sounds,
            invert_tags: fiddle_obj.factory[$ "invert_tags"] ?? false,
            inventory_size: fiddle_obj.factory.inventory_size,
            rewards_map: array_map(fiddle_obj.factory.rewards_map, function(input) {
                var arr = is_array(input) ? input : [input];
                for (var i = 0, ic = array_length(arr); i < ic; i++) {
                    arr[i] = string_to_item_id(arr[i]);
                }
                return arr;
            }),
            ui_data: fiddle_obj.factory.ui_data,
            apiary_offset: fiddle_obj.factory.apiary_offset_key,
            thought_bubble_offset: fiddle_deserialize_vec2(fiddle_obj.factory.thought_bubble_offset),
        }
        assert(array_length(o.factory.rewards_map) == FactoryTier.LEN, "Reward map must have {} entries but only has {}, are you missing a rarity?", array_length(o.factory.rewards_map), FactoryTier.LEN);
    } else {
        o.factory = undefined;
    }

    //
    if is_array(fiddle_obj.window_tiles) {
        var output_grid = ds_grid_create(o.size.x, o.size.y);

        //
        assert_eq(array_length(fiddle_obj.window_tiles), o.size.y, "window_tiles height mismatch ({} != {}) for {ObjectId}", array_length(fiddle_obj.window_tiles), o.size.y, object_id);
        for (var j = 0; j < o.size.y; j ++) {
            var str_seq = fiddle_obj.window_tiles[j];
            assert_eq(string_length(str_seq), o.size.x, "window_tiles width mismatch ({} != {}) for {ObjectId}", string_length(str_seq), o.size.x, object_id);
            for (var i = 0; i < o.size.x; i ++) {
                output_grid[# i, j] = string_char_at(str_seq, i + 1) == "1";
            }
        }

        o.window_tiles = output_grid;
    } else {
        o.window_tiles = undefined;
    }

    if is_struct(fiddle_obj.light_always_on) {
        o.light_always_on = {
            continual_on_sound: opt_and_then(fiddle_obj.light_always_on[$ "continual_on_sound"], audio_asset_assert_exists),
            light: opt_and_then(fiddle_obj.light_always_on[$ "light"], string_to_light),
            light_offset: opt_and_then(fiddle_obj.light_always_on[$ "light_offset"], fiddle_deserialize_vec2) ?? Vec2(),
        };
    } else {
        o.light_always_on = undefined;
    }

    if is_struct(fiddle_obj.animal_toy) {
        o.animal_toy = {
            species: deserialize_array_bool(fiddle_obj.animal_toy.species, string_to_animal_kind, AnimalKind.LEN),
            centered_pets: fiddle_obj.animal_toy[$ "centered_pets"] == undefined
                ? array_bool(PetKind.LEN)
                : deserialize_array_bool(fiddle_obj.animal_toy.centered_pets, string_to_pet_kind, PetKind.LEN),
            active_animation: string_to_asset(fiddle_obj.animal_toy.active_animation),
            animal_idle: fiddle_obj.animal_toy[$ "animal_idle"],
            inhibit_depth: fiddle_obj.animal_toy.inhibit_depth,
            inhibit_shadow: fiddle_obj.animal_toy.inhibit_shadow,
            active_sfx: fiddle_obj.animal_toy[$ "active_sfx"],
            attach_points: {
                left: array_map(fiddle_obj.animal_toy.attach_points.left, function(v) {
                    var tango = v[$ "tango"];
                    if tango != undefined {
                        audio_asset_assert_exists(tango);
                    }

                    return {
                        offset: fiddle_deserialize_vec2(v.offset),
                        celebrate: v[$ "celebrate"] ?? false,
                        play_animation: v[$ "play_animation"],
                        tango,
                    }
                }),
                right: array_map(fiddle_obj.animal_toy.attach_points.right, function(v) {
                    var tango = v[$ "tango"];
                    if tango != undefined {
                        audio_asset_assert_exists(tango);
                    }
                    return {
                        offset: fiddle_deserialize_vec2(v.offset),
                        celebrate: v[$ "celebrate"] ?? false,
                        play_animation: v[$ "play_animation"],
                        tango,
                    }
                }),
                center: opt_and_then(fiddle_obj.animal_toy.attach_points[$ "center"], function(val) {
                    return array_map(val, function(v) {
                        var tango = v[$ "tango"];
                        if tango != undefined {
                            audio_asset_assert_exists(tango);
                        }
                        return {
                            offset: fiddle_deserialize_vec2(v.offset),
                            celebrate: v[$ "celebrate"] ?? false,
                            play_animation: v[$ "play_animation"],
                            tango,
                        }
                    })
                }),
            },
            extra_renderer: opt_and_then(fiddle_obj.animal_toy[$ "extra_renderer"], function(v) {
                return {
                    inactive: string_to_asset(v.inactive),
                    active: string_to_asset(v.active),
                }
            }),
            celebrate_blocker: fiddle_obj.animal_toy.celebrate_blocker,
            celebrate_chance: fiddle_obj.animal_toy.celebrate_chance,
        };
        assert_eq(sprite_get_number(o.animal_toy.active_animation), array_length(o.animal_toy.attach_points.left));
        assert_eq(sprite_get_number(o.animal_toy.active_animation), array_length(o.animal_toy.attach_points.right));

        //
        for (var i = 0; i < array_length(o.animal_toy.attach_points.left); i++) {
            var attach_point_data = o.animal_toy.attach_points.left[i];
            attach_point_data.offset.x -= sprite_get_xoffset(o.animal_toy.active_animation);
            attach_point_data.offset.y -= sprite_get_yoffset(o.animal_toy.active_animation);
        }
        for (var i = 0; i < array_length(o.animal_toy.attach_points.right); i++) {
            var attach_point_data = o.animal_toy.attach_points.right[i];
            attach_point_data.offset.x -= sprite_get_xoffset(o.animal_toy.active_animation);
            attach_point_data.offset.y -= sprite_get_yoffset(o.animal_toy.active_animation);
        }
    } else {
        o.animal_toy = undefined;
    }

    //
    //
    if o.mirror_west {
        o.cardinal_data[Cardinal.West].offset = o.cardinal_data[Cardinal.East].offset.clone();
        o.cardinal_data[Cardinal.West].flipper = -1;
    }

    //
    o.collision_grid = parse_collision_strings(o.size, fiddle_obj[$ "collision_grid"], o.object_id);
    o.rule_grid = parse_rule_strings(o.size, fiddle_obj[$ "rule_grid"], o.object_id);

    var on_wall = true;
    for (var xx = 0; xx < ds_grid_width(o.rule_grid); xx++) {
        for (var yy = 0; yy < ds_grid_height(o.rule_grid); yy++) {
            if has_flag(o.rule_grid[# xx, yy], TileFlag.PlaceableWall) == false {
                on_wall = false;
                break;
            }
        }

        if on_wall == false {
            break;
        }
    }
    o.on_wall = on_wall;

    if fiddle_obj[$ "input_terrain"] == undefined {
        o.input_terrain = undefined;
    } else {
        o.input_terrain = parse_terrain_grid(o.size, fiddle_obj.input_terrain, o.object_id);
    }
    if fiddle_obj[$ "output_terrain"] == undefined {
        o.output_terrain = undefined;
    } else {
        o.output_terrain = parse_terrain_grid(o.size, fiddle_obj.output_terrain, o.object_id);
    }

    //
    var f_sub_grid = fiddle_obj[$ "child_grid"];
    if f_sub_grid != false && f_sub_grid != undefined {
        o.sub_grid = ds_grid_create(o.size.x, o.size.y);

        if is_string(f_sub_grid) {
            assert_eq(string_length(f_sub_grid), 1, "child_grid was longer than 1 character. That doesn't make any sense");
            var sub_cell = real(string_char_at(f_sub_grid, 1)) ? tile_rule_to_tile_flag(TileRule.PlayerDecoration) : 0;

            for (var j = 0; j < o.size.y; j++) {
                for (var i = 0; i < o.size.x; i++) {
                    o.sub_grid[# i, j] = sub_cell;
                }
            }
        } else {
            //
            var f_sub_h = array_length(f_sub_grid);
            assert_eq(f_sub_h, o.size.y, "child_grid height mismatch ({} != {}) for {ObjectId}", f_sub_h, o.size.y, o.object_id);
            //
            o.sub_grid = ds_grid_create(o.size.x, o.size.y);
            for (var j = 0; j < f_sub_h; j ++) {
                var str_seq = f_sub_grid[j];
                var f_sub_w = string_length(str_seq);
                assert_eq(f_sub_w, o.size.x, "child_grid width mismatch ({} != {}) for {ObjectId}", f_sub_w, o.size.x, o.object_id);
                for (var i = 0; i < f_sub_w; i ++) {
                    var sub_cell = real(string_char_at(str_seq, i + 1));
                    o.sub_grid[# i, j] = sub_cell ? tile_rule_to_tile_flag(TileRule.PlayerDecoration) : 0;
                }
            }
        }

        CARDINAL_PARSE_ENTRY(o, fiddle_obj, "child_grid_offset", function(data) {
            return opt_and_then(data, fiddle_deserialize_vec2);
        });

        var default_caser = opt_and_then(fiddle_obj[$ "child_grid_offset"], fiddle_deserialize_vec2) ?? Vec2();
        for (var i = 0; i < array_length(o.cardinals); i++) {
            var cardinal = o.cardinals[i];

            if o.cardinal_data[cardinal][$ "child_grid_offset"] == undefined {
                o.cardinal_data[cardinal].child_grid_offset = default_caser.clone();
            }
        }

        //
        if o.mirror_west
            && o.cardinal_data[Cardinal.West] != undefined
        {
            //
            if o.size.x % 2 == 1 {
                o.cardinal_data[Cardinal.West].child_grid_offset.y += 8;
            }
            //
            if o.size.y % 2 == 1 {
                o.cardinal_data[Cardinal.West].child_grid_offset.x += 8;
            }
        }
    } else {
        o.sub_grid = undefined;
    }

    //
    if o.rug {
        assert(o.depth_to_floor, "{ObjectId} is marked as a rug, but doesn't have `depth_to_floor`. It should!", object_id);

        for (var i = 0; i < o.size.x; i++) {
            for (var j = 0; j < o.size.y; j++) {
                var col = o.collision_grid[# i, j];
                assert_eq(col, 0, "{ObjectId} is marked as a rug, but has a collision on it. That's chaos!", object_id);
            }
        }

        assert_eq(o.sub_grid, undefined, "{ObjectId} is marked as a rug, but it has a sub_grid. That's a crime!", object_id);
    }

    if object_id == ObjectId.BigBell {
        o.ring_sprite = string_to_asset(fiddle_obj.ring_sprite);
        o.ring_count = fiddle_obj.ring_count;
    }
    return o;
}

//
function write_furniture_to_location(grid, xx, yy, proto, stack_count, rotation=0) {
    if array_length(proto.cardinals) == 0 || stack_count >= 3 || (stack_count > 0 && proto.can_be_child == false)  {
        return undefined;
    }

    //
    if proto.house_stairs != undefined
        && array_contains(proto.placeable_locations, grid.location_id) == false
    {
        proto = NODE_PROTOTYPES[proto.house_stairs.paired_object];
    }

    //
    var calc_rot = furniture_rotation_amount(rotation, proto);
    //
    //
    //
    //
    var rotation_matrix = furniture_calc_rot_to_rotation_matrix(calc_rot, proto);

    //
    if proto.rug == false {
        var node_at_pos = grid.try_node_index_for_cell(xx, yy);
        if node_at_pos == undefined {
            return undefined;
        }
        if object_id_to_object_category(grid.node_object_id[node_at_pos]) == ObjectCategory.Furniture
            && grid.node_parent[node_at_pos].child_grid != undefined
        {
            return write_furniture_to_location(
                grid.node_parent[node_at_pos].child_grid,
                xx - grid.node_parent[node_at_pos].top_left_x,
                yy - grid.node_parent[node_at_pos].top_left_y,
                proto,
                stack_count + 1,
                rotation
            );
        }
    }

    var region = furniture_size(rotation_matrix, proto);
    if local_pos_is_valid(grid, xx, yy, region) == false {
        return undefined;
    }

    //
    if proto.object_id == ObjectId.OcarinaSpriteStatue
        && (grid.parent_node == undefined || grid.parent_node.object_id != ObjectId.OcarinaSpriteStatueBase)
    {
        return undefined;
    }

    //
    if proto.object_id == ObjectId.AutoFeeder
        && (grid.parent_node == undefined || grid.parent_node.object_id != ObjectId.AutoFeederPlatform)
    {
        return undefined;
    }

    //
    //
    var rot_data = furniture_mask_prep_vecdata(proto.size, rotation_matrix);

    if !furniture_test_flag_mask(
        rot_data,
        grid,
        xx,
        yy,
        proto,
        rotation_matrix,
        false,
        grid != GRID,
    ) {
        return undefined;
    }

    var node = create_parent_object_node(proto, xx, yy, region);
    node.cardinal_index = calc_rot;
    node.destructable = proto.destructable;
    node.infusion = undefined;
    node.date_photo = undefined;
    node.on = false;

    var old_terrain = undefined;
    if proto.output_terrain != undefined {
        old_terrain = array_create(proto.size.x * proto.size.y, undefined);
    }

    //
    for (var i = 0; i < proto.size.x; i++) {
        for (var j = 0; j < proto.size.y; j++) {
            rot_data.offset.set_val(i - rot_data.center.x, j - rot_data.center.y);
            rot_data.offset.set_rotate(rotation_matrix);
            var posx = xx + abs(rot_data.transform.x) + rot_data.offset.x;
            var posy = yy + abs(rot_data.transform.y) + rot_data.offset.y;
            var this_cell_node = grid.try_node_index_for_cell(posx, posy);

            if proto.rug {
                //
                grid.node_rug_id[this_cell_node] = node.object_id;
                grid.node_rug_parent[this_cell_node] = node;
            } else {
                write_object_inst_node(grid, this_cell_node, node);
                set_collision_grid_flag_on_node(grid, proto.collision_grid[# i, j], posx, posy);
            }

            //
            if proto.output_terrain != undefined {
                var output_cell = proto.output_terrain[# i, j];
                if output_cell != undefined {
                    old_terrain[j * proto.size.x + i] = furniture_write_new_terrain(grid, this_cell_node, output_cell);
                }
            }

            if has_flag(grid.node_flags[this_cell_node], TileFlag.Unbreakable) {
                node.destructable = false;
            }

            if proto.bed_kind != undefined {
                grid.node_furniture_footstep[? this_cell_node] = FootstepKind.Carpet;
            }

            if proto.footstep != undefined {
                grid.node_furniture_footstep[? this_cell_node] = proto.footstep;
            }
        }
    }

    //
    node.old_terrain = old_terrain;
    if old_terrain != undefined {
        array_push(grid.terrain_editors, node);
    }

    //
    if proto.sub_grid != undefined {
        var grid_vec = furniture_mask_prep_vecdata(proto.size, rotation_matrix);
        node.child_grid = new Grid(region.x, region.y, grid.location_id);
        node.child_grid.parent_node = node;

        //
        for (var i = 0; i < proto.size.x; i ++) {
            for (var j = 0; j < proto.size.y; j ++) {
                grid_vec.offset.set_val(i - grid_vec.center.x, j - grid_vec.center.y);
                grid_vec.offset.set_rotate(rotation_matrix);
                var posx = abs(grid_vec.transform.x) + grid_vec.offset.x;
                var posy = abs(grid_vec.transform.y) + grid_vec.offset.y;

                write_ground_to_location(node.child_grid, posx, posy, TerrainKind.Ground);
                var inner_node = node.child_grid.node_index_for_cell(posx, posy);
                node.child_grid.node_flags[inner_node] = proto.sub_grid[# i, j];
            }
        }
    } else {
        node.child_grid = undefined;
    }

    //
    //
    node.parent_grid = grid;

    //
    if node.prototype.interaction_turn_on != undefined {
        node.is_on = false;
    }

    if node.object_id == ObjectId.TesseraeTree {
        node.day_count = 0;
    }

    if node.object_id == ObjectId.JunipersProtectionScroll {
        ARI.has_protection_scroll = true;
    }

    if node.prototype.is_date_photo {
        node.date_photo = undefined;
    }

    if node.prototype.bed_kind == BedKind.Double {
        T2R.write("ari_has_double_bed_placed", true);
    }

    if node.prototype.write_flag != undefined {
        T2R.write(node.prototype.write_flag, true);
    }

    //
    if node.prototype.interaction_chest != undefined {
        node.inventory = Inventory(node.prototype.interaction_chest.inventory_size);
        node.chest_icon = undefined;

        if node.prototype.interaction_chest.allow_soulbound == false {
            node.inventory.slots.for_each(function(slot) {
                slot.allow_soulbound = false;
            });
        };
    }

    if node.prototype.fence {
        autotile_furniture_fence_node(grid, node);
        if grid.is_setup && grid.location_id == CURRENT_LOCATION_ID {
            node.deploy_poof = TICK;
        }
    }

    if node.prototype.animal_toy != undefined {
        node.animal_count = 0;
    }

    if node.prototype.essence_machine {
        node.essence_supply = 0;
        node.activated_today = false;
    }

    if node.prototype.sprinkler != undefined {
        array_push(grid.sprinklers, node);
    }

    if node.object_id == ObjectId.OcarinaSpriteStatue {
        //
        var dyn_grid = DYNAMIC_GRIDS.get(grid.parent_node.parent_grid.dyn_index);
        dyn_grid.ocarina = node;
        node.sound_idx = undefined;
    }

    if node.object_id == ObjectId.AutoFeeder {
        var dyn_grid = DYNAMIC_GRIDS.get(grid.parent_node.parent_grid.dyn_index);
        dyn_grid.auto_feeder = node;
    }

    if node.prototype.pet_bed {
        array_push(grid.pet_beds, node);
    }

    if node.prototype.pet_dish != undefined {
        array_push(grid.pet_dishes, node);
    }

    if node.prototype.activities != undefined {
        grid.activity_nodes.push(node);
    }

    if node.prototype.soup_pot != undefined {
        node.status = PerpetualSoupStatus.NoItem;
    }

    if node.prototype.factory != undefined {
        FACTORIES.push(node);
    }

    //
    //
    if node.prototype.house_stairs != undefined && IN_HOUSE_STAIR_SEGMENT == false {
        //
        STAIR_COUNT += 1;

        if grid.is_setup {
            var corresponding_room = get_house_corresponding_room(grid.location_id);
            if corresponding_room != undefined {
                poof_furniture_to_items(
                    GRIDS[corresponding_room].lost_items,
                    (node.top_left_x + node.write_size_x * 0.5) * 8,
                    (node.top_left_y + node.write_size_y * 0.5) * 8,
                    GRIDS[corresponding_room],
                    node.top_left_x,
                    node.top_left_y,
                    node.top_left_x + node.write_size_x,
                    node.top_left_y + node.write_size_y
                );
            }

            IN_HOUSE_STAIR_SEGMENT = true;
            var success_object = GRIDS[corresponding_room].write_node(node.top_left_x, node.top_left_y, node.prototype.house_stairs.paired_object, rotation);
            if success_object == undefined {
                if DEBUG_ASSERTIONS {
                    crash("failed to write upper staircase!");
                } else {
                    error("Failed to write the upper staircase! This could be a game-breaking error");
                }
            }
            IN_HOUSE_STAIR_SEGMENT = false;
        }
    }

    if node.prototype.factory != undefined {
        node.day_count = 0;
        node.inventory = Inventory(node.prototype.factory.inventory_size);
        for (var i = 0, ic = node.inventory.size(); i < ic; i++) {
            node.inventory.slot(i).one_slot = true;
        }
        node.production_request = undefined;
        node.production_tier = undefined;
    }

    if node.object_id == ObjectId.AutoFeeder {
        node.inventory = Inventory(54);
    }

    if node[$ "inventory"] != undefined {
        STORAGE_NODES.push(node);
        node.use_in_crafting = node.prototype.interaction_chest != undefined
            && node.prototype.interaction_chest.belongs_to_ari
            && !node.prototype.interaction_chest.shipping_bin;
    }

    return node;
}

//
function autotile_furniture_fence_node(grid, node) {
    auto_tile_fence(grid, node.top_left_x, node.top_left_y);

    //
    auto_tile_fence(grid, node.top_left_x, node.top_left_y - 2);
    auto_tile_fence(grid, node.top_left_x, node.top_left_y + 2);
    auto_tile_fence(grid, node.top_left_x - 2, node.top_left_y);
    auto_tile_fence(grid, node.top_left_x + 2, node.top_left_y);
}

//
function create_furniture_renderer(node) {
    var cardinal_data = node.prototype.cardinal_data[node.cardinal_index];
    var sprite = cardinal_data.sprite;
    var mirror_these_sprites = cardinal_data.flipper == -1;

    var seasonal_override = cardinal_data[format("{Season}_sprite", CALENDAR.season())];
    if seasonal_override != undefined {
        sprite = seasonal_override;
    }

    var renderer_position = position_for_furniture_renderer(node);

    //
    var shadow_grid = undefined;
    if node.parent_grid.parent_node == undefined {
        if node.prototype.on_wall {
            //
            var wall_shadow = undefined;
            with obj_shadow_level {
                if self["wall_shadow"] {
                    wall_shadow = self;
                    break;
                }
            }
            if wall_shadow == undefined {
                warn("couldn't find wall `obj_shadow_level`. no shadows on wall for now!");
            } else {
                shadow_grid = wall_shadow.target_shadow_grid;
            }
        }
    } else {
        shadow_grid = node.parent_grid.parent_node.renderer.shadow_level.target_shadow_grid;
    }

    node.renderer = create_node_renderer(
        renderer_position.x,
        renderer_position.y,
        node,
        sprite,
        node.prototype.depth_offset,
        shadow_grid,
    );

    //
    if node.parent_grid.parent_node != undefined {
        node.renderer.depth = node.parent_grid.parent_node.renderer.depth
            - (node.top_left_y + node.write_size_y);
    }

    if cardinal_data.top_sprite != undefined {
        var sprite_to_use = cardinal_data.top_sprite;
        if CALENDAR.season() == Season.Winter && cardinal_data[$ "winter_top_sprite"] != undefined {
            sprite_to_use = cardinal_data.winter_top_sprite;
        }

        node.renderer.top_sheet_renderer = instance_create_layer(node.renderer.x, node.renderer.y, "Instances", obj_node_renderer_top);
        node.renderer.top_sheet_renderer.sprite_index = sprite_to_use;

        if node.parent_grid.parent_node != undefined {
            node.renderer.top_sheet_renderer.depth = node.renderer.depth - cardinal_data.top_sprite_depth_offset;
        } else {
            node.renderer.top_sheet_renderer.depth = get_instance_depth(node.renderer.y, -cardinal_data.top_sprite_depth_offset);
        }

        if mirror_these_sprites {
            node.renderer.top_sheet_renderer.image_xscale = -1;
        }
    }

    if cardinal_data.floor_sprite != undefined {
        var sprite_to_use = cardinal_data.floor_sprite;
        if CALENDAR.season() == Season.Winter && cardinal_data[$ "winter_floor_sprite"] != undefined {
            sprite_to_use = cardinal_data.winter_floor_sprite;
        }

        node.renderer.floor_renderer = instance_create_layer(node.renderer.x, node.renderer.y, "Instances", obj_node_renderer_top);
        node.renderer.floor_renderer.sprite_index = sprite_to_use;
        node.renderer.floor_renderer.depth = get_floor_depth();

        if !node.prototype.rug {
            node.renderer.floor_renderer.depth -= 1;
        }

        if mirror_these_sprites {
            node.renderer.floor_renderer.image_xscale = -1;
        }
    }

    if cardinal_data.secondary_sprite != undefined {
        node.renderer.set_secondary_sprite(cardinal_data.secondary_sprite);
    }

    if node.object_id == ObjectId.Forge {
        node.renderer.mask_index = cardinal_data.floor_sprite;
    }

    var setup_box_interaction = false;
    var interact_mask = cardinal_data.interact_mask;

    if node.prototype.bed_kind != undefined {
        node.renderer.interact("misc_local/sleep", interact_mask);

        if interact_mask == undefined {
            setup_box_interaction = true;
        }
    }

    //
    if node.prototype.continual_sound != undefined {
        node.renderer.sound_controller = new SoundInstanceController(
            TANGO.play(node.prototype.continual_sound, node.renderer.x, node.renderer.y)
        );
    }

    if node.prototype.restoration != undefined || matches(
        node.prototype.object_id,
        ObjectId.JunipersProtectionScroll,
        ObjectId.CaldarusDragonswornStatue,
    ) {
        node.renderer.interact("misc_local/inspect");
        setup_box_interaction = true;
    }

    if node.prototype.soup_pot != undefined {
        setup_box_interaction = true;

        node.renderer.highlight_interactable = true;
        register_interactable(node.renderer);

        node.renderer.light = instance_create_layer(
            node.renderer.x + node.prototype.soup_pot.light_offset.x,
            node.renderer.y + node.prototype.soup_pot.light_offset.y,
            "Lighting",
            par_light
        );
        node.renderer.light.tiered_light = node.prototype.soup_pot.light;
        node.renderer.light.sprite_index = LIGHTS[node.renderer.light.tiered_light][0];

        //
        node.renderer.register_interaction(
            InputId.Interact,
            "misc_local/input_interact",
            method(node.renderer, function() {
                //
                var callback = function(driver, soup) {
                    if driver.prompt_index_selected == 0 {
                        ARI.inventory.slot(ARI.held_item_index).pop();
                        ARI.ate_perpetual_soup_today = true;
                        use_item_fast(soup.item);
                    }
                };
                args = [self.node.prototype.soup_pot];

                //
                obj_ari.face_dir(point_direction(obj_ari.x, obj_ari.y, self.x, self.y));
                obj_ari.set_idle_simple();

                //
                play_conversation_from_path(NpcId.Hemlock, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.PerpetualSoup], callback, args);
            }),
            method(node.renderer, function() {
                return ARI.ate_perpetual_soup_today == false
                    && ARI.held_item() != undefined
                    && ARI.held_item().prototype.edible;
            }),
        );

        //
        node.renderer.register_interaction(
            InputId.Interact,
            "misc_local/input_interact",
            method(node.renderer, function() {
                obj_ari.face_dir(point_direction(obj_ari.x, obj_ari.y, self.x, self.y));
                obj_ari.set_idle_simple();

                //
                play_conversation_from_path(NpcId.Hemlock, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.PerpetualSoupNoItem]);
            }),
            method(node.renderer, function() {
                return ARI.ate_perpetual_soup_today == false
                    && (ARI.held_item() == undefined
                        || ARI.held_item().prototype.edible == false);
            }),
        );
    }

    if node.prototype.interaction_turn_on != undefined {
        if node.is_on {
            node.renderer.set_sprite(cardinal_data.on_sprite);
            if node.prototype.interaction_turn_on.continual_on_sound != undefined {
                node.renderer.sound_controller = new SoundInstanceController(TANGO.play(node.prototype.interaction_turn_on.continual_on_sound, node.renderer.x, node.renderer.y));
            }

            if node.prototype.interaction_turn_on.light != undefined {
                node.renderer.light = instance_create_layer(
                    node.renderer.x + node.prototype.interaction_turn_on.light_offset.x,
                    node.renderer.y + node.prototype.interaction_turn_on.light_offset.y,
                    "Lighting",
                    par_light
                );
                node.renderer.light.tiered_light = node.prototype.interaction_turn_on.light;
                node.renderer.light.sprite_index = LIGHTS[node.renderer.light.tiered_light][0];
            }

            if node.prototype.interaction_turn_on.interact_local != undefined {
                replace_interaction_local(
                    node.renderer,
                    node.prototype.interaction_turn_on.interact_local_off,
                    node.prototype.interaction_turn_on.interact_local
                );
            }
        }

        var local = "misc_local/input_interact";

        if node.prototype.interaction_turn_on.interact_local != undefined {
            local = node.is_on ? node.prototype.interaction_turn_on.interact_local_off : node.prototype.interaction_turn_on.interact_local;
        }

        node.renderer.interact(local, interact_mask);

        if interact_mask == undefined {
            setup_box_interaction = true;
        }
    }

    if node.prototype.light_always_on != undefined {
        if node.prototype.light_always_on.continual_on_sound != undefined {
            node.renderer.sound_controller = new SoundInstanceController(TANGO.play(node.prototype.light_always_on.continual_on_sound, node.renderer.x, node.renderer.y));
        }

        node.renderer.light = instance_create_layer(
            node.renderer.x + node.prototype.light_always_on.light_offset.x,
            node.renderer.y + node.prototype.light_always_on.light_offset.y,
            "Lighting",
            par_light
        );
        node.renderer.light.tiered_light = node.prototype.light_always_on.light;
        node.renderer.light.sprite_index = LIGHTS[node.renderer.light.tiered_light][0];
    }

    if node.prototype.bird_perch != undefined {
        node.renderer.linked_object = instance_create_depth(
            node.renderer.x + node.prototype.bird_perch.x,
            node.renderer.y,
            0,
            obj_bird_landing_position,
            {
                image_yscale: node.prototype.bird_perch.y
            }
        );
    }
    if node.prototype.factory != undefined {
        node.renderer.sound_keyframe_last = undefined;
        node.renderer.sound_chain = undefined;

        node.renderer.interact("misc_local/open", interact_mask);
        factory_node_set_full(node);
        if node.production_request != undefined {
            node.renderer.register_interaction(
                InputId.Throw,
                "misc_local/give_item",
                method(node, function() {
                    self.renderer.sprite_index = self.prototype.factory.bounce_sprite;
                    var arr = self.prototype.factory.rewards_map[self.production_tier];
                    ARI.inventory.slot(ARI.held_item_index).pop();
                    drop_item(
                        arr[irandom(array_length(arr) - 1)],
                        self.renderer.x,
                        self.renderer.y
                    );

                    if self.prototype.object_id == ObjectId.Apiary && chance_percent(15) {
                        drop_item(
                            ItemId.Honeycomb,
                            self.renderer.x,
                            self.renderer.y
                        );
                    }

                    TANGO.play("SoundEffects/Inventory/RewardDropAddition");
                    self.production_request = undefined;
                    self.day_count = 0;
                }),
                method(node, function() {
                    return ARI.held_item() != undefined && ARI.held_item().item_id == self.production_request;
                }),
            );
        }

        node.renderer.register_interaction(
            InputId.SecondaryInteract,
            "misc_local/inspect",
            method(node, function() {
                var c = function() {
                    FACTORY_INSPECT_CTX = undefined;
                }
                if self.production_request != undefined {
                    FACTORY_INSPECT_CTX = self.production_request;
                    play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.FactoryItemInspect], c);
                } else {
                    FACTORY_INSPECT_CTX = self.prototype.factory.days_to_produce - self.day_count;
                    if FACTORY_INSPECT_CTX == 1 {
                        play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.FactoryDaysRemainingSingular], c);
                    } else {
                        play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.FactoryDaysRemainingPlural], c);
                    }
                }
            }),
            method(node, function() {
                return self.inventory.total_items() == self.prototype.factory.inventory_size;
            })
        );

        node.renderer.give_animation_end_callback(function() {
            if self.sprite_index == self.node.prototype.factory.bounce_sprite  {
                factory_node_set_full(self.node);
            }
        });
    }

    if node.object_id == ObjectId.AutoFeeder {
        node.renderer.interact("misc_local/open", interact_mask);
    }

    if node.prototype.interaction_chest != undefined {
        node.renderer.interact("misc_local/open_chest", interact_mask);
        if interact_mask == undefined {
            setup_box_interaction = true;
        }

        node.renderer.give_animation_end_callback(function() {
            var chest_data = self.node.prototype.interaction_chest;
            if self.sprite_index == chest_data.opening_sprite {
                if sign(self.image_speed) == 1 {
                    self.sprite_index = chest_data.open_sprite;
                } else {
                    self.sprite_index = node.prototype.cardinal_data[node.cardinal_index].sprite;
                }
                self.image_speed = 1.0;
            } else if self.sprite_index == chest_data.bounce_sprite {
                self.sprite_index = node.prototype.cardinal_data[node.cardinal_index].sprite;
            }
        });

        if node.object_id != ObjectId.TurnInBox {
            with node.renderer {
                var key = node.prototype.interaction_chest.shipping_bin
                    ? "misc_local/ship_item"
                    : "misc_local/store_item";
                self.register_interaction(
                    InputId.Throw,
                    key,
                    function() {
                        var items = ARI.inventory.slot(ARI.held_item_index).drain();
                        obj_ari.fsm.blackboard.set("items_thrown", items);
                        obj_ari.fsm.blackboard.set("do_not_make_item", true);

                        furniture_chest_add_items(items, self.node);

                        obj_ari.fsm.change_state(PlayerState.ThrowItem);
                    },
                    function() {
                        var live_item = ARI.held_item();
                        return
                            live_item != undefined
                            && self.node.inventory.can_add(live_item, ARI.inventory.slot(ARI.held_item_index).count)
                            && ARI.held_animal_id == undefined
                    }
                );
            }
        }
    }

    if node.prototype.fence {
        node.renderer.image_speed = 0;
        node.renderer.image_index = node.fence_image_index;
        if node.renderer.shadow_caster != undefined {
            shadow_caster_set_image(node.renderer.shadow_caster, node.fence_image_index);
        }
        node.renderer.preview_fence_idx = undefined;

        if node[$ "deploy_poof"] == TICK {
            create_animation_effect(
                node.renderer.x,
                node.renderer.y,
                -1000,
                spr_fx_poof1_dirt_once
            );
        }
    }

    if node.prototype.window_tiles != undefined && instance_exists(obj_exterior_window_interior) {
        for (var xx = 0; xx < ds_grid_width(node.prototype.window_tiles); xx++) {
            for (var yy = 0; yy < ds_grid_height(node.prototype.window_tiles); yy++) {
                if node.prototype.window_tiles[# xx, yy] {
                    obj_exterior_window_interior.windows[# node.top_left_x + xx, node.top_left_y + yy] = true;
                }
            }
        }

        array_push(WINDOWS, node);
    }

    if node.object_id == ObjectId.SeedMaker {
        node.renderer.interact("misc_local/interact");
        node.renderer.register_interaction(
            InputId.SecondaryInteract,
            "misc_local/inspect",
            function() {
                play_conversation_from_path(NpcId.Adeline, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectSeedMaker]);
            }
        );
        node.renderer.give_animation_end_callback(function() {
            if self.sprite_index == spr_object_seed_maker_main_bounce {
                self.sprite_index = spr_object_seed_maker_main_idle;
            }
        });
    }

    if node.prototype.essence_machine != undefined {
        node.renderer.image_speed = 0;
        node.renderer.give_animation_end_callback(function() {
            self.image_index = 0;
            self.image_speed = 0;
        });

        if node.essence_supply > 0 {
            //
            var sprite = ITEM_PROTOTYPES[ItemId.EssenceStoneTiny].icon_sprite; //

            for (var i = 0; i < array_length(ESSENCE_STONES); i++) {
                var essence_id = ESSENCE_STONES[i];
                var proto = ITEM_PROTOTYPES[essence_id];
                if node.essence_supply >= proto.essence_charge  {
                    sprite = proto.icon_sprite;
                    break;
                }
            }

            node.renderer.essence_stone_sprite = sprite;
            node.renderer.essence_stone_offset_x = node.prototype.essence_machine.stone_offset.x;
            node.renderer.essence_stone_offset_y = node.prototype.essence_machine.stone_offset.y;
        }

        //
        node.renderer.interact("misc_local/place_essence_stone");
        setup_box_interaction = true;

        node.renderer.register_interaction(
            InputId.Interact,
            "misc_local/check_charge",
            method(node.renderer, function() {
                //
                obj_ari.face_dir(point_direction(obj_ari.x, obj_ari.y, self.x, self.y));

                obj_ari.set_idle_simple();
                ESSENCE_CHARGE = node.essence_supply;
                var c = function() {
                    ESSENCE_CHARGE = undefined;
                }
                if node.essence_supply == 1 {
                    play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.EssenceChargeRemainingSingular], c);
                } else {
                    play_conversation(NpcId.Caldarus, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.EssenceChargeRemainingPlural], c);
                }
            }),
            method(node.renderer, function() {
                return self.node.essence_supply > 0;
            })
        );
    }

    if node.prototype.sprinkler != undefined {
        node.renderer.image_index = 0;
        node.renderer.track_index = false;
        node.renderer.sprinkle_this_cycle = false;
    }

    //
    if node.object_id == ObjectId.OcarinaSpriteStatue
        && node.activated_today == false
        && node.essence_supply > 0
    {
        activate_ocarina(node);
    }

    if node.prototype.animal_toy != undefined {
        ANIMAL_TOYS_IN_ROOM.push(node);

        node.renderer.interact("misc_local/stop");
        setup_box_interaction = true;

        if node.prototype.animal_toy.extra_renderer != undefined {
            node.renderer.linked_object = instance_create_depth(0, 0, get_instance_depth(node.renderer.y), obj_animal_toy_extra_renderer, {
                node,
                shadow_caster: SHADOW_GRID.caster_create(node.renderer.x, node.renderer.y)
            });
            shadow_caster_set_sprite(node.renderer.linked_object.shadow_caster, SHADOW_DICTIONARY.get(node.prototype.animal_toy.extra_renderer.inactive));
        }
    }

    if node.prototype.is_journal {
        node.renderer.interact("misc_local/input_interact");
        setup_box_interaction = true;
    }

    if node.prototype.is_crystal_resonator {
        node.renderer.interact("misc_local/use");
        setup_box_interaction = true;
    }

    if node.object_id == ObjectId.Mailbox {
        node.renderer.interact("misc_local/read_mail");
        setup_box_interaction = true;
    }

    if node.object_id == ObjectId.BabyCradle {
        node.renderer.highlight_interactable = true;
        register_interactable(node.renderer);
        node.renderer.register_interaction(
            InputId.Interact,
            "misc_local/place_child",
            method(node.renderer, function() {
                return interact(self.node);
            }),
            method(node.renderer, function() {
                return ARI.held_child() != undefined;
            }),
        );
        node.renderer.register_interaction(
            InputId.Interact,
            "misc_local/hold_child",
            method(node.renderer, function() {
                return interact(self.node);
            }),
            method(node.renderer, function() {
                //
                //
                //
                if ARI.held_child() != undefined {
                    return false;
                }

                for (var i = 0; i < array_length(ARI.children); i++) {
                    if ARI.children[i].location == ChildLocation.InCradle {
                        return true;
                    }
                }

                return false;
            }),
        );
        setup_box_interaction = true;
    }

    if node.prototype.forecaster != undefined {
        node.renderer.interact("misc_local/crystal_ball");
        node.renderer.sprite_index = node.prototype.forecaster[CALENDAR.season()][weather_tomorrow()];
        setup_box_interaction = true;
    }

    if node.object_id == ObjectId.BigBell {
        node.renderer.interact("misc_local/bell_out");
        node.renderer.rings = 0;
        node.renderer.give_animation_end_callback(function() {
            if self.sprite_index == self.node.prototype.ring_sprite {
                self.rings += 1;
                if self.rings == self.node.prototype.ring_count {
                    self.rings = 0;
                    self.image_index = 0;
                    self.sprite_index = self.node.prototype.cardinal_data[self.node.cardinal_index].sprite;
                }
            }
        });
        setup_box_interaction = true;
    }

    if matches(
        node.object_id,
        ObjectId.StableCraftingTable,
        ObjectId.EspressoMachine,
        ObjectId.WaterSealDoor,
        ObjectId.EarthSealDoor,
        ObjectId.FireSealDoor,
        ObjectId.RuinsSealDoor,
    ) {
        node.renderer.interact("misc_local/input_interact", interact_mask);
    }

    if node.object_id == ObjectId.TesseraeTree {
        node.renderer.interact("misc_local/shake");
        node.renderer.top_sheet_renderer.sprite_index = node.day_count >= 3
            ? spr_object_tesserae_tree_main_stage2
            : spr_object_tesserae_tree_main_stage1;
        node.renderer.set_sprite(spr_object_tesserae_tree_stump_stage1);
    }

    if node.prototype.interact_menu != undefined {
        node.renderer.interact("misc_local/input_interact", interact_mask);
    }

    if node.object_id == ObjectId.FarmHouseCalendar {
        node.renderer.interact("misc_local/use");
        setup_box_interaction = true;
    }

    //
    if node.prototype.house_stairs != undefined {
        node.renderer.interact("misc_local/input_interact", interact_mask);
        if interact_mask == undefined {
            setup_box_interaction = true;
        }
    }

    if node.prototype.is_date_photo {
        node.renderer.interact("misc_local/view_photo", node.prototype[$ "interact_mask"]);
        setup_box_interaction = true;
    }

    if setup_box_interaction {
        node.renderer.interactable_mode = InteractableMode.Box;
        node.renderer.interaction_half_size = node.prototype.size.scale(4);

        node.renderer.interaction_center = Vec2(
            node.top_left_x * 8 + renderer_position.x_offset + node.renderer.interaction_half_size.x,
            node.top_left_y * 8 + renderer_position.last_y_offset + node.renderer.interaction_half_size.y,
        );
    }

    if mirror_these_sprites {
        node.renderer.image_xscale = -1;
    }

    if node.prototype.depth_to_floor {
        node.renderer.depth = get_floor_depth();
        if !node.prototype.rug {
            node.renderer.depth -= 1;
        }
    }

    if node.child_grid != undefined {
        node.renderer.shadow_level = instance_create_depth(node.renderer.x, node.renderer.y, node.renderer.depth, obj_shadow_level, {
            shadow_maps: undefined,
            render_outlines: false,
            target_shadow_grid: new ShadowGrid(true),
        });
        if DEBUG_TOOLS {
            node.renderer.shadow_level.name = format("{ObjectId}_shadows", node.object_id);
        }
        node.renderer.shadow_level.shadow_area = [
            node.renderer.sprite_index,
            node.renderer.image_index,
            node.renderer.x,
            node.renderer.y,
            1,
            1,
        ];
        node.child_grid.initialize_on_room_start();
    }
}

function replace_interaction_local(renderer, target, replacement) {
    for (var i = 0; i < renderer.interactions.count(); i++) {
        var interaction = renderer.interactions.get(i);
        if interaction.local_key == target {
            interaction.local_key = replacement;
        }
    }
}

//
//
function create_test_placement_furniture_draw_info(xx, yy, object_id, rotation, furniture_renderer) {
    var proto = NODE_PROTOTYPES[object_id];
    assert_eq(proto.category_id, ObjectCategory.Furniture);

    //
    if proto.house_stairs != undefined
        && array_contains(proto.placeable_locations, CURRENT_LOCATION_ID) == false
    {
        object_id = proto.house_stairs.paired_object;
        proto = NODE_PROTOTYPES[object_id];
    }

    if array_length(proto.cardinals) == 0 {
        return undefined;
    }

    var output = {
        cursor_data: List(),
        splotch_data: List(),
        is_valid: false,

        x_off: 0,
        y_off: 0,
    };

    //
    var calc_rot = furniture_rotation_amount(rotation, proto);
    var delta_rot = proto.cardinal_data[calc_rot].cardinal_offset;
    var rotation_matrix = cardinal_to_mat2(delta_rot);
    var rot_data = furniture_mask_prep_vecdata(proto.size, rotation_matrix);

    //
    center_offset_furniture(object_id, rotation, rot_data);
    xx += rot_data.offset.x;
    yy += rot_data.offset.y;

    //
    var spr = proto.cardinal_data[calc_rot].sprite;
    var seasonal_override = proto.cardinal_data[calc_rot][format("{Season}_sprite", CALENDAR.season())];
    if seasonal_override != undefined {
        spr = seasonal_override;
    }
    furniture_renderer.sprite_index = spr;

    //
    if proto.fence
        && GRID.try_node_index_for_cell(xx, yy) != undefined
        && GRID.node_object_id[GRID.node_index_for_cell(xx, yy)] == undefined
    {
        furniture_renderer.image_index = inner_fence_auto_tile(GRID, xx, yy, proto.object_id, undefined);

        try_update_existing_fence_preview(xx - 2, yy, proto.object_id, undefined, undefined, undefined, undefined, true);
        try_update_existing_fence_preview(xx + 2, yy, proto.object_id, undefined, undefined, true, undefined, undefined);
        try_update_existing_fence_preview(xx, yy - 2, proto.object_id, undefined, undefined, undefined, true, undefined);
        try_update_existing_fence_preview(xx, yy + 2, proto.object_id, undefined, true, undefined, undefined, undefined);
    } else {
        furniture_renderer.image_index = 0;
    }

    furniture_renderer.x = xx * 8 + proto.cardinal_data[calc_rot].offset.x;
    furniture_renderer.y = yy * 8 + proto.cardinal_data[calc_rot].offset.y;
    furniture_renderer.image_xscale = proto.cardinal_data[calc_rot].flipper;
    furniture_renderer.on_floor = proto.depth_to_floor;

    //
    var g = GRID;
    var g_xx = xx;
    var g_yy = yy;

    var z_off = 0;
    var x_off_sub = 0;
    var y_off_sub = 0;

    var stack_count = -1;
    //
    //
    while proto.rug == false {
        var table_top = undefined;
        stack_count += 1;
        //
        for (var i = 0; i < proto.size.x; i++) {
            if table_top != undefined {
                break;
            }
            for (var j = 0; j < proto.size.y; j++) {
                rot_data.offset.set_val(i - rot_data.center.x, j - rot_data.center.y);
                rot_data.offset.set_rotate(rotation_matrix);

                var posx = g_xx + abs(rot_data.transform.x) + rot_data.offset.x;
                var posy = g_yy + abs(rot_data.transform.y) + rot_data.offset.y;

                table_top = g.try_node_index_for_cell(posx, posy);
                if table_top != undefined
                    && object_id_to_object_category(g.node_object_id[table_top]) == ObjectCategory.Furniture
                    && g.node_parent[table_top].child_grid != undefined
                {
                    //
                    break;
                } else {
                    table_top = undefined;
                }
            }
        }

        if table_top != undefined {
            var cardinal_data = g.node_parent[table_top].prototype.cardinal_data[g.node_parent[table_top].cardinal_index];
            x_off_sub += cardinal_data.child_grid_offset.x;
            y_off_sub += cardinal_data.child_grid_offset.y;
            z_off -= -cardinal_data.child_grid_offset.y + g.node_parent[table_top].prototype.depth_offset + cardinal_data.offset.y + 1;

            g_xx -= g.node_top_left_x[table_top];
            g_yy -= g.node_top_left_y[table_top];
            g = g.node_parent[table_top].child_grid;
        } else {
            break;
        }
    }

    output.is_valid = furniture_test_flag_mask(rot_data, g, g_xx, g_yy, proto, rotation_matrix, false, false)
        && array_contains(proto.placeable_locations, CURRENT_LOCATION_ID)
        && stack_count < 3
        && (object_id != ObjectId.AutoFeeder || (g.parent_node != undefined && g.parent_node.object_id == ObjectId.AutoFeederPlatform))
        && (object_id != ObjectId.OcarinaSpriteStatue || (g.parent_node != undefined && g.parent_node.object_id == ObjectId.OcarinaSpriteStatueBase));

    furniture_renderer.z = z_off;
    if array_length(proto.cardinals) > 1 {
        output.render_arrow = calc_rot;
    } else {
        output.render_arrow = undefined;
    }

    if proto.can_be_child {
        furniture_renderer.x += x_off_sub;
        furniture_renderer.y += y_off_sub;

        output.x_off = x_off_sub;
        output.y_off = y_off_sub;
    }

    furniture_renderer.is_success = output.is_valid;

    if proto.cardinal_data[calc_rot].top_sprite != undefined {
        furniture_renderer.top_sprite = proto.cardinal_data[calc_rot].top_sprite;
    }
    if proto.cardinal_data[calc_rot].floor_sprite != undefined {
        furniture_renderer.bottom_sprite = proto.cardinal_data[calc_rot].floor_sprite;
    }
    if proto.cardinal_data[calc_rot].secondary_sprite != undefined {
        furniture_renderer.secondary_sprite = proto.cardinal_data[calc_rot].secondary_sprite;
    }

    //
    for (var i = 0; i < proto.size.x; i++) {
        for (var j = 0; j < proto.size.y; j++) {
            rot_data.offset.set_val(i - rot_data.center.x, j - rot_data.center.y);
            rot_data.offset.set_rotate(rotation_matrix);

            var posx = xx + abs(rot_data.transform.x) + rot_data.offset.x;
            var posy = yy + abs(rot_data.transform.y) + rot_data.offset.y;

            output.splotch_data.push(Vec2(posx * 8, posy * 8));
        }
    }

    //
    draw_test_placement_furniture_bounds(xx, yy, rot_data, delta_rot, rotation_matrix, proto, output);

    return output;
}

function draw_test_placement_furniture_bounds(xx, yy, rot_data, delta_rot, rotation_matrix, proto, output) {
    var nx = xx + abs(rot_data.transform.x);
    var ny = yy + abs(rot_data.transform.y);

    var low_target = Vec2(-abs(rot_data.transform.x), -abs(rot_data.transform.y));
    var high_target = Vec2(abs(rot_data.transform.x), abs(rot_data.transform.y));
    var low_iter_start_x = 0;
    var low_iter_start_y = 0;
    var high_iter_add_x = 0;
    var high_iter_add_y = 0;

    var x_odd = (proto.size.x % 2) == 1;
    var y_odd = (proto.size.y % 2) == 1;

    switch delta_rot {
        case 0:
            high_target.x += x_odd;
            high_target.y += y_odd;

            high_iter_add_x = 1;
            high_iter_add_y = 1;
            break;
        case 1:
            high_target.x += y_odd;
            high_target.y += 2 - x_odd;

            high_iter_add_y = 1;
            low_iter_start_x = -1;
            break;
        case 2:
            high_target.x += 2 - x_odd;
            high_target.y += 2 - y_odd;

            low_iter_start_x = -1;
            low_iter_start_y = -1;
            break;
        case 3:
            high_target.x += 2 - y_odd;
            high_target.y += x_odd;

            low_iter_start_y -= 1;

            high_iter_add_x = 1;
            break;
        break;
    }

    var min_x = infinity;
    var min_y = infinity;
    var max_x = 0;
    var max_y = 0;

    for (var i = low_iter_start_x; i < (proto.size.x + high_iter_add_x); i++) {
        for (var j = low_iter_start_y; j < (proto.size.y + high_iter_add_y); j++) {
            rot_data.offset.set_val(i - rot_data.center.x, j - rot_data.center.y);
            rot_data.offset.set_rotate(rotation_matrix);

            var posx = nx + rot_data.offset.x;
            var posy = ny + rot_data.offset.y;

            //
            var tile_x = QuickAlign.Middle;
            var tile_y = QuickAlign.Middle;

            if rot_data.offset.x == low_target.x {
                tile_x = QuickAlign.Low;
            } else if rot_data.offset.x == high_target.x {
                tile_x = QuickAlign.High;
            }

            if rot_data.offset.y == low_target.y {
                tile_y = QuickAlign.Low;
            } else if rot_data.offset.y == high_target.y {
                tile_y = QuickAlign.High;
            }
            //
            var part_x = 12 + tile_x * 8;
            var part_y = 12 + tile_y * 8;

            //
            if tile_x == QuickAlign.Middle && tile_y == QuickAlign.Middle {
                continue;
            }

            min_x = min(min_x, posx * 8 - 4);
            min_y = min(min_y, posy * 8 - 4);
            max_x = max(max_x, posx * 8 - 4);
            max_y = max(max_y, posy * 8 - 4);

            output.cursor_data.push({
                part_x: part_x,
                part_y: part_y,
                pos_x: posx * 8 - 4,
                pos_y: posy * 8 - 4,
            });
        }
    }

    output.top_left_x = min_x;
    output.top_left_y = min_y;

    output.bot_right_x = max_x;
    output.bot_right_y = max_y;
}

//
function draw_test_placement_furniture_splotches(is_valid, splotch_data, x_off, y_off) {
    //
    var c;
    if is_valid {
        gpu_set_blendmode_ext(bm_src_alpha, bm_one);
        c = make_color_rgb(2, 43, 0);
    } else {
        gpu_set_blendmode_ext(bm_dest_color, bm_zero);
        c = make_color_rgb(255, 155, 123);
    }

    for (var i = 0; i < splotch_data.count(); i++) {
        var splot_pos = splotch_data.get(i);
        draw_sprite_ext(spr_pixel, 0, splot_pos.x + x_off, splot_pos.y + y_off, 8, 8, 0, c, 1.0);
    }
    gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);
}

//
function draw_test_placement_furniture_lines(is_valid, cursor_data, x_off, y_off, alpha) {
    //
    var tile_spr_to_draw = tile_cursor_sprite_bundle().furniture[is_valid];
    for (var i = 0; i < cursor_data.count(); i++) {
        var this_data = cursor_data.get(i);
        draw_sprite_part(tile_spr_to_draw, 0, this_data.part_x, this_data.part_y, 8, 8, this_data.pos_x + x_off, this_data.pos_y + y_off, c_white, alpha);
    }
}

//
//
function furniture_object_cardinal_to_rotation(furniture_object_id, cardinal_direction) {
    var proto = NODE_PROTOTYPES[furniture_object_id];
    var cardinal_count = array_length(proto.cardinals);
    var rot = undefined;
    for (var i = 0; i < cardinal_count; i ++) {
        if proto.cardinals[i] == cardinal_direction {
            rot = i;
            break;
        }
    }
    return rot;
}

//
//
//
function bed_sleep_offset(object_id, for_spouse=false) {
    var prototype = NODE_PROTOTYPES[object_id];

    //
    var height = 0;
    for (var i = 0; i < ds_grid_height(prototype.collision_grid); i++) {
        if prototype.collision_grid[# 0, i] == 0 {
            height = i;
            break;
        }
    }

    var target_x = (ds_grid_width(prototype.collision_grid) * 8) / 2;

    if ARI.has_spouse() {
        var offset = prototype.bed_kind == BedKind.Double ? 10 : 6;
        target_x += offset * (for_spouse ? 1 : -1);
    }

    return Vec2(target_x, height * 8 + 4);
}

function furniture_mask_prep_vecdata(size, rotmat) {
    //
    //
    var center_vec = Vec2(size.x div 2, size.y div 2);
    var odd_vec = Vec2((size.x - 1) div 2, (size.y - 1) div 2);
    //
    var transform_vec = center_vec.clone();
    //
    transform_vec.set_rotate(rotmat);
    odd_vec.set_rotate(rotmat);

    //
    transform_vec.set_val(max(transform_vec.x, odd_vec.x), max(transform_vec.y, odd_vec.y));

    //
    return {
        transform: transform_vec,
        odd: odd_vec,
        center: center_vec,
        offset: Vec2()
    }
}

//
function center_offset_furniture(object_id, rotation, rot_data=undefined) {
    var proto = NODE_PROTOTYPES[object_id];
    assert_eq(proto.category_id, ObjectCategory.Furniture);

    if array_length(proto.cardinals) == 0 {
        return Vec2Zero();
    }

    //
    var calc_rot = furniture_rotation_amount(rotation, proto);
    var rotation_matrix = furniture_calc_rot_to_rotation_matrix(calc_rot, proto);

    if rot_data == undefined {
        rot_data = furniture_mask_prep_vecdata(proto.size, rotation_matrix);
    }

    //
    rot_data.offset.set_val(-rot_data.center.x, -rot_data.center.y);
    rot_data.offset.set_rotate(rotation_matrix);

    rot_data.offset.x = -abs(rot_data.offset.x);
    rot_data.offset.y = -abs(rot_data.offset.y);

    return rot_data.offset;
}

function furniture_test_flag_mask(rot_data, grid, xx, yy, proto, rotmat, ignore_object=false, ignore_ari=false) {
    if grid.parent_node != undefined && !proto.can_be_child {
        return false;
    }

    var nx = xx + abs(rot_data.transform.x);
    var ny = yy + abs(rot_data.transform.y);

    if proto.rug == false && ignore_ari == false {
        rot_data.offset.x = proto.size.x;
        rot_data.offset.y = proto.size.y;
        rot_data.offset.set_rotate(rotmat);
        rot_data.offset.x = abs(rot_data.offset.x);
        rot_data.offset.y = abs(rot_data.offset.y);

        if collision_rectangle(
            xx * 8,
            yy * 8,
            (xx + rot_data.offset.x) * 8,
            (yy + rot_data.offset.y) * 8,
            [obj_ari, obj_player_animal, obj_pet],
        ) != undefined {
            return false;
        }
    }

    for (var i = 0; i < proto.size.x; i++) {
        for (var j = 0; j < proto.size.y; j++) {
            var rule_flag = proto.rule_grid[# i, j];
            var terrain_desired = proto.input_terrain == undefined ? TerrainKind.Ground : proto.input_terrain[# i, j];
            rot_data.offset.set_val(i - rot_data.center.x, j - rot_data.center.y);
            rot_data.offset.set_rotate(rotmat);
            var posx = nx + rot_data.offset.x;
            var posy = ny + rot_data.offset.y;
            var ni = grid.try_node_index_for_cell(posx, posy);

            if ni == undefined {
                return false;
            }

            var success = true;
            //
            if array_contains(proto.placeable_locations, grid.location_id) {
                success = grid.tile_flag_satisfies_node(ni, rule_flag);
            }

            success &= ignore_object || can_write_object_on_node(grid, ni, terrain_desired, true, !proto.rug, proto.rug);

            if success == false {
                return false;
            }
        }
    }

    return true;
}

//
//
function furniture_rotation_amount(rotation, proto) {
    var calc_index = wrap(rotation, array_length(proto.cardinals));
    return proto.cardinals[calc_index];
}

//
function furniture_calc_rot_to_rotation_matrix(calc_rot, proto) {
    var delta_rot = proto.cardinal_data[calc_rot].cardinal_offset;
    return cardinal_to_mat2(delta_rot);
}

function furniture_size(rotation_matrix, proto) {
    var region = proto.size.clone();
    region.set_rotate(rotation_matrix);
    region.x = abs(region.x);
    region.y = abs(region.y);

    return region;
}

//
//
//
function position_for_furniture_renderer(node) {
    var cardinal_data = node.prototype.cardinal_data[node.cardinal_index];
    var x_offset = 0;
    var y_offset = 0;

    //
    //
    //
    //
    //
    //
    //
    //
    //
    var last_x_offset = 0;
    var last_y_offset = 0;

    var parent_node = node.parent_grid.parent_node;
    while parent_node != undefined {
        var parent_cardinal_data = parent_node.prototype.cardinal_data[parent_node.cardinal_index];

        last_x_offset = parent_node.top_left_x * 8;
        last_y_offset = parent_node.top_left_y * 8;

        x_offset += last_x_offset + parent_cardinal_data.child_grid_offset.x;
        y_offset += last_y_offset + parent_cardinal_data.child_grid_offset.y;

        parent_node = parent_node.parent_grid.parent_node;
    }

    return {
        x: (node.top_left_x * 8) + cardinal_data.offset.x + x_offset,
        y: (node.top_left_y * 8) + cardinal_data.offset.y + y_offset,
        last_x_offset,
        last_y_offset,
        x_offset,
        y_offset
    };
}

function furniture_arrow_offset(direction, min_x, min_y, max_x, max_y) {
    var render_point_x = 0;
    var render_point_y = 0;

    var spr = undefined;
    var mid_x = 0.5 * (max_x + min_x);
    var mid_y = 0.5 * (max_y + min_y);

    switch direction {
        case Cardinal.East:
            spr = spr_cursor_furniture_direction_indicator_indicator_east;
            render_point_x = max_x + 6;
            render_point_y = mid_y + 2;
            break;
        case Cardinal.West:
            spr = spr_cursor_furniture_direction_indicator_indicator_west;
            render_point_x = min_x + 2;
            render_point_y = mid_y + 3;
            break;
        case Cardinal.North:
            spr = spr_cursor_furniture_direction_indicator_indicator_north;
            render_point_x = mid_x + 4;
            render_point_y = min_y + 2;
            break;
        case Cardinal.South:
            spr = spr_cursor_furniture_direction_indicator_indicator_south;
            render_point_x = mid_x + 4;
            render_point_y = max_y + 6;
            break;
    }

    return [spr, render_point_x, render_point_y];
}

//
function activity_position_for_node(node, dir, activity_index) {
    var positions = node.prototype.activities[activity_index].positions;
    var pos = position_for_furniture_renderer(node);
    var off = positions[irandom(array_length(positions) - 1)];
    return off[dir].add(pos);
}

//
enum QuickAlign {
    Low,
    Middle,
    High,
}

enum BedKind {
    Single,
    Double,
    LEN,
}

function furniture_chest_add_items(items_list, chest) {
    TANGO.play("SoundEffects/Inventory/ItemPickup");
    TANGO.play(chest.prototype.interaction_chest.close_sfx, chest.renderer.x, chest.renderer.y);
    chest.renderer.sprite_index = chest.prototype.interaction_chest.bounce_sprite;

    for (var i = 0; i < items_list.count(); i++) {
        var item = items_list.get(i);
        if chest.inventory.add(item) > 0 {
            if ARI.inventory.can_add(item) {
                ARI.inventory.add(item);
            } else {
                drop_item(item, obj_ari.x, obj_ari.y);
            }
        }
    }
}

function auto_tile_fence(grid, xx, yy) {
    var ni = grid.try_node_index_for_cell(xx, yy);
    if ni == undefined
        || grid.node_object_id[ni] == undefined
        || object_id_to_object_category(grid.node_object_id[ni]) != ObjectCategory.Furniture
        || grid.node_parent[ni].prototype.fence == false
    {
        return;
    }

    var new_index = inner_fence_auto_tile(grid, grid.node_top_left_x[ni], grid.node_top_left_y[ni], grid.node_object_id[ni], grid.node_parent[ni][$ "blueprint_fingerprint"]);
    grid.node_parent[ni].fence_image_index = new_index;

    if grid.node_parent[ni].renderer != undefined
        && instance_exists(grid.node_parent[ni].renderer)
    {
        grid.node_parent[ni].renderer.image_index = new_index;
        if grid.node_parent[ni].parent_grid.parent_node == undefined
            && grid.node_parent[ni].renderer.shadow_caster != undefined
        {
            shadow_caster_set_image(grid.node_parent[ni].renderer.shadow_caster, new_index);
        }
    }
}

function inner_fence_auto_tile(grid, xx, yy, key_id, blueprint_fingerprint, north_override, west_override, south_override, east_override) {
    var location_has_me_there = function(grid, xx, yy, key_id, blueprint_fingerprint) {
        var oi = grid.try_node_index_for_cell(xx, yy);
        return oi != undefined
            && grid.node_object_id[oi] == key_id
            && grid.node_parent[oi].top_left_x == xx
            && grid.node_parent[oi].top_left_y == yy
            && grid.node_parent[oi][$ "blueprint_fingerprint"] == blueprint_fingerprint;
    }

    var north = north_override ?? location_has_me_there(grid, xx, yy - 2, key_id, blueprint_fingerprint);
    var west = west_override ?? location_has_me_there(grid, xx - 2, yy, key_id, blueprint_fingerprint);
    var south = south_override ?? location_has_me_there(grid, xx, yy + 2, key_id, blueprint_fingerprint);
    var east = east_override ?? location_has_me_there(grid, xx + 2, yy, key_id, blueprint_fingerprint);

    //
    return (1 * north) + (2 * west) + (4 * east) + (8 * south);
}

function try_update_existing_fence_preview(xx, yy, object_id, blueprint_fingerprint, north_override, west_override, south_override, east_override) {
    //
    var neighbor = GRID.try_node_index_for_cell(xx, yy);
    if neighbor != undefined
        && GRID.node_object_id[neighbor] == object_id
        && GRID.node_parent[neighbor].prototype.fence
    {
        GRID.node_parent[neighbor].renderer.preview_fence_idx = inner_fence_auto_tile(GRID, xx, yy, object_id, blueprint_fingerprint, north_override, west_override, south_override, east_override);
    }
}

function furniture_write_old_terrain(grid, _x, _y, size_x, size_y, old_terrain) {
    for (var i = 0; i < size_x * size_y; i++) {
        var old_terrain_collection = old_terrain[i];

        if old_terrain_collection == undefined {
            continue;
        }

        var posx = _x + i % size_x;
        var posy = _y + i div size_x;

        var ni = grid.node_index_for_cell(posx, posy);

        grid.node_terrain_kind[ni] = old_terrain_collection[0];
        grid.node_terrain_ground_kind[ni] = old_terrain_collection[1];
        grid.node_terrain_is_watered[ni] = old_terrain_collection[2];
        grid.node_terrain_variant[ni] = old_terrain_collection[3];
        grid.node_terrain_tile[ni] = old_terrain_collection[4];

        if grid.water_tilemap_id != undefined {
            if grid.node_terrain_kind[ni] == TerrainKind.Ground {
                grid.auto_tile_tile(posx, posy, true);
            } else {
                tilemap_update(grid.water_tilemap_id, 0, posx div 2, posy div 2);
                tilemap_update(grid.soil_tilemap_id, 0, posx div 2, posy div 2);
                tilemap_update(grid.grass_variant_tilemap_id, 0, posx div 2, posy div 2);
                tilemap_update(grid.grass_autotile_tilemap_id, 0, posx div 2, posy div 2);
            }
        }

    }
}

function furniture_write_new_terrain(grid, ni, new_terrain_kind) {
    var old = [
        grid.node_terrain_kind[ni],
        grid.node_terrain_ground_kind[ni],
        grid.node_terrain_is_watered[ni],
        grid.node_terrain_variant[ni],
        grid.node_terrain_tile[ni],
    ];
    grid.node_terrain_kind[ni] = new_terrain_kind;
    if new_terrain_kind == TerrainKind.Ground {
        grid.node_terrain_ground_kind[ni] = GroundKind.Grass;
    }
    grid.node_terrain_is_watered[ni] = false;
    grid.node_terrain_variant[ni] = undefined;
    grid.node_terrain_tile[ni] = undefined;

    return old;
}

function sprinkler_exit_room() {
    //
    //
    //
    //
    //
    //
    if ARI.end_of_day_sequence == false && LEAVING_EOD == false {
        for (var i = 0; i < array_length(GRID.sprinklers); i++) {
            var sprinkler = GRID.sprinklers[i];

            if sprinkler.essence_supply > 0 {
                var range = sprinkler.prototype.sprinkler * 2;
                for (var xx = -range; xx <= range; xx++) {
                    for (var yy = -range; yy <= range; yy++) {
                        var ni = GRID.node_index_for_cell(sprinkler.top_left_x + xx, sprinkler.top_left_y + yy);
                        GRID.node_terrain_is_watered[ni] = true;
                    }
                }
            }
        }
    }
}

//
//
//
//
//
function animals_using_toy(node) {
    var count = 0;

    //
    with obj_player_animal {
        if self.fsm.current_state_id() == AnimalState.UsingToy
            && self.fsm.current_state().toy == node
        {
            count += 1;
        }
    }

    //
    with obj_pet {
        if self.fsm.current_state_id() == PetState.UsingToy
            && self.fsm.current_state().toy == node
        {
            count += 1;
        }
    }

    return count;
}
