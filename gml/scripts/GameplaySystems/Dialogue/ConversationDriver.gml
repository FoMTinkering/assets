//
//
function play_conversation(npc_id, path, close_callback=undefined, args=undefined) {
    trace("Starting conversation: \"{}\"", path);
    var driver = new ConversationDriver(npc_id, path);
    driver.proceed_conversation();
    driver.close_callback = close_callback;
    driver.close_callback_args = args ?? [];
    array_insert(driver.close_callback_args, 0, driver);

    return driver;
}

//
//
function play_conversation_from_path(npc_id, path, close_callback=undefined, args=undefined) {
    //
    if matches(obj_ari.par.base_animation(), AnimationName.Run, AnimationName.Walk) {
        obj_ari.set_animation(AnimationName.Idle);
    } else if obj_ari.is_mounted() {
        obj_ari.set_animation(AnimationName.Ride);
    } else if obj_ari.is_swimming() {
        obj_ari.set_animation(AnimationName.SwimIdle);
    }

    return play_conversation(npc_id, path, close_callback, args);
}

function ConversationDriver(npc_id, path) constructor {
    self.npc_owner = npc_id;
    self.conversation_name = path;
    T2R.conversation_start(npc_id, path);

    if MIST.running == false {
        npcs_enter_pause_animations(path);
    }

    self.state = ConversationDriverState.Init;
    self.next_line_behavior = undefined;
    self.prompt_index_selected = undefined;
    self.textbox = undefined;
    self.close_callback = undefined;
    self.close_callback_args = [];
    self.is_info_line = false;

    //
    function proceed_conversation() {
        self.ensure_textbox();

        switch self.state {
            case ConversationDriverState.Init:
                self.state = ConversationDriverState.Main;
                //
				process_t2_action(T2Action.Speaker(npc_id_to_string(self.npc_owner)), self.npc_owner);
                break;
            case ConversationDriverState.Main:
                switch self.next_line_behavior.type {
                    case NextLineBehaviorId.Prompts:
                        var finished = T2R.conversation_select_prompt(self.prompt_index_selected);
                        if finished {
                            self.finish_conversation();
                            return;
                        }
                        break;
                    case NextLineBehaviorId.NextLines:
                        //
                        break;
                    case NextLineBehaviorId.Finish:
                        self.finish_conversation();
                        return;
                }
                break;
            case ConversationDriverState.Finished:
                crash("We tried to `proceed_line` but we've already finished the conversation!");
                break;
        }

        self.advance_t2();

        if self.textbox.blackout_frames != undefined {
            self.textbox.blackout(self.textbox.blackout_frames);
            self.textbox.give_callback(function() {
                self.deliver_line(self.current_line);
                self.textbox.give_callback(self.proceed_conversation);
            });
            self.textbox.blackout_frames = undefined;
        } else {
            self.deliver_line(self.current_line);
            self.textbox.give_callback(self.proceed_conversation);
        }
    }

    //
    function advance_t2() {
        self.is_info_line = false;
        self.current_line = T2R.conversation_execute();
        self.next_line_behavior = self.current_line.next_line_behavior;

        for (var i = 0, c = array_length(self.current_line.actions); i < c; i++) {
            var action = self.current_line.actions[i];
            process_t2_action(action, self.npc_owner, self);
        }
    }

    //
    function ensure_textbox() {
        if ANCHOR.get_menu(Menu.Textbox) == undefined {
            self.textbox = ANCHOR.spawn_menu(Menu.Textbox);
            self.textbox.driver = self;
            self.textbox.give_close_callback(function() {
                if self.close_callback != undefined {
                    function_execute_alt(self.close_callback, self.close_callback_args);
                }
            });
        }
    }

    //
    function deliver_line(line) {
        if line.next_line_behavior.type == NextLineBehaviorId.Prompts {
            self.textbox.ask(line.local, line.next_line_behavior.prompts);
        } else if self.is_info_line {
            self.textbox.info(line.local);
        } else {
            self.textbox.say(line.local);
        }
    }

    function finish_conversation() {
        var end_actions = T2R.conversation_end();
        for (var i = 0, c = array_length(end_actions); i < c; i++) {
            var action = end_actions[i];
            process_t2_action(action, self.npc_owner, self);
        }

        //
        if self.textbox != undefined {
            if self.textbox.state == TextboxState.Hidden || self.textbox.state == TextboxState.Translating {
                self.textbox.close();
            } else {
                self.textbox.begin_close();
            }
        }
        self.state = ConversationDriverState.Finished;
    }
}

enum ConversationDriverState {
    Init,
    Main,
    Finished,
}
