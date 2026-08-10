//
//
function StoryExecutor(chain) constructor {
    self.chain = chain;

    function wait(frames) {
        self.chain.append(LinkId.Timer, frames);
    }

    function next(func, args) {
        self.chain.append(LinkId.Function, func, args);
    }

    function await(func, args) {
        self.chain.append(LinkId.Await, func, args);
    }

    function insert(func, args) {
        var chain = new Chain();
        chain.append(LinkId.Function, func, args);
        self.chain.insert_chain(chain);
    }

    function execute(command) {
        self.next(function(command) {
            BUGGER.execute_command(command);
        }, [command]);
    }

    function goto_scene_trigger(scene) {
        var data = CUTSCENES.get(scene);

        //
        var destination = undefined;
        var pos = undefined;
        if data.trigger == undefined {
            var keys = QUESTS.keys();
            for (var i = 0; i < array_length(keys); i++) {
                var quest = QUESTS.get(keys[i]);
                var task = quest.tasks.find_value(function(v, scene) {
                    var target = v.query_targets.first();
                    return target.type == QuestQueryType.Cutscene
                        && target.cutscene == scene;
                }, scene);
                if task == undefined {
                    continue;
                }
                var query = task.query_targets.first();
                destination = query.cutscene_location;
                if query.cutscene_area[0] == -infinity {
                    pos = Vec2Zero();
                } else {
                    pos = Vec2(query.cutscene_area[0] * 8, query.cutscene_area[1] * 8);
                }
            }
        } else {
            destination = data.trigger.location;
            if data.trigger.bbox == undefined {
                pos = Vec2Zero();
            } else {
                pos = Vec2(data.trigger.bbox[0] * 8, data.trigger.bbox[1] * 8);
            }
        }

        self.next(function(destination, pos) {
            if CURRENT_LOCATION_ID != destination {
                if is_dungeon_room(LOCATIONS[destination].gm_room) && !is_dungeon_room(room()) {
                    var itinerary = create_dungeon_itinerary();
                    DUNGEON_RUNNER = new DungeonRunner(itinerary, 0);
                }

                var itin = goto_location_id(destination, true);

                if pos != undefined {
                    itin.set_exact_position(pos.x, pos.y);
                }
            } else if pos != undefined {
                obj_ari.x = pos.x;
                obj_ari.y = pos.y;
            }
        }, [destination, pos]);


        self.await(function(destination) {
            return CURRENT_LOCATION_ID == destination;
        }, [destination]);

        self.wait(60);
    }

    function goto(str) {
        self.await(function() {
            return !TAXI.is_traveling();
        });
        self.execute(format("goto {}", str));
        self.wait(1);
    }

    function clock_jump(time) {
        self.execute(format("clock jump {}", time));
    }

    function talk_to(npc) {
        self.goto(npc_id_to_string(npc));
        self.interact_with(npc_id_to_gm_obj_id(npc), "misc_local/talk");
        self.play_out_textbox();
    }

    function accept_from_request_board(quest) {
        self.goto("town/aqb_ari_at_board");
        self.interact_with(obj_noticeboard, "misc_local/use");
        self.next(function(quest) {
            var menu = ANCHOR.get_menu(Menu.QuestLog);
            var target = undefined;
            for (var i = 0; i < array_length(menu.left_pilot.map); i++) {
                var node = menu.left_pilot.map[i][0];
                if node.blackboard.get("quest_name") == quest {
                    target = node;
                    break;
                }

            }
            assert_neq(target, undefined, "Could not find '{}' on the request board!", quest);
            ANCHOR.tap_node(target);
            var accept_button = menu.right_pilot.map[array_length(menu.right_pilot.map) - 1][0];
            ANCHOR.tap_node(accept_button);
            menu.journal.close();
        }, [quest]);
        self.assert_quest_active(quest);
    }

    function turn_in_quest(npc, quest) {
        self.assert_quest_active(quest);
        self.goto(npc_id_to_string(npc));
        self.interact_with(npc_id_to_gm_obj_id(npc), "misc_local/turn_in_quest_input");
        self.next(function(quest) {
            var popup = ANCHOR.get_menu(Menu.Popup);
            assert_eq(popup.quest_name, quest, "Attempted to turn in wrong quest -- expected {} but got {}", quest, popup.quest_name);
            ANCHOR.tap_node(popup.buttons.get(1));
        }, [quest]);
        self.play_out_textbox(npc);
    }

    function play_out_textbox() {
        self.await(function() {
            var menu = ANCHOR.get_menu(Menu.Textbox);
            if menu == undefined {
                return true;
            }
            if matches(menu.state, TextboxState.Say, TextboxState.Ask, TextboxState.Info) {
                menu.driver.prompt_index_selected = TS_TEXTBOX_PROMPT_INDEX();
                menu.interact();
            }
            return false;
        });
    }

    function play_out_scene(scene_name) {
        self.await(function(scene_name) {
            static DEADLOCK_CHECK = 0;
            if MIST.runtime == undefined {
                DEADLOCK_CHECK += 1;
                if DEADLOCK_CHECK > 600 {
                    crash("We appear to be deadlocked waiting for '{}'", scene_name);
                }
                return false;
            }

            DEADLOCK_CHECK = 0;

            assert_eq(MIST.active_cutscene.id, scene_name);
            MIST.runtime.native_environment.define(
                "__textbox_interacted",
                new NativeCallable(MIST.runtime).set_call(__ts_mist_textbox_interacted),
            );
            return true;
        }, [scene_name]);

        self.await(function(scene_name) {
            return !MIST.is_running() || MIST.active_cutscene.id != scene_name;
        }, [scene_name]);

        self.wait(1);
    }

    function interact_with(obj, key) {
        self.next(function(obj, key) {
            var inst = instance_nearest(obj_ari.x, obj_ari.y, obj);
            var interaction = inst.interactions.find_value(function(a, key) {
                return a.local_key == key;
            }, key);
        interaction.callback();
        }, [obj, key]);
    }

    function end_day(scene_to_expect) {
        self.goto("bed");
        self.next(function() {
            with obj_node_renderer {
                if self.node.prototype.bed_kind != undefined {
                    interact(node);
                    ANCHOR.tap_node(ANCHOR.get_menu(Menu.Popup).buttons.get(1));
                }
            }
        });
        self.play_out_scene("sleep");
        if scene_to_expect != undefined {
            self.play_out_scene(scene_to_expect);
        }

        self.play_out_eod();
    }

    function play_out_eod() {
        self.wait(1); //
        self.await(function() {
            var menu = ANCHOR.get_menu(Menu.Eod);
            if menu != undefined && menu.next_day_button != undefined {
                ANCHOR.tap_node(menu.next_day_button);
                return true;
            }
            return false;
        });

        self.await(function() {
            //
            var popup = ANCHOR.get_menu(Menu.Popup);
            if popup != undefined {
                ANCHOR.tap_node(popup.buttons.first());
            }

            if instance_exists(obj_ari) {
                switch obj_ari.fsm.current_state_id() {
                    case PlayerState.Default: return true;
                    case PlayerState.Cutscene:
                        if MIST.active_cutscene != undefined {
                            return MIST.active_cutscene.manually_triggered_in_morning;
                        }
                        return false;
                    default: return false;
                }
            }
            return false;
        });
    }

    function skip_to_date(date_str) {
        self.goto("bed");
        self.execute(format("manana {}", date_str));
    }

    function open_letter(letter) {
        self.await(function() {
            return ANCHOR.get_menu(Menu.Inbox) == undefined;
        });
        self.next(function(letter) {
            var menu = ANCHOR.spawn_menu(Menu.Inbox);
            var button = find_node(letter);
            assert_neq(button, undefined, "'{}' was not found in inbox!", letter);
            ANCHOR.tap_node(button);
            menu.close();
        }, [letter])
    }

    function assert_quest_active(quest_name) {
        self.next(function(quest_name) {
            assert(QUEST_LOG.active.contains_key(quest_name), "{} was not active!", quest_name);
        }, [quest_name]);
    }

    function assert_quest_complete(quest_name) {
        self.next(function(quest_name) {
            assert(QUEST_LOG.completed.contains(quest_name), "{} was not completed!", quest_name);
        }, [quest_name]);
    }

    function assert_world_mod_enabled(world_mod) {
        self.next(function(world_mod) {
            assert(world_mod_enabled(world_mod), "{WorldMod} is not enabled!", world_mod);
        }, [world_mod]);
    }

    function fulfill_quest(quest_name) {
        self.next(function(quest_name) {
            var active = QUEST_LOG.active.get(quest_name);
            assert_neq(active, undefined, "Quest '{}' was not active!", quest_name);
            var requirements = active.quest.tasks.get(active.current_stage).requirements;
            for (var i = 0; i < Requirement.LEN; i++) {
                var req = requirements[i];
                if req == undefined {
                    continue;
                }
                fulfill_requirement(i, req);
            }

        }, [quest_name])
    }

    function simulate_quest(quest_name) {
        self.execute(format("quest start {}", quest_name));
        self.assert_quest_active(quest_name);
        SE.next(function(quest_name) {
            while !QUEST_LOG.completed.contains(quest_name) {
                BUGGER.execute_command(format("quest progress {}", quest_name));
            }
        }, [quest_name]);
        self.assert_quest_complete(quest_name);
    }

    function traverse_dungeon(floor) {
        for (var i = 0; i < floor; i++) {
            self.execute("dungeon");
            self.wait(5);

            //
            self.play_out_textbox();
        }
    }
}

