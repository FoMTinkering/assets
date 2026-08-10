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
function SpawnDistribution() constructor {
    self.spawnable_candidates = List();

    static add_candidate = function(_spawnable_candidate_id, _spawn_conditions) {
        self.spawnable_candidates.push(
            new __SpawnableCandidate(_spawnable_candidate_id, _spawn_conditions)
        );
        return self;
    }

    //
    static modify_all = function(_function) {
        var a = array_create(argument_count);

        //
        for(var i = 1; i < argument_count; i++) {
            a[i] = argument[i];
        }

        //
        for(var i = 0, c = self.spawnable_candidates.count(); i < c; i++) {
            var candidate = self.spawnable_candidates.get(i);
            //
            a[0] = candidate;
            //
            function_execute_alt(_function, a);
        }
    }

    //
    static get_candidate_votes_at_cell = function(grid, cell_x, cell_y) {
        return new __SpawnableCandidateVotes(self.spawnable_candidates, grid, cell_x, cell_y);
    }

    //
    //
    //
    //
    //
    function __SpawnableCandidate(_spawnable_candidate_id, _spawn_conditions) constructor {
        self.candidate_id = _spawnable_candidate_id;
        self.spawn_conditions = _spawn_conditions;
    }

    function __SpawnableCandidateVotes(spawnable_candidates, grid, cell_x, cell_y) constructor {
        self.votes = new SlowVotes();

        //
        //
        //
        for (var i = 0, _len = spawnable_candidates.count(); i < _len; i++) {
            var candidate = spawnable_candidates.get(i);

            var candidate_votes = candidate.spawn_conditions.get_votes_at_cell(grid, cell_x, cell_y);

            //
            if candidate_votes > 0 {
                self.votes.add_candidate(candidate.candidate_id, candidate_votes);
            }
        }

        //
        static get_candidate = function() {
            return self.votes.get_candidate();
        }
    }
}
