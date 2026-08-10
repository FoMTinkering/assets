//
//
//
//
function Thread(_runtime, _idx, _stack, _environment, _is_call) {
    return {
        //
        idx: _idx,
        //
        stack: ListFromArray(_stack),
        //
        environment: _environment,
        //
        awaiter: undefined,
        //
        pending_threads: List(),
        //
        //
        is_call: _is_call,
    }
}
