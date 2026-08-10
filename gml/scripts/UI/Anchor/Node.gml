enum NodeId {
    Canvas,
    Text,
    Typewriter,
    Sprite,
    Positional,
    Custom,
    LEN
}

function Node(_parent, _z, _layer_override) constructor {
    //
    idx = undefined;
    type = undefined;
    blackboard = Map();
    marked_for_death = false;
    freed = false;
    depress_children = true;
    child_offset = Vec2Zero();
    age = 0;
    hover_outline = undefined;
    run_logic = false;

    //
    z_dirty = true;
    enabled = true; //
    safe_enabled = true; //
    in_hover = false;
    hover_frames = 0;
    in_tap = false;
    unlocked = true;
    safe_unlocked = true;
    listens_for_hovers = false;
    listens_for_taps = false;
    tap_repeating = false;
    tap_tick = undefined;

    //
    children = [];
    parent = _parent;

    //
    //
    //
    //
    //
    //
    layer = AnchorLayer.WorldSpace;

    if parent == undefined {
        canvas = undefined;
    } else {
        if parent.type == NodeId.Canvas {
            canvas = parent;
            layer = canvas.layer;
        } else {
            canvas = parent.canvas;
            layer = parent.layer;
        }
    }
    if _layer_override != undefined {
        layer = _layer_override;
    }
    x = 0;
    y = 0;
    z = _z;
    z_mod = 0;
    width = 0;
    height = 0;
    horz_align = Align.LeftIn;
    vert_align =  Align.TopIn;
    alpha = 1;
    max_alpha = 1;
    color = c_white;
    bbox_offset = undefined;
    offset = Vec2(0, 0);
    cache_is_dirty = false;
    cache_x = 0;
    cache_y = 0;
    cache_z = 0;
    cache_alpha = 1;
    cache_bbox_left = 0;
    cache_bbox_top = 0;
    cache_bbox_right = 0;
    cache_bbox_bottom = 0;
    cache_layer = self.layer;

    //
    event_callbacks = {
        tap: undefined,
        think: undefined,
        gui_resize: undefined,
        room_start: undefined,
        free: undefined,
    }

    //
    pilot = undefined;
    tap_is_deferred = false;
    mouse_can_escape_tap_flag = true;
    soft_locked = false;

    lut_info = {
        enabled: false,
        texture: spr_pixel,
        sprite: spr_pixel,
        uvs: undefined,
        index: 0,
        speed: 0,
        slot_count: 0,
        //
        use_day_night_index: false,
    };

    //
    tap_sound = "SoundEffects/UI/UIClick";
    hover_sound = "SoundEffects/UI/UIMouseOver";

    //
    label = undefined;
    source_menu = undefined;
    spawn_callstack = undefined;

    static set_position = function(x, y, z) {
        if self.x == x && self.y == y && self.z == z {
            return self;
        }
        assert_neq(x, undefined);
        assert_neq(y, undefined);
        assert_neq(z, undefined);
        //
        self.cache_is_dirty = true;
        self.z_dirty = true;
        self.x = x;
        self.y = y;
        self.z = z;
        return self;
    }

    static set_xy = function(x, y) {
        if is_struct(x) {
            y = x.y;
            x = x.x;
        }
        if self.x == x && self.y == y {
            return self;
        }
        assert_neq(x, undefined);
        assert_neq(y, undefined);
        self.cache_is_dirty = true;
        self.x = x;
        self.y = y;
        return self;
    }

    static set_layer = function(new_layer) {
        if new_layer == self.layer {
            return self;
        }
        self.layer = new_layer;
        self.cache_is_dirty = true;

        return self;
    }

    static set_layer_recursive = function(new_layer) {
        self.set_layer(new_layer);
        for (var i = 0; i < array_length(self.children); i++) {
            self.children[i].set_layer_recursive(new_layer);
        }

        return self;
    }

    static set_x = function(x) {
        if self.x == x {
            return self;
        }
        assert_neq(x, undefined);
        self.cache_is_dirty = true;
        self.x = x;
        return self;
    }

    static set_y = function(y) {
        if self.y == y {
            return self;
        }
        assert_neq(y, undefined);
        self.cache_is_dirty = true;
        self.y = y;
        return self;
    }

    static set_z = function(z) {
        if self.z == z {
            return self;
        }
        assert_neq(z, undefined);
        //
        self.cache_is_dirty = true;
        self.z_dirty = true;
        self.z = z;
        return self;
    }

    static add_x = function(val) {
        if val == 0 {
            return self;
        }
        self.cache_is_dirty = true;
        self.x += val;
        return self;
    }

    static add_y = function(val) {
        if val == 0 {
            return self;
        }
        self.cache_is_dirty = true;
        self.y += val;
        return self;
    }

    static add_z = function(val) {
        if val == 0 {
            return self;
        }
        //
        self.cache_is_dirty = true;
        self.z_dirty = true;
        self.z += val;
        return self;
    }

    static add_xy = function(xx ,yy) {
        self.add_x(xx);
        self.add_y(yy);
        return self;
    }

    static get_position = function() {
        return {
            x: self.x,
            y: self.y,
            z: self.z,
        }
    }

    static get_x = function() {
        return self.x;
    }

    static get_y = function() {
        return self.y;
    }

    static get_z = function() {
        return self.z;
    }

    //
    static set_depress_children = function(boo) {
        self.depress_children = boo;
        return self;
    }

    //
    //
    //
    static set_child_offset = function(xx, yy) {
        if self.child_offset.x == xx && self.child_offset.y == yy {
            return self;
        }
        self.child_offset.x = xx;
        self.child_offset.y = yy;
        self.cache_is_dirty = true;
        return self;
    }

    //
    //
    static set_size = function(width, height) {
        if is_struct(width) {
            height = width.y;
            width = width.x;
        } else {
            height = height == undefined ? width : height;
            assert_neq(width, undefined);
            assert_neq(height, undefined);
        }
        if self.width == width && self.height == height {
            return self;
        }
        self.cache_is_dirty = true;
        self.width = width;
        self.height = height;
        return self;
    }

    static set_width = function(width) {
        if self.width == width {
            return self;
        }
        self.cache_is_dirty = true;
        self.width = width;
        return self;
    }

    static set_height = function(height) {
        if self.height == height {
            return self;
        }
        self.cache_is_dirty = true;
        self.height = height;
        return self;
    }

    static add_size = function(width, height) {
        if width == 0 && height == 0 {
            return self;
        }
        self.cache_is_dirty = true;
        self.width += width;
        self.height += height;
        return self;
    }

    static add_width = function(width) {
        if width == 0 {
            return self;
        }
        self.cache_is_dirty = true;
        self.width += width;
        return self;
    }

    static add_height = function(height) {
        if height == 0 {
            return self;
        }
        self.cache_is_dirty = true;
        self.height += height;
        return self;
    }

    static get_size = function() {
        return {
            x: self.width,
            y: self.height,
        }
    }

    static get_width = function() {
        return self.width;
    }

    static get_height = function() {
        return self.height;
    }

    static set_bbox_offset = function(left, top, right, bottom) {
        self.bbox_offset = Vec4(left, top, right, bottom);
        return self;
    }

    static set_align = function(horizontal, vertical) {
        if self.horz_align == horizontal && self.vert_align == vertical {
            return self;
        }
        self.cache_is_dirty = true;
        self.horz_align = horizontal;
        self.vert_align = vertical;
        return self;
    }

    static set_horz_align = function(horizontal) {
        if self.horz_align == horizontal {
            return self;
        }
        self.cache_is_dirty = true;
        self.horz_align = horizontal;
        return self;
    }

    static set_vert_align = function(vertical) {
        if self.vert_align == vertical {
            return self;
        }
        self.cache_is_dirty = true;
        self.vert_align = vertical;
        return self;
    }

    static get_align = function() {
        return {
            x: self.horz_align,
            y: self.vert_align,
        }
    }

    static get_left_align = function() {
        return self.horz_align;
    }

    static get_right_align = function() {
        return self.vert_align;
    }

    static set_color = function(new_color) {
        if self.color == new_color {
            return self;
        }
        self.cache_is_dirty = true;
        self.color = new_color;
        return self;
    }

    static get_color = function() {
        return self.color;
    }

    static set_alpha = function(new_alpha) {
        if self.alpha == new_alpha {
            return self;
        }
        self.cache_is_dirty = true;
        self.alpha = min(new_alpha, self.max_alpha);
        return self;
    }

    static add_alpha = function(val) {
        return self.set_alpha(self.alpha + val);
    }

    static get_alpha = function() {
        return self.alpha;
    }

    static set_max_alpha = function(new_alpha) {
        if self.max_alpha == new_alpha {
            return self;
        }
        self.cache_is_dirty = true;
        self.max_alpha = new_alpha;
        if self.alpha > self.max_alpha {
            self.alpha = self.max_alpha;
        }
        return self;
    }

    static get_max_alpha = function() {
        return self.max_alpha;
    }

    static is_hovered = function() {
        //
        //
        //
        //
        //
        return self.in_hover;
    }

    static hover_duration = function() {
        return self.is_hovered() ? self.hover_frames : 0;
    }

    static is_pressed = function() {
        //
        //
        //
        //
        //
        return self.in_tap;
    }

    //
    static listen_for_hovers = function(boo=true) {
        self.listens_for_hovers = boo;
        self.run_logic |= boo;
        return self;
    }

    //
    static listen_for_taps = function(boo=true) {
        self.listens_for_hovers = boo;
        self.listens_for_taps = boo;
        self.run_logic |= boo;
        return self;
    }

    //
    //
    //
    static add_to_pilot = function(pilot, newline_after=false) {
        //
        self.pilot = pilot;
        self.pilot.add(self);
        if newline_after {
            self.pilot.request_newline();
        }
        return self;
    }

    //
    //
    //
    //
    static mouse_can_escape_tap = function(boo=true) {
        self.mouse_can_escape_tap_flag = boo;
        return self;
    }

    static set_tap_callback = function(func, arg_array, intentional_override=false) {
        if self.event_callbacks.tap != undefined && !intentional_override {
            warn("{AnchorNode}'s tap callback is being overwritten at {}!", self, debug_get_callstack(2)[1]);
        }
        self.listens_for_hovers = true;
        self.listens_for_taps = true;
        self.run_logic = true;
        self.event_callbacks.tap = {
            func: func,
            arg_array: arg_array ?? [],
        }
        return self;
    }

    static set_room_start_callback = function(func, arg_array, intentional_override=false) {
        if self.event_callbacks.room_start != undefined && !intentional_override {
            warn("{AnchorNode}'s room_start callback is being overwritten at {}!", self, debug_get_callstack(2)[1]);
        }
        self.event_callbacks.room_start = {
            func: func,
            arg_array: arg_array ?? [],
        }
        return self;
    }

    static set_think_callback = function(func, arg_array, intentional_override=false) {
        if self.event_callbacks.think != undefined && !intentional_override {
            warn("{AnchorNode}'s think callback is being overwritten at {}!", self, debug_get_callstack(2)[1]);
        }
        self.run_logic = true;
        self.event_callbacks.think = {
            func: func,
            arg_array: arg_array ?? [],
        }
        return self;
    }

    static set_gui_resize_callback = function(func, arg_array, intentional_override=false) {
        if self.event_callbacks.gui_resize != undefined && !intentional_override {
            warn("{AnchorNode}'s gui_resize callback is being overwritten at {}!", self, debug_get_callstack(2)[1]);
        }
        self.event_callbacks.gui_resize = {
            func: func,
            arg_array: arg_array ?? [],
        }
        return self;
    }

    static set_free_callback = function(func, arg_array, intentional_override=false) {
        if self.event_callbacks.free != undefined && !intentional_override {
            warn("{AnchorNode}'s free callback is being overwritten at {}!", self, debug_get_callstack(2)[1]);
        }
        self.event_callbacks.free = {
            func: func,
            arg_array: arg_array ?? [],
        }
        return self;
    }

    //
    //
    //
    //
    static set_unlocked = function(boo, personal=true) {
        self.safe_unlocked = personal ? boo : self.unlocked && boo;
        self.unlocked = personal ? boo : self.unlocked;
        if !self.safe_unlocked && ANCHOR.current_hovered_node == self {
            ANCHOR.release_hovered_node();
        }

        for (var i = 0, c = array_length(self.children); i < c; i++) {
            var child = self.children[i];
            if child.safe_unlocked != self.safe_unlocked {
                child.set_unlocked(self.safe_unlocked, false);
            }
        }
        return self;
    }

    static lock = function() {
        return self.set_unlocked(false);
    }

    static unlock = function() {
        return self.set_unlocked(true);
    }

    //
    static is_unlocked = function() {
        return self.safe_unlocked && self.safe_enabled;
    }

    static set_label = function(new_label) {
        self.label = new_label;
        return self;
    }

    static get_label = function() {
        return self.label;
    }

    static board_set = function(name, val) {
        self.blackboard.set(name, val);
        return self;
    }

    static board_add = function(name, val) {
        var new_value = self.board_get(name) + val;
        self.blackboard.set(name, new_value);
        return new_value;
    }

    static board_get = function(name) {
        return self.blackboard.get(name);
    }

    static board_try_take = function(name, def) {
        return self.blackboard.try_take(name, def);
    }

    static board_take = function(name) {
        return self.blackboard.take(name)
    }

    //
    //
    //
    static set_enabled = function(boo=true) {
        var enabled = self.get_enabled_unsafe();
        if enabled != boo {
            if boo {
                ANCHOR.enable_node(self);
            } else {
                ANCHOR.disable_node(self);
            }
        }
        return self;
    }

    //
    static enable = function() {
        self.set_enabled(true);
        return self;
    }

    //
    static disable = function() {
        self.set_enabled(false);
        return self;
    }

    //
    //
    //
    static get_enabled = function() {
        return self.safe_enabled;
    }

    //
    //
    //
    //
    //
    static get_enabled_unsafe = function() {
        return self.enabled;
    }

    static set_lut = function(sprite, index=1) {
        if self.type == NodeId.Canvas {
            crash("Anchor no longer supports luts on canvases! Apply your lut individually.");
        }
        self.lut_info.enabled = true;
        self.lut_info.index = index;
        self.lut_info.sprite = sprite;
        self.lut_info.texture = sprite;
        self.lut_info.uvs = sprite_get_uvs(sprite, 0);

        //
        assert_eq(sprite_get_height(sprite), 256.0, "{GmSprite} in {} was only {}", sprite, self, sprite_get_height(sprite));

        self.lut_info.slot_count = sprite_get_width(sprite);
        return self;
    }

    static disable_lut = function() {
        self.lut_info.enabled = false;
        return self;
    }

    //
    static mirror_node_lut = function(node) {
        //
        self.lut_info = node.lut_info;
        return self;
    }

    static set_lut_index = function(index) {
        if self.lut_info.index == index {
            return self;
        }
        assert(self.lut_info.enabled, "Cannot set the LUT index of a node not currently using a LUT!");
        self.cache_is_dirty = true;
        self.lut_info.index = index;
        return self;
    }

    static get_lut_index = function() {
        return self.lut_info.use_day_night_index ? ANCHOR.night_lut_index : self.lut_info.index;
    }

    static set_lut_speed = function(spd) {
        if self.lut_info.speed == spd {
            return self;
        }
        self.run_logic = true;
        assert(self.lut_info.enabled, "Cannot set the LUT index of a node not currently using a LUT!");
        self.lut_info.speed = spd;
        return self;
    }

    static set_tap_sound = function(snd) {
        self.tap_sound = snd;
        return self;
    }

    static enable_tap_repeating = function() {
        self.tap_repeating = true;
        return self;
    }

    static set_hover_sound = function(snd) {
        self.hover_sound = snd;
        return self;
    }

    static set_size_to_screen = function() {
        var true_size = ANCHOR.get_true_size();
        true_size.x = ceil(true_size.x);
        true_size.y = ceil(true_size.y);

        //
        //
        if true_size.x % 2 == 1 {
            true_size.x += 1;
        }
        if true_size.y % 2 == 1 {
            true_size.y += 1;
        }

        self
            .set_size(true_size)
            .set_gui_resize_callback(function() {
                var true_size = ANCHOR.get_true_size();
                true_size.x = ceil(true_size.x);
                true_size.y = ceil(true_size.y);
                //
                //
                if true_size.x % 2 == 1 {
                    true_size.x += 1;
                }
                if true_size.y % 2 == 1 {
                    true_size.y += 1;
                }
                self.set_size(true_size);
            })
        return self;
    }

    static set_scale_to_screen = function() {
        var true_size = ANCHOR.get_true_size();
        true_size.x = ceil(true_size.x);
        true_size.y = ceil(true_size.y);

        //
        //
        if true_size.x % 2 == 1 {
            true_size.x += 1;
        }
        if true_size.y % 2 == 1 {
            true_size.y += 1;
        }

        self
            .set_scale(true_size.x, true_size.y)
            .set_gui_resize_callback(function() {
                var true_size = ANCHOR.get_true_size();
                true_size.x = ceil(true_size.x);
                true_size.y = ceil(true_size.y);
                //
                //
                if true_size.x % 2 == 1 {
                    true_size.x += 1;
                }
                if true_size.y % 2 == 1 {
                    true_size.y += 1;
                }
                self.set_scale(true_size.x, true_size.y);
            })
        return self;
    }

    static set_size_to_minspec = function() {
        self.set_size(NORMAL_MINSPEC_WIDTH, NORMAL_MINSPEC_HEIGHT);
        return self;
    }

    static enable_day_night_lut = function() {
        self.set_lut(spr_ui_master_lut, 0);
        self.lut_info.use_day_night_index = true;
        return self;
    }

    static check_for_drag_start = function(drag_threshold=0, drag_on_press=false) {
        return
            self.blackboard.get("in_drag") != true
            && self.is_pressed()
            && ANCHOR.point_in_node(self, ANCHOR.last_mouse_press.x, ANCHOR.last_mouse_press.y)
            && (drag_on_press || point_distance(MOUSE_GUI_X, MOUSE_GUI_Y, ANCHOR.last_mouse_press.x, ANCHOR.last_mouse_press.y) > drag_threshold)
    }

    static in_drag = function(drag_threshold=0, drag_on_press=false) {
        var in_drag = self.blackboard.get_or_insert("in_drag", false);
        if in_drag && INPUT.released(InputId.LeftMouse) {
            in_drag = false;
            self.blackboard.take("drag_original_position");
        } else if self.check_for_drag_start(drag_threshold, drag_on_press) {
            in_drag = true;
            self.blackboard.set("drag_original_position", Vec2(self.get_x(), self.get_y()));
        }
        self.blackboard.set("in_drag", in_drag);
        return in_drag;
    }

    static get_position_with_drag_applied = function(drag_threshold=0) {
        if !self.in_drag(drag_threshold) {
            return Vec2(self.get_x(), self.get_y());
        }
        var pos = self.blackboard.get("drag_original_position");
        return Vec2(
            pos.x + MOUSE_GUI_X - ANCHOR.last_mouse_press.x,
            pos.y + MOUSE_GUI_Y - ANCHOR.last_mouse_press.y,
        );
    }

    //
    //
    //
    //
    //
    static display = function() {
        //
        if self.label != undefined {
            return self.label;
        }

        var prefix = "unknown";

        //
        for (var i = 0; i < ANCHOR.open_menus.count(); i++) {
            var menu = ANCHOR.open_menus.get(i);
            var names = struct_get_names(menu);
            for (var j = 0; j < array_length(names); j++) {
                if menu[$ names[j]] == self {
                    prefix = format("{}::{}", capitalize(menu_to_string(menu.type)), names[j]);
                }
            }
        }

        //
        var stack = self.creation_location();
        var out = "unknown";
        switch self.type {
            case NodeId.Text:
                prefix ??= "Text";
                var key = self.get_display_key();
                if key == undefined || string_pos("extra_local", key) != 0 {
                    key = self.text;
                }
                out = fmt("<'{}'>", key);
                break;
            case NodeId.Sprite:
                prefix ??= "Sprite";
                out = fmt("<{gm_sprite}>", self.sprite);
                break;
            default:
                out = fmt("{}", capitalize(node_id_to_string(self.type)));
                break;
        }

        return format("{}{}", prefix, out);
    }

    //
    static creation_location = function() {
        if self.spawn_callstack == undefined {
            return "n/a"
        };

        return self.spawn_callstack[3];
    }

    toString = function() {
        return self.display();
    }
}

