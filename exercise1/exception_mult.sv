import round_enum::*;

// Floating-point exception handling for multiplication
module exception_mult (
    input  logic [31:0] a, b,              // Input operands
     input  logic [31:0] z_calc,            // Output after rounding
     input  logic        overflow,          // Overflow flag
     input  logic        underflow,         // Underflow flag
     input  logic        inexact,           // Inexact flag
     input  round_mode_t round_mode,        // Rounding mode
     output logic [31:0] z,                 // Final output result
     output logic        zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f // Exception flags
);


     // --------------------------
     // ENUM for Interpretation
     // --------------------------
     // Classifies floating-point numbers
     typedef enum logic [2:0] {
          ZERO,       // Zero or denormal
          INF,        // Infinity or NaN
          NORM,       // Normalized number
          MIN_NORM,   // Minimum normalized
          MAX_NORM    // Maximum normalized
     } interp_t;


     // --------------------------
     // num_interp(): Classify a 32-bit float
     // --------------------------
     // Returns the interpretation of a floating-point value
     function automatic interp_t num_interp(input logic [31:0] val);
          logic [7:0] exp = val[30:23];
          if (exp == 8'h00)
                return ZERO; // Denormal or zero
          else if (exp == 8'hFF)
                return INF;  // Inf or NaN
          else
                return NORM;
     endfunction


     // --------------------------
     // z_num(): Generate constants
     // --------------------------
     // Returns the bit pattern for a given interpretation
     function logic [30:0] z_num(input interp_t interp_val);
          case (interp_val)
                ZERO:     return 31'b00000000_00000000000000000000000; // Zero
                INF:      return 31'b11111111_00000000000000000000000; // Infinity
                MIN_NORM: return 31'b00000001_00000000000000000000000; // Min normalized
                MAX_NORM: return 31'b11111110_11111111111111111111111; // Max normalized
                default:  return 31'h00000000;
          endcase
     endfunction
    
     
     // --------------------------
     // Main Exception Handling
     // --------------------------
     always_comb begin
          // Default outputs
          zero_f = 0;
          inf_f = 0;
          nan_f = 0;
          tiny_f = 0;
          huge_f = 0;
          inexact_f = 0;

          // Main case logic: classify input operands and handle exceptions
          case ({num_interp(a),num_interp(b)})
                // Zero cases
                {ZERO, ZERO},
                {ZERO, NORM},
                {NORM, ZERO}: begin
                     z = {z_calc[31], z_num(ZERO)}; // Result is zero
                     zero_f = 1;
                end

                // Zero * Inf or Inf * Zero: result is NaN
                {ZERO, INF},
                {INF, ZERO}: begin
                     z = {1'b0, z_num(INF)}; // Canonical NaN encoding
                     nan_f = 1;
                end
          
                // Inf * Inf, Inf * Norm, Norm * Inf: result is Inf
                {INF, INF},
                {INF, NORM},
                {NORM, INF}: begin
                     z = {z_calc[31], z_num(INF)}; // Result is infinity
                     inf_f = 1;
                end

                // Both operands are normal numbers
                {NORM, NORM}: begin
                     if (overflow) begin
                          huge_f = 1; // Set huge flag
                          // Handle overflow based on rounding mode
                          case (round_mode)
                                IEEE_NEAR, NEAR_UP, AWAY_ZERO: begin
                                     z = {z_calc[31], z_num(INF)}; // Overflow to infinity
                                     inf_f = 1;
                                end
                                IEEE_ZERO: begin
                                     z = {z_calc[31], z_num(MAX_NORM)}; // Overflow to max norm
                                end
                                IEEE_PINF: begin
                                     if (z_calc[31] == 0) begin
                                          z = {1'b0, z_num(INF)}; // Positive overflow to +Inf
                                          inf_f = 1;
                                     end else begin
                                          z = {1'b1, z_num(MAX_NORM)}; // Negative overflow to -MaxNorm
                                     end
                                end
                                IEEE_NINF: begin
                                     if (z_calc[31] == 1) begin
                                          z = {1'b1, z_num(INF)}; // Negative overflow to -Inf
                                          inf_f = 1;
                                     end else begin
                                          z = {1'b0, z_num(MAX_NORM)}; // Positive overflow to +MaxNorm
                                     end
                                end
                                default: begin
                                     z = {z_calc[31], z_num(MAX_NORM)};
                                end
                          endcase
                     end else if (underflow) begin
                          tiny_f = 1; // Set tiny flag
                          // Handle underflow based on rounding mode
                          case (round_mode)
                                IEEE_NEAR, IEEE_ZERO: begin
                                     z = {z_calc[31], z_num(ZERO)}; // Underflow to zero
                                     zero_f = 1;
                                end
                                IEEE_PINF: begin
                                     if (z_calc[31] == 0) begin
                                          z = {1'b0, z_num(MIN_NORM)}; // Underflow to min norm
                                     end else begin
                                          z = {1'b1, z_num(ZERO)}; // Underflow to -0
                                          zero_f = 1;
                                     end
                                end
                                IEEE_NINF: begin
                                     if (z_calc[31] == 1) begin
                                          z = {1'b1, z_num(MIN_NORM)}; // Underflow to -min norm
                                     end else begin
                                          z = {1'b0, z_num(ZERO)}; // Underflow to +0
                                          zero_f = 1;
                                     end
                                end
                                NEAR_UP: begin
                                    z = {z_calc[31], z_num(ZERO)}; // Underflow to zero for NEAR_UP
                                    zero_f = 1;
                                           end
                                AWAY_ZERO: begin
                                     z = {z_calc[31], z_num(ZERO)};
                                     zero_f = 1;
                                   end 
 
                                default: begin
                                     z = {z_calc[31], z_num(ZERO)}; // Default to zero
                                     zero_f = 1;
                                end
                          endcase
                     end else begin
                          z = z_calc; // No exception, use calculated result
                          inexact_f = inexact; // Set inexact flag if needed
                     end
                end

                // Default case: treat as zero
                default: begin
                     z = {z_calc[31], 31'b0};
                     zero_f = 1'b1;
                end
          endcase
          
     end

endmodule