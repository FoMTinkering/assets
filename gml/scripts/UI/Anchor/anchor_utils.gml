#macro CANNOT_AFFORD_TEXT_COLOR make_color_rgb(255, 99, 111)
#macro FADE_SPEED 15
#macro UI_FADE_ALPHA 0.5
#macro DEFAULT_LINE_HEIGHT fiddle_get("ui/misc/default_line_height")
#macro DEFAULT_ELEMENT_HEIGHT fiddle_get("ui/misc/default_element_height")
#macro TEXT_CURSOR_BLINK_INTERVAL 30

#macro COMMON_LUT spr_ui_generic_font_lut

#macro COMMON_BUTTON_HEIGHT local_get_info(LocalInfoRequest.CommonButtonHeight)

#macro ACTIVE_ROOM_TITLE global.__active_room_title
ACTIVE_ROOM_TITLE = undefined;

//
#macro PUNCTUATION_CHARS global.__punctuation_chars
PUNCTUATION_CHARS = [
    ".",
    ",",
    "!",
    "?",
    ";",
    ":",
    "-",
    "—",
    "–",
    "…",
    "。",
    "、",
    "！",
    "？",
    "；",
    "：",
    "，",
    "．",
    "·",
    "・",
    "¡",
    "¿",
    "«",
    "»",
    "‹",
    "›",
    "「",
    "」",
    "『",
    "』",
    "（",
    "）",
    "［",
    "］",
    "【",
    "】",
    "｛",
    "｝",
    "〈",
    "〉",
    "《",
    "》",
    "·",
    "ㆍ",
]

enum CommonLutIndex {
    Source,
    Standard,
    Header,
    Green,
    Blue,
    Red,
    Dark,
    BlackOnYellow,
    BlackOnBeige,
    Spring,
    Summer,
    Fall,
    Winter,
    WhitePureBlack,
    WhiteOnRed,
    WhiteOnGreen,
    DarkAlt,
    DarkPurple,
    Gray,
    BlackOnGold,
    BlackOnRed,
}

enum Align {
    TopIn,
    TopOut,
    Middle,
    BottomIn,
    BottomOut,
    LeftIn,
    LeftOut,
    Center,
    RightIn,
    RightOut
}

enum TextAlign {
    Top,
    Middle,
    Bottom,
    Left,
    Center,
    Right,
}

enum AnchorTextInputMode {
    LocalKey,
    Raw,
    LEN
}

enum AnchorControl {
    Point,
    Directional,
}

enum AnchorLayer {
    WorldSpace,
    Hud,
    Standard,
    ScreenFader,
    AboveFader,
    Popup,
    Debug,

    LEN,
}

//
function menu_is_hud(menu) {
    switch menu {
        case Menu.Toolbar:
        case Menu.InfoHud:
        case Menu.Vitals:
        case Menu.Mines:
            return true;
        default: return false;
    }
}

function request_hud_show() {
    HUD_TARGET = true;
    for (var i = 0; i < Menu.LEN; i++) {
        if menu_is_hud(i) {
            var menu = ANCHOR.get_menu(i);
            if menu != undefined {
                menu.request_show();
            }
        }
    }
}

function request_hud_hide() {
    HUD_TARGET = false;
    stop_room_title();
    for (var i = 0; i < Menu.LEN; i++) {
        if menu_is_hud(i) {
            var menu = ANCHOR.get_menu(i);
            if menu != undefined {
                menu.request_hide();
            }
        }
    }
}

global.__hud_target = undefined;
#macro HUD_TARGET global.__hud_target

