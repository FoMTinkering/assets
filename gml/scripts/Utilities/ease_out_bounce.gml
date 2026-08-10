//
//
//
//
//
function ease_out_bounce(inputvalue, outputmin, outputmax, inputmax) {
    inputvalue /= inputmax;

    if inputvalue < (1 / 2.75) {
        return outputmax * 7.5625 * inputvalue * inputvalue + outputmin;
    } else if inputvalue < (2/2.75) {
        inputvalue -= 1.5/2.75;
        return outputmax * (7.5625 * inputvalue * inputvalue + 0.75) + outputmin;
    } else if inputvalue < (2.5/2.75) {
        inputvalue -= 2.25/2.75;
        return outputmax * (7.5625 * inputvalue * inputvalue + 0.9375) + outputmin;
    } else {
        inputvalue -= 2.625/2.75;
        return outputmax * (7.5625 * inputvalue * inputvalue + 0.984375) + outputmin;
    }
}
