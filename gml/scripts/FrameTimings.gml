function create_frame_timings_data(sprite_idx) {
    var frame_info = sprite_get_info(sprite_idx).frame_info;

    var output = array_create(array_length(frame_info), 0);
    var running_total = 0;
    for (var i = 0; i < array_length(frame_info); i++) {
        running_total += frame_info[i].duration * 1.5;
        output[i] = running_total;
    }

    return output;
}

function game_frame_to_frame_timings_image_index(game_frame, frame_timings) {
    for (var i = 0; i < array_length(frame_timings); i++) {
        if game_frame < frame_timings[i] {
            return i;
        }
    }

    return undefined;
}
