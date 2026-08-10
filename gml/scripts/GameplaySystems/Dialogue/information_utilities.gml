function find_info_tags(_text) {
    var _tags = [];
    assert_eq(string_count("[", _text), string_count("]", _text), "Text is malformed: {}", _text);
    while (string_pos("[", _text)) {
        var _start = string_pos("[", _text);
        var _end = string_pos("]", _text);
        var _tag = string_copy(_text, _start + 1, _end - _start - 1);
        _tags[array_length(_tags)] = _tag;
        _text = string_replace_all(_text, "[" + _tag + "]", "");
    }
    return _tags;
}
