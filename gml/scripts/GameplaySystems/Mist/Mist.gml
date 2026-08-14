#macro CUTSCENES global.__cutscenes
global.__cutscenes = undefined;

#macro MIST_STD global.__mist_std
MIST_STD = undefined;

#macro CUTSCENES_CAN_PLAY global.__cutscenes_can_play
CUTSCENES_CAN_PLAY = true;

function load_cutscenes() {
    var output = Map();
    var cutscenes = fiddle_get("cutscenes");
    var keys = struct_get_names(cutscenes);
    var cutscene_default = cutscenes[$ "default"];
    var valid_keys = struct_get_names(cutscene_default);

    var backup_conversation = T2R.exact_gameplay_conversation("cutscene_basement");
    assert_defined(backup_conversation);

    var replaced_conversations = List();

    MIST_STD = read_mist_file("std");
    assert_neq(MIST_STD, undefined, "uh oh");

    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];
        if key == "default" {
            continue;
        }
        var cutscene = cutscenes[$ key];
        var mist = read_mist_file(key);
        assert_neq(mist, undefined, "could not find mist data for {}", key);

        if DEBUG_ASSERTIONS {
            var invalid_field = find_invalid_field(cutscene, valid_keys);
            if invalid_field != undefined {
                crash("Invalid cutscene field in {}: {}", key, invalid_field);
            }
        }

        var conversation_path = undefined;
        if cutscene[$ "has_conversation"] == true {
            //
            conversation_path = T2R.exact_gameplay_conversation(key);

            if conversation_path == undefined {
                conversation_path = backup_conversation;
                replaced_conversations.push(key);
            }
        }

        var trigger = undefined;
        var t = cutscene[$ "trigger"] ?? cutscene_default[$ "trigger"];
        if t != -1 {
            trigger = {
                location: string_to_location_id(t.location),
                bbox: t[$ "bbox"],
                manually_activated: t[$ "manually_activated"] ?? false,
            }
        }

        var arr = cutscene[$ "drop_items"] ?? cutscene_default[$ "drop_items"]

        var drop_items = array_map(arr, function(item) {
            var location = undefined;
            if item[$ "location"] != undefined {
                location = trellis_point_location_position(item.location);
            }
            return {
                item_id: string_to_item_id(item.item_id),
                location: location,
                player_home: item[$ "player_home"],
                mist_id: irandom(I32_MAX)
            }
        })

        arr = cutscene[$ "status_effects"] ?? cutscene_default[$ "status_effects"];

        var status_effects = array_map(arr, function(status_effect) {
            return {
                status_effect: string_to_status_effect_id(status_effect.status_effect),
                hours: status_effect.hours,
                amount: status_effect.amount
            }
        });

        arr = cutscene[$ "given_items"] ?? cutscene_default[$ "given_items"];

        var given_items = array_map(arr, function(item) {
            return {
                item_id: string_to_item_id(item.item_id),
                quantity: item[$ "quantity"] ?? 1,
                infusion: item[$ "infusion"] != undefined ? string_to_infusion(item.infusion) : undefined,
                requirements: parse_requirements(item[$ "requirements"] ?? {}),
            }
        });

        arr = cutscene[$ "heart_level_changes"] ?? cutscene_default[$ "heart_level_changes"];

        var heart_level_changes = array_map(arr, function(command) {
            return {
                npc_id: string_to_npc_id(command.npc_id),
                heart_level: command.heart_level
            }
        })

        var object_removals = cutscene[$ "object_removals"] ?? cutscene_default[$ "object_removals"];
        for (var j = 0; j < array_length(object_removals); j++) {
            object_removals[j].location = string_to_location_id(object_removals[j].location);
            object_removals[j].object = string_to_object_id(object_removals[j].object);
        }

        var test_target = string_to_scene_test_target(cutscene.test_target);

        var quest_to_start = opt_and_then(cutscene[$ "quest_to_start"], ensure_array);
        if quest_to_start != undefined {
            for (var j = 0; j < array_length(quest_to_start); j++) {
                if CONTENT_REGISTRY.validate_quest(quest_to_start[j]) == undefined {
                    array_delete(quest_to_start, j, 1);
                    j -= 1;
                }
            }
        }

        output.insert(key, {
            id: key,
            mist: mist,
            conversation_path: conversation_path,
            requirements: parse_requirements(cutscene[$ "requirements"] ?? cutscene_default[$ "requirements"]),
            trigger: trigger,
            end_position: cutscene[$ "end_position"],
            ends_day: cutscene[$ "ends_day"] ?? cutscene_default[$ "ends_day"],
            requires_story_mode: cutscene[$ "requires_story_mode"] ?? cutscene_default[$ "requires_story_mode"],
            can_skip: cutscene[$ "can_skip"] ?? cutscene_default[$ "can_skip"],
            confirm_skip: cutscene[$ "confirm_skip"] ?? cutscene_default[$ "confirm_skip"],
            begin_with_fade_out: cutscene[$ "begin_with_fade_out"] ?? cutscene_default[$ "begin_with_fade_out"],
            test_target,
            quest_to_start,
            quest_to_progress: cutscene[$ "quest_to_progress"] == undefined ? undefined : CONTENT_REGISTRY.validate_quest(cutscene[$ "quest_to_progress"]),
            spell_to_unlock: opt_and_then(cutscene[$ "spell_to_unlock"], string_to_spell),
            mana_to_set: cutscene[$ "mana_to_set"],
            do_not_set_idle: cutscene[$ "do_not_set_idle"] ?? cutscene_default.do_not_set_idle,
            frames_before_skip_prompt: cutscene[$ "frames_before_skip_prompt"] ?? cutscene_default.frames_before_skip_prompt,
            skip_prompt_length: cutscene[$ "skip_prompt_length"] ?? cutscene_default.skip_prompt_length,
            when_sleeping: cutscene[$ "when_sleeping"] ?? cutscene_default.when_sleeping,
            can_repeat: cutscene[$ "can_repeat"] ?? cutscene_default.can_repeat,
            drop_items,
            status_effects,
            baths: cutscene[$ "baths"] ?? cutscene_default[$ "baths"],
            set_max_hp: cutscene[$ "set_max_hp"] ?? cutscene_default[$ "set_max_hp"],
            set_max_stamina: cutscene[$ "set_max_stamina"] ?? cutscene_default[$ "set_max_stamina"],
            set_health_to: cutscene[$ "set_health_to"] ?? undefined,
            set_stamina_to: cutscene[$ "set_stamina_to"] ?? undefined,
            given_items,
            menu_close: try_string_to_menu(cutscene[$ "menu_close"] ?? cutscene_default[$ "menu_close"]),
            post_process_time_override_reset: cutscene[$ "post_process_time_override_reset"] ?? cutscene_default[$ "post_process_time_override_reset"],
            animate: cutscene[$ "animate"] != undefined ? string_to_animation_name(cutscene[$ "animate"]) : undefined,
            invisible_assets: array_map(cutscene[$ "invisible_assets"] ?? cutscene_default[$ "invisible_assets"], string_to_asset),
            invisible_objects: array_map(cutscene[$ "invisible_objects"] ?? cutscene_default[$ "invisible_objects"], object),
            prevent_eod_music_stop: cutscene[$ "prevent_eod_music_stop"] ?? cutscene_default[$ "prevent_eod_music_stop"],
            heart_level_changes,
            cut_off_music: cutscene[$ "cut_off_music"] ?? cutscene_default.cut_off_music,
            allow_glyph_guide: cutscene[$ "allow_glyph_guide"] ?? cutscene_default.allow_glyph_guide,
            silence_music_after_scene: cutscene[$ "silence_music_after_scene"] ?? cutscene_default.silence_music_after_scene,
            romantic_choice_warning: opt_and_then(cutscene[$ "romantic_choice_warning"], string_to_npc_id),
            end_time_jump: opt_and_then(cutscene[$ "end_time_jump"], function(o) {
                return hours(o.hour) + minutes(o.minute);
            }),
            post_scene_tutorial: opt_and_then(cutscene[$ "post_scene_tutorial"], string_to_tutorial),
            object_removals,
            refresh_music: cutscene[$ "refresh_music"] ?? cutscene_default.refresh_music,
            refreshes_room_layers: cutscene[$ "refreshes_room_layers"] ?? cutscene_default.refreshes_room_layers,
            handle_farm_chores: cutscene[$ "handle_farm_chores"] ?? cutscene_default.handle_farm_chores,
            give_items_once: cutscene[$ "give_items_once"] ?? cutscene_default.give_items_once,
            manually_triggered_in_morning: cutscene["manually_triggered_in_morning"] ?? cutscene_default.manually_triggered_in_morning,
            nuke: cutscene["nuke"],
        });
    }

    if replaced_conversations.is_empty() == false {
        var names = "";
        for (var i = 0; i < replaced_conversations.count(); i++) {
            if i == replaced_conversations.count() - 1 {
                names += "and ";
            }
            names += replaced_conversations.get(i);

            if i != replaced_conversations.count() - 1 {
                names += ", ";
            }
        }

        error("Replaced {} cutscene conversations with backups: {}", replaced_conversations.count(), names);
    }

    return output;
}