function hud_should_show() {
    if MIST.is_running() || ARI.end_of_day_status != undefined {
        return false;
    }

    for (var i = 0, c = ANCHOR.open_menus.count(); i < c; i++) {
        var menu = ANCHOR.open_menus.get(i);
        if menu.data.hides_hud {
            return false;
        }
    }

    return true;
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
//
//
//
//
function process_node_alpha(node, parent) {
    node.cache_alpha = node.alpha * parent.cache_alpha / parent.max_alpha;
}

function process_node_position(node, parent) {
    var x_value = node.x + parent.child_offset.x;
    var y_value = node.y + parent.child_offset.y;
    switch node.horz_align {
        case Align.LeftIn:
            node.cache_x =
                round(
                    x_value
                    + parent.cache_x
                );
            break;
        case Align.LeftOut:
            node.cache_x =
                round(
                    x_value
                    + parent.cache_x
                ) - node.width;
            break;
        case Align.Center:
            node.cache_x =
                round(
                    x_value
                    + parent.cache_x
                    + floor(((parent.width - node.width) / 2) + 0.5)
                );
            break;
        case Align.RightIn:
            node.cache_x =
                round(
                    x_value
                    + parent.cache_x
                    + parent.width
                    - node.width
                );
            break;
        case Align.RightOut:
            node.cache_x =
                round(
                    x_value
                    + parent.cache_x
                    + parent.width
                );
            break;
        default: impossible("Unexpected horizontal align on {AnchorNode}: {Align}", node, node.horz_align);
    }

    switch node.vert_align {
        case Align.TopIn:
            node.cache_y =
                round(
                    y_value
                    + parent.cache_y
                );
            break;
        case Align.TopOut:
            node.cache_y =
                round(
                    y_value
                    + parent.cache_y
                ) - node.height;
            break;
        case Align.Middle:
            node.cache_y =
                round(
                    y_value
                    + parent.cache_y
                    + floor(((parent.height - node.height) / 2) + 0.5)
                );
            break;
        case Align.BottomIn:
            node.cache_y =
                round(
                    y_value
                    + parent.cache_y
                    + parent.height
                    - node.height
                );
            break;
        case Align.BottomOut:
            node.cache_y =
                round(
                    y_value
                    + parent.cache_y
                    + parent.height
                );
            break;
        default: impossible("Unexpected vertical align on {AnchorNode}: {Align}", node, node.vert_align);
    }
}

function process_node_bbox(node) {
    node.cache_bbox_left = node.cache_x;
    node.cache_bbox_top = node.cache_y;
    node.cache_bbox_right = node.cache_x + node.width;
    node.cache_bbox_bottom = node.cache_y + node.height;

    if node.bbox_offset != undefined {
        node.cache_bbox_left += node.bbox_offset.x1;
        node.cache_bbox_top += node.bbox_offset.y1;
        node.cache_bbox_right += node.bbox_offset.x2;
        node.cache_bbox_bottom += node.bbox_offset.y2;
    }
}

function process_node_layer(node) {
    if node.cache_layer != node.layer {
        //
        var queue_list = ANCHOR.render_queues[node.cache_layer][node.type];
        if queue_list != undefined {
            var pos = ds_list_find_index(queue_list, node);
            if pos != -1 {
                ds_list_delete(queue_list, pos);
            }
        }

        node.cache_layer = node.layer;
        var queue_list = self.render_queues[node.cache_layer][node.type];
        if queue_list != undefined {
            ds_list_add(queue_list, node);
        }
    }
}

//
function process_node_dirty_child(node) {
    for (var i = 0, c = array_length(node.children); i < c; i++) {
        node.children[i].cache_is_dirty = true;
    }
    node.cache_is_dirty = false;
}

//
//
function centered_positions(len, width, padding=0) {
    var half = (len / 2) - 0.5;
    var positions = array_create(len)
    var n = -(padding + width) * half;
    for (var i = 0; i < len; i++) {
        positions[i] = floor(n + (padding + width) * i);
    }
    return positions;
}

//
function get_item_tag_visuals(tag) {
    var visuals = fiddle_get("ui/misc/generic_item_visuals");
    for (var i = 0; i < array_length(visuals); i++) {
        var data = visuals[i];
        if data.tag == tag {
            return {
                sprite: string_to_asset(data.sprite),
                key: data.key,
            }
        }
    }
    return undefined;
}

//
//

function listing_icon(element) {
    switch element.type {
        case ListingType.Item: return element.item.get_ui_icon();
        case ListingType.Gold: return spr_ui_item_currency;
        case ListingType.Custom: return element.icon;
        default: impossible("Unexpected ListingType: {ListingType}", element.type);
    }
}

function listing_sub_icon(element) {
    if element.type == ListingType.Item {
        return element.sub_icon;
    } else {
        return undefined;
    }
}

function listing_label(element) {
    switch element.type {
        case ListingType.Item: return element.item.get_display_name();
        case ListingType.Gold: return local_get("misc_local/tesserae");
        case ListingType.Custom: return local_get(element.name);
        default: impossible("Unexpected ListingType: {ListingType}", element.type);
    }
}

function listing_count_fulfilled(element) {
    switch element.type {
        case ListingType.Item: return element.inventory.item_id_quantity(element.item.item_id)
        case ListingType.Gold: return ARI.get_gold();
        case ListingType.Custom: return element.owned_by_ari;
        default: impossible("Unexpected ListingType: {ListingType}", element.type);
    }
}

function can_fulfill_listing(element) {
    if element.amount == undefined {
        return true;
    }
    return element.amount <= listing_count_fulfilled(element);
}

function listing_count_text(element, compare_with_ari=true) {
    if element.amount == undefined {
        return listing_count_fulfilled(element);
    } else {
        return compare_with_ari ? format("{}/{}", listing_count_fulfilled(element), element.amount) : element.amount;
    }
}

enum ListingType {
    Item,
    ItemTag,
    Gold,
    Essence,
    Custom,
}

function ListingFactory() constructor {
    static Item = function(item, inventory, amount=1, sub_icon) {
        item = is_struct(item) ? item : new LiveItem(item);
        return {
            type: ListingType.Item,
            item: item,
            amount: amount,
            inventory: inventory,
            sub_icon: sub_icon,
        }
    }

    static ItemTag = function(tag, amount) {
        return {
            type: ListingType.ItemTag,
            tag: tag,
            amount: amount,
        }
    }

    static Gold = function(amount) {
        return {
            type: ListingType.Gold,
            amount: amount,
        }
    }
    static Custom = function(icon, name, amount, owned_by_ari) {
        return {
            type: ListingType.Custom,
            icon: icon,
            name: name,
            amount: amount,
            owned_by_ari: owned_by_ari,
        }
    }
}

#macro Listing global.__listing_factory
Listing = new ListingFactory();

//
//
function create_options_popup(title_key, list, formatter, setter, pilot, columns=2) {
    var popup = popup_creator(title_key);
    popup.use_pilot(false); //
    pilot = pilot == undefined ? popup.new_pilot() : pilot;
    var padding = 8;
    var rows = ceil(list.count() / columns);

    var button_width = list.fold(80, function(a, b, formatter) {
        var width = string_width_font(formatter(b)) + 10;
        return max(a, width);
    }, [formatter])

    var button_height = list.fold(COMMON_BUTTON_HEIGHT, function(a, b, formatter, wrap_width) {
        var height = ANCHOR.text_height(formatter(b), wrap_width) + 6;
        return max(a, height);
    }, [formatter, button_width - 6]);

    var button_size = Vec2(button_width, button_height);
    var padding_from_buttons = Vec2(padding * (columns - 1), padding * (rows - 1));
    var popup_size = Vec2(
        (button_size.x * columns) + padding_from_buttons.x + (padding * 2),
        (button_size.y * rows) + padding_from_buttons.y + (padding * 3) + popup.header.get_height(),
    );
    popup_size.x = max(popup_size.x, popup.backplate.get_width());
    popup.backplate.set_size(popup_size);

    var single_column = columns == 1;
    var pos = Vec2(single_column ? 0 : padding, popup.header.get_height() + 16);
    var horz_align = single_column ? Align.Center : Align.LeftIn;
    for (var i = 0; i < list.count(); i++) {
        var item = list.get(i);
        var button_label = ANCHOR.wrap_for_local(formatter(item));
        popup.create_button(
                button_label,
                function(setter, item) {
                    setter(item);
                    save_settings();
                },
                [setter, item],
                undefined,
                undefined,
                false,
            )
            .set_size(button_size)
            .set_xy(pos.x, pos.y)
            .set_align(horz_align, Align.TopIn)
            .add_to_pilot(pilot)
            .remove_glyph()

        if single_column || i mod columns == 1 {
            pilot.request_newline();
            pos.y += button_size.y + padding;
            if i == list.count() - 1 {
                horz_align = Align.Center;
                pos.x = 0;
            } else if !single_column {
                horz_align = Align.LeftIn;
                pos.x = padding;
            }
        } else {
            horz_align = Align.RightIn;
            pos.x = -padding;
        }
    }
    popup.spawn();
    ANCHOR.set_active_pilot(pilot);
    return popup;
}

function wavy_text(parent, key, lut, lut_index=1, period_multip=2) {
    static PADDING = 1;
    var local = local_get(key);
    var len = string_length(local);
    draw_set_font(ANCHOR.get_text_font());
    var width = string_width(local) + PADDING * (len - 2);

    var root = ANCHOR.positional(parent)
        .set_size(width, 1)

    var xx = 0;
    root.chars = List();
    for (var i = 0; i < len; i++) {
        var char = string_char_at(local, i + 1);

        var node = ANCHOR.text(root)
            .set_text(char)
            .set_align(Align.LeftIn, Align.Middle)
            .set_x(xx)
            .set_lut(lut, lut_index)

        node.set_think_callback(function(node, i, period_multip) {
            var amplitude = (-current_time() / 150) - 50 * i;
            node.set_y(sin(amplitude) * period_multip);
        }, [node, i, period_multip])

        xx += string_width(char) + PADDING;

        root.chars.push(node);
    }

    return root;
}

function rainbow_text(parent, key) {

    var root = wavy_text(parent, key, spr_ui_renown_rainbow_font_lut);

    for (var i = 0; i < root.chars.count(); i++) {
        var node = root.chars.get(i);
        node.set_lut_index(i + 1);
    }

    root.set_think_callback(function(root) {
        static COLUMNS = sprite_get_width(spr_ui_renown_rainbow_font_lut) - 1;
        for (var i = 0; i < root.chars.count(); i++) {
            var node = root.chars.get(i);
            var index = node.get_lut_index();
            index = wrap(index + 1, COLUMNS, 1);
            node.set_lut_index(index);
        }

    }, [root])

    return root;
}

function PressAndHoldReader(inputs, len) constructor {
    self.inputs = is_array(inputs) ? inputs : [inputs];
    self.hold_checks = array_create(InputId.LEN, undefined);
    self.pressed = array_create(InputId.LEN, false);
    self.tap_on_press_flag = true;
    self.len = len == undefined ? fiddle_get("ui/misc/holding/start") : len;
    self.period = fiddle_get("ui/misc/holding/period");

    //
    //
    function tap_on_press(boo=true) {
        self.tap_on_press_flag = boo;
        return self;
    }

    //
    function disable_input_repetition() {
        self.period = I32_MAX;
        return self;
    }

    function process() {
        var any_pressed = false;
        var l = array_length(self.inputs);
        for (var i = 0; i < l; i++) {
            var pressed = false;
            var input = self.inputs[i];
            if INPUT.check(input) {
                var hold = self.hold_checks[input];
                if hold == undefined {
                    pressed = self.tap_on_press_flag;
                    any_pressed = pressed;
                    self.hold_checks[input] = TICK;
                } else {
                    var duration = TICK - hold;
                    if duration >= self.len && (duration - self.len) % self.period == 0 {
                        pressed = true;
                        any_pressed = true;
                    }
                }
            } else {
                self.hold_checks[input] = undefined;
            }
            self.pressed[input] = pressed;
        }
        return any_pressed;
    }
}


//
function common_slice(parent, width=22, height=22, alt=false) {
    var node = ANCHOR.nine_slice(parent);
    node.set_size(width, height);
    node.enabled_sprite = alt ? spr_ui_generic_box_alt : spr_ui_generic_box_main;
    node.locked_sprite = spr_ui_generic_box_locked;
    node.hovered_sprite = spr_ui_generic_box_hovered;
    node.hovered_untappable_sprite = spr_ui_generic_box_hovered_untappable;
    node.tapped_sprite = spr_ui_generic_box_tapped;
    node.pressed_sprite = spr_ui_generic_box_selected;
    node.selected_sprite = spr_ui_generic_box_selected;
    node.key_sprite_target = node;
    node.run_logic = true;
    node.set_sprite(node.enabled_sprite);
    return node;
}

#macro SHOW_MINUTES_ON_UI global.__show_minutes_on_hud
SHOW_MINUTES_ON_UI = false;

function TimeWidget(parent, xx, yy, horz_align, vert_align, forced_time) constructor {
    self.forced_time = forced_time;

    function update() {
        var time = self.forced_time ?? CLOCK.time;
        var hour = get_hours(time);
        var minutes = SHOW_MINUTES_ON_UI ? get_minutes(time) : (get_minutes(time) div 10) * 10;

        var am_pm_sprite = local_language() == "zh-Hans"
            ? spr_ui_hud_font_daytime_amppm_cn
            : spr_ui_hud_font_daytime_amppm;

        self.time_text_minutes.set_index(minutes);
        var xmod = 0;
        if !SETTINGS.get("twenty_four_hour_clock") {
            var is_pm;
            if hour == 12 {
                is_pm = true;
            } else if hour == 0 {
                hour = 12;
                is_pm = false;
            } else if hour >= 12 && hour <= 23 {
                hour -= 12;
                is_pm = true;
            } else {
                is_pm = false;
            }
            if is_pm {
                self.time_am_pm.set_index(1);
            } else {
                self.time_am_pm.set_index(0);
            }
            self.time_am_pm.set_sprite(am_pm_sprite);
        } else {
            xmod = 11;
            self.time_am_pm.set_sprite(spr_nothing);
        }

        self.time_text_hours.set_index(hour);
        self.time_text_minutes.set_x(-22 + xmod);

        var base_x = self.time_root.board_get("base_x");
        self.time_text_hours.set_x(-21);
        if string_length(string(hour)) == 2 {
            self.time_root.set_x(base_x + 5);
        } else {
            self.time_root.set_x(base_x + 2);
        }
    }

    function get_width() {
        return self.time_root.get_width()
            + self.time_text_minutes.get_width()
            //
            + self.time_colon.get_width()
            //
            + self.time_text_hours.get_width()
            //
    }

    var modifier = 0;
    var am_pm_sprite = spr_ui_hud_font_daytime_amppm;
    if local_language() == "zh-Hans" {
        modifier = -3;
        am_pm_sprite = spr_ui_hud_font_daytime_amppm_cn;
    }

    self.time_root = ANCHOR.positional(parent)
        .set_xy(xx + modifier, yy)
        .set_size(sprite_get_width(am_pm_sprite), sprite_get_height(am_pm_sprite))
        .set_align(horz_align, vert_align)
        .board_set("base_x", xx)

    self.time_am_pm = ANCHOR.sprite(self.time_root)
        .set_sprite(am_pm_sprite)
        .set_y(1)

    self.time_text_minutes = ANCHOR.sprite(self.time_root)
        .set_xy(-22, 0)
        .set_sprite(spr_ui_hud_clock_minutes_baked_text)
        .set_align(Align.LeftIn, Align.Middle)

    self.time_colon = ANCHOR.sprite(self.time_text_minutes)
        .set_xy(-7, 0)
        .set_sprite(spr_ui_hud_font_daytime_colon)
        .set_align(Align.LeftIn, Align.Middle)

    self.time_text_hours = ANCHOR.sprite(self.time_colon)
        .set_xy(-11, 0)
        .set_sprite(spr_ui_hud_clock_hours_baked_text)
        .set_align(Align.LeftIn, Align.Middle)

    self.update();
}

function text_input_popup(title, starting_text, max_width, callback, callback_args=[]) {
    var popup = popup_creator(title)
        .use_pilot(false)
    popup.manual_exit_listening = false;

    return text_input_popup_configuration(
        popup,
        starting_text,
        max_width,
        callback,
        callback_args
    );
}

function text_input_popup_configuration(popup, starting_text, max_width, callback, callback_args) {
    starting_text = starting_text == undefined ? "" : starting_text;

    var name_input_plate = ANCHOR.nine_slice(popup.backplate)
        .set_sprites_from_key("spr_ui_text_input_box")
        .set_size(max_width + 4, 16)
        .set_align(Align.Center, Align.Middle)

    popup.name_input = ANCHOR.text(name_input_plate)
        .set_align(Align.Center, Align.Middle)
        .set_lut(COMMON_LUT)
        .set_max_width(max_width)
        .set_text(starting_text)
        .set_takes_input(true)
        .allow_line_breaks(false)
        .set_think_callback(function(popup) {
            if popup.name_input.spawned_steam_keyboard && !steam_textbox_is_open() && GAMEPAD_LOST_POPUP == undefined {
                popup.close();
            }
        }, [popup])

    var character_limit = local_get_info(LocalInfoRequest.TextInputCharacterLimit);
    if character_limit != undefined {
        popup.name_input.set_max_characters(character_limit);
    }

    if steam_on_deck() || (steam_in_big_picture_mode() && ON_GAMEPAD) {
        name_input_plate.set_y(5);
        popup.backplate.set_align(Align.Center, Align.TopIn);
        popup.backplate.set_y(36);
    } else {
        popup.backplate.add_height(24);

        var button = popup.create_button("misc_local/confirm");
        button.glyph_node.board_set("input_id", InputId.ConfirmTextInput);
        button.glyph_node.board_set("specific_control", undefined);

        button.set_think_callback(function(button, name_input) {
            button.set_unlocked(string_trim(name_input.get_text()) != "");
        }, [button, popup.name_input]);
    }


    //
    new_chain().append(LinkId.Await, function(popup, callback, callback_args) {
        if popup.close_requested {
            var trimmed = string_trim(popup.name_input.get_text());
            if trimmed != "" {
                array_insert(callback_args, 0, trimmed);
                function_execute_alt(callback, callback_args);
            }
            return true;
        }
        return false;
    }, [popup, callback, callback_args]);

    return popup.spawn();
}

function elide_text(text, max_width, max_lines, include_ellipses=true, font, force=false) {
    font = font == undefined ? ANCHOR.get_text_font() : font;

    //
    var with_newlines = ANCHOR.reflow(text, max_width, font, force);

    //
    var lines = string_split(with_newlines, "\n");
    var true_line_count = array_length(lines);
    array_resize(lines, min(true_line_count, max_lines));

    //
    if include_ellipses && true_line_count > max_lines {
        //
        //
        var ellipses = local_get(fiddle_get("misc_local/ellipses"));
        var ellipses_width = string_width_font(ellipses);
        var len = array_length(lines);

        //
        //
        //
        //
        //
        var new_last_line = string_apply_newlines(lines[len - 1], max_width - ellipses_width, font);

        //
        var newline_pos = string_pos("\n", new_last_line);
        if newline_pos != 0 {
            new_last_line = string_copy(new_last_line, 1, newline_pos);
        }
        new_last_line = string_trim(new_last_line);

        //
        //
        var str_len = string_length(new_last_line);
        if array_contains(PUNCTUATION_CHARS, string_char_at(new_last_line, str_len)) {
            new_last_line = string_delete(new_last_line, str_len, 1);
        }

        lines[len - 1] = new_last_line + ellipses;
    }

    //
    return string_join_ext("\n", lines);
}

function GridLayout(asset_list, pilot, columns=6, square_size=24) constructor {
    self.columns = columns;
    self.square_size = square_size;
    self.asset_list = asset_list;
    self.pilot = pilot;
    self.increment_size = square_size - 1;
    self.position = Vec2Zero();
    self.iter = 0;
    self.total_len = asset_list.count();
    if self.total_len % columns != 0 {
        self.total_len += columns - (self.total_len % columns);
    }

    function container_size() {
        return Vec2(
            self.increment_size * self.columns,
            self.increment_size * ceil(self.asset_list.count() / self.columns),
        );
    }

    function next(parent) {
        if !self.has_next() {
            return undefined;
        }

        var normal_z = parent.get_z() - 10;
        var hover_z = parent.get_z() - 20;
        var icon_z = parent.get_z() - 40;

        var square = common_slice(parent)
            .set_bbox_offset(0, 0, -2, -2)
            .set_size(self.square_size)
            .set_xy(self.position)
            .set_z(normal_z)
            .listen_for_hovers()

        if self.pilot != undefined {
            square.add_to_pilot(self.pilot)
        }

        var icon = ANCHOR.sprite(square)
            .set_align(Align.Center, Align.Middle)
            .set_z(icon_z)

        var asset = self.asset_list.try_get(self.iter);

        if asset == undefined {
            square.lock();
        } else {
            square.set_think_callback(function(square, normal_z, hover_z) {
                //
                //
                var use_hover_sprite = square.is_hovered() || square.is_selected();
                square.set_z(use_hover_sprite ? hover_z : normal_z);
            }, [square, normal_z, hover_z]);
        }

        var output = {
            iter: self.iter,
            square: square,
            icon: icon,
            asset: asset,
        };

        self.position.x += self.increment_size;
        if (self.iter + 1) % self.columns == 0 {
            self.position.x = 0;
            self.position.y += self.increment_size;
            if self.pilot != undefined {
                self.pilot.request_newline();
            }
        }

        self.iter += 1;

        return output;
    }

    function has_next() {
        return self.iter < self.total_len;
    }
}

function JournalFields(parent, pilot) constructor {
    self.yy = 0;
    self.iter = 0;
    self.parent = parent;
    self.pilot = pilot;

    function new_field(icon, text, lut_index=1) {
        var plate = common_slice(self.parent, self.parent.get_width(), 20, self.iter % 2 == 1)
            .set_y(self.yy)
            .set_bbox_offset(0, 0, 0, -1)
            .add_to_pilot(self.pilot, true)

        plate.border_top = ANCHOR.sprite(plate)
            .set_scale_x(plate.get_width())
            .set_sprite(spr_pixel)
            .set_color(c_black)
            .disable()

        plate.border_bottom = ANCHOR.sprite(plate)
            .set_y(plate.get_height() - 1)
            .set_scale_x(plate.get_width())
            .set_sprite(spr_pixel)
            .set_color(c_black)
            .disable()

        plate.icon_node = ANCHOR.sprite(plate)
            .set_x(4)
            .set_align(Align.LeftIn, Align.Middle)
            .set_sprite(icon)
            .set_speed(1)

        plate.text_node = ANCHOR.text(plate.icon_node)
            .set_align(Align.RightOut, Align.Middle)
            .set_x(3)
            .set_lut(COMMON_LUT, lut_index)
            .set_text(text)

        plate.pencil = ANCHOR.sprite(plate)
            .set_sprites_from_key("spr_ui_generic_edit_pencil_icon")
            .set_key_sprite_target(plate)
            .set_align(Align.RightIn, Align.Middle)
            .set_x(-4);

        plate.set_think_callback(function(plate) {
            plate.border_top.set_y(plate.is_pressed() ? -1 : 0);
            var yy = plate.get_height() - 1;
            plate.border_bottom.set_y(yy + (plate.is_pressed() ? -1 : 0));

            plate.border_top.set_enabled(plate.is_hovered());
            plate.border_bottom.set_enabled(plate.is_hovered());

            plate.listen_for_hovers(plate.listens_for_taps ? 1 : 0);
            plate.pencil.set_alpha(plate.listens_for_taps ? 1 : 0);
        }, [plate])

        self.yy += plate.get_height() - 1;
        self.iter += 1;

        return plate;
    }
}

//
function await_popup(func, args, chain) {
    if chain == undefined {
        ANCHOR.popup_awaiters.push({ func: func, args: args });
        return;
    }

    var awaiter = { fired: false, func: func, args: args };

    chain
        .append(LinkId.Function, function(awaiter) {
            ANCHOR.popup_awaiters.push({
                func: function(awaiter) {
                    awaiter.fired = true;
                    function_execute_alt(awaiter.func, awaiter.args);
                },
                args: [awaiter],
            });
        }, [awaiter])
        .append(LinkId.Await, function(awaiter) {
            return awaiter.fired;
        }, [awaiter])
}

function Carousel() constructor {
    static DEFAULT_LAYOUT = fiddle_get("ui/misc/carousel_layout");
    self.parent = undefined;
    self.root = undefined;
    self.window = undefined;
    self.icons = undefined;
    self.icon_sprites = undefined;
    self.arrow_left_button = undefined;
    self.arrow_left_icon = undefined;
    self.arrow_right_button = undefined;
    self.arrow_right_icon = undefined;
    self.chain = undefined;
    self.layout = clone_value(DEFAULT_LAYOUT);

    function spawn(icon_sprites, parent, callback, index_to_select=0) {
        self.icon_sprites = icon_sprites;
        self.parent = parent;
        self.callback = callback;

        self.window = ANCHOR.sprite(parent)
            .set_align(Align.Center, Align.Middle)
            .set_y(1)
            .set_sprite(spr_ui_woodcrafting_carousel_window)
            .set_z(CraftingDepth.Window)

        var len = self.ideal_len();
        var icon_positions = centered_positions(
            len,
            self.layout.icon_size,
            self.layout.icon_padding,
        );

        if len == 2 {
            self.window.add_x(icon_positions[0]);
        }

        self.arrow_left_button = ANCHOR.nine_slice(parent)
            .set_z(CraftingDepth.Arrows)
            .set_sprites_from_key("spr_ui_store_button")
            .set_size(self.layout.arrow_left_button_size)
            .set_align(Align.Center, Align.Middle)
            .add_glyph(InputId.MenuTabLeft, undefined, true)
            .set_tap_sound("SoundEffects/UI/UIJournalTabSwitch")
            .set_x(
                icon_positions[0]
                - self.layout.arrow_left_button_size
                - self.layout.arrow_button_offset
            )

        self.arrow_left_icon = ANCHOR.sprite(self.arrow_left_button)
            .set_align(Align.Center, Align.Middle)
            .set_sprites_from_key("spr_ui_store_left_arrow")
            .set_key_sprite_target(self.arrow_left_button)

        self.arrow_right_button = ANCHOR.nine_slice(parent)
            .set_z(CraftingDepth.Arrows)
            .set_sprites_from_key("spr_ui_store_button")
            .set_size(self.layout.arrow_right_button_size)
            .set_align(Align.Center, Align.Middle)
            .add_glyph(InputId.MenuTabRight)
            .set_tap_sound("SoundEffects/UI/UIJournalTabSwitch")
            .set_x(
                icon_positions[array_length(icon_positions) - 1]
                + self.layout.arrow_left_button_size
                + self.layout.arrow_button_offset
            )

        self.arrow_right_icon = ANCHOR.sprite(self.arrow_right_button)
            .set_align(Align.Center, Align.Middle)
            .set_sprites_from_key("spr_ui_store_right_arrow")
            .set_key_sprite_target(self.arrow_right_button)

        self.build(index_to_select);
    }

    function build(index_to_select=0) {
        self.icons = List();

        var max_cats = self.icon_sprites.count();
        var len = self.ideal_len();
        var icon_positions = centered_positions(
            len,
            self.layout.icon_size,
            self.layout.icon_padding,
        );

        self.root = ANCHOR.positional(parent)
            .set_size(parent.get_size())
            .set_z(CraftingDepth.Carousel)

        var central_index = len == 2 ? 0 : len div 2;
        var preliminary_index = index_to_select - central_index;

        for (var i = 0; i < len; i++) {
            var cat_index = wrap(preliminary_index + i, max_cats);
            var icon = ANCHOR.sprite(self.root)
                .set_sprite(self.icon_sprites.get(cat_index))
                .set_x(icon_positions[i])
                .set_align(Align.Center, Align.Middle)
                .set_unlocked(cat_index != index_to_select)
                .board_set("category_index", cat_index)
                .set_label("icon_" + string(i))
                .set_tap_callback(function(positional_index, cat_index) {
                    self.transition(positional_index);
                    self.callback(cat_index);
                }, [i, cat_index])

            //
            if i == central_index - 1 {
                self.arrow_left_button.set_tap_callback(function(icon) {
                    ANCHOR.tap_node(icon);
                }, [icon], true);
            }
            if i == central_index + 1 {
                self.arrow_right_button.set_tap_callback(function(icon) {
                    ANCHOR.tap_node(icon);
                }, [icon], true);
            }

            self.icons.push(icon);
        }

        if len == 2 {
            self.arrow_left_button.set_tap_callback(function() {
                ANCHOR.tap_node(self.icons.last());
            }, [], true);
            self.arrow_right_button.set_tap_callback(function() {
                ANCHOR.tap_node(self.icons.last());
            }, [], true);
        }
    }

    function transition(positional_index) {
        //
        if self.chain != undefined {
            if self.chain.running {
                while run_chain(self.chain) == false {}
            }
            self.chain = undefined;
        }

        //
        var len = self.ideal_len();
        var current_node_index = len div 2;
        var old_icons = self.icons.clone();
        var target_node = old_icons.get(positional_index);
        var target_category_index = target_node.board_get("category_index");

        //
        var old_carousel = self.root;
        self.build(target_category_index);

        //
        var slide_duration = self.layout.slide_duration;
        self.chain = new_chain();
        if len != 2 {
            //
            var slide_amount = self.layout.icon_size + self.layout.icon_padding;
            var delta = current_node_index - positional_index;
            slide_amount *= delta;
            self.root.add_x(-slide_amount);
            var ease = new Ease(EaseId.QuartOut, 0, slide_amount, slide_duration);
            self.chain.join(LinkId.Ease, ease, function(d, _, old_carousel) {
                self.root.add_x(d);
                old_carousel.add_x(d);
            }, [old_carousel]);

            //
            //
            //
            for (var i = 0; i < old_icons.count(); i++) {
                var icon = old_icons.get(i);
                var potential_index = i + delta;
                if is_between_inclusive(potential_index, 0, len - 1) {
                    ANCHOR.free_node(icon);
                } else {
                    var ease = new Ease(EaseId.QuartOut, 1, 0, 5);
                    self.chain.join(LinkId.Ease, ease, function(d, _, icon) {
                        icon.add_alpha(d);
                    }, [icon])
                }
            }
        }

        //
        self.chain.append(LinkId.Function, function(old_carousel) {
            ANCHOR.free_node(old_carousel);
            self.chain = undefined;
        }, [old_carousel]);
    }

    function ideal_len() {
        var max_cats = self.icon_sprites.count();
        if max_cats != 2 {
            return min(max_cats - (1 - max_cats % 2), self.layout.items);
        } else {
            return 2;
        }
    }
}

function calendar_widget(parent) {
    var calendar = ANCHOR.sprite(parent)
        .set_xy(2, -2)
        .set_align(Align.RightIn, Align.TopIn)

    calendar.update = method(calendar, function() {
        self.set_sprite(string_to_asset(format("spr_ui_hud_calendar_baked_text_{}_{Season}", asset_local_insert(), CALENDAR.season())));
        self.set_index(CALENDAR.day())
    });

    calendar.update();

    return calendar;
}

function ProgressBar(parent, widget) constructor {
    self.max_width = 252;
    self.widget = widget;

    self.backplate = ANCHOR.sprite(parent)
        .set_align(Align.Center, Align.Middle)
        .set_y(45)
        .set_sprite(spr_ui_renown_progress_bar_backplate)

    self.bar = ANCHOR.nine_slice(self.backplate)
        .set_size(0, 20)
        .set_align(Align.LeftIn, Align.Middle)
        .set_x(31)
        .set_sprite(spr_ui_renown_progress_bar)
        .set_lut(spr_ui_renown_progress_bar_lut)

    self.edge = ANCHOR.sprite(self.bar)
        .set_sprite(spr_ui_renown_progress_bar_leading_edge)
        .set_align(Align.RightIn, Align.Middle)
        .set_x(2)
        .mirror_node_lut(self.bar)
        .set_speed(1)

    self.flash = ANCHOR.sprite(self.backplate)
        .set_sprite(spr_ui_renown_progress_bar_flash)
        .set_align(Align.Center, Align.Middle)
        .disable()
        .set_z(self.bar.get_z() - 20)
        .set_animation_end_callback(function() {
            self.flash.set_speed(0);
            self.flash.set_index(0);
        })

    self.frontplate = ANCHOR.sprite(self.backplate)
        .set_z(self.backplate.get_z() - 50)
        .set_align(Align.Center, Align.Middle)
        .set_sprite(spr_ui_renown_progress_bar_frontplate)

    self.reward_box = ANCHOR.positional(self.frontplate)
        .set_size(18, 18)
        .set_x(-9)
        .set_align(Align.RightIn, Align.Middle)

    self.reward_icon = ANCHOR.sprite(self.reward_box)
        .set_align(Align.Center, Align.Middle)
        .set_alpha(0.5)

    self.lock_icon = ANCHOR.sprite(self.reward_box)
        .set_z(self.reward_icon.get_z() - 1)
        .set_sprite(spr_ui_renown_lock_idle)
        .set_align(Align.Center, Align.TopIn)
        .set_y(-6)
        .board_set("base_y", -6)
        .board_set("up_y", -12)
        .set_alpha(0)

    function perform_eases(ease_orders, chain) {
        self.chain = chain;
        var first_order = ease_orders.first();

        self.bar.set_width(first_order.first_position);

        var reward_icon = spr_nothing;
        if first_order.level < RENOWN.rewards.count() {
            var reward = RENOWN.rewards.get(first_order.level);
            reward_icon = reward_to_icon(reward);
        }

        self.reward_icon.set_sprite(reward_icon);

        self.renown_bar_sound = undefined;

        ease_orders.for_each(function(order) {
            static MIN_DURATION = 30;
            static MAX_DURATION = 90;
            var delta = order.end_percentage - order.start_percentage;
            var duration = clamp(delta * MAX_DURATION, MIN_DURATION, MAX_DURATION);

            self.chain
                .append(LinkId.Function, function(order) {
                    self.lock_icon
                        .set_sprite(spr_ui_renown_lock_idle)
                        .set_y(self.lock_icon.board_get("base_y"))

                    var reward_icon = spr_nothing;
                    if order.level < RENOWN.rewards.count() {
                        var reward = RENOWN.rewards.get(order.level);
                        reward_icon = reward_to_icon(reward);
                    }

                    self.reward_icon.set_sprite(reward_icon);
                    self.renown_bar_sound = TANGO.play("SoundEffects/UI/RenownBarFillUp");

                }, [order])
                .append(LinkId.Ease, new Ease(EaseId.QuadOut, order.first_position, order.end_position, duration), function(_, a) {
                    self.bar.set_width(a);
                })
                .join(LinkId.Ease, new Ease(EaseId.QuadOut, order.start_percentage, order.end_percentage, duration), function(_, a) {
                    static COLUMNS = sprite_get_width(spr_ui_renown_progress_bar_lut);
                    self.bar.set_lut_index(COLUMNS * a);
                })
                .join(LinkId.Ease, new Ease(EaseId.QuadOut, self.reward_icon.get_alpha(), 0.5, 20), function(_, a) {
                    self.reward_icon.set_alpha(a);
                })
                .join(LinkId.Ease, new Ease(EaseId.QuadOut, self.lock_icon.get_alpha(), 1, 20), function(_, a) {
                    self.lock_icon.set_alpha(a);
                })
                .append(LinkId.Function, function() {
                    //
                    if self.renown_bar_sound != undefined {
                        TANGO.force_stop(self.renown_bar_sound);
                    }
                })

            if order.is_level_up {
                self.chain
                    .append(LinkId.Function, function(order) {

                        //
                        if self.widget != undefined {
                            new_chain()
                                .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 15), function(_, a) {
                                    self.widget.level.set_alpha(a);
                                })
                                .append(LinkId.Function, function(order) {
                                    self.widget.level.set_text(format("{Local} {}", "misc_local/renown_lvl_insert_caps", order.level + 1));
                                }, [order])
                                .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 15), function(_, a) {
                                    self.widget.level.set_alpha(a);
                                })
                        }

                        self.flash
                            .enable()
                            .set_alpha(1)
                            .set_speed(1);

                        TANGO.play("SoundEffects/UI/RenownUnlock");

                    }, [order]);

                if order.level + 1 <= order.max_level {
                    self.chain
                        .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0.5, 1, 15), function(_, a) {
                            self.reward_icon.set_alpha(a);
                        })
                        .join(LinkId.Function, function() {
                            self.bar.set_width(0);
                            self.lock_icon.set_sprite(spr_ui_renown_lock_open);
                        })
                        .join(LinkId.Ease, new Ease(EaseId.BackIn, self.lock_icon.board_get("base_y"), self.lock_icon.board_get("up_y"), 15), function(_, a) {
                            self.lock_icon.set_y(a);
                        })
                        .join(LinkId.Ease, new Ease(EaseId.Linear, 1, 0, 20), function(_, a) {
                            self.lock_icon.set_alpha(a);
                        })

                    if order.is_rank_up {
                        //
                        chain
                            .append(LinkId.Timer, 25)
                            .append(LinkId.Function, function(order) {
                                TANGO.play("SoundEffects/UI/RenownRankUpIntro");

                                var rank = renown_level_to_rank(order.level + 1);

                                var overlay = ANCHOR.sprite(self.widget.star)
                                    .set_sprite(spr_ui_renown_status_star_flash_mask)
                                    .set_align(Align.Center, Align.Middle)

                                //
                                var flash_chain = new_chain();
                                var i = 0;
                                static TICKS = 10;
                                var ease = new Ease(EaseId.SineOut, 16, 3, TICKS);
                                for (var i = 0; i < TICKS; i++) {
                                    var duration = floor(ease.calculate_value(i));
                                    flash_chain
                                        .append(LinkId.Ease, new Ease(EaseId.Linear, 0, 1, duration), function(_, a, overlay) {
                                            overlay.set_alpha(a);
                                        }, [overlay])
                                        .append(LinkId.Ease, new Ease(EaseId.Linear, 1, 0, duration), function(_, a, overlay) {
                                            overlay.set_alpha(a);
                                        }, [overlay])
                                }

                                //
                                static EFFECT_DURATION = 100;
                                var effect = ANCHOR.sprite(self.widget.star)
                                    .set_speed(1)
                                    .set_align(Align.Center, Align.Middle)
                                    .set_sprite(spr_ui_renown_level_up_star_fx_energy)
                                    .set_alpha(0)

                                new_chain()
                                    .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, EFFECT_DURATION), function(_, a, effect) {
                                        effect.set_alpha(a);
                                    }, [effect])

                                //
                                flash_chain
                                    .append(LinkId.Function, function(effect, rank) {
                                        TANGO.play("SoundEffects/UI/RenownRankUpHit");

                                        ANCHOR.free_node(effect);
                                        self.widget.star.set_sprite(rank.sprite);
                                        self.widget.text.set_text(format("{Local}: {Local}", "misc_local/town_rank", rank.name));
                                        self.widget.backplate.set_width(max(self.widget.text.get_width() + 26, 130));

                                        var poof = ANCHOR.sprite(self.widget.star)
                                            .set_sprite(spr_ui_renown_level_up_star_fx_poof)
                                            .set_align(Align.Center, Align.Middle)
                                            .set_speed(1);

                                        poof.set_animation_end_callback(function(poof) {
                                            ANCHOR.free_node(poof);
                                            self.widget.star.board_set("completion_flag", true);
                                        }, [poof]);

                                    }, [effect, rank])
                            }, [order])
                            .append(LinkId.Await, function() {
                                return self.widget.star.board_try_take("completion_flag") == true;
                            })
                    }
                }

                self.chain
                    .append(LinkId.Function, function(order) {
                        if order.is_rank_up && !MIST.is_running() {
                            refresh_achievements([Requirement.ReachedRenownLevel]);
                        }
                        self.level_up_callback(order);
                    }, [order])
                    .append(LinkId.Await, function() {
                        return self.level_up_continue_check();
                    });

                if order.level + 1 < order.max_level {
                    self.chain
                        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 30), function(_, a) {
                            self.flash.set_alpha(a);
                            self.reward_icon.set_alpha(a);
                        })
                        .append(LinkId.Function, function() {
                            self.flash.disable();
                        })
                }
            } else {
                self.chain.append(LinkId.Timer, 60);
            }
        });
    }

}

