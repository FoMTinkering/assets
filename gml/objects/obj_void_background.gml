object_create(
    "obj_void_background",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            self.vel = Vec2(-0.2, 0.4);
            self.pos = Vec2Zero();
            self.og_camera_pos = CAMERA.cam_pos.clone();
            self.offset = Vec2Zero();

            self.stars_layer = layer_create(self.depth, "stars layer");
            self.stars = [
                layer_asset_create_tiled(self.stars_layer, -6000, -6000, spr_star_bkg_large, 12000, 12000),
                layer_asset_create_tiled(self.stars_layer, -6000, -6000, spr_star_bkg_medium, 12000, 12000),
                layer_asset_create_tiled(self.stars_layer, -6000, -6000, spr_star_bkg_small, 12000, 12000),
            ];

            function update(asset, weight) {
                //
                //
                //

                static ONE = Vec2(1.0, 1.0);

                //
                weight = Vec2(weight, weight);

                //
                //
                //
                //
                var camera_delta = CAMERA.cam_pos.sub(self.og_camera_pos);

                //
                //
                //
                var camera_with_offset = camera_delta.sub(self.offset);

                //
                //
                //
                //
                var camera_weighted = camera_with_offset.multip(ONE.sub(weight));

                //
                var pos_with_weight = self.pos.multip(weight);

                //
                var pos_with_camera = pos_with_weight.add(camera_weighted);

                //
                //
                //
                //
                var pos_with_offset = pos_with_camera.add(self.offset);

                //

                layer_asset_set_position(asset, pos_with_offset.x - 6000, pos_with_offset.y - 6000);
            }
        },
        step: function() {
            if SETTINGS.get("scrolling_backgrounds") {
                self.pos.x += self.vel.x;
                self.pos.y += self.vel.y;

                self.update(self.stars[0], 0.45);
                self.update(self.stars[1], 0.2);
                self.update(self.stars[2], 0.05);
            }
        },
        cleanup: function() {
            layer_destroy(self.stars_layer);
        },
    }
);
