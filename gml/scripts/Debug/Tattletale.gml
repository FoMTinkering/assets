//
function create_world_error_context() {
    var context = {
        runtime: {
            name: "maybe",
        },
        app: {
            app_version: version_to_string(GAME_VERSION),
        },
        tick: {
            tick: FORMAT_PREFIX(TICK),
        },
        settings: SETTINGS.inner,
    };
    //
    if is_world_room(room()) && Game.last_serde_path != undefined {
        context.last_save_path = Game.last_serde_path;
    }

    if DISPLAY != undefined {
        var output_dimensions = window_get_output_dimensions();
        context.display_state = {
            is_fullscreen: window_is_fullscreen(),
            expansion: DISPLAY.expansion,
            view_size: format("{}x{}", CAMERA.view_width, CAMERA.view_height),
            output_size: format("{}x{}", output_dimensions[0], output_dimensions[1]),
        };
    }

    if !is_world_room(room()) {
        context.game_state = {
            in_game: false
        }
    } else {
        context.game_state = {
            in_game: true,
            weather_type: WEATHER.weather,
            current_room: asset_to_string(room()),
            date_time: fmt(
                "Day {}, Season {Season}, Year {} @ {} (raw: {})",
                CALENDAR.day() + 1,
                CALENDAR.season(),
                CALENDAR.year(),
                clock_time_to_string(CLOCK.time),
                CALENDAR.unified_time(),
            ),
            day_time_speed: minutes_per_day_to_day_time_speed(MINUTES_PER_DAY),
            npc_locations: [],
        }
        for (var i = 0; i < NpcId.LEN; i++) {
            array_push(
                context.game_state.npc_locations,
                fmt(
                    "{}: {}",
                    npc_id_to_string(i),
                    NPCS[i].location_position.toString(),
                )
            );
        }
        var cursor = undefined;

        if instance_exists(obj_tile_cursor) {
            cursor = {
                last_valid_position : fmt("{}x{}", obj_tile_cursor.last_valid_selection.x, obj_tile_cursor.last_valid_selection.y),
                mouse_position : fmt("{}x{}", mouse_x(), mouse_y())
            }
        }

        if instance_exists(obj_ari) {
            var inventory_names = [];
            for(var i = 0, c = ARI.inventory.size(); i < c; i++) {
                var slot = ARI.inventory.slot(i);
                if slot.count != 0 {
                    array_push(inventory_names, item_id_to_string(slot.item.item_id))
                }
            }

            var chest_slot = obj_ari.par.slots[AnimationSlot.BaseChest];
            var animation = "unknown"
            if chest_slot.base.animation_name != undefined {
                animation = animation_name_to_string(chest_slot.base.animation_name);
            }

            context.player_state = {
                position: fmt("{}x{}", obj_ari.x, obj_ari.y),
                health_current: ARI.health_current,
                stamina_current: ARI.stamina_current,
                items_in_inventory : inventory_names,
                held_index: ARI.held_item_index,
                animation,
                state: player_state_to_string(obj_ari.fsm.current_state_id()),
            }

            if cursor != undefined {
                context.player_state.cursor = cursor;
            }
        }

        if ARI.mount != undefined {
            context.mount = {
                kind: animal_kind_to_string(ARI.mount.kind),
                variant: ARI.mount.variant,
                sex: sex_to_string(ARI.mount.sex),
                name: ARI.mount.name,
                cosmetic: ARI.mount.cosmetic,
            };
        }
    }
    return context;
}