function calculate_progress_ease_orders(level, value, earned, max_width, max_level, total_getter, individual_getter, rank_up_getter, args) {
    var ease_orders = List();
    var remaining_value = earned;
    args = args == undefined ? [] : args;

    while true {
        //
        if level >= max_level {
            break;
        }

        //
        var prior_value = function_execute_alt(total_getter, array_concat([level], args));

        //
        var individual = function_execute_alt(individual_getter, array_concat([level + 1], args));

        //
        var progress = value - prior_value;

        //
        var value_for_this_tick = min(remaining_value, individual - progress);

        //
        var start_percentage = progress / individual;

        //
        var end_percentage = (progress + value_for_this_tick) / individual;

        //
        remaining_value -= value_for_this_tick;

        //
        value += value_for_this_tick;

        //
        ease_orders.push({
            level: level,
            start_percentage: start_percentage,
            end_percentage: end_percentage,
            first_position: start_percentage * max_width,
            end_position: end_percentage * max_width,
            is_level_up: value >= prior_value + individual,
            is_rank_up: rank_up_getter(level),
            max_level: max_level,
        });


        if remaining_value > 0 {

            //
            level += 1;
        } else {
            //
            break;
        }

    }

    return ease_orders;
}

function player_gold_prefab(menu, include_calendar=false) {
    self.player_gold_cache = ARI.get_gold();

    self.gold_canvas = ANCHOR.canvas(ANCHOR.screen_canvas, 0, AnchorLayer.Popup)
        .set_size_to_screen()
        .set_think_callback(function(menu) {
            if menu.close_requested {
                ANCHOR.free_node(self.gold_canvas);
            }
        }, [menu])

    self.gold_backplate = ANCHOR.nine_slice(self.gold_canvas)
        .set_align(Align.RightIn, Align.TopIn)
        .set_xy(-4, 6)
        .set_size(30, 15)
        .enable_day_night_lut()
        .set_sprite(spr_ui_generalstore_inventory_currencytab)

    self.gold_icon = ANCHOR.sprite(self.gold_backplate)
        .set_x(-6)
        .set_align(Align.RightIn, Align.Middle)
        .set_sprite(spr_ui_hud_info_currency_icon)
        .enable_day_night_lut();

    self.gold_text = ANCHOR.text(self.gold_icon)
        .set_x(-2)
        .set_align(Align.LeftOut, Align.Middle)
        .set_sprite_font("currency")
        .enable_day_night_lut()
        .set_think_callback(function() {
            var v = ARI.get_gold();
            if self.player_gold_cache != v {
                self.gold_animator.set_gold(v);
                self.player_gold_cache = v;
            }
        });

    #macro GOLD_ADDER_Y 28
    self.gold_adder = ANCHOR.text(self.gold_backplate)
        .set_xy(-4, GOLD_ADDER_Y)
        .set_sprite_font("currency")
        .set_align(Align.Center, Align.Middle)
        .disable();

    self.gold_animator = new GoldAnimator(
        self.gold_backplate,
        self.gold_text,
        self.gold_adder,
        function() {
            return sprite_font_width(num_display(ARI.get_gold()), "currency") + 22;
        }
    );

    self.gold_animator.set_gold(ARI.get_gold(), true);

    if include_calendar {
        self.calendar = calendar_widget(self.gold_canvas);
        self.calendar
            .set_align(Align.RightIn, Align.TopIn)
            .set_xy(-4, 4)
        self.gold_backplate.add_x(-20);
    }
}
function item_node(parent, item, count=1) {
    item = item != undefined && !is_struct(item) ? new LiveItem(item) : item;

    var item_node = ANCHOR.sprite(parent)
        .set_sprite(spr_illegal_16)
        .set_align(Align.Center, Align.Middle)
        .set_speed(1)

    item_node.count = ANCHOR.sprite(item_node)
        .set_align(Align.RightIn, Align.BottomIn)
        .set_sprite(spr_ui_hud_item_count_baked_text)
        .set_x(1)
        .set_z(0)
        .disable()

    item_node.sub_icon = ANCHOR.sprite(item_node)
        .set_align(Align.LeftIn, Align.BottomIn)
        .set_z(0)

    item_node.set_to_item = method(item_node, function(item, count=1) {
        self.set_sprite(item.get_ui_icon())
        if count <= 1 {
            self.count.disable();
        } else {
            self.count.enable();
            self.count.set_index(count);
        }

        var sub_icon = item.get_ui_sub_icon();
        if sub_icon == undefined {
            self.sub_icon.disable();
        } else {
            self.sub_icon.enable();
            self.sub_icon.set_sprite(sub_icon);
        }

        if item.infusion != undefined {
            self.set_outline_sprite(item.prototype.icon_sprite_outline);
            var color = INFUSIONS.get(item.infusion).color;
            self.set_outline_color(make_color_rgb(color[0], color[1], color[2]));
        } else {
            self.set_outline_sprite(undefined);
        }
    });

    if item != undefined {
        item_node.set_to_item(item, count);
    }

    return item_node;
}

