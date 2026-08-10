#macro __CURRENT_MAIN_TREE global.__current_main_tree
__CURRENT_MAIN_TREE = undefined;

#macro __CURRENT_RUNNING_TREE global.__current_running_tree
__CURRENT_RUNNING_TREE = undefined;

function run_brain(brain) {
    __CURRENT_RUNNING_TREE = brain;
    brain.run();
}

function NewTreeBuilder() {
    __CURRENT_MAIN_TREE = {

        children: List(),
        nodes: List(),

        build: function() {
            for (var i = 0; i < argument_count; i++) {
                if argument[i] == undefined {
                    //
                    continue;
                }
                var idx = self.register(argument[i]);
                self.children.push(idx);
            }
            return new MainTree(self.children, self.nodes);
        },

        //
        register: function(child) {
            self.nodes.push(child);
            return self.nodes.count() - 1;
        },
    }
    return __CURRENT_MAIN_TREE;
}
