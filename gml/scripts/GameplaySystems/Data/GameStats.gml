#macro GAME_STATS global.__game_stats
global.__game_stats = undefined;

#macro GS_MINES_FLOOR GS_MINES_RUN.current_floor_data
#macro GS_MINES_RUN GAME_STATS.current_mines_run

#macro GS_MINES_FLOOR_WRITTEN global.__mines_floor_written
GS_MINES_FLOOR_WRITTEN = false;

function GameStats() {
    return {
        npcs_spoken_to: {},
        gifts_given: {},
        location_visits: {},
        menu_opens: {},
        perks: {},
        items_cooked: [],
        items_milled: [],
        items_forged: [],
        items_woodcrafted: [],
        items_refined: [],
        items_eaten: [],
        bugs_caught: [],
        bugs_missed: 0,
        fish_caught: [],
        fish_missed: 0,
        crop_harvests: [],
        tree_harvests: [],
        forageable_harvests: [],
        npcs_spoken_to: {},
        manual_saves: 0,
        gifts_given: [],
        cutscenes_skipped: 0,
        location_visits: {},
        items_sold_each_day: [],
        end_of_day_stats: [],
        gross_essence: 0,
        bedtimes: [],
        menu_opens: {},
        deaths: 0,
        faints: 0,
        bathhouse_uses: 0,
        enemies_killed: 0,
        conversations: {},
        furniture_placed: {},
        cosmetic_worn: {},
        purchases: [],
        income: [],
        end_of_day_balance: [],
        dives: [],
        basement_lines: [],
        perk_acquirements: [],
        renown_level_ups: [],
        set_completions: [],
        digs: [],
        chicken_statue_uses: [],
        wishing_well_uses: [],
        load_logs: [],
        animals: [],
        animal_eats: [],
        animal_production: [],
        animal_bead_drops: [],
        animal_eod_statuses: [],
        home_upgrades: [],
        current_mines_run: undefined,
        mines_data: []
    }
}

//
//
//
function patch_game_stats(game_stats) {
    static PATCH = function(game_stats, field, len, func) {
        var prop = game_stats[$ field];
        for (var i = 0; i < len; i++) {
            var perk = func(i);
            if prop[$ perk] == undefined {
                prop[$ perk] = 0;
            }
        }
    }

    //
    var prototype = GameStats();
    apply_defaults(game_stats, prototype);

    //
    PATCH(game_stats, "perks", Perk.LEN, perk_to_string);
    PATCH(game_stats, "menu_opens", Menu.LEN, menu_to_string);
    PATCH(game_stats, "npcs_spoken_to", NpcId.LEN, npc_id_to_string);
    PATCH(game_stats, "location_visits", LocationId.LEN, location_id_to_string);

    for (var i = array_length(game_stats.income) - 1; i >= 0; i--) {
        if game_stats.income[i] == 0 {
            array_delete(game_stats.income, i, 1);
        }
    }
}

function game_stats_increment(game_stats, key, value=1) {
    var existing = game_stats[$ key] ?? 0;
    game_stats[$ key] = existing + value;
}

//
function game_stats_serialize_ari_inventory() {
    var inventory = [];

    for (var i = 0; i < ARI.inventory.size(); i++) {
        var slot = ARI.inventory.slot(i);
        if slot.count != 0 {
            array_push(inventory, {
                item: slot.item.pretty_print(),
                count: slot.count,
            });
        }
    }

    return inventory;
}

//
function game_stats_mines_run() {
    GS_MINES_RUN = {
        day_entered: total_days(),
        ari_inventory_size: ARI.inventory.size(),
        time_start: CLOCK.time,
        inventory_on_enter: game_stats_serialize_ari_inventory(),
        inventory_on_exit: undefined,
        status: "unexpected",
        armor: [],

        floor_data: [],
        current_floor_data: undefined,
    };

    for (var i = 0; i < ARI.armor.size(); i++) {
        var item = ARI.armor.slot(i).item;
        if item != undefined {
            array_push(GS_MINES_RUN.armor, item.pretty_print());
        }
    }
}

//
function game_stats_current_mines_floor() {
    return {
        room_name: undefined,
        current_floor: undefined,
        status: "unexpected",
        time_start: CLOCK.time,
        time_end: undefined,

        monsters_spawned: [],
        rocks_spawned: [],
        rock_drops: [],
        rocks_broken: [],
        fishes_spawned: [],
        fishing_items: [],
        bugs_spawned: [],
        bugs_caught: [],
        digsites: 0,
        forageables_spawned: [],
        forageables_harvested: [],
        health_on_floor_enter: 0,
        stamina_on_floor_enter: 0,
        health_on_floor_exit: 0,
        stamina_on_floor_exit: 0,
        enemy_kill: {},
        enemy_drops: [],
        pickaxe_spawned_bugs: [],
        snacks: [],
        damages: [],
        artifacts: [],
        whirlpool_uses: 0,
        chest_items_released: [],
        debris_items_released: [],
    };
}

//
function game_stats_end_mines_floor(status) {
    if GS_MINES_RUN == undefined || GS_MINES_FLOOR == undefined || GS_MINES_FLOOR_WRITTEN {
        return;
    }
    GS_MINES_FLOOR.status = status;
    GS_MINES_FLOOR.time_end = CLOCK.time;
    GS_MINES_FLOOR.health_on_floor_exit = ARI.get_health();
    GS_MINES_FLOOR.stamina_on_floor_exit = ARI.get_stamina();

    GS_MINES_FLOOR_WRITTEN = true;
    array_push(GS_MINES_RUN.floor_data, GS_MINES_FLOOR);
}

//
function game_stats_end_mines_run(status) {
    if GS_MINES_RUN == undefined {
        return;
    }
    game_stats_end_mines_floor(status);
    GS_MINES_RUN.status = status;
    GS_MINES_RUN.exit_inventory = game_stats_serialize_ari_inventory();

    //
    GS_MINES_FLOOR = undefined;

    array_push(GAME_STATS.mines_data, GS_MINES_RUN);

    //
    GS_MINES_RUN = undefined;
}

function game_stats_mines_floor_available() {
    return is_dungeon_room(room()) && GS_MINES_RUN != undefined && GS_MINES_FLOOR != undefined;
}

//
function game_stats_get_income_total() {
    var amount = 0;
    for (var i = 0, c = array_length(GAME_STATS.income); i < c; i++;) {
        var income = GAME_STATS.income[i];
        amount += income.amount;
    }
    return amount;
}