#macro MIST global.__mist
global.__mist = undefined;

function Mist() constructor {
    self.queued_scenes = List();
    self.runtime = undefined;
    self.npcs = List();
    self.cameos = List();
    self.player_location_position_start = undefined;
    self.skip_in_progress = false;
    self.skip_forbidden = false;
    self.confirm_skip = false;
    self.cached_expansion_level = undefined;
    self.blackboard = Map();
    self.scene_history = HashSet();
    self.scenes_played_today = HashSet();
    self.active_cutscene = undefined;
    self.running = false;
    self.previously_held_animal = undefined;
    self.skip_popup = undefined;
    self.last_cutscene = undefined;
    self.arbitrary_quest_to_progress = undefined;
    self.sound_requests = List();
    self.spawned_animals = List();
    self.halt_music_until_room_swap = false;
    self.restore_no_asymptote = false;
    self.requirement_overrides = array_create(Requirement.LEN, false);

    //
    function request_scene(scene) {
        trace("Requesting {}...", scene);
        if !self.is_running() {
            self.run_scene(scene);
            return true;
        } else {
            trace("Scene is already running: inserting to queue...");
            self.queued_scenes.push(scene);
            return false;
        }
    }

    function check_cutscene_eligible(cutscene, when_sleeping=false) {
        cutscene = CUTSCENES.get(cutscene);

        var eligible = CUTSCENES_CAN_PLAY;

        eligible &= requirements_pass(cutscene.requirements);

        eligible &= cutscene.when_sleeping == when_sleeping;

        if cutscene.trigger != undefined {
            eligible &= CURRENT_LOCATION_ID == cutscene.trigger.location;
        }

        eligible &= !self.scene_history.contains(cutscene.id) || cutscene.can_repeat;

        eligible &= STORY_ENABLED || !cutscene.requires_story_mode;

        eligible &= !self.scenes_played_today.contains(cutscene.id);

        return eligible;
    }

    function on_end_day() {
        //
        var keys = CUTSCENES.keys();
        for (var i = 0; i < array_length(keys); i++) {
            if self.check_cutscene_eligible(keys[i], true) {
                self.request_scene(keys[i]);
            }
        }
    }

    function spawn_trigger(cutscene) {
        var trigger = CUTSCENES.get(cutscene).trigger;
        if self.is_running() {
            return;
        }
        var spawn_area = trigger[$ "bbox"] ?? [0, 0, room_width() div 8, room_height() div 8];
        trace("Spawning a cutscene trigger for {} at {}x{}", cutscene, spawn_area[0] * 8, spawn_area[1] * 8);
        var inst = instance_create_depth(spawn_area[0] * 8, spawn_area[1] * 8, 0, obj_cutscene_trigger);
        inst.image_xscale = (spawn_area[2] - spawn_area[0]) * 8;
        inst.image_yscale = (spawn_area[3] - spawn_area[1]) * 8;
        inst.cutscene = cutscene;
    }

    function run_scene(scene) {
        trace("Running mist scene: {}...", scene);
        self.running = true;
        PAUSE_STATUS = set_flag(PAUSE_STATUS, PauseStatus.CUTSCENE);

        self.active_cutscene = CUTSCENES.get(scene);
        self.skip_forbidden = !self.active_cutscene.can_skip;
        self.confirm_skip = self.active_cutscene.confirm_skip;

        if instance_exists(obj_ari) {
            if self.active_cutscene.do_not_set_idle {
                obj_ari.fsm.blackboard.insert("do_not_set_idle", true);
            }
            obj_ari.fsm.change_state_instant(PlayerState.Cutscene);

            //
            if self.active_cutscene.when_sleeping && obj_ari.par.base_animation() == AnimationName.Faint {
                obj_ari.set_cardinal(Cardinal.South);
                obj_ari.par.set_base_hold_on_last_frame();
            }

            self.player_location_position_start = new LocationPosition(
                gm_room_to_location_id(room()),
                Vec2(obj_ari.x, obj_ari.y),
            );

            obj_ari.par.blend = undefined;

            handle_child_on_par(obj_ari.par);
        }

        //
        //
        for (var i = 0; i < NpcId.LEN; i++) {
            var npc = new Npc(i, MistNpcBrain());
            npc.heart_level = NPCS[i].heart_level;
            self.npcs.push(npc);
        }
        for (var i = 0; i < CameoId.LEN; i++) {
            var cameo = new Cameo(i, CameoBrain());
            self.cameos.push(cameo);
        }

        static START_SCENE = function() {
            if CAMERA.asymptote == false {
                CAMERA.asymptote = true;
                self.restore_no_asymptote = true;
            }

            WEATHER.spell_stop_time = undefined;
            MIST.runtime = new MistRuntime();
            PROPS.clear_all_current_props();

            if MIST.active_cutscene.conversation_path != undefined {
                //
                MIST.runtime.blackboard.set("driver", new ConversationDriver(NpcId.Adeline, MIST.active_cutscene.conversation_path));
            }

            NON_PLAYER_ANIMALS.for_each(function(animal) {
                if animal.instance != undefined && instance_exists(animal.instance) {
                    instance_destroy(animal.instance);
                    animal.instance = undefined;
                }
            });

            //
            if ARI.held_animal_id != undefined {
                MIST.previously_held_animal = ARI.held_animal_id;
                var animal = find_animal(ARI.held_animal_id, false);
                if animal.instance != undefined {
                    instance_destroy(animal.instance);
                }
                ARI.held_animal_id = undefined;
            }

            if instance_exists(obj_ari) {
                obj_ari.initialize_for_cutscene();
            }

            if !MIST.skip_forbidden
                && MIST.active_cutscene.skip_prompt_length > 0
            {
                create_skip_prompt_for_mist(
                    MIST.active_cutscene.frames_before_skip_prompt,
                    MIST.active_cutscene.skip_prompt_length,
                    MIST.active_cutscene.id,
                );
            }

            store_loose_items_as_lost();
            instance_destroy(obj_item);

            //
            if WEATHER.atmosphere != undefined {
                WEATHER.set_atmosphere(WEATHER.atmosphere.id);
            }

            MIST.runtime.start(MIST_STD);
            MIST.runtime.run(MIST.active_cutscene.mist);
        }
        if self.active_cutscene.begin_with_fade_out {
            SCREEN_FADER.fade_out(FADE_SPEED_TRANSITION, START_SCENE);
        } else {
            START_SCENE();
        }

        MUSIC_PLAYER.refresh();
        AMBIENCE_PLAYER.refresh();
    }

    function is_running() {
        return self.running;
    }

    function on_room_start() {
        self.halt_music_until_room_swap = false;

        //
        if ANCHOR.get_menu(Menu.Eod) != undefined
            || (TEST_SUITE && !STORY_EXECUTOR_RUNNING)
            || ARI.end_of_day_status != undefined
        {
            return;
        }

        var keys = CUTSCENES.keys();
        for (var i = 0; i < array_length(keys); i++) {
            var cutscene = CUTSCENES.get(keys[i]);
            if
                cutscene.trigger != undefined
                && !cutscene.trigger.manually_activated
                && self.check_cutscene_eligible(keys[i])
            {
                self.spawn_trigger(keys[i]);
            }
        }

        //
        with obj_cutscene_trigger {
            if !MIST.is_running() {
                self.check_for_player();
            }
        }
    }

    function on_step() {
        for (var i = 0; i < self.npcs.count(); i++) {
            var npc = self.npcs.get(i);
            npc.activity_handler.run();
            run_brain(npc.brain);
        }
        for (var i = 0; i < self.cameos.count(); i++) {
            run_brain(self.cameos.get(i).brain);
        }

        //
        //
        if self.last_cutscene != undefined {
            //
            if self.last_cutscene.quest_to_start != undefined {
                for (var i = 0; i < array_length(self.last_cutscene.quest_to_start); i++) {
                    var quest = self.last_cutscene.quest_to_start[i];

                    if !QUEST_LOG.active.contains_key(quest) {
                        QUEST_LOG.start(quest);
                        create_quest_popup(quest);
                        var n = REQUEST_BOARD.find_lazy(quest);
                        if n != undefined {
                            REQUEST_BOARD.remove(n);
                        }
                    }
                }
            }

            //
            if self.last_cutscene.quest_to_progress != undefined {
                var quest = QUEST_LOG.active.get(self.last_cutscene.quest_to_progress);
                if quest == undefined {
                    //
                    //
                    warn("Skipping progression on quest '{}' because we didn't have it!", self.last_cutscene.quest_to_progress);
                } else {
                    quest.handle_progress_output(quest.progress());
                }
            }

            //
            if self.last_cutscene.spell_to_unlock != undefined {
                ARI.learn_spell(self.last_cutscene.spell_to_unlock);
            }

            //
            if self.last_cutscene.mana_to_set != undefined && ARI.mana_max < self.last_cutscene.mana_to_set {
                ARI.mana_max = self.last_cutscene.mana_to_set;
                ARI.set_mana(self.last_cutscene.mana_to_set);
            }

            if self.arbitrary_quest_to_progress != undefined {
                var output = self.arbitrary_quest_to_progress.progress();
                self.arbitrary_quest_to_progress.handle_progress_output(output);

                self.arbitrary_quest_to_progress = undefined;
            }

            self.last_cutscene = undefined;
        }

        if self.runtime != undefined {
            //
            if self.skip_popup != undefined && self.skip_popup.close_requested {
                self.skip_popup = undefined;
            }

            //
            if !self.skip_in_progress {
                self.runtime.on_step();
            }

            //
            if !self.runtime.running {
                self.clean_up_scene();
            }

            //
            if !self.skip_forbidden
                && TAXI.is_traveling() == false
                && self.skip_in_progress == false
                && self.blackboard.get("block_skip") != true
                && INPUT.take_press(InputId.MenuBack)
            {
                if self.confirm_skip {
                    self.skip_popup = popup_creator("misc_local/skip_cutscene", "misc_local/skip_cutscene_confirmation");
                    self.skip_popup.create_button("misc_local/cancel", function() {
                        self.skip_popup = undefined;
                    });
                    self.skip_popup.create_button("misc_local/yes", function() {
                        if self.active_cutscene.romantic_choice_warning != undefined {
                            await_popup(function() {
                                var body = ANCHOR.wrap_for_local(format(
                                    local_get("misc_local/romantic_choice_warning"),
                                    local_get(NPC_PROTOTYPES[self.active_cutscene.romantic_choice_warning].name),
                                ));
                                self.skip_popup = popup_creator("misc_local/warning", body);
                                self.skip_popup.body_text.set_text_align(TextAlign.Center)
                                self.skip_popup.create_button("misc_local/cancel", function() {
                                    self.skip_popup = undefined;
                                });
                                var yes = self.skip_popup.create_button("misc_local/yes", function() {
                                    var key = format("{NpcId}_status", self.active_cutscene.romantic_choice_warning);
                                    if T2R.read(key) != "dating" {
                                        T2R.write(key, "best_friend");
                                    }
                                    skip_current_cutscene();
                                    self.skip_popup = undefined;
                                });

                                yes.lock();

                                new_chain()
                                    .append(LinkId.Timer, 90)
                                    .append(LinkId.Function, function(yes) {
                                        yes.unlock();
                                    }, [yes])


                                self.skip_popup.spawn();
                            })
                        } else {
                            skip_current_cutscene();
                            self.skip_popup = undefined;
                        }

                    });

                    self.skip_popup.spawn();
                } else {
                    skip_current_cutscene();
                }
            }
        }
    }

    function clean_up_scene() {
        //
        trace("Cleaning up scene '{}'...", self.active_cutscene.id);

        var was_previously_seen = MIST.scene_history.contains(self.active_cutscene.id);
        var grant_items = !was_previously_seen || !self.active_cutscene.give_items_once;

        self.mark_scene_has_played(self.active_cutscene.id);

        self.requirement_overrides = array_create(Requirement.LEN, false);

        if !self.blackboard.try_take("removed_scene_objects", false) {
            trigger_scene_object_removals(self.active_cutscene.id);
        }

        var overlay = self.blackboard.try_take("black_overlay");
        if overlay != undefined {
            layer_destroy(overlay);
        }

        if instance_exists(obj_ari) && self.blackboard.try_take("aris_eyes_are_closed", false) == true {
            var eyes = obj_ari.par.slots[AnimationSlot.Eyes];
            obj_ari.par.set_animation_on_slot(AnimationName.Idle, eyes.modifier);
        }

        PROPS.clear_all_current_props();
        PROPS.on_room_start();

        if self.restore_no_asymptote {
            self.restore_no_asymptote = false;
            CAMERA.asymptote = false;
        }

        if self.blackboard.get("modified_camera_max_offset") == true {
            CAMERA.max_offset = DEFAULT_CAMERA_MAX_OFFSET;
        }

        if self.blackboard.get("weather_modified") == true {
            WEATHER.set_weather(WEATHER.forecast[CALENDAR.day()]);
        }

        //
        var driver = self.runtime.blackboard.get("driver");
        if driver != undefined {
            if self.skip_in_progress {
                var textbox = ANCHOR.get_menu(Menu.Textbox);
                if textbox != undefined {
                    textbox.close(true);
                    driver.textbox = undefined;
                }

                driver.finish_conversation();
            } else {
                driver.proceed_conversation();
                assert_eq(driver.state, ConversationDriverState.Finished, "We didn't finish the conversation in the cutscene!");
            }
        }

        //
        if self.skip_popup != undefined && !self.skip_popup.close_requested {
            self.skip_popup.close();
            self.skip_popup = undefined;
        }

        self.last_cutscene = self.active_cutscene;

        self.sound_requests.drain(function(s) {
            if s != undefined && self.last_cutscene.id != "sleep" { //
                TANGO.force_stop(s);
            }
        });

        self.spawned_animals.drain(function(animal) {
            NON_PLAYER_ANIMALS.remove(NON_PLAYER_ANIMALS.find_lazy(animal));

            with obj_npa {
                if self.me.id == animal {
                    instance_destroy();
                }
            }
        })

        //
        var house_is_fucked = self.blackboard.try_take("house_is_fucked") ?? false;

        //
        PAUSE_STATUS = remove_flag(PAUSE_STATUS, PauseStatus.CUTSCENE);

        //
        with obj_bug {
            self.cutscene_ended();
        }

        //
        with obj_cutscene_animal {
            instance_destroy();
        }

        instance_activate_object(obj_bird);
        with obj_bird {
            shadow_caster_set_sprite(self.shadow_caster, self.shadow_sprite_backup, self.shadow_sprite_index_backup);
            self.visible = true;
        }

        var cutscene_data = CUTSCENES.get(MIST.active_cutscene.id);

        if cutscene_data.set_health_to != undefined {
            ARI.set_health(cutscene_data.set_health_to, false, true);
        }

        if cutscene_data.set_stamina_to != undefined {
            ARI.set_stamina(cutscene_data.set_stamina_to);
        }

        for (var i = 0, c = array_length(cutscene_data.drop_items); i < c; i++) {
            var item = cutscene_data.drop_items[i];

            var location = undefined;
            if item.player_home {
                location = {
                    location_id: LocationId.PlayerHome,
                    pos: player_home_safe_position(LocationId.PlayerHome),
                };
            } else {
                location = item.location;
            }

            if location.location_id != CURRENT_LOCATION_ID {
                GRIDS[location.location_id].lost_items.push({
                    x: location.pos.x,
                    y: location.pos.y,
                    items: List(new LiveItem(item.item_id)),
                });
            } else {
                var spawned = false;
                with obj_item {
                    if self.mist_id == item.mist_id {
                        spawned = true;
                    }
                }

                if !spawned {
                    drop_item(item.item_id, location.pos.x, location.pos.y);
                }
            }

        }

        for (var i = 0, c = array_length(cutscene_data.status_effects); i < c; i++) {
            var sickness = cutscene_data.status_effects[i];
            ARI.status_effects.register(
                sickness.status_effect,
                sickness.amount,
                CALENDAR.unified_time(),
                CALENDAR.unified_time() + hours(sickness.hours),
            );
        }

        if cutscene_data.animate != undefined {
            obj_ari.par.set_base_loop();
            obj_ari.par.held_sprite = undefined;
            obj_ari.par_anim_spd = obj_ari.default_par_anim_spd;
            obj_ari.par.remove_attachment();
            obj_ari.par.unset_all_modifiers();
            obj_ari.set_animation(cutscene_data.animate, SetAnimationOverride.OverrideAnyway);
        }

        if cutscene_data.set_max_hp {
            ARI.set_health(ARI.get_max_health());
        }

        if cutscene_data.set_max_stamina && ARI.get_stamina() < ARI.get_max_stamina() {
            ARI.set_stamina(ARI.get_max_stamina());
        }

        ARI.free_baths += cutscene_data.baths;

        if cutscene_data.menu_close != -1 {
            var menu = ANCHOR.get_menu(cutscene_data.menu_close);

            if menu != undefined {
                menu.close();
            }
        }

        if cutscene_data.post_process_time_override_reset {
            POST_PROCESS_TIME_OVERRIDE = undefined;
        }

        for (var i = 0, c = array_length(cutscene_data.invisible_assets); i < c; i++) {
            with obj_assetobject {
                if sprite_index == cutscene_data.invisible_assets[i] {
                    visible = true;
                    if self.light != undefined {
                        self.light.show = true;
                    }
                    shadow_caster_set_alpha(self.shadow_caster, 1);
                    break;
                }
            }
        }

        for (var i = 0, c = array_length(cutscene_data.invisible_objects); i < c; i++) {
            with cutscene_data.invisible_objects[i] {
                visible = true;
            }
        }

        for (var i = 0, c = array_length(cutscene_data.heart_level_changes); i < c; i++) {
            var command = cutscene_data.heart_level_changes[i];
            NPCS[command.npc_id].set_heart_level(command.heart_level);
        }

        //
        for (var i = 0; i < NpcId.LEN; i++) {
            NPCS[i].report_relationship();
        }

        //
        //
        if cutscene_data.nuke != undefined {
            var xx0 = cutscene_data.nuke[0] div 8;
            var yy0 = cutscene_data.nuke[1] div 8;
            var xx1 = cutscene_data.nuke[2] div 8;
            var yy1 = cutscene_data.nuke[3] div 8;

            if DEBUG_ASSERTIONS {
                assert(xx0 < xx1);
                assert(yy0 < yy1);
            }

            var town = GRIDS[LocationId.Town];

            for (var xx = xx0; xx < xx1; xx++) {
                for (var yy = yy0; yy < yy1; yy++) {
                    var ni = town.node_index_for_cell(xx, yy);
                    erase_object_node(town, ni);
                }
            }
        }

        //
        instance_activate_object(obj_fish_school);
        instance_activate_object(obj_fishy);
        instance_activate_object(obj_divespot);

        with obj_fish_school {
            self.visible = true;
        }
        with obj_fishy {
            self.visible = true;
        }
        with obj_divespot {
            self.visible = true;
        }

        //
        with par_NPC {
            instance_destroy();
        }
        with obj_cameo {
            instance_destroy();
        }
        self.npcs.clear();
        self.cameos.clear();

        with obj_void_ari {
            instance_destroy();
        }

        //
        SCREEN_FADER.fade_in();
        if instance_exists(obj_ari) {
            obj_ari.meddler.release_reservations();
            obj_ari.meddler = new PathfindingMeddler(PathfindingAgentKind.Player, obj_ari);
        }

        //
        var changed_location = false;
        var destination = undefined;
        if self.active_cutscene.end_position != undefined {
            switch self.active_cutscene.end_position {
                case "previous":
                    destination = self.player_location_position_start;
                    break;
                case "bed":
                    destination = player_wake_position();
                    break;
                case "blackboard":
                    destination = trellis_point_location_position(self.blackboard.take(
                        "end_position",
                        "Failed to find an end_position on the blackboard!")
                    );
                    break;
                default:
                    destination = trellis_point_location_position(self.active_cutscene.end_position);
                    break;
            }
        }

        if self.active_cutscene.handle_farm_chores {
            water_all(GRIDS[LocationId.Farm], true);
            for (var i = 0; i < DYNAMIC_GRIDS.count(); i++) {
                var grid = DYNAMIC_GRIDS.get(i);
                if grid == undefined {
                    continue;
                }
                water_all(grid, true);
            }
            get_all_animals().for_each(function(animal) {
                animal.feed(ItemId.UltimateHay);
                if animal.can_pet() {
                    animal.pet();
                }
                animal.has_been_outside = true;
            });
        }

        //
        if self.active_cutscene.ends_day && (!TEST_SUITE || STORY_EXECUTOR_RUNNING) {
            if ARI.end_of_day_status == undefined {
                ARI.end_of_day_status = EndOfDayStatus.Normal;

                if self.previously_held_animal != undefined && self.previously_held_animal != PET_ID {
                    find_animal(self.previously_held_animal).send_to_stall_point();
                    self.previously_held_animal = undefined;
                }
            }

            var held_point_of_interest = undefined;
            if self.active_cutscene.id == "wedding" {
                held_point_of_interest = trellis_point_location_position("farm/wed_camera_farm_1");
            }
            end_day(true, held_point_of_interest);
        }

        //
        if self.active_cutscene.end_time_jump != undefined
            && CLOCK.time < self.active_cutscene.end_time_jump
        {
            CLOCK.jump(self.active_cutscene.end_time_jump);
        }

        var fiance = self.blackboard.get("trigger_proposal_with");
        if fiance != undefined {
            process_proposal(string_to_npc_id(fiance));
        }

        //
        switch self.active_cutscene.id {
            case "prologue":
                SCREEN_FADER.snap_out();
                var preset = ARI.presets.first();
                var menu = start_character_creation(preset, function() {
                    MIST.run_scene("day_zero");
                });

                menu.preset_button.set_tap_callback(function() {
                    var popup = popup_creator(
                        "misc_local/outfit_presets_title",
                        "misc_local/outfit_presets_description",
                    );
                    popup.create_button("misc_local/close");

                    popup.canvas.set_layer_recursive(AnchorLayer.Debug);
                    popup.background_layer = AnchorLayer.Debug;
                    popup.background_z = popup.canvas.get_z() + 1;
                    popup.spawn();
                });
                menu.preset_button.set_soft_locked(false);
                menu.override_music = true;
                destination = undefined;
                break;
            case "day_zero":
                if house_is_fucked {
                    GRID.initialize_on_room_start();
                }
                break;
            case "the_unusual_tree_pt_2":
                //
                if CURRENT_LOCATION_ID == LocationId.Farm {
                    instance_destroy(obj_ari);
                }
                break;
            case "bathhouse":
                destination.location_id = LocationId.Bathhouse;
                break;
            case "break_ruins_seal_pt_2":
                with obj_seal_tablet {
                    self.spawn_void_ari();
                }
                break;
            case "break_fire_seal":
                var cal = NPCS[NpcId.Caldarus];
                cal.wardrobe.set_outfit(cal.prototype.get_suitable_outfit_key(cal.wardrobe, CALENDAR.time));
                break;
            case "great_bird_1":
                var choice = T2R.read("utero_choice");
                T2R.write("utero_choice", undefined);
                ARI.pending_child = {
                    due_date: CALENDAR.time + days(13),
                    utero: string_to_utero(choice),
                };
                report_children_facts();
                break;
            case "wedding":
                var fiance = ARI.fiance() ?? NpcId.Juniper;
                T2R.write(format("{NpcId}_status", fiance), "spouse");
                NPCS[fiance].report_relationship();
                ARI.quest_artifacts.insert("wedding_photo_index", array_length(DATE_PHOTOS) - 1);
                break;
            case "march_ten_hearts":
                if !was_previously_seen && !TEST_SUITE {
                    ARI.cosmetic_unlocks.insert("back_gear_march_mistrian_shield");
                    new_chain()
                        .append(LinkId.Await, function() {
                            return ANCHOR.get_menu(Menu.Calendar) == undefined;
                        })
                        .append(LinkId.Function, function() {
                            var item = LiveItem(ItemId.Cosmetic);
                            item.cosmetic = "back_gear_march_mistrian_shield";
                            new_item_popup(item);
                        })
                }
                break;
            case "seridia_ten_hearts":
                if !was_previously_seen && !TEST_SUITE {
                    var cosmetics = fiddle_get("misc/seridia_armor");
                    for (var i = 0; i < array_length(cosmetics); i++) {
                        ARI.cosmetic_unlocks.insert(cosmetics[i]);
                    }
                    new_chain()
                        .append(LinkId.Await, function() {
                            return ANCHOR.get_menu(Menu.Calendar) == undefined;
                        })
                        .append(LinkId.Function, function() {
                            var item = LiveItem(ItemId.Cosmetic);
                            item.cosmetic = "back_gear_dragonsworn_cloak_seridia";
                            new_item_popup(item);
                        })
                }
                break;
            case "player_delivery":
                //
                //
                //
                //
                //
                //
                //
                //
                //
                //
                //
                //
                //
                //
                //
                //
                //
                //
                //
                for (var i = 0; i < NpcId.LEN; i++) {
                    var npc = NPCS[i];
                    if npc.is_roommate() {
                        //
                        //
                        //
                        //
                        //
                        repeat 10 {
                            if npc.activity_handler.state != ActivityState.Inactive {
                                break;
                            }
                            npc.brain.blackboard.insert("forced_location", player_wake_position().location_id);
                            npc.activity_handler.run();
                        }
                        npc.brain.blackboard.remove("forced_location");
                    }
                }
                break;
            case "upgrade_the_saturday_market_plaza":
                //
                spawn_prios_on_map(GRIDS[LocationId.Town], location_id_to_gm_room(LocationId.Town), "PriorityObjectsPlazaFixed", spawn_priority_object);
                fix_plaza_footsteps();
                break;
        }

        //
        ARI.held_animal_id = self.previously_held_animal;
        ARI.held_animal_last_frame = undefined;
        ARI.held_item_last_frame = undefined;
        self.previously_held_animal = undefined;

        //
        DISPLAY.post_post_processing = PostPostProcessing.None;

        if destination != undefined && CURRENT_LOCATION_ID != destination.location_id {
            changed_location = true;
            var itinerary = goto_location_id(destination.location_id, true)
                .set_exact_position(destination.pos.x, destination.pos.y);
            if cutscene_data.end_position != undefined && grant_items {
                itinerary.set_arrival_callback(mist_give_items_after_scene, [cutscene_data.given_items, destination]);
            }
        } else {

            if instance_exists(obj_ari) && ARI.end_of_day_status == undefined {
                //
                obj_ari.fsm.change_state(PlayerState.Default);
                obj_ari.par.set_animation(AnimationName.Idle);
                obj_ari.par.set_base_loop();
                CAMERA.follow_point_instant(obj_ari.x, obj_ari.y);
                CAMERA.follow_instance(obj_ari);

                if destination != undefined {
                    obj_ari.x = destination.pos.x;
                    obj_ari.y = destination.pos.y;
                }

                if ARI.held_animal_id != undefined {
                    obj_ari.summon_held_animal();
                }
            }

            if grant_items && !array_is_empty(cutscene_data.given_items) {
                mist_give_items_after_scene(
                    cutscene_data.given_items,
                    cutscene_data.when_sleeping || cutscene_data.ends_day
                        ? player_wake_position()
                        : new LocationPosition(CURRENT_LOCATION_ID, Vec2(obj_ari.x, obj_ari.y)),
                );
            }

            if self.active_cutscene.refreshes_room_layers {
                setup_room();
            }
        }

        mist_restore_ari_outfit();

        if self.active_cutscene.prevent_eod_music_stop {
            Game.prevent_eod_music_stop = true;
        }

        if self.active_cutscene.silence_music_after_scene {
            self.halt_music_until_room_swap = true;
        }

        if self.active_cutscene.post_scene_tutorial != undefined
            && !ARI.tutorials_seen[self.active_cutscene.post_scene_tutorial]
        {
            await_popup(spawn_tutorial, [self.active_cutscene.post_scene_tutorial]);
        }

        //
        self.blackboard.clear();

        if instance_exists(obj_ari) {
            handle_child_on_par(obj_ari.par);
        }

        //
        trace("Done cleaning up {}", self.active_cutscene.id);
        var refresh_music = self.active_cutscene.refresh_music;
        self.active_cutscene = undefined;
        self.runtime = undefined;
        self.running = false;

        //
        if !self.queued_scenes.is_empty() {
            self.run_scene(self.queued_scenes.pop());
        }

        restore_lost_items(GRID.lost_items);

        npas_room_start();
        //
        if WEATHER.atmosphere != undefined {
            WEATHER.set_atmosphere(WEATHER.atmosphere.id);
        }

        INTERIOR_WINDOW_TIME_OVERRIDE = undefined;

        if refresh_music && ARI.end_of_day_status == undefined {
            MUSIC_PLAYER.refresh();
            AMBIENCE_PLAYER.refresh();
        }

        refresh_achievements([
            Requirement.SeenCutscene,
            Requirement.HasSpouse,
            Requirement.HasBestFriend,
            Requirement.HasPartner,
            Requirement.IsDating,
        ]);
    }

    function place_on_runtime_blackboard(name, value) {
        self.blackboard.set(name, value);
    }

    function get_from_runtime_blackboard(name) {
        return self.blackboard.get(name);
    }

    //
    function mark_scene_has_played(scene) {
        self.scene_history.insert(scene);
        self.scenes_played_today.insert(scene);
        T2R.write(format("cutscene_seen_{}", scene), 1.0);
    }

    //
    function has_played_scene(scene) {
        return self.scene_history.contains(scene);
    }
}

