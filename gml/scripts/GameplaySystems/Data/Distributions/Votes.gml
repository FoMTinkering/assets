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
function SlowVotes() constructor {
    //
    self.candidates = List();
    //
    self.total = 0;

    static is_candidate = function(_candidate_id) {
        for(var i = 0, c = candidates.count(); i < c; i++) {
            if(self.candidates.get(i).candidate_id == _candidate_id) {
                return true;
            }
        }
        return false;
    }

    static clear = function() {
        self.candidates.clear();
        self.total = 0;
    }

    static add_candidate = function(_candidate, _votes) {
        assert_eq(_votes, round(_votes), "Votes must be integers!");
        self.candidates.push({
            candidate_id: _candidate,
            votes: _votes,
        });
        self.total += _votes;
        return self;
    }

    //
    //
    //
    static get_candidate = function() {
        var index = self.get_candidate_index();
        if index == undefined {
            return undefined;
        } else {
            return self.candidates.get(index).candidate_id;
        }
    }

    static take_candidate = function() {
        var _num = irandom_range(0, self.total);
        for(var i = 0, _cursor = 0, c = self.candidates.count(); i < c; i++) {
            _cursor += self.candidates.get(i).votes;
            if(_num < _cursor) {
                self.candidates.get(i).votes--;
                self.total--;
                return self.candidates.get(i).candidate_id;
            }
        }
        return undefined;
    }

    static withdraw_candidate = function() {
        var _num = irandom_range(0, self.total);
        for(var i = 0, _cursor = 0, c = self.candidates.count(); i < c; i++) {
            _cursor += self.candidates.get(i).votes;
            if(_num < _cursor) {
                return self.candidates.remove(i).candidate_id;
            }
        }
        return undefined;
    }

    //
    //
    static into_historical_votes = function(strength=1, memory_length=undefined) {
        var candidate_count = self.candidates.count();
        var historical_votes = HistoricalVotes(strength, memory_length ?? candidate_count);
        for (var i = 0; i < candidate_count; i++) {
            var candidate = self.candidates.get(i);
            historical_votes.add_candidate(candidate.candidate_id, candidate.votes);
        }
        return historical_votes;
    }

    //
    //
    static get_candidate_index = function() {
        var _num = random_range(0, self.total);
        for(var i = 0, _cursor = 0, c = self.candidates.count(); i < c; i++) {
            _cursor += self.candidates.get(i).votes;
            if(_num <= _cursor) {
                return i;
            }
        }
        return undefined;
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
//
//
//
//
//
//
//
//
//
function HistoricalVotes(strength, memory_length) {
    return new __HistoricalVotes(strength, memory_length);
}
function __HistoricalVotes(strength, memory_length) constructor {
    self.candidates = List();
    self.total = 0;
    self.strength = strength;
    self.memory_length = memory_length;

    //
    //
    //
    static get_candidate = function(callback=undefined, args=[]) {
        #macro MAX_VOTE_ITERS 1000
        static ITER = 0;

        //
        var selection_index = self.get_candidate_index();

        //
        var candidate = self.candidates.get(selection_index);
        if callback != undefined {
            var call_array = [candidate.candidate_id];
            array_copy(call_array, 1, args, 0, array_length(args));
            if !function_execute_alt(callback, call_array) {
                ITER += 1;
                if ITER > MAX_VOTE_ITERS {
                    warn("HistoricalVotes failed to find a value!");
                    ITER = 0;
                    return undefined;
                } else {
                    return self.get_candidate(callback, args);
                }
            }
        }

        //
        self.total = 0;
        var total_candidates = self.candidates.count();
        for (var i = 0; i < total_candidates; i++) {
            var candidate = self.candidates.get(i);
            if i == selection_index {
                //
                candidate.votes = candidate.original_votes * (1 - self.strength);
            } else {
                //
                var per_tick_increment = (candidate.original_votes * self.strength) / self.memory_length;
                candidate.votes = min(
                    candidate.votes + per_tick_increment,
                    candidate.original_votes,
                );
            }
            self.total += candidate.votes;
        }

        //
        var candidate = self.candidates.get(selection_index);
        ITER = 0;
        return candidate.candidate_id;
    }

    //
    static add_candidate = function(candidate, votes) {
        self.candidates.push({
            candidate_id: candidate,
            votes: votes,
            original_votes: votes,
        });
        self.total += votes;
        return self;
    }

    //
    //
    static get_candidate_index = function() {
        var num = random_range(0, self.total);
        for (var i = 0, cursor = 0, c = self.candidates.count(); i < c; i++) {
            cursor += self.candidates.get(i).votes;
            if num <= cursor {
                return i;
            }
        }
        return undefined;
    }

    //
    static clone = function() {
        var new_votes = HistoricalVotes(self.strength, self.memory_length);
        new_votes.total = self.total;
        new_votes.candidates = Ref(self.candidates).clone_inner();
        return new_votes;
    }
}

//
function historical_votes_test() {
    //
    var votes = new SlowVotes();
    votes = votes
        .add_candidate("A", 100)
        .add_candidate("B", 100)
        .into_historical_votes();
    var first = votes.get_candidate();
    for (var i = 0; i < votes.candidates.count(); i++) {
        var candidate = votes.candidates.get(i);
        if candidate.candidate_id == first {
            assert_eq(candidate.votes, 0, "First candidate should have had 0 votes, but has {}", candidate.votes);
            break;
        }
    }
    var second = votes.get_candidate();
    assert_neq(first, second, "Pulled the first member out again! This shouldn't be possible.");
    for (var i = 0; i < votes.candidates.count(); i++) {
        var candidate = votes.candidates.get(i);
        if candidate.candidate_id == first {
            assert_eq(candidate.votes, 50, "First candidate should have had 50 votes, but has {}", candidate.votes);
        } else if candidate.candidate_id == second {
            assert_eq(candidate.votes, 0, "Second candidate should have had 0 votes, but has {}", candidate.votes);
        }
    }

    //
    var votes = new SlowVotes();
    votes = votes
        .add_candidate("A", 50)
        .add_candidate("B", 100)
        .into_historical_votes(0.5, 5);
    var first = votes.get_candidate();
    for (var i = 0; i < votes.candidates.count(); i++) {
        var candidate = votes.candidates.get(i);
        if candidate.candidate_id == first {
            assert_eq(
                candidate.votes,
                candidate.original_votes * 0.5,
                "First candidate should have had {} votes, but has {}",
                candidate.original_votes * 0.5,
                candidate.votes
            );
            break;
        }
    }
}
