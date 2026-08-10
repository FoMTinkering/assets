function GossipMenu() : AnchorMenu(Menu.Gossip) constructor {

    function on_close() {
        if self.chain != undefined && self.chain.running {
            CHAINS.cancel_chain(self.chain);
        }
        if self.tooltip != undefined {
            self.tooltip.close();
        }
        if self.popup != undefined {
            self.popup.close();
        }
    }

    function create_card(selection, parent) {
        var proto = NPC_PROTOTYPES[selection.npc];
        var portrait_pos = proto.journal_portrait_offset;
        var color = proto.journal_background_color;
        var portrait_sprite = NPCS[selection.npc].wardrobe.outfit_current.portraits.get("neutral")
            ?? NPCS[selection.npc].wardrobe.outfits.get(proto.fallback_outfit).portraits.get("neutral");

        var card = ANCHOR.sprite(parent)
            .set_sprite(spr_ui_journal_relationship_photo_bg)
            .set_color(make_color_rgb(color[0], color[1], color[2]))

        var canvas = ANCHOR.canvas(card)
            .set_size(card.get_size())
            .set_render_partial(0, 0, card.get_width(), card.get_height())

        card.portrait = ANCHOR.sprite(canvas)
            .set_sprite(portrait_sprite)
            .set_xy(portrait_pos[0], portrait_pos[1])

        card.frame = ANCHOR.sprite(card)
            .set_position(-12, -10, canvas.get_z() - 10)

        if proto.dateable {
            card.frame.set_sprites_from_key("spr_ui_gift_hint_card_dateable");
        } else if array_has(proto.tags, "vendor") {
            card.frame.set_sprites_from_key("spr_ui_gift_hint_card_vendor");
        } else {
            card.frame.set_sprites_from_key("spr_ui_gift_hint_card_villager");
        }

        ANCHOR.sprite(card.frame)
            .set_sprite(selection.is_loved ? spr_ui_gift_hint_icon_loved : spr_ui_gift_hint_icon_liked)
            .set_align(Align.RightIn, Align.BottomIn)
            .set_xy(-12, -28)

        var ribbon = ANCHOR.sprite(card.frame)
            .set_sprite(selection.is_loved ? spr_ui_gift_hint_ribbon_loved : spr_ui_gift_hint_ribbon_liked)
            .set_align(Align.Center, Align.BottomIn)
            .set_y(-8)

        ANCHOR.text(ribbon)
            .set_key(selection.is_loved ? "misc_local/loved_gift" : "misc_local/liked_gift")
            .set_align(Align.Center, Align.Middle)
            .set_y(1)
            .set_lut(COMMON_LUT, selection.is_loved ? CommonLutIndex.BlackOnRed : CommonLutIndex.BlackOnGold)

        var count_zone = ANCHOR.positional(card.frame)
            .set_align(Align.RightIn, Align.BottomIn)
            .set_xy(-28, -28)
            .set_size(20, 9)

        var source = selection.is_loved ? proto.loved_gifts : proto.liked_gifts;
        var total = source.count();
        var discovered = source.sum_with(function(v, proto) {
            return NPCS[proto.id].known_gift_preferences.contains(v) ? 1 : 0;
        }, [proto])

        ANCHOR.text(count_zone)
            .set_align(Align.Center, Align.Middle)
            .set_sprite_font("item_count")
            .set_text(format("{}/{}", discovered, total))

        var base_name = proto.dateable ? "spr_ui_gift_hint_nameplate_ribbon_dateable" : "spr_ui_gift_hint_nameplate_ribbon";
        var nameplate = ANCHOR.sprite(card.frame)
            .set_sprite(string_to_asset(format("{}_{}", base_name, selection.is_loved ? "loved" : "liked")))
            .set_xy(15, 7)

        var sprites = proto.dateable
            ?  fiddle_get("ui/textbox/dateable_heart_sprites")
            :  fiddle_get("ui/textbox/non_dateable_heart_sprites")
        var sprite = string_to_asset(sprites[NPCS[proto.id].heart_level()]);

        ANCHOR.sprite(nameplate)
            .set_sprite(sprite)
            .set_align(Align.LeftIn, Align.Middle)
            .set_x(-7)

        var text_zone = ANCHOR.positional(nameplate)
            .set_size(32, 11)
            .set_align(Align.RightIn, Align.Middle)

        ANCHOR.text(text_zone)
            .set_sprite_font("aldarian")
            .set_text(proto.aldarian_name)
            .set_align(Align.Center, Align.Middle)
            .set_lut(COMMON_LUT, selection.is_loved ? CommonLutIndex.BlackOnRed : CommonLutIndex.BlackOnGold)

        return card;
    }

    function display_selections(selections) {
        static WIDTH = sprite_get_width(spr_ui_journal_relationship_photo_bg);
        var positions = centered_positions(array_length(selections), WIDTH, 32);

        for (var i = 0; i < array_length(selections); i++) {
            var selection = selections[i];

            var card = self.create_card(selection, self.canvas)
                .set_xy(positions[i], 48)
                .set_align(Align.Center, Align.Middle)
                .set_alpha(0)

            card.frame.add_to_pilot(self.pilot);

            card.frame.set_tap_callback(function(selection) {
                if self.selection_made {
                    return;
                }
                self.selection_made = true;
                TANGO.play("SoundEffects/UI/GossipCardSelect");
                self.lock();
                self.chain = new_chain()
                    .append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 20), function(_, a) {
                        self.canvas.set_alpha(a);
                    })
                    .append(LinkId.Timer, 10)
                    .append(LinkId.Function, function(selection) {
                        self.chain = undefined;
                        ANCHOR.free_children(self.canvas);
                        self.display_gift_sequence(selection);
                    }, [selection])
            }, [selection]);

            var mask = ANCHOR.nine_slice(card)
                .set_size(card.get_size())
                .set_sprite(spr_pixel_nine_slice)

            card.intro_chain = new_chain()
                .append(LinkId.Timer, 20 * i)
                .append(LinkId.Ease, new Ease(EaseId.ElasticOut, card.get_y(), 0, 90), function(_, a, card) {
                    card.set_y(a);
                }, [card])
                .join(LinkId.Ease, new Ease(EaseId.ElasticOut, 0, 1, 90), function(_, a, card, mask) {
                    card.set_alpha(a);
                    mask.set_alpha(1 - a);
                }, [card, mask])
                .join(LinkId.Function, function(i) {
                    TANGO.play(format("SoundEffects/UI/GossipCardPopup{}", i + 1));
                }, [i]);

            self.cards.push(card);
        }

        ANCHOR.set_active_pilot(self.pilot);
    }

    function display_gift_sequence(selection) {
        NPCS[selection.npc].known_gift_preferences.insert(selection.gift);
        refresh_achievements([Requirement.AllNpcGiftsDiscovered]);
        ARI.has_gossiped_today = true;

        self.unlock();

        self.popup = popup_creator();
        self.popup.backplate.set_size(200, 176);
        var root = ANCHOR.positional(self.popup.backplate)
            .set_width(92, 130)
            .set_xy(-10, 4)
            .set_align(Align.RightIn, Align.TopIn)
        var gifts = gift_preferences_ui(root);
        gifts.set_to_npc(selection.npc);

        var card = self.create_card(selection, self.popup.backplate)
            .set_align(Align.LeftIn, Align.TopIn)
            .set_xy(17, 32);

        var node_to_highlight = undefined;
        for (var i = 0; i < gifts.icons.count(); i++) {
            var icon = gifts.icons.get(i);
            if icon.item_id == selection.gift {
                node_to_highlight = icon;
            }
        }
        assert_neq(node_to_highlight, undefined, "Could not find a node for {ItemId}!", selection.gift);

        node_to_highlight.set_alpha(0.5);

        var temp = ANCHOR.sprite(node_to_highlight)
            .set_align(Align.Center, Align.Middle)
            .set_sprite(node_to_highlight.get_sprite())
            .set_color(MUSEUM_LOCKED_OVERLAY)

        ANCHOR.sprite(node_to_highlight)
            //
            .set_sprite(spr_fx_item_icon_sparkle)
            .set_speed(1)

        self.chain = new_chain()
            .append(LinkId.Timer, 20)
            .append(LinkId.Function, function() {
                TANGO.play("SoundEffects/UI/GossipGiftReveal");
            })
            .append(LinkId.Ease, new Ease(EaseId.Linear, 1, 0, 60), function(_, a, temp) {
                temp.set_alpha(a);
            }, [temp])
            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, -96, 45), function(_, a) {
                self.popup.backplate.set_x(a);
            })
            .append(LinkId.Function, function(card, selection) {
                var npc = NPCS[selection.npc];
                var portrait_sprite = npc.wardrobe.outfit_current.portraits.get(npc.prototype.gossip.portrait);
                card.portrait.set_sprite(portrait_sprite);

                var effect = portrait_effect_ui(card.portrait);
                effect.canvas = self.popup.canvas;
                effect.set_z(card.frame.get_z() - 10);
                effect.set(npc.prototype, npc.prototype.gossip.effect);

                rainbow_text(self.popup.backplate, "misc_local/gift_discovered")
                    .set_y(-10)
                    .set_align(Align.Center, Align.TopOut)

                self.tooltip = create_tooltip(selection.gift);

                self.tooltip.backplate.set_x(100);

            }, [card, selection])

        self.popup.create_button("misc_local/close", function() {
            self.close();
        });

        self.popup.manual_exit_listening = false;
        self.popup.mutes_input = false;

        return self.popup.spawn();
    }

    self.pilot = self.new_pilot();
    self.chain = undefined;
    self.selection_made = false;
    self.cards = List();
    self.popup = undefined;
    self.tooltip = undefined;
}

