function function_execute_alt(_func, _args) {
    static DEF_ARGS = [];
    return method_call(_func, _args ?? DEF_ARGS);
}
