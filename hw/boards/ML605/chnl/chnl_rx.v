// chnl_rx: Simple unbuffered Riffa/CHNL receiver
//
// Feature:
//   - Customizable PCIe width (C_PCI_DATA_WIDTH)
//   - Customizable input width (I_WIDTH)
//   - Stream-based data transfer
//
// Constraint:
//   - RX_WIDTH % GCD == 0
//   - C_PCI_DATA_WIDTH % GCD == 0
//
// Usage:
//   uint32_t buf[MAX_LENGTH];
//   int len = fpga_send(fpga, chnl, buf, MAX_LENGTH, timeout);
//   assert(len == MAX_LENGTH);

module chnl_rx #(
   parameter C_PCI_DATA_WIDTH = 9'd32,
   parameter RX_WIDTH = 32,
   parameter GCD = 32 // = gcd(RX_WIDTH, C_PCI_DATA_WIDTH)
) (
   input clk,
   input rst,

   output o_val,
   input o_rdy,
   output [RX_WIDTH-1:0] o_data,

   output CHNL_RX_CLK,
   input CHNL_RX,
   output reg CHNL_RX_ACK,
   input CHNL_RX_LAST,
   input [31:0] CHNL_RX_LEN,
   input [30:0] CHNL_RX_OFF,
   input [C_PCI_DATA_WIDTH-1:0] CHNL_RX_DATA,
   input CHNL_RX_DATA_VALID,
   output reg CHNL_RX_DATA_REN
);

   localparam S_IDLE = 1'd0;
   localparam S_RECEIVING = 1'd1;

   reg state, state_next;
   reg [31:0] cnt_left, cnt_left_next;
   reg repacker_i_val;
   wire repacker_i_rdy;

   assign CHNL_RX_CLK = clk;

   always @(*) begin
      state_next = state;
      cnt_left_next = cnt_left;

      repacker_i_val = 0;

      CHNL_RX_ACK = 0;
      CHNL_RX_DATA_REN = 0;

      case (state)
         S_IDLE: begin
            if (CHNL_RX) begin
               state_next = S_RECEIVING;
               cnt_left_next = CHNL_RX_LEN;
            end
         end
         S_RECEIVING: begin
            CHNL_RX_ACK = 1;
            if (~|cnt_left) begin
               state_next = S_IDLE;
            end else begin
               repacker_i_val = CHNL_RX_DATA_VALID;
               CHNL_RX_DATA_REN = repacker_i_rdy;
               if (CHNL_RX_DATA_VALID && repacker_i_rdy) begin
                  cnt_left_next = cnt_left - 1;
               end
            end
         end
      endcase
   end

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         state <= S_IDLE;
         cnt_left <= 0;
      end else begin
         state <= state_next;
         cnt_left <= cnt_left_next;
      end
   end

   repacker #(
      .IN (C_PCI_DATA_WIDTH / GCD),
      .OUT (RX_WIDTH / GCD),
      .W (GCD)
   ) i_repacker (
      .clk_i (clk),
      .rst_ni (!rst),
      .in_val_i (repacker_i_val),
      .in_data_i (CHNL_RX_DATA),
      .in_rdy_o (repacker_i_rdy),
      .out_val_o (o_val),
      .out_data_o (o_data),
      .out_rdy_i (o_rdy)
   );

endmodule