function MultipleChoicePopup(title, icon) constructor {
    self.popup = popup_creator(title)
        //
        .spawn();
    self.popup.play_sound(false); //
    self.popup.backplate.set_height(50);
    self.popup.header
        .set_xy(0, 0)
        .set_sprite(spr_ui_tooltip_header_box)
        .set_size(self.popup.backplate.get_width(), 31)
    self.y = 42;
    self.buttons = List();
    self.pilot = self.popup.new_pilot();
    self.popup.hid_hud = true;

    if icon != undefined {
        ANCHOR.sprite(self.popup.title)
            .set_align(Align.LeftOut, Align.Middle)
            .set_x(-3)
            .set_sprite(icon)

        self.popup.title.add_x(2);
    }

    function option(label, callback, args) {
        var button = self.popup.create_button(label, callback, args, undefined, undefined, false)
            .set_align(Align.Center, Align.TopIn)
            .set_y(self.y)
            .set_width(97)
            .remove_glyph()
            .set_tap_callback(function(callback, args) {
                self.popup.lock();
                new_chain()
                    .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 20), function(_, a) {
                        self.popup.canvas.set_alpha(a);
                    })
                    .append(LinkId.Function, function(callback, args) {
                        self.popup.close();
                        function_execute_alt(callback, args);
                    }, [callback, args])
            }, [callback, args], true)

        self.buttons.push(button);

        self.popup.pilot.request_newline();

        var inc = button.get_height() + 7;
        self.y += inc;
        self.popup.backplate.add_height(inc);
        ANCHOR.set_active_pilot(self.popup.pilot);
        return self;
    }
}

