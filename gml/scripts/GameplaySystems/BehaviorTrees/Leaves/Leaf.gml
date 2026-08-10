function WaitOneFrame() {
    return new _WaitOneFrame();
}
function _WaitOneFrame(): __Leaf() constructor {
    has_ran = undefined;

    run = function() {
        if (has_ran == undefined) {
            has_ran = true;
            __CURRENT_RUNNING_TREE.stack.push(self);
            return Status.Tick;
        } else {
            has_ran = undefined;
            var popped = __CURRENT_RUNNING_TREE.stack.pop();
            assert_eq(popped, self);
            return Status.Ok;
        }
    }

    interrupt = function() {
        has_ran = undefined;
    }
}

function Printf(msg) {
    return new _Printf(msg);
}
function _Printf(msg): __Leaf() constructor {
    self.msg = msg;

    run = function(bb) {
        var keys = bb.keys();
        for (var i = 0; i < array_length(keys); i++) {
            var tag = "{" + keys[i] + "}";
            if string_pos(tag, self.msg) != 0 {
                self.msg = string_replace_all(self.msg, tag, string(bb[$ keys[i]]));
            }
        }
        var insert;
        if bb.get("is_animal") == true {
            insert = bb.get("me").name;
        } else {
            insert = capitalize(npc_id_to_string(bb.get("me").id));
        }
        trace("[{}'s Brain]: {}", insert, self.msg);
        return Status.Ok;
    }
}

function PrintValue(vname) {
    return new _PrintValue(vname);
}
function _PrintValue(_vname): __Leaf() constructor {
    vname = _vname;

    run = function(blackboard) {
        trace("Brain Value: {}", blackboard.get(vname));
        return Status.Ok;
    }
}

function FailPrintf(_msg, _log_level) {
    _log_level = _log_level == undefined ? LogLevel.Trace : _log_level;
    return new _FailPrintf(_log_level, _msg);
}
function _FailPrintf(_log_level, _msg): __Leaf() constructor {
    log_level = _log_level;
    msg = [_msg];

    run = function(_) {
        __log(self.log_level, self.msg);
        return Status.Err;
    }
}

function StatusLiteral(_status) {
    return new _StatusLiteral(_status);
}
function _StatusLiteral(_status): __Leaf() constructor {
    //
    switch (_status) {
        case Status.Ok:
        case Status.Err:
        case Status.Tick:
            break;
        default: impossible();
    }

    status = _status;
    run = function() {
        return self.status;
    }
}

function __Leaf() constructor {
    type = NodeType.Leaf;

    run_on_init = undefined;
    run = undefined;
    interrupt = function() {
        //
    }
}
