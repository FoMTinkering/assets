global.prop_map = undefined;
function toggle_asset_visibility(asset_name, mist=true) {
    var sprite = string_to_asset(asset_name);

    if DEBUG_ASSERTIONS && mist {
        var cutscene_data = CUTSCENES.get(MIST.active_cutscene.id);
        var success = false;
        for (var i = 0, c = array_length(cutscene_data.invisible_assets); i < c; i++) {
            if cutscene_data.invisible_assets[i] == sprite {
                success = true;
                break;
            }
        }
        assert(success, "asset {} was not well defined in cutscene.toml", asset_name);
    }

    with obj_assetobject {
        if sprite_index == sprite {
            visible = !visible;
            if self.light != undefined {
                self.light.show = !self.light.show;
            }
            shadow_caster_set_alpha(self.shadow_caster, 0);
            break;
        }
    }
}

function mist_position_input(xx, yy) {
    if is_string(xx) {
        if xx == "ari" {
            return Vec2(obj_ari.x, obj_ari.y);
        } else if xx == "pet" {
            return Vec2(obj_pet.x, obj_pet.y);
        } else if xx == "void_ari" {
            return Vec2(obj_void_ari.x, obj_void_ari.y);
        } else {
            var tp = trellis_point_find_by_name(
                location_id_to_gm_room(TAXI.current_location_id()),
                xx,
            );
            if tp == undefined {
                var npc_id = string_to_npc_id(xx);
                return MIST.npcs.get(npc_id).location_position.pos;
            } else {
                return Vec2(tp.x, tp.y);
            }
        }
    } else {
        return Vec2(xx, yy);
    }
}