function show_room_title() {

    var location = LOCATIONS[CURRENT_LOCATION_ID];
    var name;

    var this_building = get_buildings().find_value(function(v) {
        return v.dyn_index == CURRENT_DYN_INDEX;
    });

    if this_building != undefined {
        name = this_building.name;
    } else if CURRENT_LOCATION_ID == LocationId.Dungeon {
        if
            DUNGEON_RUNNER.last_floor == undefined
            || DUNGEON_BIOME != DUNGEON_RUNNER.itinerary.get(DUNGEON_RUNNER.last_floor).biome
        {
            name = local_get(DUNGEON.biomes[DUNGEON_BIOME].name);
        } else {
            return;
        }
    } else if CURRENT_LOCATION_ID == LocationId.Farm {
        name = ARI.farm_name;
    } else if location.name != undefined {
        name = local_get(location.name);
    } else {
        return;
    }

    stop_room_title();
    var width = string_width_font(name) + 16;
    var backplate = ANCHOR.nine_slice(ANCHOR.screen_canvas)
        .set_layer(AnchorLayer.Standard)
        .set_size(width, 14)
        .set_max_alpha(0.75)
        .set_y(8)
        .set_align(Align.Center, Align.TopIn)
        .set_sprite(spr_ui_generalstore_prompt_box)
        .set_alpha(0);

    ANCHOR.text(backplate)
        .set_text(name)
        .set_align(Align.Center, Align.Middle)

    if is_dungeon_room(room()) {
        ANCHOR.get_menu(Menu.Mines).request_hide(0);
    }

    var chain = new_chain()
        .append(LinkId.Timer, 15)
        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 40), function(_, a) {
            ACTIVE_ROOM_TITLE.node.set_alpha(a);
        })
        .append(LinkId.Timer, 100)
        .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 40), function(_, a) {
            ACTIVE_ROOM_TITLE.node.set_alpha(a);
        })
        .append(LinkId.Function, function() {
            ANCHOR.free_node(ACTIVE_ROOM_TITLE.node);
            ACTIVE_ROOM_TITLE = undefined;
            if is_dungeon_room(room()) {
                ANCHOR.get_menu(Menu.Mines).request_show();
            }
        })

    ACTIVE_ROOM_TITLE = {
        chain: chain,
        node: backplate
    };
}

