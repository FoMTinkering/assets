function SumArray(size=120, goal=60) constructor {
    self.internal_array = array_create(size, goal);
    self.point = 0;

    function add_value(value) {
        self.internal_array[point] = value;
        point = (point + 1) % array_length(self.internal_array);
    }

    function average() {
        var o = 0;
        for (var i = 0, c = array_length(self.internal_array); i < c; i++) {
            o += self.internal_array[i];
        }

        return o / c;
    }
}
