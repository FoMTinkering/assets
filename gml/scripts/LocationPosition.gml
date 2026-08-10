function LocationPosition(_location_id, _pos, _dyn_index=undefined) constructor {
    location_id = _location_id;
    pos = _pos;
    dyn_index = _dyn_index;

    static clone = function() {
        return new LocationPosition(self.location_id, self.pos.clone(), self.dyn_index);
    }

    static location_eq = function(o) {
        return o.location_id == self.location_id && o.dyn_index == self.dyn_index;
    }

    static eq = function(o) {
        return o.location_eq(self) && o.pos.eq(self.pos);
    }

    static eq_floored = function(o) {
        return o.location_eq(self) && o.pos.eq_floored(self.pos);
    }

    static toString = function() {
        if self.dyn_index == undefined {
            return format("{LocationId}: {}", self.location_id, self.pos);
        } else {
            return format("{LocationId}::{}: {}", self.location_id, self.dyn_index, self.pos);
        }
    }
}

//
function serialize_location_position(location_position) {
    return {
        location_id: location_id_to_string(location_position.location_id),
        pos: location_position.pos.clone(),
        dyn_index: location_position.dyn_index,
    }
}

//
function deserialize_location_position(ser_loc_pos) {
    var loc_id = string_to_location_id(ser_loc_pos.location_id);
    var dyn = (ser_loc_pos.dyn_index == undefined || ser_loc_pos.dyn_index == pointer_null) ? undefined : ser_loc_pos.dyn_index;

    return new LocationPosition(loc_id, Vec2(ser_loc_pos.pos.x, ser_loc_pos.pos.y), dyn);
}