function skip_current_cutscene() {
    if MIST.is_running() == false {
        return;
    }

    game_stats_increment(GAME_STATS, "cutscenes_skipped");
    MIST.skip_in_progress = true;
    SCREEN_FADER.fade_out(FADE_SPEED_CUTSCENE, function() {
        MIST.runtime.end_scene();
        MIST.clean_up_scene();
        MIST.skip_in_progress = false;
    }, [], true);
}

function mist_give_items_after_scene(items, location_position) {
    for (var i = 0, c = array_length(items); i < c; i++) {
        var item = items[i];

        if !requirements_pass(item.requirements) {
            continue;
        }

        var li = new LiveItem(item.item_id);

        if item.infusion != undefined {
            li.infusion = item.infusion;
        }

        if ARI.inventory.can_add(item.item_id, item.quantity) {
            ARI.give_item(li, item.quantity, false, false, false);
        } else if location_position.location_id == CURRENT_LOCATION_ID {
            var pos = location_position.pos.clone();
            if GRID.try_node_index_for_room_position(pos.x, pos.y) == undefined {
                pos.x = clamp(pos.x, 16, GRID.dims.x * 8 - 16);
                pos.y = clamp(pos.y, 16, GRID.dims.y * 8 - 16);
            }
            drop_item(array_create(item.quantity, li), pos.x, pos.y);
        } else {
            GRIDS[location_position.location_id]
                .lost_items
                .push({
                    x: location_position.pos.x,
                    y: location_position.pos.y,
                    items: ListFromArray(array_map(array_create(item.quantity, li), function(v) {
                        return v.clone();
                    })),
                });
        }
    }
}

