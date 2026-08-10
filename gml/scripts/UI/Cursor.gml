#macro CURSOR global.__cursor
CURSOR = undefined;

enum CursorType {
    None,
    Default,
    X,
    Tap,
    Point,
    Sell
}

function Cursor(render_strategy) constructor {
    self.type = CursorType.None;
    self.render_strategy = render_strategy;
    window_hide_cursor();

    self.cursor_type_to_sprite = [
        spr_illegal_16,
        spr_cursor_mouse_cursor_idle,
        spr_cursor_mouse_cursor_blocked,
        spr_cursor_mouse_cursor_grab,
        spr_cursor_mouse_cursor_interact,
        spr_cursor_mouse_cursor_sell
    ];

    function step() {
        switch self.render_strategy {
            case CursorRender.None:
                return;
            case CursorRender.OnGpu:
                window_hide_cursor();
                return;
            case CursorRender.Software:
                if self.type == CursorType.None || window_has_mouse() == false {
                    window_hide_cursor();
                } else {
                    var sprite = self.cursor_type_to_sprite[self.type];
                    window_set_cursor_sprite_ext(sprite, DISPLAY.asset_resize());
                }
                break;
        }
    }

    //
    function render_cursor_manually(xx, yy, resize) {
        if window_has_mouse() && self.type != CursorType.None {
            draw_sprite_ext(
                self.cursor_type_to_sprite[self.type],
                0,
                xx,
                yy,
                resize,
                resize,
                0,
                c_white,
                1.0
            );
        }
    }
}

enum CursorRender {
    None,
    OnGpu,
    Software,
}
