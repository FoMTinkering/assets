#macro MINIMUM_DEFAULT_SIZE 4

//
//
//
//
//
//
//
function List() {
    var backing_array = array_create(argument_count);
    for (var i = 0; i < argument_count; i++) {
        backing_array[i] = argument[i];
    }

    return new __List(backing_array, argument_count);
}

//
function EmptyList() {
    return new __List([], 0);
}

//
//
//
//
//
//
function ListPreAllocate(size) {
    return new __List(array_create(size, 0), 0);
}

//
//
//
//
function ListFromArray(arr) {
    return new __List(arr, array_length(arr));
}

function __List(arr, c) constructor {
    __count = c;
    __internal_size = array_length(arr);
    __buffer = arr;

    static count = function() {
        return __count;
    }

    //
    static clone = function() {
        if (self.is_empty()) {
            return List();
        }
        var new_array = array_create(self.count(), 0);
        array_copy(new_array, 0, self.__buffer, 0, self.count());

        return ListFromArray(new_array);
    }

    static push = function(item) {
        self.ensure_size(self.__count + 1);

        self.__buffer[__count] = item;
        self.__count++;
    }

    //
    //
    //
    //
    //
    //
    static pop = function() {
        if (self.__count > 0) {
            var ret = self.get(self.__count - 1);
            self.__count--;
            return ret;
        } else {
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
    static insert = function(item, idx) {
        assert(idx >= 0 && idx < self.__count, "tried index insert at {}, but count is {}", idx, self.__count);
        var old_count = self.__count;
        self.ensure_size(self.__count + 1);

        //
        for (var i = old_count - 1; i > (idx - 1); i--) {
            self.__buffer[i + 1] = self.__buffer[i];
        }

        self.__buffer[idx] = item;
        self.__count++;
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
    static transfer = function(other_list) {
        self.copy_from(other_list);

        //
        other_list.clear();
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
    static copy_from = function(other_list) {
        //
        self.ensure_size(self.__count + other_list.count());

        //
        array_copy(self.__buffer, self.__count, other_list.__buffer, 0, other_list.__count);
        self.__count += other_list.count();
        return self;
    }

    //
    static get = function(idx) {
        assert(idx >= 0 && idx < self.__count, "tried index get at {}, but count is {}", idx, self.__count);
        return self.__buffer[idx];
    }

    //
    static set = function(idx, item) {
        assert(idx >= 0 && idx < self.__count, "tried index set at {}, but count is {}", idx, self.__count)

        self.__buffer[idx] = item;
    }

    //
    //
    static try_get = function(idx) {
        if (idx >= 0 && idx < self.__count) {
            return self.__buffer[idx];
        } else {
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
    static try_set = function(idx, item) {
        if (idx > 0 && idx < self.__count) {
            self.__buffer[idx] = item;
            return true;
        } else {
            return false;
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
    static swap_remove = function(idx) {
        assert(idx >= 0 || idx < self.__count, "tried swap-remove at {}, but count is {}", idx, self.__count);

        //
        self.__count--;

        var old = self.__buffer[idx];

        //
        if (self.__count != 0) {
            var swapper = self.__buffer[self.__count];
            self.__buffer[idx] = swapper;
        }

        return old;
    }

    //
    //
    //
    //
    //
    //
    static remove = function(idx) {
        //
        if (self.__count == 1) {
            return self.swap_remove(0);
        }

        assert(idx >= 0 && idx < self.__count, "tried index remove at {}, but count is {}", idx, self.__count);

        //
        var value = self.__buffer[idx];
        self.__count--;

        //
        //
        var a = [];
        array_copy(a, 0, self.__buffer, 0, idx); //
        array_copy(a, idx, self.__buffer, idx + 1, self.__count - idx); //
        self.__buffer = a;

        return value;
    }

    static clear = function() {
        self.__count = 0;
    }

    static is_empty = function() {
        return self.__count == 0;
    }

    //
    //
    static size_to_fit = function() {
        //
        array_resize(self.__buffer, self.__count);
        self.__internal_size = self.__count;
    }

    //
    //
    //
    //
    static contains = function(test_value) {
        return array_contains(self.__buffer, test_value, 0, self.__count);
    }

    //
    static sort = function(sort_type=true) {
        //
        self.size_to_fit();
        array_sort(self.__buffer, sort_type);
        return self;
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
    static sort_with = function(func) {
        //
        self.size_to_fit();

        array_sort(self.__buffer, func);
        return self;
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
    static find = function(selector, param0, param1, param2) {
        for (var i = 0; i < self.count(); i++) {
            var cur = self.get(i);
            if selector(cur, param0, param1, param2) {
                return i;
            }
        }

        return undefined;
    }

    //
    //
    //
    //
    //
    //
    static find_lazy = function(value) {
        return array_index(self.__buffer, value, self.__count);
    }

    //
    //
    //
    //
    static has = function(value) {
        return self.find_lazy(value) != undefined; //
    }

    //
    static for_each = function(func, args) {
        args = args == undefined ? [] : args;
        for (var i = 0; i < self.__count; i++) {
            var these_args = array_concat([self.get(i)], args ?? []);
            function_execute_alt(func, these_args);
        }
        return self;
    }

    //
    //
    //
    //
    //
    //
    //
    //
    static any = function(selector, param0, param1, param2) {
        return self.find(selector, param0, param1, param2) != undefined;
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
    static every = function(func, param0, param1, param2) {
        for (var i = 0; i < self.__count; i++) {
            if !func(self.get(i), param0, param1, param2) {
                return false;
            }
        }
        return true;
    }

    //
    static contains_any_value_from = function(other_list) {
        for (var i = 0; i < other_list.count(); i++) {
            if self.contains(other_list.get(i)) {
                return true;
            }
        }
        return false;
    }

    //
    //
    static find_value = function(selector, param0, param1, param2) {
        var output = self.find(selector, param0, param1, param2);
        if (output != undefined) {
            return self.get(output);
        } else {
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
    static minimum_comparator = function(c) {
        if (self.__count == 0) {
            return undefined;
        }

        var current_leader = self.get(0);
        for (var i = 1; i < self.count(); i++) {
            var cur = self.get(i);
            if (c(cur, current_leader) == Ordering.LessThan) {
                current_leader = cur;
            }
        }

        return current_leader;
    }

    //
    static first = function() {
        if (self.count() == 0) {
            return undefined;
        } else {
            return self.get(0);
        }
    }

    //
    static last = function() {
        if (self.count() == 0) {
            return undefined;
        } else {
            return self.get(self.count() - 1);
        }
    }

    //
    static reverse = function() {
        var new_list = self.clone();
        var c = self.count();

        for (var i = 0; i < c; i++) {
            new_list.set(i, self.get(c - 1 - i));
        }

        return new_list;
    }

    //
    static set_reverse = function() {
        var new_list = self.clone();
        var c = self.count();

        for (var i = 0; i < c; i++) {
            self.set(i, new_list.get(c - 1 - i));
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
    static map = function(f_to_u) {
        array_map_mut(self.__buffer, f_to_u, self.__count);
        return self;
    }

    //
    //
    static map_to = function(f_to_u) {
        return ListFromArray(array_map(self.__buffer, f_to_u, 0, self.__count));
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
    static filter_map = function(f_to_u) {
        self.map(f_to_u);
        self.retain(function(e) {
            return e != undefined;
        });
        return self;
    }

    //
    //
    //
    //
    //
    static enumerate = function() {
        var iter = 0;
        var output = self.clone();
        output.fold(iter, function(iter, v, output) {
            output.set(iter, [iter, v]);
            return iter + 1;
        }, [output]);
        return output;
    }

    //
    //
    //
    //
    //
    //
    //
    static join = function(delimiter) {
        delimiter = delimiter == undefined ? "" : delimiter;
        return self
            .enumerate()
            .fold("", function(str, value, delimiter, count) {
                var iter = value[0];
                var element = value[1];
                return iter == count - 1
                    ? fmt("{}{}", str, element)
                    : fmt("{}{}{}", str, element, delimiter);
            }, [delimiter, self.count()])
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
    static fold = function(initializer, f, args) {
        var accum = initializer;
        for (var i = 0; i < self.__count; i++) {
            var these_args = array_concat([accum, self.get(i)], args ?? []);
            accum = function_execute_alt(f, these_args);
        }

        return accum;
    }

    //
    static shuffle = function() {
        for (var i = 0, c = self.count(); i < c; i++) {
            var j = irandom_range(i, c - 1);
            self.swap(i, j);
        }
    }

    //
    static sum = function() {
        return self.fold(0, function(a, e) {
            return a + e;
        });
    }

    //
    static sum_with = function(func, args) {
        return self.fold(0, function(a, element, func, args) {
            var these_args = array_concat([element], args ?? []);
            return a + function_execute_alt(func, these_args);
        }, [func, args]);
    }

    //
    static max = function() {
        return self.fold(0, function(a, e) {
            return e > a ? e : a;
        });
    }

    //
    static average = function() {
        return self.sum() / self.count();
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
    static choose_random = function(seed) {
        if seed != undefined {
            random_set_seed(seed);
        }

        if self.is_empty() {
            return undefined;
        }

        var output = self.get(irandom_range(0, self.__count - 1));

        //
        if seed != undefined {
            randomize();
        }

        return output;
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
    static remove_random = function(seed) {
        if seed != undefined {
            random_set_seed(seed);
        }

        if self.is_empty() {
            return undefined;
        }

        var index = irandom_range(0, self.__count - 1);
        var output = self.get(index);
        self.remove(index);

        //
        if seed != undefined {
            randomize();
        }

        return output;
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
    static to_array = function() {
        var a = [];
        array_copy(a, 0, self.__buffer, 0, self.__count);
        return a;
    }

    //
    //
    //
    //
    //
    static retain = function(f, a1, a2, a3) {
        var c = self.count();
        for (var i = 0; i < c; i++) {
            var e = self.get(i);
            if !function_execute_alt(f, [e, a1, a2, a3]) {
                self.remove(i);
                i -= 1;
                c -= 1;
            }
        }
        return self;
    }

    //
    //
    //
    //
    static drain = function(f, a1, a2, a3) {
        var o = List();
        var c = self.count();
        for (var i = 0; i < c; i++) {
            var e = self.get(i);
            if function_execute_alt(f, [e, a1, a2, a3]) {
                o.push(e);
                self.remove(i);
                i -= 1;
                c -= 1;
            }
        }
        return o;
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
    static satisfies = function(o) {
        for (var i = 0, c = o.count(); i < c; i++) {
            if !self.has(o.get(i)) {
                return false;
            }
        }
        return true;
    }

    //
    //
    static ensure_size = function(requested_size) {
        var gate = false;
        //
        while (self.__internal_size < requested_size) {
            self.__internal_size = self.__internal_size > 1 ? floor(self.__internal_size * (3 / 2)) : MINIMUM_DEFAULT_SIZE;
        }
        if (gate) {
            array_resize(self.__buffer, self.__internal_size);
        }
        return gate;
    }

    //
    //
    //
    //
    //
    //
    //
    //
    static swap = function(lhs, rhs) {
        var _idx_0 = self.get(lhs);
        self.set(lhs, self.get(rhs));
        self.set(rhs, _idx_0);
    }


    //
    static toString = function() {
        var output = "List[";
        for (var i = 0; i < self.count(); i++) {
            if self.get(i) == self {
                output += "[~RECURSION~]";
            } else {
                output += string(self.get(i));
            }
            if (i + 1 != self.count()) {
                output += ", ";
            }
        }

        output += "]";

        return output;
    }
}
