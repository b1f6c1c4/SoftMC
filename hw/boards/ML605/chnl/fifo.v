module fifo #(
   parameter WIDTH = 32
) (
   input clk,
   input srst,

   input i_val,
   output i_rdy,
   input [WIDTH-1:0] i_data,

   output o_val,
   input o_rdy,
   output [WIDTH-1:0] o_data
);
   localparam W = 32;
   localparam PIECES = (WIDTH + W - 1) / W;

   wire [W*PIECES-1:0] wdata, rdata;
   wire [PIECES-1:0] fulls, emptys, aemptys;
   wire full = |fulls;
   wire empty = |emptys;
   wire aempty = |aemptys;
   reg rden;

   reg rbuf, rbuf_next;
   always @(posedge clk) begin
      if (srst) begin
         rbuf <= 0;
      end else begin
         rbuf <= rbuf_next;
      end
   end

   assign i_rdy = ~full;
   assign wdata = i_data;
   assign o_val = rbuf;
   assign o_data = rdata[WIDTH-1:0];

   genvar i;
   generate
      for (i = 0; i < PIECES; i = i + 1) begin : g
         wire [63:0] wd, rd;
         assign wd = {32'b0,wdata[i*W+W-1:i*W]};
         assign rdata[i*W+W-1:i*W] = rd[W-1:0];
         FIFO36E1 #(
            .ALMOST_FULL_OFFSET (1),
            .ALMOST_EMPTY_OFFSET (1),
            .EN_SYN ("TRUE"),
            .DATA_WIDTH (36),
            .DO_REG (0)
         ) inst (
            .RST (srst),
            .RSTREG (0),
            .REGCE (0),

            .WRCLK (clk),
            .WREN (~srst && i_val && i_rdy),
            .DI (wd),
            .DIP (0),
            .FULL (fulls[i]),
            .ALMOSTFULL (),
            .WRCOUNT (), .WRERR (),

            .RDCLK (clk),
            .RDEN (rden),
            .DO (rd),
            .DOP (),
            .EMPTY (emptys[i]),
            .ALMOSTEMPTY (aemptys[i]),
            .RDCOUNT (), .RDERR (),

            .INJECTDBITERR (0), .INJECTSBITERR (0),
            .DBITERR (), .SBITERR (), .ECCPARITY ()
         );
      end
   endgenerate

   always @(*) begin
      if (srst) begin
         rden = 0;
         rbuf_next = 0;
      end else begin
         if (empty) begin
            rden = 0;
            rbuf_next = rbuf && ~o_rdy;
         end else if (~rbuf) begin
            rden = 1; // prefetch
            rbuf_next = 1;
         end else if (o_rdy) begin
            rden = 1; // prefetch next
            rbuf_next = 1;
         end else begin
            rden = 0; // keep
            rbuf_next = 1;
         end
      end
   end

endmodule
