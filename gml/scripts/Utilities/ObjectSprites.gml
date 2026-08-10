//
//
function SpriteCatalogue() constructor {
    self.sprites = [[], [], [], []];

    //
    static add_sprite = function(_season, _sprite, _shadow) {
        array_push(self.sprites[_season], {
            sprite: _sprite,
            shadow: _shadow
        });
        return self;
    }

    //
    static set_season_sprites = function(_season, _sprites, _shadows) {
        assert_eq(
            array_length(_sprites),
            array_length(_shadows),
            "Sprite and shadow array must match in length!"
        );
        for (var i = 0; i < array_length(_sprites); i++) {
            self.add_sprite(_season, _sprites[i], _shadows[i]);
        }
        return self;
    }
}
