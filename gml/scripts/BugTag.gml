enum BugTag {
    NONE = 0,
    STANDARD = 1 << 0,
    WATER_BUG = 1 << 1,
    DEEP_WOODS = 1 << 2,
    BEACH = 1 << 3,
    MINES = 1 << 4,
}

function parse_bug_tag(input) {
    var output = BugTag.NONE;
    if input == false {
        return output;
    }

    assert_eq(typeof(input), "array", "bug tag parses only arrays!");

    for (var i = 0; i < array_length(input); i++) {
        switch input[i] {
            case "standard":
                output = set_flag(output, BugTag.STANDARD);
                break;
            case "water_bug":
                output = set_flag(output, BugTag.WATER_BUG);
                break;
            case "deep_woods":
                output = set_flag(output, BugTag.DEEP_WOODS);
                break;
            case "beach":
                output = set_flag(output, BugTag.BEACH);
                break;
            case "mines":
                output = set_flag(output, BugTag.MINES);
                break;
            default: impossible("unexpected bug_tag: {}", input[i]);
        }
    }

    return output;
}
