function format_arg_provider(function_name, value) {
    switch function_name {
        case "bool":
        case "Bool":
            value = value ? "true" : "false";
            break;
        case "int":
        case "Int":
        case "int64":
        case "Int64":
            value = int64(value);
            break;
        case "float":
        case "f32":
        case "f64":
        case "double":
            value = string_format(value, 0, 10);
            break;
        case "f32_2":
            value = string_format(value, 0, 2);
            break;
        case "hex":
        case "Hex":
        case "hexadecimal":
            value = int_to_hex_string(value);
            break;
        case "string":
        case "str":
        case "String":
            value = "\"" + value + "\"";
            break;
        case "GmRoom":
        case "gmroom":
        case "gm_room":
            value = asset_to_string(value);
            break;
        case "micro":
            value = string(value / 1000000) + "s";
            break;
        case "ms":
        case "milliseconds":
            value = string(value / 1000) + "ms";
            break;
        case "s":
        case "seconds":
            value = string((value / 1000) / 1000) + "s";
            break;
        case "AnchorNode":
        case "anchor_node":
            value = value.display();
            break;
        case "GmSprite":
        case "gm_sprite":
        case "gmsprite":
            try {
                value = asset_to_string(value);
            } catch(_e) {
                value = "undefined";
            }
            break;
        case "GmObject":
        case "gm_object":
        case "gmobject":
            value = object_get_name(value);
            break;
        case "color":
        case "Color":
            var new_str = "";
            for (var channel = 0; channel < array_length(value); channel++) {
                new_str += string(value[channel] * 255);
                if channel != (array_length(value) - 1) {
                    new_str += ", ";
                }
            }
            value = new_str;
            break;
        case "json":
        case "JSON":
            value = json_stringify(value);
            break;
        case "SemVer":
        case "Semver":
            value = version_to_string(value);
            break;
        case "time":
        case "Time":
            value = clock_time_to_string(value);
            break;
        case "date":
        case "Date":
            value = localize_date(value);
            break;
        case "Local":
        case "local":
            value = local_get(value);
            break;
        case "keycode":
        case "Keycode":
            value = keycode_to_string(value);
            break;
        case "megabytes":
        case "mb":
            value = string((value / 1000) / 1000) + "mb";
            break;
        case "gigabytes":
        case "gb":
            value = string(((value / 1000) / 1000) / 1000) + "gb";
            break;
        case "CoreObjectId":
            value = try_core_object_id_to_string(value);
            break;
        case "DigitalStatus":
            static STATUSES = [
                [DigitalStatus.Off, "Off"],
                [DigitalStatus.Pressed, "Pressed"],
                [DigitalStatus.Released, "Released"],
                [DigitalStatus.On, "On"],
                [DigitalStatus.Muted, "Muted"],
            ];
            var out = List();
            for (var i = 0; i < array_length(STATUSES); i++) {
                if has_flag(value, STATUSES[i][0]) {
                    out.push(STATUSES[i][1]);
                }
            }

            value = out.join(", ");
            break;
        default:
            value = format_value_by_enum_name(function_name, value);
    }

    return value;
}

provide_formatting_function(format_arg_provider);