function mist_glow_effect_calculation(object, property) {
    var anchor = 0.5;
    var range = 0.15;
    var cycle_time = 45;
    var oscillation = sin(property * 2 * pi / cycle_time);
    object.image_alpha = (anchor + oscillation * range) * property;
    return approach(property, 1, 0.05);
}

function scenes_in_test_target(category) {
    var out = [];
    var keys = CUTSCENES.keys();
    for (var i = 0; i < array_length(keys); i++) {
        if CUTSCENES.get(keys[i]).test_target == category {
            array_push(out, keys[i]);
        }
    }
    return out;
}

function trigger_scene_object_removals(scene) {
    var data = CUTSCENES.get(scene);
    for (var i = 0; i < array_length(data.object_removals); i++) {
        var entry = data.object_removals[i];
        var grid = GRIDS[entry.location];
        for (var ni = 0; ni < grid.node_len; ni++) {
            if grid.node_object_id[ni] == entry.object {
                erase_object_node(grid, ni);
                break;
            }
        }
    }
}

function mist_restore_ari_outfit() {
    var cache = MIST.blackboard.try_take("par_asset_cache");
    if cache != undefined {
        ARI.presets.set(ARI.preset_index_selected, cache);
        build_obj_ari_par_from(ARI.animation_assets());
    }
}

function magic_glow_color() {
    var blend_amount = abs(sin(current_time() / 150));
    var blend = blend_rgb32([255, 255, 255], [253, 216, 245], blend_amount);
    return make_color_rgb(blend[0], blend[1], blend[2]);
}

enum SceneTestTarget {
    None,
    General,
    MainStory,
    DragonStory,
    ShootingStar,
    MarriageAndChildren,
    LEN,
}
