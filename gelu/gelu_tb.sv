`timescale 1ps / 1ps

module gelu_tb 
#(
    parameter integer D_W   = 32,
    parameter integer SHIFT = 14,
    parameter integer M     = 8
)
();

localparam integer REP = M + 40;

reg       clk = 1'b0;
reg [1:0] rst = 2'b11;

`ifndef XIL_TIMING
always #1 clk = ~clk;
`else
always #20000 clk = ~clk;
`endif

always @(posedge clk) begin
    rst <= rst >> 1;
end

reg                   in_valid;
reg  signed [D_W-1:0] qin;
reg  signed [D_W-1:0] qb;
reg  signed [D_W-1:0] qc;
reg  signed [D_W-1:0] q1;
wire                  out_valid;
wire signed [D_W-1:0] qout;

reg signed [D_W-1:0]     in_memory  [M-1:0];
reg signed [D_W-1:0]     out_memory [M-1:0];
reg        [$clog2(M):0] in_addr;
reg        [$clog2(M):0] out_addr;
reg        [$clog2(M):0] errors;

initial begin
    $readmemh("gelu_in.mem", in_memory);
    $readmemh("gelu_out.mem", out_memory);
end

always @(posedge clk) begin
    if (rst[0]) begin
        in_addr  <= 0;
        out_addr <= 0;
        in_valid <= 0;
        qin      <= 0;
        qb       <= 0;
        qc       <= 0;
        q1       <= 0;
        errors   <= 0;
    end else begin
        if (in_addr <= M-1) begin
            in_addr  <= in_addr + 1;
            in_valid <= 1;
            qin      <= in_memory[in_addr];
        end else begin
            in_valid <= 0;
        end

        qb <= -1816;
        qc <= -348738;
        q1 <= -223;

        $display("# Time=%0d, in_valid=%0d, in_cntr=%0d, qin=%0d, out_valid=%0d, out_cntr=%0d, qout=%0d", $time, in_valid, in_addr, qin, out_valid, out_addr, qout);

        if (out_valid) begin
            out_addr <= out_addr + 1;
            if (out_memory[out_addr] != qout || ^qout === 1'bX) begin
                $display("# Error: Time=%0d, qout=%0d, true=%0d", $time, qout, out_memory[out_addr]);
                errors <= errors + 1;
            end
        end
    end
end

initial begin
    $timeformat(-9, 2, " ns", 20);
    repeat(REP) @(posedge clk);
    if (out_addr != M) begin
        $display("# Error: Incorrect number of outputs were produced by the module: given inputs=%0d, produced outputs=%0d.", in_addr, out_addr);
    end else begin
        if (errors > 0)
            $display("\n--\nErrors=%0d\n--\n", errors);
        else
            $display("\n--\nPASSED!\n--\n");
    end
    $finish;
end

gelu
`ifndef XIL_TIMING
#(
    .D_W   ( D_W    ),
    .SHIFT ( SHIFT  )
)
`endif
gelu_test (
    .clk       ( clk       ), 
    .rst       ( rst[0]    ),
    .in_valid  ( in_valid  ),
    .qin       ( qin       ),
    .qb        ( qb        ),
    .qc        ( qc        ),
    .q1        ( q1        ),
    .out_valid ( out_valid ),
    .qout      ( qout      )
);

endmodule
