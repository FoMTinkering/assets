#macro GAME_STATS global.__game_stats
global.__game_stats = undefined;

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

    //
    struct_remove(game_stats, "current_mines_run");
    struct_remove(game_stats, "mines_data");
}

function game_stats_increment(game_stats, key, value=1) {
    var existing = game_stats[$ key] ?? 0;
    game_stats[$ key] = existing + value;
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
