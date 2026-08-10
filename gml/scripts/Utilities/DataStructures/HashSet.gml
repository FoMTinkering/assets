//
function HashSet() {
    return new __HashSet();
}

function HashSetFromArray(a) {
    var h = HashSet();
    for (var i = 0; i < array_length(a); i++) {
        h.insert(a[i]);
    }
    return h;
}

function __HashSet() constructor {
    inner = {};

    //
    static insert = function(key) {
        var old = self.inner[$ key];
        self.inner[$ key] = 0;
        return old != undefined;
    }

    //
    static contains = function(key) {
        return struct_exists(self.inner, key);
    }

    //
    static contains_hash = function(hash_key) {
        return struct_get_from_hash(self.inner, hash_key) != undefined;
    }

    //
    static remove = function(key) {
        struct_remove(self.inner, key);
    }

    //
    static is_empty = function() {
        return self.count() == 0;
    }

    //
    static count = function() {
        return array_length(self.keys());
    }

    //
    static copy_from = function(hash_set) {
        var keys = hash_set.keys();
        for (var i = 0; i < array_length(keys); i++) {
            self.insert(keys[i]);
        }
    }

    //
    //
    static find_missing = function(o) {
        var missing = List();
        var k = o.keys();
        for (var i = 0; i < array_length(k); i++) {
            if !self.contains(k[i]) {
                missing.push(k[i]);
            }
        }
        return missing;
    }

    //
    static keys = function() {
        return struct_get_names(self.inner);
    }

    //
    static toString = function() {
        var output = "HashSet[";
        var data = keys();
        for (var i = 0, c = array_length(data); i < c; i++) {
            var value = data[i];
            if value == self {
                output += "[~RECURSION~]";
            } else {
                output += string(value);
            }
            if (i + 1 != c) {
                output += ", ";
            }
        }

        output += "]";

        return output;
    }

    static join = function(hashset) {
        var arr = hashset.keys();
        for(var i = 0, c = array_length(arr); i < c; i++) {
            self.insert(arr[i]);
        }
    }

    static clear = function() {
        self.inner = {};
    }
}
