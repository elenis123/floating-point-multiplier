// Module 1: Immediate Assertions
// This module checks for illegal combinations of status bits using immediate assertions.
module test_status_bits(
    input logic clk,
    input logic [7:0] status
);
    // Immediate Assertions
    // These assertions fire at time 0 and check that certain status bits are not high simultaneously.
    initial begin
        if (!$isunknown(status)) begin
            // Zero and Inf cannot be high at the same time
            assert (!(status[0] && status[1])) else $error("Zero and Inf cannot be high simultaneously.");
            // Zero and NaN cannot be high at the same time
            assert (!(status[0] && status[2])) else $error("Zero and NaN cannot be high simultaneously.");
            // Zero and Tiny cannot be high at the same time
            assert (!(status[0] && status[3])) else $error("Zero and Tiny cannot be high simultaneously.");
            // Zero and Huge cannot be high at the same time
            assert (!(status[0] && status[4])) else $error("Zero and Huge cannot be high simultaneously.");
            // Zero and Inexact cannot be high at the same time
            assert (!(status[0] && status[5])) else $error("Zero and Inexact cannot be high simultaneously.");

            // Inf and Tiny cannot be high at the same time
            assert (!(status[1] && status[3])) else $error("Inf and Tiny cannot be high simultaneously.");
            // Inf and Huge cannot be high at the same time
            assert (!(status[1] && status[4])) else $error("Inf and Huge cannot be high simultaneously.");
            // Inf and Inexact cannot be high at the same time
            assert (!(status[1] && status[5])) else $error("Inf and Inexact cannot be high simultaneously.");

            // NaN and Tiny cannot be high at the same time
            assert (!(status[2] && status[3])) else $error("NaN and Tiny cannot be high simultaneously.");
            // NaN and Huge cannot be high at the same time
            assert (!(status[2] && status[4])) else $error("NaN and Huge cannot be high simultaneously.");
            // NaN and Inexact cannot be high at the same time
            assert (!(status[2] && status[5])) else $error("NaN and Inexact cannot be high simultaneously.");
        end
    end
endmodule

// Module 2: Concurrent Assertions
// This module checks the correctness of status bits with respect to the floating-point result and operands.
module test_status_z_combinations(
    input logic clk,
    input logic [7:0] status,       // [0] = zero, [1] = inf, [2] = nan, [3] = tiny, [4] = huge
    input logic [31:0] z,           // Result value (IEEE 754 single-precision)
    input logic [31:0] a, b         // Operand values (IEEE 754 single-precision)
);

    // Sequence to detect NaN condition:
    // 3 cycles before, one operand has exponent 0 and the other has exponent 255 (all 1s
    sequence nan_condition;
      ($past(a[30:23], 2) == 8'b0 && $past(b[30:23], 2) == 8'b11111111) ||
      ($past(a[30:23], 2) == 8'b11111111 && $past(b[30:23], 2) == 8'b0);
    endsequence

    // ZERO: If status[0] is set, the exponent of z must be 0 (zero value)
    assert property (@(posedge clk) status[0] |-> (z[30:23] == 8'b0))
        else $error("Zero status bit set but exponent of 'z' is not zero");

    // INF: If status[1] is set, the exponent of z must be all 1s (infinity)
    assert property (@(posedge clk) status[1] |-> (z[30:23] == 8'b11111111))
        else $error("Infinity status bit set but exponent of 'z' is not all ones");

    // NAN: If status[2] is set, nan_condition must have been true 3 cycles ago
    assert property (@(posedge clk) status[2] |-> nan_condition)
        else $error("NaN status bit set but prior condition not met for 'a' and 'b'");

    // TINY: If status[3] is set, z must be subnormal (exp==0) or minNormal (exp==1, mantissa==0)
    assert property (@(posedge clk) status[3] |-> 
        (z[30:23] == 8'b0 || (z[30:23] == 8'b00000001 && z[22:0] == 23'b0)))
        else $error("Tiny status bit set but 'z' is not minNormal or subnormal");

    // HUGE: If status[4] is set, z must be infinity (exp==255) or maxNormal (exp==254, mantissa==max)
    assert property (@(posedge clk) status[4] |-> 
        (z[30:23] == 8'b11111111 || (z[30:23] == 8'b11111110 && z[22:0] == 23'h7FFFFF)))
        else $error("Huge status bit set but 'z' is not maxNormal or infinity");

endmodule