module deep_fifo #(
   parameter WIDTH = 32,
   parameter DEPTH = 1 // unit: 1024
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

   wire m_val[DEPTH:0];
   wire m_rdy[DEPTH:0];
   wire [WIDTH-1:0] m_data[DEPTH:0];

   assign m_val[0] = i_val;
   assign o_val = m_val[DEPTH];
   assign m_rdy[DEPTH] = o_rdy;
   assign i_rdy = m_rdy[0];
   assign m_data[0] = i_data;
   assign o_data = m_data[DEPTH];

   genvar i;
   generate
      for (i = 0; i < DEPTH; i = i + 1) begin : g
         fifo #(
            .WIDTH (WIDTH)
         ) inst (
            .clk (clk),
            .srst (srst),
            .i_val (m_val[i]),
            .i_rdy (m_rdy[i]),
            .i_data (m_data[i]),
            .o_val (m_val[i+1]),
            .o_rdy (m_rdy[i+1]),
            .o_data (m_data[i+1])
         );
      end
   endgenerate

endmodule
