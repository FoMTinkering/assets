#macro SCROLLBAR_WIDTH 18

function Scroller(parent, canvas_pos, canvas_size, canvas_align, scroll_bar_pos, scroll_bar_size, scroll_bar_align) constructor {
    function free() {
        ANCHOR.free_node(self.canvas);
        ANCHOR.free_node(self.outline);
        ANCHOR.free_node(self.scroll_bar_root);
        ANCHOR.free_node(self.hovered_borders[0]);
        ANCHOR.free_node(self.hovered_borders[1]);
        ANCHOR.free_node(self.selected_borders[0]);
        ANCHOR.free_node(self.selected_borders[1]);
    }

    //
    function new_element(height) {
        static DEF_HEIGHT = DEFAULT_ELEMENT_HEIGHT; //
        height = height == undefined ? DEF_HEIGHT : height;
        var width = self.canvas.get_width();

        var alt = self.alternate_colors_flag && self.iterator % 2 == 1;
        if self.use_common_slice_flag {
            var node = common_slice(self.root, width, height, alt);
        } else {
            var sprite_key = alt ? self.main_box_sprite_key : self.alt_box_sprite_key;
            var node = ANCHOR.nine_slice(self.root)
                .set_sprites_from_key(sprite_key)
                .set_size(width, height)
        }

        node
            .set_bbox_offset(0, 0, 0, -1)
            .set_label(format("scroller_element_{}", self.iterator))
            .set_y(self.root_bottom_y)
            .set_z(self.element_depth)

        //
        //
        node.z_mod = 0;

        self.add_vertical_space(height - 1);
        self.iterator += 1;
        return node;
    }

    //
    function new_header(icon, title, height=20) {
        var header = self.new_element(height);
        header.set_sprites_from_key("spr_ui_generic_box_category");

        header.icon_node = ANCHOR.sprite(header)
            .set_sprite(icon)
            .set_align(Align.LeftIn, Align.Middle)
            .set_x(4)

        ANCHOR.text(header.icon_node)
            .set_x(3)
            .set_align(Align.RightOut, Align.Middle)
            .set_key(title)
            .set_lut(spr_ui_cooking_text_lut, 12)

        return header;
    }

    //
    function add_height_to_element(element, amount) {
        element.add_height(amount);
        var pos = array_pos(self.root.children, element);
        for (var i = pos + 1; i < array_length(self.root.children); i++) {
            var elem = self.root.children[i];
            elem.add_y(amount);
        }
        self.add_vertical_space(amount);
    }

    //
    function add_vertical_space(height) {
        var new_height = self.root_bottom_y + height;
        self.canvas.set_height(max(new_height, self.view_height));
        self.root_bottom_y = new_height;
        if self.root_bottom_y < self.view_height {
            self.scroll_bar_root.disable();
        } else if self.root_bottom_y - 1 > self.view_height {
            self.scroll_bar_root.enable();
        }
        self.update_button_height();
    }

    //
    //
    function get_current_y() {
        return abs(self.root.get_y());
    }

    //
    function get_max_canvas_y() {
        return max(0, self.canvas.get_height() - self.view_height - 1);
    }

    //
    function set_button_y_from_canvas() {
        var current_y = self.get_current_y();
        var max_canvas_y = self.get_max_canvas_y();
        if max_canvas_y == 0 {
            self.button.set_y(0);
        } else {
            var ratio_position = current_y / max_canvas_y;
            var new_y = floor(self.range_pos_limits.y * ratio_position);
            self.button.set_y(new_y);
        }
    }

    //
    function set_canvas_y_from_button() {
        var button_y = self.button.get_y();
        var ratio_position = button_y / max(self.range_pos_limits.y, 1);
        var new_y = floor(self.get_max_canvas_y() * ratio_position);
        self.root.set_y(self.base_root_position - new_y);
    }

    //
    function scroll_by_amount(val) {
        var new_y = clamp(
            abs(self.root.get_y()) + val,
            0,
            self.get_max_canvas_y(),
        );
        self.root.set_y(self.base_root_position - new_y);
        self.set_button_y_from_canvas();
    }

    //
    //
    function update_button_height() {
        var height = clamp(
            floor(self.range.get_height() / (self.root_bottom_y / self.view_height)),
            32,
            self.range.get_height()
        );
        self.button.set_height(height);
        self.range_pos_limits.y = self.range.get_height() - height;
    }

    //
    function set_scroll_sprites(up_arrow, down_arrow, range, button) {
        self.arrow_up.set_sprite(up_arrow);
        self.arrow_down.set_sprite(down_arrow);
        self.range.set_sprite(range);
        self.button.set_sprite(button);
    }

    //
    function set_element_sprite_keys(main_box, alt_box) {
        self.main_box_sprite_key = main_box;
        self.alt_box_sprite_key = alt_box ?? main_box;
    }

    //
    //
    //
    //
    function subscribe_to_pilot(pilot, top_padding, bottom_padding) {
        self.subscribed_pilot = pilot;
        self.set_pilot_padding(top_padding, bottom_padding)
        return self;
    }

    //
    function set_pilot_padding(top_padding=0, bottom_padding=-2) {
        self.pilot_padding = {
            top: top_padding,
            bottom: bottom_padding,
        };
        return self;
    }

    //
    function set_unlocked(boo=true) {
        self.canvas.set_unlocked(boo);
    }

    //
    function lock() {
        self.set_unlocked(false);
    }

    //
    function unlock() {
        self.set_unlocked(true);
    }

    //
    function remove_outline() {
        self.outline.disable();
        return self;
    }

    //
    function set_lut(lut, index) {
        self.arrow_up.set_lut(lut, index);
        self.arrow_down.set_lut(lut, index);
        self.range.set_lut(lut, index);
        self.button.set_lut(lut, index);
        self.outline.set_lut(lut, index);
    }

    //
    function scroll_with_stick(boo=true) {
        self.scroll_with_stick_flag = boo;
        return self;
    }

    function use_common_slice(boo) {
        self.use_common_slice_flag = boo;
        return self;
    }

    function alternate_colors(boo=true) {
        self.alternate_colors_flag = boo;
        return self;
    }

    //
    function move(xx, yy) {
        self.canvas.add_xy(xx, yy);
        self.hovered_borders[0].add_xy(xx, yy);
        self.hovered_borders[1].add_xy(xx, yy);
        self.selected_borders[0].add_xy(xx, yy);
        self.selected_borders[1].add_xy(xx, yy);
        self.outline.add_xy(xx, yy);
    }

    self.scroll_with_stick_flag = false;
    self.iterator = 0;
    self.use_common_slice_flag = true;
    self.pilot_up_padding = 0;
    self.pilot_down_padding = 0;
    self.view_height = canvas_size.y;
    self.subscribed_pilot = undefined;
    self.main_box_sprite_key = "spr_ui_scroller_main_box";
    self.alt_box_sprite_key = "spr_ui_scroller_alt_box";
    self.alternate_colors_flag = true;
    self.scroll_suppression = undefined;

    self.canvas = ANCHOR.canvas(parent, parent.get_z() - 3)
        .set_xy(canvas_pos.x, canvas_pos.y)
        .set_size(canvas_size)
        .set_align(canvas_align.x, canvas_align.y)
        .set_render_partial(0, 0, canvas_size.x, canvas_size.y)
        .set_label("scroller_canvas")
        .set_think_callback(function() {
            if ON_KBM {
                if self.canvas.is_unlocked() && ANCHOR.point_in_node(self.canvas, MOUSE_GUI_X, MOUSE_GUI_Y) {
                    if mouse_wheel_up() {
                        self.scroll_by_amount(-15);
                    } else if mouse_wheel_down() {
                        self.scroll_by_amount(15);
                    }
                }

                if
                    ANCHOR.point_in_node(self.range, MOUSE_GUI_X, MOUSE_GUI_Y)
                    && INPUT.take_press(InputId.LeftMouse)
                {
                    var range_y = ANCHOR.get_screen_position(self.range).y;
                    var range_height = self.range.get_height();

                    var button_y = self.button.get_y();
                    var button_height = self.button.get_height();

                    var normal_y = MOUSE_GUI_Y - range_y;

                    var click_ratio = normal_y / range_height;
                    var top_ratio = button_y / range_height;

                    if click_ratio > top_ratio {
                        var target_y = normal_y - button_height;
                    } else {
                        var target_y = normal_y;
                    }

                    self.button.set_y(clamp(
                        target_y,
                        self.range_pos_limits.x,
                        self.range_pos_limits.y
                    ));
                    self.set_canvas_y_from_button();
                }
            }

            if
                self.scroll_with_stick_flag
                && ON_GAMEPAD
                && ANCHOR.get_active_pilot() == self.subscribed_pilot
                && INPUT.gp_right_stick.y != 0
            {
                self.scroll_by_amount(INPUT.gp_right_stick.y * 4);
                self.scroll_suppression = self.subscribed_pilot.get();
            }

            if
                self.subscribed_pilot != undefined
                && ANCHOR.in_directional_control()
                && ANCHOR.active_pilot == self.subscribed_pilot
                && (
                    self.scroll_suppression == undefined
                    || self.scroll_suppression != self.subscribed_pilot.get()
                )
            {
                self.scroll_suppression = undefined;
                var node = self.subscribed_pilot.get();
                if node != undefined {
                    var node_y = ANCHOR.get_relative_position(node, self.canvas).y;
                    var base = node_y + node.get_height();
                    var above = node_y - self.pilot_padding.top < 0;
                    var below = base + self.pilot_padding.bottom > self.view_height;
                    if above && !below {
                        self.scroll_by_amount(node_y - self.pilot_padding.top);
                    }

                    if below && !above {
                        self.scroll_by_amount(base - self.view_height + self.pilot_padding.bottom);
                    }
                }
            }

            var enable_hovered_top = false;
            var enable_hovered_bottom = false;
            var enable_selected_top = false;
            var enable_selected_bottom = false;
            for (var i = 0; i < array_length(self.root.children); i++) {
                var child = self.root.children[i];
                var top = child.get_y() + root.get_y();
                var bot = top + child.get_height() - 1;

                //
                var top_is_clipped = top < -1 || top > self.view_height;
                var bottom_is_clipped = bot < -1 || bot > self.view_height;
                var all_clipped = (top < -1 && bot < -1) || (top > self.view_height && bot > self.view_height);
                child.set_enabled(!all_clipped);

                if child.is_hovered() {
                    enable_hovered_top = !top_is_clipped;
                    enable_hovered_bottom = !bottom_is_clipped;
                    self.hovered_borders[0]
                        .set_x(self.canvas.get_x())
                        .set_y(child.get_y() + self.root.get_y() + self.canvas.get_y())
                        .set_scale_x(child.get_width())
                    self.hovered_borders[1]
                        .set_x(self.canvas.get_x())
                        .set_y(child.get_y() + child.get_height() + self.root.get_y() + self.canvas.get_y() - 1)
                        .set_scale_x(child.get_width())
                    child.set_z(self.hovered_element_depth + child.z_mod);
                } else {
                    child.set_z(self.element_depth + child.z_mod);
                }

                if child.is_selected() {
                    enable_selected_top = !top_is_clipped;
                    enable_selected_bottom = !bottom_is_clipped;
                    self.selected_borders[0]
                        .set_x(self.canvas.get_x())
                        .set_y(child.get_y() + self.root.get_y() + self.canvas.get_y())
                        .set_scale_x(child.get_width())
                    self.selected_borders[1]
                        .set_x(self.canvas.get_x())
                        .set_y(child.get_y() + child.get_height() + self.root.get_y() + self.canvas.get_y() - 1)
                        .set_scale_x(child.get_width())
                    child.set_z(self.hovered_element_depth);
                }
            }

            self.hovered_borders[0].set_enabled(enable_hovered_top && self.use_common_slice_flag);
            self.hovered_borders[1].set_enabled(enable_hovered_bottom && self.use_common_slice_flag);

            self.selected_borders[0].set_enabled(enable_selected_top && self.use_common_slice_flag);
            self.selected_borders[1].set_enabled(enable_selected_bottom && self.use_common_slice_flag);
        })

    //
    //
    self.base_root_position = -1;
    self.root = ANCHOR.positional(self.canvas)
        .set_y(self.base_root_position)
        .set_label("scroller_root")

    self.element_depth = self.root.get_z() - 1;
    self.header_depth = self.root.get_z() - 1.1;
    self.outline_depth = self.root.get_z() - 1.2;
    self.hovered_element_depth = self.root.get_z() - 1.3;
    self.border_depth = self.root.get_z() - 1.4;

    self.root_bottom_y = 0;
    var scroll_bar_vertical_padding = 4;

    self.scroll_bar_root = ANCHOR.positional(parent, parent.get_z() - 2)
        .set_xy(scroll_bar_pos.x, scroll_bar_pos.y)
        .set_size(scroll_bar_size)
        .set_align(scroll_bar_align.x, scroll_bar_align.y)
        .disable()

    self.arrow_up = ANCHOR.sprite(self.scroll_bar_root)
        .set_y(scroll_bar_vertical_padding)
        .set_align(Align.Center, Align.TopIn)
        .set_sprites_from_key("spr_ui_scroller_arrow_up")

    self.arrow_down = ANCHOR.sprite(self.scroll_bar_root)
        .set_y(-scroll_bar_vertical_padding)
        .set_align(Align.Center, Align.BottomIn)
        .set_sprites_from_key("spr_ui_scroller_arrow_down")

    var range_height = scroll_bar_size.y - 20 - scroll_bar_vertical_padding * 2;
    self.range_pos_limits = Vec2Zero();
    self.range = ANCHOR.nine_slice(self.scroll_bar_root)
    self.range
        .set_align(Align.Center, Align.Middle)
        .set_sprite(spr_ui_scroller_range)
        .set_size(6, range_height)
        .set_bbox_offset(-4, 0, 4, 0)
        .set_hover_sound(undefined)

    self.button = ANCHOR.nine_slice(self.range)
        .set_sprite(spr_ui_scroller_button)
        .set_size(8, 8)
        //
        .set_align(Align.Center, Align.TopIn)
        .set_hover_sound(undefined)
        .listen_for_taps()
        .set_think_callback(function() {
            if self.button.in_drag(0, true) {
                var new_pos = self.button.get_position_with_drag_applied();
                self.button.set_y(clamp(
                    new_pos.y,
                    self.range_pos_limits.x,
                    self.range_pos_limits.y
                ));
                self.set_canvas_y_from_button();
            }
        })

    self.outline = ANCHOR.nine_slice(parent, self.outline_depth)
        .set_xy(canvas_pos.x, canvas_pos.y)
        .set_align(canvas_align.x, canvas_align.y)
        .set_sprite(spr_ui_scroller_outline)
        .disable()
        .set_think_callback(function() {
            self.outline.set_size(
                self.canvas.get_width(),
                self.view_height + 1,
            );
        })

    //
    //
    //
    //
    self.hovered_borders = [
        ANCHOR.sprite(parent, self.border_depth)
            .set_x(-1)
            .set_sprite(spr_pixel)
            .set_color(c_black)
            .disable(),

        ANCHOR.sprite(parent, self.border_depth)
            .set_x(-1)
            .set_sprite(spr_pixel)
            .set_color(c_black)
            .disable(),
    ];

    self.selected_borders = [
        ANCHOR.sprite(parent, self.border_depth)
            .set_x(-1)
            .set_sprite(spr_pixel)
            .set_color(c_black)
            .disable(),

        ANCHOR.sprite(parent, self.border_depth)
            .set_x(-1)
            .set_sprite(spr_pixel)
            .set_color(c_black)
            .disable(),
    ];

    self.update_button_height();
}

function create_scroller(parent, canvas_pos=undefined, canvas_size=undefined) {
    //
    canvas_pos = canvas_pos == undefined ? Vec2(-1, 0) : canvas_pos;
    canvas_size = canvas_size == undefined ? Vec2((parent.get_width() + 2) - SCROLLBAR_WIDTH + 1, parent.get_height()) : canvas_size;
    var canvas_align = Vec2(Align.LeftIn, Align.TopIn);
    var scroll_bar_pos = Vec2(canvas_pos.x + canvas_size.x - 1, canvas_pos.y - 1);
    var scroll_bar_size = Vec2(SCROLLBAR_WIDTH, canvas_size.y + 2);
    var scroll_bar_align = Vec2(Align.LeftIn, Align.TopIn);
    return new Scroller(parent, canvas_pos, canvas_size, canvas_align, scroll_bar_pos, scroll_bar_size, scroll_bar_align);
}

function create_scroller_ext(parent, canvas_pos, canvas_size, canvas_align, scroll_bar_pos, scroll_bar_size, scroll_bar_align) {
    return new Scroller(parent, canvas_pos, canvas_size, canvas_align, scroll_bar_pos, scroll_bar_size, scroll_bar_align);
}
