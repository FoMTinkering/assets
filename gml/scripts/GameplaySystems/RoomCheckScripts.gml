function is_world_room(_room) {
    return !is_menu_room(_room);
}
function is_menu_room(_room) {
    return _room == rm_menu;
}
function is_dungeon_room(_room) {
    var rc = room_class(_room);
    return rc == RoomClass.Dungeon || rc == RoomClass.DungeonSpecial;
}
function is_special_dungeon_room(_room) {
    return room_class(_room) == RoomClass.DungeonSpecial;
}
