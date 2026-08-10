//
function read_text_file(filename) {
    assert(file_exists(filename), "File does not exist! {}", filename);
    var buff = buffer_load(filename);
    var o_buff = undefined;
    var str = buffer_read(buff, buffer_string);
    buffer_delete(buff);
    if o_buff != undefined {
        buffer_delete(o_buff);
    }
    return str;
}

//
function save_text_file(filename, str, compress = false) {
    var size = string_byte_length(str);
    var buff = buffer_create(size, buffer_fixed, 1);
    var o_buff = undefined;
    buffer_write(buff, buffer_text, str);
    if compress {
        o_buff = buff;
        buff = buffer_compress(o_buff, 0, buffer_get_size(o_buff));
    }
    buffer_save(buff, filename);
    buffer_delete(buff);
    if o_buff != undefined {
        buffer_delete(o_buff);
    }
}

//
function try_read_json_file(filename, struct, decompress) {
    try {
        return read_json_file(filename, struct, decompress);
    } catch (e) {
        return undefined;
    }
}

//
//
//
function read_json_file(filename, struct) {
    var str = read_text_file(filename);
    var data = json_parse(str);
    if struct != undefined {
        var keys = struct_get_names(data);
        for (var i = 0; i < array_length(keys); i++) {
            var key = keys[i];
            assert(!struct_exists(struct, key), "Key already exists in struct: {}", key);
            struct[$ key] = data[$ key];
        }
    }
    return data;
}

//
function save_json_file(filename, struct, compress = false) {
    var json;
    try {
        json = json_stringify_pretty(struct);
    } catch(e) {
        error("Failed to stringify @ {}", filename);
        error("struct was {}", struct);
        crash("failed to stringify because {}", e);
    }
    save_text_file(filename, json, compress);
}