function stop_room_title() {
    if ACTIVE_ROOM_TITLE != undefined {
        CHAINS.cancel_chain(ACTIVE_ROOM_TITLE.chain);
        ANCHOR.free_node(ACTIVE_ROOM_TITLE.node);
        ACTIVE_ROOM_TITLE = undefined;
        if is_dungeon_room(room()) {
            ANCHOR.get_menu(Menu.Mines).request_show();
        }
    }
}

function render_animal_in_ui(animal, parent, dir=Cardinal.East, override_animation) {
    var sprites = animal.sprites_for_animation(override_animation ?? "idle", dir);

    //
    if animation_to_shape(sprites.base_sprite) == undefined {
        warn("Missing a shape for '{gm_sprite}'!", sprites.base_sprite);
        var centered = Vec2Zero();
    } else {
        var centered = centered_position_from_bbox(
            sprites.base_sprite,
            parent.get_size(),
        );
    }

    var animal_base = ANCHOR.sprite(parent)
        .set_sprite(sprites.base_sprite)
        .set_xy(centered);

    static MAKE_LAYER = function(base, sprite, z) {
        sprite ??= spr_nothing;
        var base_sprite = base.get_sprite();

        return ANCHOR.sprite(base, z)
            .set_sprite(sprite)
            .set_xy(
                sprite_get_xoffset(base_sprite) - sprite_get_xoffset(sprite),
                sprite_get_yoffset(base_sprite) - sprite_get_yoffset(sprite),
            );
    };


    var cosmetic_base = MAKE_LAYER(animal_base, sprites.base_cosmetic, animal_base.z - 1);
    var animal_top = MAKE_LAYER(animal_base, sprites.top_sprite, animal_base.z - 2);
    var cosmetic_top = MAKE_LAYER(animal_base, sprites.top_cosmetic, animal_base.z - 3);

    if sprites.lut != undefined {
        animal_base.set_lut(sprites.lut, sprites.lut_index);
        animal_top.set_lut(sprites.lut, sprites.lut_index);
    }

    return {
        animal_base,
        cosmetic_base,
        animal_top,
        cosmetic_top,
    };
}

function scroller_none_option(scroller, height) {
    var element = scroller.new_element(height)
        .add_to_pilot(scroller.subscribed_pilot)
        .listen_for_hovers()
    ANCHOR.text(element)
        .set_align(Align.Center, Align.Middle)
        .set_key("misc_local/none_alt")
        .set_lut(COMMON_LUT)
        .set_alpha(UI_FADE_ALPHA)

    return element;
}

function centered_position_from_bbox(sprite, container_size) {
    var bbox_dims = shape_get_dimensions(sprite);
    var bbox_offset = shape_get_offset(sprite);
    var sprite_offset = sprite_get_offset(sprite);

    return Vec2(
        (container_size.x / 2) + sprite_offset[0] - bbox_offset[0] - (bbox_dims[0] / 2),
        (container_size.y / 2) + sprite_offset[1] - bbox_offset[1] - (bbox_dims[1] / 2),
    );
}

function render_skill_level(parent, skill, auto_update=true) {
    var root = ANCHOR.positional(parent)
        .set_align(Align.Center, Align.Middle)
        .set_height(8)

    var icon = ANCHOR.sprite(root).set_align(Align.LeftIn, Align.Middle);

    root.lvl = ANCHOR.text(icon)
        .set_text("99");
    root.skill = skill;
    root.icon = icon;
    root.cached_xp = ARI.skill_xp[skill];

    root.update_level = method(root, function(override) {
        var level = override ?? ARI.level(self.skill);
        self.lvl.set_text(level);
        self.lvl.set_x(level >= 10 ? 2 : 4);
        self.icon.set_sprite(string_to_asset(fiddle_get(format("skills/{Skill}/sprite", self.skill))));
        self.set_width_for_nodes([self.icon, self.lvl]);
    });

    root.lvl
        .set_align(Align.RightOut, Align.Middle)
        .set_x(2)
        .set_sprite_font("player_level")
        .set_lut(COMMON_LUT, CommonLutIndex.Green);

    if auto_update {
        root.set_think_callback(function(root) {
            if root.cached_xp != ARI.skill_xp[root.skill] {
                root.update_level();
                root.cached_xp = ARI.skill_xp[root.skill];
            }
        }, [root])
    }

    root.update_level();

    return root;
}

function spawn_tutorial(tutorial) {
    if TEST_SUITE {
        return;
    }

    ARI.tutorials_seen[tutorial] = true;

    var data = TUTORIALS[tutorial];

    var popup = popup_creator();
    popup.tutorial = data;
    popup.manual_exit_listening = false;

    popup.add_title(data.title);

    popup.backplate.set_size(211, 218);

    popup.header
        .set_xy(0, 0)
        .set_sprite(spr_ui_tooltip_header_box)
        .set_size(popup.backplate.get_width(), 36)

    popup.image = ANCHOR.sprite(popup.header)
        .set_align(Align.Center, Align.BottomOut)
        .set_y(6)

    popup.text = ANCHOR.text(popup.image)
        .set_align(Align.Center, Align.BottomOut)
        .set_y(3)
        .set_lut(COMMON_LUT)
        .allow_line_breaks()
        .set_text_align(TextAlign.Center)
        .set_key(data.steps[0].text)

    popup.set_to_step = method(popup, function(index, button_to_hover) {
        self.buttons.drain(function(b) {
            ANCHOR.free_node(b);
            return true;
        });
        self.pilot.reset();

        self.image.set_sprite(self.tutorial.steps[index].sprite)
        self.text.set_key(self.tutorial.steps[index].text);
        self.text.set_max_width(self.text.infer_max_size(self.backplate).x);

        var is_last = index + 1 >= array_length(self.tutorial.steps);

        if index != 0 {
            var button = self.create_button(
                "misc_local/back",
                self.set_to_step,
                [index - 1, 0],
                undefined,
                undefined,
                true,
                false,
            );
            button.remove_glyph();
        }

        if !is_last {
            var button = self.create_button(
                "misc_local/next",
                self.set_to_step,
                [index + 1, 1],
                undefined,
                undefined,
                true,
                false,
            );
            button.remove_glyph();
        } else {
            var button = self.create_button("misc_local/close");
            button.remove_glyph();
        }

        if button_to_hover != undefined {
            var target = self.buttons.get(button_to_hover);
            self.pilot.force_select(target);
        }
    });

    popup.set_to_step(0);

    popup.spawn();
}

function create_invalid_save_popup() {
    var popup = popup_creator("misc_local/invalid_save", "misc_local/invalid_save_body");
    popup.create_button("misc_local/close");
    popup.spawn();
    return popup;
}

