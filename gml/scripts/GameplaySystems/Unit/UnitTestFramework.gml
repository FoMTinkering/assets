#macro UNIT_TEST_FRAMEWORK global.__unit_test_framework
UNIT_TEST_FRAMEWORK = undefined;

function UnitTestFramework() constructor {
    self.tests = List();

    function new_test(name, func) {
        self.tests.push({
            name: name,
            func: func,
        });
    }

    function run() {
        var summary = "Running all unit tests...\n";
        var errors = List();
        var failed_test_names = List();

        for (var i = 0; i < self.tests.count(); i++) {
            var test = self.tests.get(i);
            var err = undefined;
            var timer = get_timer();
            trace("Running '{}'...", test.name);
            try {
                test.func();
            } catch (e) {
                err = e;
            }
            if err == undefined {
                summary += fmt("\n{}... ok ({ms})", test.name, get_timer() - timer);
            } else {
                failed_test_names.push(test.name);
                summary += fmt("\n{}... FAIL", test.name);
                errors.push({
                    name: test.name,
                    err: err,
                });
            }
        }

        var error_count = errors.count();
        summary += fmt(
            "\n\nTest results: {}. ({} passed, {} failed)",
            errors.is_empty() ? "ok" : "FAIL",
            self.tests.count() - error_count,
            error_count,
        );

        if error_count != 0 {
            summary += "\n\nFailures:\n"
            for (var i = 0; i < error_count; i++) {
                var err = errors.get(i);
                summary += fmt("\n---- output for {} ----\n", err.name);
                summary += format("{}", err.err);
            }
        }

        show_debug_message(summary);
        return {
            succeeded: error_count == 0,
            error_count: error_count,
            summary: summary,
            failed_test_names: failed_test_names,
        };
    }
}

function run_unit_tests() {
    UNIT_TEST_FRAMEWORK = new UnitTestFramework();
    define_unit_tests(UNIT_TEST_FRAMEWORK);
    var result = UNIT_TEST_FRAMEWORK.run();
    UNIT_TEST_FRAMEWORK = undefined;
    return result;
}

function gm_error_to_string(err) {
    summary = fmt("{}\n", err.longMessage);
    for (var i = 0; i < array_length(err.stacktrace); i++) {
        summary += err.stacktrace[i] + "\n"
    }
    return summary;
}
