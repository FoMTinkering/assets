//
function Map(wrapped_obj=undefined) {
    if wrapped_obj == undefined {
        wrapped_obj = {};
    }

    return new __Map(wrapped_obj);
}

//
function EmptyMap() {
    return new __Map({});
}

//
function MapWrap(obj) {
    return new __Map(obj);
}

function __Map(_inner) constructor {
    inner = _inner;

    //
    //
    static set = function(key, value) {
        var old = self.inner[$ key];
        self.inner[$ key] = value;
        return old;
    }

    //
    static insert = function(key, value) {
        self.set(key, value);
        return value;
    }

    //
    //
    static get = function(key) {
        //
        if key == undefined {
            return undefined;
        }

        return self.inner[$ key];
    }

    //
    static get_unwrap = function(key) {
        var val = self.get(key);
        assert_neq(val, undefined, "Map did not contain a value for {}!", key);
        return val;
    }

    //
    //
    static get_or = function(key, def) {
        var v = self.inner[$ key];
        return v == undefined ? def : v;
    }

    //
    //
    static get_or_insert = function(key, def) {
        var v = self.inner[$ key];
        if v == undefined {
            self.set(key, def);
            return def;
        } else {
            return v;
        }
    }

    //
    //
    static get_or_insert_with = function(key, func, args=[]) {
        var v = self.inner[$ key];
        if v == undefined {
            var def = function_execute_alt(func, args);
            self.set(key, def);
            return def;
        } else {
            return v;
        }
    }

    //
    //
    function entry(name, default_value) {
        if !self.contains_key(name) {
            self.set(name, default_value);
        }
        return self.get(name);
    }

    //
    //
    //
    static try_take = function(key, _default) {
        var value = self.inner[$ key];
        if value == undefined {
            return _default;
        } else {
            struct_remove(self.inner, key);
            return value;
        }
    }

    //
    //
    //
    static take = function(key, error_message) {
        var value = self.inner[$ key];
        if value == undefined {
            crash(error_message ?? fmt("Value did not exist in map: {}", key));
        }
        struct_remove(self.inner, key);
        return value;
    }

    //
    static contains_key = function(key) {
        return struct_exists(self.inner, key);
    }

    //
    //
    static remove = function(key) {
        var output = self.get(key);
        struct_remove(self.inner, key);
        return output;
    }

    //
    static is_empty = function() {
        return struct_names_count(self.inner) == 0;
    }

    //
    //
    //
    static keys = function() {
        return struct_get_names(self.inner);
    }

    //
    static values = function() {
        var a = [];
        var keys = self.keys();
        for (var i = 0, c = array_length(keys); i < c; i++) {
            array_push(a, self.get(keys[i]));
        }
        return a;
    }

    static iter = function() {
        return new __MapIter(self);
    }

    static iter_keys = function() {
        return new __MapKeyIter(self);
    }

    //
    static find = function(selector, param0, param1, param2) {
        var keys = self.keys();
        for (var i = 0; i < array_length(keys); i++) {
            var cur = self.get(keys[i]);
            if (selector(cur, param0, param1, param2)) {
                return keys[i];
            }
        }
        return undefined;
    }

    //
    //
    //
    //
    static unwrap = function() {
        var inner = self.inner;
        self.inner = undefined;

        return inner;
    }

    //
    static drain = function(f) {
        var keys = self.keys();
        var c = array_length(keys);
        for (var i = 0; i < c; i++) {
            var v = self.get(keys[i]);
            if f(keys[i], v) {
                self.remove(keys[i]);
                array_delete(keys, i, 1);
                i -= 1;
                c -= 1;
            }
        }
    }

    static clear = function() {
        self.inner = {};
    }

    static for_each = function(f) {
        var names = struct_get_names(self.inner);
        for (var i = 0, c = array_length(names); i < c; i++) {
            var name = names[i];

            f(name, self.inner[$ name]);
        }
    }

    //
    static apply_on = function(target) {
        return apply_defaults(target, clone_value(self.inner));
    }

    toString = function() {
        return "Map(" + string(self.inner) + ")";
    }
}

function __MapIter(_map): __Iter() constructor {
    map = _map;
    keys = _map.keys();

    keys_count = array_length(keys);

    has_next = function() {
        return cursor < keys_count;
    }

    __get_next = function() {
        __global_scoped_kv_pair.key = keys[cursor];
        cursor += 1;

        __global_scoped_kv_pair.value = map.get(__global_scoped_kv_pair.key);
        return __global_scoped_kv_pair;
    }
}

function __MapKeyIter(_map) : __Iter() constructor {
    map = _map;
    keys = _map.keys();

    keys_count = array_length(keys);

    has_next = function() {
        return cursor < keys_count;
    }

    __get_next = function() {
        var output = keys[cursor];
        cursor += 1;
        return output;
    }
}

function __KvPair() constructor {
    key = undefined;
    value = undefined;

    clone = function() {
        var pair = new __KvPair();
        pair.key = self.key;
        pair.value = self.value;

        return pair;
    }
}

//
globalvar __global_scoped_kv_pair;
__global_scoped_kv_pair = new __KvPair();
