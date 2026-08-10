object_create(
    "obj_hayden_store",
    object_reserve("par_ledger"),
    {
        sprite_index: spr_hayden_ledger_spring,
        create: function() {
            event_inherit(ObjectEvent.Create);

            self.darkness_sprite = spr_hayden_ledger_darkness;
            self.name = "hayden_store";

            function spawn_menu() {
                self.mcp = new MultipleChoicePopup("stores/hayden/name", spr_ui_haydenstock_icon_hayden);
                self.mcp.option("misc_local/farm_supplies", function() {
                    var shop = ANCHOR.spawn_menu(Menu.Store, Store.Hayden);
                    shop.background.in_now();
                    self.mcp.popup.background.out_now();

                    shop.on_free = function() {
                        var menu = ANCHOR.get_menu(Menu.Store);
                        if menu.tooltip != undefined {
                            menu.tooltip.close();
                        }
                        obj_hayden_store.spawn_menu();
                    }
                });
                self.mcp.option("misc_local/adoption", function() {
                    var adoption = ANCHOR.spawn_menu(Menu.Adoption);
                    adoption.background.in_now();
                    self.mcp.popup.background.out_now();

                    adoption.on_free = function() {
                        obj_hayden_store.spawn_menu();
                    }
                });
                self.mcp.option("misc_local/daycare", function() {
                    var daycare = ANCHOR.spawn_menu(Menu.Daycare);
                    daycare.background.in_now();
                    self.mcp.popup.background.out_now();

                    daycare.on_free = function() {
                        obj_hayden_store.spawn_menu();
                    }
                });
                self.mcp.option("misc_local/sell_animals", function() {
                    var sell_animals = ANCHOR.spawn_menu(Menu.SellAnimals);
                    sell_animals.background.in_now();
                    self.mcp.popup.background.out_now();

                    sell_animals.on_free = function() {
                        obj_hayden_store.spawn_menu();
                    }
                });
            }

            self.register_interaction(
                InputId.Interact,
                "misc_local/shop",
                function() {
                    self.spawn_menu();
                },
                function() {
                    return ARI.held_animal_id == undefined;
                }
            );

            depth = get_instance_depth(y);
        },
    }
);
