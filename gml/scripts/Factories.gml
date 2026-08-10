enum FactoryTier {
    Mixed,
    Common,
    Uncommon,
    Rare,
    Legendary,
    LEN
}

#macro FACTORY_INSPECT_CTX global.__factory_inspect_ctx
FACTORY_INSPECT_CTX = undefined;

#macro FACTORIES global.__factories
FACTORIES = undefined;


//
function factory_generate_listings(node, menu) {
    if menu.factory_listings != undefined {
        ANCHOR.free_children(menu.factory_listings);
    }
    var yy = 0;
    var factory_prototype_data = node.prototype.factory;
    var factory_index = factory_rewards_index(menu.left);
    for (var i = 0, ic = array_length(factory_prototype_data.rewards_map); i < ic; i++) {
        var listing = factory_prototype_data.rewards_map[i];
        var root = ANCHOR.positional(menu.factory_listings)
            .set_align(Align.LeftIn, Align.BottomOut)
            .set_size(menu.left_box.get_width() - 18, 16)
            .set_xy(5, yy - 7)
            .set_lut(COMMON_LUT, 7);

        var bg = ANCHOR.nine_slice(root)
            .set_sprites_from_key( i % 2 == 0 ? "spr_ui_generic_box_alt" : "spr_ui_generic_box_main")
            .set_width(menu.left_box.get_width() - 4)
            .set_height(20)
            .set_x(-3)
            .set_align(Align.LeftIn, Align.TopIn);

        var icon = ANCHOR.sprite(root)
            .set_sprite(factory_index == i ? spr_ui_apiary_terrarium_checkbox_on : spr_ui_apiary_terrarium_checkbox_off)
            .set_y(1)
            .set_align(Align.LeftIn, Align.Middle);

        ANCHOR.text(icon)
            .set_key(format("misc_local/factory_{FactoryTier}", i))
            .set_x(5)
            .set_lut(COMMON_LUT, factory_index == i ? 3 : 18)
            .set_align(Align.RightOut, Align.Middle);

        var xx = 0;
        for (var j = 0, jc = array_length(listing); j < jc; j++) {
            var item_id = listing[j];
            ANCHOR.sprite(bg)
                .set_sprite(ITEM_PROTOTYPES[item_id].icon_sprite)
                .set_align(Align.RightIn, Align.Middle)
                .set_x(xx)
                .set_color(ARI.items_acquired[item_id] ? c_white : MUSEUM_LOCKED_OVERLAY);
            xx -= sprite_get_width(ITEM_PROTOTYPES[item_id].icon_sprite);
        }

        yy += 19;
    }

    return yy;
}

//
function factory_generate_storage_menu(node) {
    var factory_prototype_data = node.prototype.factory;
    var menu = ANCHOR.spawn_menu(Menu.Storage)
        .set_inventories(node.inventory, ARI.inventory)
        .with_right_banner()
        .with_tags(factory_prototype_data.legal_tags, factory_prototype_data.illegal_tags)
        .with_alt_stack_behavior()
        .with_left_help_button()
        .with_pull_button(false)
        .with_left_banner()
        .build();

    var storage_info = fiddle_get(format("{}/{}", factory_prototype_data.ui_data, menu.left.size()));

    menu.left_menu.play_special_full_sound = true;
    menu.right_box.set_xy(storage_info.backpack_x, 4);
    menu.left_banner.banner.set_y(3);
    menu.factory_listings = ANCHOR.positional(menu.canvas)
        .set_xy(storage_info.storage_x, 8)
        .set_align(Align.LeftIn, Align.Middle);
    menu.left_box.set_sprite(string_to_asset(storage_info.backplate));
    menu.left_box.set_xy(storage_info.storage_x, storage_info.storage_y);
    menu.factory_subscriber = new InventorySubscriber(menu.left);
    menu.left_box.set_think_callback(function(node, menu) {
        if !menu.factory_subscriber.pull().is_empty() {
            factory_generate_listings(node, menu);
        }
    }, [node, menu]);

    var parent_root = ANCHOR.positional(menu.left_box)
        .set_align(Align.LeftIn, Align.BottomOut)

    var yy = factory_generate_listings(node, menu);
    var header = ANCHOR.nine_slice(parent_root)
        .set_sprite(string_to_asset(storage_info.header))
        .set_align(Align.LeftIn, Align.TopIn)
        .set_size(menu.left_box.get_width(), 22)
        .set_y(1);

    ANCHOR.text(header)
        .set_align(Align.Center, Align.Middle)
        .set_lut(COMMON_LUT, CommonLutIndex.Header)
        .set_text_align(TextAlign.Center)
        .set_key(storage_info.header_local)
        .set_lut(COMMON_LUT, CommonLutIndex.BlackOnGold);

    menu.listing_plate = ANCHOR.nine_slice(header)
        .set_sprite(string_to_asset(storage_info.guide_box))
        .set_width(menu.left_box.get_width())
        .set_align(Align.Center, Align.TopIn);

    menu.left_banner.help.set_tap_callback(function() {
        spawn_tutorial(Tutorial.ApiariesAndTerrariums);
    }, [], true);

    menu.listing_plate.set_height(yy + header.get_height() + 1);
    var total_height = menu.listing_plate.get_height();
    menu.left_box.set_y(total_height / 2 - 114);

    menu.factory_node = node;
    menu.on_close = method(menu, function() {
        factory_node_set_full(self.factory_node);
    });
}

