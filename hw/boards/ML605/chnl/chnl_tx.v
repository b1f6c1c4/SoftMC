// chnl_tx: High performance buffered Riffa/CHNL transmitter
//
// Feature:
//   - Customizable PCIe width (C_PCI_DATA_WIDTH)
//   - Customizable input width (TX_WIDTH)
//   - Stream-based aligned data transfer (CHNL_ALIGN)
//   - Send partial data if no input (MAX_IDLE_CYCLES)
//   - Maximum (1024*C_PCI_DATA_WIDTH)bits buffer size
//
// Constraint:
//   - C_PCI_DATA_WIDTH >= 32
//   - C_PCI_DATA_WIDTH % 32 == 0
//   - TX_WIDTH % GCD == 0
//   - C_PCI_DATA_WIDTH % GCD == 0
//   - CHNL_ALIGN >= C_PCI_DATA_WIDTH / 32
//   - MAX_LENGTH >= CHNL_ALIGN
//   - MAX_LENGTH <= 1024 * (C_PCI_DATA_WIDTH / 32)
//   - MAX_LENGTH % CHNL_ALIGN == 0
//
// Usage:
//   uint32_t buf[MAX_LENGTH];
//   int len = fpga_recv(fpga, chnl, buf, MAX_LENGTH, timeout);
//   for (int i = 0; i < len; i += CHNL_ALIGN)
//       process_data(buf + i);

module chnl_tx #(
   parameter C_PCI_DATA_WIDTH = 32,
   parameter TX_WIDTH = 32,
   parameter GCD = 32, // = gcd(TX_WIDTH, C_PCI_DATA_WIDTH)
   parameter CHNL_ALIGN = 4, // unit: uint32_t
   parameter MAX_LENGTH = 32, // unit: uint32_t
   parameter MAX_IDLE_CYCLES = 128
) (
   input clk,
   input rst,

   input i_val,
   output i_rdy,
   input [TX_WIDTH-1:0] i_data,

   output CHNL_TX_CLK,
   output reg CHNL_TX,
   input CHNL_TX_ACK,
   output CHNL_TX_LAST,
   output [31:0] CHNL_TX_LEN,
   output [30:0] CHNL_TX_OFF,
   output [C_PCI_DATA_WIDTH-1:0] CHNL_TX_DATA,
   output reg CHNL_TX_DATA_VALID,
   input CHNL_TX_DATA_REN
);
   localparam ALIGN = 32 * CHNL_ALIGN / C_PCI_DATA_WIDTH; // unit: C_PCI_DATA_WIDTH

   localparam S_IDLE = 1'd0;
   localparam S_SENDING = 1'd1;

   reg state, state_next;
   reg [31:0] cnt_queued, cnt_queued_next;
   reg [31:0] cnt_left, cnt_left_next;
   reg [31:0] cnt_idle_cycles, cnt_idle_cycles_next;

   wire [C_PCI_DATA_WIDTH-1:0] fifo_i_data;
   wire fifo_i_val;
   reg fifo_o_rdy;
   wire fifo_i_rdy, fifo_o_val;

   // equals to cnt_queue - cnt_left_next when S_IDLE->S_SENDING
   reg [31:0] cnt_queued_left;

   assign CHNL_TX_CLK = clk;
   assign CHNL_TX_LAST = 1;
   assign CHNL_TX_OFF = 0;
   // Notice: CHNL_TX is asserted before S_IDLE->S_SENDING, at the same time
   // of setting cnt_left_next; thus cnt_left is not ready yet
   assign CHNL_TX_LEN = cnt_left_next * C_PCI_DATA_WIDTH / 32; // unit: uint32_t

   // Receiving data from i_val/rdy/data
   always @(*) begin
      cnt_queued_next = cnt_queued_left;
      cnt_idle_cycles_next = cnt_idle_cycles;
      if (fifo_i_val && fifo_i_rdy) begin
         cnt_queued_next = cnt_queued_left + 1;
         cnt_idle_cycles_next = 0;
      end else if (!fifo_i_val && cnt_idle_cycles < MAX_IDLE_CYCLES) begin // avoid overflow
         cnt_idle_cycles_next = cnt_idle_cycles + 1;
      end
   end

   always @(*) begin
      state_next = state;
      cnt_left_next = cnt_left;

      fifo_o_rdy = 0;
      cnt_queued_left = cnt_queued;

      CHNL_TX = 0;
      CHNL_TX_DATA_VALID = 0;

      case (state)
         S_IDLE: begin
            if (cnt_queued * C_PCI_DATA_WIDTH >= MAX_LENGTH * 32) begin
               state_next = S_SENDING;
               cnt_left_next = MAX_LENGTH * 32 / C_PCI_DATA_WIDTH;
               cnt_queued_left = cnt_queued - cnt_left_next;
               CHNL_TX = 1;
            end else if (|cnt_queued && cnt_queued >= ALIGN) begin
               if (|MAX_IDLE_CYCLES && cnt_idle_cycles >= MAX_IDLE_CYCLES) begin
                  state_next = S_SENDING;
                  cnt_queued_left = cnt_queued % ALIGN;
                  cnt_left_next = cnt_queued - cnt_queued_left;
                  CHNL_TX = 1;
               end
            end
         end
         S_SENDING: begin
            CHNL_TX = 1;
            fifo_o_rdy = CHNL_TX_DATA_REN;
            CHNL_TX_DATA_VALID = fifo_o_val;
            if (CHNL_TX_DATA_REN && fifo_o_val) begin
               cnt_left_next = cnt_left - 1;
               if (cnt_left == 1) begin
                  state_next = S_IDLE;
                  CHNL_TX = 0;
               end
            end
         end
      endcase
   end

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         state <= S_IDLE;
         cnt_queued <= 0;
         cnt_left <= 0;
         cnt_idle_cycles <= 0;
      end else begin
         state <= state_next;
         cnt_queued <= cnt_queued_next;
         cnt_left <= cnt_left_next;
         cnt_idle_cycles <= cnt_idle_cycles_next;
      end
   end

   repacker #(
      .IN (TX_WIDTH / GCD),
      .OUT (C_PCI_DATA_WIDTH / GCD),
      .W (GCD)
   ) i_repacker (
      .clk_i (clk),
      .rst_ni (!rst),
      .in_val_i (i_val),
      .in_data_i (i_data),
      .in_rdy_o (i_rdy),
      .out_val_o (fifo_i_val),
      .out_data_o (fifo_i_data),
      .out_rdy_i (fifo_i_rdy)
   );

   fifo #(
      .WIDTH (C_PCI_DATA_WIDTH)
   ) i_fifo (
     .srst_i (rst),
     .clk_i (clk),
     .en_i (1'b1),
     .in_val_i (fifo_i_val),
     .in_data_i (fifo_i_data),
     .in_rdy_o (fifo_i_rdy),
     .out_val_o (fifo_o_val),
     .out_data_o (CHNL_TX_DATA),
     .out_rdy_i (fifo_o_rdy)
   );

endmodule
