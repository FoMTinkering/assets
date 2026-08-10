#macro GAME_VERSION global.__game_version
global.__game_version = undefined;

#macro TEST_TARGET_VERSION global.__test_target_version
global.__test_target_version = undefined;

function string_to_version(str) {
    var working_str = "";
    var numerals = [];
    for (var i = 1; i <= string_length(str); i++) {
        var char = string_char_at(str, i);
        if string_digits(char) == char {
            working_str += char;
        } else {
            array_push(numerals, int64(working_str));
            working_str = "";
            if char == "-" {
                assert_eq(array_length(numerals), 3);
                i += 1;
                assert_eq(string_char_at(str, i), "p");
                i += 1;
                assert_eq(string_char_at(str, i), "r");
                i += 1;
                assert_eq(string_char_at(str, i), "e");
                i += 1;
                working_str += string_char_at(str, i);
            }
        }
    }
    array_push(numerals, int64(working_str));

    return {
        major: numerals[0],
        minor: numerals[1],
        patch: numerals[2],
        pre: array_length(numerals) > 3 ? numerals[3] : undefined,
    };
}

function version_to_string(ver) {
    var pre_insert = ver.pre != undefined ? format("-pre{}", ver.pre) : "";
    return format("{}.{}.{}{}", ver.major, ver.minor, ver.patch, pre_insert);
}

function version_is_ahead(v1, v2) {
    switch sign(v1.major - v2.major) {
        case 1: return true;
        case -1: return false;
        default:
            //
    }

    switch sign(v1.minor - v2.minor) {
        case 1: return true;
        case -1: return false;
        default:
            //
    }

    switch sign(v1.patch - v2.patch) {
        case 1: return true;
        case -1: return false;
        default:
            //
    }

    //
    switch sign(sign((v1.pre ?? I32_MAX) - (v2.pre ?? I32_MAX))) {
        case 1: return true;
        case -1: return false;
        default:
            //
    }

    //
    return false;
}

function versions_match(a, b) {
    return a.major == b.major
        && a.minor == b.minor
        && a.patch == b.patch
        && a.pre == b.pre;
}

//
function test_semver_parsing() {
    static ASSERT_SEMVER_EQ = function(a, b) {
        assert(
            versions_match(a, b),
            "SemVer's do not match: {SemVer} and {SemVer}",
            a,
            b,
        );
    }

    ASSERT_SEMVER_EQ(
        string_to_version("1.2.3-pre4"),
        { major: 1, minor: 2, patch: 3, pre: 4 },
    );

    ASSERT_SEMVER_EQ(
        string_to_version("0.0.0"),
        { major: 0, minor: 0, patch: 0, pre: undefined },
    );

    ASSERT_SEMVER_EQ(
        string_to_version("11.22.33-pre44"),
        { major: 11, minor: 22, patch: 33, pre: 44 },
    );

    ASSERT_SEMVER_EQ(
        string_to_version("0.0.0-pre2"),
        { major: 0, minor: 0, patch: 0, pre: 2 },
    );

    assert(version_is_ahead(string_to_version("0.0.1"), string_to_version("0.0.0")));
    assert(version_is_ahead(string_to_version("0.1.0"), string_to_version("0.0.9")));
    assert(version_is_ahead(string_to_version("1.0.0"), string_to_version("0.9.0")));
    assert(version_is_ahead(string_to_version("0.0.0"), string_to_version("0.0.0-pre0")));
    assert(version_is_ahead(string_to_version("0.0.0-pre2"), string_to_version("0.0.0-pre1")));
    assert(version_is_ahead(string_to_version("0.0.0-pre40"), string_to_version("0.0.0-pre0")));

    assert(!version_is_ahead(string_to_version("0.0.1"), string_to_version("0.0.2")));
    assert(!version_is_ahead(string_to_version("0.1.10"), string_to_version("0.2.0")));
    assert(!version_is_ahead(string_to_version("1.200.0-pre0"), string_to_version("2.0.0")));
    assert(!version_is_ahead(string_to_version("0.0.0-pre0"), string_to_version("0.0.0-pre40")));

    //
    assert(!version_is_ahead(string_to_version("0.0.0-pre0"), string_to_version("0.0.0-pre0")));
    assert(!version_is_ahead(string_to_version("0.12.4"), string_to_version("0.12.4")));
}
