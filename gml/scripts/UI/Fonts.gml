#macro SPRITE_FONTS global.sprite_fonts
SPRITE_FONTS = undefined;

function load_sprite_fonts() {
    var f_fonts = fiddle_get("fonts/sprite_fonts");

    var output = {};
    var keys = struct_get_names(f_fonts);
    for (var i = 0; i < array_length(keys); i++) {
        var sprite_font = f_fonts[$ keys[i]];

        //
        var char_names = struct_get_names(sprite_font.characters);

        for (var k = 0; k < array_length(char_names); k++) {
            var char = char_names[k];
            assert_neq(string_pos(char, sprite_font.order), 0);
        }

        //
        assert_eq(string_length(sprite_font.order), array_length(char_names));

        output[$ keys[i]] = {
            sprite: string_to_asset(sprite_font.sprite),
            order: sprite_font.order,
            characters: sprite_font.characters,
        };
    }

    return output;
}
