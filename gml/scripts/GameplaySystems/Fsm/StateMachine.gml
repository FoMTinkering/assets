function StateMachineBuilder(_state_count) {
    return {
        states: ListFromArray(array_create(_state_count, undefined)),

        //
        add_state: function(state) {
            assert_neq(state[$ "__capabilities"], "state does not have `capas`")
            self.states.set(state.state_id, state);
            return self;
        },

        //
        spawn: function(_initial_state, _owner, _blackboard) {
            return StateMachine(self.states, _initial_state, _owner, _blackboard ?? Map());
        }
    }
}

function StateMachine(_states, _initial_state, _owner, _blackboard) {
    var fsm = new __StateMachine(_states, _blackboard);

    //
    for (var i = 0; i < fsm.states.count(); i++) {
        var state = fsm.states.get(i);
        assert_neq(state, undefined, "state {} was not correctly defined, even though it should have been", i);
        state.owner = _owner;
        state.blackboard = _blackboard;
        state.fsm = fsm;
    }

    //
    for (var i = 0; i < fsm.states.count(); i++) {
        var state = fsm.states.get(i);
        if (state.has_create()) {
            state.create();
        }
    }

    //
    var state = fsm.states.get(_initial_state);
    fsm.begin_new_state(state);

    return fsm;
}

function __StateMachine(_states, _blackboard) constructor {
    states = _states;

    state_frame = 0;
    state = undefined;
    next_state = undefined;
    last_state_id = undefined;
    blackboard = _blackboard;

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
    static change_state = function(new_state_id) {
        var ns = self.states.get(new_state_id);
        assert_neq(ns, undefined, "No State defined for state id {}", new_state_id);
        self.next_state = ns;
    }

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
    static change_state_instant = function(new_state_id) {
        var ns = self.states.get(new_state_id);
        assert_neq(ns, undefined, "No State defined for state id {}", new_state_id);

        self.next_state = ns;
        self.execute_state_change();
    }

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
    static current_state_id = function() {
        return self.state.state_id;
    }

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
    static current_state = function() {
        return self.state;
    }

    //
    //
    //
    //
    //
    //
    //
    //
    static check_state_inclusive = function(state_to_check) {
        return self.state.state_id == state_to_check
            || (self.next_state != undefined && self.next_state.state_id == state_to_check)
    }


    //
    static step = function() {
        if self.state.has_step() {
            self.state.step();
        }
    }

    //
    static step_after = function() {
        if self.state.has_step_after() {
            self.state.step_after();
        }
    }

    //
    static end_step = function() {
        if self.state.has_end_step() {
            self.state.end_step();
        }
    }

    //
    static draw = function() {
        if self.state.has_draw() {
            self.state.draw();
        }
    }

    //
    static draw_after = function() {
        if (self.state.has_draw_after()) {
            self.state.draw_after();
        }
    }

    //
    static anim_end = function() {
        if self.state.has_anim_end() {
            self.state.anim_end();
        }
    }

    //
    static room_start = function() {
        if self.state.has_room_start() {
            self.state.room_start();
        }
    }

    //
    static room_end = function() {
        if self.state.has_room_end() {
            self.state.room_end();
        }
    }

    //
    //
    static destroy = function() {
        //
        if self.state.has_stop() {
            self.state.stop();
        }

        for (var i = 0; i < self.states.count(); i++) {
            var state = self.states.get(i);
            if state.has_destroy() {
                state.destroy();
            }
        }
    }

    //
    //
    static cleanup = function() {
        for (var i = 0; i < self.states.count(); i++) {
            var state = self.states.get(i);
            if state.has_cleanup() {
                state.cleanup();
            }
        }
    }

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
    //
    static new_tick = function() {
        if self.next_state != undefined {
            self.execute_state_change();
            return true;
        } else {
            self.state_frame += 1;
            return false;
        }
    }

    static execute_state_change = function() {
        if self.state.has_stop() {
            self.state.stop();
        }

        self.last_state_id = self.state.state_id;
        self.begin_new_state(self.next_state);
    }

    static begin_new_state = function(new_state) {
        self.state_frame = 0;
        self.state = new_state;
        self.next_state = undefined;
        if self.state.has_start() {
            self.state.start();
        }
    }
}
