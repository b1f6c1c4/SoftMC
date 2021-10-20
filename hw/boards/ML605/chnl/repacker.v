module repacker #(
   parameter IN = 3, // number of chunks to receive at a time
   parameter OUT = 8, // number of chunks to emit at a time
   parameter W = 8 // size of a chunk
) (
   input clk,
   input rst,

   input i_val,
   output i_rdy,
   input [W*IN-1:0] i_data,

   output o_val,
   input o_rdy,
   output [W*OUT-1:0] o_data
);

   function integer clog2;
      input integer value;
      begin
         value = value - 1;
         for (clog2 = 0; value > 0; clog2 = clog2 + 1)
            value = value >> 1;
      end
   endfunction

   localparam BUFF = IN + OUT - 1; // max number of chunks buffered

   reg [clog2(BUFF+IN+1)-1:0] v; // number of chunks buffered
   reg [W-1:0] mem[0:BUFF-1]; // the buffered chunks
   reg [W-1:0] mx[0:IN+BUFF-1]; // the chunks after receiving

   // I/O control
   wire push, pop;
   assign i_rdy = pop ? v + IN <= BUFF + OUT : v + IN <= BUFF;
   assign o_val = v >= OUT;
   assign push = i_val && i_rdy;
   assign pop = o_val && o_rdy;

   genvar i;
   generate
      // Receiving
      for (i = 0; i < IN + BUFF; i = i + 1) begin : gi
         always @(*) begin
            if (v <= i && i < v + IN && push) begin
               mx[i] = i_data >> (W*(i - v));
            end else if (i < BUFF && i < v) begin
               mx[i] = mem[i];
            end else begin
               mx[i] = 0;
            end
         end
      end
      // Emitting
      for (i = 0; i < BUFF; i = i + 1) begin : gm
         always @(posedge clk, posedge rst) begin
            if (rst) begin
               mem[i] <= 0;
            end else if (pop) begin
               if (i + OUT < IN + BUFF) begin
                  mem[i] <= mx[i + OUT];
               end else begin
                  mem[i] <= 0;
               end
            end else begin
               mem[i] <= mx[i];
            end
         end
      end
      for (i = 0; i < OUT; i = i + 1) begin : go
         assign o_data[W*i+W-1:W*i] = mem[i];
      end
   endgenerate

   // Updating counter
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         v <= 0;
      end else begin
         v <= v + (push ? IN : 0) - (pop ? OUT : 0);
      end
   end

endmodule
