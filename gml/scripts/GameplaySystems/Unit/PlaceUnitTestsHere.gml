//
function define_unit_tests(framework) {
    framework.new_test("Craft All Items", function() { crafting_test(); });
    framework.new_test("Fish Bounce Angles", function() { fish_bounce_test(); });
    framework.new_test("Historical Votes", function() { historical_votes_test(); });
    framework.new_test("Item String Functions", function() { item_string_functions(); });
    framework.new_test("Keycode Strings", function() { test_keycode_strings(); });
    framework.new_test("Location Room Functions", function() { location_room_functions(); });
    framework.new_test("Matrix tests", function() { mat_unit_tests(); });
    framework.new_test("Mist Unit Test", function() { mist_unit_test(); });
    framework.new_test("archaeology_xp_functions", function() { test_archaeology_xp_functions(); });
    framework.new_test("auto_feeder_items", function() { test_auto_feeder_items(); });
    framework.new_test("blacksmithing_xp_functions", function() { test_blacksmithing_xp_functions(); });
    framework.new_test("combat_xp_functions", function() { test_combat_xp_functions(); });
    framework.new_test("condition_clone", function() { condition_clone(); });
    framework.new_test("cooking_xp_functions", function() { test_cooking_xp_functions(); });
    framework.new_test("description_fish_size", function() { test_description_fish_size(); });
    //
    framework.new_test("description_rarity", function() { test_description_rarity(); });
    framework.new_test("description_seasonal_validity", function() { test_description_seasonal_validity(); });
    //
    framework.new_test("dungeon_itineraries", function() { test_dungeon_itineraries(); });
    framework.new_test("farming_xp_functions", function() { test_farming_xp_functions(); });
    framework.new_test("fishing_xp_functions", function() { test_fishing_xp_functions(); });
    framework.new_test("gift_dialogue", function() { test_gift_dialogue(); });
    framework.new_test("hex_conversion", function() { test_hex_conversion(); });
    framework.new_test("inn_plates", function() { test_inn_plates(); });
    framework.new_test("inventory", function() { inventory_unit_test(); });
    framework.new_test("item_price_parsing", function() { test_item_price_parsing(); });
    framework.new_test("live_item_partial_eq", function() { test_live_item_partial_eq(); });
    framework.new_test("mining_xp_functions", function() { test_mining_xp_functions(); });
    framework.new_test("most_special_human", function() { test_most_special_human(); });
    framework.new_test("museum_wing_ui_registration", function() { test_museum_wing_ui_registration(); });
    framework.new_test("ranching_xp_functions", function() { test_ranching_xp_functions(); });
    framework.new_test("ranges_overlap", function() { test_ranges_overlap(); });
    framework.new_test("recipes_are_set_up", function() { test_recipes_are_set_up(); });
    framework.new_test("semver-parse", function() { test_semver_parsing(); });
    framework.new_test("skill_xp_paralleled", function() { test_skill_xp_paralleled(); });
    framework.new_test("woodcrafting_xp_functions", function() { test_woodcrafting_xp_functions(); });
}