function scrolling_popup(title) {
    var popup = popup_creator(title);

    popup.backplate.set_size(180, 200);

    var root = ANCHOR.positional(popup.backplate)
        .set_size(160, 156)
        .set_align(Align.Center, Align.Middle)
        .set_xy(4, 11)

    popup.scroller = create_scroller(root);

    popup.scroller.outline.enable();

    popup.scroller.subscribe_to_pilot(popup.pilot);

    return popup;
}

//
function find_node(name) {
    for (var i = 0; i < ANCHOR.node_count; i++) {
        if ANCHOR.node_registrar[| i].display() == name {
            return ANCHOR.node_registrar[| i];
        }
    }
    return undefined;
}

function gift_preferences_ui(parent) {
    var loved_gifts = ANCHOR.text(parent)
        .set_key("misc_local/loved_gifts")
        .set_align(Align.Center, Align.TopIn)
        .set_y(3)
        .set_lut(COMMON_LUT)

    var loved_gift_zone = ANCHOR.positional(parent)
        .set_size(86, 35)
        .set_align(Align.Center, Align.TopIn)
        .set_y(16)

    var liked_gifts = ANCHOR.text(parent)
        .set_key("misc_local/liked_gifts")
        .set_align(Align.Center, Align.TopIn)
        .set_y(52)
        .set_lut(COMMON_LUT)

    var liked_gift_zone = ANCHOR.positional(parent)
        .set_size(86, 52)
        .set_align(Align.Center, Align.TopIn)
        .set_y(66)

    var nodes = {
        loved_gifts,
        loved_gift_zone,
        liked_gifts,
        liked_gift_zone,
        icons: List(),
    };


    nodes.set_to_npc = method(nodes, function(npc_id) {
        static GIFT_NODE = function(gift, parent, icons, npc_id, xx, yy) {
            var slot = common_slice(parent, 18, 18)
                .set_xy(xx, yy)
            if gift == undefined {
                slot.lock();
            } else {
                var knows_gift = NPCS[npc_id].known_gift_preferences.contains(gift);
                var given_gift = NPCS[npc_id].gifts_given.contains(gift);
                var icon = ANCHOR.sprite(slot)
                    .set_sprite(knows_gift ? ITEM_PROTOTYPES[gift].icon_sprite : spr_ui_generic_lock_icon)
                    .set_align(Align.Center, Align.Middle)
                    .set_alpha(knows_gift && !given_gift ? 0.5 : 1);

                icon.item_id = gift;
                icons.push(icon);
            }
        }

        var proto = NPC_PROTOTYPES[npc_id];

        ANCHOR.free_children(self.loved_gift_zone);
        var iter = 0;
        for (var i = 0; i < 2; i++) {
            for (var j = 0; j < 5; j++) {
                GIFT_NODE(proto.loved_gifts.try_get(iter), self.loved_gift_zone, self.icons, npc_id, 17 * j, 17 * i);
                iter += 1;
            }
        }

        ANCHOR.free_children(self.liked_gift_zone);
        var iter = 0;
        for (var i = 0; i < 4; i++) {
            for (var j = 0; j < 5; j++) {
                GIFT_NODE(proto.liked_gifts.try_get(iter), self.liked_gift_zone, self.icons, npc_id, 17 * j, 17 * i);
                iter += 1;
            }
        }
    });

    return nodes;
}

function npc_polaroid_ui(parent, small=false) {
    var bkg = small
        ? spr_ui_journal_relationship_photo_bg_smaller
        : spr_ui_journal_relationship_photo_bg;
    var background = ANCHOR.sprite(parent)
        .set_sprite(bkg)
        .set_xy(12, 18);
    var w = sprite_get_width(bkg);
    var h = sprite_get_height(bkg);
    var canvas = ANCHOR.canvas(background)
        .set_size(w, h)
        .set_render_partial(0, 0, w, h)

    var portrait = ANCHOR.sprite(canvas);

    if small {
        portrait.set_x(-2);
    }

    var frame = ANCHOR.sprite(background)
        .set_sprite(small
            ? spr_ui_journal_relationship_photo_frame_smaller
            : spr_ui_journal_relationship_photo_frame
        )
        .set_align(Align.Center, Align.Middle)

    var nodes = {
        background,
        canvas,
        portrait,
        frame,
    };

    nodes.set_to_npc = method(nodes, function(npc) {
        var proto = NPC_PROTOTYPES[npc];
        var position = proto.journal_portrait_offset;
        var color = proto.journal_background_color;
        var portrait_sprite = NPCS[npc].wardrobe.outfit_current.portraits.get("neutral")
            ?? NPCS[npc].wardrobe.outfits.get(proto.fallback_outfit).portraits.get("neutral");
        self.portrait
            .set_sprite(portrait_sprite)
            .set_xy(position[0], position[1])
        self.background.set_color(make_color_rgb(color[0], color[1], color[2]));
    });

    return nodes;
}

function create_quest_popup(quest) {
    var raw = format("{Local}:\n{Local}", "misc_local/quest_started", QUESTS.get(quest).name);
    create_notification(ANCHOR.wrap_for_local(raw));
}

function portrait_effect_ui(parent) {
    var portrait_effect = ANCHOR.sprite(parent)
        .set_align(Align.Center, Align.Middle)
        .set_speed(0.5)
        .disable();

    portrait_effect.set_animation_end_callback(function(portrait_effect) {
        if portrait_effect.play_once {
            portrait_effect.set_speed(0);
        }
    }, [portrait_effect]);

    portrait_effect.play_once = false;

    portrait_effect.set = method(portrait_effect, function(speaker_prototype, effect_name) {
        effect_name = effect_name == undefined ? "none" : effect_name;
        var entry = fiddle_get(format("ui/dialogue_effects/{}", effect_name));
        if entry[$ "sprite"] != undefined {
            self.enable();
            self.set_sprite(string_to_asset(entry.sprite));
            self.set_index(0);
        } else {
            self.disable();
        }
        if entry[$ "sound"] != undefined {
            TANGO.play(entry.sound);
        }

        var position = Vec2();

        if effect_name != "none" {
            var offset = speaker_prototype.offsets[$ effect_name];
            position.x = offset[0];
            position.y = offset[1];
        }

        self.play_once = entry[$ "play_once"] ?? false;
        self.set_speed(1);
        self.set_xy(position.x, position.y);
    });

    return portrait_effect;
}

function npc_selection_ui(callback) {
    var popup = popup_creator("misc_local/select_a_villager");
    popup.backplate.set_height(220);

    var scroller = create_scroller(
        popup.backplate,
        Vec2(10, 36),
        Vec2(147, 170),
    );
    scroller.outline.enable();
    var pilot = popup.new_pilot();
    scroller.subscribe_to_pilot(pilot);
    var elements = List();

    for (var i = 0; i < NpcId.LEN; i++) {
        if !NPCS[i].has_met() {
            continue;
        }
        var element = scroller.new_element(26)
            .add_to_pilot(pilot, true)
            .set_tap_callback(function(popup, npc, callback) {
                popup.close();
                callback(npc);
            }, [popup, i, callback])
        var icon = ANCHOR.sprite(element)
            .set_sprite(get_npc_icon(i))
            .set_align(Align.LeftIn, Align.Middle)
            .set_x(3)
        ANCHOR.text(icon)
            .set_key(NPC_PROTOTYPES[i].name)
            .set_lut(COMMON_LUT)
            .set_align(Align.RightOut, Align.Middle)
            .set_x(2)

        elements.push(element);
    }

    popup.spawn();

    ANCHOR.set_active_pilot(pilot);

    return {
        popup,
        scroller,
        pilot,
        elements,
    };

}

function animal_selection_ui(size, element_height) {
    var popup = popup_creator("misc_local/select_an_animal");
    popup.backplate.set_size(200, 220);

    var scroller = create_scroller(
        popup.backplate,
        Vec2(10, 36),
        Vec2(167, 171),
    );
    scroller.outline.enable();
    var pilot = popup.new_pilot();
    scroller.subscribe_to_pilot(pilot);
    var entries = populate_scroller_with_farm_buildings(scroller, pilot, size, element_height);

    if !scroller.scroll_bar_root.get_enabled() {
        scroller.move(6, 0);
    }

    popup.spawn();

    ANCHOR.set_active_pilot(pilot);

    return {
        popup,
        scroller,
        pilot,
        entries,
    };
}

function song_selection_ui(callback) {
    var popup = popup_creator("misc_local/select_a_song");
    popup.backplate.set_size(300, 220);

    var scroller = create_scroller(
        popup.backplate,
        Vec2(10, 36),
        Vec2(popup.backplate.get_width() - 30, 170),
    );
    scroller.outline.enable();
    var pilot = popup.new_pilot();
    scroller.subscribe_to_pilot(pilot);
    pilot.allow_vertical_wrapping();
    var elements = List();

    var keys = ListFromArray(struct_get_names(SONGS));
    keys.sort_with(function(e1, e2) {
        var e1_unlocked = array_has(ARI.song_unlocks, e1);
        var e2_unlocked = array_has(ARI.song_unlocks, e2);
        if e1_unlocked && e2_unlocked {
            var e1_name = local_get(SONGS[e1].name);
            var e2_name = local_get(SONGS[e2].name);
            return string_alphanumeric_comparison(e1_name, e2_name);
        } else if e1_unlocked {
            return -1;
        } else {
            return 1;
        }
    });
    keys.insert(undefined, 0);
    for (var i = 0; i < keys.count(); i++) {
        var key = keys.get(i);
        var unlocked = key == undefined ? true : array_has(ARI.song_unlocks, key);
        var element = scroller.new_element(26)
            .add_to_pilot(pilot, true)
            .set_soft_locked(!unlocked)
            .set_selected_getter(function(key) {
                return ARI.song_overrides[CURRENT_LOCATION_ID] == key;
            }, [key])
            .set_tap_callback(function(popup, song, callback) {
                popup.close();
                callback(song);
            }, [popup, key, callback])
        var icon = ANCHOR.sprite(element)
            .set_sprite(key == undefined ? spr_ui_generic_icon_select_none_odd : SONGS[key].icon)
            .set_align(Align.LeftIn, Align.Middle)
            .set_color(unlocked ? c_white : MUSEUM_LOCKED_OVERLAY)
            .set_x(3)
        ANCHOR.text(icon)
            .set_key(unlocked
                ? (key == undefined ? "misc_local/none" : SONGS[key].name)
                : ANCHOR.wrap_for_local("???")
            )
            .set_lut(COMMON_LUT)
            .set_align(Align.RightOut, Align.Middle)
            .set_x(2)

        elements.push(element);
    }

    popup.spawn();

    ANCHOR.set_active_pilot(pilot);

    return popup;
}

