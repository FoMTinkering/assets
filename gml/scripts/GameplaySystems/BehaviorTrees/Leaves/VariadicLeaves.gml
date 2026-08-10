function Set(_value_name, _value) {
    return new _Set(_value_name, _value);
}
function _Set(_value_name, _value): __Leaf() constructor {
    value_name = _value_name;
    value = _value;

    run = function(blackboard) {
        blackboard.set(value_name, value);
        return Status.Ok;
    }
}

function Copy(value_name, new_name) {
    return new _Copy(value_name, new_name);
}
function _Copy(value_name, new_name): __Leaf() constructor {
    self.value_name = value_name;
    self.new_name = new_name;

    run = function(blackboard) {
        blackboard.set(self.new_name, blackboard.get(self.value_name));
        return Status.Ok;
    }
}

function ChooseSet(_value_name, _array) {
    return new _ChooseSet(_value_name, _array);
}
function _ChooseSet(_value_name, _array): __Leaf() constructor {
    value_name = _value_name;
    array = _array;

    run = function(blackboard) {
        blackboard.set(value_name, array[irandom(array_length(array) - 1)]);
        return Status.Ok;
    }
}

function Breakpoint() {
    return new _Breakpoint();
}
function _Breakpoint(): __Leaf() constructor {
    run = function() {
        b = 2;
        return Status.Ok;
    }
}

function SetWith(_value_name, _fn) {
    return new _SetWith(_value_name, _fn);
}
function _SetWith(_value_name, _fn): __Leaf() constructor {
    value_name = _value_name;
    my_func = _fn;

    run = function(blackboard) {
        var val = my_func(blackboard);
        if val != undefined {
            blackboard.set(value_name, val);
            return Status.Ok;
        } else {
            return Status.Err;
        }
    }
}

function Run(func) {
    return new _Run(func);
}
function _Run(func) : __Leaf() constructor {
    self.func = func;

    run = function(bb) {
        return self.func(bb);
    }
}

function RemoveVariable(_value_name) {
    return new _RemoveVariable(_value_name);
}
function _RemoveVariable(_value_name): __Leaf() constructor {
    value_name = _value_name;

    run = function(blackboard) {
        blackboard.set(value_name, undefined);
        return Status.Ok;
    }
}

function PopStack(_stack_name, _save_to) {
    return new _PopStack(_stack_name, _save_to);
}
function _PopStack(_stack_name, _save_to): __Leaf() constructor {
    stack_name = _stack_name;
    save_to = _save_to;

    run = function(blackboard) {
        var stack = blackboard.get(stack_name);
        if (stack != undefined) {
            var v = stack.pop();
            if (v == undefined) {
                return Status.Err;
            } else {
                blackboard.set(save_to, v);
                return Status.Ok;
            }
        } else {
            return Status.Err;
        }
    }
}

function Increment(_value, _amount) {
    return new _Increment(_value, _amount);
}
function _Increment(_value_name, _amount): __Leaf() constructor {
    value_name = _value_name;
    amount = _amount == undefined ? 1 : _amount;

    run = function(blackboard) {
        var v = blackboard.get(self.value_name);
        if (v != undefined) {
            blackboard.set(self.value_name, v + self.amount);
            return Status.Ok;
        } else {
            return Status.Err;
        }
    }
}

function Decrement(_value, _amount) {
    return new _Decrement(_value, _amount);
}
function _Decrement(_value_name, _amount): __Leaf() constructor {
    value_name = _value_name;
    amount = _amount == undefined ? 1 : _amount;

    run = function(blackboard) {
        var v = blackboard.get(self.value_name);
        if (v != undefined) {
            blackboard.set(self.value_name, v - self.amount);
            return Status.Ok;
        } else {
            return Status.Err;
        }
    }
}

function Equal(_value_name, _value) {
    return new _Equal(_value_name, _value);
}
function _Equal(_value_name, _value): __Leaf() constructor {
    value_name = _value_name;
    value = _value;

    run = function(blackboard) {
        var v = blackboard.get(value_name);
        if (v == value) {
            return Status.Ok;
        } else {
            return Status.Err;
        }
    }
}

function IsDefined(_value_name) {
    return new _IsDefined(_value_name);
}
function _IsDefined(_value_name): __Leaf() constructor {
    value_name = _value_name;

    run = function(blackboard) {
        return blackboard.get(value_name) != undefined
            ? Status.Ok
            : Status.Err;
    }
}

function Take(name, value) {
    return new _Take(name, value);
}
function _Take(name, value): __Leaf() constructor {
    self.name = name;
    self.value = value;
    self.run = function(bb) {
        var value = bb.get(self.name);
        if value == self.value {
            bb.take(self.name);
            return Status.Ok;
        }
        return Status.Err;
    }
}

function TakeFlag(_value_name) {
    return new _Take(_value_name, true);
}

function LessThan(_value_name, _value) {
    return new _LessThan(_value_name, _value);
}
function _LessThan(_value_name, _value): __Leaf() constructor {
    value_name = _value_name;
    value = _value;

    run = function(blackboard) {
        var v = blackboard.get(value_name);
        if (v < value) {
            return Status.Ok;
        } else {
            return Status.Err;
        }
    }
}

function GreaterThan(_value_name, _value) {
    return new _GreaterThan(_value_name, _value);
}
function _GreaterThan(_value_name, _value): __Leaf() constructor {
    value_name = _value_name;
    value = _value;

    run = function(blackboard) {
        var v = blackboard.get(value_name);
        var o = self.value;
        if (is_string(self.value)) {
            o = blackboard.get(self.value);
        }
        if (v > o) {
            return Status.Ok;
        } else {
            return Status.Err;
        }
    }
}

function InRoom() {
    return new _InRoom();
}

function _InRoom(): __Leaf() constructor {
    run = function(blackboard) {
        var npc = blackboard.get("instance");
        if npc == undefined || !instance_exists(npc){
            return Status.Err;
        } else {
            return Status.Ok;
        }
    }
}

function LocationIs(location_id) {
    return new _LocationIs(location_id);
}

function _LocationIs(location_id): __Leaf() constructor {
    self.location_id = location_id;

    run = function(blackboard) {
        var npc = blackboard.get("me");
        var location_id = self.location_id;
        if is_string(location_id) {
            location_id = blackboard.get(location_id);
        }
        if (npc.location_position.location_id == location_id) {
            return Status.Ok;
        } else {
            return Status.Err;
        }
    }
}

function GetTime(save_name) {
    return new _GetTime(save_name);
}

function _GetTime(save_name): __Leaf() constructor {
    self.save_name = save_name;
    run = function(blackboard) {
        blackboard.set(self.save_name, CLOCK.time);
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
//
//
function Wait(frames) {
    return Sequence(
        Set("wait_frames", frames),
        Run(function(bb) {
            bb.set("awake_on", TICK + bb.get("wait_frames"));
            return Status.Ok;
        }),
        RepeatUntilSuccess(
            Run(function(bb) {
                return TICK >= bb.get("awake_on") ? Status.Ok : Status.Err;
            })
        )
    )
}
