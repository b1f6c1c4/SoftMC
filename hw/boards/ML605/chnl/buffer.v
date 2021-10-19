module buffer #(
   parameter WIDTH = 32
) (
   input clk,
   input rst,

   input i_val,
   output i_rdy,
   input [WIDTH-1:0] i_data,

   output reg o_val,
   input o_rdy,
   output reg [WIDTH-1:0] o_data
);

   wire en;

   assign i_rdy = o_rdy || !o_val;
   assign en = i_rdy && i_val;

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         o_val <= 0;
         o_data <= 0;
      end else if (en) begin
         o_val <= i_val;
         o_data <= i_data;
      end
   end

endmodule
