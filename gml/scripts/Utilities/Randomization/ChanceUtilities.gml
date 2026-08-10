function chance_percent(_percent) {
    return random(1) <= _percent / 100 && _percent != 0;
}

function chance_array(argument_array) {
    //

    var _choice;
    var v = random_range(1,100);
    var _array = argument_array;
    var _len = array_length(_array);
    var r, i = 0, total = 0; repeat(_len/2){
        r = _array[i+1] + total;
        if(v <= r){
            _choice = _array[i];
            break;
        }
        total += _array[i+1];
        i+=2;
    }

    return _choice;
}
