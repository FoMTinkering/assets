//
function fish_bounce_test() {
    assert(is_between(get_bounce_dir(1, 1, 45, true), 0, 45), "Val should have been between 0 and 45, got: {}", get_bounce_dir(1, 1, 45, true));
    assert(is_between(get_bounce_dir(-1, -1, 45, true), 180, 225), "Val should have been between 180 and 225, got: {}", get_bounce_dir(-1, -1, 45, true));
    assert(is_between(get_bounce_dir(-1, 1, 45, true), 135, 180), "Val should have been between 135 and 180, got: {}", get_bounce_dir(-1, 1, 45, true));
    assert(is_between(get_bounce_dir(1, -1, 45, true), 0, 315), "Val should have been between 0 and 315, got: {}", get_bounce_dir(1, -1, 45, true));

    assert(is_between(get_bounce_dir(1, 1, 45, false), 225, 270), "Val should have been between 225 and 270, got: {}", get_bounce_dir(1, 1, 45, false));
    assert(is_between(get_bounce_dir(-1, -1, 45, false), 45, 90), "Val should have been between 45 and 90, got: {}", get_bounce_dir(-1, -1, 45, false));
    assert(is_between(get_bounce_dir(-1, 1, 45, false), 270, 315), "Val should have been between 270 and 315, got: {}", get_bounce_dir(-1, 1, 45, false));
    assert(is_between(get_bounce_dir(1, -1, 45, false), 90, 135), "Val should have been between 90 and 135, got: {}", get_bounce_dir(1, -1, 45, false));
}
