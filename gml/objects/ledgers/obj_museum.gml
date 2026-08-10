object_create(
    "obj_museum",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_museum_entryhall_ledger_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.darkness_sprite = spr_museum_entryhall_ledger_darkness;
            self.name = "museum";
            self.menu_inst = undefined;

            self.small_icon = spr_ui_bark_icon_archaeology_small;
            self.big_icon = spr_ui_bark_icon_archaeology;

            function spawn_menu() {
                self.mcp = new MultipleChoicePopup("misc_local/donate", spr_ui_generic_museum_sub_icon);

                self.mcp.option("misc_local/donate", function() {
                    self.menu_inst = spawn_museum_donation_menu();

                    self.menu_inst.background.in_now();
                    self.mcp.popup.background.out_now();

                    self.menu_inst.on_free = function() {
                        self.menu_inst.left.drain().for_each(function(item) {
                            drop_item(item, obj_ari.x, obj_ari.y);
                        });

                        await_popup(self.spawn_menu);
                    }
                });
                self.mcp.buttons.last().add_width(40);

                self.mcp.option("misc_local/view_wings", function() {
                    self.menu_inst = ANCHOR.spawn_menu(Menu.Museum);
                    self.menu_inst.background.in_now();
                    self.mcp.popup.background.out_now();

                    self.menu_inst.on_free = function() {
                        self.spawn_menu();
                    }
                })
                self.mcp.buttons.last().add_width(40);
            }

            self.register_interaction(
                InputId.Interact,
                "misc_local/interact",
                function() {
                    self.spawn_menu();
                },
            );

            depth = get_instance_depth(y, -10);
        },
    }
);
