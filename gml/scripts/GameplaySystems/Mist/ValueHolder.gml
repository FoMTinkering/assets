//
function ValueHolder() constructor {
    self.inner = undefined;

    //
    static set = function(value) {
        if self.inner != undefined {
            crash("Attempted to set a return inner twice!");
        } else {
            self.inner = value;
        }

    }

    //
    function get() {
        var v = self.inner;
        self.inner = undefined;
        return v;
    }
}
