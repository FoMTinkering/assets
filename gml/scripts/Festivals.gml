#macro FESTIVALS global.__festivals
FESTIVALS = undefined;

//
#macro CANCEL_FESTIVALS global.__cancel_festivals
CANCEL_FESTIVALS = false;

function load_festivals() {
    var f = fiddle_get("festivals");
    var keys = struct_get_names(f);
    var output = array_create(FestivalId.LEN, undefined);
    for (var i = 0; i < FestivalId.LEN; i++) {
        var key = festival_id_to_string(i);
        var proto = clone_value(f[$ "default"]);
        patch_object(f[$ key], proto);
        filter_toml_nulls(proto);
        proto.type = undefined;
        proto.date.season = string_to_season(proto.date.season);
        proto.icon = string_to_asset(proto.icon);
        proto.forced_weather = string_to_weather(proto.forced_weather);
        proto.location = string_to_location_id(proto.location);
        proto.challenges = opt_and_then(proto[$ "challenges"], function(challenges) {
            for (var i = 0; i < array_length(challenges); i++) {
                var proto = challenges[i];
                //
                //

                for (var j = 0; j < array_length(proto.tier_results); j++) {
                    var result = proto.tier_results[j];
                    result.asset_layer = result[$ "asset_layer"];
                    result.collision_layer = result[$ "collision_layer"];
                    result.sprite_swaps = result[$ "sprite_swaps"];
                    assert(CUTSCENES.contains_key(result.cutscene), "Cutscene does not exist: {}", result.cutscene);
                }
            }

            return challenges;
        });

        proto.stocks = apply_func(proto.stocks, function(e) {
            return apply_func(e, function(e) {
                //
                //
                //
                //
                return {
                    item: parse_store_item(e),
                    requirements: parse_requirements(e[$ "requirements"] ?? {}),
                    tier_required: e.tier_required,
                    has_unlocked_animal: opt_and_then(e[$ "has_unlocked_animal"], string_to_animal_kind),
                };
            });
        });

        if proto.associated_quest != undefined {
            assert(QUESTS.contains_key(proto.associated_quest), "Quest '{}' does not exist!", proto.associated_quest);
        }

        if proto.festival_post_line != undefined {
            proto.festival_post_line = string_to_gp_triggered_conversation(proto.festival_post_line);
        }

        if proto.festival_post_sprite != undefined {
            proto.festival_post_sprite = string_to_asset(proto.festival_post_sprite);
        }

        proto.location_music = struct_to_array(proto.location_music, LocationId.LEN, string_to_location_id);

        proto.decor = struct_to_array(proto.decor, LocationId.LEN, string_to_location_id);

        //
        for (var location_id = 0; location_id < LocationId.LEN; location_id++) {
            var decor = proto.decor[location_id];
            if decor != undefined {
                decor.grid_flag_edits = array_map(decor.grid_flag_edits, function(input) {
                    return [input.position[0], input.position[1], input.value];
                });
            }
        }

        if proto.npc_date != undefined {
            proto.npc_date.item = opt_and_then(proto.npc_date[$ "item"], try_string_to_item_id);
            proto.npc_date.solo_cutscene = proto.npc_date[$ "solo_cutscene"] != undefined
                ? CONTENT_REGISTRY.validate_cutscene(proto.npc_date.solo_cutscene)
                : undefined;
            var keys = struct_get_names(proto.npc_date.participants);
            for (var j = 0; j < array_length(keys); j++) {
                var npc_data = proto.npc_date.participants[$ keys[j]];
                npc_data.basic_accept.line = string_to_gp_triggered_conversation(npc_data.basic_accept.line);
                npc_data.basic_accept.requirements = parse_requirements(npc_data.basic_accept.requirements);

                if npc_data[$ "super_accept"] != undefined {
                    npc_data.super_accept.line = string_to_gp_triggered_conversation(npc_data.super_accept.line);
                    npc_data.super_accept.requirements = parse_requirements(npc_data.super_accept.requirements);
                } else {
                    npc_data.super_accept = undefined;
                }
                npc_data.decline_line = string_to_gp_triggered_conversation(npc_data.decline_line);
                npc_data.friend_decline_line = string_to_gp_triggered_conversation(npc_data.friend_decline_line);
                assert(CUTSCENES.contains_key(npc_data.cutscene), "Cutscene '{}' does not exist!", npc_data.cutscene);
            }
        }

        var idx = string_to_festival_id(key);
        output[idx] = new Festival(idx, proto);
    }
    return output;
}

