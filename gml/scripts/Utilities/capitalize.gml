function capitalize(_string) {
    return string_upper(string_copy(_string, 1, 1)) + string_copy(_string, 2, string_length(_string) - 1);
}