function factory_rewards_index(inventory) {
    var rarity = undefined;
    if inventory.total_items() != inventory.size() {
        return undefined;
    }
    for (var i = 0, ic = inventory.size(); i < ic; i++) {
        var item = inventory.slot(i).item;
        if item == undefined {
            continue;
        }
        var prototype = BUGS.get(item.item_id);
        if rarity == undefined {
            rarity = prototype.rarity;
        } else if prototype.rarity != rarity {
            return FactoryTier.Mixed;
        }
    }

    switch rarity {
        case "common":
            return FactoryTier.Common;
        case "uncommon":
            return FactoryTier.Uncommon;
        case "rare":
            return FactoryTier.Rare;
        case "legendary":
        case "very_rare":
            return FactoryTier.Legendary;
    }
}

function factory_node_set_full(node) {
    if node.renderer.sound_controller != undefined {
        node.renderer.sound_controller.force_stop();
        node.renderer.sound_controller = undefined;
    }

    if node.object_id == ObjectId.Terrarium {
        stop_terrarium_sound_chain(node);
    }

    if node.inventory.total_items() == node.prototype.factory.inventory_size {
        node.renderer.set_sprite(node.prototype.factory.full_sprite);

        if node.object_id == ObjectId.Terrarium {
            run_terrarium_sound_chain(node);
        } else {
            var asset = node.prototype.factory.full_sounds[irandom(array_length(node.prototype.factory.full_sounds) - 1)];
            node.renderer.sound_controller = new SoundInstanceController(TANGO.play(asset, node.renderer.x, node.renderer.y));
        }
    } else {
        node.renderer.set_sprite(node.prototype.cardinal_data[node.cardinal_index].sprite);
        node.production_request = undefined;
        node.production_tier = undefined;
    }
}

function run_terrarium_sound_chain(node) {
    with node.renderer {
        self.sound_chain = new_world_chain(self, CURRENT_LOCATION_ID)
            .append(LinkId.Await, function() {
                static KEYFRAMES = [1, 6, 15, 26];
                var this_index = floor(self.image_index);
                if array_has(KEYFRAMES, this_index) && self.sound_keyframe_last != this_index {
                    self.sound_keyframe_last = this_index;
                    return true;
                }
                return false;
            })
            .append(LinkId.Function, function() {
                TANGO.play(self.node.prototype.factory.full_sounds[0], self.x, self.y);
                run_terrarium_sound_chain(self.node);
            })
    }
}

function stop_terrarium_sound_chain(node) {
    if node.renderer.sound_chain != undefined {
        CHAINS.cancel_chain(node.renderer.sound_chain);
        node.renderer.sound_chain = undefined;
    }
}
