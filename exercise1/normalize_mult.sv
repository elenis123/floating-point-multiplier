import round_enum::*;
module normalize_mult (
    input  logic [47:0] P,                // 48-bit multiplication result
    input  logic [9:0]  exponent_in,      // 10-bit exponent (sum of exponents - bias)
    output logic [22:0] normalized_mantissa, // 23-bit normalized mantissa (excluding leading one)
    output logic [9:0]  normalized_exponent, // 10-bit normalized exponent
    output logic        guard_bit,        // Guard bit
    output logic        sticky_bit        // Sticky bit
);

    logic msb; // P[47]
    assign msb = P[47];

    always_comb begin
        if (msb == 1'b1) begin
            // Leading '1' is at P[47], binary point is between P[46] and P[45]
            normalized_exponent   = exponent_in + 1;
            normalized_mantissa   = P[46:24];      // Bits [46:24] --> 23 bits (excluding leading 1)
            guard_bit             = P[23];
            sticky_bit            = |P[22:0];      // OR-reduction of bits [22:0]
        end 
        else begin
            // Leading '1' is at P[46], binary point is between P[45] and P[44]
            normalized_exponent   = exponent_in;
            normalized_mantissa   = P[45:23];      // Bits [45:23] --> 23 bits (excluding leading 1)
            guard_bit             = P[22];
            sticky_bit            = |P[21:0];      // OR-reduction of bits [21:0]
        end
    end

endmodule