function define_std(_runtime) {
    with _runtime {
        function handle_item_input(item) {
            if item == "lightweight_copper_ring" {
                var live_item = new LiveItem(ItemId.CopperRing);
                live_item.infusion = Infusion.Lightweight;
                return live_item;
            } else if item == "lightweight_hoe_copper" {
                var live_item = new LiveItem(ItemId.HoeCopper);
                live_item.infusion = Infusion.Lightweight;
                return live_item;
            } else {
                return new LiveItem(string_to_item_id(item));
            }
        }

        function create_function(name, func) {
            var callable = new NativeCallable(self).set_call(func);
            self.native_environment.define(name, callable);
        }

        create_function("__haydens_door_broken", function() {
            with obj_door {
                if sprite_index == spr_beach_barn_door_spring_closed {
                    y -= 2;
                    sprite_index = spr_haydensfarm_barn_door_broken_spring;
                }
            }
        })

        create_function("__haydens_door_fixed", function() {
            with obj_door {
                if sprite_index == spr_haydensfarm_barn_door_broken_spring {
                    y += 2;
                    sprite_index = spr_beach_barn_door_spring_closed;
                }
            }
        });

        create_function("checkpoint", function(checkpoint) {
            if MIST.runtime.checkpoint_target == checkpoint {
                MIST.runtime.end_simulation();
            }
        })

        create_function("__get_from_blackboard", function(name) {
            return MIST.get_from_runtime_blackboard(name);
        });

        create_function("__set_on_blackboard", function(name, value) {
            MIST.place_on_runtime_blackboard(name, value);
        });

        create_function("take_from_blackboard", function(name) {
            return MIST.blackboard.take(name);
        })

        create_function("try_take_from_blackboard", function(name) {
            return MIST.blackboard.try_take(name);
        })

        create_function("__get_from_npc_blackboard", function(name) {
            return MIST.npcs.get(string_to_npc_id(npc)).blackboard.get(name);
        });

        create_function("__set_on_npc_blackboard", function(npc, name, value) {
            MIST.npcs.get(string_to_npc_id(npc)).blackboard.set(name, value);
        });

        create_function("eat_item", function(npc) {
            MIST.npcs.get(string_to_npc_id(npc)).set_animation("eat");
        });

        create_function("pantomime_eating", function(npc) {
            var obj = actor_name_to_object(npc);
            MIST.npcs.get(string_to_npc_id(npc)).set_animation("eat");
            obj.clean_eat_and_drink();
            obj.animator.set_index(0);
        })

        create_function("__print", function(_msg) {
            trace("mist print: {}", _msg);
        });

        create_function("__assert", function(v, e) {
            assert(v, "MIST assert: {}", e);
        });

        create_function("__alert", function(_msg) {
            show_message(_msg);
        });

        create_function("__error", function(_msg) {
            crash(_msg);
        });

        create_function("__label", function(_name) {
            if _name == self.simulation_label {
                self.end_simulation();
            }
        });

        create_function("__get_localization_value", function(_key) {
            return local_get(string(_key));
        });

        create_function("__destroy_prop", function(_prop) {
            instance_destroy(_prop);
        });

        create_function("__next_line", function() {
            var driver = self.blackboard.get("driver");
            if MIST.runtime.is_simulating() {
                if driver.next_line_behavior != undefined && driver.next_line_behavior.type == NextLineBehaviorId.Prompts {
                    driver.prompt_index_selected = MIST.runtime.simulated_prompt_index;
                    T2R.conversation_select_prompt(driver.prompt_index_selected);
                }
                driver.advance_t2();
                return;
            }
            driver.proceed_conversation();
            var index = MIST.blackboard.try_take("make_next_prompt_pink");
            if index != undefined {
                var prompts = [driver.textbox.prompt_one, driver.textbox.prompt_two, driver.textbox.prompt_three];
                prompts[index].blackboard.set("pink", true);
            }

            if self.blackboard.get("textbox_is_raised") {
                driver.textbox.canvas.set_layer_recursive(AnchorLayer.AboveFader);
            }
            var target_alpha = self.blackboard.try_take("portrait_target_alpha");
            if target_alpha != undefined {
                driver.textbox.portrait_target_alpha = target_alpha;
            }
            driver.textbox.give_callback(
                function() {
                    self.blackboard.set("textbox_interacted", true);
                },
            );
        });

        create_function("__repeat_line", function() {
            var driver = self.blackboard.get("driver");
            driver.deliver_line(driver.current_line);
        })

        create_function("__get_selected_option_index", function() {
            var driver = self.blackboard.get("driver");
            return driver.prompt_index_selected;
        });

        create_function("__close_textbox", function() {
            var textbox = ANCHOR.get_menu(Menu.Textbox);
            if textbox != undefined {
                textbox.begin_close();
            }
        });

        create_function("__textbox_is_in", function() {
            var textbox = ANCHOR.get_menu(Menu.Textbox);
            return textbox != undefined && textbox.in_translation == false;
        });

        create_function("__textbox_is_open", function() {
            var textbox = ANCHOR.get_menu(Menu.Textbox);
            return textbox != undefined;
        });

        create_function("set_conversation", function(convo) {
            var driver = self.blackboard.get("driver");
            if driver != undefined {
                driver.finish_conversation();
            }
            self.blackboard.set("driver", new ConversationDriver(NpcId.Adeline, convo));
        });

        create_function("get_small_animal_tier", function() {
            var idx = ARI.quest_artifacts.get("festival_selected_small_animal");
            var animal = opt_and_then(idx, function(idx) {
                return find_animal(idx, true);
            });
            if animal != undefined {
                var animal_score = animal_festival_score(animal.tier(), points_to_animal_heart_level(animal.heart_points));
                return score_to_tier_reward_index(QUESTS.get("the_animal_festival").reward_list.first(), animal_score);
            } else {
                return 0;
            }
        })

        create_function("get_large_animal_tier", function() {
            var idx = ARI.quest_artifacts.get("festival_selected_large_animal");
            var animal = opt_and_then(idx, function(idx) {
                return find_animal(idx, true);
            });
            if animal != undefined {
                var animal_score = animal_festival_score(animal.tier(), points_to_animal_heart_level(animal.heart_points));
                return score_to_tier_reward_index(QUESTS.get("the_animal_festival").reward_list.first(), animal_score);
            } else {
                return 0;
            }
        })

        create_function("__set_rumble", function(rumble_name) {
            set_rumble(string_to_rumble_kind(rumble_name));
        });

        function actor_name_to_object(_name) {
            if (_name == "Ari" || _name == "ari") {
                return obj_ari;
            } else if _name == "pet" || _name == "Pet" {
                return obj_pet;
            } else if _name == "void_ari" {
                return obj_void_ari;
            } else if !is_string(_name) && instance_exists(_name) && _name.object_index == obj_cutscene_animal {
                return _name;
            } else if try_string_to_npc_id(_name) != undefined {
                return npc_id_to_gm_obj_id(string_to_npc_id(_name));
            } else {
                return cameo_id_to_gm_obj_id(string_to_cameo_id(_name));
            }
        }

        create_function("__face", function(_actor, _direction) {
            if _actor == "ari" {
                if !instance_exists(obj_ari) {
                    //
                    //
                    return;
                }
                obj_ari.fsm.watch_target = undefined;
                switch _direction {
                    case "north":
                        obj_ari.face_dir(Cardinal.North * 90);
                        break;
                    case "south":
                        obj_ari.face_dir(Cardinal.South * 90);
                        break;
                    case "west":
                        obj_ari.face_dir(Cardinal.West * 90);
                        break;
                    case "east":
                        obj_ari.face_dir(Cardinal.East * 90);
                        break;
                }
            } else if _actor == "pet" {
                PET.set_cardinality(string_to_cardinal(_direction));
            } else if _actor == "void_ari" {
                obj_void_ari.par.set_cardinal(string_to_cardinal(_direction));
            } else {
                var _obj = actor_name_to_object(_actor);
                if !instance_exists(_obj) {
                    //
                    //
                    return;
                }
                _obj.fsm.watch_target = undefined;
                _obj.me.set_cardinality(string_to_cardinal(_direction));
            }
        });

        create_function("__get_actor_dir", function(actor) {
            if actor == "ari" {
                return cardinal_to_string(obj_ari.cardinal);
            } else if actor == "void_ari" {
                return cardinal_to_string(obj_void_ari.cardinal);
            } else {
                return cardinal_to_string(MIST.npcs.get(string_to_npc_id(actor)).cardinality);
            }
        });

        create_function("__textbox_interacted", function() {
            return self.blackboard.try_take("textbox_interacted", false);
        });

        create_function("__fuck_up_aris_house", function() {
            with obj_node_renderer {
                if matches(self.node.object_id, ObjectId.WornFireplace, ObjectId.WornWindow) {
                    continue;
                }
                instance_destroy();
            }
        });

        create_function("__override_post_process_time", function(h, m) {
            var cutscene_data = CUTSCENES.get(MIST.active_cutscene.id);
            assert(cutscene_data.post_process_time_override_reset);
            var new_time = hours(real(h)) + minutes(real(m));
            POST_PROCESS_TIME_OVERRIDE = new_time;
        });

        create_function("__reset_post_process_time", function() {
            var cutscene_data = CUTSCENES.get(MIST.active_cutscene.id);
            assert(cutscene_data.post_process_time_override_reset);
            POST_PROCESS_TIME_OVERRIDE = undefined;
        });

        create_function("__textbox_is_ready", function() {
            var textbox = ANCHOR.get_menu(Menu.Textbox);
            return textbox.state == TextboxState.Ready;
        });

        create_function("set_weather", function(weather) {
            WEATHER.set_weather(string_to_weather(weather));
            MIST.blackboard.set("weather_modified", true);
        })

        create_function("reset_weather", function() {
            WEATHER.set_weather(WEATHER.forecast[CALENDAR.day()]);
            MIST.blackboard.set("weather_modified", false);
        })

        create_function("__move", function(_actor, _x, _y) {
            var position = mist_position_input(_x, _y);
            var _obj = actor_name_to_object(_actor);
            var current_location = gm_room_to_location_id(room());
            var itinerary = PATHFINDING.calculate_map_path(
                new LocationPosition(current_location, Vec2(_obj.x, _obj.y)),
                new LocationPosition(current_location, Vec2(position.x, position.y)),
            );

            //
            if itinerary.items.is_empty() {
                //
                if _obj == obj_ari {
                    _obj.par_anim_spd = obj_ari.default_par_anim_spd;
                    _obj.par.set_base_loop();
                }

                return;
            }
            if _obj == obj_ari || _obj == obj_pet || _obj == obj_void_ari {
                //
                var result = PATHFINDING.calculate_local_path(
                    _obj.x,
                    _obj.y,
                    position.x,
                    position.y,
                );
                assert_neq(result, undefined, "we could not pathfind because: {}", PATHFINDING.last_error);
                var itinerary_current_item = itinerary.current_item();
                itinerary_current_item.local_path = result.output_list;
                itinerary_current_item.local_path_distance = result.distance;

                if _obj == obj_void_ari {
                    _obj.start_pathfind(itinerary);
                } else {
                    _obj.fsm.blackboard.set("itinerary", itinerary);

                    if _obj == obj_ari {
                        _obj.par_anim_spd = obj_ari.default_par_anim_spd;
                        _obj.par.set_base_loop();
                        _obj.fsm.change_state(PlayerState.Pathfind);
                    } else {
                        obj_pet.fsm.change_state(PetState.Pathfinding);
                    }
                }
            } else {
                _obj.me.simulated_distance_traveled = 0;
                _obj.me.itinerary = itinerary;
                _obj.fsm.change_state(NpcState.Pathfinding);
            }
        });

        create_function("__set_actor_speed", function(_actor, _speed) {
            var _obj = actor_name_to_object(_actor);
            if !is_real(_speed) {
                _speed = fiddle_get(format("misc/movement_speeds/{}", _speed));
            }
            //
            if _actor == "ari" {
                _obj.fsm.blackboard.set("move_accel", Vec2(_speed, _speed));
            } else if _actor == "pet" {
                PET.cutscene_speed.x = _speed;
                PET.cutscene_speed.y = _speed;
            } else {
                _obj.image_speed = _speed;
                _obj.move_accel.x = _speed;
                _obj.move_accel.y = _speed;
            }
        });

        create_function("__move_instant", function(_actor, _x, _y) {
            var position = mist_position_input(_x, _y);
            var obj = actor_name_to_object(_actor);
            obj.x = position.x;
            obj.y = position.y;
            if _actor == "ari" || _actor == "void_ari" {
                //
                obj.z = 0;
                obj.depth = get_instance_depth(obj.y);
            } else if _actor == "pet" {
                obj.depth = get_instance_depth(obj.y);
            } else if _actor == "obj_void_ari" {
                obj.depth = get_instance_depth(obj.y);
            } else {
                obj.y -= 1; //
                obj.me.location_position.pos.x = obj.x;
                obj.me.location_position.pos.y = obj.y;
            }
        });

        create_function("__animate", function(actor, animation_name) {
            var obj = actor_name_to_object(actor);
            if actor == "ari" || actor == "void_ari" {
                obj.par.set_base_loop();
                obj.par.held_sprite = undefined;
                obj.par_anim_spd = obj.default_par_anim_spd;
                obj.par.remove_attachment();
                obj.par.unset_all_modifiers();

                var anim_name = string_to_animation_name(animation_name);
                if actor == "ari" {
                    obj.set_animation(anim_name, SetAnimationOverride.OverrideAnyway);
                } else {
                    obj.par.set_animation(anim_name);
                }
            } else if obj.object_index == obj_cutscene_animal {
                obj.fsm.blackboard.set("animation", animation_name);
                obj.fsm.change_state(CutsceneAnimalState.Animate);
            } else if obj.object_index == obj_pet {
                //
            } else {
                obj.me.set_animation(animation_name);
            }
        });
        create_function("set_post_process", function(process_name) {
            POST_PROCESS = new PostProcessor(POST_PROCESS_DATABASE[$ process_name]);
        });
        create_function("reset_post_process", function() {
            POST_PROCESS = post_process_by_location();
        });
        create_function("create_animation", function(animation, x, y=0, offset_x=0, offset_y=0, offset_z=0) {
            var pos = mist_position_input(x,y);
            var sprite = string_to_asset(animation);
            create_animation_effect(pos.x + offset_x,pos.y + offset_y, offset_z, sprite);
        })
        create_function("__await_ari_animation", function() {
            return obj_ari.par.animation_complete;
        });

        create_function("__await_ari_cutscene_state", function() {
            return obj_ari.fsm.current_state_id() == PlayerState.Cutscene;
        });

        create_function("__ari_set_attachment", function(item) {
            obj_ari.par.set_attachment(item);
        });

        create_function("__freeze_ari", function() {
            obj_ari.par_anim_spd = 0;
        });

        create_function("freeze_void_ari", function() {
            obj_void_ari.par_anim_spd = 0;
        });

        create_function("__unfreeze_ari", function() {
            obj_ari.par_anim_spd = obj_ari.default_par_anim_spd;
        });

        create_function("unfreeze_void_ari", function() {
            obj_void_ari.par_anim_spd = obj_void_ari.default_par_anim_spd;
        });

        create_function("__freeze_ari_on_last_frame", function() {
            obj_ari.par.set_base_hold_on_last_frame();
        });

        create_function("freeze_void_ari_on_last_frame", function() {
            obj_void_ari.par.set_base_hold_on_last_frame();
        });

        create_function("__set_ari_to_idle", function() {
            obj_ari.fsm.change_state(PlayerState.Cutscene);
        })

        create_function("__await_npc_animation", function(npc) {
            npc = npc_id_to_gm_obj_id(string_to_npc_id(npc));
            return npc.animator.next_tick_values(npc.anim_speed).completed;
        })

        create_function("set_shadow_enabled", function(npc, boo) {
            shadow_caster_set_alpha(npc_id_to_gm_obj_id(string_to_npc_id(npc)).shadow_caster, boo);
        })

        create_function("__use_item", function(item, xx, yy) {
            var o = obj_ari.cell_select.clone();

            if xx != -1 && yy != -1 {
                o = Vec2(xx, yy);
            }
            use_item_fast(handle_item_input(item), o);
            obj_ari.fsm.blackboard.set("end_state", PlayerState.Cutscene);
        });

        create_function("__pick_node", function(item, xx, yy) {
            var doppel = new TangoDoppel();
            pick_node(GRID, xx, yy, ITEM_PROTOTYPES[string_to_item_id(item)], 0, undefined, doppel);
            doppel.resolve();
        });

        create_function("__chop_node", function(item, xx, yy) {
            var doppel = new TangoDoppel();
            chop_node(GRID, xx, yy, ITEM_PROTOTYPES[string_to_item_id(item)], 0, doppel);
            doppel.resolve();
        });

        create_function("__water_node", function(xx, yy) {
            water_node(GRID, xx, yy);
        });

        create_function("__shovel_node", function(prop_name) {
            var trellis_point_key = format("{LocationId}/{}", CURRENT_LOCATION_ID, prop_name);
            var coordinates = trellis_point(trellis_point_key);
            var doppel = new TangoDoppel();
            shovel_node(GRID, coordinates.x div 8 , coordinates.y div 8, doppel)
        });

        //
        //
        create_function("__erase_node", function(xx, yy) {
            erase_object_node(GRID, GRID.node_index_for_cell(xx, yy));
        });

        create_function("__set_ari_health", function(value) {
            var current = ARI.get_health();
            if value < current {
                obj_ari.fsm.change_state(PlayerState.Hurt);
                obj_ari.fsm.blackboard.set("end_state", PlayerState.Cutscene);
            }
            ARI.set_health(value);
        });

        create_function("__get_ari_health", function() {
            return ARI.get_health();
        });

        create_function("__get_ari_max_health", function() {
            return ARI.get_max_health();
        });

        create_function("__set_ari_stamina", function(value) {
            return ARI.set_stamina(value);
        });

        create_function("__get_ari_stamina", function() {
            return ARI.get_stamina();
        });

        create_function("__get_ari_max_stamina", function() {
            return ARI.get_max_stamina();
        });

        create_function("__set_ari_health_direct", function(value) {
            ARI.set_health(value);
        });

        create_function("__set_ari_stamina_direct", function(value) {
            ARI.set_stamina(value);
        });

        create_function("__ari_hold_item", function(item_str, offset_x, offset_y) {
            if item_str == undefined {
                obj_ari.par.held_sprite = undefined;
                return;
            }
            var item = handle_item_input(item_str);
            ARI.held_item_last_frame = item;
            obj_ari.par.set_held_sprite(item.get_ui_icon(), 0, offset_x, offset_y, offset_x);
        });

        create_function("__void_ari_hold_item", function(item_str, offset_x, offset_y) {
            if item_str == undefined {
                obj_void_ari.par.held_sprite = undefined;
                return;
            }
            var item = handle_item_input(item_str);
            obj_void_ari.par.set_held_sprite(item.get_ui_icon(), 0, offset_x, offset_y, offset_x);
        });

        create_function("ari_identify_item", function(item_str, offset_x, offset_y) {
            if item_str == undefined {
                obj_ari.par.held_sprite = undefined;
                return;
            }
            var item = handle_item_input(item_str);
            obj_ari.par.set_held_sprite(item.get_ui_icon(), 0, offset_x, offset_y, offset_x);
        });

        create_function("__ari_hold_sprite", function(sprite_name, offset_x, offset_y) {
            if sprite_name == undefined {
                obj_ari.par.held_sprite = undefined;
                return;
            }
            var sprite = string_to_asset(sprite_name);
            var item = new LiveItem(ItemId.MistHeldItem);
            item.icon_override = sprite;
            ARI.held_item_last_frame = item;
            obj_ari.par.set_held_sprite(item.get_ui_icon(), 0, offset_x, offset_y, offset_x);
        });

        create_function("__prepare_room", function() {
            //
            with par_NPC {
                instance_destroy();
            }

            //
            with obj_bug {
                self.cutscene_started();
            }

            //
            with obj_bird {
                self.shadow_sprite_backup = self.shadow_caster[ShadowCasterField.SpriteIndex];
                self.shadow_sprite_index_backup = self.shadow_caster[ShadowCasterField.ImageIndex];
                shadow_caster_set_sprite(self.shadow_caster, spr_nothing);
                self.visible = false;
            }
            instance_deactivate_object(obj_bird);

            with obj_fish_school {
                self.visible = false;
            }
            with obj_fishy {
                self.visible = false;
            }
            with obj_divespot {
                self.visible = false;
            }
            instance_deactivate_object(obj_fish_school);
            instance_deactivate_object(obj_fishy);
            instance_deactivate_object(obj_divespot);
        });

        create_function("setup_prop", function(prop_name) {
            PROPS.spawn_prop(prop_name);
        });

        create_function("destroy_prop", function(prop_name) {
            var success = PROPS.despawn_prop(prop_name, CURRENT_LOCATION_ID);
            assert(success, "we couldn't destroy the prop `{}`", prop_name);
        });

        create_function("info_toast", function(label) {
            create_notification(label);
        });

        create_function("__actor_is_present", function(_actor) {
            return instance_exists(actor_name_to_object(_actor));
        });

        create_function("__actor_spawn", function(_actor, _x, _y) {
            var actor_obj = actor_name_to_object(_actor);
            var position = mist_position_input(_x, _y);

            if actor_obj == obj_ari {
                instance_create_layer(0, 0, "Instances", obj_ari);
                obj_ari.initialize_for_cutscene();
            } else if actor_obj == obj_pet {
                spawn_pet(PetInitialization.Cutscene);
                obj_pet.x = position.x;
                obj_pet.y = position.y;
            } else if actor_obj == obj_void_ari {
                instance_create_layer(position.x, position.y, "Instances", obj_void_ari);
            } else {
                var inst = instance_create_depth(position.x, position.y, 0, actor_obj);
                var cameo_id = try_string_to_cameo_id(_actor);
                var me = cameo_id != undefined
                    ? MIST.cameos.get(string_to_cameo_id(_actor))
                    : MIST.npcs.get(actor_obj.npc_id);

                me.location_position = new LocationPosition(gm_room_to_location_id(room()), Vec2(position.x, position.y));
                inst.initialize(me);
            }
        });

        create_function("__mark_actor_as_met", function(actor) {
            var npc = try_string_to_npc_id(actor);
            if npc == undefined {
                return;
            }
            NPCS[npc].set_has_met();
        });

        create_function("__actor_is_moving", function(_actor) {
            var state;
            switch _actor {
                case "ari":
                    state = PlayerState.Pathfind;
                    break;
                case "pet":
                    state = PetState.Pathfinding;
                    break;
                case "void_ari":
                    return obj_void_ari.itinerary != undefined;
                default:
                    state = NpcState.Pathfinding;
            }
            with actor_name_to_object(_actor) {
                return self.fsm.check_state_inclusive(state);
            }
            return false;
        });

        create_function("__set_outfit", function(_actor, _outfit) {
            MIST.npcs.get(string_to_npc_id(_actor)).wardrobe.set_outfit(_outfit);
        });

        create_function("reset_outfit", function(_actor) {
            var npc = MIST.npcs.get(string_to_npc_id(_actor));
            npc.wardrobe.set_outfit(npc.prototype.get_suitable_outfit_key(npc.wardrobe, CALENDAR.time));
        });

        create_function("__bark", function(_actor, _bark_name, is_speech=false) {
            var obj = actor_name_to_object(_actor);
            if !instance_exists(obj) {
                //
                //
                return;
            }
            obj.bark_emitter.emit(string_to_bark_id(_bark_name), is_speech ? BarkType.Speech : BarkType.Thought);
        });

        create_function("__actor_is_barking", function(_actor) {
            var obj = actor_name_to_object(_actor);
            if !instance_exists(obj) {
                //
                //
                return;
            }
            return obj.bark_emitter.is_barking();
        });

        create_function("offset_actor_barks", function(actor, v) {
            with actor_name_to_object(actor) {
                self.bark_emitter.y_offset += v;
            }
        })

        create_function("__chat", function(npc_a, npc_b) {
            if try_string_to_cameo_id(npc_a) != undefined || try_string_to_cameo_id(npc_b) != undefined {
                return; //
            }
            actor_name_to_object(npc_a).chat_with(string_to_npc_id(npc_b));
        });

        create_function("__stop_chat", function(npc) {
            var obj = actor_name_to_object(npc);
            obj.chat_partner = undefined;
            obj.chat_timer = undefined;
        });

        create_function("__watch_actor", function(_actor, _target) {
            actor_name_to_object(_actor)
                .fsm
                .blackboard
                .set("watch_target", actor_name_to_object(_target))
        });

        create_function("__remove_actor", function(_actor) {
            instance_destroy(actor_name_to_object(_actor));
        });

        create_function("__actor_name_to_object", function(_name) {
            return actor_name_to_object(_name);
        });

        create_function("get_position_x", function(pos) {
            return mist_position_input(pos).x;
        });


        create_function("get_position_y", function(pos) {
            return mist_position_input(pos).y;
        });

        create_function("__fade_in", function(_seconds) {
            SCREEN_FADER.fade_in(round(_seconds * 60));
        });

        create_function("__fade_out", function(_seconds) {
            SCREEN_FADER.fade_out(round(_seconds * 60));
        });

        create_function("__camera_set_in", function() {
            SCREEN_FADER.snap_in();
        });

        create_function("__camera_set_out", function() {
            SCREEN_FADER.snap_out();
        });

        create_function("__camera_is_fading", function() {
            return SCREEN_FADER.active_fade != undefined;
        });

        create_function("__get_new_day_location_id", function() {
            return location_id_to_string(player_wake_position().location_id);
        })

        create_function("__get_new_day_spawn_x", function() {
            return player_wake_position().pos.x;
        })

        create_function("__get_new_day_spawn_y", function() {
            return player_wake_position().pos.y;
        })

        create_function("spouse_wake_x", function() {
            return spouse_wake_position().pos.x;
        })

        create_function("spouse_wake_y", function() {
            return spouse_wake_position().pos.y;
        })

        create_function("spouse", function() {
            return npc_id_to_string(ARI.spouse());
        })

        create_function("__pan_camera", function(_seconds, _x, _y, _ease) {
            _ease = string_to_ease_id(_ease);
            var position = mist_position_input(_x, _y);
            CAMERA.pan(
                position.x,
                position.y,
                _seconds * 60,
                _ease,
            );
        });

        create_function("__camera_position", function(_x, _y) {
            var position = mist_position_input(_x, _y);
            CAMERA.follow_point_instant(position.x, position.y);
        });

        create_function("get_camera_x", function() {
            return CAMERA.cam_pos.x + CAMERA.view_width / 2;
        })

        create_function("get_camera_y", function() {
            return CAMERA.cam_pos.y + CAMERA.view_height / 2;
        })

        create_function("__camera_follow", function(actor, instant) {
            actor = actor_name_to_object(actor);
            if instant {
                CAMERA.follow_instance_instant(actor);
            } else {
                CAMERA.follow_instance(actor)
            }
        });

        create_function("__camera_is_panning", function() {
            return CAMERA.get_state() == CameraTarget.Pan;
        });

        create_function("__goto", function(_location_name) {
            //
            var location = string_to_location_id(string_lower(_location_name));
            if is_dungeon_room(LOCATIONS[location].gm_room) && !is_dungeon_room(room()) {
                var itinerary = create_dungeon_itinerary();
                DUNGEON_RUNNER = new DungeonRunner(itinerary, 0);
            }
            assert_neq(
                TAXI.current_location_id(),
                location,
                "We tried to move to location {}, but we were already there. whaddup with that",
                _location_name
            );

            //
            for (var i = 0; i < NpcId.LEN; i++) {
                var npc = MIST.npcs.get(i);
                npc.itinerary = undefined;
            }

            goto_location_id(location, true);
        });

        create_function("__game_is_traveling", function() {
            return TAXI.is_traveling();
        });

        create_function("__get_location_name", function() {
            return location_id_to_string(TAXI.current_location_id());
        });

        create_function("__set_lighting_time", function(time) {
            POST_PROCESS.update(time);
        });

        create_function("__get_time", function() {
            return CLOCK.time;
        });

        create_function("__clock_jump", function(target_time) {
            return CLOCK.jump(target_time);
        });

        create_function("__toggle_layer_visibility", function(b) {
            strict_layer_set_visible(layer_get_id(name), b);
        });

        create_function("__open_menu", function(name) {
            switch name {
                case "forging":
                    spawn_crafting_menu(BLACKSMITHING_UI_DATA);
                    break;
                case "cooking":
                    var menu = spawn_crafting_menu(COOKING_UI_DATA);
                        menu.object_coordinates.x = obj_ari.x;
                        menu.object_coordinates.y = obj_ari.y;
                    break;
                case "forging_sequence":
                    var menu = ANCHOR.spawn_menu(Menu.CraftingSequence);
                    menu.setup(RecipeContext.Blacksmithing);
                    break;
                case "cooking_sequence":
                    var menu = ANCHOR.spawn_menu(Menu.CraftingSequence);
                    menu.setup(RecipeContext.Cooking);
                    break;
                case "inbox":
                    var menu = ANCHOR.spawn_menu(Menu.Inbox);
                    menu.display_letter(0);
                    break;
                case "customization":
                    var preset = ARI.presets.get(ARI.preset_index_selected).clone();
                    if !TEST_SUITE {
                        var menu = start_character_creation(preset, function() {}, false);
                        menu.continue_button.text_label.set_key("misc_local/continue");
                        menu.continue_button.set_tap_callback(function(menu) {
                            var popup = popup_creator("misc_local/confirm", "misc_local/wedding_outfit_confirmation");
                            popup.create_button("misc_local/no", function(menu) {
                                menu.unlock();
                            }, [menu]);
                            popup.create_button("misc_local/yes", function(menu) {
                                menu.close();
                                ANCHOR.free_node(menu.continue_button);
                            }, [menu]);
                            popup.spawn();
                        }, [menu], true)
                    }
                    self.blackboard.insert("wedding_outfit", preset);
                    break;
                case "request_board":
                    var menu = spawn_request_board_menu();
                    menu.journal.listen_for_exit_flag = false;
                    menu.close_on_accept = true;
                    break;
                default:
                    ANCHOR.spawn_menu(string_to_menu(name));
                    break;
            }
        });

        create_function("__hide_menu", function(name, instant) {
            ANCHOR.get_menu(string_to_menu(name)).request_hide(instant ? 0 : undefined);
        });

        create_function("__show_menu", function(name, instant) {
            ANCHOR.get_menu(string_to_menu(name)).request_show(instant);
        });

        create_function("__close_menu", function(name) {
            switch name {
                case "request_board":
                    name = "baby_journal";
                    break;
                default: break;
            }
            var menu = ANCHOR.get_menu(string_to_menu(name));
            if menu != undefined {
                menu.close();
            }
        });

        create_function("__menu_exists", function(name) {
            switch name {
                case "forging":
                case "cooking":
                    return ANCHOR.get_menu(Menu.Crafting) != undefined;
                case "cooking_sequence":
                case "forging_sequence":
                    return ANCHOR.get_menu(Menu.CraftingSequence) != undefined;
                case "request_board":
                    return ANCHOR.get_menu(Menu.QuestLog) != undefined;
                case "customization": return ANCHOR.get_menu(Menu.Customization) != undefined;
                default:
                    return ANCHOR.get_menu(string_to_menu(name)) != undefined;
            }
        });

        create_function("__show_caldarus_statue", function() {
            var menu = ANCHOR.spawn_menu(Menu.CaldarusStatueOverlay);
            menu.in();
        });

        create_function("__hide_caldarus_statue", function() {
            var menu = ANCHOR.get_menu(Menu.CaldarusStatueOverlay);
            menu.out();
        });

        //
        create_function("__raise_textbox", function() {
            var menu = ANCHOR.get_menu(Menu.Textbox);
            if menu != undefined {
                menu.canvas.set_layer_recursive(AnchorLayer.AboveFader);
            }
            self.blackboard.set("textbox_is_raised", true);
        });

        create_function("__lower_textbox", function() {
            var menu = ANCHOR.get_menu(Menu.Textbox);
            if menu != undefined {
                menu.canvas.set_layer_recursive(AnchorLayer.Standard);
            }
            self.blackboard.set("textbox_is_raised", false);
        });

        create_function("__music_is_playing", function() {
            return MUSIC_PLAYER.is_on();
        });

        create_function("__request_music_stop", function(secs=-1) {
            if !MUSIC_PLAYER.is_on() {
                return;
            }

            MIST.blackboard.set("requested_music", undefined);
            MIST.blackboard.set("halt_music", true);
            secs = secs == -1 ? undefined : secs * 60;
            MUSIC_PLAYER.stop(secs);
        });

        create_function("__force_music_stop", function() {
            MIST.blackboard.set("requested_music", undefined);
            MIST.blackboard.set("halt_music", true);
            MUSIC_PLAYER.refresh();
            MUSIC_PLAYER.stop(0);
        });

        create_function("__request_music_play", function(track) {
            var npc = try_string_to_npc_id(track);
            track = npc == undefined ? track : NPC_PROTOTYPES[npc].music;
            MIST.blackboard.set("requested_music", track);
            MIST.blackboard.set("halt_music", false);
            MUSIC_PLAYER.refresh();
        });

        create_function("__play_item_toast", function(item, count=1) {
            item = handle_item_input(item);
            TANGO.play("SoundEffects/Inventory/ItemPickup");
            ANCHOR.get_menu(Menu.ItemToasts).create_pickup(item, count);
        });

        create_function("drop_item", function() {
            var cutscene_data = CUTSCENES.get(MIST.active_cutscene.id);
            var spawned = false;
            for (var i = 0, c = array_length(cutscene_data.drop_items); i < c; i++) {
                var item = cutscene_data.drop_items[i];
                var id_available = true;
                with obj_item {
                    if self.mist_id == item.mist_id {
                        id_available = false;
                        break;
                    }
                }
                if id_available {
                    var items = drop_item_stack(item.location.pos.x, item.location.pos.y, List(new LiveItem(item.item_id)));
                    items.mist_id = item.mist_id;
                    spawned = true;
                    break;
                }
            }

            assert(spawned, "Couldn't find item {ItemId}, did you add enough of the item for it to spawn multiple times?  Cutscene was: {}", item.item_id, MIST.active_cutscene.id);
        })
        create_function("write_world_fact",function(fact, value) {
            T2R.write(fact, value);
        });
        create_function("read_world_fact",function(fact) {
            var f = T2R.read(fact);
            return f == undefined ? "undefined" : f;
        });
        create_function("request_activity", function(_npc,activity) {
            var npc = MIST.npcs.get(string_to_npc_id(_npc));
            npc.activity_handler.request_activity(string_to_activity(activity));
        })
        create_function("request_routine", function(_npc,routine) {
            var npc = MIST.npcs.get(string_to_npc_id(_npc));
            npc.activity_handler.routine = ROUTINES.get(string_to_routine(routine));
        })
        create_function("anim_speed", function(_npc,_speed) {
            var npc = actor_name_to_object(_npc);
            npc.anim_speed = _speed;
        });
        create_function("__play_sound", function(track, xx, yy) {
            var pos = mist_position_input(xx, yy);
            MIST.sound_requests.push(TANGO.play(track, pos.x, pos.y));
        });
        create_function("__play_sound_free", function(track, xx, yy) {
            var pos = mist_position_input(xx, yy);
            TANGO.play(track, pos.x, pos.y);
        });

        create_function("__get_element_x", function(element) {
            return  mist_position_input(element).x;
        });

        create_function("__get_element_y", function(element) {
            return  mist_position_input(element).y;
        });

        create_function("look_for_entry_transition", function(name) {
            var obj = npc_id_to_gm_obj_id(string_to_npc_id(name));
            obj.look_for_entry_transition();
        });

        create_function("__use_door", function(actor) {
            if actor == "ari" {
                crash("you think I added support for ari in this thing?");
            } else if actor == "pet" {
                obj_pet.pathfind_to_home_from_farm();
            } else {
                var obj = npc_id_to_gm_obj_id(string_to_npc_id(actor));
                with obj {
                    var nearest = instance_nearest(self.x, self.y, obj_door);
                    nearest.request_open();
                    var angle = point_direction(self.x, self.y, nearest.x, nearest.y);
                    self.me.set_cardinality(angle_to_cardinal(angle));
                    var wait_time = nearest.get_wait_time();
                    self.fsm.blackboard.set("dummy_exit_condition", DummyExitCondition.Timer(60));
                    self.fsm.blackboard.set("dummy_exit_callback", function() {
                        instance_destroy();
                    })
                    self.fsm.change_state_instant(NpcState.Dummy);
                    new_chain()
                        .join(LinkId.Timer, wait_time)
                        .append(LinkId.Function, function() {
                            if !instance_exists(self) {
                                return;
                            }
                            self.fsm.blackboard.set("start_dummy_walk", true);
                        });
                }
            }
        });

        create_function("__give_ari_status_effect", function(status) {
            var cutscene_data = CUTSCENES.get(MIST.active_cutscene.id);
            var impaired = false;
            for (var i = 0, c = array_length(cutscene_data.status_effects); i < c; i++) {
                var effect = cutscene_data.status_effects[i];
                if string_to_status_effect_id(status) == effect.status_effect {
                    ARI.status_effects.register(
                        effect.status_effect,
                        effect.amount,
                        CALENDAR.unified_time(),
                        CALENDAR.unified_time() + hours(effect.hours)
                    );
                    impaired = true;
                }
            }

            assert(impaired, "Effect {} not defined in {}'s cutscenes.toml", effect, MIST.active_cutscene.id);
        })

        create_function("__ari_jump", function(x_sign, y_sign) {
            obj_ari.check_jump(
                x_sign,
                y_sign,
                HUMAN_RUN_JUMP_DISTANCE,
            );
            obj_ari.fsm.change_state(PlayerState.Jump);
            obj_ari.fsm.blackboard.set("end_state", PlayerState.Cutscene);
        })

        create_function("quest_is_active", function(quest) {
            return QUEST_LOG.active.contains_key(quest);
        })

        create_function("current_season", function() {
            return season_to_string(CALENDAR.season());
        });

        create_function("building_change", function(name, state) {
            building_change_modifier(string_to_building(name), string_to_building_modifier(state));
        });

        create_function("fade_npc_alpha", function(npc, start, target, len) {
            if MIST.runtime.is_simulating() {
                //
                return;
            }

            var inst = actor_name_to_object(npc);
            fade_value(inst, "image_alpha", start, target, len);

            if inst == obj_ari {
                fade_value(inst.par, "alpha", start, target, len);
            }
        })

        create_function("fade_prop_alpha", function(prop, start, target, len) {
            var inst = PROPS.spawned.get(prop).inst;
            inst.image_alpha = start;
            new_chain().append(LinkId.Ease, new Ease(EaseId.Linear, start, target, len), function(_, a, inst) {
                if !instance_is_alive(inst) {
                    return;
                }
                inst.image_alpha = a;
            }, [inst])
        })

        create_function("set_portrait_target_alpha", function(alpha) {
            var menu = ANCHOR.get_menu(Menu.Textbox);
            if menu == undefined {
                self.blackboard.set("portrait_target_alpha", alpha);
            } else {
                menu.portrait_target_alpha = alpha;
            }
        })

        create_function("ari_owned_item_count", function(item) {
            return total_item_count(string_to_item_id(item));
        })

        create_function("__run_tutorial", function(tutorial) {
            spawn_tutorial(string_to_tutorial(tutorial));
        })

        create_function("__tutorial_complete", function() {
            return ANCHOR.get_menu(Menu.Popup) == undefined;
        })

        create_function("turn_on_windows", function(offset=0) {
            with obj_exterior_light {
                self.time_offset = offset;
                self.turn_on();
            }
            INTERIOR_WINDOW_TIME_OVERRIDE = hours(22);
        })

        create_function("drink_item", function(actor, drink) {
            var obj = actor_name_to_object(actor);
            obj.drink_override = drink;
            obj.me.set_animation("drink");
            obj.animator.set_index(0);
        })

        create_function("start_shooting_stars", function() {
            instance_create_layer(1120, 368, "Meta", obj_shooting_star_generator);
            instance_create_layer(1088, 336, "Meta", obj_shooting_star_generator);
            instance_create_layer(1152, 400, "Meta", obj_shooting_star_generator);
        })

        create_function("toggle_asset_visibility", function(asset_name) {
            toggle_asset_visibility(asset_name);
        });

        create_function("toggle_object_visibility", function(object_name) {
            if DEBUG_TOOLS {
                var cutscene_data = CUTSCENES.get(MIST.active_cutscene.id);
                var success = false;
                for (var i = 0, c = array_length(cutscene_data.invisible_objects); i < c; i++) {
                    if cutscene_data.invisible_objects[i] == object(object_name) {
                        success = true;
                        break;
                    }
                }
                assert(success, "object {} was not well defined in cutscene.toml", object_name);
            }
            with object(object_name) {
                visible = !visible;
            }
        });

        create_function("spawn_animal", function(kind, variant, sex, days_old, card, xx, yy) {
            var position = mist_position_input(xx, yy);
            var animal = new NonPlayerAnimal(
                string_to_animal_kind(kind),
                variant,
                string_to_sex(sex)
            );
            animal.days_old = days_old;
            animal.location_position = new LocationPosition(CURRENT_LOCATION_ID, position);
            animal.instance = instance_create_layer(
                animal.location_position.pos.x,
                animal.location_position.pos.y,
                "Instances",
                obj_cutscene_animal,
                {
                    me: animal,
                }
            );
            animal.set_cardinality(string_to_cardinal(card));
            return animal.instance;
        });

        create_function("mistmare_poof", function() {
            create_animation_effect(obj_cutscene_animal.x + irandom(8), obj_cutscene_animal.y - irandom_range(4, 16), -100000, spr_fx_poof1_essence_once);
            create_animation_effect(obj_cutscene_animal.x - irandom(8), obj_cutscene_animal.y - irandom_range(4, 16), -100000, spr_fx_poof1_essence_once);
            create_animation_effect(obj_cutscene_animal.x + irandom(8), obj_cutscene_animal.y - irandom_range(4, 16), -100000, spr_fx_poof1_essence_once);
            create_animation_effect(obj_cutscene_animal.x - irandom(8), obj_cutscene_animal.y - irandom_range(4, 16), -100000, spr_fx_poof1_essence_once);
        });

        create_function("stop_shooting_stars", function() {
            with obj_shooting_star_generator {
                instance_destroy();
            }
        })

        create_function("stop_ambiance", function() {
            self.blackboard.set("block_ambience", true);

            with obj_sound_emitter {
                if string_pos("Ambience", self.sound_asset) != 0 {
                    instance_destroy();
                }
            }
        })

        create_function("refresh_ambience", function() {
            AMBIENCE_PLAYER.refresh();
        })

        create_function("spawn_star", function(star) {
            static POSITIONS = [
                Vec2(1120, 368),
                Vec2(1088, 336),
                Vec2(1152, 400)
            ];
            var pos = POSITIONS[star];
            var inst = instance_create_layer(pos.x, pos.y, "Meta", obj_shooting_star_generator);
            inst.index = star;
        })

        create_function("stop_star", function(star) {
            with obj_shooting_star_generator {
                if self.index == star {
                    instance_destroy();
                }
            }
        });

        //
        //
        create_function("explode_furniture", function(xx0, yy0, xx1, yy1) {
            xx0 = xx0 div 8;
            xx1 = xx1 div 8;
            yy0 = yy0 div 8;
            yy1 = yy1 div 8;

            if DEBUG_ASSERTIONS {
                assert(xx0 < xx1);
                assert(yy0 < yy1);
            }

            for (var xx = xx0; xx < xx1; xx++) {
                for (var yy = yy0; yy < yy1; yy++) {
                    var ni = GRID.try_node_index_for_cell(xx, yy);
                    if ni != undefined && object_id_to_object_category(GRID.node_object_id[ni]) == ObjectCategory.Furniture {
                        var old_item = find_item_prototype(GRID.node_object_id[ni]);
                        if old_item != undefined {
                            var item = new LiveItem(old_item.item_id);
                            if item.infusion == undefined {
                                item.infusion = try_string_to_infusion(GRID.node_parent[ni].infusion);
                            }
                            GRID.lost_items.push({
                                x: GRID.node_parent[ni].renderer.x,
                                y: GRID.node_parent[ni].renderer.y,
                                items: List(item),
                            })
                        }
                        erase_object_node(GRID, ni);
                    }
                }
            }
        });

        //
        create_function("nuke_tut", function(xx0, yy0, xx1, yy1) {
            xx0 = xx0 div 8;
            xx1 = xx1 div 8;
            yy0 = yy0 div 8;
            yy1 = yy1 div 8;

            if DEBUG_ASSERTIONS {
                assert(xx0 < xx1);
                assert(yy0 < yy1);
            }

            for (var xx = xx0; xx < xx1; xx++) {
                for (var yy = yy0; yy < yy1; yy++) {
                    var ni = GRID.try_node_index_for_cell(xx, yy);
                    if ni != undefined
                        && GRID.node_object_id[ni] != ObjectId.TreePineSpecial
                        && object_id_to_object_category(GRID.node_object_id[ni]) != ObjectCategory.Grass
                    {
                        erase_object_node(GRID, ni);
                    }
                }
            }
        });

        create_function("start_pet_creation", function() {
            run_pet_acquiring_sequence();
        })

        create_function("create_ghost_pet", function() {
            //
            var node = ANCHOR.sprite(ANCHOR.screen_canvas, 0, AnchorLayer.AboveFader)
                .set_sprite(spr_cutscene_pet_silhouette)
                .set_align(Align.Center, Align.Middle)
                .set_y(-8)
                .set_alpha(0)

            node.set_think_callback(function(node) {
                if !MIST.is_running() {
                    ANCHOR.free_node(node);
                }
            }, [node])

            new_chain()
                .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 120), function(_, a, node) {
                    node.set_alpha(a);
                }, [node]);

            MIST.blackboard.set("pet_node", node);
        })

        create_function("update_pet_sprite", function() {
            var node = MIST.blackboard.get("pet_node");
            var sprites = PET.sprites_for_animation("idle", Cardinal.East);
            node.set_sprite(sprites.base_sprite);
            if sprites.lut != undefined {
                node.set_lut(sprites.lut, sprites.lut_index);
            }

            //
            var bark_position = {
                x: 0,
                y: 0,
                image_xscale: 1,
                image_yscale: 1,
            };
            var bark = ANCHOR.custom(node)
                .set_align(Align.Center, Align.TopOut)
                .set_xy(12, 0)

            bark.set_render_callback(method(bark, function() {
                self.bark_position.x = self.cache_x * DISPLAY.asset_resize();
                self.bark_position.y = self.cache_y * DISPLAY.asset_resize();
                self.bark_position.image_xscale = DISPLAY.asset_resize();
                self.bark_position.image_yscale = DISPLAY.asset_resize();
                self.emitter.on_draw();
            }));


            bark.emitter = new BarkEmitter(bark_position, 0, 0);
            bark.bark_position = bark_position;

            var spr = PET.sprites_for_animation("happy", Cardinal.East).base_sprite;
            new_chain()
                .append(LinkId.Timer, 60)
                .append(LinkId.Function, function(node, bark, spr) {
                    node.set_sprite(spr);
                    node.set_speed(0.5);
                    bark.emitter.emit(BarkId.Heart);
                }, [node, bark, spr])
        });

        create_function("destroy_pet_sprite", function() {
            var node = MIST.blackboard.get("pet_node");
            var node = new_chain()
                .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 120), function(_, a, node) {
                    node.set_alpha(a);
                }, [node])
                .append(LinkId.Function, function(node) {
                    ANCHOR.free_node(node);
                }, [node])
        })
        create_function("play_pet_positive_sound", function() {
            var xx = instance_exists(obj_pet)
                ? obj_pet.x
                : CAMERA.cam_pos.x + (CAMERA.view_width / 2);
            var yy = instance_exists(obj_pet)
                ? obj_pet.y
                : CAMERA.cam_pos.y + (CAMERA.view_height / 2);
            TANGO.play(PET.positive_react_tango_event_name(), xx, yy);
        })

        //
        create_function("__ari_breath_fire", function() {
            if ARI.status_effects.get_effect_value(StatusEffectId.FlameBreath) == undefined {
                cast_spell(Spell.FireBreath);
            }
            obj_ari.breathe_fire_in_other_states = true;
            ARI.fire_breath_time = 10000;
        });

        create_function("allow_ari_fire_breath", function() {
            obj_ari.breathe_fire_in_other_states = true;
        });

        //
        create_function("__end_ari_breath_fire", function() {
            ARI.fire_breath_time = 0;
            ARI.status_effects.cancel(StatusEffectId.FlameBreath);
        });

        //
        create_function("__start_destroying_vines", function() {
            with obj_eastern_road_thorny_steps {
                self.begin_destruction = true;
            }
        });

        //
        create_function("__finish_destroying_vines", function() {
            instance_destroy(obj_eastern_road_thorny_steps.interaction_trigger);
            obj_eastern_road_thorny_steps.interaction_trigger = undefined;
            obj_eastern_road_thorny_steps.update_collisions(false);
        });

        create_function("update_narrows_control", function() {
            with obj_narrows_control {
                self.update();
            }
        });

        //
        create_function("__start_destroying_secret_cave", function() {
            with obj_narrows_secret_build_mod_obj {
                self.begin_destruction = true;
            }
            with obj_beach_secret_build_mod_obj {
                self.begin_destruction = true;
            }
        });

        //
        create_function("__destroy_secret_cave", function() {
            CAMERA.add_trauma(0.7);

            var obj = instance_exists(obj_narrows_secret_build_mod_obj) ? obj_narrows_secret_build_mod_obj : obj_beach_secret_build_mod_obj;

            create_animation_effect(
                obj.x - 8,
                obj.y,
                obj.depth,
                spr_fx_poof1_dirt_once
            );

            create_animation_effect(
                obj.x + 8,
                obj.y,
                obj.depth,
                spr_fx_poof1_dirt_once
            );
        });

        create_function("__send_pet_to_home", function() {
            PET.location_id = pet_valid_house_location();

            if instance_exists(obj_pet) {
                instance_destroy(obj_pet);
            }
        });

        create_function("enable_simple_pathfinding", function() {
            PATHFINDING.enable_simple_pathfinding();
            with par_NPC {
                self.pathfinding_agent.meddler.release_reservations();
                self.pathfinding_agent.meddler = undefined;
                self.pathfinding_agent.should_reserve_squares = false;
            }
        });

        create_function("__harvest_festival_pathfind_finish", function() {
            PATHFINDING.initialize_local_grid();
            with par_NPC {
                self.pathfinding_agent.meddler = new PathfindingMeddler(PathfindingAgentKind.Npc, self);
                self.pathfinding_agent.should_reserve_squares = true;
            }
        });

        create_function("shake_camera", function(amount) {
            CAMERA.add_trauma(amount);
        });

        create_function("camera_is_shaking", function() {
            return CAMERA.trauma.x != 0 || CAMERA.trauma.y != 0;
        })

        create_function("get_trauma_max", function() {
            return max(CAMERA.trauma.x, CAMERA.trauma.y);
        })

        create_function("set_max_shake_offset", function(xx, yy) {
            MIST.blackboard.insert("modified_camera_max_offset", true);
            CAMERA.max_offset.x = xx;
            CAMERA.max_offset.y = yy;
        })

        create_function("reset_max_shake_offset", function() {
            CAMERA.max_offset = DEFAULT_CAMERA_MAX_OFFSET;
        })

        create_function("create_unique_renderer", function() {
            switch MIST.active_cutscene.id {
                case "break_fire_seal":
                    instance_create_depth(0, 0, FIRE_SEAL_BLACK_OVERLAY_DEPTH, obj_break_fire_seal_renderer);
                    break;
                case "break_ruins_seal_pt_1":
                case "break_ruins_seal_pt_3":
                    instance_create_depth(0, 0, FIRE_SEAL_BLACK_OVERLAY_DEPTH, obj_break_ruins_seal_renderer);
                    break;
                case "dragon_tablet_pt_3":
                case "dragon_tablet_pt_4":
                    instance_create_depth(0, 0, FIRE_SEAL_BLACK_OVERLAY_DEPTH, obj_dragon_tablet_renderer);
                    break;
                case "juniper_eight_hearts":
                    instance_create_depth(0, 0, FIRE_SEAL_BLACK_OVERLAY_DEPTH, obj_juniper_eight_hearts_renderer);
                    break;
                default: impossible();
            }
        });

        create_function("make_next_ari_walk_use_run", function() {
            obj_ari.fsm.blackboard.insert("use_run_animation", true);
        });

        create_function("cast_spell", function(hold_seconds, spell) {
            if spell == undefined {
                spell = CUTSCENE_SPELL_SIGNUM;
            } else {
                spell = string_to_spell(spell);
            }
            obj_ari.fsm.blackboard.set("spell", spell);
            obj_ari.fsm.blackboard.set("loop_timer", hold_seconds * 60);
            obj_ari.fsm.change_state(PlayerState.Spell);
            obj_ari.fsm.blackboard.set("end_state", PlayerState.Cutscene);
        })

        create_function("raise_actor", function(actor) {
            var obj = actor_name_to_object(actor);
            if actor == "ari" {
                obj_ari.fsm.current_state().set_depth = false;
                obj_ari.can_set_depth_in_pause = false;
                obj.depth = FIRE_SEAL_BLACK_OVERLAY_DEPTH - 1;
            } else {
                obj.z = FIRE_SEAL_BLACK_OVERLAY_DEPTH - 1;
            }
        });

        create_function("lower_actor", function(actor) {
            var obj = actor_name_to_object(actor);
            obj.z = 0;
            obj.depth = get_instance_depth(obj.y, obj.z);
        });

        create_function("close_ari_eyes", function() {
            obj_ari.par.set_animation(AnimationName.EyesClosed);
            MIST.blackboard.set("aris_eyes_are_closed", true);
        });

        create_function("open_ari_eyes", function() {
            var eyes = obj_ari.par.slots[AnimationSlot.Eyes];
            obj_ari.par.set_animation_on_slot(AnimationName.Idle, eyes.modifier);
            MIST.blackboard.remove("aris_eyes_are_closed");
        });

        create_function("make_next_prompt_pink", function(index) {
            var menu = ANCHOR.get_menu(Menu.Textbox);
            if menu == undefined {
                MIST.blackboard.insert("make_next_prompt_pink", index);
                return;
            }
            var prompts = [menu.prompt_one, menu.prompt_two, menu.prompt_three];
            prompts[index].blackboard.set("pink", true);
        })

        create_function("screen_flash", function() {
            if SETTINGS.get("screen_flash") != true {
                return;
            }
            var node = ANCHOR.nine_slice(ANCHOR.screen_canvas)
                .set_layer(AnchorLayer.ScreenFader)
                .set_size(ANCHOR.screen_canvas.get_size())
                .set_alpha(1)
                .set_sprite(spr_pixel_nine_slice)
            new_chain()
                .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 40), function(_, a, node) {
                    node.set_alpha(a);
                }, [node])
                .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 40), function(_, a, node) {
                    node.set_alpha(a);
                }, [node])
                .append(LinkId.Function, function(node) {
                    ANCHOR.free_node(node);
                }, [node])
        })

        create_function("random_date_bark", function() {
            var date = MIST.get_from_runtime_blackboard("date");
            var barks = DATES[date].random_barks;
            return bark_id_to_string(barks[irandom(array_length(barks) - 1)]);
        })

        create_function("capture_date_photo", function() {
            with par_NPC {
                self.visible = false;
                shadow_caster_set_alpha(self.shadow_caster, 0.0);
            }
            obj_ari.visible = false;
            shadow_caster_set_alpha(obj_ari.shadow_caster, 0.0);
            with obj_bug {
                self.cutscene_started();
            }
            var partner = undefined;
            var date = undefined;
            if MIST.active_cutscene.id == "wedding" {
                date = Date.Wedding;
                partner = ARI.fiance() ?? NpcId.Juniper;
            } else {
                partner = string_to_npc_id(MIST.get_from_runtime_blackboard("date_partner"));
                date = MIST.get_from_runtime_blackboard("date");
            }
            DATE_PHOTO_REQUEST = [partner, date];

            new_chain()
                .append(LinkId.Timer, 1)
                .append(LinkId.Function, function() {
                    with par_NPC {
                        self.visible = true;
                        shadow_caster_set_alpha(self.shadow_caster, 1.0);
                    }
                    obj_ari.visible = true;
                    shadow_caster_set_alpha(obj_ari.shadow_caster, 1.0);

                    with obj_bug {
                        self.cutscene_ended();
                    }
                }, [])
        })

        create_function("irandom", function(v) {
            return irandom(v);
        });

        create_function("random", function(v) {
            return random(v);
        });

        create_function("date_prop_edit", function(prop_name) {
            PROPS.spawned.get(prop_name).inst.sprite_index = MIST.blackboard.get("prop_sprite");
        })

        create_function("override_requirement", function(req) {
            MIST.requirement_overrides[string_to_requirement(req)] = true;
        })

        create_function("refresh_room_layers", function() {
            if DEBUG_ASSERTIONS {
                assert(
                    MIST.active_cutscene.refreshes_room_layers,
                    "Scene '{}' must be marked to refresh layers in cutscenes.toml!",
                    MIST.active_cutscene.id,
                );
            }
            setup_room();
        })

        create_function("trigger_scene_object_removals", function() {
            trigger_scene_object_removals(MIST.active_cutscene.id);
            MIST.blackboard.insert("removed_scene_objects", true);
        })

        create_function("turn_on_sparky_asset", function(index) {
            if index == 0 {
                obj_seal_tablet.sprite_index = spr_ruins_seal_tablet_cutscene_spring_start;
                TANGO.play("SoundEffects/SpecialEvents/RuinsPedestalTurnOnCenter", obj_seal_tablet.x, obj_seal_tablet.y);
            } else {
                var lol = List();
                with obj_seal_altar {
                    lol.push([self.id, self.x]);
                }
                lol.sort_with(function(a, b) {
                    return a[1] < b[1] ? -1 : 1;
                });
                var inst = lol.get(index - 1)[0];
                inst.sprite_index = spr_ruins_seal_altar_cutscene_spring_start;
                TANGO.play(format("SoundEffects/SpecialEvents/RuinsPedestalTurnOn{}", index));
            }
        })

        create_function("turn_off_sparky_asset", function(index) {
            if index == 0 {
                obj_seal_tablet.sprite_index = spr_ruins_seal_tablet_cutscene_spring_end;
            } else {
                var lol = List();
                with obj_seal_altar {
                    lol.push([self.id, self.x]);
                }
                lol.sort_with(function(a, b) {
                    return a[1] < b[1] ? -1 : 1;
                });
                lol.get(index - 1)[0].sprite_index = spr_ruins_seal_altar_cutscene_spring_end;
            }
        })

        create_function("add_item_to_altar", function(index) {
            var lol = List();
                with obj_seal_altar {
                    lol.push([self.id, self.x]);
                }
                lol.sort_with(function(a, b) {
                    return a[1] < b[1] ? -1 : 1;
                });
                lol.get(index - 1)[0].icon_override = true;
        })

        create_function("__setup_arena", function(action) {
            switch action {
                case "ladder":
                    obj_dungeon_ladder_down.set_state(LadderState.TrapdoorClosed);
                    TANGO.play("SoundEffects/Entrances/MineHatchClose", obj_dungeon_ladder_down.x, obj_dungeon_ladder_down.y);

                    create_animation_effect(
                        obj_dungeon_ladder_down.x - random(2),
                        obj_dungeon_ladder_down.y - random(2),
                        obj_dungeon_ladder_down.depth,
                        spr_fx_poof1_dirt_once
                    );

                    create_animation_effect(
                        obj_dungeon_ladder_down.x + random(2),
                        obj_dungeon_ladder_down.y - random(2),
                        obj_dungeon_ladder_down.depth,
                        spr_fx_poof1_dirt_once
                    );

                    break;
                case "ladder_open":
                    obj_dungeon_ladder_down.try_open();
                    TANGO.play("SoundEffects/Entrances/MineHatchOpen2D", obj_dungeon_ladder_down.x, obj_dungeon_ladder_down.y);
                    break;
                case "chest":
                    var chest = obj_dungeon_ladder_down.linked_chest;
                    chest.renderer.set_sprite(chest.prototype.chest.closed_sprite);
                    chest.renderer.image_speed = 0;
                    TANGO.play("SoundEffects/Objects/TreasureChestClose", chest.renderer.x, chest.renderer.y);
                    break;
                case "chest_unlocked":
                    obj_dungeon_ladder_down.linked_chest.is_locked = false;
                    breakable_open_chest(obj_dungeon_ladder_down.linked_chest);
                    break;
                case "lights_on":
                    Game.dark_room_target_override = 0.55;
                    Game.last_alpha_edit_amount = 0.55;
                    break;
                case "lights_off":
                    Game.dark_room_light_count = 0;
                    Game.dark_room_target_override = undefined;
                    Game.dark_room_transition_speed = 0.03;
                    break;
                case "lights_finished":
                    Game.dark_room_target_override = 0.55;
                    break;
            }
        });

        create_function("equip_dragonsworn_armor", function() {
            var active_preset = ARI.animation_assets();
            var cache_preset = active_preset.clone();

            active_preset.assets.retain(function(asset) {
                static BANNED = [ParUiSlot.Back, ParUiSlot.FaceGear, ParUiSlot.HeadGear, ParUiSlot.Bottom, ParUiSlot.Feet, ParUiSlot.Top];
                for (var i = 0; i < array_length(BANNED); i++) {
                    var cat = CUSTOMIZATION_UI_DATA.get(BANNED[i]);
                    for (var j = 0; j < cat.count(); j++) {
                        var sub = cat.get(j);
                        var remove = sub.assets.any(function(v, asset) {
                            return v[$ "key"] == asset.name;
                        }, asset);
                        if remove {
                            obj_ari.par.remove_asset(asset.name);
                            return false;
                        }
                    }
                }
                return true;
            });

            active_preset.assets.push({
                name: "back_gear_dragonsworn_cloak",
                lut_index: 1,
            });
            active_preset.assets.push({
                name: "head_dragonsworn_helmet",
                lut_index: 1,
            });
            active_preset.assets.push({
                name: "pants_dragonsworn_armor",
                lut_index: 1,
            });
            active_preset.assets.push({
                name: "shoes_boots_dragonsworn_armor",
                lut_index: 1,
            });
            active_preset.assets.push({
                name: "top_dragonsworn_armor",
                lut_index: 1,
            });

            build_obj_ari_par_from(active_preset);

            MIST.blackboard.set("par_asset_cache", cache_preset);
        })

        create_function("remove_dragonsworn_armor", mist_restore_ari_outfit);

        create_function("caldarus_textbox_hack", function(boo) {
            MIST.blackboard.set("caldarus_textbox_hack", boo);
        })

        create_function("linnet_textbox_hack", function(boo) {
            MIST.blackboard.set("linnet_textbox_hack", boo);
        })

        create_function("start_sepia", function() {
            DISPLAY.post_post_processing = PostPostProcessing.Sepia;
        })

        create_function("stop_sepia", function() {
            DISPLAY.post_post_processing = PostPostProcessing.None;
        })

        create_function("write_seridia_shrine_status", function() {
            var got_something = false;
            var mining_data = DRAGON_SHRINE_DATA.get("mining");
            var combat_data = DRAGON_SHRINE_DATA.get("combat");
            for (var i = 0; i < 5; i++) {
                var tier = mining_data[$ fmt("tier_{}", i + 1)];
                for (var j = 0; j < array_length(tier); j++) {
                    var entry = tier[j];
                    if entry.perk != undefined {
                        got_something |= ARI.perks[entry.perk];
                    }
                }
                var tier = combat_data[$ fmt("tier_{}", i + 1)];
                for (var j = 0; j < array_length(tier); j++) {
                    var entry = tier[j];
                    if entry.perk != undefined {
                        got_something |= ARI.perks[entry.perk];
                    }
                }
            }

            T2R.write("has_given_seridia_essence", got_something);
        })

        create_function("kill_sound_emitters", function() {
            with obj_sound_emitter {
                instance_destroy();
            }
        })

        create_function("apply_heart_level_changes", function() {
            var cutscene_data = CUTSCENES.get(MIST.active_cutscene.id);
            for (var i = 0, c = array_length(cutscene_data.heart_level_changes); i < c; i++) {
                var command = cutscene_data.heart_level_changes[i];
                NPCS[command.npc_id].set_heart_level(command.heart_level);
            }
        })

        create_function("teleport_effect", function(actor) {
            var obj = actor_name_to_object(actor);
            var chain = new_world_chain(obj, CURRENT_LOCATION_ID);
            TANGO.play("SoundEffects/Entrances/Teleport", obj.x, obj.y);
            if obj == obj_ari {
                chain.append(LinkId.Ease, new Ease(EaseId.SineIn, 0.0, 1.0, 60), function(_, ab) {
                    obj_ari.par.blend = {
                        src_mode: bm_src_alpha,
                        dest_mode: bm_inv_src_alpha,
                        color: c_white,
                        alpha: floor(ab * 10.0) / 10.0,
                    };
                });
                chain.append(LinkId.Timer, 6);
            } else {
                var inst = create_renderer_at_depth(obj.depth - 1, undefined, [obj]);
                inst.image_alpha = 0;
                inst.draw_call = method(inst, function(obj) {
                    if !MIST.is_running() || !instance_exists(obj) {
                        instance_destroy(self);
                        return;
                    }
                    self.depth = obj.depth - 1;

                    gpu_set_extra(UberShaderKind.Flat);
                    draw_sprite_ext(obj.sprite_index, obj.image_index, obj.x, obj.y, 1.0, 1.0, 0.0, c_white, self.image_alpha);
                    gpu_reset_extra();
                });

                chain.append(LinkId.Ease, new Ease(EaseId.SineIn, 0.0, 1.0, 60), function(_, ab, inst) {
                    inst.image_alpha = floor(ab * 10.0) / 10.0;
                }, [inst]);
                chain.append(LinkId.Timer, 6);
                chain.append(LinkId.Function, function(inst) {
                    instance_destroy(inst);
                }, [inst]);
            }

            chain.append(LinkId.Function, function(obj) {
                create_animation_effect(
                    obj.x,
                    obj.y,
                    -10000,
                    spr_fx_teleport_void_disappear
                );
                MIST.blackboard.insert("teleport_done", true);
            }, [obj])
        })

        create_function("kill_chest_for_eiland_eight_heart", function() {
            with obj_assetobject {
                if self.sprite_index == spr_dragonsworn_glade_storage_chest_spring_closed
                    || self.sprite_index == spr_dragonsworn_glade_storage_chest_winter_closed
                {
                    self.image_alpha = 0;
                }
            }
        })

        create_function("is_dating", function(npc) {
            return NPCS[string_to_npc_id(npc)].is_dating();
        })

        create_function("is_best_friend", function(npc) {
            return NPCS[string_to_npc_id(npc)].is_best_friend();
        })

        create_function("is_partner", function(npc) {
            return NPCS[string_to_npc_id(npc)].is_partner();
        })

        create_function("is_spouse", function(npc) {
            return NPCS[string_to_npc_id(npc)].is_spouse();
        })

        create_function("drop_pet", function() {
            //
            if ARI.held_animal_id == PET_ID {
                animal_inst = obj_pet;
                ARI.held_animal_id = undefined;

                if GRID.node_collideable[GRID.node_index_for_room_position(obj_ari.x, obj_ari.y + 8)] == false {
                    obj_pet.x = obj_ari.x;
                    obj_pet.y = obj_ari.y + 8;
                } else {
                    obj_pet.x = obj_ari.x;
                    obj_pet.y = obj_ari.y;
                }

                obj_pet.put_down();
            }
        })

        //
        //
        create_function("path_length", function(actor, xx, yy) {
            var obj = actor_name_to_object(actor);
            var dest = mist_position_input(xx, yy);

            var test_path = PATHFINDING.calculate_local_path(obj.x, obj.y, xx, yy);
            if test_path == undefined {
                return -1;
            }

            var path = test_path.output_list.reverse();
            var total = 0;
            for (var i = 0; i < path.count() - 1; i++) {
                var dest = path.get(i + 1);
                var start = path.get(i);
                total += abs(dest.x - start.x) + abs(dest.y - start.y);
            }

            return total;
        });

        create_function("refresh_achievements", function() {
            refresh_achievements();
        })

        create_function("past_year_one", function() {
            return CALENDAR.time > years(1);
        })

        create_function("__trigger_birth", function() {
            var spouse = ARI.spouse();
            var child = NPC_PROTOTYPES[spouse].children[array_length(ARI.children)];
            trigger_birth(child);

            if TEST_SUITE {
                var popup = ANCHOR.get_menu(Menu.Popup);
                ANCHOR.tap_node(popup.buttons.first());
            }
        })

        create_function("evaluate_wedding_actors", function() {
            var spouse = ARI.fiance();
            if spouse == undefined {
                warn("You have no fiance?! Using Juniper instead...");
                spouse = NpcId.Juniper;
            }
            MIST.runtime.blackboard.insert("wedding_actors", wedding_party_for(spouse));
        });

        create_function("ceremony_actor", function(key) {
            var a = MIST.runtime.blackboard.get("wedding_actors").ceremony[$ key];
            return a ?? "undefined";
        });

        create_function("reception_actor", function(key) {
            var a = MIST.runtime.blackboard.get("wedding_actors").reception[$ key];
            return a ?? "undefined";
        });

        create_function("ari_house_exit_x", function() {
            return player_home_safe_position(CURRENT_LOCATION_ID).x;
        });

        create_function("ari_house_exit_y", function() {
            return player_home_safe_position(CURRENT_LOCATION_ID).y;
        });

        create_function("apply_wedding_outfit", function() {
            var preset = self.blackboard.get("wedding_outfit");
            build_obj_ari_par_from(preset);
        })

        create_function("create_black_overlay", function() {
            var lay = layer_create(FIRE_SEAL_BLACK_OVERLAY_DEPTH, "BlackBackground");
            var back_asset = layer_asset_create_tiled(lay, -1000, -1000, mwe_white_pixel, room_width() + 2000, room_height() + 2000);
            layer_asset_set_blend(back_asset, c_black, 1.0);
            MIST.blackboard.insert("black_overlay", lay);
        });

        create_function("spawn_baby_prop", function(x, y) {
            var position = mist_position_input(x, y);
            var child = potential_child();
            var sprite = child.get_sprite("idle_diagonal", Cardinal.South);
            create_sprite_renderer(position.x, position.y, -999, sprite);
        });

        create_function("spawn_stork_baby_prop", function() {
            var position = trellis_point_find_by_name(room(), "gb_bird");
            var child = potential_child();
            var sprite = child.get_sprite("idle_diagonal", Cardinal.South);
            var inst = create_sprite_renderer(position.x, position.y + 3, -99999, sprite);
            new_chain().append(LinkId.Ease, new Ease(EaseId.Linear, 0, 1, 180), function(_, a, inst) {
                if !instance_is_alive(inst) {
                    return;
                }
                inst.image_alpha = a;
            }, [inst])
        });

        create_function("wedding_cosmetic_popup", function() {
            if TEST_SUITE {
                return;
            }

            var items = fiddle_get("misc/wedding_assets");
            for (var i = 0; i < array_length(items); i++) {
                ARI.cosmetic_unlocks.insert(items[i]);
            }
            var item = LiveItem(ItemId.Cosmetic);
            item.cosmetic = "head_wedding_veil";
            new_item_popup(item);
        })

        create_function("is_defined", function(value) {
            return !matches(value, "undefined", undefined);
        })

        create_function("mistril_renown_sequence", function() {
            //
            ARI.renown = renown_level_total_cost(99) + (renown_level_individual_cost(100) * 0.95);
            ARI.pending_renown_entries.push(RenownEntry.Gold(9999));
            var menu = ANCHOR.spawn_menu(Menu.RenownSequence);
            ARI.renown = renown_level_total_cost(100);
            ARI.pending_renown_entries.clear();
        })

        create_function("chicken_give_egg", function() {
            obj_chicken_statue.prize = List(new LiveItem(ItemId.BigEgg));
            obj_chicken_statue.sprite_index = obj_chicken_statue.on_sprite;
            obj_chicken_statue.image_speed = 1;
        });

        create_function("freeze_actor", function(actor) {
            var actor = actor_name_to_object(actor);
            actor.anim_speed = 0;
        })

        create_function("unfreeze_actor", function(actor) {
            var actor = actor_name_to_object(actor);
            actor.anim_speed = 1;
        })
    }
}