function fulfill_requirement(i, req) {
    switch i {
        case Requirement.HasItem:
            for (var j = 0; j < array_length(req); j++) {
                if ARI.inventory.room_for_item(req[j][0]) < req[j][1] {
                    ARI.inventory.slot(0).drain();
                }
                ARI.give_item(req[j][0], req[j][1]);
            }
            break;
        case Requirement.HasGold:
            ARI.modify_gold(req);
            break;
        case Requirement.SuppliedItems:
            for (var j = 0; j < array_length(req); j++) {
                var this_req = req[j];
                var inventory = undefined;
                if this_req.type == SupplyType.Chest {
                    var point = trellis_point_location_position(this_req.point);
                    var ni = GRIDS[point.location_id].node_index_for_cell(point.pos.x div 8, point.pos.y div 8);
                    inventory = GRIDS[point.location_id].node_parent[ni].inventory;
                } else {
                    inventory = SEAL_INVENTORIES[this_req.seal];
                }

                for (var k = 0; k < ItemId.LEN; k++) {
                    var count = this_req.items[k];
                    if count != 0 {
                        inventory.add(k, count);
                    }
                }
            }
            break;
        case Requirement.ShippedTag:
            for (var j = 0; j < array_length(req); j++) {
                for (var k = 0; k < ItemId.LEN; k++) {
                    if ITEM_PROTOTYPES[k].tags.contains(req[j][0]) {
                        shipping_bins().first().inventory.add(k, req[j][1]);
                        break;
                    }
                }
            }
            break;
        case Requirement.ShippedItem:
            for (var j = 0; j < array_length(req); j++) {
                shipping_bins().first().inventory.add(req[j][0], req[j][1]);
            }
            break;
        case Requirement.WorldFactIs:
            for (var j = 0; j < array_length(req); j++) {
                T2R.write(req[j][0], req[j][1]);
            }
            break;
        case Requirement.SeenCutscene:
            for (var j = 0; j < array_length(req); j++) {
                MIST.mark_scene_has_played(req[j]);
                trigger_scene_object_removals(req[j]);
            }
            break;
        case Requirement.CompletedQuest:
            for (var j = 0; j < array_length(req); j++) {
                QUEST_LOG.completed.insert(req[j]);
            }
            break;
        default:
            if requirement_is_alias(i) {
                var data = REQUIREMENT_ALIASES[i];
                for (var j = 0; j < Requirement.LEN; j++) {
                    if data[j] != undefined {
                        fulfill_requirement(j, data[j]);
                    }
                }
            } else {
                impossible("Cannot progress requirement: {Requirement}", i);
            }
            break;
    }
}

function unfulfill_requirement(i, req) {
    switch i {
        case Requirement.SeenCutscene:
            for (var j = 0; j < array_length(req); j++) {
                MIST.scene_history.remove(req[j]);
                //
            }
        case Requirement.CompletedQuest:
            for (var j = 0; j < array_length(req); j++) {
                QUEST_LOG.completed.remove(req[j]);
            }
            break;
        default:
            if requirement_is_alias(i) {
                var data = REQUIREMENT_ALIASES[i];
                for (var j = 0; j < Requirement.LEN; j++) {
                    if data[j] != undefined {
                        unfulfill_requirement(j, data[j]);
                    }
                }
            } else {
                impossible("Cannot unfulfill requirement: {Requirement}", i);
            }
            break;
    }
}
