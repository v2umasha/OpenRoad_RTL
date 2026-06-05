`timescale 1ps/1ps

/*
Clock gen, reset sequence, DUT instantiation, drive block, checker block, timeout block — these are the five pieces every TB needs.
out_addr and in_addr must be separate counters because pipeline latency decouples input and output timing.
Counter width needs $clog2(M)+1 bits to hold the value M itself, not just M-1.
localparam for constants, not logic with initial assignment.
$readmemh loads hex golden values — your Python script generates them from the reference model.
Timeout block catches silent failures where DUT produces fewer outputs than expected — errors==0 alone doesn't catch that.
*/

module gelu_tb #(
    parameter integer D_W   = 32,
    parameter integer SHIFT = 14,
    parameter integer M = 8
)();

    localparam signed [D_W-1:0] QB = -1816;
    localparam signed [D_W-1:0] QC = -348738;
    localparam signed [D_W-1:0] Q1 = -223;

    //clk and reset

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic [1:0] rst = 2'b11;

    always@(posedge clk) begin
        rst <= rst >> 1;
    end

    logic in_valid;
    logic signed [D_W-1:0] qin;
    logic out_valid;
    logic signed [D_W-1:0] qout;

    //read from mem files
    logic signed [D_W-1:0] in_mem [M-1:0];
    logic signed [D_W-1:0] out_mem [M-1:0];

    logic [$clog2(M):0] in_addr;
    logic [$clog2(M):0] out_addr;

    initial begin
        $dumpfile("gelu.vcd");
        $dumpvars(0, gelu_tb);
        $readmemh("gelu_in.mem", in_mem);
        $readmemh("gelu_out.mem", out_mem);
    end

    //dut
    gelu #(
        .D_W(D_W),
        .SHIFT(SHIFT)
    )
    gelu_test (
        .clk       (clk), 
        .rst       (rst[0]),
        .in_valid  (in_valid),
        .qin       (qin),
        .qb        (QB),
        .qc        (QC),
        .q1        (Q1),
        .out_valid (out_valid),
        .qout      (qout)
    );




    always_ff@(posedge clk) begin
        if (rst) begin
            in_valid <= 0;
            qin <= 0;
            in_addr <= 0;
        end else begin
            if (in_addr<M) begin
                in_valid <= 1;
                qin <= in_mem[in_addr];
                in_addr <= in_addr + 1;
            end else begin
                in_valid <= 0;
            end
        end
    end

    always_ff @( posedge clk ) begin : CHECKER
        
        if (rst) begin
            out_addr <= 0;
        end else begin

            if (out_valid) begin

                // === is like '==' but checks for Z and X as well 
                // ^ is the reduction XOR operator, it will return 1 if any bit of qout is X!
                if (out_mem[out_addr] != qout || ^qout === 1'bX) begin 
                    $error("Test failed at index %d: expected %h, got %h", out_addr, out_mem[out_addr], qout);
                end else begin
                    $display("Test passed at index %d: expected %h, got %h", out_addr, out_mem[out_addr], qout);
                end
                out_addr <= out_addr + 1;
            end
            
        end
        
    end


    initial begin
        repeat (M+20) @(posedge clk);
        if (out_addr != M) begin
            $error("expected %d but got %d", M, out_addr);
        end else begin
            $display("PASSED");
        end
        $finish;
    end
endmodule