//
function create_stump_prototype(object_id, fiddle_obj) {
    var o = {
        object_id,
        sprites: array_map(ensure_array(fiddle_obj.sprites), string_to_asset),
        winter_sprites: undefined,
        max_hitpoints: fiddle_obj.hp,
        size: fiddle_deserialize_vec2(fiddle_obj.size),
        minimum_quality: string_to_quality_id(fiddle_obj.minimum_quality),
        offset: fiddle_deserialize_vec2(fiddle_obj.offset),
        drop_bundle: create_fiddle_drops(fiddle_obj.drops),
        initial_burn_iframes: fiddle_obj.initial_burn_iframes,
    };

    if fiddle_obj[$ "winter_sprites"] == undefined {
        o.winter_sprites = array_clone(o.sprites);
    } else {
        o.winter_sprites = array_map(ensure_array(fiddle_obj.winter_sprites), string_to_asset);
    }

    return o;
}

//
function write_stump_to_location(grid, xx, yy, proto) {
    var node = attempt_to_write_object_node(grid, xx, yy, proto.size, proto, true);
    if (node == undefined) {
        return undefined;
    }

    //
    node.hitpoints = node.prototype.max_hitpoints;
    node.variant_idx = irandom_range(0, 99) / 100.0;

    return node;
}

function create_stump_renderer(node) {
    //
    var spr_array = (CALENDAR.season() == Season.Winter) ? node.prototype.winter_sprites : node.prototype.sprites;
    var spr = spr_array[floor(array_length(spr_array) * node.variant_idx)];

    node.renderer = create_node_renderer(
        (node.top_left_x * 8) + node.prototype.offset.x,
        (node.top_left_y * 8) + node.prototype.offset.y,
        node,
        spr,
    );
}
