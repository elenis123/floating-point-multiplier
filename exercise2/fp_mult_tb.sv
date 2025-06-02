`timescale 1ns / 1ps
`include "multiplication.sv"

import round_enum::*;

module fp_mult_tb;

  logic clk, rst;
  logic [31:0] a, b;
  logic [2:0] rnd;
  logic [31:0] z, real_z;
  logic [7:0] status;
  int success_count = 0;
  int fail_count = 0;
  logic [2:0] round_tb [6] = '{3'b000, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101};
  
 int N, i, j, k;
 assign N = 60; // Number of tests
 int IEEE_near_success = 0, IEEE_ZERO = 0, IEEE_PINF = 0, IEEE_NINF = 0, NEAR_UP = 0, AWAY_ZERO = 0;  
  
  // Instantiate DUT
  fp_mult_top DUT (
    .clk(clk),
    .rst(rst),
    .a(a),
    .b(b),
    .rnd(rnd),
    .z(z),
    .status(status)
  );
  
  // Bind DUT to the status test module
  bind DUT test_status_bits dutbound (clk, status);

  // Bind DUT to the z combinations test module
 bind DUT test_status_z_combinations dutbound_z (clk, status, z ,a ,b);

  // Clock generation: 10ns period
  always #5 clk = ~clk;
  
 // Corner cases
typedef enum logic [3:0]{
neg_s_nan, pos_s_nan, neg_q_nan, pos_q_nan, neg_inf, 
pos_inf, neg_norm, pos_norm, neg_denorm, pos_denorm, neg_zero, pos_zero} corner_case_t;

// Corner cases function 

function logic [31:0] corner_case_to_value(corner_case_t corner_case);
    case (corner_case)
        neg_s_nan:  return 32'b11111111100000000000000000000001; // negative signaling NaN
        pos_s_nan:  return 32'b01111111100000000000000000000001; // positive signaling NaN
        neg_q_nan:  return 32'b11111111110000000000000000000001; // negative quiet NaN
        pos_q_nan:  return 32'b01111111110000000000000000000001; // positive quiet NaN
        neg_inf:    return 32'b11111111100000000000000000000000; // negative infinity
        pos_inf:    return 32'b01111111100000000000000000000000; // positive infinity
        neg_norm:   return 32'b10111111100000000000000000000000; // random negative normal 
        pos_norm:   return 32'b00111111100000000000000000000000; // random positive normal
        neg_denorm: return 32'b10000000000000000000000000000001; // random negative denormal
        pos_denorm: return 32'b00000000000000000000000000000001; // random positive denormal
        neg_zero:   return 32'b10000000000000000000000000000000; // negative zero
        pos_zero:   return 32'b00000000000000000000000000000000; // positive zero
        default:    return 32'b00000000000000000000000000000000;
    endcase
endfunction


corner_case_t corner_cases[12] = '{
  neg_s_nan, pos_s_nan, 
  neg_q_nan, pos_q_nan, 
  neg_inf, pos_inf, 
  neg_norm, pos_norm, 
  neg_denorm, pos_denorm, 
  neg_zero, pos_zero
};

 string round_s[6] = {"IEEE_near","IEEE_zero","IEEE_pinf","IEEE_ninf","near_up","away_zero"};

 initial 
 begin 
 $dumpfile("wave.vcd");
 $dumpvars(0, fp_mult_tb); 
 clk = 0;
 rst = 0;

#2 rst = 1;
@(posedge clk);
@(posedge clk);
 //checks for all 6 possible roundings 
 //case: IEEE_near
 for (i = 0; i < N; i++) begin
 a   = $urandom;
 b   = $urandom;
 rnd = 3'b000;
 real_z = multiplication(round_s[0], a, b);
 repeat (4) @(posedge clk);

 if (z !== real_z)$display("-ERROR: Mismatch at IEEE_near test %0d: a=%h, b=%h, z=%h, expected=%h", i, a, b, z, real_z);
 // check for error and display message
    else IEEE_near_success ++ ;
  // $display("+Test PASSED at IEEE_near");
 end
   $display("+ PASSED at IEEE_near for %0d tests", IEEE_near_success ); 