function CanvasNode(parent, z, layer_override) : Node(parent, z, layer_override) constructor {
    type = NodeId.Canvas;
    children_are_dirty = true;
    locked = false;
    render_partial_info = {
        enabled: false,
        x: 0,
        y: 0,
        width: 0,
        height: 0,
    };

    //
    function set_render_partial(xx, yy, width, height) {
        self.cache_is_dirty = true;
        self.render_partial_info.enabled = true;
        self.render_partial_info.x = xx;
        self.render_partial_info.y = yy;
        self.render_partial_info.width = width;
        self.render_partial_info.height = height;
        return self;
    }
}

function TextNode(parent, z, layer_override) : Node(parent, z, layer_override) constructor {
    self.type = NodeId.Text;
    self.text_input_mode = AnchorTextInputMode.LocalKey;
    self.text_align = TextAlign.Left;
    self.local_key = undefined;
    self.text = "";
    self.display_text = "";
    self.font = ANCHOR.default_font;
    self.font_is_forced = false;
    self.text_style = undefined;
    self.line_height = undefined;
    self.max_width = undefined;
    self.max_height = undefined;
    self.max_characters = undefined;
    self.can_line_break = false;
    self.takes_input = false;
    self.cursor_timer = 0;
    self.strike_through_node = undefined;
    self.disallow_spillover = false;
    self.spawned_steam_keyboard = false;
    self.sprite_font = undefined;
    self.sprite_font_name = undefined;
    self.ghost_key = undefined;
    self.required_padding = 6;
    self.spillover_logged_text = undefined;
    self.backspace_info = {
        active: false,
        delay_timer: 0,
        delay_timer_max: 20,
        timer: 0
    }

    static set_text_style = function(pack) {
        self.text_style = pack;
        self.cache_is_dirty = true;
        self.font = TEXT_STYLES[$ pack][$ local_language()];
        return self;
    }

    static set_sprite_font = function(sprite_font_name) {
        self.sprite_font_name = sprite_font_name;
        self.sprite_font = SPRITE_FONTS[$ sprite_font_name];
        assert_neq(self.sprite_font, undefined, "SpriteFont `{}` does not exist", sprite_font_name);

        self.cache_is_dirty = true;

        return self;
    }

    static set_line_height = function(height) {
        if self.line_height == height {
            return self;
        }
        self.cache_is_dirty = true;
        self.line_height = height;
        return self;
    }

    static get_line_height = function() {
        return self.line_height;
    }

    static set_key = function(key) {
        if self.local_key == key && self.text_input_mode == AnchorTextInputMode.LocalKey {
            return self;
        }
        self.local_key = key;

        self.set_text(local_get(key));
        self.text_input_mode = AnchorTextInputMode.LocalKey;
        return self;
    }


    //
    //
    static set_ghost_key = function(key) {
        self.ghost_key = key;
        return self;
    }

    static get_local_key = function() {
        return self.local_key;
    }

    //
    //
    //
    static get_display_key = function() {
        if self.ghost_key != undefined {
            return self.ghost_key;
        }
        return self.text_input_mode == AnchorTextInputMode.LocalKey ? self.local_key : undefined;
    }

    static set_text = function(str) {
        if is_int64(str) || is_real(str) {
            str = num_display(str);
        } else if !is_string(str) {
            str = string(str);
        }
        if self.text == str {
            return self;
        }
        self.cache_is_dirty = true;
        self.text_input_mode = AnchorTextInputMode.Raw;
        self.text = str;
        self.update_display_text();
        return self;
    }



    static get_text = function() {
        return self.text;
    }

    static set_required_padding = function(val) {
        if self.required_padding == val {
            return self;
        }
        self.cache_is_dirty = true;
        self.required_padding = val;
        return self;
    }

    static infer_max_size = function(node) {
        node = node == undefined ? self.parent : node;
        return Vec2(
            node.get_width() - max(self.get_x() * 2, self.required_padding),
            node.get_height() - self.get_y() * 2,
        );
    }

    static get_max_size = function() {
        var size = self.infer_max_size();
        size.x = self.max_width ?? size.x;
        size.y = self.max_height ?? size.y;
        return size;
    }

    static prevent_spillover = function(boo=true) {
        self.disallow_spillover = boo;
        return self;
    }

    static measure = function() {
        if self.cache_is_dirty {
            self.update_display_text();
        }
        return Vec2(self.width, self.height);
    }

    //
    static update_display_text = function() {
        if self.max_characters != undefined {
            self.display_text = string_copy(self.text, 1, min(string_length(self.text), self.max_characters));
        } else if self.can_line_break {
            var max_size = self.get_max_size();
            var key_to_check = self.ghost_key ?? self.local_key;
            var force = key_to_check != undefined && !local_has_translation(local_language(), key_to_check);
            self.display_text = ANCHOR.reflow(self.text, max_size.x, self.font, force);
        } else {
            self.display_text = self.text;
        }
        var is_empty = self.display_text == "";

        if is_empty {
            self.display_text = " "; //
        }

        if self.sprite_font != undefined {
            if is_empty == false {
                self.width = sprite_font_width(self.display_text, self.sprite_font_name);
                self.height = sprite_get_height(self.sprite_font.sprite);
            }
        } else {
            //
            draw_set_font(self.font);

            self.width = string_width(self.display_text, self.line_height, I32_MAX);
            self.height = string_height(self.display_text, self.line_height, I32_MAX);
        }

        return self;
    }

    //
    //
    static check_spillover = function() {
        if !self.disallow_spillover || self.spillover_logged_text == self.text {
            return self;
        }
        var max_size = self.get_max_size();
        if max_size.x < self.width || max_size.y < self.height {
            self.spillover_logged_text = self.text;
            var source_menu = self.source_menu == undefined ? undefined : self.source_menu.type;
            var menu = TEST_SUITE_MENU_TARGET ?? source_menu;
            SPILLOVER_LOGS.push({
                node: self.display(),
                menu: menu == undefined ? "unknown" : menu_to_string(menu),
                max_size: max_size,
                my_size: Vec2(self.width, self.height),
            });
        }
        return self;
    }

    function lines() {
        self.update_display_text();
        return string_count("\n", self.display_text) + 1;
    }

    static set_takes_input = function(new_setting) {
        self.run_logic |= new_setting;
        ANCHOR.text_input_node = new_setting ? self : undefined;
        self.takes_input = new_setting;
        if !self.takes_input {
            stop_text_input();
            self.display_text = string_replace(self.display_text, "|", ""); //
            self.spawned_steam_keyboard = false;
            return self;
        }

        start_text_input();

        self.cursor_timer = 1;

        if steam_on_deck() || (steam_in_big_picture_mode() && ON_GAMEPAD) {
            self.spawned_steam_keyboard = steam_open_textbox();
        }
        return self;
    }

    static get_takes_input = function() {
        return self.takes_input;
    }

    static set_text_align = function(align) {
        if self.text_align == align {
            return self;
        }
        self.cache_is_dirty = true;
        self.text_align = align;
        return self;
    }

    static get_casing = function() {
        return self.casing;
    }

    static set_font = function(font) {
        self.font_is_forced = false;
        self.text_style = undefined;
        if self.font == font {
            return self;
        }
        self.cache_is_dirty = true;
        self.font = font;
        return self;
    }

    //
    //
    static force_font = function(font) {
        self.font_is_forced = true;
        self.text_style = undefined;
        if self.font == font {
            return self;
        }
        self.cache_is_dirty = true;
        self.font = font;
        return self;
    }

    static get_font = function() {
        return self.font;
    }

    static set_max_width = function(width) {
        if self.max_width != width {
            self.cache_is_dirty = true;
            self.max_width = width;
        }
        self.max_characters = undefined;
        self.allow_line_breaks();
        return self;
    }

    static set_max_height = function(height) {
        if self.max_height == height {
            return self;
        }
        self.cache_is_dirty = true;
        self.max_height = height;
        self.max_characters = undefined;
        return self;
    }

    static set_max_size = function(width, height) {
        self.set_max_width(width);
        self.set_max_height(height);
        return self;
    }

    static set_max_characters = function(count) {
        if self.max_characters == count {
            return self;
        }
        self.cache_is_dirty = true;
        self.max_width = undefined;
        self.max_height = undefined;
        self.max_characters = count;
        return self;
    }

    static get_max_width = function() {
        return self.max_width;
    }


    static get_max_height = function() {
        return self.max_height;
    }

    static allow_line_breaks = function(bool=true) {
        if self.can_line_break == bool {
            return self;
        }
        self.cache_is_dirty = true;
        self.can_line_break = bool;
        self.disallow_spillover &= bool;
        return self;
    }

    static get_can_line_break = function() {
        return self.can_line_break;
    }

    static show_text_zone = function() {
        var old = self.blackboard.try_take("zone");
        if old != undefined {
            ANCHOR.free_node(old);
        }

        var node = ANCHOR.nine_slice(self)
            .set_size(self.get_size())
            .set_sprite(spr_pixel_nine_slice)
            .set_color(c_red)
            .set_alpha(0.5);

        var line = ANCHOR.nine_slice(node)
            .set_size(self.get_max_width() ?? self.infer_max_size().x, 1)
            .set_sprite(spr_pixel_nine_slice)
            .set_color(c_green);

        line.set_think_callback(function(line) {
            line.set_alpha(ANCHOR.point_in_node(line, MOUSE_GUI_X, MOUSE_GUI_Y) ? 1 : 0);
        }, [line]);

        self.board_set("zone", node);

        return self;
    }

    //
    static strike_through = function() {
        self.run_logic = true;
        self.strike_through_node = ANCHOR.positional(self);
        self.strike_through_node.text_cache = undefined;
        self.strike_through_node.update = function() {
            if self.strike_through_node.text_cache != self.display_text {
                self.strike_through_node.text_cache = self.display_text;
                ANCHOR.free_children(self.strike_through_node);

                //
                //
                var lines = string_split(self.display_text, "\n");
                if array_is_empty(lines) {
                    lines = [self.display_text];
                }
                var line_height = font_line_height(self.get_font());
                for (var i = 0; i < array_length(lines); i++) {
                    var line = lines[i];
                    var width = string_width_font(line) + 3; //
                    var yy = (i * line_height) + (line_height / 2);
                    ANCHOR.nine_slice(self.strike_through_node)
                        .set_xy(-2, yy)
                        .set_sprite(spr_pixel_nine_slice)
                        .set_size(width, 1)
                        .mirror_node_lut(self)
                }
            }
        }

        return self;
    }
}

