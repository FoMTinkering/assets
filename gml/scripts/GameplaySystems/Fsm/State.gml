enum StateEvent {
    Create      = 1 << 0,
    Step        = 1 << 1,
    StepAfter   = 1 << 2,
    EndStep     = 1 << 3,
    Draw        = 1 << 4,
    DrawAfter   = 1 << 5,
    Start       = 1 << 6,
    Stop        = 1 << 7,
    Cleanup     = 1 << 8,
    AnimEnd     = 1 << 9,
    RoomStart   = 1 << 10,
    RoomEnd     = 1 << 11,
    Destroy     = 1 << 12,
}

function StateBuilder(_id) {
    return {
        state_id: _id,

        create_ev: undefined,
        step_ev: undefined,
        step_after_ev: undefined,

        end_step_ev: undefined,
        draw_ev: undefined,
        draw_after_ev: undefined,

        start_ev: undefined,
        stop_ev: undefined,

        cleanup_ev: undefined,
        destroy_ev: undefined,
        anim_end_ev: undefined,

        room_start_ev: undefined,
        room_end_ev: undefined,

        create: function(fn) {
            create_ev = fn;
            return self;
        },

        step: function(fn) {
            step_ev = fn;
            return self;
        },

        step_after: function(fn) {
            step_after_ev = fn;
            return self;
        },

        end_step: function(fn) {
            end_step_ev = fn;
            return self;
        },

        draw: function(fn) {
            draw_ev = fn;
            return self;
        },

        draw_after: function(fn) {
            draw_after_ev = fn;
            return self;
        },

        start: function(fn) {
            start_ev = fn;
            return self;
        },

        stop: function(fn) {
            stop_ev = fn;
            return self;
        },

        destroy: function(fn) {
            destroy_ev = fn;
            return self;
        },

        cleanup: function(fn) {
            cleanup_ev = fn;
            return self;
        },

        anim_end: function(fn) {
            anim_end_ev = fn;
            return self;
        },

        room_start: function(fn) {
            room_start_ev = fn;
            return self;
        },

        room_end: function(fn) {
            room_end_ev = fn;
            return self;
        },

        spawn: function() {
            var state = new __State(self.state_id);

            //
            if self.create_ev != undefined {
                state.create = method(state, self.create_ev);
                state.__capabilities |= StateEvent.Create;
            }

            //
            if self.step_ev != undefined {
                state.step = method(state, self.step_ev);
                state.__capabilities |= StateEvent.Step;
            }

            //
            if self.step_after_ev != undefined {
                state.step_after = method(state, self.step_after_ev);
                state.__capabilities |= StateEvent.StepAfter;
            }

            //
            if self.end_step_ev != undefined {
                state.end_step = method(state, self.end_step_ev);
                state.__capabilities |= StateEvent.EndStep;
            }

            //
            if self.draw_ev != undefined {
                state.draw = method(state, self.draw_ev);
                state.__capabilities |= StateEvent.Draw;
            }

            //
            if self.draw_after_ev != undefined {
                state.draw_after = method(state, self.draw_after_ev);
                state.__capabilities |= StateEvent.DrawAfter;
            }

            //
            if self.start_ev != undefined {
                state.start = method(state, self.start_ev);
                state.__capabilities |= StateEvent.Start;
            }

            //
            if self.stop_ev != undefined {
                state.stop = method(state, self.stop_ev);
                state.__capabilities |= StateEvent.Stop;
            }

            //
            if self.cleanup_ev != undefined {
                state.cleanup = method(state, self.cleanup_ev);
                state.__capabilities |= StateEvent.Cleanup;
            }

            if self.destroy_ev != undefined {
                state.destroy = method(state, self.destroy_ev);
                state.__capabilities |= StateEvent.Destroy;
            }

            //
            if self.anim_end_ev != undefined {
                state.anim_end = method(state, self.anim_end_ev);
                state.__capabilities |= StateEvent.AnimEnd;
            }

            //
            if self.room_start_ev != undefined {
                state.room_start = method(state, self.room_start_ev);
                state.__capabilities |= StateEvent.RoomStart;
            }

            //
            if self.room_end_ev != undefined {
                state.room_end = method(state, self.room_end_ev);
                state.__capabilities |= StateEvent.RoomEnd;
            }

            return state;
        }
    }
}

function __State(_state_id) constructor {
    fsm = undefined;
    owner = undefined;
    blackboard = undefined;
    state_id = _state_id;

    __capabilities = 0;

    static has_create = function() {
        return self.has_event(StateEvent.Create);
    }

    static has_step = function() {
        return self.has_event(StateEvent.Step);
    }

    static has_step_after = function() {
        return self.has_event(StateEvent.StepAfter);
    }

    static has_end_step = function() {
        return self.has_event(StateEvent.EndStep);
    }

    static has_draw = function() {
        return self.has_event(StateEvent.Draw);
    }

    static has_draw_after = function() {
        return self.has_event(StateEvent.DrawAfter);
    }

    static has_start = function() {
        return self.has_event(StateEvent.Start);
    }

    static has_stop = function() {
        return self.has_event(StateEvent.Stop);
    }

    static has_destroy = function() {
        return self.has_event(StateEvent.Destroy);
    }

    static has_cleanup = function() {
        return self.has_event(StateEvent.Cleanup);
    }

    static has_anim_end = function() {
        return self.has_event(StateEvent.AnimEnd);
    }

    static has_room_start = function() {
        return self.has_event(StateEvent.RoomStart);
    }

    static has_room_end = function() {
        return self.has_event(StateEvent.RoomEnd);
    }

    static has_event = function(ev) {
        return (__capabilities & ev) == ev;
    }
}