function bell_sound_selection_ui(callback) {
    var popup = popup_creator("misc_local/select_bell_sound");
    popup.canvas.set_layer_recursive(AnchorLayer.Standard);
    popup.background_layer = AnchorLayer.Standard;
    popup.background_z = popup.canvas.get_z() + 1;
    popup.active_sound = undefined;
    popup.backplate.set_size(240, 220);

    var scroller = create_scroller(
        popup.backplate,
        Vec2(10, 36),
        Vec2(popup.backplate.get_width() - 30, 170),
    );
    scroller.outline.enable();
    var pilot = popup.new_pilot();
    scroller.subscribe_to_pilot(pilot);
    pilot.allow_vertical_wrapping();
    var elements = List();

    var keys = ListFromArray(struct_get_names(BELL_SOUNDS));
    keys.sort_with(function(e1, e2) {
        if e1 == "default" {
            return -1;
        } else if e1 == "default" {
            return 1;
        } else {
            return string_alphanumeric_comparison(BELL_SOUNDS[e1].name, BELL_SOUNDS[e2].name);
        }
    });
    for (var i = 0; i < keys.count(); i++) {
        var key = keys.get(i);
        var element = scroller.new_element(26)
            .add_to_pilot(pilot, true)
            .set_selected_getter(function(key) {
                return ARI.bell_sound == key;
            }, [key])
            .set_tap_callback(function(popup, key, callback) {

                var confirm = popup_creator(
                    "misc_local/confirm_bell_sound",
                    ANCHOR.wrap_for_local(format(
                        local_get("misc_local/confirm_bell_sound_description"),
                        local_get(BELL_SOUNDS[key].name),
                    )),
                );
                var close = confirm.create_button("misc_local/close");
                var conf_button = confirm.create_button("misc_local/confirm", function(key, callback, popup) {
                    callback(key);
                }, [key, callback, popup]);
                var preview = confirm.create_button(
                    "misc_local/preview",
                    function(key, popup) {
                        if popup.active_sound != undefined {
                            TANGO.force_stop(popup.active_sound);
                        }
                        popup.active_sound = TANGO.play(BELL_SOUNDS[key].sound + "2D")
                    },
                    [key, popup],
                    undefined,
                    undefined,
                    false,
                    false,
                );
                confirm.backplate.add_height(20);
                confirm.body.add_y(-10);
                preview.add_y(-23);

                //
                confirm.pilot.reset();
                preview.add_to_pilot(confirm.pilot, true);
                close.add_to_pilot(confirm.pilot);
                conf_button.add_to_pilot(confirm.pilot);
                confirm.pilot.force_select(close);
                confirm.spawn();
            }, [popup, key, callback])
        var icon = ANCHOR.sprite(element)
            .set_sprite(BELL_SOUNDS[key].icon)
            .set_align(Align.LeftIn, Align.Middle)
            .set_x(3)
        ANCHOR.text(icon)
            .set_key(BELL_SOUNDS[key].name)
            .set_lut(COMMON_LUT)
            .set_align(Align.RightOut, Align.Middle)
            .set_x(2)

        elements.push(element);
    }

    popup.spawn();

    ANCHOR.set_active_pilot(pilot);

    return popup;
}


#macro BUTTON_SPRITE_CACHE global.__button_sprite_cache
BUTTON_SPRITE_CACHE = Map();

function preload_button_sprite_cache() {
    var prefixes = fiddle_get("ui/misc/button_sprite_prefixes");
    for (var i = 0; i < array_length(prefixes); i++) {
        load_button_sprites(prefixes[i]);
    }
}

function load_button_sprites(key) {
    static PRE_LOADED = HashSetFromArray(fiddle_get("ui/misc/button_sprite_prefixes"));

    if BUTTON_SPRITE_CACHE.contains_key(key) {
        return BUTTON_SPRITE_CACHE.get(key);
    }

    if DEBUG_ASSERTIONS && !PRE_LOADED.contains(key) {
        warn("Button sprites for '{}' are not preloaded -- please add it to ui/misc.toml!", key);
    }

    var enabled_sprite = ((try_string_to_asset(key + "_enabled")
        ?? try_string_to_asset(key + "_default"))
        ?? try_string_to_asset(key + "_main"))
        ?? string_to_asset(key);
    var pressed_sprite = (try_string_to_asset(key + "_pressed")
        ?? try_string_to_asset(key + "_tapped"))
        ?? enabled_sprite;
    var locked_sprite = (try_string_to_asset(key + "_disabled")
        ?? try_string_to_asset(key + "_locked"))
        ?? enabled_sprite;
    var selected_sprite = try_string_to_asset(key + "_selected") ?? pressed_sprite;
    var hovered_sprite = (try_string_to_asset(key + "_hovered")
        ?? try_string_to_asset(key + "_highlighted"))
        ?? enabled_sprite;
    var hovered_untappable_sprite = try_string_to_asset(key + "_hovered_untappable") ?? hovered_sprite;

    var output = {
        enabled_sprite,
        pressed_sprite,
        locked_sprite,
        selected_sprite,
        hovered_sprite,
        hovered_untappable_sprite,
    };

    BUTTON_SPRITE_CACHE.insert(key, output);

    return output;
}

function sprite_font_width(input_text, sprite_font_name) {
    var sprite_font = SPRITE_FONTS[$ sprite_font_name];

    assert_neq(sprite_font, undefined, "`{}` was not a valid sprite_font", sprite_font_name);

    var width = 0;
    //
    for (var i = 1; i <= string_length(input_text); i++) {
        var char = string_char_at(input_text, i);
        width += sprite_font.characters[$ char] ?? 0;
    }
    return width;
}

function create_naming_popup(animal_to_render) {
    var popup = ANCHOR.spawn_menu(Menu.Popup);

    popup.backplate.set_size(176, 130);

    popup.inner_backplate = ANCHOR.nine_slice(popup.backplate)
        .set_sprite(spr_ui_haydenstock_namescreen_box_outer)
        .set_size(160, 84)
        .set_align(Align.Center, Align.TopIn)
        .set_y(12)

    popup.image_background = ANCHOR.nine_slice(popup.inner_backplate)
        .set_sprite(spr_ui_haydenstock_namescreen_box_inner)
        .set_size(48, 32)
        .set_y(8)
        .set_align(Align.Center, Align.TopIn)

    popup.name_input_plate = ANCHOR.nine_slice(popup.image_background)
        .set_sprites_from_key("spr_ui_ranching_text_input_box")
        .set_size(ANIMAL_NAME_MAX_WIDTH + 8, 20)
        .add_to_pilot(popup.pilot)
        .set_y(11)
        .set_align(Align.Center, Align.BottomOut);

    popup.name_input = ANCHOR.text(popup.name_input_plate)
        .set_align(Align.Center, Align.Middle)
        .set_max_width(popup.name_input_plate.get_width())
        .set_lut(COMMON_LUT)

    popup.name_input_plate
        .set_tap_callback(function(popup) {
            var popup_builder = popup_creator("misc_local/enter_new_name")
                .use_pilot(false);
            popup_builder.manual_exit_listening = false;

            popup_builder.canvas.add_z(-100);
            popup_builder.backplate.add_z(-100);
            popup_builder.header.add_z(-100);
            popup_builder.title.add_z(-100);

            //
            //
            //
            popup_builder.canvas.layer = AnchorLayer.Debug;
            popup_builder.backplate.layer = AnchorLayer.Debug;
            popup_builder.header.layer = AnchorLayer.Debug;
            popup_builder.title.layer = AnchorLayer.Debug;

            popup_builder.background_layer = AnchorLayer.Debug;
            popup_builder.background_z = popup_builder.canvas.get_z() + 1;

            text_input_popup_configuration(
                popup_builder,
                popup.name_input.get_text(),
                ANIMAL_NAME_MAX_WIDTH,
                function(txt, popup) {
                    popup.name_input.set_text(txt);
                },
                [popup]
            );

            //
        }, [popup])

    popup.random_button = ANCHOR.nine_slice(popup.inner_backplate)
        .set_align(Align.RightIn, Align.BottomIn)
        .set_xy(-8, -11)
        .set_size(22)
        .add_to_pilot(popup.pilot, true)
        .set_sprites_from_key("spr_ui_button")
        .add_hover_outline()

    popup.random_icon = ANCHOR.sprite(popup.random_button)
        .set_sprites_from_key("spr_ui_ranching_adoption_dice_button")
        .set_align(Align.Center, Align.Middle)
        .set_key_sprite_target(popup.random_button)

    return popup;
}

function asset_local_insert() {
    var insert = local_language();
    insert = string_replace(insert, "-", "_");
    insert = string_lower(insert);
    return insert;
}

function render_kitchen_tier(parent, tier) {
    var root = ANCHOR.positional(parent);

    root.icon = ANCHOR.sprite(root)
        .set_sprite(string_to_asset(format("spr_ui_tooltip_icon_kitchen_level_{}", asset_local_insert())))
        .set_align(Align.LeftIn, Align.Middle)

    root.text = ANCHOR.text(root)
        .set_x(1)
        .set_align(Align.RightIn, Align.Middle)
        .set_sprite_font("player_level")
        .set_lut(COMMON_LUT, CommonLutIndex.Green)
        .set_text(string(tier))

    root.set_width_for_nodes([root.icon, root.text]);
    root.set_height(root.icon.get_height());

    return root;
}
