enum EaseId {
    Linear,
    SineIn,
    SineOut,
    SineInOut,
    QuadIn,
    QuadOut,
    QuadInOut,
    CubicIn,
    CubicOut,
    CubicInOut,
    QuartIn,
    QuartOut,
    QuartInOut,
    QuintIn,
    QuintOut,
    QuintInOut,
    ExpoIn,
    ExpoOut,
    ExpoInOut,
    CircIn,
    CircOut,
    CircInOut,
    BackIn,
    BackOut,
    BackInOut,
    ElasticIn,
    ElasticOut,
    ElasticInOut,
    LEN,
}

function Ease(_ease_id, _start_value, _end_value, _duration) constructor {
    start_value = _start_value;
    end_value = _end_value;
    duration = _duration;
    ease_id = _ease_id;

    //
    //
    //
    //
    //
    //
    //
    //
    //
    static calculate_value = function(time) {
        if self.duration == 0 {
            return 1;
        } else if self.duration == time {
            return self.end_value;
        }
        time = clamp(time, 0, self.duration);
        var weight = time / self.duration;
        var ease_value;
        switch self.ease_id {
            case EaseId.Linear:
                ease_value = weight;
                break;
            case EaseId.SineIn:
                ease_value = -1 * cos((weight / 2) * pi) + 1;
                break;
            case EaseId.SineOut:
                ease_value = sin((weight / 4) * pi * 2);
                break;
            case EaseId.SineInOut:
                ease_value = -0.5 * (cos(weight * pi) - 1);
                break;
            case EaseId.QuadIn:
                ease_value = weight * weight;
                break;
            case EaseId.QuadOut:
                ease_value = -1 * weight * (weight - 2);
                break;
            case EaseId.QuadInOut:
                weight *= 2;
                if weight < 1 {
                    ease_value = 0.5 * weight * weight;
                    break;
                }
                --weight;
                ease_value = -0.5 * (weight * (weight - 2) - 1);
                break;
            case EaseId.CubicIn:
                ease_value = weight * weight * weight;
                break;
            case EaseId.CubicOut:
                --weight;
                ease_value = weight * weight * weight + 1;
                break;
            case EaseId.CubicInOut:
                weight *= 2;
                if weight < 1 {
                    ease_value = 0.5 * weight * weight * weight;
                    break;
                }
                weight -= 2;
                ease_value = 0.5 * (weight * weight * weight + 2);
                break;
            case EaseId.QuartIn:
                ease_value = weight * weight * weight * weight;
                break;
            case EaseId.QuartOut:
                --weight;
                ease_value = -(weight * weight * weight * weight - 1);
                break;
            case EaseId.QuartInOut:
                weight *= 2;
                if weight < 1 {
                    ease_value = 0.5 * weight * weight * weight * weight;
                    break;
                }
                weight -= 2;
                ease_value = -0.5 * (weight * weight * weight * weight - 2);
                break;
            case EaseId.QuintIn:
                ease_value = weight * weight * weight * weight * weight;
                break;
            case EaseId.QuintOut:
                --weight;
                ease_value = weight * weight * weight * weight * weight + 1;
                break;
            case EaseId.QuintInOut:
                weight *= 2;
                if weight < 1 {
                    ease_value = 0.5 * weight * weight * weight * weight * weight;
                    break;
                }
                weight -= 2;
                ease_value = 0.5 * (weight * weight * weight * weight * weight + 2);
                break;
            case EaseId.ExpoIn:
                ease_value = power(2, 10 * (weight - 1));
                break;
            case EaseId.ExpoOut:
                ease_value = -power(2, -10 * weight) + 1;
                break;
            case EaseId.ExpoInOut:
                weight *= 2;
                if weight < 1 {
                    ease_value = 0.5 * power(2, 10 * (weight - 1));
                    break;
                }
                ease_value = 0.5 * (-power(2, -10 * (weight - 1)) + 2);
                break;
            case EaseId.CircIn:
                ease_value = -1 * (sqrt(1 - weight * weight) - 1);
                break;
            case EaseId.CircOut:
                --weight;
                ease_value = sqrt(1 - weight * weight);
                break;
            case EaseId.CircInOut:
                weight *= 2;
                if weight < 1 {
                    ease_value = -0.5 * (sqrt(1 - weight * weight) - 1);
                    break;
                }
                weight -= 2;
                ease_value = 0.5 * (sqrt(1 - weight * weight) + 1);
                break;
            case EaseId.BackIn:
                var overshoot = 1.70158;
                ease_value = weight * weight * ((overshoot + 1) * weight - overshoot);
                break;
            case EaseId.BackOut:
                var overshoot = 1.70158;
                weight -= 1;
                ease_value = weight * weight * ((overshoot + 1) * weight + overshoot) + 1;
                break;
            case EaseId.BackInOut:
                var overshoot = 2.5949095;
                weight *= 2;
                if weight < 1 {
                    ease_value = (weight * weight * ((overshoot + 1) * weight - overshoot)) / 2;
                    break;
                }
                weight -= 2;
                ease_value = (weight * weight * ((overshoot + 1) * weight + overshoot)) / 2 + 1;
                break;
            case EaseId.ElasticIn:
                var period = 0.3;
                --weight;
                ease_value = -power(2, 10 * weight) * sin((weight - period / 4) * pi * 2 / period);
                break;
            case EaseId.ElasticOut:
                var period = 0.3;
                ease_value = power(2, -10 * weight) * sin((weight - period / 4) * pi * 2 / period) + 1;
                break;
            case EaseId.ElasticInOut:
                var period = 0.3;
                weight *= 2;
                --weight;
                if weight < 0 {
                    ease_value = -0.5 * power(2, 10 * weight) * sin((weight - period / 4) * pi * 2 / period);
                    break;
                }
                ease_value = power(2, -10 * weight) * sin((weight - period / 4) * pi * 2 / period) * 0.5 + 1;
                break;
            default:
                impossible("Unrecognized ease id: {}", self.ease_id);
                return;
        }
        return self.start_value + (self.end_value - self.start_value) * ease_value;
    }
}
