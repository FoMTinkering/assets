//
//
//
//
function Ref(struct) {
    return new __Ref(struct);
}

//
function __Ref(struct) constructor {
    assert(is_struct(struct), "Ref only works with structs!");
    self.__inner = weak_ref_create(struct);

    //
    static get = function(property_name) {
        assert(weak_ref_alive(self.__inner), "Reference has been lost!");
        assert(
            struct_exists(self.__inner.ref, property_name),
            "Inner struct does not have property '{}'!",
            property_name
        );
        return self.__inner.ref[$ property_name];
    }

    //
    static call = function(function_name, function_args) {
        var func = self.get(function_name);
        return function_execute_alt(func, function_args);
    }

    //
    static alive = function() {
        return weak_ref_alive(self.__inner);
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
    static clone_inner = function() {
        return self.__clone_struct(self.__inner.ref);
    }

    //
    static __clone_struct = function(struct) {
        if instanceof(struct) == "__List" {
            return ListFromArray(self.__clone_array(struct.__buffer));
        }
        var clone = {};
        var names = struct_get_names(struct);
        for (var i = 0, c = array_length(names); i < c; i++) {
            var name = names[i];
            var value = struct[$ name];
            if is_struct(value) {
                value = self.__clone_struct(value);
            } else if is_array(value) {
                value = self.__clone_array(value);
            }
            clone[$ name] = value;
        }
        return clone; //
    }

    //
    static __clone_array = function(array) {
        var clone = [];
        for (var i = 0, c = array_length(array); i < c; i++) {
            var value = array[i];
            if is_struct(value) {
                value = self.__clone_struct(value);
            } else if is_array(value) {
                value = self.__clone_array(value);
            }
            clone[i] = value;
        }
        return clone;
    }
}
