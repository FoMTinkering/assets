function trellis_point_by_location_position(location_position) {
    var o = trellis_point_find_by_position(
        location_id_to_gm_room(location_position.location_id),
        location_position.pos.x,
        location_position.pos.y,
        TrellisPointDataRequest.ROOM_ID
            | TrellisPointDataRequest.DIRECTION
            | TrellisPointDataRequest.OBJECT_INDEX
            | TrellisPointDataRequest.NAME
    );
    if o == undefined {
        return undefined;
    }

    return {
        location_position: new LocationPosition(location_position.location_id, Vec2(o.x, o.y)),
        object_index: o.object_index,
        direction: o.direction,
        name: o.name,
    }
}

function trellis_point_location_position(str) {
    var location_name = string_split(str, "/");
    var location_id = string_to_location_id(location_name[0]);
    var room_id = location_id_to_gm_room(location_id);
    var o = trellis_point_find_by_name(room_id, location_name[1], TrellisPointDataRequest.ROOM_ID);
    assert_defined(o, "failed to find trellis_point `{}`", str);
    return LocationPosition(gm_room_to_location_id(o.room), Vec2(o.x, o.y));
}

function trellis_point(str) {
    var location_name = string_split(str, "/");
    var location_id = string_to_location_id(location_name[0]);
    var room_id = location_id_to_gm_room(location_id);
    var o = trellis_point_find_by_name(room_id, location_name[1]);
    assert_defined(o, "failed to find trellis_point `{}`", str);
    return Vec2(o.x, o.y);
}
