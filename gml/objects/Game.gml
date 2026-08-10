var game_obj = object_create(
    "Game",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            depth = -15000;
            var start_time = get_timer();

            POST_PROCESS = new PostProcessor(POST_PROCESS_DATABASE.in_room);
            MIST = new Mist();
            ARI = new Ari();
            PET = new Pet();
            DAYCARE = List();
            DECOR = new Decor();
            PROP_PROTOTYPES = create_prop_prototypes();
            QUEST_LOG = new QuestLog();
            REQUEST_BOARD_ENTRIES = load_request_board_entries();
            MUSEUM_PROGRESS = array_bool(ItemId.LEN);
            CALENDAR = new Calendar();
            WEATHER = new WeatherManager();
            SATURDAY_MARKET = new SaturdayMarket();
            NPCS = array_create_ext(NpcId.LEN, function(i) {
                return new Npc(i, DefaultNpcBrain());
            });
            PATHFINDING = new Pathfinding();
            PAUSE_STATUS = PauseStatus.EMPTY;
            STORAGE_NODES.clear();
            FORAGEABLES = new Forageables();
            SEAL_INVENTORIES = create_seal_inventories();
            PROPS = new PropMaster();
            FISHING = FishHub();
            RENOWN_REWARD_INVENTORY = Inventory(8);
            DUNGEON = load_dungeon();
            DUNGEON_TREASURE = array_map(DUNGEON.biomes, create_treasure_distributions);
            MUSIC_PLAYER.selector = in_game_music_selector;
            AMBIENCE_PLAYER.selector = in_game_ambience_selector;
            STAIR_COUNT = 0;
            DATE_PHOTOS = [];
            LOST_AND_FOUND = Inventory(54);
            FISH_TRAP_RARITY = undefined;
            FISH_TRAP_TIMESTAMP = undefined;
            ACHIEVEMENTS_FILTER = HashSet();
            FACTORIES = List();
            //
            function exit_to_menu() {
                self.go_to_main_menu = true;
                MUSIC_PLAYER.stop();
                AMBIENCE_PLAYER.stop();
                WEATHER.stop_atmosphere_sounds();

                for (var i = 0; i < Season.LEN; i++) {
                    portrait_atlas_unload(season_to_portrait_atlas(i));
                }
            }

            //
            function execute_return_to_menu() {
                instance_destroy(self);
                if DEBUG_TOOLS {
                    instance_destroy(obj_cosmic_debug);
                }
                FROM_GAME = true;
                TAXI.itinerary = undefined;
                room_goto(rm_menu);
                global.__buildings = undefined;

                DUNGEON_RUNNER = undefined;
                GAME_STATS = undefined;
                NON_PLAYER_ANIMALS = undefined;
                PENDING_DAY_TIME_SPEED_CHANGE = undefined;
                CANCEL_FESTIVALS = undefined;
                MINUTES_PER_DAY = 15;
                PET = undefined;
                FACTORIES.clear();
                t2_reset_world();
                clear_loaded_date_photos();
            }

            function draw_lights() {
                if DEBUG_TOOLS {
                    gpu_push_group("lights");
                }

                gpu_set_srgb_blending(false);
                var is_dark_mines = in_dark_mines();

                //
                //
                //
                //
                gpu_set_blendmode_ext(
                    bm_dest_color,
                    bm_inv_src_alpha,
                );

                gpu_set_stencil_operation(StencilOperation.Replace);
                gpu_set_depth_test(is_dark_mines ? cmpfunc_always : cmpfunc_lessequal, false);

                var write_strength = POST_PROCESS.multiply_color[3];
                var final_write_strength = write_strength;

                if POST_PROCESS.multiply_by_light_count {
                    if is_home_location(CURRENT_LOCATION_ID) {
                        var diff_value = (write_strength - POST_PROCESS.min_multiply_level) * 0.5;
                        var new_target = diff_value * 2.0 * (1.0 - power(0.5, instance_number(par_light)));

                        self.last_alpha_edit_amount = approach(self.last_alpha_edit_amount, new_target, 0.003);
                        write_strength = max(
                            write_strength - self.last_alpha_edit_amount,
                            POST_PROCESS.min_multiply_level
                        );
                        final_write_strength = write_strength;
                    } else if is_dark_mines {
                        var new_target = undefined;
                        if ARI.status_effects.effects.get(StatusEffectId.SacredLight) != undefined {
                            new_target = 0.55;
                        } else if self.dark_room_target_override != undefined {
                            new_target = self.dark_room_target_override;
                        } else {
                            new_target = lerp(
                                POST_PROCESS.min_multiply_level,
                                write_strength,
                                self.dark_room_light_count / POST_PROCESS.multiply_by_light_count,
                            );
                        }

                        self.last_alpha_edit_amount = approach(self.last_alpha_edit_amount, new_target, self.dark_room_transition_speed);
                        write_strength = max(
                            write_strength - self.last_alpha_edit_amount,
                            POST_PROCESS.min_multiply_level
                        );

                        //
                        final_write_strength = 0.09;
                    } else {
                        write_strength = POST_PROCESS.min_multiply_level;
                        final_write_strength = write_strength;
                    }
                }

                gpu_set_extra(UberShaderKind.Light);
                var current_depth = gpu_get_depth();

                var tier_alpha = array_create(3);
                var tier_color = array_create(3);
                for (var i = 0; i < 3; i++) {
                    var s = POST_PROCESS.light_strength[3 - i];
                    tier_alpha[i] = is_dark_mines ? min(s, write_strength) : s * write_strength;
                    tier_color[i] = make_color_rgb(
                        round(255 * POST_PROCESS.multiply_color[0] * tier_alpha[i]),
                        round(255 * POST_PROCESS.multiply_color[1] * tier_alpha[i]),
                        round(255 * POST_PROCESS.multiply_color[2] * tier_alpha[i]),
                    );
                }

                var light_stencil_value = stencil_reserve_band(4);
                var non_tiered_lights_exist = false;
                for (var i = 0; i < 3; i++) {
                    gpu_set_stencil_test(cmpfunc_greater, light_stencil_value - i);

                    with par_light {
                        if self.show == false
                            || self.sprite_index == undefined
                        {
                            continue;
                        }

                        if self.tiered_light == undefined {
                            non_tiered_lights_exist = true;
                            continue;
                        }

                        var this_light_level = i - real(is_dark_mines && self["secondary"] != undefined);
                        if this_light_level < 0 {
                            continue;
                        }

                        var write_alpha = tier_alpha[i];
                        var write_color = tier_color[i];
                        var light_spr = LIGHTS[self.tiered_light][this_light_level];

                        if is_dark_mines == false {
                            gpu_set_depth(self.depth - sprite_get_yoffset(light_spr));
                        }
                        draw_sprite_ext(
                            light_spr,
                            self.image_index,
                            self.x,
                            self.y,
                            self.image_xscale,
                            self.image_yscale,
                            0,
                            write_color,
                            write_alpha,
                        );
                    }
                }

                //
                var exterior_window = instance_singleton(obj_exterior_window_interior);

                if non_tiered_lights_exist || exterior_window != undefined {
                    gpu_set_color_write(false);
                }
                with par_light {
                    if self.show && self.tiered_light == undefined && self.sprite_index != undefined {
                        gpu_set_depth(self.depth);

                        draw_sprite_ext(
                            self.sprite_index,
                            self.image_index,
                            self.x,
                            self.y,
                            self.image_xscale,
                            self.image_yscale,
                            0,
                            0,
                            0,
                        );
                    }
                }

                var exterior_window = instance_singleton(obj_exterior_window_interior);
                if exterior_window != undefined {
                    gpu_set_depth(exterior_window.depth);

                    //
                    //
                    for (var yy = 0; yy < ds_grid_height(exterior_window.windows); yy++) {
                        for (var xx = 0; xx < ds_grid_width(exterior_window.windows); xx++) {
                            if exterior_window.windows[# xx, yy] {
                                draw_sprite_ext(
                                    spr_pixel,
                                    0,
                                    xx * 8,
                                    yy * 8,
                                    8,
                                    8,
                                    0,
                                    0,
                                    0,
                                );
                            }
                        }
                    }
                }

                //
                if non_tiered_lights_exist || exterior_window != undefined {
                    gpu_set_color_write(true);
                }

                gpu_set_depth(current_depth);
                gpu_set_stencil_test(cmpfunc_greater, light_stencil_value - 3);
                gpu_set_depth_test(cmpfunc_always);

                //
                //
                final_write_strength = max(final_write_strength, write_strength);

                draw_sprite_ext(
                    spr_pixel,
                    0,
                    CAMERA.internal_cam_pos.x - CAMERA.x_buffer,
                    CAMERA.internal_cam_pos.y - CAMERA.y_buffer,
                    CAMERA.view_width + (CAMERA.x_buffer * 2),
                    CAMERA.view_height + (CAMERA.y_buffer * 2),
                    0,
                    make_color_rgb(
                        round(255 * POST_PROCESS.multiply_color[0] * final_write_strength),
                        round(255 * POST_PROCESS.multiply_color[1] * final_write_strength),
                        round(255 * POST_PROCESS.multiply_color[2] * final_write_strength),
                    ),
                    final_write_strength,
                );
                gpu_set_srgb_blending(true);
                gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);
                gpu_disable_stencil();
                gpu_reset_extra();
                if DEBUG_TOOLS {
                    gpu_pop_group();
                }
            }

            //
            self.unique_identifier = self.load_state.game_ident;
            self.last_serde_path = undefined;
            self.play_time_comparator = undefined;

            self.bell_sound_instance = undefined;

            switch self.load_state.type {
                case LoadStateId.Load:
                    var failure = false;

                    //
                    //
                    //
                    if !DEBUG_ASSERTIONS {
                        try {
                            load_game(self.load_state.loader);
                        } catch (e) {
                            failure = true;
                        }
                    } else {
                        load_game(self.load_state.loader);
                    }
                    //
                    vault_close_all_vaults();

                    failure |= self.load_state.loader.cannot_be_ran;

                    if failure {
                        DISPLAY_INVALID_SAVE_POPUP = 1;
                        self.execute_return_to_menu();
                        return;
                    }
                    break;
                case LoadStateId.New:
                    new_game(self.load_state.player_data);
                    break;
                default: impossible("unexpected load_state type: {}", self.load_state.type)
            }
            self.load_state = undefined;

            //
            //

            //
            if TEST_SUITE {
                FORMAT_PREFIX = function() {
                    var hex = int_to_hex_string(TICK % 256, 2);
                    return fmt("[{} | {time} | {}] ", hex, CLOCK.time, time_since_boot_str());
                }
            } else {
                FORMAT_PREFIX = function() {
                    var hex = int_to_hex_string(TICK % 256, 2);
                    return fmt("[{} | {time}] ", hex, CLOCK.time);
                }
            }

            setup_expansion_blockers(GRIDS[LocationId.Farm]);

            INN_STOCK = create_store_stock(Store.Inn);

            local_set_pronouns(ARI.pronouns);

            //
            ANCHOR.spawn_menu(Menu.ItemToasts);
            ANCHOR.spawn_menu(Menu.InfoToasts);
            ANCHOR.spawn_menu(Menu.Dingaling);
            for (var i = 0; i < Menu.LEN; i++) {
                if menu_is_hud(i) {
                    ANCHOR.spawn_menu(i);
                }
            }

            //
            if DEBUG_TOOLS {
                instance_create_depth(0,0,-10000, obj_cosmic_debug);
            }

            self.music_cut_off = false;
            self.late_warning_issued = false;
            self.bell_rang = false;
            self.go_to_main_menu = false;
            self.animal_eat = false;
            self.animal_eat_exit = false;
            self.turned_on_lights = false;

            self.prevent_eod_music_stop = false;
            self.last_alpha_edit_amount = 0;
            self.dark_room_light_count = 0;
            self.dark_room_target_override = undefined;
            self.player_home_light_count = 1000; //

            self.manual_crash_timer = 0;

            trace("Game initialization complete: {micro}!", get_timer() - start_time);

            if DEBUG_TOOLS {
                var value = environment_get_variable("FOM_QUICK_CMD");

                if value != undefined {
                    new_chain()
                        .join(LinkId.Timer, 1)
                        .append(LinkId.Function, function() {
                            BUGGER.execute_command(environment_get_variable("FOM_QUICK_CMD"));
                        });
                }
            }

            for (var i = 0; i < Perk.LEN; i++) {
                if GAME_STATS.perks[$ perk_to_string(i)] == undefined {
                    GAME_STATS.perks[$ perk_to_string(i)] = 0;
                }
            }
        },
        step: function() {
            FISHING.step();

            if game_paused() == false {
                npcs_on_step();
            }

            POST_PROCESS.update(POST_PROCESS_TIME_OVERRIDE ?? CLOCK.time);
            MIST.on_step();

            //
            if !self.music_cut_off && CLOCK.time >= NIGHT_TIME {
                self.music_cut_off = true;

                //
                //
                if !matches(CURRENT_LOCATION_ID, LocationId.Dungeon, LocationId.Inn, LocationId.MinesEntry)
                    && ARI.end_of_day_status == undefined
                {
                    MUSIC_PLAYER.refresh();
                    AMBIENCE_PLAYER.refresh();
                }
            }

            //
            if self.bell_rang == false && CLOCK.time >= NIGHT_TIME {
                if CLOCK.time <= (NIGHT_TIME + minutes(5)) {
                    var sound = bell_sound_path();
                    var sprite_mapping = undefined;
                    var sound_position = undefined;

                    if CURRENT_LOCATION_ID == LocationId.Town {
                        sound_position = Vec2(527, 1162);
                        sprite_mapping = [
                            spr_town_building_bell_tower_bell_idle,
                            spr_town_building_bell_tower_bell_ring,
                        ];
                    }

                    if CURRENT_LOCATION_ID == LocationId.BellTowerF2 {
                        sprite_mapping = [
                            spr_bell_tower_f2_bell_idle,
                            spr_bell_tower_f2_bell_ring,
                        ];
                    }

                    if sound_position == undefined {
                        self.bell_sound_instance = TANGO.play(sound);
                    } else {
                        self.bell_sound_instance = TANGO.play(sound, sound_position.x, sound_position.y);
                    }

                    if sprite_mapping != undefined {
                        with obj_assetobject {
                            if self.sprite_index == sprite_mapping[0] {
                                self.image_index = 0;
                                self.sprite_index = sprite_mapping[1];
                                new_world_chain(self, CURRENT_LOCATION_ID)
                                    .append(LinkId.Await, function() {
                                        return !TANGO.instance_alive(Game.bell_sound_instance);
                                    })
                                    .append(LinkId.Function, function(asset, sprite_mapping) {
                                        asset.sprite_index = sprite_mapping[0];
                                    }, [self, sprite_mapping]);
                                break;
                            }
                        }
                    }
                }
                self.bell_rang = true;
            }

            if self.animal_eat == false && CLOCK.time >= hours(10) {
                var animals = get_all_animals();
                for (var i = 0; i < animals.count(); i++) {
                    var animal = animals.get(i);

                    //
                    if animal.is_home()
                        && !animal.has_eaten
                        && animal.location_position.location_id != CURRENT_LOCATION_ID
                    {
                        animal_try_to_eat_from_stable(animal, animal.stable);
                    }
                }

                if (CURRENT_LOCATION_ID == LocationId.SmallBarn
                    || CURRENT_LOCATION_ID == LocationId.SmallBarn
                    || CURRENT_LOCATION_ID == LocationId.MediumBarn
                    || CURRENT_LOCATION_ID == LocationId.MediumCoop
                    || CURRENT_LOCATION_ID == LocationId.LargeBarn
                    || CURRENT_LOCATION_ID == LocationId.LargeCoop)
                    && ANCHOR.get_menu(Menu.Eod) == undefined
                {
                    self.animal_eat_exit = true;
                }
            }

            pet_update_at_time(CLOCK.time);

            if !self.late_warning_issued && CLOCK.time >= hours(24) {
                create_notification("misc_local/late_warning");
                self.late_warning_issued = true;
            }

            if self.turned_on_lights == false && CLOCK.time >= LIGHT_TURN_ON_TIME || MIST.blackboard.get("force_lights_on") == true {
                with obj_exterior_light {
                    self.turn_on();
                }

                self.turned_on_lights = true;
            }

            //
            if self.spawn_birds != undefined && CLOCK.time <= NIGHT_TIME && game_paused() == false {
                self.bird_refresh -= 1;

                if self.bird_refresh <= 0 && instance_number(obj_bird) < self.spawn_birds {
                    //
                    var landing_position = instance_find(obj_bird_landing_position, irandom(instance_number(obj_bird_landing_position) - 1));
                    if landing_position != undefined && landing_position.occupied == undefined {
                        var b = instance_create_depth(choose(0, CAMERA.room_view_bound_width), choose(0, CAMERA.room_view_bound_height), 0, obj_bird, { target: landing_position });
                        landing_position.occupied = b;
                    }

                    self.bird_refresh = irandom_range(60, 120);
                }
            }

            //
            if !TEST_SUITE
                && is_dungeon_room(room())
                && DUNGEON_RUNNER != undefined
                && DUNGEON_RUNNER.current_level().impl == DungeonImpl.Enemy
                && DUNGEON_RUNNER.finished_enemy_floor == EnemyFloorState.OnGoing
                && instance_number(par_monster) == 0
                && instance_exists(obj_ari)
                && obj_ari.is_in_normal_state()
            {
                DUNGEON_RUNNER.finished_enemy_floor = EnemyFloorState.Finished;
                DUNGEON_RUNNER.blocking_music = false;
                obj_ari.end_hurt_state();
                obj_ari.iframe_can_invisible = false;
                obj_ari.par.alpha = 1.0;
                shadow_caster_set_alpha(obj_ari.shadow_caster, obj_ari.par.alpha);

                MIST.place_on_runtime_blackboard("ladder_x", obj_dungeon_ladder_down.x);
                MIST.place_on_runtime_blackboard("ladder_y", obj_dungeon_ladder_down.y);
                MIST.run_scene("arena_end");
            }

            if RUMBLE != undefined {
                var gp_modifier = SETTINGS.get("rumble");
                for (var i = 0; i < GAMEPADS_COUNT; i++) {
                    if gamepad_is_connected(i) {
                        gamepad_set_vibration(
                            i,
                            sin(RUMBLE.timer * pi / (RUMBLE.max_length * 0.5)) * RUMBLE.left_max * gp_modifier,
                            sin(RUMBLE.timer * pi / (RUMBLE.max_length * 0.5)) * RUMBLE.right_max * gp_modifier,
                        );
                    }
                }

                RUMBLE.timer += 1;

                if RUMBLE.timer >= RUMBLE.max_length {
                    RUMBLE = undefined;
                }
            }
        },
        step_begin: function() {
            TICK++;

            INPUT.begin_frame();

            CLOCK.update();
            T2R.update();

            if DEBUG_TOOLS {
                BUGGER.update();
            }
            CHAINS.on_begin_step();
            ANCHOR.on_begin_step();
        },
        step_end: function() {
            CAMERA.update();
            CURSOR.step();
            GLYPH_GUIDE.process();

            run_node_renderer_utils();

            FOCUS.on_end_step();
            MUSIC_PLAYER.on_step();
            AMBIENCE_PLAYER.on_step();

            if keyboard_check(vk_control) && keyboard_check(vk_shift) && keyboard_check(vk_f12) {
                self.manual_crash_timer += 1;
                if self.manual_crash_timer >= 30 {
                    var crash_kind = environment_get_variable("MISTRIA_TEST_CRASH");
                    switch crash_kind {
                        case "script":
                            crash("Test Crash");
                            break;
                        case "native":
                            __native_crash("Test Crash");
                            break;
                        default:
                            self.manual_crash_timer = 0;
                            warn("unknown crash kind: {}", crash_kind);
                            break;
                    }
                }
            } else {
                self.manual_crash_timer = 0;
            }
        },
        draw: function() {
            draw_extra_shadow_maps();
            WEATHER.on_draw();
            if POST_PROCESS != undefined && POST_PROCESS.should_post_process {
                self.draw_lights();
            }
        },
        room_start: function() {
            var start_time = get_timer();

            if DEBUG_TOOLS {
                interactable_fiddle_update();
            }

            //
            SHADOW_GRID.free();
            ANIMAL_TOYS_IN_ROOM.clear();
            WINDOWS = [];

            SHADOW_GRID = new ShadowGrid();

            for (var i = 0; i < SHADOW_WAIT_LIST.count(); i++) {
                var shadow_data = SHADOW_WAIT_LIST.get(i);
                shadow_caster_set_sprite(SHADOW_GRID.caster_create(shadow_data.x, shadow_data.y), shadow_data.sprite);
            }
            SHADOW_WAIT_LIST.clear();

            //
            GRID.remove_as_current_grid();
            if is_dungeon_room(room()) {
                if is_special_dungeon_room(room()) {
                    GRID = GRIDS[gm_room_to_location_id(room())];
                } else {
                    GRID = create_dungeon_grid(room());
                }
            } else {
                if TAXI.itinerary.dyn_index == undefined {
                    GRID = GRIDS[gm_room_to_location_id(room())];
                } else {
                    GRID = DYNAMIC_GRIDS.get(TAXI.itinerary.dyn_index);
                }
            }

            last_alpha_edit_amount = 0;
            dark_room_target_override = undefined;
            dark_room_light_count = 0;
            dark_room_transition_speed = 0.03;
            if in_dark_mines() {
                dark_room_transition_speed = 0.006;
            }

            //
            if room() == rm_priestess_quarters {
                dark_room_light_count = 1;
                dark_room_transition_speed = 1;
            }
            instance_create_layer(0, 0, "Instances", obj_ari);

            world_chain_clean_locations(CHAINS.chains, CURRENT_LOCATION_ID);

            POST_PROCESS = post_process_by_location();
            CAMERA.on_room_start();
            if MIST.running == false {
                PROPS.on_room_start();
            }

            SPRINKLER_TIMER = 150;

            PATHFINDING.on_room_start();
            setup_room();

            //
            if is_home_location(GRID.location_id) {
                DECOR.setup_room(GRID, false);
            }

            if LOCATIONS[GRID.location_id].wall_shadows != undefined {
                var shadow_level = instance_create_depth(
                    0,
                    0,
                    room_data_layer_depth(location_id_to_gm_room(GRID.location_id), "Level_0_Walls") - 1,
                    obj_shadow_level,
                    {
                        target_shadow_grid: new ShadowGrid(true),
                        shadow_maps: undefined,
                        render_outlines: false,
                        shadow_area: [
                            spr_pixel,
                            0,
                            0,
                            0,
                            room_width(),
                            LOCATIONS[GRID.location_id].wall_shadows,
                        ],
                        wall_shadow: true,
                    }
                );
                if DEBUG_TOOLS {
                    shadow_level.name = "WallsShadows";
                }
            }

            if GRID.location_id == LocationId.DeepWoods
                && requirements_pass(Requirement.ClosedFinalSeal)
            {
                var stump_node_index = GRID.node_index_for_cell(196, 162);
                if GRID.node_object_id[stump_node_index] == ObjectId.StumpLarge {
                    erase_object_node(GRID, stump_node_index);
                }
            }

            GRID.initialize_on_room_start();

            if is_dungeon_room(room()) {
                on_dungeon_enter();
            }

            //
            //
            //
            //
            //
            if room() == rm_mines_entry {
                obj_dungeon_elevator.dungeon_init();
                obj_dungeon_ladder_down.dungeon_init();
            }

            DECOR.on_room_start();
            TAXI.arrive();

            festival_room_start();

            if MIST.running == false {
                npcs_on_room_start();
            }
            setup_all_fish_spawners();
            var buildings = get_buildings();
            for (var i = 0; i < buildings.count(); i++) {
                var building = buildings.get(i);
                if building.stable != undefined {
                    building.stable.on_room_start();
                }
            }
            WEATHER.on_room_start();
            npas_room_start();
            ANCHOR.on_room_start();
            pet_on_room_start();

            spawn_animal_toys();

            //
            //
            spawn_bugs_on_room_start();
            MIST.on_room_start();

            //
            //
            if instance_exists(obj_ari) && !MIST.is_running() {
                obj_ari.quest_handle_queries();
            }

            if is_home_location(CURRENT_LOCATION_ID) == false {
                ARI.has_left_house_today = true;
            }

            ARI.used_elevator = false;
            if !game_paused() && ARI.end_of_day_status == undefined {
                show_room_title();
            }

            if LOCATIONS[CURRENT_LOCATION_ID].bird_count == undefined {
                self.spawn_birds = undefined;
            } else {
                var range = LOCATIONS[CURRENT_LOCATION_ID].bird_count;
                self.spawn_birds = irandom_range(range.x, range.y);
            }
            self.bird_refresh = 0;

            if MIST_SIGHT_ACTIVE_INDEX != undefined {
                var mist_sight = MIST_SIGHT_LIST.get(MIST_SIGHT_ACTIVE_INDEX);
                if mist_sight.location_id == CURRENT_LOCATION_ID {
                    instance_create_layer(mist_sight.pos.x, mist_sight.pos.y, "Instances", obj_mist_spot, {
                        index: MIST_SIGHT_ACTIVE_INDEX
                    });
                }
            }
            MUSIC_PLAYER.refresh();
            AMBIENCE_PLAYER.refresh();

            trace(
                "Loaded '{}' in {micro}",
                display_location(CURRENT_LOCATION_ID, CURRENT_DYN_INDEX, room()),
                get_timer() - start_time,
            );
        },
        room_end: function() {
            switch CURRENT_LOCATION_ID {
                case LocationId.Farm:
                    get_all_animals().for_each(function(animal) {
                        if animal.location_position.location_id == LocationId.Farm && (animal.liminal || animal.instance != undefined) {
                            //
                            var sprites = animal.sprites_for_animation("idle", Cardinal.East);

                            var bbox_dims = shape_get_dimensions(sprites.base_sprite);
                            var bbox_offset = shape_get_offset(sprites.base_sprite);

                            var bbl = animal.location_position.pos.x + bbox_offset[0];
                            var bbr = bbl + bbox_dims[0];
                            var bbb = animal.location_position.pos.y + bbox_offset[1];
                            var bbt = bbb + bbox_dims[1];

                            var node_tl = GRID.try_node_index_for_room_position(bbl, bbt);
                            var node_tr = GRID.try_node_index_for_room_position(bbr, bbt);
                            var node_bl = GRID.try_node_index_for_room_position(bbl, bbb);
                            var node_br = GRID.try_node_index_for_room_position(bbr, bbb);

                            if node_tl == undefined || node_tr == undefined || node_bl == undefined || node_br == undefined {
                                return;
                            }

                            var stuck = object_id_to_object_category(GRID.node_object_id[node_tl]) == ObjectCategory.Building
                                || object_id_to_object_category(GRID.node_object_id[node_tr]) == ObjectCategory.Building
                                || object_id_to_object_category(GRID.node_object_id[node_br]) == ObjectCategory.Building
                                || object_id_to_object_category(GRID.node_object_id[node_bl]) == ObjectCategory.Building;

                            if stuck {
                                var attempts = 0;
                                while stuck && attempts < 8 {
                                    attempts += 1;
                                    var dir = 0;
                                    if animal.prototype.core.size == AnimalSize.Large {
                                        dir = 270;
                                    }
                                    animal.location_position.pos.x += lengthdir_x(16, dir);
                                    animal.location_position.pos.y += lengthdir_y(16, dir);
                                    animal.location_position.pos.x = clamp(animal.location_position.pos.x, 0, 2044);

                                    var bbox_dims = shape_get_dimensions(sprites.base_sprite);
                                    var bbox_offset = shape_get_offset(sprites.base_sprite);
                                    bbl = animal.location_position.pos.x + bbox_offset[0];
                                    bbr = bbl + bbox_dims[0];
                                    bbb = animal.location_position.pos.y + bbox_offset[1];
                                    bbt = bbb + bbox_dims[1];

                                    var node_tl = GRID.try_node_index_for_room_position(bbl, bbt);
                                    var node_tr = GRID.try_node_index_for_room_position(bbr, bbt);
                                    var node_bl = GRID.try_node_index_for_room_position(bbl, bbb);
                                    var node_br = GRID.try_node_index_for_room_position(bbr, bbb);

                                    if node_tl == undefined || node_tr == undefined || node_bl == undefined || node_br == undefined {
                                        stuck = false;
                                    } else {
                                        stuck = object_id_to_object_category(GRID.node_object_id[node_tl]) == ObjectCategory.Building
                                            || object_id_to_object_category(GRID.node_object_id[node_tr]) == ObjectCategory.Building
                                            || object_id_to_object_category(GRID.node_object_id[node_br]) == ObjectCategory.Building
                                            || object_id_to_object_category(GRID.node_object_id[node_bl]) == ObjectCategory.Building;
                                    }
                                }
                            }
                        }
                    });

                    sprinkler_exit_room();
                    break;
                case LocationId.SmallCoop:
                case LocationId.SmallBarn:
                case LocationId.MediumBarn:
                case LocationId.MediumCoop:
                case LocationId.LargeBarn:
                case LocationId.LargeCoop:
                    if GRID.dyn_index != undefined {
                        var d_grid = DYNAMIC_GRIDS.get(GRID.dyn_index);
                        if d_grid.ocarina != undefined && d_grid.ocarina.sound_idx != undefined {
                            TANGO.request_stop(d_grid.ocarina.sound_idx);
                        }

                        if self.animal_eat_exit {
                            var animals = get_all_animals();
                            for (var i = 0; i < animals.count(); i++) {
                                var animal = animals.get(i);
                                if animal.is_home() && !animal.has_eaten {
                                    animal_try_to_eat_from_stable(animal, animal.stable);
                                }
                            }
                            self.animal_eat_exit = false;
                        }
                    }
                    break;

                case LocationId.LargeGreenhouse:
                case LocationId.SmallGreenhouse:
                    sprinkler_exit_room();
                    break;

                case LocationId.PlayerHome:
                    self.player_home_light_count = instance_number(par_light);
                    break;
            }

            with obj_player_animal {
                if self.fsm.current_state_id() == AnimalState.Eat || self.fsm.current_state_id() == AnimalState.Pathfinding {
                    self.fsm.current_state().finish_food(true);
                }

                if self.fsm.blackboard.get("on_animation_complete_params") != undefined {
                    var args = self.fsm.blackboard.take("on_animation_complete_params");
                    GRID.lost_items.push({
                        x: args[1],
                        y: args[2],
                        items: ListFromArray(array_create(args[0], new LiveItem(ItemId.AnimalCurrency)))
                    })
                    array_push(GAME_STATS.animal_bead_drops, {
                        amount: args[0],
                        day: total_days(),
                    });
                }
            }

            store_loose_items_as_lost();
            festival_room_end();

            INTERACTABLES.clear();
        },
        cleanup: function() {
            WEATHER = undefined;
            ANCHOR.shutdown();
            var control = ANCHOR.control_mode;
            create_anchor();
            ANCHOR.control_mode = control;
            LOAD_SEQUENCE = new LoadSequence();
            if DEBUG_TOOLS {
                BUGGER = new Bugger();
                bugger_initialize();
            }

            ACTIVE_ROOM_TITLE = undefined;
        },
    }
);

object_persists_on_room_change(game_obj);