// Test IEEE_zero
for (i = 0; i < N; i++) begin
  a = $urandom();
  b = $urandom();
  rnd = 3'b001; // IEEE_zero
  real_z = multiplication(round_s[1], a, b);
  repeat (4) @(posedge clk);
  if (z !== real_z)
    $display("-ERROR: Mismatch at IEEE_zero test %0d: a=%h, b=%h, z=%h, expected=%h", i, a, b, z, real_z);
  else IEEE_ZERO++;
end
$display("+ PASSED at IEEE_zero for %0d tests", IEEE_ZERO);

// Test IEEE_pinf
for (i = 0; i < N; i++) begin
  a = $urandom();
  b = $urandom();
  rnd = 3'b010; // IEEE_pinf
  real_z = multiplication(round_s[2], a, b);
  repeat (4) @(posedge clk);
  if (z !== real_z)
    $display("-ERROR: Mismatch at IEEE_pinf test %0d: a=%h, b=%h, z=%h, expected=%h", i, a, b, z, real_z);
  else IEEE_PINF++;
end
$display("+ PASSED at IEEE_pinf for %0d tests", IEEE_PINF);

// Test IEEE_ninf
for (i = 0; i < N; i++) begin
  a = $urandom();
  b = $urandom();
  rnd = 3'b011; // IEEE_ninf
  real_z = multiplication(round_s[3], a, b);
  repeat (4) @(posedge clk);
  if (z !== real_z)
    $display("-ERROR: Mismatch at IEEE_ninf test %0d: a=%h, b=%h, z=%h, expected=%h", i, a, b, z, real_z);
  else IEEE_NINF++;
end
$display("+ PASSED at IEEE_ninf for %0d tests", IEEE_NINF);

// Test near_up
for (i = 0; i < N; i++) begin
  a = $urandom();
  b = $urandom();
  rnd = 3'b100; // near_up
  real_z = multiplication(round_s[4], a, b);
  repeat (4) @(posedge clk);
  if (z !== real_z)
    $display("-ERROR: Mismatch at near_up test %0d: a=%h, b=%h, z=%h, expected=%h", i, a, b, z, real_z);
  else NEAR_UP++;
end
$display("+ PASSED at near_up for %0d tests", NEAR_UP);

// Test away_zero
for (i = 0; i < N; i++) begin
  a = $urandom();
  b = $urandom();
  rnd = 3'b101; // away_zero
  real_z = multiplication(round_s[4], a, b);
  repeat (4) @(posedge clk);
  if (z !== real_z)
    $display("-ERROR: Mismatch at away_zero test %0d: a=%h, b=%h, z=%h, expected=%h", i, a, b, z, real_z);
  else AWAY_ZERO++;
end
$display("+ PASSED at away_zero for %0d tests", AWAY_ZERO);
   

   
// Checks for corner cases
$display("=== Starting Corner Case Tests ===");
   for (k = 0; k < 6; k++) begin
    for (int i = 0; i < 12; i++) begin
      for (int j = 0; j < 12; j++) begin
        a = corner_case_to_value(corner_cases[i]);
        b = corner_case_to_value(corner_cases[j]);
        real_z = multiplication(round_s[k], a, b);
        // Apply the inputs and wait for the result
        repeat (4) @(posedge clk);
     
        // Display errors
	if (z !== real_z)
	    begin
        $display("ERROR: Mismatch at corner cases for round %s ",round_s[k]);
		$display("a = %h, b = %h, z = %h, expected = %h", a, b, z, real_z);
        $display("At time %0t", $time);
		fail_count = fail_count + 1;
        end else begin
          success_count = success_count + 1;
        end
      end
    end
   end

    // Report
    $display("=== Completed Corner Case Tests ===");
    $display("Simulation complete.");
    $display("  Successful comparisons: %0d", success_count);
    $display("  Failed comparisons:     %0d", fail_count);
    $display("  Total comparisons:      %0d", success_count + fail_count);
  
    #1000 $stop;
  end

endmodule
