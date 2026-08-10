function BabyJournalMenu() : AnchorMenu(Menu.BabyJournal) constructor {
    self.sub_menu = undefined;

    function on_close() {
        self.sub_menu.close();
    }

    function give_sub_menu(sub_menu) {
        self.sub_menu = sub_menu;
        self.sub_menu.journal = self;
    }

    create_journal_nodes(self.canvas, self);
}

//
function spawn_baby_journal(sub_menu) {
    var baby = ANCHOR.spawn_menu(Menu.BabyJournal);
    baby.give_sub_menu(sub_menu);
    return baby;
}
