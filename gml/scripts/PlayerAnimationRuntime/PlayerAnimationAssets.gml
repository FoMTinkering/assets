function PlayerAnimationAssets() constructor {
    assets = List();
    skin_tone = 0;
    eyes = 0;

    function apply_to_par(par) {
        //
        for (var i = 0, c = self.assets.count(); i < c; i++) {
            var asset = self.assets.get(i);

            par.set_asset(asset.name, asset.lut_index);
        }
        par.render_hair = self.should_render_hair();
        par.set_skin_tone(self.skin_tone);
    }

    function should_render_hair() {
        return self.assets.every(function(v) {
            return !PLAYER_ANIMATION_DATABASE.player_assets.get(v.name).hide_hair;
        });
    }

    function clone() {
        var paa = new PlayerAnimationAssets();
        paa.assets = self.assets.clone();
        foreach_field(paa.assets, function(e) {
            return clone_value(e);
        })
        paa.skin_tone = self.skin_tone;
        paa.eyes = self.eyes;
        return paa;
    }


    //
    function serialize() {
        return {
            assets: self.assets.to_array(),
            skin_tone: self.skin_tone,
            eyes: self.eyes,
        }
    }
}

function create_default_player_animation_assets() {
    var paa = new PlayerAnimationAssets();

    paa.assets.push({
        name: "eyes_default",
        lut_index: 1,
    });
    paa.assets.push({
        name: "hair_straight_long_fringed",
        lut_index: 44,
    });
    paa.assets.push({
        name: "overalls_skirt",
        lut_index: 8,
    });
    paa.assets.push({
        name: "shoes_boots",
        lut_index: 3,
    });

    paa.skin_tone = 2;
    paa.eyes = 0;

    return paa;
}

//
function player_animation_assets_deserialize(deserialize_struct) {
    var paa = new PlayerAnimationAssets();

    //
    var has_eyes = false;
    var has_modesty = false;

    for (var i = 0; i < array_length(deserialize_struct.assets); i++) {
        var asset = deserialize_struct.assets[i];
        var asset_manifest = PLAYER_ANIMATION_DATABASE.player_assets.get(asset.name);

        if asset_manifest == undefined {
            if DEBUG_ASSERTIONS {
                crash("failed to load player_asset `{}`: unknown", asset.name);
            } else {
                error("failed to load player_asset `{}`: unknown", asset.name);
            }
            continue;
        }

        if asset_manifest.slots[AnimationSlot.Eyes] != undefined {
            has_eyes = true;
        }

        if asset_manifest.slots[AnimationSlot.Legs] != undefined
            || asset_manifest.slots[AnimationSlot.LegsTop] != undefined
            || asset_manifest.slots[AnimationSlot.Waist] != undefined
        {
            has_modesty = true;
        }

        //
        paa.assets.push(asset);
    }

    if DEBUG_ASSERTIONS
        && (has_eyes == false || has_modesty == false)
    {
        crash("Player Preset either does not have eyes or does not have pants or waist.\nCurrent Assets: {}", paa.assets);
    }

    if has_eyes == false {
        error("Player was missing eyes -- adding `eyes_default`");
        paa.assets.push({
            name: "eyes_default",
            lut_index: 1,
        });
    }

    if has_modesty == false {
        error("Player was missing waist or legs -- adding `underwear_shorts`");

        paa.assets.push({
            name: "underwear_shorts",
            lut_index: 1,
        });
    }

    paa.skin_tone = deserialize_struct.skin_tone;
    paa.eyes = deserialize_struct.eyes;

    return paa;
}
