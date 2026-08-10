function add_key_time(argument0, argument1, argument2, argument3, argument4, argument5, argument6, argument7) {

    var i = 0;
    if(!is_undefined(color[0][0])) i = array_length(color[0]);

    color[i][0] = argument0/255;
    color[i][1] = argument1/255;
    color[i][2] = argument2/255;

    con_sat_brt[i][0] = argument3;
    con_sat_brt[i][1] = argument4;
    con_sat_brt[i][2] = argument5;

    con_sat_brt[i][3] = argument6;
    con_sat_brt[i][4] = argument7;


}
