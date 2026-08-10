function RenownChestMenu() : AnchorMenu(Menu.RenownChest) constructor {

    self.box = ANCHOR.sprite(self.canvas)
        .set_align(Align.Center, Align.Middle)
        .set_y(50)
        .set_sprite(spr_ui_renown_chest_backplate)

    self.title = ANCHOR.text(self.box)
        .set_align(Align.Center, Align.TopIn)
        .set_key("misc_local/rewards")
        .set_lut(spr_ui_renown_chest_font_lut)
        .set_y(16)

    self.inventory_ui = new InventoryMenu(4, RENOWN_REWARD_INVENTORY, self.new_pilot());
    self.inventory_ui.idle_slot_sprite = spr_ui_renown_chest_item_slot_enabled;
    self.inventory_ui.hover_slot_sprite = spr_ui_renown_chest_item_slot_highlighted;
    self.inventory_ui.build(
        0,
        12,
        self.box,
        Align.Center,
        Align.Middle,
    );

    self.inventory_ui.input_check = function(index) {
        if ANCHOR.take_tap() {
            var slot = self.inventory_ui.slots[index];
            if !slot.square.is_unlocked() || RENOWN_REWARD_INVENTORY.slot(index).count == 0 {
                return;
            }
            var items = RENOWN_REWARD_INVENTORY.slot(index).drain();
            var item = items.first();
            var count = items.count();
            repeat count {
                if ARI.inventory.can_add(item) {
                    ARI.inventory.add(item);
                } else {
                    drop_item(item, obj_ari.x, obj_ari.y);
                }
            }
        }
    }

    var nodes = renown_status_widget(self.canvas);
    nodes.backplate.add_y(-50);

    ANCHOR.set_active_pilot(self.inventory_ui.pilot);

}
