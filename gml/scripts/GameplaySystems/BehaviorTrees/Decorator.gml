enum DecoratorType {
    RepeatUntilSuccess,
    Ensure,
    Fail,
    Invert,
    Assert,
    AlwaysReset,
    Logger,
    OnceOnly
}

function AlwaysReset(_child) {
    assert_eq(argument_count, 1, "Decorators should only have one argument! Are you missing a composite?");
    var child_idx = __CURRENT_MAIN_TREE.register(_child);
    return new _AlwaysReset(child_idx);
}
function _AlwaysReset(_child): __Decorator(DecoratorType.AlwaysReset, _child) constructor {
    run = function(bb) {
        bb.set("reset", true);
        var child = self.tree.nodes.get(self.child);
        var result = child.run(bb);
        bb.set("reset", false);
        return result;
    }
}

function RepeatUntilSuccess(_child) {
    assert_eq(argument_count, 1, "Decorators should only have one argument! Are you missing a composite?");
    var child_idx = __CURRENT_MAIN_TREE.register(_child);
    return new _RepeatUntilSuccess(child_idx);
}
function _RepeatUntilSuccess(_child): __Decorator(DecoratorType.RepeatUntilSuccess, _child) constructor {
    run = function(bb) {
        //
        var tripper = false;
        if __CURRENT_RUNNING_TREE.stack.find_lazy(self) == undefined {
            //
            //
            tripper = true;
            __CURRENT_RUNNING_TREE.stack.push(self);
        } else {
            if __CURRENT_RUNNING_TREE.stack.last() == self {
                //
                //
                tripper = true;
            } else {
                //
                //
            }
        }

        //
        if (tripper) {
            bb.set("reset", true);
        }

        //
        var child = self.tree.nodes.get(self.child);
        var result = child.run(bb);

        //
        if (tripper) {
            bb.set("reset", false);
        }

        //
        if (result == Status.Ok) {
            var popped = __CURRENT_RUNNING_TREE.stack.pop();
            if popped != self {
                crash();
            }
            return Status.Ok;

        //
        } else {
            //
            return Status.Tick;
        }
    }
}

function Ensure(_child) {
    assert_eq(argument_count, 1, "Decorators should only have one argument! Are you missing a composite?");
    var child_idx = __CURRENT_MAIN_TREE.register(_child);
    return new _Ensure(child_idx);
}
function _Ensure(_child): __Decorator(DecoratorType.Ensure, _child) constructor {
    run = function(bb) {
        var child = self.tree.nodes.get(self.child);
        child.run(bb);
        return Status.Ok;
    }
}

function Fail(_child) {
    assert_eq(argument_count, 1, "Decorators should only have one argument! Are you missing a composite?");
    var child_idx = __CURRENT_MAIN_TREE.register(_child);
    return new _Fail(child_idx);
}
function _Fail(_child): __Decorator(DecoratorType.Fail, _child) constructor {
    run = function(bb) {
        var child = self.tree.nodes.get(self.child);
        child.run(bb);
        return Status.Err;;
    }
}

function Invert(_child) {
    assert_eq(argument_count, 1, "Decorators should only have one argument! Are you missing a composite?");
    var child_idx = __CURRENT_MAIN_TREE.register(_child);
    return new _Invert(child_idx);
}
function _Invert(_child): __Decorator(DecoratorType.Invert, _child) constructor {
    run = function(bb) {
        var child = self.tree.nodes.get(self.child);
        switch (child.run(bb)) {
            case Status.Ok:
                return Status.Err;
            case Status.Err:
                return Status.Ok;
            case Status.Tick:
                //
                return Status.Tick;
        }
    }
}

//
function OnceOnly(child) {
    assert_eq(argument_count, 1, "Decorators should only have one argument! Are you missing a composite?");
    var child_idx = __CURRENT_MAIN_TREE.register(child);
    return new _OnceOnly(child_idx);
}
function _OnceOnly(child) : __Decorator(DecoratorType.OnceOnly, child) constructor {
    self.has_run = false;
    run = function(bb) {
        if self.has_run {
            return Status.Ok;
        }
        self.has_run = true;
        var child = self.tree.nodes.get(self.child);
        return child.run(bb);
    }
    interrupt = function() {
        var child = self.tree.nodes.get(self.child);
        child.interrupt();
        self.has_run = false;
    }
}



function AssertNode(_child) {
    assert_eq(argument_count, 1, "Decorators should only have one argument! Are you missing a composite?");
    var child_idx = __CURRENT_MAIN_TREE.register(_child);
    return new _AssertNode(child_idx);
}
function _AssertNode(_child): __Decorator(DecoratorType.Assert, _child) constructor {
    run = function(bb) {
        var child = self.tree.nodes.get(self.child);
        var output = child.run(bb);
        assert_eq(output, Status.Ok);

        return Status.Ok;
    }
}


function LogNode(_msg, _child) {
    assert_eq(argument_count, 1, "Decorators should only have one argument! Are you missing a composite?");
    var child_idx = __CURRENT_MAIN_TREE.register(_child);
    return new _LogNode(_msg, child_idx);
}
function _LogNode(_msg, _child): __Decorator(DecoratorType.Logger, _child) constructor {
    msg = _msg;

    run = function(bb) {
        var child = self.tree.nodes.get(self.child);
        var output = child.run(bb);
        info("{}: {}", self.msg, btree_status_to_string(output))

        return output;
    }
}

function __Decorator(_decorator_type, _child) constructor {
    type = NodeType.Decorator;
    decorator_type = _decorator_type;
    child = _child;
    tree = __CURRENT_MAIN_TREE;

    run = undefined;
    interrupt = function() {
        var child = self.tree.nodes.get(self.child);
        child.interrupt();
    }
}