//
function Festival(id, prototype) constructor {
    self.id = id;
    self.prototype = prototype;

    //
    function is_today() {
        return self.prototype.implemented
            && CALENDAR.season() == self.prototype.date.season
            && CALENDAR.day() == self.prototype.date.day - 1
            && !CANCEL_FESTIVALS;
    }

    //
    function build_layers() {

        //
        if !self.prototype.implemented|| !self.is_today() {
            return;
        }

        //
        var decor = self.prototype.decor[CURRENT_LOCATION_ID];
        if decor != undefined {
            for (var i = 0; i < array_length(decor.asset_layers); i++) {
                var is_floor_sprites =  string_pos("FloorSprites", decor.asset_layers[i]) != 0;
                process_asset_layer(layer_get_id(decor.asset_layers[i]), is_floor_sprites);
            }
            for (var i = 0; i < array_length(decor.collision_layers); i++) {
                process_other_collision_layer(CURRENT_LOCATION_ID, decor.collision_layers[i]);
            }
            var grid_flag_edit;
            for (var i = 0; i < array_length(decor.grid_flag_edits); i++) {
                grid_flag_edit = decor.grid_flag_edits[i];
                set_collision_grid_flag_on_node(GRID, grid_flag_edit[2], grid_flag_edit[0], grid_flag_edit[1]);
            }
        }

        //
        if CURRENT_LOCATION_ID != self.prototype.location {
            return;
        }

        //
        for (var i = 0; i < array_length(self.prototype.challenges); i++) {
            var challenge = self.prototype.challenges[i];
            var artifact = ARI.quest_artifacts.get(challenge.artifact_key);
            if artifact == undefined {
                continue;
            }

            //
            for (var j = 0; j <= artifact.last_tier; j++) {
                var tier = challenge.tier_results[j];

                if tier.asset_layer != undefined  {
                    process_asset_layer(layer_get_id(tier.asset_layer));
                }

                if tier.collision_layer != undefined {
                    process_other_collision_layer(self.prototype.location, tier.collision_layer);
                }

                if tier.sprite_swaps != undefined {
                    var keys = struct_get_names(tier.sprite_swaps);
                    for (var k = 0; k < array_length(keys); k++) {
                        var asset = string_to_asset(keys[k]);
                        with obj_assetobject {
                            if
                                self.sprite_index == asset
                                //
                                && color_get_green(self.original_blend) != 255
                            {
                                self.sprite_index = string_to_asset(tier.sprite_swaps[$ keys[k]]);
                                shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));
                            }
                        }
                    }
                }
            }
        }
    }

    //
    function room_start() {

        //
        if !self.prototype.implemented|| !self.is_today() {
            return;
        }

        //
        if CURRENT_LOCATION_ID != self.prototype.location {
            return;
        }

        //
        if MIST.is_running() {
            return;
        }

        //
        for (var i = 0; i < array_length(self.prototype.challenges); i++) {
            var challenge = self.prototype.challenges[i];
            var artifact = ARI.quest_artifacts.get(challenge.artifact_key);
            if artifact == undefined {
                continue;
            }

            //
            //
            if QUEST_LOG.active.contains_key(self.prototype.associated_quest) {
                MIST.spawn_trigger(challenge.tier_results[artifact.last_tier].cutscene);
            }
        }

        //
        if self.prototype.npc_date != undefined && self.prototype.npc_date.manual == false {
            if ARI.festival_date_partner != undefined {
                var date_data = self.prototype.npc_date.participants[$ npc_id_to_string(ARI.festival_date_partner)];

                var target_scene = date_data.cutscene;
                var scene_seen = MIST.scene_history.contains(target_scene);
                //
                //
                //
                if (NPCS[ARI.festival_date_partner].is_partner() || scene_seen)
                    && !(matches(ARI.festival_date_partner, NpcId.Caldarus, NpcId.Seridia) && !scene_seen)
                {
                    start_date_cutscene(ARI.festival_date_partner, Date.ShootingStar);
                    T2R.write(
                        "shooting_star_date_status",
                        format("{NpcId}_went", ARI.festival_date_partner),
                        CALENDAR.time + days(14),
                    );
                } else {
                    MIST.blackboard.insert("date_partner", npc_id_to_string(ARI.festival_date_partner));
                    MIST.spawn_trigger(target_scene);
                }
            } else if self.prototype.npc_date.solo_cutscene != undefined {
                MIST.spawn_trigger(self.prototype.npc_date.solo_cutscene);
            }
        }
    }

    //
    function room_end() {
        //
        if CURRENT_LOCATION_ID != self.prototype.location || !self.is_today() {
            return;
        }

        //
        if !self.prototype.implemented {
            return;
        }

        for (var i = 0; i < array_length(self.prototype.challenges); i++) {
            var challenge = self.prototype.challenges[i];

            //
            var artifact = ARI.quest_artifacts.get(challenge.artifact_key);
            if artifact == undefined {
                continue;
            }
            var index = artifact.last_tier;

            //
            for (var j = 0; j < min(index + 1, array_length(challenge.tier_results)); j++) {
                var tier = challenge.tier_results[j];
                if tier.collision_layer != undefined {
                    process_other_collision_layer(self.prototype.location, tier.collision_layer, false);
                }
            }
        }

        var decor = self.prototype.decor[CURRENT_LOCATION_ID];
        if decor != undefined {
            for (var i = 0; i < array_length(decor.collision_layers); i++) {
                process_other_collision_layer(CURRENT_LOCATION_ID, decor.collision_layers[i], false);
            }
        }
    }

    //
    function end_day() {
        //
        if !self.prototype.implemented {
            return;
        }

        //
        if !self.is_today() {
            return;
        }

        //
        if QUEST_LOG.active.contains_key(self.prototype.associated_quest) {
            var active = QUEST_LOG.active.get(self.prototype.associated_quest);
            while active.progress() != ProgressOutput.Complete {}
            QUEST_LOG.complete(self.prototype.associated_quest);
        }

        //
        if ARI.festival_date_partner != undefined {
            T2R.write(
                format("has_been_to_{FestivalId}_festival_with_{NpcId}", self.id, ARI.festival_date_partner),
                true,
            );
            T2R.write(
                format("{FestivalId}_date_partner", self.id),
                undefined,
            );
            ARI.festival_date_partner = undefined
        }

        //
        if self.prototype.npc_date != undefined && self.prototype.npc_date.item != undefined {
            remove_item_from_world(self.prototype.npc_date.item);
        }

        for (var i = 0; i < LocationId.LEN; i++) {
            var location_decor = self.prototype.decor[i];
            if location_decor != undefined {
                for (var j = 0, jc = array_length(location_decor.collision_layers); j < jc; j++) {
                    process_other_collision_layer(i, location_decor.collision_layers[j], false);
                }

                for (var j = 0, jc = array_length(location_decor.grid_flag_edits); j < jc; j++) {
                    var grid_flag_edit = location_decor.grid_flag_edits[j];
                    remove_collision_on_node(GRIDS[i], grid_flag_edit[0], grid_flag_edit[1]);
                }
            }
        }
    }

    //
    function new_day() {
        //
        if !self.prototype.implemented {
            return;
        }

        //
        //
        if self.is_today() {
            if self.prototype.associated_quest != undefined {
                QUEST_LOG.start(self.prototype.associated_quest);
            }

            for (var i = 0; i < array_length(self.prototype.writes); i++) {
                var write_bundle = self.prototype.writes[i];
                trace("{}", write_bundle);
                T2R.write(write_bundle[0], write_bundle[1] == "undefined" ? undefined : write_bundle[1]);
            }
        }
    }

    //
    function days_until() {
        var date = self.prototype.date;
        var season = CALENDAR.season();
        var day = CALENDAR.day();

        //
        var target_year = CALENDAR.year();
        if date.season < season || (date.season == season && (date.day - 1) < day) {
            target_year += 1;
        }

        return day_delta(date.season, date.day - 1, target_year);
    }

    //
    function days_since() {
        var date = self.prototype.date;
        var season = CALENDAR.season();
        var day = CALENDAR.day();

        //
        var target_year = CALENDAR.year() - 1;
        if date.season < season || (date.season == season && (date.day - 1) < day) {
            target_year += 1;
        }

        return abs(day_delta(date.season, date.day - 1, target_year));
    }
}

