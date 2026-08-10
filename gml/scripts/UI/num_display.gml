function num_display(num) {
    if local_get_info(LocalInfoRequest.CommasInNumbers) == false {
        return string(num);
    }

    var r, i;
    r = string(num);
    if string_pos(".", r) != 0 {
        var l = string_length(r);
        while string_char_at(r, l) == "0" {
            r = string_delete(r, string_length(r), 1);
            l = string_length(r);
        }
    } else {
        for (i = string_length(r) - 2; i > 1; i -= 3) {
            r = string_insert(",", r, i)
        }
    }
    return r
}
