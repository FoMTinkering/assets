//
function Awaiter(_runtime, _environment, _callable, _executer) constructor {
    self.runtime = _runtime;
    self.environment = _environment;
    self.executer = _executer;
    self.callable = _callable;
    self.is_resolved = false;

    function resolve(_value) {
        self.is_resolved = true;
    }

    static run = function() {
        if !self.is_resolved {
            self.executer(self.resolve, self.environment, self.callable);
        }
    }
}
