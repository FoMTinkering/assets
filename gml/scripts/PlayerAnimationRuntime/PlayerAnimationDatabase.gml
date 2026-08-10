#macro PLAYER_ANIMATION_DATABASE global.__pad
PLAYER_ANIMATION_DATABASE = undefined;

function PlayerAnimationDatabase() constructor {
    self.player_animations = array_create(AnimationSlot.LEN, undefined);
    self.player_assets = Map();

    function load() {
        //
        var loader = read_json_file("animation/par_output.json");

        for (var animation_slot = 0; animation_slot < AnimationSlot.LEN; animation_slot++) {
            var bone = loader[$ animation_slot_to_string(animation_slot)];

            var animations = array_create(AnimationName.LEN, undefined);
            for (var animation_name = 0; animation_name < AnimationName.LEN; animation_name++) {
                var animation = bone[$ animation_name_to_string(animation_name)];

                var data = array_create(Cardinal.LEN, undefined);

                if animation != undefined {
                    for (var i = 0; i < Cardinal.LEN; i++) {
                        if i == Cardinal.West {
                            continue;
                        }

                        var frame_data = animation[$ cardinal_to_string(i)];
                        if frame_data != undefined {
                            for (var j = 0, c = array_length(frame_data); j < c; j++) {
                                var anim = frame_data[j];
                                anim.offset = fiddle_deserialize_vec2(anim.offset);
                                anim.broadcast_message = anim[$ "broadcast_message"] ?? BroadcastMessage.EMPTY;
                            }
                        }

                        data[i] = frame_data;
                    }
                }
                data[Cardinal.West] = data[Cardinal.East];

                animations[animation_name] = data;
            }

            player_animations[animation_slot] = animations;
        }
        self.player_animations = player_animations;

        self.modifiers = array_create(AnimationName.LEN, undefined);

        for (var i = 0; i < AnimationName.LEN; i++) {
            var maybe_modifier = loader.modifiers[$ animation_name_to_string(i)];
            if maybe_modifier != undefined {
                apply_func(maybe_modifier.slots, function(value) {
                    if is_string(value) {
                        return {
                            controls_depth: false,
                            use_sprite_data: true,
                            slot: string_to_animation_slot(value),
                        }
                    } else {
                        return {
                            controls_depth: value.controls_depth,
                            use_sprite_data: value.use_sprite_data,
                            slot: string_to_animation_slot(value.slot),
                        }
                    }
                });
                maybe_modifier.on_end = opt_and_then(maybe_modifier[$ "on_end"], string_to_player_animation_end_behavior) ?? PlayerAnimationEndBehavior.Normal;
            }

            self.modifiers[i] = maybe_modifier;
        }

        //
        self.player_asset_parts = read_json_file("animation/player_asset_parts.json");
        foreach_field(self.player_asset_parts, function(item) {
            var output = array_create(AnimationSlot.LEN, undefined);
            for (var i = 0; i < AnimationSlot.LEN; i++) {
                if DEBUG_ASSERTIONS {
                    output[i] = opt_and_then(item[$ animation_slot_to_string(i)], string_to_asset);
                } else {
                    output[i] = opt_and_then(item[$ animation_slot_to_string(i)], try_string_to_asset);
                }
            }

            return output;
        });

        var fiddle_player_assets = fiddle_get("player_assets");
        var names = struct_get_names(fiddle_player_assets);
        for (var i = 0, c = array_length(names); i < c; i++) {
            var player_asset_name = names[i];
            var fiddle_asset = fiddle_player_assets[$ player_asset_name];

            var ui_asset_icon;
            if fiddle_asset[$ "ui_asset_icon"] == undefined {
                var single_layer_name = fmt("spr_ui_item_wearable_{}", player_asset_name);
                var double_layer_name = fmt("spr_ui_item_wearable_{}_asset", player_asset_name);
                ui_asset_icon = try_string_to_asset(single_layer_name);
                ui_asset_icon = ui_asset_icon == undefined ? try_string_to_asset(double_layer_name) : ui_asset_icon;
                ui_asset_icon = ui_asset_icon == undefined ? spr_nothing : ui_asset_icon;
            } else {
                ui_asset_icon = string_to_asset(fiddle_asset.ui_asset_icon);
            }
            if ui_asset_icon == -1 {
                ui_asset_icon = spr_illegal_16;
            }

            var ui_merged_icon = try_string_to_asset(format("spr_ui_item_wearable_{}_merged", player_asset_name));

            var ui_body_icon = spr_nothing;
            if fiddle_asset[$ "ui_body_icon"] == undefined {
                ui_body_icon_name = fmt("spr_ui_item_wearable_{}_body", player_asset_name);
                ui_body_icon = try_string_to_asset(ui_body_icon_name) ?? spr_nothing;
            }

            var output_asset_data = {
                name: fiddle_asset.name,
                slots: array_create(AnimationSlot.LEN, undefined),
                ui_slot: string_to_par_ui_slot(fiddle_asset.ui_slot),
                ui_sub_category: fiddle_asset["ui_sub_category"],
                ui_asset_icon: ui_asset_icon,
                ui_body_icon: ui_body_icon,
                ui_merged_icon: ui_merged_icon,
                lut_sprite: opt_and_then(fiddle_asset[$ "lut"], string_to_asset),
                default_unlocked: fiddle_asset[$ "default_unlocked"] ?? false,
                hide_hair: fiddle_asset[$ "hide_hair"] ?? false,
                price_override: fiddle_asset[$ "price_override"],
            };

            //
            var asset_parts_bundle = self.player_asset_parts[$ player_asset_name];
            if asset_parts_bundle != undefined {
                for (var slot = 0; slot < AnimationSlot.LEN; slot++) {
                    if asset_parts_bundle[slot] != undefined {
                        output_asset_data.slots[slot] = asset_parts_bundle[slot];
                    }
                }
            }

            //
            for (var slot = 0; slot < AnimationSlot.LEN; slot++) {
                var outfit_ptr = fiddle_asset[$ animation_slot_to_string(slot)];
                if outfit_ptr != undefined {
                    //
                    var outfit = self.player_asset_parts[$ outfit_ptr];

                    assert_neq(outfit, undefined, "outfit {} does not exist, yet is used in asset {}", outfit_ptr, player_asset_name);

                    var outfit_sprite = outfit[slot];

                    assert_neq(outfit_sprite, undefined, "outfit {} exists, but doesn't have {AnimationSlot}, which it is supposed to in asset {}", outfit_ptr, slot, player_asset_name);

                    output_asset_data.slots[slot] = outfit_sprite;
                }
            }

            self.player_assets.set(player_asset_name, output_asset_data);
        }

        //
        var player_tools_struct = read_json_file("animation/player_tools.json");
        apply_func(player_tools_struct, function(map) {
            var output = array_create(AnimationName.LEN, undefined);

            for (var anim_name = 0; anim_name < AnimationName.LEN; anim_name++) {
                var value = map[$ animation_name_to_string(anim_name)];
                if value != undefined {
                    var slot_map = array_create(Attachment.LEN, undefined);

                    for (var i = 0; i < Attachment.LEN; i++) {
                        var slot_value = value[$ attachment_to_string(i)];

                        if slot_value != undefined {
                            var cardinal_map = array_create(Cardinal.LEN, undefined);
                            for (var c = 0; c < Cardinal.LEN; c++) {
                                if c == Cardinal.West {
                                    continue;
                                }
                                cardinal_map[c] = opt_and_then(
                                    slot_value[$ cardinal_to_string(c)],
                                    try_string_to_asset,
                                );
                            }
                            cardinal_map[Cardinal.West] = cardinal_map[Cardinal.East];
                            slot_map[i] = cardinal_map;
                        }
                    }

                    output[anim_name] = slot_map;
                }
            }

            return output;
        });

        player_attachments = MapWrap(player_tools_struct);
    }

    function animation(slot, animation, cardinal) {
        return self.player_animations[slot][animation][cardinal];
    }

    function asset(asset_name, slot) {
        return self.player_assets.get(asset_name).slots[slot];
    }

    self.load();
}

function validate_cosmetic(cosmetic) {
    assert(
        PLAYER_ANIMATION_DATABASE.player_assets.contains_key(cosmetic),
        "Cosmetic '{}' does not exist!",
        cosmetic,
    );

    return cosmetic;
}

function default_cosmetic_unlocks() {
    var output = HashSet();
    var keys = PLAYER_ANIMATION_DATABASE.player_assets.keys();
    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];
        if PLAYER_ANIMATION_DATABASE.player_assets.get(key).default_unlocked {
            output.insert(key);
        }
    }
    return output;
}
