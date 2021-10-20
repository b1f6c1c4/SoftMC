module buffer #(
   parameter WIDTH = 32
) (
   input clk,
   input rst,

   input i_val,
   output i_rdy,
   input [WIDTH-1:0] i_data,

   output o_val,
   input o_rdy,
   output [WIDTH-1:0] o_data
);

   localparam S_AOBI = 1'b0;
   localparam S_AIBO = 1'b1;

   reg state, state_next;

   reg oA_val, oB_val;
   reg [WIDTH-1:0] oA_data, oB_data;

   // For timing requirement, i_rdy must NOT depend on o_rdy.
   assign i_rdy = !rst && (state == S_AIBO ? !oA_val : !oB_val);
   assign o_val = state == S_AOBI ? oA_val : oB_val;
   assign o_data = state == S_AOBI ? oA_data : oB_data;

   always @(*) begin
      state_next = state;
      // Toggle state iff. the output buffer is clear
      if (!o_val || o_rdy) begin
         case (state)
            S_AOBI: state_next = S_AIBO;
            S_AIBO: state_next = S_AOBI;
         endcase
      end
   end

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         state <= S_AOBI;
      end else begin
         state <= state_next;
      end
   end

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         oA_val <= 0;
         oA_data <= 0;
      end else if (state == S_AIBO && !oA_val) begin // take input
         oA_val <= i_val;
         oA_data <= i_data;
      end else if (state == S_AOBI && o_rdy) begin // emit output
         oA_val <= 0;
      end
   end

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         oB_val <= 0;
         oB_data <= 0;
      end else if (state == S_AOBI && !oB_val) begin // take input
         oB_val <= i_val;
         oB_data <= i_data;
      end else if (state == S_AIBO && o_rdy) begin // emit output
         oB_val <= 0;
      end
   end

endmodule
