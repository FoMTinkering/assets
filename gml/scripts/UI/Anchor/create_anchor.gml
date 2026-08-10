global.__anchor = undefined;
#macro ANCHOR global.__anchor

global.__bugger = undefined;
#macro BUGGER global.__bugger

function create_anchor() {
    ANCHOR = new Anchor();
    ANCHOR.initialize();
    GLYPH_GUIDE = ANCHOR.spawn_menu(Menu.GlyphGuide);
    SCREEN_FADER = ANCHOR.spawn_menu(Menu.ScreenFader);
}
