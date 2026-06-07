`timescale 1ps / 1ps

/*
// =========================================================================
// RETROSPECTIVE: KEY FUNCTIONAL BUGS FIXED
// =========================================================================

// 1. SIGN APPLICATION MULTIPLIER BUG (Stage 4)
// STRUGGLE: Originally used `qerf <= ql * qsgn3`. 
// WHY IT FAILED: `qsgn3` was just a 1-bit sign extractor (0 or 1). In hardware, 
// multiplying by 1'b1 doesn't negate a number; it stays positive. 
// FIX: Replaced with an explicit if/else (or ternary) to negate the value when 
// the sign bit is active, accurately matching Python's `np.sign()`.
if (qsgn3 == 1) begin
    qerf <= -ql;
end else begin
    qerf <= ql;
end

// 2. LOGICAL VS. ARITHMETIC RIGHT SHIFT (Stage 5)
// STRUGGLE: Originally used `>> SHIFT` for fixed-point scaling.
// WHY IT FAILED: The `>>` operator is a logical right shift. It zero-fills the 
// MSBs, which destroys the sign bit and turns negative numbers into massive 
// positive values.
// FIX: Swapped to `>>>`, the arithmetic right shift operator, which properly 
// preserves and extends the sign bit for signed values.
qout <= ((qerf >>> SHIFT) + q1) * qin4;


// 3. SIGNED OPERAND CONTEXT LOSS (Stage 2)
// STRUGGLE: Originally multiplied `qb * 2`.
// WHY IT FAILED: In SystemVerilog, raw integer literals like `2` default to 
// unsigned. If any operand in an expression is unsigned, the entire operation 
// gets implicitly cast to unsigned, stripping `qb` of its signed context.
// FIX: Explicitly cast the literal as signed using `32'sd2`.
qb2 <= qb * 32'sd2;

*/

module gelu
#(
    parameter integer D_W   = 32,
    parameter integer SHIFT = 14
)
(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  in_valid,
    input  logic signed [D_W-1:0] qin,           // gelu input

    input  logic signed [D_W-1:0] qb,            // coefficient
    input  logic signed [D_W-1:0] qc,            // coefficient
    input  logic signed [D_W-1:0] q1,            // coefficient

    output logic                  out_valid,
    output logic signed [D_W-1:0] qout           // gelu output
);

    logic qsgn;
    logic qsgn2;
    logic qsgn3; 

    logic signed [D_W-1:0] qin1;
    logic signed [D_W-1:0] qin_abs;

    logic signed [D_W-1:0] qin2;
    logic signed [D_W-1:0] qb2;
    logic signed [D_W-1:0] qmin;
    
    logic signed [D_W-1:0] qin3;

    logic signed [D_W-1:0] qin4;

    logic signed [D_W-1:0] ql;
    logic signed [D_W-1:0] qerf;

    logic out_valid1;
    logic out_valid2;
    logic out_valid3;
    logic out_valid4;

    //need qin until the end so depending on number of pipeline stages we need to keep it going forward

    always_ff@(posedge clk) begin
        if (rst) begin
            qsgn <= 0;
            qin1 <= 0;
            qin_abs <= 0;

            qmin <= 0;
            qb2 <= 0;
            qsgn2 <= 0;
            qin2 <= 0;

            ql <= 0;
            qsgn3 <= 0;
            qin3 <= 0;

            qerf <= 0;
            qin4 <= 0;

            qout <= 0;

            out_valid1 <= 0;
            out_valid2 <= 0;
            out_valid3 <= 0;
            out_valid4 <= 0;
            out_valid  <= 0;

            
        end else begin // only do work when data is valid
            qsgn <= qin[D_W-1]; //we can't actually make this combiantional because we need it later
            qin1 <= qin;
            qin_abs <= (qin[D_W-1] != 0) ? -qin : qin;
            out_valid1 <= in_valid;

            //coefficients are constant so don't need to pipeline them along

            // 2nd stage
            qmin <= (-qb < qin_abs) ? -qb : qin_abs;
            qb2 <= qb * 32'sd2; // need to specify signed values otherwise we default to unsigned which causes problems with negative numbers

            qsgn2 <= qsgn;
            qin2 <= qin1;
            out_valid2 <= out_valid1;

            // 3rd stage
            ql <= ((qmin + qb2) * qmin) + qc;

            qsgn3 <= qsgn2;
            qin3 <= qin2;
            out_valid3 <= out_valid2;
            
            //4th stage
            if (qsgn3 == 1) begin
                qerf <= -ql;
            end else begin
                qerf <= ql;
            end

            qin4 <= qin3;
            out_valid4 <= out_valid3;

            //5th stage
            qout <= ((qerf >>> SHIFT) + q1) * qin4;
            out_valid <= out_valid4;

            
        end
    end

endmodule