function get_gossip_selections() {
    random_set_seed(Game.unique_identifier + get_days(CALENDAR.time));

    var dateable_pool = List();
    var townsfolk_pool = List();
    var vendor_pool = List();
    for (var i = 0; i < NpcId.LEN; i++) {
        var npc = NPCS[i];
        if !npc_is_unlocked(i) || !npc.has_met() || i == NpcId.Caldarus {
            continue;
        }

        var liked = npc.prototype.liked_gifts.clone()
            .retain(function(gift, npc) {
                return !npc.known_gift_preferences.contains(gift);
            }, npc)
            .remove_random();

        var loved = npc.prototype.loved_gifts.clone()
            .retain(function(gift, npc) {
                return !npc.known_gift_preferences.contains(gift);
            }, npc)
            .remove_random();

        static LOVED_CHANCE = fiddle_get("gossip/loved_chance");
        var gift = undefined;
        var is_loved = false;
        if random(1) <= LOVED_CHANCE && loved != undefined {
            gift = loved;
            is_loved = true;
        } else {
            gift = liked;
        }

        if gift == undefined {
            continue;
        }

        var target = undefined;
        if npc.prototype.dateable {
            target = dateable_pool;
        } else if array_has(npc.prototype.tags, "vendor") {
            target = vendor_pool;
        } else {
            target = townsfolk_pool;
        }

        target.push({
            npc: npc.id,
            gift,
            is_loved,
        });
    }

    var pools = ListFromArray([dateable_pool, townsfolk_pool, vendor_pool]);
    var selections = [];
    for (var i = 0; i < pools.count(); i++) {
        var selection = pools.get(i).remove_random();
        if selection != undefined {
            array_push(selections, selection);
        }
    }

    while array_length(selections) < 3 {
        var fallback = pools.find_value(function(pool) {
            return !pool.is_empty();
        });
        if fallback == undefined {
            break;
        }
        array_push(selections, fallback.remove_random());
    }

    randomize();

    return selections;
}
