enum CompositeType {
    Selector,
    Sequence,
}

function Sequence() {
    var children = List();
    for (var i = 0; i < argument_count; i++) {
        if argument[i] == undefined {
            //
            continue;
        }
        var idx = __CURRENT_MAIN_TREE.register(argument[i]);
        children.push(idx);
    }
    return new __Sequence(children);
}
function __Sequence(children): __Composite(children) constructor {

    run = function(blackboard) {
        var c = self.children.count();
        if (blackboard.get("reset")) {
            self.cursor = 0;
        }

        for (var i = self.cursor; i < c; i++) {
            var child_idx = self.children.get(i);
            var child = self.tree.nodes.get(child_idx);
            var result = child.run(blackboard);
            switch result {
                case Status.Ok: break;
                case Status.Tick:
                    self.cursor = i;
                    return result;
                case Status.Err:
                    self.cursor = 0;
                    return result;
                default: impossible("Unexpected result: {Status}", result);
            }
        }

        self.cursor = 0;
        return Status.Ok;
    }
}

function Selector() {
    var children = List();
    for (var i = 0; i < argument_count; i++) {
        if argument[i] == undefined {
            //
            continue;
        }
        var idx = __CURRENT_MAIN_TREE.register(argument[i]);
        children.push(idx);
    }
    return new __Selector(children);
}
function __Selector(children) : __Composite(children) constructor {

    run = function(blackboard) {
        var c = self.children.count();
        for (var i = self.cursor; i < c; i++) {
            var child_idx = self.children.get(i);
            var child = self.tree.nodes.get(child_idx);
            var result = child.run(blackboard);
            switch (result) {
                case Status.Ok:
                    self.cursor = 0;
                    return Status.Ok;
                case Status.Tick:
                    self.cursor = i;
                    return Status.Tick;
                case Status.Err:
                    continue;
                default:
                    impossible("happened at child {}", i);
            }
        }
        self.cursor = 0;
        return Status.Err;
    }
}

function __Composite(children) constructor {
    self.children = children;
    self.tree = __CURRENT_MAIN_TREE;
    self.cursor = 0;

    run = undefined;
    interrupt = function() {
        self.cursor = 0;
        var c = self.children.count();
        for (var i = 0; i < c; i++) {
            var child_idx = self.children.get(i);
            var child = self.tree.nodes.get(child_idx);
            child.interrupt();
        }
    }
}
