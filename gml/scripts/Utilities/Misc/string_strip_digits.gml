function string_strip_digits(s) {
    s = string_replace_all(s, "0", "");
    s = string_replace_all(s, "1", "");
    s = string_replace_all(s, "2", "");
    s = string_replace_all(s, "3", "");
    s = string_replace_all(s, "4", "");
    s = string_replace_all(s, "5", "");
    s = string_replace_all(s, "6", "");
    s = string_replace_all(s, "7", "");
    s = string_replace_all(s, "8", "");
    s = string_replace_all(s, "9", "");
    return s;
}
