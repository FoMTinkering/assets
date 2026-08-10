#macro IN_ROOM_BRAIN_FREQUENCY 60
assert(IN_ROOM_BRAIN_FREQUENCY mod 5 == 0, "The brain tick rate must be divisible by 5!");

#macro OUT_OF_ROOM_BRAIN_FREQUENCY 60
assert(OUT_OF_ROOM_BRAIN_FREQUENCY mod 5 == 0, "The brain tick rate must be divisible by 5!");

#macro ANIMAL_BRAIN_FREQUENCY 600
assert(ANIMAL_BRAIN_FREQUENCY mod 5 == 0, "The brain tick rate must be divisible by 5!");

enum Status {
    Ok,
    Err,
    Tick,
}

enum NodeType {
    Composite,
    Decorator,
    Leaf,
}

enum TreeType {
    Main,
    Sub,
}

function MainTree(children, nodes): __Tree(children, nodes, TreeType.Main) constructor  {
    self.cursor = 0;

    static TICK_ITER = 0;

    self.ticks_until_run = wrap(TICK_ITER, OUT_OF_ROOM_BRAIN_FREQUENCY + 1);

    TICK_ITER += 1;

    run = function() {
        var c = self.children.count();

        for (var i = self.cursor; i < c; i++) {
            var child_idx = self.children.get(i);
            var child = self.nodes.get(child_idx);
            var result = child.run(self.blackboard);
            switch (result) {
                case Status.Ok:
                    break;
                case Status.Tick:
                    self.cursor = i;
                    return;
                case Status.Err:
                    continue;
            }
        }
        self.cursor = 0;
    };

    interrupt = function() {
        var c = self.children.count();
        for (var i = 0; i < c; i++) {
            var child_idx = self.children.get(i);
            var child = self.nodes.get(child_idx);
            child.interrupt();
        }
        self.cursor = 0;
        self.blackboard = Map();
        self.stack.clear();
    }
}

function __Tree(_children, nodes, _stack, _tree_type) constructor {
    self.tree_type = _tree_type;
    self.children = _children;
    self.nodes = nodes;
    self.stack = List();
    self.blackboard = Map();
    self.run = undefined;
    self.interrupt = undefined;
}