//
function festival_room_start() {
    for (var i = 0; i < FestivalId.LEN; i++) {
        FESTIVALS[i].room_start();
    }
}

//
function festival_build_layers() {
    for (var i = 0; i < FestivalId.LEN; i++) {
        FESTIVALS[i].build_layers();
    }
}

//
function festival_room_end() {
    for (var i = 0; i < FestivalId.LEN; i++) {
        FESTIVALS[i].room_end();
    }
}

//
function festival_end_day() {
    for (var i = 0; i < FestivalId.LEN; i++) {
        FESTIVALS[i].end_day();
    }
}

//
function festival_new_day() {
    for (var i = 0; i < FestivalId.LEN; i++) {
        FESTIVALS[i].new_day();
    }
}

//
function setup_festival_ledger(festival, store, interaction_key, local_key) {
    var f = FESTIVALS[festival];

    if !f.is_today() {
        instance_destroy();
        return;
    }

    self.darkness_sprite = spr_nothing;
    self.store = store;

    self.name = interaction_key;
    self.local_key = local_key;
    self.register_interaction(
        InputId.Interact,
        "misc_local/shop",
        function() {
            ANCHOR.spawn_menu(Menu.Store, self.store);
        },
    );

    depth = get_instance_depth(y, -10);
}

//
function todays_festival() {
    for (var i = 0; i < FestivalId.LEN; i++) {
        var festival = FESTIVALS[i];
        if festival.is_today() {
            return i;
        }
    }
    return undefined;
}
