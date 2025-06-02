import round_enum::*;
module round_mult (
    input  logic [23:0] mantissa_in,      // 24-bit input mantissa (includes leading 1)
    input  logic        guard_bit,
    input  logic        sticky_bit,
    input  logic        sign,             // Sign of the result
    input  logic [2:0]  round_mode,       // Enum encoded round mode
    output logic [24:0] mantissa_out,     // 25-bit mantissa (1-bit for potential overflow)
    output logic        inexact           // 1 if result was not exact
);
 
    logic round_up;
    logic [24:0] mantissa_extended;

    assign mantissa_extended = {1'b0, mantissa_in};  // Extend for possible carry on rounding

    // Inexact flag logic
    assign inexact = guard_bit | sticky_bit;

    always_comb begin
        round_up = 1'b0;

        case (round_mode)
            IEEE_NEAR: begin
                // Round to nearest even
                if (guard_bit && (sticky_bit || mantissa_extended[0])) begin
                    round_up = 1;
                end
            end
            IEEE_ZERO: begin
                // Round toward zero: never round up
                round_up = 0;
            end
            IEEE_PINF: begin
                // Round toward +infinity
                round_up = (sign == 0) && inexact;
            end
            IEEE_NINF: begin
                // Round toward -infinity
                round_up = (sign == 1) && inexact;
            end
            NEAR_UP: begin
                // Round to nearest, bias toward +Inf when tie
//                 if (guard_bit && (sticky_bit || mantissa_extended[0])) begin
//                     round_up = 1;
              if (guard_bit)
                      round_up = 1;
                 
            end
            AWAY_ZERO: begin
                // Round away from zero
              if (guard_bit && (sticky_bit || mantissa_extended[0])) begin
              round_up = 1;
              end else begin
              round_up = 0;
              end
end
            default: begin
                // Default: IEEE_NEAR
                if (guard_bit && (sticky_bit || mantissa_extended[0])) begin
                    round_up = 1;
                end
            end
        endcase

        if (round_up) begin
            mantissa_out = mantissa_extended + 1;
        end else begin
            mantissa_out = mantissa_extended;
        end
    end

endmodule

