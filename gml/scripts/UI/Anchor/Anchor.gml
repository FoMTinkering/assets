function Anchor() constructor {
    self.node_idx_iter = 0;
    self.node_count = 0;
    self.node_registrar = ds_list_create();
    self.pending_node_deletions = ds_list_create();
    self.open_menus = List();
    self.popup_awaiters = List();
    self.screen_canvas = undefined;
    self.screen_canvas_size = Vec2Zero();
    self.current_hovered_node = undefined;
    self.active_pilot = undefined;
    self.night_lut_index = 0;
    self.last_mouse_press = Vec2(MOUSE_GUI_X, MOUSE_GUI_Y);
    self.last_mouse_pos = Vec2(MOUSE_GUI_X, MOUSE_GUI_Y);
    self.text_input_node = undefined;
    self.control_mode = (ON_KBM && !ON_CONSOLE) ? AnchorControl.Point : AnchorControl.Directional;
    self.press_and_hold_reader = new PressAndHoldReader([InputId.Left, InputId.Right, InputId.Up, InputId.Down]);

    self.render_queues = array_create_ext(AnchorLayer.LEN, function() {
        return array_create_ext(NodeId.LEN, function(node_id) {
            switch node_id {
                case NodeId.Text:
                case NodeId.Typewriter:
                case NodeId.Sprite:
                case NodeId.Custom:
                    return ds_list_create();
                default:
                    return undefined;
            }
        });
    });

    //
    function initialize() {
        self.screen_canvas_size.x = CAMERA.view_width;
        self.screen_canvas_size.y = CAMERA.view_height;

        //
        //
        //
        //
        //
        self.screen_canvas = self.canvas(undefined, 1000, AnchorLayer.WorldSpace)
            .set_size_to_screen()
            .set_label("ANCHOR_SCREEN_CANVAS");

        self.language_refresh();
    }

    //
    function shutdown() {
        while self.open_menus.count() > 0 {
            var menu = self.open_menus.first();
            menu.on_free();
            self.open_menus.remove(0);
            PAUSE_STATUS = remove_flag(PAUSE_STATUS, menu.data.pause);
        }
        self.free_node(self.screen_canvas);
        self.clear_pending_nodes();
    }

    //
    function get_true_size() {
        return self.screen_canvas_size.clone();
    }

    //
    //
    //
    function set_gui_size(width, height) {
        self.screen_canvas_size.x = width;
        self.screen_canvas_size.y = height;
        for (var i = 0, c = ds_list_size(self.node_registrar); i < c; i++) {
            var node = self.node_registrar[| i];
            if node.event_callbacks.gui_resize != undefined {
                function_execute_alt(
                    node.event_callbacks.gui_resize.func,
                    node.event_callbacks.gui_resize.arg_array,
                );
            }
        }
    }

    //
    function get_text_font() {
        return self.default_font;
    }

    //
    function spawn_menu(menu_id, arg1, arg2, arg3, arg4, arg5, arg6) {
        var spawn = function(menu_id, arg1, arg2, arg3, arg4, arg5, arg6) {
            switch menu_id {
                case Menu.Journal: return new JournalMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.BabyJournal: return new BabyJournalMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.DragonShrine: return new DragonShrineMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Store: return new StoreMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Storage: return new StorageMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.RenownChest: return new RenownChestMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Inbox: return new InboxMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Daycare: return new DaycareMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Adoption: return new AdoptionMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Elevator: return new ElevatorMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Calendar: return new CalendarMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Textbox: return new TextboxMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Crafting: return new CraftingMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Museum: return new MuseumMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.ScreenFader: return new ScreenFaderMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Bugger: return new BuggerMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.FarmBuildingSelection: return new FarmBuildingSelectionMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.FishingIndicator: return new FishingIndicatorMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.CraftingSequence: return new CraftingSequenceMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.CaldarusStatueOverlay: return new CaldarusStatueOverlayMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Title: return new TitleMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Load: return new LoadMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Dingaling: return new DingalingMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Popup: return new PopupMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Eod: return new EodMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.RenownSequence: return new RenownSequenceMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Player: return new PlayerMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Relationships: return new RelationshipsMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Almanac: return new AlmanacMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.QuestLog: return new QuestLogMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Customization: return new CustomizationMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Map: return new MapMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Settings: return new SettingsMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Spellcasting: return new SpellcastingMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.InfoHud: return new InfoHudMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.InfoToasts: return new InfoToastsMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.ItemToasts: return new ItemToastsMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Toolbar: return new ToolbarMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Vitals: return new VitalsMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.GlyphGuide: return new GlyphGuideMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Mines: return new MinesMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Animal: return new AnimalMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.SellAnimals: return new SellAnimalsMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Credits: return new CreditsMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                case Menu.Gossip: return new GossipMenu(arg1, arg2, arg3, arg4, arg5, arg6);
                default: impossible("Menu not set up in Anchor::spawn_menu: {Menu}", menu_id);
            }
        }

        //
        if GAME_STATS != undefined && !menu_is_hud(menu_id) {
            GAME_STATS.menu_opens[$ menu_to_string(menu_id)] += 1;
        }

        var menu = spawn(menu_id, arg1, arg2, arg3, arg4, arg5, arg6);
        self.open_menus.push(menu);
        return menu;
    }

    //
    //
    function get_menu(menu_type) {
        var len = self.open_menus.count();
        var output = undefined;
        for (var i = 0; i < len; i++) {
            var menu = self.open_menus.get(i);
            if menu.type == menu_type {
                if DEBUG_ASSERTIONS {
                    assert_eq(
                        output,
                        undefined,
                        "Attempted to get menu '{Menu}' by type, but more than one was open!",
                        menu_type,
                    );
                    output = menu;
                } else {
                    return menu;
                }
            }
        }
        return output;
    }

    function popup_is_open() {
        return self.open_menus.any(function(e) {
            var valid_to_check = e.type == Menu.Popup && e.spawned && e[$ "is_tooltip"] != true;
            return valid_to_check && !e.free_requested;
        });
    }

    function on_begin_step() {
        if DEBUG_TOOLS {
            var span = profile_span_start("Anchor::on_begin_step");
        }

        var mouse_gui_x = MOUSE_GUI_X;
        var mouse_gui_y = MOUSE_GUI_Y;
        if INPUT.pressed(InputId.LeftMouse) {
            self.last_mouse_press.x = mouse_gui_x;
            self.last_mouse_press.y = mouse_gui_y;
        }
        if self.text_input_node != undefined {
            for (var i = 0; i < array_length(KEYBOARD_INPUTS); i++) {
                var keycode = KEYBOARD_INPUTS[i];
                if keycode == vk_enter {
                    continue;
                }
                INPUT.raw_keyboard[i] = DigitalStatus.Off;
            }
        }

        //
        //
        //
        //
        //
        //
        //
        var any_mouse_button_pressed = false;
        for (var i = 0; i < array_length(INPUT.raw_mouse); i++) {
            if
                has_flag(INPUT.raw_mouse[i], DigitalStatus.Pressed)
                || has_flag(INPUT.raw_mouse[i], DigitalStatus.On)
            {
                any_mouse_button_pressed = true;
                break;
            }
        }

        //
        //
        var mouse_is_moving =
            mouse_gui_x != self.last_mouse_pos.x
            || mouse_gui_y != self.last_mouse_pos.y;

        //
        //
        //
        var mouse_is_active = mouse_is_moving || any_mouse_button_pressed;

        //
        //
        //
        //
        //
        var skip_pilot_input = false;

        //
        var directional_input_pressed = self.press_and_hold_reader.process();

        var pilot_is_set = self.active_pilot != undefined;
        if self.in_point_control() && pilot_is_set && (directional_input_pressed || ON_GAMEPAD)  {
            self.switch_control(AnchorControl.Directional, "Directional input was pressed with a pilot active");

            //
            //
            if self.active_pilot != undefined && self.current_hovered_node == undefined {
                skip_pilot_input = true;
            }

            //
            self.try_pilot_hover();
        } else if any_mouse_button_pressed {
            self.switch_control(AnchorControl.Point, "A mouse button was pressed");
        }

        self.night_lut_index = self.get_current_night_lut_index();

        var regenerate_pause_status = false;
        for (var i = 0; i < self.open_menus.count(); i++) {
            var menu = self.open_menus.get(i);
            if menu.free_requested {
                menu.free();
                self.open_menus.remove(i);
                i -= 1;
                if menu.data.pause != PauseStatus.EMPTY {
                    regenerate_pause_status = true;
                    PAUSE_STATUS = remove_flag(PAUSE_STATUS, menu.data.pause);
                }
            }
        }

        //
        //
        while !self.popup_awaiters.is_empty() && !self.popup_is_open() {
            var awaiter = self.popup_awaiters.remove(0);
            function_execute_alt(awaiter.func, awaiter.args);
        }

        if is_world_room(room()) && regenerate_pause_status {
            for (var i = 0; i < self.open_menus.count(); i++) {
                var menu = self.open_menus.get(i);
                PAUSE_STATUS |= menu.data.pause;
            }

            if PAUSE_STATUS == PauseStatus.EMPTY
                && instance_exists(obj_ari)
                && self.get_menu(Menu.Eod) == undefined
            {
                CAMERA.follow_instance_instant(obj_ari);
            }
        }

        if is_world_room(room()) {
            var hud_status = hud_should_show();
            if hud_status != HUD_TARGET {
                if hud_status {
                    request_hud_show();
                } else {
                    request_hud_hide();
                }
                HUD_TARGET = hud_status;
            }
        }

        //
        self.clear_pending_nodes();

        //
        if !skip_pilot_input && self.active_pilot != undefined && self.in_directional_control() {
            for (var i = 0; i < 4; i++) {
                switch i {
                    case 0:
                        var pressed = self.press_and_hold_reader.pressed[InputId.Left];
                        var cardinal = Cardinal.West;
                        break;
                    case 1:
                        var pressed = self.press_and_hold_reader.pressed[InputId.Right];
                        var cardinal = Cardinal.East;
                        break;
                    case 2:
                        var pressed = self.press_and_hold_reader.pressed[InputId.Up];
                        var cardinal = Cardinal.North;
                        break;
                    case 3:
                        var pressed = self.press_and_hold_reader.pressed[InputId.Down];
                        var cardinal = Cardinal.South;
                        break;
                }
                if pressed {
                    var movement = self.active_pilot.find_first_acceptable_node(
                        self.active_pilot.position.x,
                        self.active_pilot.position.y,
                        cardinal,
                    );
                    switch movement.type {
                        case PilotMovementReturnType.Freeze: break;
                        case PilotMovementReturnType.Movement:
                            self.active_pilot.position.x = movement.xx;
                            self.active_pilot.position.y = movement.yy;
                            self.try_pilot_hover();
                            break;
                        case PilotMovementReturnType.SwapPilot:
                            movement.pilot.set_position(movement.x, movement.y);
                            self.set_active_pilot(movement.pilot);
                            break;
                        default: impossible("Unexpected PilotMovementReturnType: {}", movement.type);
                    }
                }
            }
        }

        if DEBUG_TOOLS {
            var node_span = profile_span_start("Anchor::on_begin_step::nodes");
        }

        //
        //
        //
        //
        //
        //
        var starting_count = self.node_count;
        var ending_bound = 0;

        while true {

            for (var i = self.node_count - 1; i >= ending_bound; i--) {

                var node = self.node_registrar[| i];

                if node.run_logic && node.safe_enabled && !node.marked_for_death {

                    //
                    if node.listens_for_hovers && node.safe_unlocked {

                        //
                        var mouse_in_node =
                            self.point_in_node(node, mouse_gui_x, mouse_gui_y)
                            && (
                                !node.canvas.render_partial_info.enabled
                                || self.point_in_node(node.canvas, mouse_gui_x, mouse_gui_y)
                            );

                        if !node.in_hover && mouse_is_active && mouse_in_node {

                            //
                            self.switch_control(AnchorControl.Point, "User hovered over a node");
                            self.hover_node(node, true);
                        }

                        //
                        if node.in_hover {
                            node.hover_frames += 1;
                            if
                                self.in_point_control()
                                && !mouse_in_node
                                && (!node.in_tap || node.mouse_can_escape_tap_flag)
                            {
                                self.release_hovered_node();
                            } else {
                                var tap = node.listens_for_taps && self.take_tap();

                                //
                                //
                                if tap {
                                    node.in_tap = true;
                                    node.tap_tick = TICK;
                                    if node.depress_children {
                                        node.set_child_offset(0, 1);
                                    }
                                    if any_mouse_button_pressed {
                                        node.tap_is_deferred = true;
                                    } else {
                                        self.tap_node(node);
                                    }
                                }

                                if node.hover_outline != undefined && node.is_unlocked() {
                                    node.hover_outline.set_enabled(!node.in_tap);
                                }
                            }
                        }
                        //
                        if node.in_tap {
                            if node.tap_repeating {
                                var duration = TICK - node.tap_tick;
                                static HOLD_LEN = fiddle_get("ui/misc/holding/start");
                                static HOLD_PERIOD = fiddle_get("ui/misc/holding/period");
                                if duration >= HOLD_LEN && (duration - HOLD_LEN) % HOLD_PERIOD == 0 {
                                    self.tap_node(node);
                                }
                            }

                            if self.tap_released() {
                                if node.tap_is_deferred {
                                    self.tap_node(node);
                                    node.tap_is_deferred = false;
                                }
                                node.in_tap = false;
                                node.tap_tick = undefined;
                                node.set_child_offset(0, 0);
                            }
                        }
                    }

                    //
                    if node.lut_info.speed != 0 {
                        if node.lut_info.index + node.lut_info.speed > node.lut_info.slot_count {
                            node.lut_info.index = 0;
                        } else {
                            node.lut_info.index += node.lut_info.speed;
                        }
                    }

                    //
                    if node.type == NodeId.Text {
                        if node.strike_through_node != undefined {
                            node.strike_through_node.update();
                        }

                        if node.takes_input {
                            if node.cursor_timer == 0 {
                                node.cursor_timer = TEXT_CURSOR_BLINK_INTERVAL;
                            } else {
                                node.cursor_timer -= 1;
                            }
                            var new_request = node.text;

                            var keyboard_str = keyboard_string();
                            if keyboard_str != "" {
                                node.cursor_timer = TEXT_CURSOR_BLINK_INTERVAL;
                                var passes = true;
                                var str = node.text + keyboard_str;
                                if node.max_width != undefined {
                                    if string_width_font(str, node.font) > node.max_width {
                                        passes = false;
                                    }
                                } else if node.max_characters != undefined &&  string_length(str) > node.max_characters {
                                    passes = false;
                                }
                                if passes {
                                    new_request = fmt("{}{}", new_request, keyboard_str);
                                    node.set_text(new_request);
                                }
                            }
                            if keyboard_check_pressed(vk_backspace) && string_length(node.get_text()) > 0 {
                                node.cursor_timer = TEXT_CURSOR_BLINK_INTERVAL;
                                node.set_text(string_copy(
                                    node.get_text(),
                                    1,
                                    string_length(new_request) - 1
                                ));
                            }
                            if keyboard_check(vk_backspace) {
                                node.cursor_timer = TEXT_CURSOR_BLINK_INTERVAL;
                                if !node.backspace_info.active {
                                    ++node.backspace_info.delay_timer;
                                    if node.backspace_info.delay_timer > node.backspace_info.delay_timer_max {
                                        node.backspace_info.active = true;
                                    }
                                } else {
                                    ++node.backspace_info.timer;
                                    if node.backspace_info.timer mod 2 == 0
                                        && string_length(node.get_text()) > 0
                                    {
                                        node.set_text(string_copy(
                                            node.get_text(),
                                            1,
                                            string_length(new_request) - 1
                                        ));
                                    }
                                }
                            }
                            if keyboard_check_released(vk_backspace) {
                                node.backspace_info.active = false;
                                node.backspace_info.timer = 0;
                                node.backspace_info.delay_timer = 0;
                            }
                        }
                    }

                    //
                    else if node.type == NodeId.Typewriter && !node.characters.is_empty() {
                        node.cache_is_dirty = true;

                        //
                        if node.pause {
                            node.pause_timer -= 1;
                            if node.pause_timer <= 0 {
                                node.pause = false;
                            }
                        }

                        //
                        if !node.pause && !FOCUS.out_of_focus() {
                            if node.counter == 0 && node.override_sound != undefined {
                                TANGO.play(node.override_sound);
                            }
                            var play_sound = SETTINGS.get("sound_vocal_text") && node.counter mod 2 == 0 && node.speaker_sound_path != undefined;
                            node.counter = min(node.counter + 0.5, node.characters.count() - 1);
                            if !node.is_resting() {
                                var character = node.characters.get(floor(node.counter));
                                switch character.char {
                                    case ",":
                                        node.pause = true;
                                        node.pause_timer = 7;
                                        break;
                                    case ".":
                                    case "?":
                                    case "!":
                                        node.pause = true;
                                        node.pause_timer = 12;
                                        break;
                                    default:
                                        //
                                        if play_sound {
                                            TANGO.play(node.speaker_sound_path);

                                            if MIST.blackboard.get("caldarus_textbox_hack") == true {
                                                TANGO.play("SoundEffects/NPCs/Vocal/TextBlipCaldarus");
                                            }

                                            if MIST.blackboard.get("linnet_textbox_hack") == true {
                                                TANGO.play("SoundEffects/NPCs/Vocal/TextBlipWiscar");
                                            }
                                        }
                                        break;
                                }

                                //
                                if character.shake {
                                    CAMERA.add_trauma(0.6);
                                }
                            }
                        }
                    }

                    //
                    else if node.type == NodeId.Sprite {
                        //
                        if node.text_label != undefined {
                            node.text_label.update();
                        }

                        //
                        if node.speed != 0 && node.frame_count > 1 {
                            if node.at_animation_end() && node.event_callbacks.animation_end != undefined {
                                function_execute_alt(
                                    node.event_callbacks.animation_end.func,
                                    node.event_callbacks.animation_end.arg_array
                                );
                            }
                            node.set_index(node.index + node.get_index_inc());
                        }

                        //
                        if node.key_sprite_target != undefined {
                            var targ = node.key_sprite_target;

                            if !targ.unlocked {
                                node.set_sprite(node.locked_sprite);
                            } else if targ.in_tap {
                                node.set_sprite(node.pressed_sprite);
                            } else if targ.in_hover {
                                if !targ.listens_for_taps {
                                    node.set_sprite(node.hovered_untappable_sprite);
                                } else {
                                    node.set_sprite(node.hovered_sprite);
                                }
                            } else if targ.is_selected() {
                                node.set_sprite(node.selected_sprite);
                            } else {
                                node.set_sprite(node.enabled_sprite);
                            }
                        }
                    }

                    //
                    if node.canvas != undefined {
                        node.offset.x = node.canvas.offset.x + node.canvas.render_partial_info.x;
                        node.offset.y = node.canvas.offset.y + node.canvas.render_partial_info.y;
                    }

                    //
                    if node.event_callbacks.think != undefined {
                        function_execute_alt(
                            node.event_callbacks.think.func,
                            node.event_callbacks.think.arg_array
                        );
                    }
                }
            }

            //
            if starting_count == self.node_count {
                break;
            } else {
                //
                ending_bound = self.node_count - (self.node_count - starting_count);
                starting_count = self.node_count;
            }
        }

        if DEBUG_TOOLS {
            profile_span_stop(node_span);
            var think_span = profile_span_start("Anchor::on_begin_step::think");
        }

        //
        for (var i = 0, c = self.open_menus.count(); i < c; i++) {
            var menu = self.open_menus.get(i);
            menu.think();
        };

        if DEBUG_TOOLS {
            profile_span_stop(think_span);
        }

        //
        self.clear_pending_nodes();

        //
        self.last_mouse_pos.x = mouse_gui_x;
        self.last_mouse_pos.y = mouse_gui_y;

        //
        var node = self.current_hovered_node;
        if ON_GAMEPAD {
            CURSOR.type = CursorType.None;
        } else if node != undefined {
            CURSOR.type = node.in_tap ? CursorType.Tap : CursorType.Point;
        } else {
            CURSOR.type = CursorType.Default;
        }

        if DEBUG_TOOLS {
            profile_span_stop(span);
        }
    }

    function on_draw_gui(resize_amount) {
        self.clear_pending_nodes();
        self.compute_node_caches();
        self.render(resize_amount);
    }

    function on_room_start() {
        for (var i = 0, c = self.node_count; i < c; i++) {
            var node = self.node_registrar[| i];
            if node.event_callbacks.room_start != undefined {
                function_execute_alt(
                    node.event_callbacks.room_start.func,
                    node.event_callbacks.room_start.arg_array
                );
            }
        }
    }

    function compute_node_caches() {
        for (var node_iter = 0; node_iter < self.node_count; node_iter++) {
            var node = self.node_registrar[| node_iter];
            if !node.safe_enabled || !node.cache_is_dirty {
                continue;
            }

            var parent = node.parent;

            switch node.type {
                case NodeId.Canvas: {
                    node.cache_is_dirty = false;
                    process_node_dirty_child(node);
                    if node.parent == undefined {
                        node.cache_x = node.x;
                        node.cache_y = node.y;
                        process_node_bbox(node);
                        continue; //
                    } else {
                        process_node_alpha(node, node.parent);
                        process_node_position(node, node.parent);
                        process_node_bbox(node);
                        process_node_layer(node);
                    }
                    break;
                }
                case NodeId.Typewriter: {
                    if node.cache_is_dirty {
                        process_node_dirty_child(node);
                        process_node_alpha(node, parent);
                        process_node_position(node, parent);
                        process_node_bbox(node);
                        process_node_layer(node);
                    }
                    break;
                }
                case NodeId.Text: {
                    if node.cache_is_dirty {
                        process_node_dirty_child(node);
                        node.update_display_text();
                        if DEBUG_ASSERTIONS {
                            node.check_spillover();
                        }
                        process_node_alpha(node, parent);
                        process_node_position(node, parent);
                        process_node_bbox(node);
                        process_node_layer(node);
                    }
                    break;
                }
                case NodeId.Sprite: {
                    if node.cache_is_dirty {
                        process_node_dirty_child(node);
                        if !node.is_nine_slice {
                            //
                            node.width = node.spr_width * node.scale_x;
                            node.height = node.spr_height * node.scale_y;
                        }
                        process_node_alpha(node, parent);
                        process_node_position(node, parent);
                        process_node_bbox(node);
                        process_node_layer(node);
                    }
                    break;
                }
                case NodeId.Custom: {
                    if node.cache_is_dirty {
                        process_node_dirty_child(node);
                        process_node_alpha(node, parent);
                        process_node_position(node, parent);
                        process_node_bbox(node);
                        process_node_layer(node);
                    }
                    break;
                }
                case NodeId.Positional: {
                    if node.cache_is_dirty {
                        process_node_dirty_child(node);
                        process_node_position(node, parent);
                        process_node_alpha(node, parent);
                        process_node_bbox(node);
                        process_node_layer(node);
                    }
                    break;
                }
                default:  {
                    impossible("Unrecognized node type: {}", node.type);
                    break;
                }
            }

            //
            if DEBUG_ASSERTIONS && parent.type != NodeId.Canvas {
                assert(
                    node.z < parent.z,
                    "Child behind node!\nChild ({AnchorNode}) z: {}\nParent ({AnchorNode}) z: {}",
                    node,
                    node.z,
                    parent,
                    parent.z,
                );
            }
        }
    }

    function render(resize_amount) {
        if DEBUG_TOOLS {
            gpu_push_group("anchor");
        }
        var output_size = window_get_output_dimensions();
        draw_camera_set_view_size(output_size[0] / resize_amount, output_size[1] / resize_amount);

        draw_clear_depth(1.0);
        gpu_set_depth_test(cmpfunc_lessequal);
        gpu_set_blendmode_ext(bm_one, bm_inv_src_alpha);

        var original_depth = gpu_get_depth();
        var original_scissor = gpu_get_scissor();
        var current_scissor = [0, 0, 0, 0];
        var in_scissor = false;

        var rendered_anything = false;
        for (var anchor_layer_id = 0; anchor_layer_id < AnchorLayer.LEN; anchor_layer_id++) {
            var layer_render_queue = self.render_queues[anchor_layer_id];

            rendered_anything = false;

            gpu_set_extra(UberShaderKind.AnchorSprite, 0, 0, 0);
            var queue = layer_render_queue[NodeId.Sprite];
            for (var i = 0, c = ds_list_size(queue); i < c; i++) {
                var node = queue[| i];
                if node.safe_enabled == false
                    || node.cache_alpha <= 0
                    || node.cache_bbox_top > self.screen_canvas.height
                    || node.cache_bbox_bottom < 0
                {
                    continue;
                }

                rendered_anything = true;

                if node.canvas.render_partial_info.enabled {
                    if in_scissor == false ||
                        current_scissor[0] != node.canvas.cache_x
                        || current_scissor[1] != node.canvas.cache_y
                        || current_scissor[2] != node.canvas.render_partial_info.width
                        || current_scissor[3] != node.canvas.render_partial_info.height
                    {
                        current_scissor[0] = node.canvas.cache_x;
                        current_scissor[1] = node.canvas.cache_y;
                        current_scissor[2] = node.canvas.render_partial_info.width;
                        current_scissor[3] = node.canvas.render_partial_info.height;

                        gpu_set_scissor(
                            current_scissor[0],
                            current_scissor[1],
                            current_scissor[2],
                            current_scissor[3],
                        );
                        in_scissor = true;
                    }
                } else if in_scissor {
                    gpu_reset_scissor(original_scissor);
                    in_scissor = false;
                }

                if node.outline_sprite != undefined {
                    gpu_set_depth(node.z + 1);
                    draw_sprite_ext(
                        node.outline_sprite,
                        0,
                        node.cache_x + sprite_get_xoffset(node.outline_sprite),
                        node.cache_y + sprite_get_yoffset(node.outline_sprite),
                        node.scale_x,
                        node.scale_y,
                        0.0,
                        node.outline_color,
                        node.cache_alpha,
                    );
                }

                //
                var lut_node = undefined;
                if node.lut_info.enabled {
                    lut_node = node;
                }
                if lut_node != undefined {
                    var column_idx = lut_node.get_lut_index();
                    if column_idx > 0 {
                        shader_set_texture("u_LutTexture", lut_node.lut_info.texture, 0, "u_LutTexelSize");
                        gpu_set_extra(UberShaderKind.AnchorSprite, lut_node.lut_info.uvs[0], lut_node.lut_info.uvs[1], column_idx);
                    }
                }

                if node.is_nine_slice {
                    if node.width > 0 && node.height > 0 {
                        var w = node.spr_width;
                        var h = node.spr_height;
                        var cw = node.width - w * 2;
                        var ch = node.height - h * 2;
                        var frame_count = node.frame_count;

                        var xx = node.cache_x;
                        var yy = node.cache_y;
                        var nw = node.width;
                        var nh = node.height;
                        var color = node.color;
                        var alpha = node.cache_alpha;
                        var index = node.index;
                        var sprite = node.sprite;

                        gpu_set_depth(node.z);

                        //
                        draw_sprite_stretched_ext(
                            sprite,
                            0 * frame_count + index,
                            xx,
                            yy,
                            w,
                            h,
                            color,
                            alpha,
                            [0, 0],
                        );
                        draw_sprite_stretched_ext(
                            sprite,
                            2 * frame_count + index,
                            xx + nw - w,
                            yy,
                            w,
                            h,
                            color,
                            alpha,
                            [0, 0],
                        );
                        draw_sprite_stretched_ext(
                            sprite,
                            6 * frame_count + index,
                            xx,
                            yy + nh - h,
                            w,
                            h,
                            color,
                            alpha,
                            [0, 0],
                        );
                        draw_sprite_stretched_ext(
                            sprite,
                            8 * frame_count + index,
                            xx + nw - w,
                            yy + nh - h,
                            w,
                            h,
                            color,
                            alpha,
                            [0, 0],
                        );

                        draw_sprite_stretched_ext(
                            sprite,
                            1 * frame_count + index,
                            xx + w,
                            yy,
                            cw,
                            h,
                            color,
                            alpha,
                            [0, 0],
                        );

                        draw_sprite_stretched_ext(
                            sprite,
                            3 * frame_count + index,
                            xx,
                            yy + h,
                            w,
                            ch,
                            color,
                            alpha,
                            [0, 0],
                        );
                        draw_sprite_stretched_ext(
                            sprite,
                            5 * frame_count + index,
                            xx + nw - w,
                            yy + h,
                            w,
                            ch,
                            color,
                            alpha,
                            [0, 0],
                        );
                        draw_sprite_stretched_ext(
                            sprite,
                            7 * frame_count + index,
                            xx + w,
                            yy + nh - h,
                            cw,
                            h,
                            color,
                            alpha,
                            [0, 0],
                        );

                        //
                        draw_sprite_stretched_ext(
                            sprite,
                            4 * frame_count + index,
                            xx + w,
                            yy + h,
                            cw,
                            ch,
                            color,
                            alpha,
                            [0, 0],
                        );
                    }
                } else {
                    gpu_set_depth(node.z);
                    draw_sprite_ext(
                        node.sprite,
                        node.index,
                        node.cache_x + sprite_get_xoffset(node.sprite),
                        node.cache_y + sprite_get_yoffset(node.sprite),
                        node.scale_x,
                        node.scale_y,
                        0,
                        node.color,
                        node.cache_alpha,
                    );
                }

                if lut_node != undefined {
                    gpu_set_extra(UberShaderKind.AnchorSprite, 0, 0, 0);
                }
            }

            //
            var queue = layer_render_queue[NodeId.Text];
            for (var i = 0, c = ds_list_size(queue); i < c; i++) {
                var node = queue[| i];
                if node.safe_enabled == false
                    || node.cache_alpha <= 0
                    || node.cache_bbox_top > self.screen_canvas.height
                    || node.cache_bbox_bottom < 0
                    || node.sprite_font == undefined
                {
                    continue;
                }

                //
                if node.canvas.render_partial_info.enabled {
                    if in_scissor == false ||
                        current_scissor[0] != node.canvas.cache_x
                        || current_scissor[1] != node.canvas.cache_y
                        || current_scissor[2] != node.canvas.render_partial_info.width
                        || current_scissor[3] != node.canvas.render_partial_info.height
                    {
                        current_scissor[0] = node.canvas.cache_x;
                        current_scissor[1] = node.canvas.cache_y;
                        current_scissor[2] = node.canvas.render_partial_info.width;
                        current_scissor[3] = node.canvas.render_partial_info.height;

                        gpu_set_scissor(
                            current_scissor[0],
                            current_scissor[1],
                            current_scissor[2],
                            current_scissor[3],
                        );
                        in_scissor = true;
                    }
                } else if in_scissor {
                    gpu_reset_scissor(original_scissor);
                    in_scissor = false;
                }

                if node.lut_info.enabled {
                    var column_idx = node.get_lut_index();
                    if column_idx > 0 {
                        shader_set_texture("u_LutTexture", node.lut_info.texture, 0, "u_LutTexelSize");
                        gpu_set_extra(UberShaderKind.AnchorSprite, node.lut_info.uvs[0], node.lut_info.uvs[1], column_idx);
                    }
                }

                var x_off = 0;
                var str = node.display_text;
                //
                for (var j = 1; j <= string_length(str); j++) {
                    var char = string_char_at(str, j);
                    var index = string_pos(char, node.sprite_font.order) - 1;
                    if index >= 0 {
                        gpu_set_depth(node.z);
                        draw_sprite_ext(
                            node.sprite_font.sprite,
                            index,
                            node.cache_x + x_off + sprite_get_xoffset(node.sprite_font.sprite),
                            node.cache_y - sprite_get_yoffset(node.sprite_font.sprite),
                            1.0,
                            1.0,
                            0.0,
                            node.color,
                            node.cache_alpha,
                        );
                        x_off += node.sprite_font.characters[$ char];
                    }
                }

                if node.lut_info.enabled {
                    gpu_set_extra(UberShaderKind.AnchorSprite, 0, 0, 0);
                }
            }

            if in_scissor {
                gpu_reset_scissor(original_scissor);
                in_scissor = false;
            }

            //
            gpu_set_extra(UberShaderKind.AnchorText, 0, 0, 0);
            var queue = layer_render_queue[NodeId.Text];
            var c = ds_list_size(queue);
            for (var i = 0; i < c; i++) {
                var node = queue[| i];
                if node.safe_enabled == false
                    || node.cache_alpha <= 0
                    || node.cache_bbox_top > self.screen_canvas.height
                    || node.cache_bbox_bottom < 0
                    || node.sprite_font != undefined
                {
                    continue;
                }
                rendered_anything = true;
                draw_set_font(node.font);
                if node.takes_input {
                    var has_cursor = string_pos("|", node.display_text);
                    if node.cursor_timer == 0 {
                        if has_cursor {
                            node.display_text = string_replace(node.display_text, "|", "");
                        } else {
                            node.display_text += "|";
                        }
                    }
                }

                var lut_source = node;
                if node.lut_info.enabled == false && node.canvas.lut_info.enabled {
                    lut_source = node.canvas;
                }
                if lut_source.lut_info.enabled {
                    shader_set_texture("u_LutTexture", lut_source.lut_info.texture, 0, "u_LutTexelSize");
                    gpu_set_extra(UberShaderKind.AnchorText, lut_source.lut_info.uvs[0], lut_source.lut_info.uvs[1], lut_source.get_lut_index());
                } else {
                    gpu_set_extra(UberShaderKind.AnchorText, 0, 0, 0);
                }

                if node.canvas.render_partial_info.enabled {
                    if in_scissor == false ||
                        current_scissor[0] != node.canvas.cache_x
                        || current_scissor[1] != node.canvas.cache_y
                        || current_scissor[2] != node.canvas.render_partial_info.width
                        || current_scissor[3] != node.canvas.render_partial_info.height
                    {
                        current_scissor[0] = node.canvas.cache_x;
                        current_scissor[1] = node.canvas.cache_y;
                        current_scissor[2] = node.canvas.render_partial_info.width;
                        current_scissor[3] = node.canvas.render_partial_info.height;

                        gpu_set_scissor(
                            current_scissor[0],
                            current_scissor[1],
                            current_scissor[2],
                            current_scissor[3],
                        );
                        in_scissor = true;
                    }
                } else if in_scissor {
                    gpu_reset_scissor(original_scissor);
                    in_scissor = false;
                }

                var render_x = node.cache_x;
                switch node.text_align {
                    case TextAlign.Left:
                        draw_set_halign(HorizontalOffset.Left);
                        break;
                    case TextAlign.Center:
						var ww = node.width / 2;
						render_x += floor(ww) + (node.width % 2 == 1 ? 0.5 : 0);
                        draw_set_halign(HorizontalOffset.Middle);
                        break;
                    case TextAlign.Right:
                        draw_set_halign(HorizontalOffset.Right);
                        break;
                    default:
                        impossible();
                }

                //
                gpu_set_depth(node.z);
                draw_text_with_color(
                    render_x,
                    node.cache_y,
                    node.display_text,
                    1.0,
                    1.0,
                    node.color,
                    node.cache_alpha,
                    node.line_height,
                );
            }
            if c > 0 {
                if in_scissor {
                    gpu_reset_scissor(original_scissor);
                    in_scissor = false;
                }
            }

            var queue = layer_render_queue[NodeId.Typewriter];
            var c = ds_list_size(queue);
            if c > 0 {
                gpu_set_extra(UberShaderKind.AnchorText, 0, 0, 0);
            }
            for (var i = 0; i < c; i++) {
                var node = queue[| i];
                if node.safe_enabled == false
                    || node.cache_alpha <= 0
                    || node.cache_bbox_top > self.screen_canvas.height
                    || node.cache_bbox_bottom < 0
                {
                    continue;
                }

                if node.characters.is_empty() {
                    continue;
                }
                rendered_anything = true;

                gpu_set_depth(node.z);

                draw_set_font(node.font);
                draw_set_halign(HorizontalOffset.Left);
                draw_set_valign(VerticalOffset.Top);

                shader_set_texture("u_LutTexture", node.lut_info.texture, 0, "u_LutTexelSize");
                gpu_set_extra(UberShaderKind.AnchorText, node.lut_info.uvs[0], node.lut_info.uvs[1], node.get_lut_index());

                if node.canvas.render_partial_info.enabled {
                    if in_scissor == false ||
                        current_scissor[0] != node.canvas.cache_x
                        || current_scissor[1] != node.canvas.cache_y
                        || current_scissor[2] != node.canvas.render_partial_info.width
                        || current_scissor[3] != node.canvas.render_partial_info.height
                    {
                        current_scissor[0] = node.canvas.cache_x;
                        current_scissor[1] = node.canvas.cache_y;
                        current_scissor[2] = node.canvas.render_partial_info.width;
                        current_scissor[3] = node.canvas.render_partial_info.height;

                        gpu_set_scissor(
                            current_scissor[0],
                            current_scissor[1],
                            current_scissor[2],
                            current_scissor[3],
                        );
                        in_scissor = true;
                    }
                } else if in_scissor {
                    gpu_reset_scissor(original_scissor);
                    in_scissor = false;
                }

                var text_x = node.cache_x;
                var text_y = node.cache_y;
                for (var i = 0; i <= floor(node.counter); i++) {
                    var character = node.characters.get(i);

                    //
                    if character.linebreak {
                        text_x = node.cache_x;
                        text_y += node.line_height;
                        continue;
                    }

                    //
                    if character.char == " " {
                        text_x += 4;
                        continue;
                    }

                    //
                    if character.jitter {
                        var shk = 0.8;
                        draw_text_with_color(
                            text_x + random_range(-shk, shk),
                            text_y + random_range(-shk, shk),
                            character.char,
                            1.0,
                            1.0,
                            node.color,
                            node.cache_alpha
                        );

                    //
                    } else if character.gold || character.purple || character.pink {
                        var index;
                        if character.gold {
                            index = 9;
                        } else if character.purple {
                            index = 15;
                        } else {
                            index = 17;
                        }

                        gpu_set_extra(UberShaderKind.AnchorText, node.lut_info.uvs[0], node.lut_info.uvs[1], index);
                        draw_text_with_color(
                            text_x,
                            text_y,
                            character.char,
                            1.0,
                            1.0,
                            node.color,
                            node.cache_alpha
                        );
                        gpu_set_extra(UberShaderKind.AnchorText, node.lut_info.uvs[0], node.lut_info.uvs[1], node.get_lut_index());

                    //
                    } else {
                        draw_text_with_color(
                            text_x,
                            text_y,
                            character.char,
                            1.0,
                            1.0,
                            node.color,
                            node.cache_alpha
                        );
                    }
                    text_x += string_width(character.char);
                }
            }
            if c > 0 {
                if in_scissor {
                    gpu_reset_scissor(original_scissor);

                    in_scissor = false;
                }
            }

            //
            gpu_reset_extra();
            var queue = layer_render_queue[NodeId.Custom];
            for (var i = 0, c = ds_list_size(queue); i < c; i++) {
                var node = queue[| i];
                if node.event_callbacks.render == undefined {
                    continue;
                }

                var args = [
                    node.cache_x,
                    node.cache_y,
                    node.width,
                    node.height,
                    node.color,
                    node.cache_alpha,
                    node.z,
                ];
                for (var arg_c = 0; arg_c < array_length(node.event_callbacks.render.arg_array); arg_c++) {
                    array_push(args, node.event_callbacks.render.arg_array[arg_c]);
                }
                function_execute_alt(node.event_callbacks.render.func, args);

                rendered_anything = true;
                gpu_set_depth_test(cmpfunc_lessequal);
            }

            if rendered_anything {
                draw_clear_depth(1.0);
            }
        }

        draw_camera_set_view_size(output_size[0], output_size[1]);
        gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);
        gpu_set_depth_test(cmpfunc_always);
        gpu_set_depth(original_depth);

        if DEBUG_TOOLS {
            gpu_pop_group();
        }
    }

    //
    function canvas(parent, z, anchor_layer) {
        if z == undefined {
            z = parent.z - 1;
        }
        var node = new CanvasNode(parent, z, anchor_layer);
        return self.register_node(node);
    }

    //
    function text(parent, z, layer_override) {
        var node = new TextNode(parent, z ?? parent.z - 1, layer_override);
        node.set_text_style("standard");
        return self.register_node(node);
    }

    //
    function typewriter(parent, z, layer_override) {
        var node = new TypewriterNode(parent, z ?? parent.z - 1, layer_override);
        node.set_text_style("standard");
        return self.register_node(node);
    }

    //
    function sprite(parent, z, layer_override) {
        var node = new SpriteNode(parent, z ?? parent.z - 1, layer_override);
        return self.register_node(node);
    }

    //
    //
    function nine_slice(parent, z, layer_override) {
        var node = new SpriteNode(parent, z ?? parent.z - 1, layer_override);
        node.render_as_nine_slice();
        return self.register_node(node);
    }

    //
    function custom(parent, z, layer_override) {
        var node = new CustomNode(parent, z ?? parent.z - 1, layer_override);
        return self.register_node(node);
    }

    //
    function positional(parent, z, layer_override) {
        var node = new PositionalNode(parent, z ?? parent.z - 1, layer_override);
        return self.register_node(node);
    }

    //
    function register_node(node) {
        //
        node.idx = self.node_idx_iter;
        if DEBUG_TOOLS || DEBUG_ASSERTIONS {
            node.spawn_callstack = debug_get_callstack();
        } else {
            node.spawn_callstack = undefined;
        }
        ds_list_add(self.node_registrar, node);
        if node.parent != undefined {
            assert(!node.parent.freed, "Attempted to make a node on a freed parent!");
            array_push(node.parent.children, node);
            node.source_menu = node.parent.source_menu;
        }
        if node.canvas != undefined {
            //
            if node.parent.get_enabled() {
                var queue_list = self.render_queues[node.layer][node.type];
                if queue_list != undefined {
                    ds_list_add(queue_list, node);
                }
            } else {
                node.safe_enabled = false;
            }
        }
        ++self.node_idx_iter;
        ++self.node_count;
        return node;
    }

    //
    //
    //
    function create_ari_node(parent, animation_data, xx, yy, scale, clipping_canvas) {
        var par = new PlayerAnimationRuntime();
        var par_offset = fiddle_deserialize_vec2(fiddle_get("player/par/offset"));
        par.set_cardinal(Cardinal.South);
        animation_data.apply_to_par(par);
        handle_child_on_par(par);
        par.set_animation(AnimationName.Idle);
        par.scale = scale;
        par.clipping_canvas = clipping_canvas;

        return self.custom(parent)
            .set_xy(par_offset.x + xx, par_offset.y + yy)
            .board_set("__par__", par)
            .set_gui_resize_callback(function(par, scale) {
                par.scale = scale;
            }, [par, scale])
            .set_render_callback(function(xx, yy, _width, _height, _color, alpha, z, par, resize) {
                par.alpha = alpha;
                gpu_set_depth(z);

                var old_scissor = undefined;
                if par.clipping_canvas != undefined {
			        old_scissor_region = gpu_get_scissor();
                    var screen_pos = self.get_screen_position(par.clipping_canvas);
                    var part = par.clipping_canvas.render_partial_info;
                    var this_x = screen_pos.x + part.x;
                    var this_y = screen_pos.y + part.y;
                    gpu_set_scissor(
                        this_x,
                        this_y,
                        part.width,
                        part.height,
                    );
                }

                gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);
                par.draw(xx, yy);
                gpu_set_blendmode_ext(bm_one, bm_inv_src_alpha);

                if par.clipping_canvas != undefined {
                    if old_scissor == undefined {
                        gpu_disable_scissor();
                    } else {
                        gpu_set_scissor(old_scissor[0], old_scissor[1], old_scissor[2], old_scissor[3]);
                    }
                }

                par.animate();
            }, [par, scale]);
    }

    //
    function width_for_text_container(text, additional_padding=8, font) {
        font = font == undefined ? ANCHOR.get_text_font() : font;
        return string_width_font(text, font) + additional_padding;
    }

    function text_height(text, width, font, line_height, force_reflow=false) {
        font = font == undefined ? ANCHOR.get_text_font() : font;
        draw_set_font(font);
        return string_height(self.reflow(text, width, font, force_reflow), line_height, I32_MAX);
    }

    //
    function reflow(text, width, font, force=false) {
        if !local_get_info(LocalInfoRequest.AutomaticLinebreaks) && !force {
            return text;
        }
        font = font == undefined ? ANCHOR.get_text_font() : font;
        return string_apply_newlines(text, width, font);
    }

    //
    function get_current_night_lut_index() {
        if !instance_exists(Game) {
            return 0;
        };
        var time = CLOCK.time;
        var start_time = NIGHT_TIME;
        var end_time = NIGHT_TIME + (60 * 25);
        var max_index = 16;
        if time < start_time {
            return 0;
        } else if time > end_time {
            return max_index;
        } else {
            var normalized_pos = time - start_time;
            var normalized_length = end_time - start_time;
            var percentage = real(normalized_pos) / real(normalized_length);
            return floor(max_index * percentage);
        }
    }

    //
    function check_for_click_close(node) {
        return
            self.in_point_control()
            && node.is_unlocked()
            && !FOCUS.out_of_focus()
            && !self.point_in_node(node, MOUSE_GUI_X, MOUSE_GUI_Y)
            && self.take_tap();
    }

    //
    function language_refresh() {
        self.default_font = TEXT_STYLES.standard[$ local_language()];

        for (var i = 0, c = self.node_count; i < c; i++) {
            var node = self.node_registrar[| i];
            if node.type == NodeId.Text {
                if !node.font_is_forced {
                    if node.text_style != undefined {
                        node.set_text_style(node.text_style);
                    } else {
                        node.set_font(node.font);
                    }
                }
                if node.local_key != undefined {
                    var key = node.local_key;
                    node.local_key = undefined;
                    node.set_key(key);
                }
                node.cache_is_dirty = true;
            }
        }
    }

    //
    function enable_node(node, personal) {
        if node.freed {
            if DEBUG_ASSERTIONS {
                crash("Attempted to enable a dead node: {}", node);
            } else {
                warn("Ignoring an attempty to enable a dead node...");
                return;
            }
        }

        if personal == undefined {
            personal = true;
        }
        if personal {
            node.enabled = true;
        }
        node.safe_enabled = node.enabled;
        if node.safe_enabled && node.canvas != undefined {
            var queue_list = self.render_queues[node.cache_layer][node.type];
            if queue_list != undefined {
                ds_list_add(queue_list, node);
            }

            for (var i = 0, c = array_length(node.children); i < c; i++) {
                var child = node.children[i];
                if !child.safe_enabled {
                    self.enable_node(child, false);
                }
            }
        }
    }

    //
    function disable_node(node, personal) {
        if personal == undefined {
            personal = true;
        }
        if personal {
            node.enabled = false;
        }
        node.safe_enabled = false;
        if node.canvas != undefined {
            var queue_list = self.render_queues[node.cache_layer][node.type];
            if queue_list != undefined {
                var pos = ds_list_find_index(queue_list, node);
                if pos != -1 {
                    ds_list_delete(queue_list, pos);
                }
            }
        }
        for (var i = 0, c = array_length(node.children); i < c; i++) {
            var child = node.children[i];
            if child.safe_enabled {
                self.disable_node(child, false);
            }
        }
    }

    //
    function free_children(node) {
        for (var i = 0, c = array_length(node.children); i < c; i++) {
            self.free_node(node.children[i]);
        }
    }

    function free_node(node) {
        if node.marked_for_death {
            return;
        }
        node.marked_for_death = true;
        ds_list_add(self.pending_node_deletions, node);
    }

    function true_free_node(node) {
        if node.freed {
            return;
        }
        node.freed = true;
        if ds_list_find_index(self.node_registrar, node) == -1 {
            crash("An invalid node was asked to be freed! {AnchorNode}", node);
        }
        if node.event_callbacks.free != undefined {
            function_execute_alt(
                node.event_callbacks.free.func,
                node.event_callbacks.free.arg_array
            );
        }
        if node.parent != undefined {
            var pos = array_pos(node.parent.children, node);
            array_delete(node.parent.children, pos, 1);
        }
        var count = array_length(node.children);
        repeat count {
            self.true_free_node(node.children[0]);
        }

        //
        //
        if self.text_input_node == node {
            self.text_input_node = undefined;
        }

        //
        var par = node.blackboard.try_take("__par__");
        if par != undefined {
            ds_priority_destroy(par.priority);
        }

        var position = ds_list_find_index(self.node_registrar, node);
        ds_list_delete(self.node_registrar, position);
        --self.node_count;
        if node.canvas != undefined {
            var queue_list = self.render_queues[node.layer][node.type];
            if queue_list != undefined {
                var pos = ds_list_find_index(queue_list, node);
                if pos != -1 {
                    ds_list_delete(queue_list, pos);
                }
            }
        }
        if self.current_hovered_node == node {
            self.current_hovered_node = undefined;
        }
    }

    function clear_pending_nodes() {
        if DEBUG_TOOLS {
            var span = profile_span_start("Anchor::clear_pending_nodes");
        }

        while ds_list_size(self.pending_node_deletions) > 0 {
            self.true_free_node(self.pending_node_deletions[| 0]);
            ds_list_delete(self.pending_node_deletions, 0);
        }

        if DEBUG_TOOLS {
            profile_span_stop(span);
        }
    }

    function point_in_node(node, x, y) {
        return point_in_rectangle(
            x,
            y,
            node.cache_bbox_left - node.offset.x,
            node.cache_bbox_top - node.offset.y,
            node.cache_bbox_right - node.offset.x,
            node.cache_bbox_bottom - node.offset.y,
        )
    }

    function get_screen_position(node) {
        if node.parent.parent != undefined {
            process_node_position(node.parent, node.parent.parent);
        }
        process_node_position(node, node.parent);
        return {
            x: node.cache_x - node.offset.x,
            y: node.cache_y - node.offset.y,
        }
    }

    //
    function get_relative_position(node, target) {
        var node_iter = node;
        var position = Vec2Zero();
        while node_iter.parent != undefined {
            process_node_position(node_iter, node_iter.parent);
            position.x += node_iter.cache_x - node_iter.parent.cache_x;
            position.y += node_iter.cache_y - node_iter.parent.cache_y;
            if node_iter.parent == target {
                return position;
            }
            node_iter = node_iter.parent;
        }

        if DEBUG_ASSERTIONS {
            crash("{AnchorNode} is not a descendant of {AnchorNode}!", node, target);
        }
        return position;
    }

    function mouse_interacting_with_any_node() {
        for (var i = 0, c = self.node_count; i < c; i++) {
            if self.node_registrar[| i].in_hover {
                return true;
            }
        }
        return false;
    }

    function screen_space_to_local_space(node, x, y) {
        //
        return Vec2(
            x - node.parent.cache_x,
            y - node.parent.cache_y,
        );
    }

    //
    //
    function hover_node(node, play_sound=false) {
        self.release_hovered_node();
        self.current_hovered_node = node;
        node.in_hover = true;
        var in_point_control = self.in_point_control();
        if node.hover_sound != undefined && !in_point_control && play_sound {
            TANGO.play(node.hover_sound);
        }
        if node.hover_outline != undefined && !node.in_tap {
            node.hover_outline.enable()
        }
        if in_point_control && node.pilot != undefined {
            node.pilot.force_select(node);
        }
    }

    //
    function tap_pressed() {
        return INPUT.pressed(InputId.LeftMouse) || INPUT.pressed(InputId.Interact);
    }

    //
    function tap_released() {
        return INPUT.released(InputId.LeftMouse) || INPUT.released(InputId.Interact);
    }

    //
    function take_tap() {
        return INPUT.take_press(InputId.LeftMouse) || INPUT.take_press(InputId.Interact);
    }

    //
    function in_point_control() {
        return self.control_mode == AnchorControl.Point;
    }

    //
    function in_directional_control() {
        return self.control_mode == AnchorControl.Directional;
    }

    //
    function switch_control(control) {
        if self.control_mode == control {
            return;
        }
        self.control_mode = control;
    }

    //
    function release_hovered_node() {
        if self.current_hovered_node == undefined {
            return;
        }
        if self.current_hovered_node.hover_outline != undefined {
            self.current_hovered_node.hover_outline.disable()
        }
        self.current_hovered_node.in_hover = false;
        self.current_hovered_node.in_tap = false;
        self.current_hovered_node.tap_is_deferred = false;
        self.current_hovered_node.hover_frames = 0;
        self.current_hovered_node.set_child_offset(0, 0);
        self.current_hovered_node = undefined;
    }

    //
    function tap_node(node) {
        if node.soft_locked {
            TANGO.play("SoundEffects/UI/UIUnableToInteract");
            return;
        }
        if node.tap_sound != undefined {
            TANGO.play(node.tap_sound);
        }
        if node.event_callbacks.tap != undefined {
            function_execute_alt(
                node.event_callbacks.tap.func,
                node.event_callbacks.tap.arg_array
            );
        }

        //
        //
        if self.in_directional_control() && node.depress_children {
            node.set_child_offset(0, 1);
            new_chain()
                .append(LinkId.Timer, fiddle_get("ui/misc/directional_tap_depress_frames"))
                .append(LinkId.Function, function(node) {
                    node.set_child_offset(0, 0);
                }, [node])
        }
    }
    //
    function set_active_pilot(pilot) {
        self.active_pilot = pilot;
        self.try_pilot_hover(false);
    }

    //
    //
    //
    //
    //
    //
    //
    //
    function try_pilot_hover(play_sound=false) {
        if self.active_pilot != undefined && self.in_directional_control() {
            var node = self.active_pilot.get();
            if node != undefined && !node.freed && self.current_hovered_node != node {
                self.hover_node(node, play_sound);
                if self.active_pilot.tap_on_hover_flag {
                    self.tap_node(node);
                }
                return true;
            }
        }
        return false;
    }

    //
    function get_active_pilot() {
        return self.active_pilot;
    }

    //
    function release_active_pilot() {
        self.active_pilot = undefined;
        //
    }

    //
    //
    function detect_lost_nodes() {
        var output = List();
        for (var i = 0, c = ds_list_size(self.node_registrar); i < c; i++) {
            var node = self.node_registrar[| i];
            if node == self.screen_canvas {
                continue;
            }
            if node.source_menu != undefined {
                if !self.open_menus.contains(node.source_menu) {
                    output.push(node);
                }
            } else {
                output.push(node);
            }
        }
        return output;
    }

    //
    function wrap_for_local(str) {
        return local_wrap(str);
    }
}
