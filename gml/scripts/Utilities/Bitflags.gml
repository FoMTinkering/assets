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
function has_flag(val, flag) {
    gml_pragma("forceinline");

    return (val & flag) == flag;
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
function set_flag(val, flag) {
    gml_pragma("forceinline");

    return val | flag;
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
function remove_flag(val, flag) {
    gml_pragma("forceinline");

    return val & ~flag;
}

function intersects_flag(val, flag) {
    gml_pragma("forceinline");

    return (val & flag) != 0;
}
