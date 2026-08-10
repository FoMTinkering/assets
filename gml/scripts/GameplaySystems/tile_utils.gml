//
function tilemap_get_tile_index(map, xx, yy) {
    return tilemap_get(map, xx, yy) & tile_index_mask;
}

//
function create_tilemap_on_new_layer(name, z, tileset, cell_size=16) {
    assert(tileset != -1)
    var lay = layer_create(z, name);
    var map = layer_tilemap_create(lay, 0, 0, tileset, room_width() div cell_size, room_height() div cell_size);
    return map;
}
