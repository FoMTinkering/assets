#macro EULERS_NUMBER 2.7182818284590452353602874713527
//
function PerlinObjectRange(_density) {
    return new __PerlinObjectRange(_density);
}

function __PerlinObjectRange(_density) constructor {
    assert(_density >= 0 && _density <= 1, "Density for PerlinObjectRanges must be between 0 and 1");
    self.density = _density;
    self.objects = List();

    //
    self.__cached_votes = new SlowVotes();

    static add_range = function(_id, _min, _max, _spawn_conditions) {
        //
        var _object_range = {
            object_id: _id,
            spawn_conditions: _spawn_conditions,
            perlin_data: {}
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
        var _sigma = (_max - _min - 0.03) / 6;
        //
        _object_range.perlin_data.min = _min;
        //
        _object_range.perlin_data.max = _max;
        //
        //
        _object_range.perlin_data.mean = (_min + _max)/2;
        //
        //
        //
        //
        _object_range.perlin_data.factor_a = 1 / (_sigma * sqrt(2 * pi));
        //
        _object_range.perlin_data.factor_b = - 1 / (2 * sqr(_sigma));
        //
        //

        self.objects.push(_object_range);
        return self;
    }

    //
    static get_object_votes_at_cell = function(_grid, _perlin_value, _x, _y) {
        self.__cached_votes.clear();

        //
        //
        //
        if(random_range(0, 1) <= self.density) {
            //
            var _count = self.objects.count();
            for(var i = 0; i < _count; i++) {
                //
                var _obj = self.objects.get(i);
                var _perlin_data = _obj.perlin_data;
                //
                //
                if(_perlin_value >= _perlin_data.min && _perlin_value <= _perlin_data.max) {
                    //
                    var _spawn_votes = _obj.spawn_conditions.get_votes_at_cell(_grid, _x, _y);
                    //
                    if(_spawn_votes > 0) {
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
                        var a = _perlin_data.factor_a;
                        var b = _perlin_data.factor_b;
                        var c = sqr(_perlin_value - _perlin_data.mean);

                        //
                        var _probability = a * power(EULERS_NUMBER, c * b);

                        //
                        //
                        var _modified_votes = floor(_spawn_votes * _probability * 10);
                        //
                        self.__cached_votes.add_candidate(_obj.object_id, _modified_votes);
                    }
                }
            }
        }

        //
        return self.__cached_votes;
    }
}
