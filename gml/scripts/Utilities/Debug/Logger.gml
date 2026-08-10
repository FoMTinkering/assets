#macro FORMAT_PREFIX global.__format_prefix
FORMAT_PREFIX = function() {
    return "[INIT]";
}

enum LogLevel {
    Trace,
    Info,
    Warn,
    Error,
    None,
}

function dbg(val) {
    var msg = val == undefined ? val : [val];
    __log(LogLevel.Info, msg);
    return val;
}

function error(_msg) {
    if (_msg != undefined) {
        var _arg_a = array_create(argument_count);
        for (var i = 0; i < argument_count; i++) {
            _arg_a[i] = argument[i];
        }
        _msg = _arg_a;
    }
    __log(LogLevel.Error, _msg);
}

function warn(_msg) {
    if (_msg != undefined) {
        var _arg_a = array_create(argument_count);
        for (var i = 0; i < argument_count; i++) {
            _arg_a[i] = argument[i];
        }
        _msg = _arg_a;
    }
    __log(LogLevel.Warn, _msg);
}

function info(_msg) {
    if (_msg != undefined) {
        var _arg_a = array_create(argument_count);
        for (var i = 0; i < argument_count; i++) {
            _arg_a[i] = argument[i];
        }
        _msg = _arg_a;
    }
    __log(LogLevel.Info, _msg);
}

function trace(_msg) {
    if (_msg != undefined) {
        var _arg_a = array_create(argument_count);
        for (var i = 0; i < argument_count; i++) {
            _arg_a[i] = argument[i];
        }
        _msg = _arg_a;
    }
    __log(LogLevel.Trace, _msg);
}

function __log(kind, message) {
    var cs = debug_get_callstack()[2 + !GM_RUNTIME];
    if DEBUG_TOOLS {
        cs = text_trim_callstack(cs);
    }

    var text_from_buffer = format(
        "{} {} {} -- {}",
        FORMAT_PREFIX(TICK),
        log_level_to_display_text(kind),
        cs,
        message == undefined ? "undefined" : script_execute_alt(format, message),
    );
    if GM_RUNTIME {
        show_debug_message(text_from_buffer);
    } else {
        show_debug_message(format(
            "{} {} {} -- {}",
            text_color_logging(kind),
            text_color_dim(FORMAT_PREFIX(TICK)),
            cs,
            message == undefined ? "undefined" : script_execute_alt(fmt, message),
        ));
    }

    tattletale_breadcrumb(kind, text_from_buffer);

    if DEBUG_TOOLS && BUGGER != undefined && steam_on_deck() {
        BUGGER.cli.post(text_from_buffer);
    }
}

function log_level_to_display_text(kind) {
    switch kind {
        case LogLevel.Trace: return "TRACE";
        case LogLevel.Info: return "INFO";
        case LogLevel.Warn: return "WARN";
        default: return "ERROR";
    }
}