function TypewriterNode(parent, z, layer_override) : Node(parent, z, layer_override) constructor {
    type = NodeId.Typewriter;
    font = ANCHOR.default_font;
    text_style = undefined;
    line_height = 15;
    max_width = undefined;
    characters = List();
    counter = 0;
    pause = false;
    pause_timer = 0;
    speaker_sound_path = undefined;
    override_sound = undefined;
    ghost_key = undefined;

    static set_text_style = function(pack) {
        self.text_style = pack;
        self.cache_is_dirty = true;
        self.font = TEXT_STYLES[$ pack][$ local_language()];
        return self;
    }

    static set_ghost_key = function(key) {
        self.ghost_key = key;
        return self;
    }

    static is_resting = function() {
        return self.counter == self.characters.count() - 1;
    }

    static set_text = function(str) {
        if !is_string(str) {
            str = string(str);
        }
        self.cache_is_dirty = true;
        self.text = str;
        return self;
    }

    static set_font = function(font) {
        self.cache_is_dirty = true;
        self.text_style = undefined;
        self.font = font;
        return self;
    }

    static set_max_width = function(width) {
        if self.max_width == width {
            return self;
        }
        self.cache_is_dirty = true;
        self.max_width = width;
        return self;
    }

    static get_max_width = function() {
        return self.max_width;
    }

    static set_speaker_sound_path = function(path) {
        self.speaker_sound_path = path;
        return self;
    }

    static set_override_sound = function(override_sound) {
        self.override_sound = override_sound;
        return self;
    }

    static make_character = function(char, linebreak=false, gold=false, purple=false, pink=false, jitter=false, shake=false) {
        return {
            char: char,
            gold: gold,
            purple: purple,
            pink: pink,
            jitter: jitter,
            shake: shake,
            linebreak: linebreak,
        };
    }

    static play = function(input_text) {
        self.cache_is_dirty = true;
        self.counter = 0;
        self.characters.clear();
        draw_set_font(self.font);
        input_text = filter_text_for_textbox(input_text);
        var str_len = string_length(input_text);
        var special_chars = fiddle_get("ui/text_markers/special_characters");

        var plain_text = "";
        for (var i = 1; i <= str_len; i++) {
            var char = string_char_at(input_text, i);
            if !array_has(special_chars, char) {
                plain_text += char;
            }
        }
        var break_positions = HashSetFromArray(line_break_positions(plain_text));
        var line_width = 0; //
        var pending_width = 0; //
        var line_start = 0; //
        var pending_start = 0; //
        var plain_index = 0; //
        var can_break = local_get_info(LocalInfoRequest.AutomaticLinebreaks)
            || !local_has_translation(local_language(), self.ghost_key);
        var inside_jitter = false;
        var inside_gold = false;
        var inside_purple = false;
        var inside_pink = false;
        for (var i = 1; i <= str_len; i++) {
            var char = string_char_at(input_text, i);
            var shake = false;
            if array_has(special_chars, char) {
                switch char {
                    case "#":
                        inside_jitter = !inside_jitter;
                        break;
                    case "@":
                        shake = true;
                        break;
                    case "$":
                        inside_gold = !inside_gold
                        break;
                    case "^":
                        inside_purple = !inside_purple;
                        break;
                    case "=":
                        inside_pink = !inside_pink;
                        break;
                    default: impossible("unknown special character: {}", char)
                }
                continue;
            }
            self.characters.push(self.make_character(char, false, inside_gold, inside_purple, inside_pink, inside_jitter, shake));

            plain_index += 1;

            if char == "\n" {
                self.characters.last().linebreak = true;
                line_width = 0;
                pending_width = 0;
                line_start = self.characters.count();
                pending_start = line_start;
                continue;
            }

            pending_width += char == " " ? 4 : string_width(char);
            if break_positions.contains(plain_index) {
                line_width += pending_width;
                pending_width = 0;
                pending_start = self.characters.count();
            }

            if can_break && line_width + pending_width > self.max_width {
                var break_marker = self.make_character(" ", true);
                if pending_start == line_start || pending_start == self.characters.count() {
                    self.characters.push(break_marker);
                    pending_start = self.characters.count();
                    pending_width = 0;
                } else {
                    //
                    //
                    //
                    self.characters.insert(break_marker, pending_start);
                    pending_start += 1;
                }

                line_width = 0;
                line_start = pending_start;
            }
        }
    }
}

