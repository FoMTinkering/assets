function __Iter() constructor {
    cursor = 0;

    has_next = undefined;
    __get_next = undefined;

    adapters = undefined;

    next = function() {
        var next = self.__get_next();
        if (adapters != undefined) {
            for (var i = 0; i < adapters.count(); i++) {
                var adapter = adapters.get(i);
                next = apply_adapter(adapter[0], adapter[1], next);
            }
        }

        return next;
    }

    static map = function(f) {
        if (adapters == undefined) {
            adapters = List([Adapter.Map, f]);
        } else {
            adapters.push([Adapter.Map, f]);
        }

        return self;
    }

    static collect_list = function() {
        var output = List();
        while (self.has_next()) {
            output.push(self.next());
        }

        return output;
    }
}

enum Adapter {
    Map,
}

function apply_adapter(kind, f, v) {
    if kind == Adapter.Map {
        return f(v);
    } else {
        impossible();
    }
}
