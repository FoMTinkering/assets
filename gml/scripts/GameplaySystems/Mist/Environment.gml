global.env_count = 0; //

//
//
//
//
//
//
//
//
//
function Environment(_runtime, _enclosing) constructor {
    self.idx = global.env_count++;
    self.map = Map();
    self.runtime = _runtime;
    self.enclosing = _enclosing;

    //
    static define = function(_name, _value) {
        self.map.set(_name, _value);
    }

    //
    //
    static has = function(_name) {
        return self.map.contains_key(_name)
        || (self.enclosing != undefined && self.enclosing.has(_name));
    }

    //
    static get = function(_name) {
        if self.map.contains_key(_name) {
            return self.map.get(_name);
        } else if self.enclosing != undefined && self.enclosing.has(_name) {
            return self.enclosing.get(_name);
        } else {
            crash("Undefined variable: {}", _name);
        }
    }

    //
    static assign = function(_name, _value) {
        if self.map.contains_key(_name) {
            self.map.set(_name, _value);
            return _value;
        } else if self.enclosing != undefined {
            self.enclosing.assign(_name, _value);
            return _value;
        } else {
            crash("Undefined variable: {}", _name);
        }
    }

    //
    static clear = function() {
        self.map.clear();
    }


}
