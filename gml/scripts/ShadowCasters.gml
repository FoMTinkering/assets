#macro SHADOW_GRID global.__shadow_grid
global.__shadow_grid = new ShadowGrid(true);

#macro SHADOW_GRID_CELL_SIZE_DEFAULT 128

#macro SHADOW_WAIT_LIST global.__shadow_wait_list
global.__shadow_wait_list = List();

function ShadowGrid(initial=false) constructor {
    if initial == false && LOCATIONS[gm_room_to_location_id(room())].outdoor {
        self.cells = ds_grid_create(ceil(room_width() / SHADOW_GRID_CELL_SIZE_DEFAULT), ceil(room_height() / SHADOW_GRID_CELL_SIZE_DEFAULT));
        ds_grid_clear(self.cells, undefined);
    } else {
        self.cells = undefined;
    }

    self.is_freed = false;
    self.oversized_cell = array_create(100, undefined);

    //
    function caster_create(xx, yy, over_sized=false) {
        var caster = create_shadow_caster(xx, yy, over_sized);
        self.caster_add(caster);

        return caster;
    }

    //
    function caster_add(caster) {
        if DEBUG_ASSERTIONS {
            assert_eq(caster[ShadowCasterField.Id], undefined);
        }

        var cell;
        if caster[ShadowCasterField.OverSized] || self.cells == undefined {
            cell = self.oversized_cell;
        } else {
            var cell_x = caster[ShadowCasterField.WorldX] div SHADOW_GRID_CELL_SIZE_DEFAULT;
            var cell_y = caster[ShadowCasterField.WorldY] div SHADOW_GRID_CELL_SIZE_DEFAULT;

            var maybe_cell;

            if cell_x < 0
                || cell_x >= ds_grid_width(self.cells)
                || cell_y < 0
                || cell_y >= ds_grid_height(self.cells)
            {
                maybe_cell = self.oversized_cell;
            } else {
                maybe_cell = self.cells[# cell_x, cell_y];
            }

            //
            if maybe_cell == undefined {
                cell = array_create(8, undefined);
                self.cells[# cell_x, cell_y] = cell;
            } else {
                cell = maybe_cell;
            }
        }

        var first_undefined_idx = array_index(cell, undefined);
        if first_undefined_idx == undefined {
            caster[ShadowCasterField.Id] = array_length(cell);
            array_push(cell, caster);
        } else {
            cell[first_undefined_idx] = caster;
            caster[ShadowCasterField.Id] = first_undefined_idx;
        }
    }

    //
    function caster_remove(caster) {
        //
        if caster[ShadowCasterField.Id] == undefined {
            return;
        }

        var cell;
        if caster[ShadowCasterField.OverSized] || self.cells == undefined {
            cell = self.oversized_cell;
        } else {
            var cell_x = caster[ShadowCasterField.WorldX] div SHADOW_GRID_CELL_SIZE_DEFAULT;
            var cell_y = caster[ShadowCasterField.WorldY] div SHADOW_GRID_CELL_SIZE_DEFAULT;

            if cell_x < 0 || cell_x >= ds_grid_width(self.cells)
                || cell_y < 0 || cell_y >= ds_grid_height(self.cells)
            {
                cell = self.oversized_cell;
            } else {
                cell = self.cells[# cell_x, cell_y];
            }
        }

        //
        if cell == undefined {
            return;
        }

        cell[caster[ShadowCasterField.Id]] = undefined;
        caster[ShadowCasterField.Id] = undefined;
    }

    //
    function grid_get_collection_view(cull_region) {
        var output = [];

        //
        array_push(output, self.oversized_cell);

        if self.cells != undefined {
            var xx_max = min(1 + (cull_region[0] + cull_region[2]) div SHADOW_GRID_CELL_SIZE_DEFAULT, ds_grid_width(self.cells));
            var yy_max = min(1 + (cull_region[1] + cull_region[3]) div SHADOW_GRID_CELL_SIZE_DEFAULT, ds_grid_height(self.cells));

            //
            var cell;
            for (var i = cull_region[0] div SHADOW_GRID_CELL_SIZE_DEFAULT; i < xx_max; i++) {
                for (var j = cull_region[1] div SHADOW_GRID_CELL_SIZE_DEFAULT; j < yy_max; j++) {
                    cell = self.cells[# i, j];

                    if cell != undefined {
                        array_push(output, cell);
                    }
                }
            }
        }

        return output;
    }

    //
    function free() {
        if self.cells != undefined {
            self.cells = undefined;
        }
        self.oversized_cell = undefined;
        self.is_freed = true;
    }
}

function create_shadow_caster(xx, yy, over_sized, shadow_grid_override) {
    var output = array_create(ShadowCasterField.LEN, undefined);

    output[ShadowCasterField.WorldX] = xx;
    output[ShadowCasterField.WorldY] = yy;
    output[ShadowCasterField.ImageIndex] = 0.0;
    output[ShadowCasterField.ImageXScale] = 1.0;
    output[ShadowCasterField.ImageYScale] = 1.0;
    output[ShadowCasterField.ImageAlpha] = 1.0;
    output[ShadowCasterField.OverSized] = over_sized;
    output[ShadowCasterField.Grid] = shadow_grid_override ?? SHADOW_GRID;

    return output;
}

function shadow_caster_set_sprite(caster, spr, index) {
    //
    if caster[ShadowCasterField.SpriteIndex] == spr {
        return;
    }
    if index != undefined {
        caster[ShadowCasterField.ImageIndex] = index;
    }
    //
    caster[ShadowCasterField.SpriteIndex] = spr;

    if caster[ShadowCasterField.SpriteIndex] != undefined
        && caster[ShadowCasterField.OverSized] == false
        && (caster[ShadowCasterField.ImageXScale] * sprite_get_width(caster[ShadowCasterField.SpriteIndex]) >= SHADOW_GRID_CELL_SIZE_DEFAULT
            || caster[ShadowCasterField.ImageYScale] * sprite_get_height(caster[ShadowCasterField.SpriteIndex]) >= SHADOW_GRID_CELL_SIZE_DEFAULT
            || array_contains(SHADOWS_OVERSIZED, caster[ShadowCasterField.SpriteIndex]))
    {
        caster[ShadowCasterField.Grid].caster_remove(caster);
        caster[ShadowCasterField.OverSized] = true;
        caster[ShadowCasterField.Grid].caster_add(caster);
    }
}

function shadow_caster_set_image(caster, index) {
    caster[ShadowCasterField.ImageIndex] = index;
}

function shadow_caster_set_image_xscale(caster, image_x) {
    //
    if caster[ShadowCasterField.ImageXScale] == image_x {
        return;
    }
    //
    caster[ShadowCasterField.ImageXScale] = image_x;

    if caster[ShadowCasterField.OverSized] == false
        && image_x * sprite_get_width(caster[ShadowCasterField.SpriteIndex]) >= SHADOW_GRID_CELL_SIZE_DEFAULT
    {
        caster[ShadowCasterField.Grid].caster_remove(caster);
        caster[ShadowCasterField.OverSized] = true;
        caster[ShadowCasterField.Grid].caster_add(caster);
    }
}

function shadow_caster_set_alpha(caster, alpha) {
    caster[ShadowCasterField.ImageAlpha] = alpha;
}

function shadow_caster_set_position(caster, xx, yy) {
    if xx == caster[ShadowCasterField.WorldX] && yy == caster[ShadowCasterField.WorldY] {
        return;
    }

    var needs_rebind;
    if caster[ShadowCasterField.OverSized] || caster[ShadowCasterField.Grid].cells == undefined {
        needs_rebind = false;
    } else {
        needs_rebind =
            (xx div SHADOW_GRID_CELL_SIZE_DEFAULT) != (caster[ShadowCasterField.WorldX] div SHADOW_GRID_CELL_SIZE_DEFAULT)
            || (yy div SHADOW_GRID_CELL_SIZE_DEFAULT) != (caster[ShadowCasterField.WorldY] div SHADOW_GRID_CELL_SIZE_DEFAULT);
    }

    //
    if needs_rebind {
        caster[ShadowCasterField.Grid].caster_remove(caster);
    }

    caster[ShadowCasterField.WorldX] = xx;
    caster[ShadowCasterField.WorldY] = yy;

    if needs_rebind {
        caster[ShadowCasterField.Grid].caster_add(caster);
    }
}
