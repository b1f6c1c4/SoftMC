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

   input o_val,
   output o_rdy,
   input [RX_WIDTH-1:0] o_data,

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

   localparam S_IDLE = 2'd0;
   localparam S_OPENING = 2'd1;
   localparam S_OPEN = 2'd2;

   reg [1:0] state, state_next;
   reg repacker_i_val;
   wire repacker_i_rdy;

   assign CHNL_RX_CLK = clk;

   always @(*) begin
      state_next = state;

      repacker_i_val = 0;

      CHNL_RX_ACK = 0;
      CHNL_RX_DATA_REN = 0;

      case (state)
         S_IDLE: begin
            if (CHNL_RX) begin
               state_next = S_OPENING;
            end
         end
         S_OPENING: begin
            if (CHNL_RX) begin
               state_next = S_OPEN;
               CHNL_RX_ACK = 1;
            end else begin
               state_next = S_IDLE;
            end
         end
         S_OPEN: begin
            if (CHNL_RX) begin
               repacker_i_val = CHNL_RX_DATA_VALID;
               CHNL_RX_DATA_REN = CHNL_RX_DATA_VALID && repacker_i_rdy;
            end else begin
               state_next = S_IDLE;
            end
         end
      endcase
   end

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         state <= S_IDLE;
      end else begin
         state <= state_next;
      end
   end

   repacker #(
      .IN (RX_WIDTH / GCD),
      .OUT (C_PCI_DATA_WIDTH / GCD),
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
