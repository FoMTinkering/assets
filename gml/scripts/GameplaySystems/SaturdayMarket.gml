#macro SATURDAY_MARKET global.__saturday_market
global.__saturday_market = undefined;

//
//
function SaturdayMarket() constructor {
    self.stalls = array_create(NpcId.LEN, false);
    self.active = false;

    function on_new_day(override_vendors) {
        for (var i = 0; i < NpcId.LEN; i++) {
            self.stalls[i] = false;
        }

        if requirements_pass(Requirement.SaturdayMarketUnlocked) && CALENDAR.day_type() == Day.Saturday {
            //
            //
            self.stalls = override_vendors ?? self.eligible_vendors();

            self.active = true;

            for (var i = 0; i < NpcId.LEN; i++) {
                if self.stalls[i] {
                    var name = format("Stall_{}", capitalize(npc_id_to_string(i)));
                    process_other_collision_layer(LocationId.Town, name);
                }
            }
        } else {
            self.active = false;
        }
    }

    function on_end_day() {
        if requirements_pass(Requirement.SaturdayMarketUnlocked) && CALENDAR.day_type() == Day.Saturday  {
            for (var i = 0; i < NpcId.LEN; i++) {
                if self.stalls[i] {
                    var name = format("Stall_{}", capitalize(npc_id_to_string(i)));
                    process_other_collision_layer(LocationId.Town, name, false);
                }
            }
            process_other_collision_layer(LocationId.Town, "Saturday_Market", false);
        }
    }

    function on_room_start() {
        if CURRENT_LOCATION_ID != LocationId.Town {
            return;
        }

        //
        var layers = layer_get_all();
        for (var i = 0; i < array_length(layers); i++) {
            var layer_id = layers[i];
            var layer_name = layer_get_name(layer_id);

            if string_pos("_Stall_", layer_name) == 0 {
                if self.active {
                    if layer_name == "Level_0_Assets_Saturday_Market" {
                        process_asset_layer(layer_id);
                    }
                    if layer_name == "Tiles_Collision_Saturday_Market" {
                        process_other_collision_layer(LocationId.Town, "Saturday_Market");
                    }
                    if layer_name == "Level_0_FloorSprites_Saturday_Market" {
                        process_asset_layer(layer_id, true);
                    }
                }
                continue;
            }

            //
            var is_active = false;
            for (var j = 0; j < NpcId.LEN; j++) {
                if self.stalls[j] == false {
                    continue;
                }
                var key = npc_id_to_string(j);
                if string_pos(key, string_lower(layer_name)) != 0 {
                    is_active = true;
                    break;
                }
            }
            if is_active {
                if string_pos("Tiles_Collision", layer_name) != 0 {
                    process_other_collision_layer(LocationId.Town, string_trim(layer_name, ["Tiles_Collision_"]));
                } else if string_pos("FloorSprites", layer_name) != 0 {
                    process_asset_layer(layer_id, true);
                } else if string_pos("Assets", layer_name) != 0 {
                    process_asset_layer(layer_id);
                }
            } else if string_pos("Lighting", layer_name) != 0 {
                layer_destroy_instances(layer_id);
            }

            //
            //
            //
            //
            //
            //
        }
    }

    function eligible_vendors() {
        return array_create_ext(NpcId.LEN, function(v) {
            return array_contains(NPC_PROTOTYPES[v].tags, "vendor") && npc_is_unlocked(v);
        });
    }
}
