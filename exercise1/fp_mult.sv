package round_enum;
    // Round mode encoding (match Table 4 in your image)
    typedef enum logic [2:0] {
        IEEE_NEAR ,
        IEEE_ZERO ,
        IEEE_PINF ,
        IEEE_NINF ,
        NEAR_UP   ,
        AWAY_ZERO 
    } round_mode_t;
endpackage

import round_enum::*;
`include "normalize_mult.sv"
`include "round_mult.sv"
`include "exception_mult.sv"
`include "assertions.sv"
module fp_mult (
	input logic [31:0] a, b,
	input  logic [2:0] rnd,
	output logic [31:0] z,
  output logic [7:0] status,
    input logic clk, rst
);



logic sign_mult;
logic [9:0] exp_add;
logic [47:0] P;
logic [9:0] exp_mult;
logic [24:0] result;
logic [22:0] norm_mantissa;
logic [9:0] norm_exp;
logic inexact;
logic [24:0] post_mant;
logic [9:0] post_exp;
logic guard_bit, sticky_bit;
logic [31:0] z_calc;
logic overflow;
logic underflow;
logic zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f;

round_mode_t rnd_t;
round_mode_t rnd_reg;
always_comb begin
	rnd_t = round_mode_t'(rnd);
end
 
assign sign_mult = a[31]^b[31];
assign exp_add = (a[30:23] + b[30:23]);
assign exp_mult = exp_add - 127;
assign P = ({1'b1, a[22:0]} * {1'b1, b[22:0]});

normalize_mult normalization(P, exp_mult, norm_mantissa, norm_exp,  guard_bit, sticky_bit);

// Pipeline Registers After Normalization 
// These registers store the normalized exponent, mantissa, guard, sticky, and sign bits
// to create a pipeline stage between normalization and rounding.
logic [9:0] norm_exp_reg;         // Registered normalized exponent
logic [22:0] norm_mantissa_reg;   // Registered normalized mantissa
logic guard_bit_reg, sticky_bit_reg; // Registered guard and sticky bits
logic sign_mult_reg;              // Registered sign bit

// Pipeline register logic: On reset, clear all registers. Otherwise, capture normalized values.
always_ff @(posedge clk or negedge rst) begin
  if (!rst) begin
    norm_exp_reg <= '0;
    norm_mantissa_reg <= '0;
    guard_bit_reg <= 0;
    sticky_bit_reg <= 0;
    sign_mult_reg <= 0;
    rnd_reg  <= IEEE_ZERO;
    
  end else begin
    norm_exp_reg <= norm_exp;
    norm_mantissa_reg <= norm_mantissa;
    guard_bit_reg <= guard_bit;
    sticky_bit_reg <= sticky_bit;
    sign_mult_reg <= sign_mult;
    rnd_reg <= rnd_t;
  end
end

  round_mult rounding({1'b1,norm_mantissa_reg}, guard_bit_reg, sticky_bit_reg, sign_mult_reg, rnd_reg, result, inexact);

always_comb begin
  if (result[24] == 1'b1) begin // MSB of mantissa is 1
	post_mant = result >> 1; // Shift mantissa to the right by one
	post_exp = norm_exp_reg + 1; // Increase exponent by one
	end
  else begin
	post_mant = result;
	post_exp = norm_exp_reg;
	end
end

// Make z_calc
  assign z_calc = {sign_mult_reg,post_exp[7:0],post_mant[22:0]};

// Calculate overflow and underflow signals
always_comb begin
    overflow = 0;
    underflow = 0;

  if (signed'(post_exp) >  $signed(254)) overflow = 1; // Overflow
    else overflow = 0;
	    
  if (signed'(post_exp) <  $signed(1)) underflow = 1; //Undeflow
    else underflow = 0;
end

// Exception handling
  exception_mult excep_handling(a, b, z_calc, overflow, underflow, inexact, rnd_reg, z,
	zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f);

assign status = {1'b0, 1'b0, inexact_f, huge_f, tiny_f, nan_f, inf_f, zero_f};

endmodule