object_create(
    "obj_shadow_level",
    undefined,
    {
        sprite_index: undefined,
        create: function() {
            //
            //
            //
            //
            //

            //
            //
            //
            //
            //
            //
            //
            //
            //
            shadow_area = undefined;

            //
            name = undefined;

            function draw_shadow_level() {
                gpu_set_depth_test(cmpfunc_lessequal, false);

                if DEBUG_TOOLS {
                    gpu_push_group(self.name ?? "unknown_shadows");
                }

                gpu_set_stencil_operation(StencilOperation.Replace);

                //
                if self.target_shadow_grid != undefined && self.shadow_area != undefined {
                    var value = stencil_increment();
                    gpu_set_stencil_test(cmpfunc_greater, value);
                
                    //
                    //
                    gpu_set_color_write(false);
                    draw_sprite_ext(
                        self.shadow_area[0],
                        self.shadow_area[1],
                        self.shadow_area[2],
                        self.shadow_area[3],
                        self.shadow_area[4],
                        self.shadow_area[5],
                        0,
                        c_white,
                        1.0,
                    );
                    gpu_set_color_write(true);

                    gpu_set_stencil_test(cmpfunc_equal, value);
                } else {
                    gpu_set_stencil_test(cmpfunc_greater, stencil_increment());
                }

                gpu_set_extra(UberShaderKind.Flat);
                var shadow_color = make_color_rgb(
                    round(255 * POST_PROCESS.shadow_multiply_color[0] * POST_PROCESS.shadow_multiply_color[3] * self.image_alpha),
                    round(255 * POST_PROCESS.shadow_multiply_color[1] * POST_PROCESS.shadow_multiply_color[3] * self.image_alpha),
                    round(255 * POST_PROCESS.shadow_multiply_color[2] * POST_PROCESS.shadow_multiply_color[3] * self.image_alpha),
                );
                var shadow_alpha = POST_PROCESS.shadow_multiply_color[3] * self.image_alpha;

                //
                //
                //
                //
                //
                gpu_set_blendmode_ext_sepalpha(
                    bm_dest_color,
                    bm_inv_src_alpha,
                    bm_one,
                    bm_one
                );

                //
                if self.target_shadow_grid != undefined {
                    //
                    shadows_draw_shadow_collection(
                        self.target_shadow_grid.grid_get_collection_view(CAMERA.get_cull_region()),
                        shadow_color,
                        shadow_alpha
                    );

                    //
                    if instance_exists(obj_tile_cursor) && self.target_shadow_grid == SHADOW_GRID {
                        //
                        for (var i = 0; i < obj_tile_cursor.extra_casters_to_draw; i++) {
                            var shadow_caster = obj_tile_cursor.extra_shadow_casters.try_get(i);
                            if shadow_caster == undefined {
                                continue;
                            }

                            //
                            //
                            if shadow_caster[ShadowCasterField.ImageXScale] == 0
                                && shadow_caster[ShadowCasterField.ImageYScale] == 0
                            {
                                draw_sprite_ext(
                                    shadow_caster[ShadowCasterField.SpriteIndex],
                                    shadow_caster[ShadowCasterField.ImageIndex],
                                    shadow_caster[ShadowCasterField.WorldX],
                                    shadow_caster[ShadowCasterField.WorldY],
                                    1,
                                    1,
                                    0,
                                    shadow_color,
                                    shadow_alpha
                                );
                            } else {
                                draw_sprite_part(
                                    shadow_caster[ShadowCasterField.SpriteIndex],
                                    shadow_caster[ShadowCasterField.ImageIndex],
                                    shadow_caster[ShadowCasterField.ImageXScale],
                                    shadow_caster[ShadowCasterField.ImageYScale],
                                    8,
                                    8,
                                    shadow_caster[ShadowCasterField.WorldX],
                                    shadow_caster[ShadowCasterField.WorldY],
                                    shadow_color,
                                    shadow_alpha,
                                );
                            }
                        }

                        //
                        var old_b = obj_tile_cursor.image_blend;
                        obj_tile_cursor.image_blend = shadow_color;
                        obj_tile_cursor.shadow_draw(shadow_alpha);
                        obj_tile_cursor.image_blend = old_b;
                    }
                }

                //
                if self.shadow_maps != undefined {
                    for (var i = 0, c = array_length(self.shadow_maps); i < c; i++) {
                        var off = self.shadow_map_offsets[i];
                        draw_tilemap(self.shadow_maps[i], off.x, off.y, shadow_color, shadow_alpha);
                    }
                }

                gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);
                gpu_reset_extra();
                gpu_disable_stencil();

                if self.render_outlines {
                    shadows_draw_grass_backing();
                }
                gpu_set_depth_test(cmpfunc_always);

                if DEBUG_TOOLS {
                    gpu_pop_group();
                }
            }
        },
        draw: function() {
            if self.shadow_maps != undefined {
                self.draw_shadow_level();
            }
        }
    }
);

function draw_extra_shadow_maps() {
    with obj_shadow_level {
        if self.shadow_maps == undefined {
            gpu_set_depth(self.depth);
            self.draw_shadow_level();
        }
    }
}
