//

//
//
//
//
//
function Callable(_runtime) constructor {
    self.runtime = _runtime;
    self.parent_callable = undefined;
    self.resolve_call = undefined;
    self.call = undefined;
    self.invoke_resolve_call = undefined;
    self.invoke_call = undefined;
    self.has_resolve = false;

    //
    static set_call = function(_call) {
        self.call = _call;
        return self;
    }

    //
    //
    static set_resolve_check = function(_resolve) {
        self.resolve_call = _resolve;
        return self;
    }

    //
    //
    static is_resolved = function(_environment) {
        return self.invoke_resolve_call(_environment);
    }
}

//
function UserCallable(_runtime, _params, _main_body, _resolve_body) : Callable(_runtime) constructor {
    self.params = ListFromArray(_params);
    self.main_body = _main_body.stmts;
    self.resolve_body = undefined;
    self.has_resolve = false;
    if _resolve_body != undefined {
        self.resolve_body = _resolve_body.stmts;
        self.has_resolve = true;
    }

    //
    function invoke_call(_environment, _args) {

        //
        var defaults = [];
        for (var i = 0; i < self.params.count(); i++) {
            var param = self.params.get(i);
            defaults[i] = param.default_value == undefined
                ? undefined
                : self.runtime.evaluate_expr(
                    param.default_value
                );
        }
        for (var i = 0, c = self.params.count(); i < c; i++;) {
            _environment.define(
                self.params.get(i).value,
                array_length(_args) <= i ? defaults[i] : _args[i]
            );
        }

        //
        return self.runtime.create_thread(self.main_body, _environment, true);
    }

    //
    function invoke_resolve_call(_environment) {
        if self.resolve_body == undefined {
            return true;
        }
        self.runtime.create_thread(self.resolve_body, _environment, true);
        var value = self.runtime.return_value.get();
        if value != true && value != false {
            crash("Non-boolean result returned from resolve call: {}", value);
            return;
        }
        return value;
    }
}

//
function NativeCallable(_runtime) : Callable(_runtime) constructor {
    self.has_resolve = false //

    function invoke_call(_environment, _args) {
        self.runtime.return_value.set(function_execute_alt(self.call, _args));
    }

    function invoke_resolve_call(_environment) {
        return self.resolve_call();
    }
}