function SpriteNode(parent, z, layer_override) : Node(parent, z, layer_override) constructor {
    self.type = NodeId.Sprite;
    self.sprite = spr_nothing_nineslice;
    self.index = 0;
    self.speed = 0;
    self.event_callbacks.animation_end = undefined;
    self.frame_count = 1;
    self.is_nine_slice = false;
    self.text_label = undefined;
    self.glyph_node = undefined;
    self.scale_x = 1;
    self.scale_y = 1;
    self.spr_width = 0;
    self.spr_height = 0;
    self.outline_sprite = undefined;
    self.outline_color = c_white;
    self.event_callbacks.selected_getter = {
        func: function() {},
        arg_array: [],
    }

    //
    //
    //
    self.enabled_sprite = undefined;
    self.pressed_sprite = undefined;
    self.hovered_sprite = undefined;
    self.hovered_untappable_sprite = undefined;
    self.locked_sprite = undefined;
    self.selected_sprite = undefined;
    self.key_sprite_target = undefined;

    //
    static render_as_nine_slice = function(boo=true) {
        self.is_nine_slice = boo;
        self.cache_is_dirty = true;
        return self;
    }

    //
    static set_sprite = function(new_sprite) {
        if new_sprite == self.sprite {
            return self;
        }
        self.cache_is_dirty = true;
        self.sprite = new_sprite;
        self.index = 0;
        self.frame_count = sprite_get_number(self.sprite);
        self.spr_width = sprite_get_width(self.sprite);
        self.spr_height = sprite_get_height(self.sprite);
        if !self.is_nine_slice {
            self.width = self.spr_width;
            self.height = self.spr_height;
        } else {
            self.frame_count /= 9;
        }
        return self;
    }

    static get_sprite = function() {
        return self.sprite;
    }

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
    static set_sprites_from_key = function(key) {
        //
        var sprites = load_button_sprites(key);
        self.key_sprite_target = self;
        self.enabled_sprite = sprites.enabled_sprite;
        self.pressed_sprite = sprites.pressed_sprite;
        self.locked_sprite = sprites.locked_sprite;
        self.selected_sprite = sprites.selected_sprite;
        self.hovered_sprite = sprites.hovered_sprite;
        self.hovered_untappable_sprite = sprites.hovered_untappable_sprite;
        self.set_sprite(self.enabled_sprite, true);
        return self;
    }

    //
    //
    static set_key_sprite_target = function(node) {
        self.key_sprite_target = node;
        self.run_logic = true;
        return self;
    }

    //
    //
    static set_enabled_sprite = function(new_sprite) {
        self.enabled_sprite = new_sprite;
        return self;
    }

    //
    //
    static set_pressed_sprite = function(new_sprite) {
        self.pressed_sprite = new_sprite;
        return self;
    }

    //
    //
    static set_hovered_sprite = function(new_sprite) {
        self.hovered_sprite = new_sprite;
        return self;
    }

    //
    //
    static set_hovered_untappable_sprite = function(new_sprite) {
        self.hovered_untappable_sprite = new_sprite;
        return self;
    }

    //
    static set_soft_locked = function(boo=true) {
        self.soft_locked = boo;
        return self;
    }

    //
    //
    static set_locked_sprite = function(new_sprite) {
        self.locked_sprite = new_sprite;
        return self;
    }

    //
    //
    static set_selected_sprite = function(new_sprite) {
        self.selected_sprite = new_sprite;
        return self;
    }

    static set_outline_sprite = function(outline_sprite) {
        if self.outline_sprite == outline_sprite {
            return self;
        }
        self.outline_sprite = outline_sprite;
        return self;
    }

    static set_outline_color = function(col) {
        self.outline_color = col;
        return self;
    }

    static is_outlined = function() {
        return self.outline_sprite != undefined;
    }

    static set_index = function(index) {
        index = wrap(index, self.frame_count);
        if index == self.index {
            return self;
        }
        self.cache_is_dirty = true;
        self.index = index;
        return self;
    }

    static get_index = function() {
        return floor(self.index);
    }

    static set_speed = function(speed) {
        if speed == self.speed {
            return self;
        }
        self.cache_is_dirty = true;
        self.speed = speed;
        if self.speed > 0 {
            self.run_logic = true;
        }
        return self;
    }

    static get_speed = function() {
        return self.speed;
    }

    static set_scale = function(width, height) {
        self.scale_x = width;
        self.scale_y = height;
        return self;
    }

    static set_scale_x = function(width) {
        self.scale_x = width;
        return self;
    }

    static set_scale_y = function(height) {
        self.scale_y = height;
        return self;
    }

    static get_scale = function() {
        return {
            x: self.scale_x,
            y: self.scale_y,
        }
    }

    static get_scale_x = function() {
        return self.scale_x;
    }

    static get_scale_y = function() {
        return self.scale_y;
    }

    static get_index_inc = function() {
        //
        //
        //
        return 0.1666666666 * self.speed;
    }

    static at_animation_end = function() {
        var spd = self.get_index_inc();
        if sign(spd) == 1 {
            return self.index + spd >= self.frame_count;
        } else {
            return self.index + spd <= 0;
        }
    }

    static set_animation_end_callback = function(func, arg_array, intentional_override=false) {
        if self.event_callbacks.animation_end != undefined && !intentional_override {
            warn("{AnchorNode}'s animation_end callback is being overwritten at {}!", self, debug_get_callstack(2)[1]);
        }
        self.event_callbacks.animation_end = {
            func: func,
            arg_array: arg_array ?? [],
        }
        return self;
    }

    //
    //
    static set_selected_getter = function(func, arg_array) {
        self.event_callbacks.selected_getter = {
            func: func,
            arg_array: arg_array ?? [],
        }
        return self;
    }

    //
    static is_selected = function() {
        var getter = self.event_callbacks.selected_getter;
        return getter == undefined
            ? false
            : function_execute_alt(getter.func, getter.arg_array);
    }

    //
    //
    //
    //
    //
    //
    //
    //
    static add_glyph = function(input_id, specific_control=undefined, left_corner=false) {
        var display = get_display_for_input_id(input_id);
        var glyph = ANCHOR.sprite(self, self.get_z() - 10);
        var horz_align = left_corner ? Align.LeftIn : Align.RightIn;
        var offset = left_corner ? Vec2(-6, 1) : Vec2(6, 1);
        glyph.previous_input_type = INPUT.active_input_type;
        glyph.previous_input_id = input_id;
        glyph.previous_binding = BINDINGS.get_primary_binding(input_id);
        glyph.trigger_taps = true;
        glyph
            .set_sprite(display.small_sprite)
            .set_index(display.index)
            .set_align(horz_align, Align.BottomIn)
            .set_xy(offset.x, offset.y)
            .board_set("input_id", input_id)
            .board_set("specific_control", specific_control)
            .set_think_callback(function(glyph) {
                //
                var input_id = glyph.board_get("input_id");
                var specific_control = glyph.board_get("specific_control");
                var in_valid_control_mode = matches(specific_control, undefined, ANCHOR.control_mode);
                var binding = BINDINGS.get_primary_binding(input_id);
                var is_visible = binding != undefined
                    && self.is_unlocked()
                    && in_valid_control_mode;
                glyph.set_alpha(is_visible ? 1 : 0);

                if glyph.previous_input_type != INPUT.active_input_type
                    || input_id != glyph.previous_input_id
                    || binding != glyph.previous_binding
                {
                    glyph.previous_input_type = INPUT.active_input_type;
                    glyph.previous_input_id = input_id;
                    glyph.previous_binding = binding;

                    var display = get_display_for_input_id(input_id);
                    glyph.set_sprite(display.small_sprite);
                    glyph.set_index(display.index);
                }

                //
                if glyph.trigger_taps
                    && in_valid_control_mode
                    && self.is_unlocked()
                    && INPUT.take_press(input_id)
                {
                    ANCHOR.tap_node(self);
                }

            }, [glyph]);
        self.glyph_node = glyph;
        return self;
    }

    //
    static remove_glyph = function() {
        if self.glyph_node != undefined {
            ANCHOR.free_node(self.glyph_node);
            self.glyph_node = undefined;
        }
        return self;
    }

    //
    //
    //
    //
    //
    static add_text_label = function(key, lut_sprite=COMMON_LUT, enabled_lut_index=1, pressed_lut_index, hovered_lut_index, disabled_lut_index, selected_lut_index, font) {

        //
        pressed_lut_index = pressed_lut_index == undefined ? enabled_lut_index : pressed_lut_index;
        hovered_lut_index = hovered_lut_index == undefined ? enabled_lut_index : hovered_lut_index;
        disabled_lut_index = disabled_lut_index == undefined ? enabled_lut_index : disabled_lut_index;
        selected_lut_index = selected_lut_index == undefined ? enabled_lut_index : selected_lut_index;

        self.text_label = ANCHOR.text(self)
            .set_lut(lut_sprite, 0)
            .set_align(Align.Center, Align.Middle)
            .allow_line_breaks()
            .prevent_spillover()

        if font != undefined {
            self.text_label.set_font(font);
        }

        self.text_label.set_key(key);

        self.text_label.update = method(self.text_label, function() {
            if !self.target.unlocked || self.target.soft_locked {
                self.set_alpha(0.5);
                self.set_lut_index(self.disabled_lut);
            } else {
                self.set_alpha(1);
                if self.target.in_tap {
                    self.set_lut_index(self.pressed_lut);
                } else if self.target.in_hover {
                    self.set_lut_index(self.hovered_lut);
                } else if self.target.is_selected() {
                    self.set_lut_index(self.selected_lut);
                } else {
                    self.set_lut_index(self.enabled_lut);
                }
            }
        });

        self.text_label.selected_lut = selected_lut_index;
        self.text_label.enabled_lut = enabled_lut_index;
        self.text_label.hovered_lut = hovered_lut_index;
        self.text_label.pressed_lut = pressed_lut_index;
        self.text_label.disabled_lut = disabled_lut_index;
        self.text_label.target = self;

        //
        //
        self.text_label.retarget = method(self.text_label, function(node) {
            self.target.text_label = undefined;
            self.target = node;
            node.text_label = self;
            return self;
        });
        return self;
    }

    static add_hover_outline = function(tappable_sprite=spr_ui_button_hover_outline) {
        self.hover_outline = ANCHOR.nine_slice(self)
            .set_align(Align.Center, Align.Middle)
            .set_sprite(tappable_sprite)
            .set_speed(1)
            .disable()
            .set_think_callback(function() {
                self.hover_outline.set_size(self.width + 4, self.height + 4)
            })
        return self;
    }
}

