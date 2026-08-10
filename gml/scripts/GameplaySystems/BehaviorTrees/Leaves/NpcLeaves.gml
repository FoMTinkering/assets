function TransferLiteralToInstBlackboard(_them, _literal) {
    return new _TransferLiteralToInstBlackboard(_them, _literal);
}
function _TransferLiteralToInstBlackboard(_them, _literal): __Leaf() constructor {
    literal = _literal;
    them = _them;

    run = function(blackboard) {
        var npc_bb = blackboard.get("instance").fsm.blackboard;
        npc_bb.set(them, literal);
        return Status.Ok;
    }
}

function SetOnStatic(name, value) {
    return new _SetOnStatic(name, value);
}
function _SetOnStatic(name, value): __Leaf() constructor {
    self.name = name;
    self.value = value;
    self.run = function(bb) {
        bb.get("me")[$ self.name] = self.value;
        return Status.Ok;
    }
}

function TransferToInstBlackboard(_us, _them) {
    return new _TransferToInstBlackboard(_us, _them);
}
function _TransferToInstBlackboard(_us, _them): __Leaf() constructor {
    us = _us;
    them = _them == undefined ? _us : _them;

    run = function(blackboard) {
        var v = blackboard.get(us);
        var inst = blackboard.get("instance");
        if inst == undefined || !instance_exists(inst) {
            return Status.Err;
        }
        var npc_bb = inst.fsm.blackboard;
        npc_bb.set(them, v);
        return Status.Ok;
    }
}

function TransferFromInstBlackboard(_us, _them) {
    return new _TransferFromInstBlackboard(_us, _them);
}
function _TransferFromInstBlackboard(_us, _them): __Leaf() constructor {
    us = _us;
    them = _them == undefined ? _us: _them;

    run = function(blackboard) {
        var npc_bb = blackboard.get("instance").fsm.blackboard;
        var v = npc_bb.get(them);

        if (v == undefined) {
            return Status.Err;
        } else {
            blackboard.set(us, v);
            return Status.Ok;
        }
    }
}

function TakeFromInstBlackboard(_us, _them) {
    return new _TakeFromInstBlackboard(_us, _them);
}
function _TakeFromInstBlackboard(_us, _them): __Leaf() constructor {
    us = _us;
    them = _them == undefined ? _us: _them;

    run = function(blackboard) {
        var npc_bb = blackboard.get("instance").fsm.blackboard;
        var v = npc_bb.try_take(them);

        if (v == undefined) {
            return Status.Err;
        } else {
            blackboard.set(us, v);
            return Status.Ok;
        }
    }
}

function TransferFromStatic(_us, _them) {
    return new _TransferFromStatic(_us, _them);
}
function _TransferFromStatic(_us, _them): __Leaf() constructor {
    us = _us;
    them = _them == undefined ? _us: _them;

    run = function(blackboard) {
        var data = blackboard.get("me");
        var v = data[$ them];

        if (v == undefined) {
            return Status.Err;
        } else {
            blackboard.set(us, v);
            return Status.Ok;
        }
    }
}

function StateSwitch(_new_state) {
    return new _StateSwitch(_new_state);
}
function _StateSwitch(_new_state): __Leaf() constructor {
    new_state = _new_state;

    run = function(blackboard) {
        var npc = blackboard.get("instance");
        npc.fsm.change_state(self.new_state);
        return Status.Ok;
    }
}

function ChooseStateSwitch(state_array) {
    return new _ChooseStateSwitch(state_array);
}
function _ChooseStateSwitch(_state_array): __Leaf() constructor {
    state_array = _state_array;

    run = function(blackboard) {
        var npc = blackboard.get("instance");
        npc.fsm.change_state(self.state_array[irandom(array_length(self.state_array) - 1)]);
        return Status.Ok;
    }
}
function StateIs(_state) {
    return new _StateIs(_state);
}
function _StateIs(_state): __Leaf() constructor {
    state = _state;

    run = function(blackboard) {
        var npc = blackboard.get("instance");
        if state == npc.fsm.current_state_id() {
            return Status.Ok;
        } else {
            return Status.Err;
        }
    }
}

function WithinRect(x1, y1, x2, y2) {
    return new _WithinRect(x1, y1, x2, y2);
}
function _WithinRect(x1, y1, x2, y2): __Leaf() constructor {
    self.x1 = x1;
    self.y1 = y1;
    self.x2 = x2;
    self.y2 = y2;

    run = function(blackboard) {
        var npc = blackboard.get("me");
        var position = npc.location_position.pos;
        if position.x >= self.x1 && position.x <= self.x2
        && position.y >= self.y1 && position.y <= self.y2 {
            return Status.Ok;
        } else {
            return Status.Err;
        }
    }
}

function PlayerNear(distance) {
    return new _PlayerNear(distance);
}
function _PlayerNear(distance): __Leaf() constructor {
    self.distance = distance;
    run = function(blackboard) {
        var npc = blackboard.get("instance");
        if point_distance(npc.x, npc.y, obj_ari.x, obj_ari.y) <= self.distance {
            return Status.Ok;
        } else {
            return Status.Err;
        }
    }
}

function ImageIndexIs(frame) {
    return new _ImageIndexIs(frame);
}
function _ImageIndexIs(frame): __Leaf() constructor {
    self.frame = frame;

    run = function(blackboard) {
        var animator = blackboard.get("instance").animator;
        if floor(animator.current_image) == self.frame {
            return Status.Ok;
        } else {
            return Status.Err;
        }
    }
}

function TeleportTo(location) {
    return new _TeleportTo(location);
}
function _TeleportTo(location): __Leaf() constructor {
    self.location = location;
    run = function(blackboard) {
        var static_data = blackboard.get("me");
        var location = self.location;
        if is_string(location) {
            location = blackboard.get(location);
        }
        static_data.location_position = location.clone();
        var instance = blackboard.get("instance");
        if instance != undefined && instance_exists(instance) {
            instance_destroy(instance);
        }
        return Status.Ok;
    }
}

//
function PlayBark(bark_name, bark_type) {
    return new _PlayBark(bark_name, bark_type);
}
function _PlayBark(bark_name, bark_type): __Leaf() constructor {
    self.bark_name = bark_name;
    self.bark_type = bark_type;
    run = function(bb) {
        var inst = bb.get("instance");
        if inst == undefined {
            return Status.Err;
        }
        var bark_id = string_to_bark_id(self.bark_name);
        inst.bark_emitter.emit(bark_id, self.bark_type);
        return Status.Ok;
    }
}

//
//
//
//
//
//
//
function SetAnimation(name, reset=undefined) {
    return Sequence(
        HasAnimation(name),
        Set("animation_to_set", name),
        Set("reset_to_set", reset),
        Selector(
            Equal("reset_to_set", undefined),
            HasAnimation(reset),
        ),
        Run(function(bb) {
            var anim = bb.take("animation_to_set");
            var reset = bb.try_take("reset_to_set");
            var inst = bb.get("instance");
            if inst != undefined {
                inst.me.set_animation(anim);
                inst.reset_cycle_name = reset;
            } else {
                bb.get("me").set_animation(anim);
            }
            return Status.Ok;
        })
    );
}

//
function HasAnimation(name) {
    return new _HasAnimation(name);
}
function _HasAnimation(name) : __Leaf() constructor {
    self.name = name;
    self.run = function(bb) {
        return bb.get("me").wardrobe.outfit_current.cycles.contains_key(self.name)
            ? Status.Ok
            : Status.Err;
    }
}
