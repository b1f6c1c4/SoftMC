`timescale 1ns / 1ps

module softMC_pcie_app #(
   parameter C_PCI_DATA_WIDTH = 9'd32, DQ_WIDTH = 64
)(
   input clk,
   input rst,
   output CHNL_RX_CLK,
   input CHNL_RX,
   output reg CHNL_RX_ACK,
   input CHNL_RX_LAST,
   input [31:0] CHNL_RX_LEN,
   input [30:0] CHNL_RX_OFF,
   input [C_PCI_DATA_WIDTH-1:0] CHNL_RX_DATA,
   input CHNL_RX_DATA_VALID,
   output CHNL_RX_DATA_REN,

   output CHNL_TX_CLK,
   output CHNL_TX,
   input CHNL_TX_ACK,
   output CHNL_TX_LAST,
   output [31:0] CHNL_TX_LEN,
   output [30:0] CHNL_TX_OFF,
   output [C_PCI_DATA_WIDTH-1:0] CHNL_TX_DATA,
   output CHNL_TX_DATA_VALID,
   input CHNL_TX_DATA_REN,

   output  app_en,
   input app_ack,
   output[31:0] app_instr,

   //Data read back Interface
   input rdback_fifo_empty,
   output rdback_fifo_rden,
   input[DQ_WIDTH*4 - 1:0] rdback_data
 );

 assign CHNL_RX_CLK = clk;
 assign CHNL_TX_CLK = clk;
 assign CHNL_TX_OFF = 0;
 assign CHNL_TX_LAST = 1'd1;

 reg app_en_r;
 reg[C_PCI_DATA_WIDTH-1:0] rx_data_r;

 reg old_chnl_rx;
 reg pending_ack = 0;

 //always acknowledge transaction
 always@(posedge clk) begin
      old_chnl_rx <= CHNL_RX;

      if(~old_chnl_rx & CHNL_RX)
         pending_ack <= 1'b1;

      if(CHNL_RX_ACK)
         CHNL_RX_ACK <= 1'b0;
      else begin
         if(pending_ack /*& app_ack*/) begin
            CHNL_RX_ACK <= 1'b1;
            pending_ack <= 1'b0;
         end
      end
 end

 //register incoming data
 assign CHNL_RX_DATA_REN = ~app_en_r | app_ack;
 always@(posedge clk) begin
   if(~app_en_r | app_ack) begin
      app_en_r <= CHNL_RX_DATA_VALID;
      rx_data_r <= CHNL_RX_DATA;
   end
 end

//send to the MC
assign app_en = app_en_r;
assign app_instr = rx_data_r;

//SEND DATA TO HOST
reg tx_state;
always @(posedge clk, posedge rst) begin
   if (rst) begin
      tx_state <= 0;
   end else if (tx_state == 0) begin
      if (!rdback_fifo_empty) begin
         tx_state <= 1;
      end
   end else begin
      if (CHNL_TX_DATA_REN && CHNL_TX_DATA_VALID) begin
         tx_state <= 0;
      end
   end
end

assign CHNL_TX_CLK = clk;
assign CHNL_TX = tx_state == 1;
assign CHNL_TX_OFF = 0;
assign CHNL_TX_LEN = 1;
assign CHNL_TX_LAST = 1;
assign CHNL_TX_DATA_VALID = tx_state == 1 && !rdback_fifo_empty;
assign rdback_fifo_rden = tx_state == 1 && CHNL_TX_DATA_REN;
assign CHNL_TX_DATA = rdback_data[31:0];

endmodule
