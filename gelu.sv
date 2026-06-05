`timescale 1ps / 1ps

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

            
        end else if (in_valid) begin // only do work when data is valid
            qsgn <= {qin[D_W-1]}; //we can't actually make this combiantional because we need it later
            qin1 <= qin;
            qin_abs <= qin;
            out_valid1 <= 1;

            //we need to tackle the abs
            //if value is already positive we can keep it moving forward but if it is negative
            // we need hardware to convert it
            if (qin[D_W-1] != 0) begin
                //bitwise negation
                qin_abs <= qin * -1;
            end

            //coefficients are constant so don't need to pipeline them along

            // 2nd stage
            qmin <= (qb > qin_abs) ? qb : qin_abs;
            qb2 <= qb * 2;
            qsgn2 <= qsgn;
            qin2 <= qin1;

            out_valid2 <= out_valid1;

            // 3rd stage
            ql <= ((qmin + qb2) * qmin) + qc;
            qsgn3 <= qsgn2;
            qin3 <= qin2;

            out_valid3 <= out_valid2;
            
            //4th stage
            qerf <= ql * qsgn3; // might need to move some of stage 3 into stage 4 -> we will look at timing
            qin4 <= qin3;
            out_valid4 <= out_valid3;

            //5th stage
            out_valid <= out_valid4;
            qout <= ((qerf >> SHIFT) + q1) * qin4;



            
        end
    end

endmodule