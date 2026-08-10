enum RangePattern {
    One,
    OneByThree,
    ThreeByThree,
    ThreeBySix,
    SixBySix,
    SixByNine,
    LEN
}

//
function range_pattern_to_targets(xx,yy,range_pattern, cardinality) {
    var list = List();
    switch range_pattern {
        case RangePattern.One:
            list.push(Vec2(xx,yy));
            break;
        case RangePattern.OneByThree:
            switch(cardinality) {
                case Cardinal.South:
                    list.push(Vec2(xx,yy));
                    list.push(Vec2(xx,yy+2));
                    list.push(Vec2(xx,yy+4));
                    break;
                case Cardinal.North:
                    list.push(Vec2(xx,yy));
                    list.push(Vec2(xx,yy-2));
                    list.push(Vec2(xx,yy-4));
                    break;
                case Cardinal.West:
                    list.push(Vec2(xx,yy));
                    list.push(Vec2(xx-2,yy));
                    list.push(Vec2(xx-4,yy));
                    break;
                case Cardinal.East:
                    list.push(Vec2(xx,yy));
                    list.push(Vec2(xx+2,yy));
                    list.push(Vec2(xx+4,yy));
                    break;
            }
            break;
        case RangePattern.ThreeByThree:
            switch(cardinality) {
                case Cardinal.South:
                    for (var _x = -2; _x < 4; _x+=2) {
                        for (var _y = 0; _y < 6; _y+=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
                case Cardinal.North:
                    for (var _x = -2; _x < 4; _x+=2) {
                        for (var _y = 0; _y > -6; _y-=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
                case Cardinal.West:
                    for (var _x = 0; _x > -6; _x -= 2) {
                        for (var _y = 2; _y > -4; _y-=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
                case Cardinal.East:
                    for (var _x = 0; _x < 6; _x += 2) {
                        for (var _y = 2; _y > -4; _y-=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
            }

            break;
        case RangePattern.ThreeBySix:
            switch(cardinality) {
                case Cardinal.South:
                    for (var _x = -2; _x < 4; _x+=2) {
                        for (var _y = 0; _y < 12; _y+=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
                case Cardinal.North:
                    for (var _x = -2; _x < 4; _x+=2) {
                        for (var _y = 0; _y > -12; _y-=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
                case Cardinal.West:
                    for (var _x = 0; _x > -12; _x-=2) {
                        for (var _y = -2; _y < 4; _y+=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
                case Cardinal.East:
                    for (var _x = 0; _x < 12; _x+=2) {
                        for (var _y = -2; _y < 4; _y+=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
            }

            break;
        case RangePattern.SixBySix:
            switch(cardinality) {
                case Cardinal.South:
                    for (var _x = -4; _x < 8; _x+=2) {
                        for (var _y = 0; _y < 12; _y+=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
                case Cardinal.North:
                    for (var _x = -4; _x < 8; _x+=2) {
                        for (var _y = 0; _y > -12; _y-=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
                case Cardinal.West:
                    for (var _x = 0; _x > -12; _x-=2) {
                        for (var _y = -4; _y < 8; _y+=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
                case Cardinal.East:
                    for (var _x = 0; _x < 12; _x += 2) {
                        for (var _y = -4; _y < 8; _y+=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
            }
            break;
        case RangePattern.SixByNine:
            switch(cardinality) {
                case Cardinal.South:
                    for (var _x = -4; _x < 8; _x+=2) {
                        for (var _y = 0; _y < 18; _y+=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
                case Cardinal.North:
                    for (var _x = -4; _x < 8; _x+=2) {
                        for (var _y = 0; _y > -18; _y-=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
                case Cardinal.West:
                    for (var _x = 0; _x > -18; _x-=2) {
                        for (var _y = -4; _y < 8; _y+=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
                case Cardinal.East:
                    for (var _x = 0; _x < 18; _x+=2) {
                        for (var _y = -4; _y < 8; _y+=2) {
                            list.push(Vec2(xx+_x,yy+_y));
                        }
                    }
                    break;
            }
            break;
        default:
            impossible("Invalid range pattern given");
    }
    return list;
}

function quality_to_range_pattern(quality) {
    switch quality {
        case QualityId.Tier1:
            return RangePattern.One;
        case QualityId.Tier2:
            return RangePattern.OneByThree;
        case QualityId.Tier3:
            return RangePattern.ThreeByThree;
        case QualityId.Tier4:
            return RangePattern.ThreeBySix;
        case QualityId.Tier5:
            return RangePattern.SixBySix;
        case QualityId.Tier6:
            return RangePattern.SixByNine;
        default:
            impossible("Incorrect quality supplied: {}", quality);
    }
}

//
function range_pattern_to_count(range_pattern) {
    switch range_pattern {
        case RangePattern.One: return 1;
        case RangePattern.OneByThree: return 3;
        case RangePattern.ThreeByThree: return 9;
        case RangePattern.ThreeBySix: return 18;
        case RangePattern.SixBySix: return 36;
        case RangePattern.SixByNine: return 54;
        default: impossible("unexpected range_pattern: {}", range_pattern);
    }
}

function range_pattern_to_blip_sound(range_pattern) {
    switch range_pattern {
        case RangePattern.One: return "SoundEffects/Tools/ChargeStrike/BlipOne";
        case RangePattern.OneByThree: return "SoundEffects/Tools/ChargeStrike/BlipOneByThree";
        case RangePattern.ThreeByThree: return "SoundEffects/Tools/ChargeStrike/BlipThreeByThree";
        case RangePattern.ThreeBySix: return "SoundEffects/Tools/ChargeStrike/BlipThreeBySix";
        case RangePattern.SixBySix: return "SoundEffects/Tools/ChargeStrike/BlipSixBySix";
        case RangePattern.SixByNine: return "SoundEffects/Tools/ChargeStrike/BlipSixByNine";
        default: impossible("unexpected range_pattern: {}", range_pattern);
    }
}

function range_pattern_to_swing_sound(range_pattern) {
    switch range_pattern {
      case RangePattern.One: return undefined;
      case RangePattern.OneByThree: return "SoundEffects/Tools/ChargeStrike/HoeAndShovelSwingOneByThree";
      case RangePattern.ThreeByThree: return "SoundEffects/Tools/ChargeStrike/HoeAndShovelSwingThreeByThree";
      case RangePattern.ThreeBySix: return "SoundEffects/Tools/ChargeStrike/HoeAndShovelSwingThreeBySix";
      case RangePattern.SixBySix: return "SoundEffects/Tools/ChargeStrike/HoeAndShovelSwingSixBySix";
      case RangePattern.SixByNine: return "SoundEffects/Tools/ChargeStrike/HoeAndShovelSwingSixByNine";
        default: impossible("unexpected range_pattern: {}", range_pattern);
    }
}