//
//
function CustomNode(parent, z, layer_override) : Node(parent, z, layer_override) constructor {
    type = NodeId.Custom;
    event_callbacks.render = undefined;

    static set_render_callback = function(func, arg_array, intentional_override=false) {
        if self.event_callbacks.render != undefined && !intentional_override {
            warn("{AnchorNode}'s render callback is being overwritten at {}!", self, debug_get_callstack(2)[1]);
        }
        self.event_callbacks.render = {
            func: func,
            arg_array: arg_array ?? [],
        }
        return self;
    }
}

//
function PositionalNode(parent, z, layer_override) : Node(parent, z, layer_override) constructor {
    type = NodeId.Positional;

    //
    //
    static preview = function(color=c_red) {
        var old = self.blackboard.try_take("preview");
        if old != undefined {
            ANCHOR.free_node(old);
        }

        var node = ANCHOR.nine_slice(self)
            .set_size(self.get_size())
            .set_sprite(spr_pixel_nine_slice)
            .set_color(color)
            .set_alpha(0.5);

        self.board_set("preview", node);

        return self;
    }

    //
    //
    //
    static set_width_for_nodes = function(nodes) {
        var width = 0;
        for (var i = 0; i < array_length(nodes); i++) {
            var node = nodes[i];
            width += node.get_x() + node.get_width();
        }
        self.set_width(width);
        return self;
    }
}
