//
//
//
//
//
function SpawnConditions() constructor {
    self.sum_conditions = List();
    self.required_conditions = List();

    //
    //
    //
    //
    static add = function(_votes, _condition) {
        var v = typeof(_votes);
        assert(matches(v, "number", "int32", "int64"), "First argument 'votes' was a '{}', but it must be a number!", v);
        self.sum_conditions.push({
            condition: _condition == undefined ? Condition.None : _condition,
            votes: _votes,
        });
        return self;
    }

    //
    //
    static require = function(_condition) {
        self.required_conditions.push({
            condition: _condition == undefined ? Condition.None : _condition,
            votes: undefined,
        });
        return self;
    }

    //
    static get_votes_at_cell = function(grid, cell_x, cell_y) {
        //
        for(var i = 0, c = self.required_conditions.count(); i < c; i++) {
            var spawn_condition = self.required_conditions.get(i);

            if test_condition(grid, spawn_condition.condition, cell_x, cell_y) == false {
                return 0;
            }
        }

        //
        var sum_votes = self.sum_conditions.count() == 0 ? 1 : 0;
        for (var i = 0, c = self.sum_conditions.count(); i < c; i++) {
            var spawn_condition = self.sum_conditions.get(i);
            if test_condition(grid, spawn_condition.condition, cell_x, cell_y) {
                sum_votes += spawn_condition.votes;
            }
        }

        return max(sum_votes, 0);
    }

    //
    static clone = function() {
        var me = new SpawnConditions();
        me.sum_conditions = self.sum_conditions.map_to(function(v) {
            return {
                condition: clone_condition(v.condition),
                votes: v.votes,
            }
        });
        me.required_conditions = self.required_conditions.map_to(function(v) {
            return {
                condition: clone_condition(v.condition),
                votes: v.votes,
            }
        });

        return me;
    }
}
