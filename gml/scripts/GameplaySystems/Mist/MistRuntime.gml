#macro MIST_LOG if false mist_log

global.mist_log_cache = 0;
global.mist_log_indent = 0;

function mist_log(_msg) {
    if (_msg != undefined) {
        var _arg_a = array_create(argument_count);
        for (var i = 0; i < argument_count; i++) {
            _arg_a[i] = argument[i];
        }
        _msg = _arg_a;
    }

    var tt = get_timer();
    var dur = tt - global.mist_log_cache;
    global.mist_log_cache = tt;
    var s = "";
    repeat global.mist_log_indent - 1 {
        s += "  ";
    }
    var hex = int_to_hex_string(TICK % 256, 2);
    s += fmt("[MIST:{} | {ms}] ", hex, dur) + script_execute_alt(fmt, _msg);
    show_debug_message(s);
}

function MistRuntime() constructor {
    self.threads = ds_map_create(); //
    self.thread_iter = 0;
    self.thread_stack = List();
    self.call_stack = List();
    self.free_threads = List();
    self.native_environment = new Environment(self, undefined);
    self.global_environment = new Environment(self, self.native_environment);
    self.active_environment = self.global_environment;
    self.global_environment.define("_SIMULATE_", false);
    self.return_value = new ValueHolder();
    self.running = false;
    self.checkpoint_target = undefined;
    self.simulated_prompt_index = 0;
    self.muted = false;
    self.blackboard = Map();
    self.base_thread = undefined;


    //
    function stack_to_string(_stack) {
        var s = "{ "
        for (var i = 0; i < array_length(_stack); i++) {
            s += self.stmt_to_string(_stack[i]) + ", ";
        }
        return s + "}";
    }

    //
    function stmt_to_string(_stmt) {
        switch _stmt.stmt_type {
            case "Expr":
                return self.expr_to_string(_stmt.expr);
            case "Var":
                var s = "var " + _stmt.name.value;
                if _stmt.initializer != null {
                    s += " = " + self.expr_to_string(_stmt.initializer);
                }
                return s;
            case "Block":
                var s = "{ "
                for (var i = 0; i < array_length(_stmt.stmts); i++) {
                    s += self.stmt_to_string(_stmt.stmts[i]) + ", ";
                }
                return s + "}";
            case "If":
                var s = "if " + self.expr_to_string(_stmt.condition);
                s += self.stmt_to_string(_stmt.then_branch);
                if _stmt.else_branch != undefined s += "else " + self.stmt_to_string(_stmt.else_branch);
                return s;
            case "While":
                var s = "while " + self.expr_to_string(_stmt.condition) + self.stmt_to_string(_stmt.body);
                return s;
            case "Function":
                var s = "fun " + _stmt.name.value + " ";
                for (var i = 0; i < array_length(_stmt.params); i++) {
                    s += _stmt.params[i].value;
                    if _stmt.params[i].default_value != undefined {
                        var val = undefined;
                        if _stmt.params[i].default_value.expr_type == "Unary" {
                            s += "-";
                            val = _stmt.params[i].default_value.right.value;
                        } else {
                            val = _stmt.params[i].default_value.value;
                        }
                        switch val.token_type {
                            case "False":
                                s += "false";
                                break;
                            case "True":
                                s += "true";
                                break;
                            case "String":
                                s += val.value;
                                break;
                            default:
                                s += "unimpl_def_type: " + _stmt.params[i].default_value.expr_type;
                                break;
                        }
                    }
                    s += " ";
                }
                return s + "{ ... }";
            case "Return":
                if _stmt.value == undefined return "return";
                return "return " + self.expr_to_string(_stmt.value);
            case "Simultaneous":
                var s = "sim { "
                for (var i = 0; i < array_length(_stmt.body.stmts); i++) {
                    s += self.stmt_to_string(_stmt.body.stmts[i]) + ", ";
                }
                return s + "}";
            case "Free":
                var s = "free { "
                s += self.stmt_to_string(_stmt.stmt) + ", ";
                return s + "}";
        }
    }

    //
    function expr_to_string(_expr) {
        var left;
        var right;
        var op;
        switch _expr.expr_type {
            case "Binary":
                left = self.expr_to_string(_expr.left);
                right = self.expr_to_string(_expr.right);
                switch _expr.operator.token_type {
                    case "Plus": op = "+"; break;
                    case "Minus": op = "-"; break;
                    case "Star": op = "*"; break;
                    case "Slash": op = "/"; break;
                    case "Mod": op = "%"; break;
                    case "Greater": op = ">"; break;
                    case "GreaterEqual": op = ">="; break;
                    case "Less": op = "<"; break;
                    case "LessEqual": op = "<="; break;
                    case "DoubleEqual": op = "=="; break;
                    case "BangEqual": op = "!="; break;
                }
                return fmt("{} {} {}", left, op, right);
            case "Unary":
                right = self.expr_to_string(_expr.right);
                switch _expr.operator.token_type {
                    case "Minus": op = "-";
                    case "Bang": op = "!";
                }
                return fmt("{}{}", op, right);
            case "Literal":
                switch _expr.value.token_type {
                    case "True":
                        return "true";
                    case "False":
                        return "false";
                    case "Number":
                        return string(_expr.value.Value);
                    case "String":
                        return "\"" + string(_expr.value.value) + "\"";
                }

            case "Grouping":
                return "(" + self.expr_to_string(_expr.expr) + ")";
            case "Named":
                return _expr.name.value;
            case "Assign":
                var value = self.expr_to_string(_expr.value);
                return fmt("{} = {}", _expr.name.name.value, value);
            case "Logical":
                left = self.expr_to_string(_expr.left);
                right = self.expr_to_string(_expr.right);
                if _expr.operator.token_type == "Or" {
                    op = "||";
                } else {
                    op = "&&";
                }
                return fmt("{} {} {}", left, op, right);
            case "Call":
                var s = "";
                s += self.expr_to_string(_expr.call) + ": ";
                for (var i = 0, c = array_length(_expr.args); i < c; i++;) {
                    s += self.expr_to_string(_expr.args[i]) + " ";
                }
                return s;
        }
    }



    //
    function set_environment(_environment) {
        self.active_environment = _environment;
    }

    //
    function get_environment() {
        return self.active_environment;
    }



    //
    //
    //
    //
    //
    //
    //
    //
    function create_thread(_stack, _environment, _is_call, _free) {
        if _is_call == undefined {
            _is_call = false;
        }
        if _free == undefined {
            _free = false;
        }
        var idx = self.thread_iter++;
        MIST_LOG("CREATE {}: {}", idx, self.stack_to_string(_stack));
        var thread = Thread(
            self,
            idx,
            _stack,
            _environment,
            _is_call
        );

        //
        self.threads[? idx] = thread;

        //
        self.run_thread(idx);

        //
        //
        //
        if _free {
            self.free_threads.push(idx);
        } else if !self.check_thread_complete(idx) && self.thread_stack.count() > 0 {
            //
            self.assign_pending_thread_to_top_thread(idx);
        }
        return idx;
    }

    //
    function get_top_thread() {
        return self.thread_stack.get(self.thread_stack.count() - 1);
    }

    //
    //
    function assign_pending_thread_to_top_thread(_assignee_idx) {
        var idx = self.get_top_thread();
        MIST_LOG("PUSH {} TO {}", _assignee_idx, idx);
        self.threads[? idx].pending_threads.push(_assignee_idx);
    }

    //
    //
    function assign_awaiter_to_last_thread(_awaiter) {
        var idx = self.get_top_thread();
        MIST_LOG("AWAIT {}", idx);
        self.threads[? idx].awaiter = _awaiter;
    }

    //
    //
    //
    function check_thread_is_call(_idx) {
        var thread = self.threads[? _idx];
        return thread.is_call;
    }

    //
    function check_thread_complete(_idx) {
        if self.threads[? _idx] == undefined {
            return true;
        }
        var thread = self.threads[? _idx];
        return thread.stack.count() == 0
            && !self.check_thread_blocked(_idx);
    }

    //
    function check_thread_empty(_idx) {
        var thread = self.threads[? _idx];
        return thread.stack.count() == 0;
    }

    //
    //
    function check_thread_blocked(_idx) {
        var thread = self.threads[? _idx];
        return thread.awaiter != undefined || thread.pending_threads.count() != 0;
    }

    //
    function close_thread(_idx) {
        ds_map_remove(self.threads, _idx);
    }

    //
    function run_thread(_idx) {
        global.mist_log_indent += 1;
        self.thread_stack.push(_idx);
        MIST_LOG("RUN {}", _idx);
        self.run_thread_internal(_idx);
        MIST_LOG("END {} RUN.", _idx);
        self.thread_stack.pop();
        global.mist_log_indent -= 1;
    }

    //
    function run_thread_internal(_idx) {
        var thread = self.threads[? _idx];
        while true {

            //
            if thread.awaiter != undefined {
                MIST_LOG("CHECK {} AWAITER...", _idx);
                thread.awaiter.run();
                MIST_LOG("DONE WITH {} AWAITER.", _idx);
                if thread.awaiter.is_resolved {
                    MIST_LOG("{} IS RESOLVED.", _idx);
                    thread.awaiter = undefined;
                } else {
                    MIST_LOG("{} IS NOT RESOLVED.", _idx);
                }
            }


            //
            for (var i = 0, c = thread.pending_threads.count(); i < c; i++;) {
                var pending_idx = thread.pending_threads.get(i);
                MIST_LOG("{} RUN PENDING THREAD {}", _idx, pending_idx);
                self.run_thread(pending_idx);
                if self.check_thread_complete(pending_idx) {
                    MIST_LOG("{}'s PENDING THREAD {} IS COMPLETE.", _idx, pending_idx);
                    MIST_LOG("{} UNTRACK {}", _idx, pending_idx);
                    thread.pending_threads.remove(i);
                    --i;
                    --c;
                } else {
                    MIST_LOG("{}'s PENDING THREAD {} IS NOT COMPLETE.", _idx, pending_idx);
                }
            }

            //
            if self.check_thread_complete(_idx)  {
                self.close_thread(_idx);
                MIST_LOG("{} IS COMPLETE.", _idx);
                MIST_LOG("CLOSE {} (pre-run)", _idx);
                return;
            }

            //
            if !self.check_thread_blocked(_idx)  {
                //
                self.set_environment(thread.environment);
                MIST_LOG("EXECUTE {}: {}", _idx, self.stmt_to_string(thread.stack.get(0)));
                var eject = self.execute_stmt(thread.stack.get(0));
                self.set_environment(self.global_environment);

                //
                if self.check_thread_complete(_idx) {
                    MIST_LOG("{} COMPLETE VIA USER RETURN.", _idx);
                    return;
                }

                //
                if eject {
                    MIST_LOG("STMT IS COMPLETED.");

                    //
                    thread.stack.remove(0);

                    //
                    if self.check_thread_blocked(_idx) {
                        MIST_LOG("BLOCKED {}", _idx);
                        break;
                    }

                    //
                    if !self.check_thread_empty(_idx) {
                        MIST_LOG("CONTINUE {}", _idx);
                        continue;
                    }

                    //
                    self.close_thread(_idx);
                    MIST_LOG("CLOSE {} (post-run)", _idx);
                    return;
                } else {
                    MIST_LOG("STMT IS NOT COMPLETED.");
                }
            } else {
                //
                MIST_LOG("{} CANNOT RUN (BLOCKED)", _idx);
                break;
            }
        }
    }



    //
    //
    //
    function execute_stmt(_stmt) {
        switch _stmt.stmt_type {
            case "Expr":
                self.evaluate_expr(_stmt.expr);
                return true;
            case "Var":
                var value = undefined;
                if _stmt.initializer != undefined {
                    value = self.evaluate_expr(_stmt.initializer);
                }
                self.active_environment.define(_stmt.name.value, value);
                return true;
            case "Block":
                self.create_thread(
                    _stmt.stmts,
                    new Environment(self, self.active_environment)
                );
                return true;
            case "If":
                if self.is_truthy(self.evaluate_expr(_stmt.condition)) {
                    self.execute_stmt(_stmt.then_branch);
                } else if _stmt.else_branch != undefined {
                    self.execute_stmt(_stmt.else_branch);
                }
                return true;
            case "While":
                if self.is_truthy(self.evaluate_expr(_stmt.condition)) {
                    self.execute_stmt(_stmt.body);
                    return false;
                }
                return true;
            case "Function":
                if self.active_environment.has(_stmt.name.value) {
                    crash(
                        "Attempted to delcare function twice: {}",
                        _stmt.name.value
                    );
                    return;
                }
                var callable = new UserCallable(
                    self,
                    _stmt.params,
                    _stmt.body,
                    _stmt.resolve
                )
                self.active_environment.define(
                    _stmt.name.value,
                    callable
                );
                return true;
            case "Return":
                var i = self.thread_stack.count() - 1;
                while i != 0 {
                    var idx = self.thread_stack.get(i);
                    //
                    if self.check_thread_is_call(idx) {
                        self.close_thread(idx);
                        break;
                    }
                    self.close_thread(idx);
                    --i;
                }

                //
                if _stmt.value != undefined {
                    self.return_value.set(
                        self.evaluate_expr(_stmt.value)
                    );
                }
                return true;
            case "Simultaneous":
                //
                for (var i = 0, c = array_length(_stmt.body.stmts); i < c; i++;) {
                    self.execute_stmt(_stmt.body.stmts[i]);
                }
                return true;
            case "Free":
                //
                self.create_thread(
                    [_stmt.stmt],
                    new Environment(self, self.active_environment),
                    false,
                    true,
                );
                return true;
            default:
                crash("Reached an unexpected stmt type: {}", _stmt.stmt_type);
                return true;
        }
    }

    //
    function evaluate_expr(_expr) {
        var left;
        var right;
        switch _expr.expr_type {
            case "Binary":
                left = self.evaluate_expr(_expr.left);
                right = self.evaluate_expr(_expr.right);
                switch _expr.operator.token_type {
                    case "Plus": return left + right;
                    case "Minus": return left - right;
                    case "Star": return left * right;
                    case "Slash": return left / right;
                    case "Mod": return left mod right;
                    case "Greater": return left > right;
                    case "GreaterEqual": return left >= right;
                    case "Less": return left < right;
                    case "LessEqual": return left <= right;
                    case "DoubleEqual": return left == right;
                    case "BangEqual": return left != right;
                    default: impossible("Invalid binary operator type: {}", _expr.operator.token_type);
                }
            case "Unary":
                right = self.evaluate_expr(_expr.right);
                switch _expr.operator.token_type {
                    case "Minus": return -right;
                    case "Bang": return !self.is_truthy(right);
                    default: impossible("Invalid unary operator type: {}", _expr.operator.token_type);
                }
            case "Literal":
                switch _expr.value.token_type {
                    case "True": return true;
                    case "False": return false;
                    case "Number": return _expr.value.Value;
                    case "String": return _expr.value.value;
                    default: impossible("Invalid literal type: {}", _expr.value.token_type);
                }

            case "Grouping":
                return self.evaluate_expr(_expr.expr);
            case "Named":
                if !self.active_environment.has(_expr.name.value) {
                    return _expr.name.value;
                } else {
                    return self.active_environment.get(_expr.name.value);
                }
            case "Assign":
                var value = self.evaluate_expr(_expr.value);
                self.active_environment.assign(
                    _expr.name.name.value,
                    value
                );
                return value;
            case "Logical":
                left = self.evaluate_expr(_expr.left);
                switch _expr.operator.token_type {
                    case "And": return self.is_truthy(left) && self.is_truthy(self.evaluate_expr(_expr.right));
                    case "Or": return self.is_truthy(left) || self.is_truthy(self.evaluate_expr(_expr.right));
                    default: impossible("Unexpected logical operator: {}", _expr.operator.token_type);
                }
            case "Call":
                MIST_LOG("EVALUATING CALL TARGET...");
                var this_callable = self.evaluate_expr(_expr.call);
                if is_string(this_callable) {
                    crash("Could not find a function with the name '{}'!", this_callable);
                    return;
                }
                var environment = new Environment(self, self.active_environment);
                var args = [];
                MIST_LOG("EVALUATING ARGUMENTS...");
                for (var i = 0, c = array_length(_expr.args); i < c; i++;) {
                    args[i] = self.evaluate_expr(_expr.args[i]);
                }
                MIST_LOG("INVOKE CALL...");
                this_callable.invoke_call(environment, args);
                MIST_LOG("FINISHED CALL.")
                if this_callable.has_resolve {
                    MIST_LOG("ASSIGNING AN AWAITER");
                    self.assign_awaiter_to_last_thread(
                        new Awaiter(
                            self,
                            environment,
                            this_callable,
                            function(_resolve, _environment, _callable) {
                                if _callable.invoke_resolve_call(_environment) {
                                    MIST_LOG("RESOLVE");
                                    _resolve();
                                }
                            }));
                }
                return self.return_value.get();
            default:
                crash("Invalid expr type: {}", _expr.expr_type);
                return;
        }
    }

    //
    function assert_is_number() {
        for (var i = 0; i < argument_count; i++) {
            if !is_real(argument[i]) && !is_int64(argument[i]) {
                crash("Operand must be a number, but recieved '{}'", argument[i]);
                return false;
            }
        }
        return true;
    }

    //
    function is_truthy(_value) {
        if _value == undefined return false;
        if is_real(_value) && _value <= 0 || _value == false return false; //
        return true;
    }

    //
    function begin_simulation(checkpoint, prompt_index=0) {
        self.checkpoint_target = checkpoint;
        self.simulated_prompt_index = prompt_index;
        global_environment.assign("_SIMULATE_", true);
    }

    //
    function end_simulation() {
        self.checkpoint_target = undefined;
        global_environment.assign("_SIMULATE_", false);
    }

    //
    function is_simulating() {
        return self.checkpoint_target != undefined;
    }

    //
    function end_scene() {
        self.running = false;
        if self.global_environment.has("on_scene_end") {
            var func = self.global_environment.get("on_scene_end");
            var environment = new Environment(self, self.active_environment);
            var args = [];
            func.invoke_call(environment, args);
        }
        self.threads = undefined;
        self.free_threads.clear();
    }

    //
    function run_std_func(name, args) {
        var func = self.native_environment.get(name);
        var environment = new Environment(self, self.active_environment);
        func.invoke_call(environment, args);
    }

    function __run_free(_stmts) {
        self.base_thread = self.create_thread(_stmts, self.global_environment);
    }

    //
    function __run_await(_stmts) {
        self.base_thread = self.create_thread(_stmts, self.global_environment);
        var keys = ds_map_keys_to_array(self.threads);
        for (var i = 0, c = array_length(keys); i < c; i++) { //
            self.run_thread(keys[i]);
        }
    }

    //
    function start(_std_stmts) {
        define_std(self);
        self.__run_await(_std_stmts);
    }

    //
    function run(_stmts) {
        self.__run_free(_stmts);
        //
        if self.threads[? self.base_thread] != undefined {
            self.running = true;
        }
    }

    //
    function on_step() {
        if self.running && !non_cutscene_pause() {
            self.run_thread(self.base_thread);
            if self.threads[? self.base_thread] == undefined {
                self.end_scene();
            }
            for (var i = 0; i < self.free_threads.count(); i++) {
                var thread = self.free_threads.get(i);
                if self.check_thread_complete(thread) {
                    self.free_threads.remove(i);
                    i -= 1;
                    continue;
                }
                self.run_thread(thread);
                if self.check_thread_complete(thread) {
                    self.free_threads.remove(i);
                    i -= 1;
                }
            }
        }
    }

}

//
function mist_unit_test() {
    var runtime = new MistRuntime();
    runtime.start(MIST_STD);
    runtime.__run_await(CUTSCENES.get("unit_test").mist);
}
