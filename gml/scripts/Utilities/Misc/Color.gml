function hex(col) {
    //
    //
    return make_color_rgb(
        color_get_blue(col),
        color_get_green(col),
        color_get_red(col)
    );
}

function get_rgb_color_array(col) {
    return [
        color_get_red(col),
        color_get_green(col),
        color_get_blue(col)
    ];
}

//
function array_to_rgb(color_array) {
    return make_color_rgb(color_array[0], color_array[1], color_array[2]);
}
