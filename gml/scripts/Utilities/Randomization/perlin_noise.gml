#macro PERLIN_BUFF global.__perlin_buffer

perlin_generate_2d(0, 6, 2, 0.5);

global.__perlin_buffer = {
    perl_buff: -1,

    //
    generate: function(width, height) {
        //
        buffer_delete(self.perl_buff);
        self.perl_buff = buffer_create(width * height * 8, buffer_fixed, 8);
        rn_perlin_2d_fill_buff(width, height, self.perl_buff, buffer_get_address(self.perl_buff));
    },

    //
    read_next: function() {
        return buffer_read(self.perl_buff, buffer_f64);
    }
};

//
function perlin_noise_get(offset) {
    return perlin_1d_get(current_time() + offset);
}
